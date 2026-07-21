import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Builds light/dark [ThemeData] from a seed or dynamic [ColorScheme].
/// Dynamic color (Material You) is wired up in `main.dart` via
/// `dynamic_color`'s `DynamicColorBuilder`; this factory just consumes
/// whatever scheme it's handed so it works identically with the fallback
/// seed color when the platform doesn't expose one.
abstract final class AppTheme {
  static const Color fallbackSeed = Color(0xFF2E7D32); // brand green

  static ThemeData light(ColorScheme? dynamicScheme) {
    return _build(
      dynamicScheme?.harmonized() ??
          ColorScheme.fromSeed(
            seedColor: fallbackSeed,
            brightness: Brightness.light,
          ),
    );
  }

  static ThemeData dark(ColorScheme? dynamicScheme) {
    return _build(
      dynamicScheme?.harmonized() ??
          ColorScheme.fromSeed(
            seedColor: fallbackSeed,
            brightness: Brightness.dark,
          ),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
    );
  }
}
