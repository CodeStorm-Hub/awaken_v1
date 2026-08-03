# Tech Debt Audit — awaken_v1

Sources: `lib/` scan, `android/`+`ios/` scan, Supabase advisors (`qxxkydisyqnodskmymla`), `flutter pub outdated`, `flutter analyze` (clean, 0 issues).

### P0 — Block before any real release (fix first, effort low, risk severe)

1. **Release APK signed with debug keystore.** [android/app/build.gradle.kts:52](android/app/build.gradle.kts:52), TODO at line 50. Priority score ~50 (impact 5, risk 5, effort 1). Can't publish to Play Store as-is — anyone can resign/tamper an APK built this way. Fix: generate real upload keystore, wire `signingConfigs.release`.
2. **`main_prod.dart` points at `awaken-dev` Supabase project**, not a separate prod project. [lib/main_prod.dart:5](lib/main_prod.dart:5). Score ~40. Real risk of prod traffic hitting dev DB (the 35-row/25-row dev dataset you just saw). Fix: stand up prod Supabase project + `.env.client` before any prod build ships.
3. **Leaked password protection disabled** (Supabase Auth advisor, WARN). Score ~30. One dashboard toggle — HaveIBeenPwned check currently off.
4. **iOS `Info.plist` declares unused background modes** — `location`/`audio`/`fetch` in `UIBackgroundModes` plus a `BGTaskSchedulerPermittedIdentifiers` entry for `flutter_foreground_task` (iOS-unsupported per CLAUDE.md), with no `AppDelegate` handler behind any of them. Score ~25. App Store review flags declared-but-unused background modes — strip until iOS background-location path actually exists.

### P1 — Next sprint (real bugs, hidden failure paths)

5. **Silent `catch (_) {}` swallowing with no telemetry**, squad + territory repos: [squad_repository_impl.dart:111,204,364](lib/features/squad/data/repositories/squad_repository_impl.dart:111), [run_tracking_repository_impl.dart:159,289,303,312](lib/features/territory/data/repositories/run_tracking_repository_impl.dart:159). Score ~28. Checkpoint writes / presence fetch / leaderboard fetch can fail 100% of the time in prod with zero Sentry signal — `alarm_repository_impl.dart:331` already does this right (logs to Sentry), squad/territory don't. Fix: route through same Sentry-logging pattern.
6. **Zero test coverage for `lib/features/squad/*`** (CLAUDE.md already flags this). Score ~24, compounds finding 5 — untested code + swallowed errors = regressions ship invisibly. Fix: repository + presentation tests minimum before touching squad code further.
7. **ProGuard missing `-keep` for `flutter_foreground_task`/geolocator reflectively-invoked classes.** [android/app/proguard-rules.pro](android/app/proguard-rules.pro). Score ~24. File's own comment admits untested by real release build — R8 could strip classes needed at runtime, crash only in release builds.
8. **AGP 9.0.1 / Kotlin 2.3.20** — bleeding-edge, landed right at the iOS-retarget date. [android/settings.gradle.kts:19-20](android/settings.gradle.kts:19). Score ~20. Confirm intentional pin vs accidental pre-release adoption — hard-to-diagnose build breakage risk.
9. **`alarm_reliability_test_page.dart` (286 lines) shipped in production widget tree**, not gated behind debug flag. [lib/features/alarm/presentation/pages/alarm_reliability_test_page.dart](lib/features/alarm/presentation/pages/alarm_reliability_test_page.dart). Score ~20. Dev QA tool bundled into shipped app.

### P2 — Architecture/maintainability (schedule alongside feature work)

10. **God-files + inconsistent state management**: `territory_page.dart` 2768 lines (9 `setState()` calls in a Bloc-based app), `squad_page.dart` 1577, `alarm_list_page.dart` 1277, `active_run_page.dart` 1250, `profile_page.dart` 1139 (uses `ChangeNotifier` — only ChangeNotifier usage in an otherwise Cubit app). Score ~14-24 each. Hardest files to test/onboard into; the state-management inconsistency specifically (setState/ChangeNotifier vs the ADR-001 Bloc standard) is worth flagging as a real deviation, not just size.
11. **Root `build.gradle.kts` force-overrides `compileSdk = 36`** for all plugin subprojects via `afterEvaluate`. [android/build.gradle.kts:8-24](android/build.gradle.kts:8). Score ~16. Blunt — could mask real plugin incompatibility if one genuinely needs a lower compileSdk.
12. **Thin/smoke-only tests** for profile, onboarding, home, shell (one narrow file each, no domain/usecase coverage) — auth flows (`sign_in_with_google`, `link_with_email`, `delete_account`) unverified. Score ~12.
13. **Outdated deps with resolvable majors**: `connectivity_plus` 6.1.5→7.3.1, `get_it` 8.3.0→9.2.1, `google_fonts` 6.3.3→8.2.0, `injectable` 2.7.1→3.0.0, `patrol` 3.20→4.8.0. Score ~12. None urgent (analyze clean, no CVEs surfaced), but drift grows compounding-upgrade pain.
14. **`sqlite3_flutter_libs` latest upstream release is tagged `+eol`** (0.6.0+eol) — worth checking upstream package status/replacement path before the current 0.5.42 pin becomes unmaintained.

### P3 — Low, opportunistic

15. Unused Postgres indexes (`bounty_zones_center_gix`, `runs_user_id_idx`, `runs_path_gix`, `profiles_squad_id_idx`, `sessions_user_id_idx`, `sessions_alarm_id_idx`, 3 more on `squad_reports`/`squads`) — harmless now (low row counts), revisit once real traffic exists.
16. Magic numbers/timeouts scattered inline (`squad_repository_impl.dart:109,202`) instead of centralized in `app_constants.dart` (only 12 constants today).
17. `core/theme/expressive_widgets.dart` (611 lines) and `territory_map_style.dart` (763 lines) approaching god-file size — watch, not yet urgent.
18. Stale cross-file TODO: [verification_page.dart:20](lib/features/verification/presentation/pages/verification_page.dart:20) references a "TODO in alarm_ring_page.dart" for a Phase 4 dismiss button that doesn't exist there — planning drifted into code comments, re-sync with actual backlog.

### Not debt (confirmed clean / accepted-by-design)

- `flutter analyze`: 0 issues.
- No `print()`/`debugPrint()` leftovers, no stray `@Deprecated` usage in `lib/`.
- SECURITY DEFINER RPCs flagged by Supabase advisor (`bump_wake_up_tax`, `create_squad`, `submit_run`, leaderboards, etc.) — per CLAUDE.md these are intentionally `EXECUTE`-granted to `authenticated`, not a regression.
- Anonymous-access RLS warnings — expected, anonymous sessions are first-class users here.
- `GoogleService-Info.plist` API key in plaintext — normal for Firebase iOS (bundle-ID restricted), just confirm API restrictions are set server-side.
- Podfile/`IPHONEOS_DEPLOYMENT_TARGET` in sync at 15.5, matches ML Kit requirement — no drift.
- `android/gradle.properties` `kotlin.incremental=false` — intentional Windows workaround per CLAUDE.md, not debt.

### Phased remediation plan

- **Phase 0 (before next release build, ~1-2 days):** items 1-4. Blocking or App-Store-review-risk items, all cheap fixes.
- **Phase 1 (this sprint, alongside feature work):** items 5-9. Fix swallowed-error logging while touching squad/territory anyway; add squad tests before further squad changes; verify ProGuard with an actual release build.
- **Phase 2 (next 1-2 sprints):** items 10-14. Break up god-files incrementally as each gets touched for feature work rather than a dedicated rewrite sprint; bump safe-looking deps (`get_it`, `google_fonts`) opportunistically.
- **Phase 3 (ongoing/opportunistic):** items 15-18.