# Awaken

Gamified alarm + fitness Android app: alarms are dismissed by performing camera-verified
exercises, and outdoor runs that close a geographic loop capture "territory" on a shared map.

- Architecture: Feature-First Clean Architecture (Presentation → Domain → Data), BLoC state
  management, offline-first (Drift as local source of truth, Supabase as sync target via a
  hand-rolled outbox).
- Full rationale, corrected package matrix, phased roadmap, and risk register:
  [`awaken_app_refined_plan.md`](awaken_app_refined_plan.md) — **read this first.**
- Background docs (superseded by the refined plan, kept for context):
  [`awaken_app_development_plan.md`](awaken_app_development_plan.md),
  [`awaken_app_ui_ux_plan.md`](awaken_app_ui_ux_plan.md).

## Project layout

```
lib/
  core/            # theme (motion/shape tokens), DI, error types, base usecase, constants
  sync/            # Drift schema + outbox engine + connectivity watcher (Phase 3)
  features/
    onboarding/    # value carousel, permission rationale, reliability self-test
    alarm/         # scheduling, ringing screen, wake-up tax
    verification/  # camera + ML Kit pose pipeline + rep state machine
    territory/     # run tracking, Kalman smoothing, map, polygons
    squad/         # realtime presence/broadcast, leaderboards
    profile/       # auth, guest→linked account, settings
```

Each feature follows `presentation/ → domain/ → data/`, wired through `get_it` + `injectable`.
See the refined plan §3 and §6 for the full architecture and phase sequencing.

## Getting started

```bash
cp .env.client.example .env.client   # fill in Supabase URL + publishable key
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate injection.config.dart, drift tables
flutter analyze
flutter test
flutter run --flavor dev -t lib/main_dev.dart   # dev/prod flavors — see android/app/build.gradle.kts
```

### Environment files

Two separate env files, deliberately not merged:

- **`.env.client`** — bundled into the app binary as a Flutter asset (see `pubspec.yaml`).
  Only client-safe values: Supabase URL + publishable key (protected by RLS, not secrecy),
  Google OAuth client IDs. Loaded at startup via `core/config/env.dart`.
- **`.env`** — tooling-only (Supabase management-API PAT for MCP/CLI use). **Never** referenced
  by app code or added to `pubspec.yaml` assets.

Both are gitignored; `.env.client.example` / `.env.example` show the expected shape.

### Supabase backend

Project **`awaken-dev`** (`ap-southeast-1`, free tier, Postgres 17 + PostGIS). Schema applied via
migrations (see `mcp__supabase__list_migrations` or the dashboard's migration history):
`profiles`, `alarms`, `sessions`, `runs`, `territories` — all with RLS keyed to `auth.uid()`
(`territories` is public-read; mutated only through the `submit_run()` `SECURITY DEFINER` RPC,
per the refined plan §3's server-authoritative territory pipeline). One accepted advisory:
`public.spatial_ref_sys` (a PostGIS system table, read-only SRID reference data) doesn't have
RLS enabled and can't be altered without table-owner privileges — low risk, common on
PostGIS-enabled Supabase projects.

### Known Windows build workaround

`android/gradle.properties` sets `kotlin.incremental=false`. On this machine, Kotlin's
build-tools-api incremental compiler intermittently fails to close its on-disk caches under
`build\<module>\...` (file-lock/AV interference), failing `compileDebugKotlin` for several
plugins. Disabling incremental compilation trades a slower build for reliability. Revisit if
upstream fixes it; safe to try re-enabling on other machines/CI (Linux runners).

## Status

**Phase 0 (Foundations) — complete.** Project structure, DI skeleton, theme/motion tokens,
manifest permissions, dependency matrix, Supabase project provisioned + schema/RLS/territory RPC
applied, app wired to load env and boot the Supabase client through DI, CI workflow
(`.github/workflows/ci.yaml`), dev/prod build flavors (`lib/main_dev.dart` / `lib/main_prod.dart`),
anonymous-auth bootstrap at startup, decision records (`docs/decisions.md`).

**Phase 1 (Alarm core) — feature-complete, self-test passing on emulator.** `alarm`-package
integration (`features/alarm/`) with the critical `androidStopAlarmOnTermination: false`
override; native Kotlin FSI/exact-alarm capability channel + lock-screen bypass flags
(`MainActivity.kt`); OEM battery-exemption onboarding (`features/onboarding/`); in-app alarm
reliability self-test (`AlarmReliabilityTestPage`). Verified end-to-end on an Android 17 (API 37)
emulator: locked screen → scheduled alarm fires → full-screen intent wakes the screen and
bypasses the keyguard → ring UI takes over globally (including from a nested route — this
required fixing the ring overlay to live in `MaterialApp.builder` rather than the root route
only) → dismiss works. Two real bugs were caught and fixed by this runtime testing, not just
static analysis:
1. `POST_NOTIFICATIONS` was declared in the manifest but never requested at runtime (mandatory
   on Android 13+) — the alarm's notification was silently blocked until this was added to
   `main_common.dart`'s bootstrap.
2. The ring screen only auto-displayed when the user was on the root route — fixed via a
   `MaterialApp.builder` overlay (`app.dart`) so a ringing alarm always takes over regardless of
   navigation depth.

**Still required before calling Phase 1 done per the plan's own exit criterion:** real testing on
≥ 4 physical devices (incl. Xiaomi/HyperOS and Samsung), screen off, 30+ min after force-kill —
emulator testing cannot substitute for this (plan §6). Supabase's "Anonymous Sign-ins" provider
toggle also needs to be enabled in the dashboard; it isn't controllable via the tools used to set
up this project.

**Phase 2 (Pose verification) — implemented, not yet device-verified.** `features/verification/`:
NV21 camera stream (front camera, `CameraDataSource`) → ML Kit `PoseDetector` in STREAM mode
(`PoseDetectorDataSource`) with a frame-drop governor (in-flight frame drops the next one rather
than queuing); joint-angle rep state machine (`AngleRepCounter` — hip-knee-ankle for squats,
shoulder-elbow-wrist for push-ups, with a dead zone between the down/up thresholds so noisy
frames near a boundary don't flicker the phase); 3-rep calibration before real counting starts;
low-light/no-pose and camera-permission-denied states; skeleton overlay (`SkeletonPainter`);
`VerificationPage` as a standalone screen. Unit-tested (`test/features/verification/domain/`) —
9 rep-counter tests covering the down-then-up transition, partial reps, missing landmarks, and
multi-rep counts. **Not yet done:** wired into the alarm-dismiss flow (that's Phase 4 by design —
see the TODO in `alarm_ring_page.dart`); Phase 2's actual exit criterion (20 squats ≥ 95% accuracy
across 5 body types/lighting, < 45 °C, on a Snapdragon 6-series phone) needs a real device, same
caveat as Phase 1.

Next: **Phase 3 — Offline-first data layer** (Drift schema/migrations, outbox engine), or physical-
device verification of Phases 1–2's exit criteria. See the refined plan §6 for full phase
sequencing.
