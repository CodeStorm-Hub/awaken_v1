import 'package:flutter/material.dart';

/// Shared M3-Expressive-style building blocks used across the redesigned
/// alarm/verification/onboarding screens (see the "Awaken Flutter Mobile
/// App" Claude Design handoff, `m3x.css`). Core Flutter ships none of this
/// — same rationale as `motion_tokens.dart`/`shape_tokens.dart`.

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
    super.key,
  });

  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                child: Container(
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
    if (!animatePop) return blob;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
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
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
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
    );
  }
}

/// Per-item corner radius for the handoff's "grouped container" list
/// pattern: 3dp gaps between items, large outer corners on the first/last
/// item, small corners everywhere else (touching edges).
BorderRadius groupedItemRadius({
  required int index,
  required int count,
  double outer = 24,
  double inner = 8,
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
    this.radius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });

  final Color bg;
  final Color fg;
  final String value;
  final String label;
  final IconData? icon;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    // Flat, no elevation — the handoff's own CSS for these tiles has no
    // box-shadow. Elevation here previously cast a drop shadow into the
    // 3px gap between adjacent tiles, reading as a stray colored seam.
    return Material(
      color: bg,
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 22, color: fg),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
