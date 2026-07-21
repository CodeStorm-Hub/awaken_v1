import 'package:flutter/widgets.dart';

/// M3 Expressive-inspired corner-radius scale (see UI/UX plan §"Shape
/// Morphing"). Sharp variants are reserved for high-stakes warnings such as
/// the Wake-Up Tax visualizer, deliberately breaking the rounded rhythm.
abstract final class ShapeTokens {
  static const BorderRadius extraSmall = BorderRadius.all(Radius.circular(4));
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(28));
  static const BorderRadius extraExtraLarge =
      BorderRadius.all(Radius.circular(48));

  /// Sharp-cornered container for high-stakes warnings (e.g. the "Wake-Up
  /// Tax" penalty card) — intentional visual tension against the otherwise
  /// rounded interface.
  static const BorderRadius sharpWarning = BorderRadius.all(Radius.zero);
}
