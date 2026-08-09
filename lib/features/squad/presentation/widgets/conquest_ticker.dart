import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/motion_tokens.dart';
import '../../../../core/theme/shape_tokens.dart';
import '../../domain/entities/territory_capture_feed_item.dart';
import '../../domain/usecases/get_recent_territory_captures.dart';

/// Small live activity feed of recent territory captures — "conquest
/// ticker" (2026-07-29 UI/UX audit item 9). Falls back to a periodic
/// refetch rather than Realtime, since `SquadRemoteDataSource` only opens a
/// per-squad Presence/Broadcast channel and there's no existing public
/// broadcast channel this feed could piggyback on.
class ConquestTicker extends StatefulWidget {
  const ConquestTicker({super.key});

  @override
  State<ConquestTicker> createState() => ConquestTickerState();
}

class ConquestTickerState extends State<ConquestTicker> {
  static const _refetchInterval = Duration(seconds: 30);
  static const _rotateInterval = Duration(seconds: 4);

  List<TerritoryCaptureFeedItem> _items = const [];
  var _index = 0;
  Timer? _refetchTimer;
  Timer? _rotateTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refetchTimer = Timer.periodic(_refetchInterval, (_) => unawaited(_load()));
    _rotateTimer = Timer.periodic(_rotateInterval, (_) {
      if (!mounted || _items.length < 2) return;
      setState(() => _index = (_index + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _refetchTimer?.cancel();
    _rotateTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await getIt<GetRecentTerritoryCaptures>()(rowLimit: 10);
      if (!mounted) return;
      setState(() {
        _items = items;
        if (_index >= items.length) _index = 0;
      });
    } catch (_) {
      // Best-effort — a failed refetch just leaves the last known feed
      // showing (or nothing, before the first successful load).
    }
  }

  String _label(TerritoryCaptureFeedItem item) {
    final areaLabel = item.areaTakenSqm >= 10000
        ? '${(item.areaTakenSqm / 1000000).toStringAsFixed(2)} km²'
        : '${item.areaTakenSqm.round()} m²';
    return item.loserDisplayName == null
        ? '${item.winnerDisplayName} captured $areaLabel of unclaimed ground'
        : '${item.winnerDisplayName} captured $areaLabel from ${item.loserDisplayName}';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final item = _items[_index.clamp(0, _items.length - 1)];

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: MotionTokens.defaultSpatial,
        switchInCurve: MotionTokens.effectsCurve,
        switchOutCurve: MotionTokens.effectsCurve,
        child: Container(
          key: ValueKey(item.captureId),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: ShapeTokens.r16,
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: scheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _label(item),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
