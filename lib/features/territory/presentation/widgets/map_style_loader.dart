import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/env.dart';

enum MapStyleLoadStatus { loading, loaded, retrying, failed }

/// Drives which style URL a `MapLibreMap` should use and escalates through
/// fallback tiers when the style never finishes loading. `maplibre_gl`
/// exposes no style-load-failure callback and no way to swap a running
/// map's style — `styleString` is only read once, at native view creation
/// (see `maplibre_map.dart`'s `creationParams`) — so the only way to apply
/// a new style is to give the `MapLibreMap` widget a new [styleKey], which
/// forces Flutter to tear down and recreate the native view.
///
/// Tiers, in order: primary (`Env.mapStyleUrl`) → manually configured
/// hosted fallback ([Env.mapStyleFallbackUrl]) → bundled self-hosted
/// fallback (a local-asset style pointing at [Env.tileWorkerUrl], a global
/// low-zoom OSM extract — degraded detail, but doesn't depend on any
/// external style host being reachable). Each tier not configured (null)
/// is skipped. [onChange] is called whenever [styleString]/[styleKey]/
/// [status] change so the host `State` can `setState`.
class MapStyleLoader {
  // An initializing formal here would force callers to name the argument
  // `_isDark` (a private identifier), not the public `isDark` every call
  // site uses — hence the plain assignment below over `this._isDark`.
  MapStyleLoader({
    required this.onChange,
    required bool isDark,
    Duration? timeout,
  }) : _isDark = isDark, // ignore: prefer_initializing_formals
       _timeout = timeout ?? const Duration(seconds: 15);

  final VoidCallback onChange;
  final Duration _timeout;

  /// The app's theme brightness — picks which default style tier 0 falls
  /// back to (see `Env.mapStyleUrl`'s doc comment). Mutable, via
  /// [updateBrightness]: `IndexedStack`-based tab shells (this app's,
  /// `AppShellPage`) build every tab eagerly at startup, which can run
  /// before `ThemeModeCubit` finishes loading the persisted preference from
  /// disk — a map page built at that exact moment would otherwise lock onto
  /// a transient, possibly-wrong brightness forever (the chrome around it
  /// doesn't have this problem since `AppleGlassContainer` re-reads
  /// `Theme.of(context)` on every rebuild instead of caching it once).
  bool _isDark;

  static const _bundledFallbackAssetPath = 'assets/map/fallback_style.json';
  static const _bundledFallbackPlaceholder = '{{TILE_WORKER_BASE_URL}}';

  /// Must match `assets/map/fallback_style.json`'s source `maxzoom`. The
  /// bundled fallback tier only has data up to this zoom — animating the
  /// camera past it (e.g. to a "zoomed into your GPS fix" level meant for
  /// full-detail tiers) doesn't error, but overzooms a single low-res tile
  /// into a giant, illegible solid-color fragment instead of showing a
  /// recognizable degraded map. Found live: panning after a forced fallback
  /// moved the position marker correctly (real interactive map, real
  /// style), but the fill stayed a uniform color with no visible
  /// coastline/borders anywhere on screen — a dead giveaway of overzoom,
  /// confirmed by checking this tier never actually reaches its own
  /// `maxzoom` bound in the affected call sites.
  static const bundledFallbackMaxZoom = 6.0;

  /// Highest zoom the *active* tier's data actually supports, or `null` for
  /// tiers backed by full-detail hosted styles (no clamp needed). Callers
  /// animating the camera to a level tuned for full detail (e.g. a GPS fix)
  /// should clamp to this when non-null.
  double? get dataMaxZoom => _tier == 2 ? bundledFallbackMaxZoom : null;

  /// True once the loader has settled on the bundled offline fallback tier
  /// (tier 2) — the lowest-quality tier, only reachable when both the
  /// primary and hosted-fallback style URLs failed to load in time.
  /// Distinct from [status]: `status` flips to [MapStyleLoadStatus.loaded]
  /// as soon as *any* tier (including this one) finishes loading, and the
  /// retry banner disappears with it — leaving no indicator that the map is
  /// degraded unless a caller checks this separately (audit finding: the
  /// low-zoom fallback tier could silently masquerade as a fully-loaded
  /// map). Callers should show a persistent, non-auto-dismissing chip
  /// whenever this is true, for as long as it stays true.
  bool get isDegradedFallback => _tier == 2;

  late String styleString = Env.mapStyleUrl(isDark: _isDark);
  Key styleKey = const ValueKey('map-style-0');
  MapStyleLoadStatus status = MapStyleLoadStatus.loading;

  int _tier = 0;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;

  /// Call once, right after the `MapLibreMap` widget is built (mirrors
  /// `onMapCreated`) to start the failure-detection timer for the current
  /// tier.
  void start() => _armTimeout();

  /// Call from `onStyleLoadedCallback`.
  void onStyleLoaded() {
    _timer?.cancel();
    if (status != MapStyleLoadStatus.loaded) {
      status = MapStyleLoadStatus.loaded;
      onChange();
    }
  }

  /// Resets to the primary tier and retries — e.g. from a manual "Retry"
  /// button after [status] reaches [MapStyleLoadStatus.failed].
  void retry() {
    _tier = 0;
    _swapTo(
      Env.mapStyleUrl(isDark: _isDark),
      status: MapStyleLoadStatus.retrying,
    );
  }

  /// Call from the host `State`'s `didChangeDependencies` with the current
  /// `Theme.of(context).brightness == Brightness.dark`. A no-op unless the
  /// brightness actually changed and the loader is still on tier 0/1 (a
  /// tier-2 bundled-fallback swap means the primary/fallback hosts are
  /// unreachable — reverting to a tier-0 URL there would just restart a
  /// doomed load instead of leaving the working degraded map alone).
  void updateBrightness(bool isDark) {
    if (isDark == _isDark || _tier > 1) return;
    _isDark = isDark;
    if (_tier == 0) {
      _swapTo(
        Env.mapStyleUrl(isDark: isDark),
        status: MapStyleLoadStatus.retrying,
      );
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _armTimeout() {
    _timer?.cancel();
    _timer = Timer(_timeout, () {
      unawaited(_advance());
    });
  }

  Future<void> _advance() async {
    var candidateTier = _tier + 1;
    while (true) {
      final next = await _styleForTier(candidateTier);
      if (next == null && candidateTier > _maxTier) {
        if (_disposed) return;
        status = MapStyleLoadStatus.failed;
        onChange();
        return;
      }
      if (next != null) {
        _tier = candidateTier;
        _swapTo(next, status: MapStyleLoadStatus.retrying);
        return;
      }
      candidateTier++;
    }
  }

  static const _maxTier = 2;

  Future<String?> _styleForTier(int tier) async {
    switch (tier) {
      case 1:
        return Env.mapStyleFallbackUrl;
      case 2:
        final workerUrl = Env.tileWorkerUrl;
        if (workerUrl == null) return null;
        final template = await rootBundle.loadString(_bundledFallbackAssetPath);
        return template.replaceAll(_bundledFallbackPlaceholder, workerUrl);
      default:
        return null;
    }
  }

  void _swapTo(String style, {required MapStyleLoadStatus status}) {
    if (_disposed) return;
    _generation++;
    styleString = style;
    styleKey = ValueKey('map-style-$_generation');
    this.status = status;
    onChange();
    _armTimeout();
  }
}
