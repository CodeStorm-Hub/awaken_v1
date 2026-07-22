import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the one-time "has seen the onboarding carousel" flag —
/// previously there was no onboarding domain/data layer at all, so
/// `_StartupFlow` in `app.dart` always defaulted to showing onboarding on
/// every cold start.
@lazySingleton
class OnboardingLocalDataSource {
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
