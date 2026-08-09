import 'package:flutter/material.dart';

import 'motion_tokens.dart';
import 'shape_tokens.dart';

/// Shared M3-Expressive-style building blocks used across the redesigned
/// alarm/verification/onboarding screens (see the "Awaken Flutter Mobile
/// App" Claude Design handoff, `m3x.css`). Core Flutter ships none of this
/// — same rationale as `motion_tokens.dart`/`shape_tokens.dart`.

/// Secondary/de-emphasized label color used across every card subtitle,
/// section header, and empty state — previously a single hardcoded
/// `Color(0xFF8E8E93)` regardless of theme brightness. Contrast against the
/// dark canvas (`AppTheme.darkCanvas`) is already ~5.5:1, well past WCAG
/// AA's 4.5:1, so dark mode keeps that value unchanged. Against the light
/// surface (`0xFFF2F2F7`) the same color only clears ~3:1 — below AA for
/// the 10-13px sizes it's used at throughout. `0xFF6E6E73` clears ~4.5:1
/// against that light surface while staying visually in the same "iOS
/// secondary label" gray family.
Color secondaryLabelColor(BuildContext context) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);
}

/// The single-letter fallback shown on avatar badges (top-bar avatar,
/// Profile's own avatar) when there's no provider photo. `displayName`/
/// `email` can be an empty string — not just null — for some Supabase
/// providers/email sign-ups, and indexing `[0]` on an empty string throws a
/// `RangeError`; every call site used to do that inline via `?? 'A'`, which
/// only guards `null`, not `''`, crashing the avatar (and with it every top
/// bar it appears in) for those accounts.
String avatarInitial({
  required bool isAnonymous,
  String? displayName,
  String? email,
}) {
  if (isAnonymous) return 'G';
  final label = (displayName != null && displayName.isNotEmpty)
      ? displayName
      : email;
  return (label != null && label.isNotEmpty) ? label[0].toUpperCase() : 'A';
}

/// A solid, no-blur surface card — the app's default "raised panel" look
/// (used for the floating headers/docks over the Home/Territory/ActiveRun
/// screens, list rows, etc). Originally a real iOS-style `BackdropFilter`
/// glass blur; replaced with a solid surface because blurring a live
/// `MapLibreMap` platform view underneath is one of the most expensive
/// things Flutter can composite on Android (a full-region snapshot +
/// Gaussian blur, every frame it's on screen — cost independent of
/// `setState`/rebuild avoidance, see `TerritoryPage`'s presence-throttling
/// comments for the related rebuild-side fix).
///
/// Styled entirely from `ColorScheme` (Material 3 tonal-elevation roles:
/// `surfaceContainerHigh` for the panel, `outlineVariant` for its border,
/// `shadow` for the drop shadow) rather than hardcoded hex colors — this is
/// what actually makes a "raised surface" read correctly in both
/// light/dark and under a custom seed color, without needing a manual
/// `isDark` branch: `ColorScheme.fromSeed` already computes the right tone
/// for either brightness. Flutter's `material`/`cupertino` libraries don't
/// ship Material 3 Expressive natively as of this Flutter release (tracked
/// upstream, flutter/flutter#168813) — the M3-Expressive-*styled* shape/
/// motion tokens this app uses (`ShapeTokens`, `MotionTokens`) are
/// hand-rolled for that reason, but the surface *color* logic below is
/// plain, current-generation M3 (`ColorScheme` surface-container roles),
/// no compatibility gap there.
class AppleGlassContainer extends StatelessWidget {
  const AppleGlassContainer({
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurAmount = 20.0,
    this.borderColor,
    this.borderWidth = 0.5,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  /// Retained for backwards compatibility. No blur filter is applied — see
  /// the class doc comment.
  final double blurAmount;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveRadius = borderRadius ?? ShapeTokens.r16;

    final surfaceBorder =
        borderColor ?? scheme.outlineVariant.withValues(alpha: 0.4);

    // `Material` + `InkWell` only when actually tappable, so a future
    // `onTap` caller gets standard ripple/press feedback instead of a
    // silent tap — but the far more common non-tappable case (every
    // current call site) stays exactly as cheap as a plain `Container`,
    // no `Material`/`InkWell` participating in hit-testing for nothing.
    final body = onTap != null
        ? Material(
            type: MaterialType.transparency,
            borderRadius: effectiveRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ),
          )
        : Padding(padding: padding ?? EdgeInsets.zero, child: child);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: effectiveRadius,
        border: Border.all(color: surfaceBorder, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.06,
            ),
            blurRadius: scheme.brightness == Brightness.dark ? 16 : 12,
            offset: Offset(0, scheme.brightness == Brightness.dark ? 4 : 3),
          ),
        ],
      ),
      child: body,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// The "G" profile-avatar circle used in the top-right corner of Home,
/// Territory, and Squad's app bars — previously duplicated three times as a
/// 40x40 tappable `SizedBox`, under WCAG 2.5.5's 44x44 touch-target minimum.
/// Extracted once so the fix (44x44 tap area, explicit `Semantics` label
/// rather than relying on `Tooltip`'s message reaching TalkBack) lands
/// everywhere at once instead of needing three separate edits.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({
    required this.initial,
    required this.onTap,
    this.avatarUrl,
    super.key,
  });

  final String initial;
  final VoidCallback onTap;

  /// The signed-in-with-Google user's provider photo, if any. Falls back
  /// to [initial] when null, or if the image fails to load — same
  /// fallback behavior as the Profile page's own avatar.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fallback = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Profile',
      button: true,
      child: Tooltip(
        message: 'Profile',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: avatarUrl == null
                    ? fallback
                    : ClipOval(
                        child: Image.network(
                          avatarUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          cacheWidth: (40 * dpr).round(),
                          cacheHeight: (40 * dpr).round(),
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : fallback,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A colored "flower" badge with a centered icon/child — the handoff's
/// `.m3x-flower` CSS shape: two stacked squares, each rounded 32%, the
/// second rotated 45°, which reads as a soft four-petaled blob. Used for
/// empty-state icons, the alarm bell, the celebration trophy, and the
/// reliability-test checkmark.
class ExpressiveFlower extends StatelessWidget {
  const ExpressiveFlower({
    required this.size,
    required this.color,
    required this.child,
    this.animatePop = false,
    this.borderColor,
    super.key,
  });

  final double size;
  final Color color;
  final Widget child;

  /// Plays a spring-like scale-in once on mount (the handoff's `m3x-pop`
  /// keyframe) — used for celebratory/confirming moments, not static badges.
  final bool animatePop;

  /// Optional outline traced on both petal squares. Without a seed-derived
  /// color, [color] alone can land on a near-surface-tone fill (e.g.
  /// `surfaceContainerHigh` under some dynamic-color palettes is only ~6
  /// tones off the page background, with no chroma to fall back on) where
  /// the whole blob silhouette disappears — confirmed against a live
  /// screenshot, not just theoretical. A border keeps the badge shape
  /// legible regardless of how close the fill lands to the background.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final petalRadius = BorderRadius.circular(size * 0.32);
    final border = borderColor == null
        ? null
        : Border.all(color: borderColor!, width: 1.5);
    final blob = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: petalRadius,
              border: border,
            ),
            child: SizedBox(width: size, height: size),
          ),
          Transform.rotate(
            angle: 0.785398, // 45deg
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: petalRadius,
                border: border,
              ),
              child: SizedBox(width: size, height: size),
            ),
          ),
          child,
        ],
      ),
    );
    // "Reduce motion" accessibility setting — a purely decorative pop-in
    // shouldn't play for a user who has asked the OS to minimize animation.
    if (!animatePop || MediaQuery.disableAnimationsOf(context)) return blob;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionTokens.defaultSpatial,
      curve: MotionTokens.spatialCurve,
      builder: (context, value, scaledChild) =>
          Transform.scale(scale: value, child: scaledChild),
      child: blob,
    );
  }
}

/// M3 Expressive "contained loading indicator" — a squircle that morphs
/// through a handful of asymmetric corner-radius shapes while slowly
/// rotating (the handoff's `m3x-loader`: `m3x-morph` + `m3x-spin-slow`
/// keyframes), rather than a plain spinner.
class ExpressiveLoader extends StatefulWidget {
  const ExpressiveLoader({this.size = 44, this.color, super.key});

  final double size;
  final Color? color;

  @override
  State<ExpressiveLoader> createState() => _ExpressiveLoaderState();
}

class _ExpressiveLoaderState extends State<ExpressiveLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Corner-radius keyframes approximating m3x.css's `m3x-morph` blob cycle.
  static const _shapeStops = [0.42, 0.58, 0.46, 0.42];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    // Reduce-motion: freeze on the resting shape instead of looping the
    // morph/spin — matches the guard already applied to [ExpressiveFlower].
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_controller.isAnimating) _controller.stop();
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.size * _shapeStops.first),
        ),
      );
    }
    if (!_controller.isAnimating) _controller.repeat();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final morphT = (_controller.value * 2) % 1.0;
        final stopIndex = (_controller.value * (_shapeStops.length - 1))
            .floor();
        final localT = _controller.value * (_shapeStops.length - 1) - stopIndex;
        final radiusFactor =
            _shapeStops[stopIndex] +
            (_shapeStops[(stopIndex + 1).clamp(0, _shapeStops.length - 1)] -
                    _shapeStops[stopIndex]) *
                localT;
        return Transform.rotate(
          angle: morphT * 2 * 3.14159,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(widget.size * radiusFactor),
            ),
          ),
        );
      },
    );
  }
}

/// M3-Expressive pill switch: thumb grows and shows a check glyph when on
/// (the handoff's `M3Switch`), rather than the standard M3 `Switch`.
class ExpressiveSwitch extends StatelessWidget {
  const ExpressiveSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: value,
      label: value ? 'Alarm on' : 'Alarm off',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        // The switch's own visual size (56x32) sits under WCAG 2.5.5's
        // 48x48 tap-target minimum, and it's the primary control for
        // enabling/disabling an alarm. `SizedBox` extends the opaque hit
        // area to 48 tall while keeping the visual pill the same size,
        // centered inside it.
        child: SizedBox(
          width: 56,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: MotionTokens.fastEffects,
              curve: MotionTokens.effectsCurve,
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: value ? scheme.primary : scheme.surfaceContainerHigh,
                border: Border.all(
                  color: value ? scheme.primary : scheme.outline,
                  width: 2,
                ),
              ),
              child: AnimatedAlign(
                duration: MotionTokens.fastSpatial,
                curve: MotionTokens.spatialCurve,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: MotionTokens.fastSpatial,
                    curve: MotionTokens.spatialCurve,
                    width: value ? 24 : 18,
                    height: value ? 24 : 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? scheme.onPrimary : scheme.outline,
                    ),
                    child: value
                        ? Icon(Icons.check, size: 15, color: scheme.primary)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-item corner radius for the handoff's "grouped container" list
/// pattern: 3dp gaps between items, large outer corners on the first/last
/// item, small corners everywhere else (touching edges).
BorderRadius groupedItemRadius({
  required int index,
  required int count,
  double outer = 24, // ShapeTokens.r24
  double inner = 8, // ShapeTokens.r8
}) {
  final top = index == 0 ? outer : inner;
  final bottom = index == count - 1 ? outer : inner;
  return BorderRadius.vertical(
    top: Radius.circular(top),
    bottom: Radius.circular(bottom),
  );
}

/// A single tile in a connected stat-row (streak/area/rank on Home, the
/// captured-area chip, Squad rank, Profile stats) — repeats across the
/// handoff's screens as `flex:1` colored blocks with an optional icon,
/// a big tabular-numeral value, and a small label underneath.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.bg,
    required this.fg,
    required this.value,
    required this.label,
    this.icon,
    this.radius = ShapeTokens.r8,
    this.hasError = false,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    super.key,
  });

  final Color bg;
  final Color fg;
  final String value;
  final String label;
  final IconData? icon;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;

  /// Set when the stream backing [value] emitted an error — without this,
  /// every stat tile on Home/Profile fell back to `?? 0`, which renders
  /// identically to a genuine zero (a real "you haven't started yet" state)
  /// and silently hides a failed fetch. When true, an error glyph replaces
  /// [value] and [icon] and the tile tints toward `errorContainer` instead
  /// of masking the failure.
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveBg = hasError ? scheme.errorContainer : bg;
    final effectiveFg = hasError ? scheme.onErrorContainer : fg;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: radius,
        border: Border.all(
          color: hasError
              ? scheme.error
              : scheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasError)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 20, color: effectiveFg),
              )
            else if (icon != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveFg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: effectiveFg),
              ),
            if (icon != null || hasError) const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasError ? '—' : value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: effectiveFg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasError ? "Couldn't load" : label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: effectiveFg.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
