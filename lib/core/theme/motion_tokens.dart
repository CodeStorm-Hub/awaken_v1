import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// M3 Expressive-inspired spring physics, hand-implemented because core
/// Flutter does not ship M3 Expressive (see awaken_app_refined_plan.md C2).
/// Damping-ratio / stiffness pairs are taken from the UI/UX plan's Table 2
/// and converted to `SpringDescription`'s absolute damping coefficient via
/// `c = zeta * 2 * sqrt(mass * stiffness)`.
abstract final class MotionTokens {
  static SpringDescription _spring({
    required double dampingRatio,
    required double stiffness,
  }) {
    const mass = 1.0;
    final criticalDamping = 2 * math.sqrt(mass * stiffness);
    return SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: dampingRatio * criticalDamping,
    );
  }

  /// Significant bounce, rapid resolution (~350ms). Attention-grabbing
  /// layout changes: expanding config cards, morphing high-priority shapes.
  static final SpringDescription expressiveFastSpatial =
      _spring(dampingRatio: 0.42, stiffness: 1670);

  /// Moderate bounce, standard resolution (~500ms). Page transitions,
  /// sliding panels, standard interactive gestures.
  static final SpringDescription expressiveDefaultSpatial =
      _spring(dampingRatio: 0.38, stiffness: 1210);

  /// Stiff, zero overshoot (~150ms). Micro-interactions: toggles, button
  /// presses, rapid color state changes.
  static final SpringDescription expressiveFastEffects =
      _spring(dampingRatio: 0.31, stiffness: 940);

  /// Low bounce, predictable resolution (~500ms). List scrolling,
  /// navigation-rail transitions, secondary structural animations.
  static final SpringDescription standardDefaultSpatial =
      _spring(dampingRatio: 0.27, stiffness: 1060);

  // `Duration`/`Curve` pairs for the (more common) `AnimatedContainer`-style
  // call sites that don't use a raw `SpringDescription`. Values mirror the
  // resolution times documented on the springs above so both animation
  // styles feel consistent, rather than each screen picking its own
  // duration ad hoc (the 2026-07-29 audit found 150/200/250/350/500ms all
  // in use for comparable interactions with no shared scale).

  /// Micro-interactions: toggles, button presses, color state changes.
  /// Pair with [effectsCurve].
  static const Duration fastEffects = Duration(milliseconds: 150);

  /// Attention-grabbing layout changes: expanding cards, badge pop-ins.
  /// Pair with [spatialCurve].
  static const Duration fastSpatial = Duration(milliseconds: 350);

  /// Page transitions, sliding panels, standard interactive gestures.
  /// Pair with [spatialCurve].
  static const Duration defaultSpatial = Duration(milliseconds: 500);

  static const Curve effectsCurve = Curves.easeOut;
  static const Curve spatialCurve = Curves.easeOutBack;
}
