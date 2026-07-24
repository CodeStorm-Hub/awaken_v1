import 'package:flutter/widgets.dart';

/// M3 Expressive-inspired corner-radius scale (see UI/UX plan §"Shape
/// Morphing"). Sharp variants are reserved for high-stakes warnings such as
/// the Wake-Up Tax visualizer, deliberately breaking the rounded rhythm.
///
/// **2026-07-23 audit finding**: this file was never actually referenced
/// from `lib/features/` — every screen used its own inline
/// `BorderRadius.circular(N)` literals, and those literals had organically
/// settled on a *different* scale (12/16/18/20/24/28/32, plus 999 for
/// pills) than what this file originally declared (4/8/12/16/28/48). Rather
/// than force dozens of call sites onto the old scale (a large, purely
/// cosmetic, non-trivial-to-verify refactor for zero visual change), this
/// file's scale has been corrected to match what's actually in use, so it
/// now documents reality instead of an aspiration nothing consumed. Wiring
/// real call sites to reference these constants (instead of repeating the
/// literal) is worth doing incrementally, screen by screen, rather than as
/// one large mechanical sweep — flagging here rather than doing it blind.
abstract final class ShapeTokens {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius mediumLarge = BorderRadius.all(Radius.circular(16));
  static const BorderRadius large = BorderRadius.all(Radius.circular(18));
  static const BorderRadius largeExtra = BorderRadius.all(Radius.circular(20));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(24));
  static const BorderRadius extraLargeExtra = BorderRadius.all(Radius.circular(28));
  static const BorderRadius extraExtraLarge = BorderRadius.all(Radius.circular(32));

  /// Fully-rounded pill shape — by far the most common radius in the
  /// codebase (buttons, chips, switches), previously written as the magic
  /// number `999` at every call site.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Sharp-cornered container for high-stakes warnings (e.g. the "Wake-Up
  /// Tax" penalty card) — intentional visual tension against the otherwise
  /// rounded interface.
  static const BorderRadius sharpWarning = BorderRadius.all(Radius.zero);
}
