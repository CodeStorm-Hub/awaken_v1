# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Awaken: a gamified alarm + fitness app (Flutter) targeting **Android and iOS**. Alarms can only
be dismissed by performing camera-verified exercises; outdoor runs that close a geographic loop
capture "territory" on a shared map, with squads/leaderboards.

**Scope note (updated 2026-07-22, supersedes the refined plan §8 / original dev-plan
"Android-only"):** the refined plan and its risk register were written Android-first, and this
doc previously said iOS was explicitly out of scope. The project has since been retargeted to
both platforms — `ios/` already has real prep (Info.plist usage strings, ML Kit-pinned Podfile
deployment target) predating this note, and Android remains the more mature/tested platform.
When touching platform-specific code, check both `android/` and `ios/`, and don't assume an
Android-only pattern (MethodChannels, foreground services, image formats) transfers to iOS
without verification — several real gaps were found and partly fixed in the 2026-07-22 Phase 6
session (see below): `SystemCapabilities`' MethodChannel has no iOS implementation (now
platform-gated rather than crashing), pose detection was feeding ML Kit an Android-only image
format on both platforms (fixed), and `flutter_foreground_task`'s run-tracking approach doesn't
carry over to iOS as-is (still open — iOS needs its own code path via `geolocator`'s background
location support, not flutter_foreground_task).

**Read `awaken_app_refined_plan.md` before making architectural changes.** It is the authoritative
build plan — corrected package versions, the phased roadmap (§6, with per-phase exit criteria),
the risk register (§7), and the rationale behind every non-obvious decision below. The other two
root-level docs (`awaken_app_development_plan.md`, `awaken_app_ui_ux_plan.md`) are superseded
background context; don't treat them as current. `docs/decisions.md` has short ADRs for the two
"decide once" calls (BLoC over Riverpod, hand-rolled outbox over PowerSync).

## Commands

```bash
# Setup (first time / after pulling)
cp .env.client.example .env.client   # fill in Supabase URL + publishable key
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerates injection.config.dart, drift tables

# Everyday
flutter analyze
flutter test                                   # all tests
flutter test test/features/alarm/alarm_list_page_test.dart   # single file
flutter run --flavor dev -t lib/main_dev.dart  # dev flavor (only flavor with a live backend today)
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

`--flavor` and `-t lib/main_dev.dart` (or `main_prod.dart`) are **required** together — the app
has no un-flavored entrypoint; `lib/main.dart` just forwards to `main_dev.dart` as a convenience
for tools that don't pass `--flavor`. Whenever you add/change an `@injectable`, `@lazySingleton`,
or Drift table, rerun the `build_runner build` command above — nothing will resolve without it.

CI (`.github/workflows/ci.yaml`) runs analyze/test/build on every push/PR, plus a best-effort
16KB-page-size emulator smoke job (`continue-on-error`, don't treat its failures as blocking).
`.github/workflows/build_ios.yml` builds the iOS target but is manually triggered, not run
automatically on push/PR.

### Windows-specific build workaround

`android/gradle.properties` sets `kotlin.incremental=false`. Kotlin's build-tools-api incremental
compiler intermittently fails to close its on-disk caches under `build\<module>\...` on this
machine (file-lock/AV interference), breaking `compileDebugKotlin` for several plugins. Don't
remove this without confirming the underlying Gradle/Kotlin bug is fixed — safe to re-enable on
Linux CI runners if it matters there.

## Architecture

**Feature-First Clean Architecture.** Each feature under `lib/features/<name>/` has its own
`presentation/ → domain/ → data/` stack:

- `domain/` — entities, repository *interfaces*, use cases. Zero Flutter imports. Use cases
  implement `core/usecase/usecase.dart`'s `UseCase<ReturnType, Params>` (stream-returning
  operations skip that interface and just expose a plain `call()`, e.g. `WatchAlarms`).
- `data/` — repository implementations (`@LazySingleton(as: XRepository)`), datasources wrapping
  third-party SDKs/plugins, DTOs/mappers. Presentation never touches a plugin (Supabase, the
  `alarm` package, etc.) directly — always through a domain repository interface.
- `presentation/` — `bloc/` (Cubit/Bloc per ADR-001), `pages/`, `widgets/`.

`lib/core/` holds cross-cutting concerns: `di/` (get_it + injectable — `injection.config.dart` is
**generated**, don't hand-edit it), `theme/` (hand-rolled M3-Expressive-style motion/shape tokens
— core Flutter does not ship M3 Expressive, see refined plan C2), `platform/` (native
MethodChannel wrappers), `error/` (`Failure` hierarchy), `usecase/`, `constants/`, `config/`
(env loading), `router/`, `utils/`.

`lib/sync/` holds the offline-first Drift schema + outbox engine (Phase 3, implemented per
ADR-002): `local/database.dart` (Drift schema + DAOs), `outbox/local_writer.dart` +
`sync_worker.dart` (transactional enqueue, connectivity-triggered drain, backoff),
`pull/pull_down_sync.dart`, and `connectivity/connectivity_watcher.dart`. Every feature writes
through the shared `LocalWriter`, never touches Supabase directly for user data.

### DI pattern

`get_it` + `injectable`, code-generated. Third-party singletons that injectable can't construct
itself (e.g. `SupabaseClient`) are bound via `@module` classes — see
`core/di/register_module.dart`. Order matters in `main_common.dart`'s `bootstrap()`:
`Env.load()` → `Supabase.initialize()` → `configureDependencies()` → then anything that reads
`getIt<SupabaseClient>()`.

### Build flavors

Android product flavors `dev`/`prod` (`android/app/build.gradle.kts`) pair with Dart entrypoints
`lib/main_dev.dart` / `lib/main_prod.dart`, both delegating to `lib/main_common.dart`'s shared
`bootstrap({required String envFile})`. Only `.env.client` exists today (one Supabase project,
`awaken-dev`); `main_prod.dart` currently points at the same file with a TODO for when a separate
prod project exists.

### Environment files — two, deliberately not merged

- **`.env.client`** — bundled into the app binary as a Flutter asset (`pubspec.yaml` → `assets:`).
  Only ever put client-safe values here (Supabase URL + publishable key, Google OAuth client
  IDs) — anything here ships inside the APK.
- **`.env`** — tooling-only (Supabase management-API PAT for MCP/CLI use). Never referenced by
  app code, never added to `pubspec.yaml` assets.

Both are gitignored; `.env.client.example` / `.env.example` document the expected shape.

### The alarm feature (`features/alarm/`) — read before touching alarm code

This is the highest-risk part of the app (plan §6 Phase 1 exit criterion: must survive a
force-kill + 30 min screen-off on real OEM hardware). Two non-obvious things:

1. `AlarmSettings.androidStopAlarmOnTermination` **must** be `false`
   (`alarm_repository_impl.dart`) — the `alarm` package's own default (`true`) stops the alarm
   the instant the user swipes the app from recents, defeating the entire feature.
2. The ring screen (`AlarmRingPage`) is shown via a `MaterialApp.builder` overlay in `app.dart`,
   **not** as the root route's conditional widget. It must always take over regardless of how
   deep the user has navigated — this was empirically wrong once (only showed from the root
   route) and was fixed by moving the switch into `builder`. Don't regress this by moving ring
   logic back into a single route's widget tree.

Also load-bearing: `Permission.notification.request()` in `main_common.dart`'s `bootstrap()`.
Android 13+ silently blocks *all* notifications — including the alarm's full-screen-intent one —
until this is granted at runtime; declaring `POST_NOTIFICATIONS` in the manifest alone does
nothing. This was found by live device/emulator testing, not static analysis — if you touch the
alarm flow, verify by actually running it (lock the screen, wait for the alarm), not just
`flutter analyze`.

Native Android side (`android/app/src/main/kotlin/.../MainActivity.kt`) exposes a
`com.awaken.awaken/system_capabilities` MethodChannel (wrapped by
`core/platform/system_capabilities.dart`) for FSI/exact-alarm capability checks and best-effort
OEM autostart deep links, plus sets the lock-screen-bypass window flags
(`setShowWhenLocked`/`setTurnScreenOn`/`requestDismissKeyguard`/`FLAG_KEEP_SCREEN_ON`).

### Manifest permissions

`ACCESS_BACKGROUND_LOCATION` is deliberately **not** declared — run tracking is always
foreground-initiated with a while-in-use location foreground service (plan H3), avoiding Play's
harshest background-location review tier. Don't add it without re-reading H3 first.

### Supabase backend

Project `awaken-dev` (`ap-southeast-1`, free tier, Postgres 17 + PostGIS). Tables: `profiles`,
`alarms`, `sessions`, `runs`, `territories` — all RLS-scoped to `auth.uid()`. `territories` is
public-read but has **no client INSERT/UPDATE policy** — it's mutated only through the
`submit_run()` `SECURITY DEFINER` RPC, which implements the server-authoritative territory
pipeline (validate closure/length → polygonize via `ST_MakeValid` → `ST_Difference` against rival
territories → `ST_Union` into the capturing user's territory). Never add a client-writable policy
on `territories`; new territory logic belongs in that RPC (or a new one), not client code. Area
math throughout casts to `::geography` (SRID 4326 geometry alone gives square degrees, not m² —
plan C4).
