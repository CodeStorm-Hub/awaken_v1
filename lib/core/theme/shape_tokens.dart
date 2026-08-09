import 'package:flutter/widgets.dart';

/// Corner-radius scale, wired to every real `BorderRadius.circular(N)` call
/// site in `lib/features` (2026-08-09 sweep — previously this file
/// documented a scale nothing actually referenced; see git history for that
/// note). Named by their radius value rather than a semantic tier
/// (small/medium/large) deliberately: the underlying values were never a
/// designed scale to begin with, just what organically emerged across
/// screens, so a numeric name is honest about that and unambiguous to grep.
/// Sharp variants are reserved for high-stakes warnings such as the
/// Wake-Up Tax visualizer, deliberately breaking the rounded rhythm.
abstract final class ShapeTokens {
  static const BorderRadius r2 = BorderRadius.all(Radius.circular(2));
  static const BorderRadius r4 = BorderRadius.all(Radius.circular(4));
  static const BorderRadius r8 = BorderRadius.all(Radius.circular(8));
  static const BorderRadius r10 = BorderRadius.all(Radius.circular(10));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius r14 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius r18 = BorderRadius.all(Radius.circular(18));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(20));
  static const BorderRadius r22 = BorderRadius.all(Radius.circular(22));
  static const BorderRadius r23 = BorderRadius.all(Radius.circular(23));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(24));
  static const BorderRadius r28 = BorderRadius.all(Radius.circular(28));
  static const BorderRadius r32 = BorderRadius.all(Radius.circular(32));

  /// Fully-rounded pill shape — by far the most common radius in the
  /// codebase (buttons, chips, switches), previously written as the magic
  /// number `999` at every call site.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Sharp-cornered container for high-stakes warnings (e.g. the "Wake-Up
  /// Tax" penalty card) — intentional visual tension against the otherwise
  /// rounded interface.
  static const BorderRadius sharpWarning = BorderRadius.all(Radius.zero);
}
