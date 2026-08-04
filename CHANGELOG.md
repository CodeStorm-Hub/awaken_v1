# Changelog

All notable changes to the **Awaken** project will be documented in this file.

## [0.1.0] - 2026-08-04

### Added
- **Core foundations (Phase 0):** Clean architecture structure, basic dependency injection (`get_it` and `injectable`), and centralized theme with Material 3 tokens.
- **Supabase integration:** Initial auth setup, user profiles, and sync schemas with Row-Level Security (RLS) policies.
- **Alarm management (Phase 1):** Scheduling, native exact alarms on Android (`USE_EXACT_ALARM`), exact wakeups, and locked screen bypass using full-screen intent.
- **Onboarding flows:** OEM battery exemption onboarding to prevent background app suspension.
- **Verification engine (Phase 2):** Real-time camera pose detection using Google ML Kit to dismiss alarms with exercises (squats/push-ups).
- **Compliance preparation:** Verified production build scripts, live Privacy Policy hosting, and Play Store pre-release compliance guidelines.
