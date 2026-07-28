import 'package:flutter/material.dart';

/// Domain-specific color roles Material 3's [ColorScheme] doesn't cover
/// (it only ships an `error` role). Every one of these previously existed
/// as a hardcoded hex literal duplicated across feature files — territory
/// ownership colors defined once in the map legend and again, slightly
/// differently, in the fill-redraw logic; streak/bounty/warning colors
/// repeated per screen with no shared source of truth. Centralizing them
/// here means a single edit updates every consumer, and each role gets a
/// brightness-tuned value instead of one hex reused unchanged in both
/// themes (see `AppTheme.light`/`AppTheme.dark`, which registers both
/// constructors as a [ThemeExtension]).
///
/// Usage: `Theme.of(context).extension<AppSemanticColors>()!.territoryRival`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.territoryOwned,
    required this.territoryOwnedFill,
    required this.territoryRival,
    required this.territoryRivalFill,
    required this.territoryNeutral,
    required this.territoryAtRisk,
    required this.bountyGold,
    required this.bountyGoldContainer,
    required this.streakFlame,
    required this.gpsGood,
    required this.gpsWeak,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.success,
    required this.successContainer,
  });

  /// Outline/legend color for territory the current user owns.
  final Color territoryOwned;

  /// Fill color for the user's own territory polygons on the map
  /// (composited at reduced opacity at the call site, not baked in here,
  /// so map-style JSON and the Dart legend can share one alpha policy).
  final Color territoryOwnedFill;

  /// Outline/legend color for a rival's territory.
  final Color territoryRival;

  /// Fill color for rival territory polygons.
  final Color territoryRivalFill;

  /// Unclaimed, runnable ground near the user — distinct from both owned
  /// and rival so the map reads as "capturable," not empty space.
  final Color territoryNeutral;

  /// Pulsing-border color for territory below the contested-health
  /// threshold (`territories.health < 30`) or actively being contested.
  final Color territoryAtRisk;

  /// Bounty-zone ring/badge color — kept distinct from `streakFlame` even
  /// though both read as "warm accent," since they appear together on the
  /// capture sheet and need to stay individually identifiable.
  final Color bountyGold;
  final Color bountyGoldContainer;

  /// Home's streak-flame stat tile.
  final Color streakFlame;

  /// GPS-quality chip on the active-run screen. Paired with distinct
  /// iconography at the call site (not color alone) for colorblind users.
  final Color gpsGood;
  final Color gpsWeak;

  /// Non-error warning role (battery-exemption denial, wake-up-tax
  /// escalation) — visually distinct from `ColorScheme.error`, which is
  /// reserved for destructive/failure states.
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Positive/success confirmation role (capture success, sync recovered).
  final Color success;
  final Color successContainer;

  static const AppSemanticColors light = AppSemanticColors(
    territoryOwned: Color(0xFF0E9488),
    territoryOwnedFill: Color(0xFF0E9488),
    territoryRival: Color(0xFFD92D3C),
    territoryRivalFill: Color(0xFFD92D3C),
    territoryNeutral: Color(0xFF8A8F99),
    territoryAtRisk: Color(0xFFB26B00),
    bountyGold: Color(0xFFA67C00),
    bountyGoldContainer: Color(0xFFFBF0D2),
    streakFlame: Color(0xFFFF5D3A),
    gpsGood: Color(0xFF0E9488),
    gpsWeak: Color(0xFFB26B00),
    warning: Color(0xFFB26B00),
    warningContainer: Color(0xFFFBEBD1),
    onWarningContainer: Color(0xFF3D2900),
    success: Color(0xFF0E9488),
    successContainer: Color(0xFFDDF3EF),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    territoryOwned: Color(0xFF3FD9C7),
    territoryOwnedFill: Color(0xFF3FD9C7),
    territoryRival: Color(0xFFFF6B7A),
    territoryRivalFill: Color(0xFFFF6B7A),
    territoryNeutral: Color(0xFF6E7280),
    territoryAtRisk: Color(0xFFF0B33D),
    bountyGold: Color(0xFFF0C94A),
    bountyGoldContainer: Color(0xFF332B10),
    streakFlame: Color(0xFFFF7A57),
    gpsGood: Color(0xFF3FD9C7),
    gpsWeak: Color(0xFFF0B33D),
    warning: Color(0xFFF0B33D),
    warningContainer: Color(0xFF3A2E13),
    onWarningContainer: Color(0xFFFDE5B8),
    success: Color(0xFF3FD9C7),
    successContainer: Color(0xFF16332F),
  );

  @override
  AppSemanticColors copyWith({
    Color? territoryOwned,
    Color? territoryOwnedFill,
    Color? territoryRival,
    Color? territoryRivalFill,
    Color? territoryNeutral,
    Color? territoryAtRisk,
    Color? bountyGold,
    Color? bountyGoldContainer,
    Color? streakFlame,
    Color? gpsGood,
    Color? gpsWeak,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? success,
    Color? successContainer,
  }) {
    return AppSemanticColors(
      territoryOwned: territoryOwned ?? this.territoryOwned,
      territoryOwnedFill: territoryOwnedFill ?? this.territoryOwnedFill,
      territoryRival: territoryRival ?? this.territoryRival,
      territoryRivalFill: territoryRivalFill ?? this.territoryRivalFill,
      territoryNeutral: territoryNeutral ?? this.territoryNeutral,
      territoryAtRisk: territoryAtRisk ?? this.territoryAtRisk,
      bountyGold: bountyGold ?? this.bountyGold,
      bountyGoldContainer: bountyGoldContainer ?? this.bountyGoldContainer,
      streakFlame: streakFlame ?? this.streakFlame,
      gpsGood: gpsGood ?? this.gpsGood,
      gpsWeak: gpsWeak ?? this.gpsWeak,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      territoryOwned: Color.lerp(territoryOwned, other.territoryOwned, t)!,
      territoryOwnedFill:
          Color.lerp(territoryOwnedFill, other.territoryOwnedFill, t)!,
      territoryRival: Color.lerp(territoryRival, other.territoryRival, t)!,
      territoryRivalFill:
          Color.lerp(territoryRivalFill, other.territoryRivalFill, t)!,
      territoryNeutral:
          Color.lerp(territoryNeutral, other.territoryNeutral, t)!,
      territoryAtRisk: Color.lerp(territoryAtRisk, other.territoryAtRisk, t)!,
      bountyGold: Color.lerp(bountyGold, other.bountyGold, t)!,
      bountyGoldContainer:
          Color.lerp(bountyGoldContainer, other.bountyGoldContainer, t)!,
      streakFlame: Color.lerp(streakFlame, other.streakFlame, t)!,
      gpsGood: Color.lerp(gpsGood, other.gpsGood, t)!,
      gpsWeak: Color.lerp(gpsWeak, other.gpsWeak, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
    );
  }
}

/// Shorthand accessor — `context.semanticColors.territoryRival` instead of
/// the verbose `Theme.of(context).extension<AppSemanticColors>()!` at every
/// call site. The `!` is safe: both `AppTheme.light`/`.dark` always
/// register the extension, so it's only null if a screen builds its own
/// bare `ThemeData` outside `AppTheme` (not done anywhere in this app).
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
