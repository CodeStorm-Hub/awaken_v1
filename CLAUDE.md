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
carry over to iOS as-is — a real background-location code path via `geolocator` is still
unbuilt, but as of the 2026-08-07 modernization pass `RunForegroundService.start()`/`stop()`
(`features/territory/data/datasources/run_foreground_service.dart`) is now explicitly
`Platform.isAndroid`-gated rather than being called unconditionally into an iOS shim that did
nothing. `ios/Runner/Info.plist`'s Always-location usage strings and `UIBackgroundModes:
location` were also removed in that pass, since the app doesn't request background location on
either platform yet — re-add them only alongside the real iOS background-tracking feature.

**Read `docs/awaken_app_refined_plan.md` before making architectural changes.** It is the
authoritative build plan — corrected package versions, the phased roadmap (§6, with per-phase
exit criteria), the risk register (§7), and the rationale behind every non-obvious decision below.
(Moved from repo root into `docs/` on 2026-07-30 along with the other planning docs — update any
stale root-relative references you find.) The other two planning docs
(`docs/awaken_app_development_plan.md`, `docs/awaken_app_ui_ux_plan.md`) are superseded background
context; don't treat them as current. `docs/decisions.md` has short ADRs for the two "decide once"
calls (BLoC over Riverpod, hand-rolled outbox over PowerSync). `docs/` also now has
`SESSION_HARDENING_STATUS.md` (live checklist for the ongoing hardening pass) and several dated
QA/review docs — check there before assuming a root-level `.md` is current; several review/report
`.md` files still at repo root (`awaken_comprehensive_review.md`,
`awaken_screen_uiux_review.md`, etc.) are point-in-time snapshots, not living docs.

## Working efficiently in this repo (token budget)

- Never `Read` generated files to understand structure — `injection.config.dart` (DI wiring) and
  `**/*.g.dart` (Drift tables, JSON codecs) are derived from their source annotations. Read the
  `@injectable`/`@lazySingleton` class or the Drift `Table` class instead; regenerate with
  `dart run build_runner build` rather than hand-editing or reading the output to verify it.
- Prefer `Grep`/`Glob` over opening whole feature directories — the feature-first layout means a
  symbol's data/domain/presentation files usually share a name prefix, so a targeted grep beats
  scanning `lib/features/<name>/**`.
- Use the Dart MCP server's `hot_reload`/`get_runtime_errors`/`analyze_files` for iteration instead
  of full `flutter run`/`flutter build` cycles when checking a single change.
- When a task only touches one platform, don't read the other platform's native project
  (`android/` vs `ios/`) unless the change is genuinely cross-platform (MethodChannels, foreground
  services, image formats — see scope note above for known gaps).
- This CLAUDE.md documents only non-obvious, load-bearing decisions (gotchas found by live
  debugging, workarounds, "don't do X" warnings). Don't add anything re-derivable by reading the
  code — that's what makes it worth loading every session instead of wasting context.

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

**Resolved (2026-07-31):** `sqlite3_flutter_libs` was removed from `pubspec.yaml` — it was
deprecated (`0.6.0+eol` was its final, empty release), and native SQLite bundling for Android/iOS
moved into `sqlite3` itself as of its 3.x line (already resolved transitively at 3.5.0). Verified
on a real Android emulator (API 37): fresh install, onboarding, alarm create/list/delete, and a
full native alarm-ring trigger all worked with no crash and no `SQLiteException` in logcat. iOS
wasn't re-verified on this pass — check the Drift DB still opens there before shipping an iOS
build if this hasn't been done since.

### Windows-specific build workaround

`android/gradle.properties` sets `kotlin.incremental=false`. Kotlin's build-tools-api incremental
compiler intermittently fails to close its on-disk caches under `build\<module>\...` on this
machine (file-lock/AV interference), breaking `compileDebugKotlin` for several plugins. Don't
remove this without confirming the underlying Gradle/Kotlin bug is fixed — safe to re-enable on
Linux CI runners if it matters there.

Same class of issue can also corrupt `android/.gradle/<version>/executionHistory/executionHistory.bin`
directly (seen as `Could not read entry '...' from cache executionHistory.bin` failing
`compileReleaseJavaWithJavac` on an otherwise-correct build) — delete that
`executionHistory` directory and rebuild rather than debugging it as a real code/config problem.

AGP `9.0.1` / Kotlin `2.3.20` (`android/settings.gradle.kts`) — confirmed working 2026-07-30 via a
real `flutter build apk --release --flavor prod`; not an accidental pre-release pin.

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
`bootstrap({required String envFile})`. Only `.env.client` exists today, pointing at `awaken-dev` —
this is the **one and only** Supabase project, deliberately shared by dev and prod builds. Don't
treat `main_prod.dart` pointing at `.env.client` as a gap to fix; there is no separate prod project
planned.

### Environment files — two, deliberately not merged

- **`.env.client`** — bundled into the app binary as a Flutter asset (`pubspec.yaml` → `assets:`).
  Only ever put client-safe values here (Supabase URL + publishable key, Google OAuth client
  IDs) — anything here ships inside the APK.
- **`.env`** — tooling-only (Supabase management-API PAT for MCP/CLI use). Never referenced by
  app code, never added to `pubspec.yaml` assets.

`.env` is gitignored (real secret). **`.env.client` is deliberately force-tracked in git**
(`.gitignore` ignores `.env.*` then un-ignores `.env.client`/`.env.client.example`) — its
contents ship inside the APK anyway, so there's no confidentiality gained by keeping it out of
version control, and tracking it means `flutter pub get` on a fresh clone doesn't need a manual
copy step. Don't "fix" this by re-gitignoring `.env.client`; do keep the file's own contents to
genuinely client-safe values, since anything in it is public by construction.
`.env.client.example` / `.env.example` document the expected shape.

**Sentry DSN is currently unset.** `main_common.dart` wires up `Sentry.init` and several
repositories (`squad_repository_impl.dart`, `run_tracking_repository_impl.dart`, etc.) call
`Sentry.captureException`/`addBreadcrumb` on error paths so failures are visible in production —
but `.env.client`'s `SENTRY_DSN` is empty, so none of that currently reaches a real Sentry
project in a build cut from this checkout. Provision a Sentry project and set the DSN before
relying on this for production error visibility; don't assume errors are being reported anywhere
just because the logging code exists.

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

### Verification feature (`features/verification/`) — camera + ML Kit pose detection

- Rep counting (`rep_counter.dart`'s `AngleRepCounter`) is a hand-tuned angle-threshold state
  machine (squat: hip→knee→ankle crossing 100°/160°; push-up: shoulder→elbow→wrist crossing
  90°/160°), with confirm-frame counts and a cooldown to reject noise. It **locks to one side**
  (left/right) once a descent starts, so a user can't complete a rep by switching limbs mid-rep.
- Camera is always front-facing. Android requests NV21, iOS bgra8888, but iOS's
  `camera_platform_interface` doesn't reliably honor the request — `pose_mapper.dart` reads the
  frame's *actual* reported format rather than trusting what was requested.
- `CameraController` is exposed as a getter off the datasource — a deliberate, narrow exception
  to "presentation never touches a plugin directly," so `CameraPreview` has one seam instead of
  scattering `package:camera` imports.
- `VerificationCubit` is per-session (fresh per page open) with explicit `pause()`/`resume()` to
  release the camera on backgrounding — Android can hit resource conflicts and iOS can kill
  backgrounded camera sessions otherwise.

### Territory feature (`features/territory/`) — client-side run tracking

- `GeolocatorLocationProvider` wraps `geolocator` and feeds `kalman_dr`'s EKF for smoothed
  positions; fixes with `position.isMocked` are discarded client-side as a cheap anti-spoof
  pre-filter — the authoritative check is server-side in `submit_run()`.
- `flutter_foreground_task` exists only to keep the Android location-type foreground notification
  alive; the actual position stream is read in the main isolate, the background task handler is
  intentionally a no-op. iOS needs its own path (see scope note above) — this doesn't port as-is.
- `LocationProviderFactory.getCurrentPosition()` reuses the streaming provider's first emission
  instead of calling `Geolocator.getCurrentPosition()` directly — works around a real bug where
  Android's FusedLocationProviderClient returned a stale cached fix.
- `ActiveRunPage`'s `MapLibreMap` is built exactly once in `build()`, never inside a
  `BlocBuilder` — a 1Hz elapsed-timer tick would otherwise rebuild the whole map. Route/marker/
  camera updates go through `MapLibreMapController` imperatively via a `BlocListener` gated on
  point-count change.
- Loop-closure capture button enables only when `distanceMeters >= 400` AND back within ~30m of
  start. `PathSimplifier` RDP-simplifies (5m epsilon) and ships a parallel `p_point_timestamps`
  array alongside the GeoJSON (which has no per-vertex time field) for server-side anti-cheat.

**Territory map rendering (`TerritoryPage`/`territory_map_style.dart`, rewritten 2026-07-30)** —
read these files' own doc comments before touching map layers, they're extensively self-documented;
summary of the load-bearing parts:
- Territory polygons render via one `GeoJsonSource` + several filtered `Fill`/`Line` style layers
  (`setLayerProperties`/`setGeoJsonSource`), **not** per-territory `Fill`/`Line` annotations
  anymore. Cause: MapLibre Native (Android/iOS) doesn't support data-driven `line-dasharray`
  expressions — confirmed via a live logcat error — so the rival-territory dashed outline needed
  its own `filter`-based layer instead of one layer with a data expression.
- `_controller != null` (set at `onMapCreated`) does **not** mean the style is ready — a squad
  stream emitting before `onStyleLoadedCallback` fires caused a live `STYLE_NOT_READY`
  `PlatformException`. Gate any `addGeoJsonSource`/`addLayer` call on a separate `_styleReady` flag
  set from `onStyleLoadedCallback`.
- GeoJSON rings need ≥3 points before closing (repeating the first point) — an unfiltered
  degenerate ring caused live "Invalid geometry in line layer" warnings.
- A Pokémon-GO-style basemap recolor (`TerritoryBasemapRecolor`) patches OpenFreeMap layers via
  `setLayerProperties` from `onStyleLoadedCallback`. OpenFreeMap's `liberty` (light) and `dark`
  styles use genuinely different OpenMapTiles layer id sets — hardcoded per-tier id lists, checked
  against `controller.getLayerIds()` before use, not a generic source-layer rule. Any
  `SymbolLayerProperties` call must explicitly set `textFont: ['Noto Sans Regular']` — leaving it
  unset sends an explicit null that the native side resolves to an SDK default font OpenFreeMap
  doesn't host, causing live "Failed to load glyph range" 404s.

### Shell, profile, onboarding, squad — other non-obvious behavior

- **`features/shell/`** is the bottom-nav/app shell (`AppShellPage`): adaptive `NavigationBar`
  below 600dp, `NavigationRail` at ≥600dp. Tab pages are built once into a `late final` field (not
  inline in `build()`) so `IndexedStack` preserves each tab's `State` across switches.
- **`features/profile/`** — anonymous→real-account upgrade calls `updateUser` on the anonymous
  session (keeps the same user id), but the JWT's `is_anonymous` claim only flips on the *next*
  token refresh — `refreshSession()` must be called on app resume or the UI keeps showing "Guest".
  Display name is duplicated: auth metadata (`full_name`, self-display) vs `profiles.display_name`
  (everyone else, via leaderboards/squad — RLS is select-own-row only). Account deletion goes
  through a `delete-account` Edge Function (needs the service-role key the client never holds).
- **`features/onboarding/`** — `BatteryExemptionRepositoryImpl` hardcodes OEMs known to
  aggressively kill background apps (Xiaomi, Oppo, Vivo, Huawei, Samsung, OnePlus) and opens
  OEM autostart settings via the `SystemCapabilities` MethodChannel, which is Android-only
  (guarded, not implemented on iOS).
- **`features/squad/`** — Realtime presence (`trackPresence`, once per session) and telemetry
  broadcast (throttled internally) run from `RunTrackingCubit`/`VerificationCubit`, not from
  squad's own code. Weekly leaderboard rollover is detected via a `SharedPreferences`-backed
  last-seen-week check (`WeeklyResetLocalDataSource`), same pattern as onboarding's local
  datasource. Repository and cubit tests exist under `test/features/squad/`.

### Manifest permissions

`ACCESS_BACKGROUND_LOCATION` is deliberately **not** declared — run tracking is always
foreground-initiated with a while-in-use location foreground service (plan H3), avoiding Play's
harshest background-location review tier. Don't add it without re-reading H3 first.

### Supabase backend

Project `awaken-dev` (id `qxxkydisyqnodskmymla`, `ap-southeast-1`, free tier, Postgres 17 +
PostGIS). Tables: `profiles`, `alarms`, `sessions`, `runs`, `territories`, `user_stats`, `squads`,
`squad_reports`, `bounty_zones`, `territory_captures`, `active_runs` — all RLS-scoped to
`auth.uid()` (anonymous sessions are first-class users here, not excluded). `territories` is
public-read but has **no client INSERT/UPDATE policy** — mutated only through the
`submit_run(p_run_id, p_path, p_started_at, p_ended_at, p_point_timestamps)` `SECURITY DEFINER`
RPC (validate closure/length → polygonize via `ST_MakeValid` → `ST_Difference` against rival
territories → `ST_Union`, plus decay/bounty-zone/rivalry bonuses layered on since — see the
`territory_decay`/`bounty_zones`/`territory_rivalry` migrations). Never add a client-writable
policy on `territories`; new territory logic belongs in `submit_run` (or a new RPC), not client
code. Area math throughout casts to `::geography` (SRID 4326 geometry alone gives square degrees,
not m² — plan C4).

`active_runs` is a realtime-replicated in-progress-run row per user (`path` as `jsonb`, written
incrementally during a run so a killed/backgrounded client can resume) — distinct from the final
`runs` row that `submit_run` writes on completion; don't confuse the two when debugging sync.

Squad/leaderboard/economy features (added across the 2026-07-22→07-29 migrations, not yet
reflected elsewhere in this doc) are RPC-driven rather than direct table access from the client:
`create_squad`/`join_squad`/`leave_squad`/`squad_members`, `global_leaderboard`/
`nearby_leaderboard`/`squad_leaderboard` (+ matching `my_*_rank` RPCs), and a "wake-up tax" penalty
system (`bump_wake_up_tax`/`reset_wake_up_tax` write `user_stats.current_tax_multiplier`, consumed
by `alarms.penalty_multiplier`). These are `SECURITY DEFINER` and deliberately `EXECUTE`-granted to
`authenticated` — Supabase's security advisor flags that by default; it's expected here, not a
regression. Run `get_advisors` before assuming a WARN is new; as of 2026-07-30 the only
actually-actionable one is leaked-password protection being disabled (Auth dashboard setting, not
code).
