import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds light/dark [ThemeData] from a seed or dynamic [ColorScheme].
/// Dynamic color (Material You) is wired up in `main.dart` via
/// `dynamic_color`'s `DynamicColorBuilder`; this factory just consumes
/// whatever scheme it's handed so it works identically with the fallback
/// seed color when the platform doesn't expose one.
abstract final class AppTheme {
  static const Color fallbackSeed = Color(0xFF0A84FF); // iOS Electric System Blue

  // Authentic Glossy iOS Dark Mode & Dark Map visual tokens
  static const Color darkCanvas = Color(0xFF16161A); // Deep Glossy Obsidian Dark Map canvas
  static const Color darkSurface = Color(0xFF222228); // iOS Dark Surface / Secondary Container
  static const Color darkCardContainer = Color(0xFF222228); // Glossy Dark Grouped Inset Container
  static const Color darkCardContainerHigh = Color(0xFF2E2E36); // Glossy Dark Inset Row Fill
  static const Color darkBorderOutline = Color(0xFF383842); // Subtle iOS 0.5px glass separator

  static ThemeData light(ColorScheme? dynamicScheme) {
    final baseScheme = dynamicScheme?.harmonized() ??
        ColorScheme.fromSeed(
          seedColor: fallbackSeed,
          brightness: Brightness.light,
        );

    final customLightScheme = baseScheme.copyWith(
      surface: const Color(0xFFF2F2F7), // iOS System Grouped Background
      surfaceContainer: const Color(0xFFFFFFFF), // iOS Secondary Grouped Background (Cards)
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerHigh: const Color(0xFFE5E5EA), // iOS Tertiary Grouped Fill (Insets)
      surfaceContainerHighest: const Color(0xFFE5E5EA),
      onSurface: const Color(0xFF000000), // iOS System Label
      onSurfaceVariant: const Color(0xFF3C3C43).withValues(alpha: 0.6), // iOS Secondary Label
      outline: const Color(0xFFC6C6C8), // iOS 0.5px Separator
      outlineVariant: const Color(0xFFE5E5EA),
      primary: const Color(0xFF007AFF), // iOS System Blue
      onPrimary: Colors.white,
      secondary: const Color(0xFF5856D6), // iOS System Purple
      secondaryContainer: const Color(0xFFE5E5EA),
      onSecondaryContainer: const Color(0xFF000000),
    );

    return _build(customLightScheme);
  }

  static ThemeData dark(ColorScheme? dynamicScheme) {
    final baseScheme = dynamicScheme?.harmonized() ??
        ColorScheme.fromSeed(
          seedColor: fallbackSeed,
          brightness: Brightness.dark,
        );

    // Custom dark scheme tailored to authentic iOS Dark Mode & Map Dark Theme
    final customDarkScheme = baseScheme.copyWith(
      surface: darkCanvas,
      surfaceContainer: darkCardContainer,
      surfaceContainerLow: darkCardContainer,
      surfaceContainerLowest: darkCardContainer,
      surfaceContainerHigh: darkCardContainerHigh,
      surfaceContainerHighest: darkCardContainerHigh,
      onSurface: const Color(0xFFFFFFFF),
      onSurfaceVariant: const Color(0xFFEBEBF5).withValues(alpha: 0.6),
      outline: darkBorderOutline,
      primary: const Color(0xFF0A84FF),
      onPrimary: Colors.white,
    );

    return _build(customDarkScheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: scheme.brightness);
    final isDark = scheme.brightness == Brightness.dark;

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        textStyle: base.textTheme.displayLarge?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
      ),
      displayMedium: GoogleFonts.inter(
        textStyle: base.textTheme.displayMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      headlineMedium: GoogleFonts.inter(
        textStyle: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? darkCanvas : scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkCanvas : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: scheme.onSurface,
          size: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkCardContainer : scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? darkBorderOutline : scheme.outline,
            width: 0.5,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkSurface : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkSurface : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
