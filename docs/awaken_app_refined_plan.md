# Awaken — Refined Development Plan (v2)

**Date:** 2026-07-18
**Supersedes:** `awaken_app_development_plan.md` and `awaken_app_ui_ux_plan.md` (both remain useful as background; this document corrects their issues and is the actionable build plan.)
**Target:** Android-first Flutter app. Flutter stable 3.4x (Impeller default), `targetSdk 36` (Android 16), `minSdk 26` recommended.

---

## 1. Executive Summary

Awaken is a gamified alarm + fitness app: alarms can only be dismissed by performing camera-verified exercises (ML Kit pose detection), and outdoor runs that close a geographic loop capture "territory" on a shared map, with squads, leaderboards, and streaks. Stack: **Flutter + BLoC + Drift (offline-first) + Supabase (Postgres/PostGIS, Auth, Realtime)**.

The original two planning documents are directionally sound (offline-first outbox, feature-first clean architecture, FSI handling, Kalman smoothing, PostGIS turf logic) but contain **stale package pins, two discontinued/unsupported foundations (flutter_adaptive_scaffold, core-Flutter M3 Expressive), several Play-policy gaps that would block release in 2026, an OSM tile-usage violation, a PostGIS area-calculation bug, and an over-reliance on immature packages for mission-critical sync and alarm code.** This plan fixes all of those and sequences the work into 8 phases with explicit risk mitigations.

---

## 2. Issues Found in the Original Plans (and Resolutions)

### 2.1 Critical (would block release or break core features)

| # | Issue | Detail | Resolution |
|---|-------|--------|------------|
| C1 | **`flutter_adaptive_scaffold` is discontinued** | The Flutter team discontinued the package on 30 Apr 2025 ([flutter/flutter#162965](https://github.com/flutter/flutter/issues/162965)). The UI/UX plan builds its entire adaptive layout strategy on it. | Use plain `MediaQuery.sizeOf` breakpoints (600/840 dp) + `NavigationBar`/`NavigationRail` directly, or the community drop-in [`adaptive_scaffold_plus`](https://pub.dev/packages/adaptive_scaffold_plus). Adaptive layout is ~200 lines of first-party code; do not take a framework dependency for it. Phone-first: ship Compact layout in v1, Medium/Expanded in a later milestone. |
| C2 | **Material 3 Expressive is NOT available in core Flutter** | Flutter is explicitly *not* developing M3 Expressive in the framework and is not accepting contributions; Material/Cupertino are being decoupled into separate packages first ([flutter/flutter#168813](https://github.com/flutter/flutter/issues/168813)). The UI/UX plan assumes spring tokens, shape morphing, and 35 new shapes exist as framework features. They do not. | Treat M3 Expressive as a **design language to emulate, not an API to consume**. Implement: springs via Flutter's own `SpringSimulation`/`SpringDescription` (map the plan's damping/stiffness tokens into a small `MotionTokens` class) or the [`motor`](https://pub.dev/packages/motor) package; shape morphing via `MorphableShapeBorder`-style custom `ShapeBorder` tweens; dynamic color via `dynamic_color` + `ColorScheme.fromSeed`. Budget real time for this — it is custom design-system work, not free framework behavior. |
| C3 | **OSM public tile servers cannot be used in production** | The plan renders `flutter_map` against openstreetmap.org raster tiles. The OSMF tile usage policy prohibits heavy/production app usage; apps get throttled or blocked. | Keep `flutter_map` (v8.x) but serve tiles from a proper provider: free tiers of MapTiler / Stadia Maps / Thunderforest, self-hosted Protomaps (PMTiles on cheap object storage), or OpenFreeMap. Required attribution stays. Budget: free tiers cover dev + early production; PMTiles self-hosting is the long-term cost hedge. |
| C4 | **`ST_Area` on SRID 4326 geometry returns square degrees, not m²** | The data model stores `geom` as `GEOMETRY(Polygon, 4326)` and computes `area_sqm` "via ST_Area" — that yields garbage (degrees²). | Compute areas and distances on the **geography** type: `ST_Area(geom::geography)`. Same for velocity checks (`ST_Length(path::geography)`), loop-closure radius (`ST_DWithin(::geography, 30)`). Store geometry 4326 for topology ops; cast to geography for metric ops. |
| C5 | **Mission-critical sync pinned to a 90-download package** | `offline_first_sync_drift` v0.1.x (4 likes, unverified uploader) would own the app's most critical invariant: never lose user data. | Two viable paths — decide in Phase 0: **(a) Hand-rolled outbox on Drift** (the pattern is well documented and ~500 lines: transactional write + `sync_outbox` table + backoff worker; full control, no vendor). **(b) [PowerSync](https://docs.powersync.com/integrations/supabase/guide)** — purpose-built Supabase↔SQLite sync with upload queue and conflict hooks; managed service (cost + vendor dependency) or self-hosted. Recommendation: **hand-rolled outbox** — the app's write patterns (append-only sessions, runs, polygons) are simple, single-writer, and don't need generalized bidirectional merge. |
| C6 | **Full-screen-intent activity launch pattern is wrong** | The dev plan says the `BroadcastReceiver` "launches the MainActivity" directly. Background activity starts are blocked on Android 10+ and further tightened in Android 16 (strict BAL mode). Direct `startActivity` from a receiver will silently fail. | Correct pattern: receiver posts a **high-priority notification whose `fullScreenIntent` PendingIntent** points at the alarm activity, on a notification channel with `IMPORTANCE_HIGH` + alarm audio attributes. The OS launches the FSI when the screen is off/locked; when the user is actively using the device it shows a heads-up notification instead (this is by design — embrace it as the fallback). Activity itself sets `setShowWhenLocked(true)`, `setTurnScreenOn(true)`, requests keyguard dismissal, `FLAG_KEEP_SCREEN_ON`. |
| C7 | **Play policy timeline (2026)** | By **31 Aug 2026** all new apps and updates must target **API 36 / Android 16**; since **1 Nov 2025** updates must support **16 KB memory pages** (AGP ≥ 8.5.1, all native-code plugins current). The plan targets Android 14-era APIs. | Start at `targetSdk 36`, AGP 8.7+, latest plugin versions (all pinned versions in §4 are 16 KB-ready as of July 2026). Test on a 16 KB-page emulator image. Also: Android 15+ enforces **edge-to-edge** — audit every screen with `SafeArea`/`MediaQuery.padding`. |

### 2.2 High (degraded reliability or review rejection risk)

| # | Issue | Resolution |
|---|-------|------------|
| H1 | **`android_alarm_manager_plus` is the wrong tool.** It cannot manage the `SCHEDULE_EXACT_ALARM` permission flow and only runs Dart callbacks — it doesn't handle audio, wake, boot-restore, or FSI. | Use the [`alarm`](https://pub.dev/packages/alarm) package (v5.5+, actively maintained): foreground-service-backed ringing, survives app kill, boot restore, `androidFullScreenIntent`, volume/audio-focus handling. Keep a thin native Kotlin layer only for `canScheduleExactAlarms()` / `canUseFullScreenIntent()` checks and settings intents (`ACTION_REQUEST_SCHEDULE_EXACT_ALARM`, `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`) via a MethodChannel — or `permission_handler` where it covers them. |
| H2 | **Play Console declarations are a launch dependency, not an afterthought.** FSI by default requires the app to be a *bona fide alarm app* (policy active since 22 Jan 2025); `FOREGROUND_SERVICE_LOCATION` requires a Play Console declaration **with a demo video**; background location has its own review. | Add a "Play compliance" workstream (Phase 7): store listing categorized as alarm/clock, FSI declaration, FGS-location declaration + video, prominent in-app disclosure for location. Build the demo video from the run-tracking flow early. |
| H3 | **`ACCESS_BACKGROUND_LOCATION` is probably unnecessary — drop it.** Run tracking always starts in the foreground (user taps "Start Run"), then a `location`-type foreground service keeps GPS alive with only while-in-use permission. Requesting background location triggers the harshest Play review for zero benefit. | Permissions set: `ACCESS_FINE_LOCATION` (while-in-use) + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` + persistent notification. Only revisit if a future feature needs passive tracking. |
| H4 | **OEM battery killers will silently break alarms** (Xiaomi/HyperOS, Samsung, Huawei, Oppo aggressive task killing — see dontkillmyapp.com). The plans never mention it. | Onboarding step that detects OEM and deep-links to the vendor-specific battery-exemption screen; request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (alarm apps are a legitimate exemption case); in-app "alarm reliability check" self-test (schedule a 1-minute test alarm). |
| H5 | **ML Kit pose detection is beta + the Flutter wrapper is community-maintained** (`google_mlkit_pose_detection`, flutter-ml disclaims production responsibility). Also 33-landmark inference at "60 fps" is fantasy on mid-range hardware. | Accept ML Kit for v1 (it remains the pragmatic choice; MediaPipe `pose_landmarker` is the escalation path via a custom platform channel if ML Kit stalls). Set realistic targets: **process 10–15 FPS** at `ResolutionPreset.low/medium`, `PoseDetectionModel.base`, STREAM mode; UI renders at 60/120 via `ValueNotifier` + `CustomPaint` + `RepaintBoundary` (this part of the plan was correct). On Android feed `InputImage` as **NV21** (set `imageFormatGroup: ImageFormatGroup.nv21` in camera ^0.12). Drop frames when the detector is busy (process-latest, skip-backlog). |
| H6 | **Supabase Realtime limits constrain the Squad live-telemetry design.** Free tier: 200 concurrent connections, 2 M messages/month; Pro: 500 connections then $10/1000. Streaming every rep of every squad member is message-volume suicide. | Use **Broadcast channels with throttled payloads** (≤ 1 message / 2–3 s per active workout, aggregate state not per-rep), Presence for online status, and drop to polling for leaderboards. Design the telemetry contract around a message budget from day one. |
| H7 | **Anti-cheat needs more than `isMocked`.** Rooted devices and instrumented builds defeat client checks. | Layered: `Position.isMocked` discard + client velocity gate → server-side PostGIS velocity/teleport validation (authoritative) → **Play Integrity API** verdict attached to run-submission for suspicious runs → territory awarded only by server. Never trust client-computed polygons or areas. |
| H8 | **Guest → account migration: prefer Supabase anonymous sign-in over re-keying.** The plan's "re-key every local row to the new auth.uid()" routine is error-prone. | When online at first launch: `signInAnonymously()` — the user gets a real `auth.uid()` immediately, and **linking** email/OAuth later preserves the same uid — zero re-keying, RLS works from day one. Keep the local-placeholder + re-key routine only as the fully-offline-first-launch fallback. |

### 2.3 Moderate (correctness / hygiene)

- **Stale package pins** throughout the dev plan (flutter_bloc ^8 → 9.x, camera ^0.10 → 0.12.x, flutter_map ^6 → 8.x, drift → 2.34.x, flutter_foreground_task 9 → 10, mlkit 0.14 → 0.15). Corrected matrix in §4.
- **`ST_Buffer(geom, 0)` to fix invalid polygons is deprecated practice** → use `ST_MakeValid()` (+ `ST_CollectionExtract(…, 3)` to keep only polygons).
- **`kalman_dr` is a 1-like niche package.** The code is small, pure-Dart, MIT-friendly — pin an exact version and be prepared to **vendor/fork it**; add golden-trajectory unit tests against recorded GPS traces so a swap-out is verifiable. Alternative: EKF is ~200 lines to own outright.
- **`turf` (Dart) is an incomplete 0.0.x port** — fine for cheap client-side pre-checks (loop-closure distance, point-in-polygon for UI), but all authoritative geometry stays in PostGIS.
- **Penalty multiplier data type**: `penalty_multiplier INTEGER` with "exponential growth" — use a bounded schedule (e.g., ×1.5 capped at ×4) stored as numeric; unbounded exponential reps is hostile UX and a churn machine.
- **"Non-dismissible" has hard limits**: users can always force-stop the app, restart the phone, or toggle DND. Design the tax/streak system to make skipping *costly in-game* rather than pretending the OS allows a true lockout. Also provide an accessibility escape hatch (injury/disability mode with alternative dismissal), which is both ethical and a likely Play-review expectation.
- **WebSockets wording**: use `supabase_flutter`'s Realtime client, not raw WebSockets — same architecture (Data-layer stream behind a Domain interface), less code.
- **Impeller is the only Android renderer now** (opt-out deprecated in Flutter 3.38+). Profile the camera-preview + CustomPaint overlay and the map polygon layers on Impeller specifically; file-and-workaround rather than toggling back to Skia (no longer possible).

---

## 3. Architecture (confirmed, with amendments)

Feature-first Clean Architecture stands as planned:

```
lib/
  core/            # theme (M3E-inspired tokens), motion tokens, errors, DI, utils
  features/
    onboarding/    # value carousel, permission rationale flows, reliability check
    alarm/         # scheduling, ringing screen, wake-up tax
    verification/  # camera + pose pipeline + rep state machine (split from alarm: it's the riskiest module)
    territory/     # run tracking FGS, kalman smoothing, map, polygons
    squad/         # realtime presence/broadcast, leaderboards
    profile/       # auth, guest→linked account, settings
  sync/            # drift schema, outbox engine, connectivity watcher
```

Each feature: `presentation/` (widgets + blocs) → `domain/` (entities, usecases, repo interfaces, zero Flutter imports) → `data/` (repo impls, drift + supabase datasources, DTOs/mappers). DI via `get_it` + `injectable`. State management: `flutter_bloc` 9.x (as planned; Riverpod 3 is an acceptable substitution if the team prefers — decide once in Phase 0 and never revisit).

**Amendment — verification is its own feature module.** The pose pipeline has unique dependencies (camera, mlkit) and its own perf discipline; isolating it keeps the alarm feature testable without camera hardware.

**Amendment — sync engine ownership.** `sync/` exposes exactly two things to features: a `LocalWriter` (transactional write + outbox enqueue) and `Stream<SyncStatus>` for the cloud-state chip. Features never touch Supabase directly for user data; read models come from Drift streams (which makes the whole UI reactive and offline-correct for free).

### Data model corrections

Original ERD stands with these changes:

- `territories.geom GEOMETRY(MultiPolygon, 4326)` — after `ST_Difference`, a territory can be split into disjoint pieces; Polygon type would reject the update.
- `area_sqm` → computed as `ST_Area(geom::geography)`, maintained by trigger, never client-supplied.
- All tables: `updated_at timestamptz`, `deleted_at timestamptz` (soft delete), client-generated UUIDv4 PKs.
- `runs` additionally: `started_at`, `ended_at`, `point_count`, `integrity_verdict` (nullable, from Play Integrity spot-checks), `rejected_reason`.
- `sync_outbox` (client-only): add `entity_id`, `created_at`, `next_attempt_at` (backoff is a scheduled time, not a sleep).
- RLS on every table keyed to `auth.uid()`; territory mutation happens **only** through `SECURITY DEFINER` RPC / Edge Function — clients never write `territories` directly.

### Territory pipeline (server-authoritative, corrected SQL)

1. Client: EKF-smoothed points, Ramer-Douglas-Peucker simplification (`simplify` client-side for payload size), loop pre-check with `turf` (`ST_DWithin`-equivalent, 30 m).
2. RPC `submit_run(path jsonb)` validates: min length (`ST_Length(path::geography) > 400m`), max speed between consecutive fixes (< ~7 m/s sustained), closure (`ST_DWithin(start::geography, end::geography, 30)`).
3. Polygonize: `ST_MakeValid(ST_MakePolygon(ST_AddPoint(path, ST_StartPoint(path))))` → `ST_CollectionExtract(…, 3)`.
4. Conflict: for each intersecting rival territory, `rival.geom = ST_Difference(rival.geom, new.geom)`; delete rivals whose area drops below a floor; insert/merge (`ST_Union`) the winner's polygon.
5. Recompute `area_sqm` for all touched rows; single transaction; return the delta for client-side celebration UI.

### Territory feature v2 — refined scope (2026-07-26)

Merges the original MVP capture loop above with retention/competitive mechanics from an earlier prototype's spec (`old_awaken_project_details.md`), reconciled and simplified — redundant thresholds collapsed, ranges replaced with single values, Fog of War excluded entirely (out of scope). Supersedes nothing above; adds decay, bounty zones, lightweight rivalry, a real multi-scope leaderboard, and crash-resilient tracking on top of the existing capture pipeline.

**Objective:** running a closed loop claims land, but that land now has real stakes — it decays if neglected, can be taken by rivals, and some zones are worth more — with a leaderboard and light rivalry-awareness to make it feel like an ongoing competitive game rather than a one-off log entry. Tracking itself must survive real-world interruptions (lost signal, backgrounded app, OS process death) without losing a run.

**Functional requirements (condensed — full flows/user-story detail live in session notes, not duplicated here):**
- Loop validation stays a single closure-radius + min-length + min-point-count check (no separate "exit distance" rule — redundant with min-length).
- Server remains sole authority on validity/area; client checks are advisory pre-filters only.
- Run tracking checkpoints to local storage on a fixed ~10s interval; an orphaned checkpoint is detected and offered for resume/finalize on next launch — bounds data loss to the checkpoint interval rather than promising an unachievable zero-loss guarantee.
- Locally-queued unsent runs are encrypted at rest.
- A territory decays after a fixed inactivity period (grace-period notification before reversion); re-capturing/defending it resets the clock.
- A small number of live, map-visible bounty zones apply a flat capture-area multiplier when a capture overlaps one (flat multiplier, not a range — legibility over tunability).
- A single "current rival" surfaces per user (the other party in their most recent contested capture, either direction) — not a persistent multi-rival system.
- Leaderboard adds Global and Nearby (GPS-proximity) scopes alongside the existing Squad scope, and All-Time / Weekly time windows (Monthly dropped — two windows cover the meaningful cases), a Top-3 podium + "my neighborhood" (±5 ranks) view, and tap-to-jump from a rank row to that user's territory on the map.

**Non-functional requirements (new/changed):**
- Reliability: a run must survive screen-off, backgrounding, and — bounded by the checkpoint interval — process death. "Bounded data loss," not absolute zero-loss, is the accepted standard (matches this project's existing moderate-over-absolute posture elsewhere, e.g. §2.3).
- Security: locally-queued run/session data is encrypted at rest (`drift/native`'s encrypted executor + `sqlcipher_flutter_libs`, key held in platform secure storage via `flutter_secure_storage` — never hardcoded, derived via a KDF).
- Fairness: decay is deliberate — the map staying contested is a design goal, not a bug to fix by making ownership permanent.
- Privacy: no new continuous-location requirement — "nearby" ranking and rivalry both derive from data already produced by active runs (run centroid, capture events), not a standing location subscription; still no `ACCESS_BACKGROUND_LOCATION` (H3 stands).

#### Database changes required

All additive (new tables/columns + new/modified RPCs); no breaking changes to the existing `runs`/`territories` pipeline above.

1. **Decay tracking** — add `territories.last_defended_at timestamptz not null default now()` (distinct from `updated_at`, which the area-recompute trigger also touches for unrelated reasons); `submit_run()` sets it whenever a capture creates or touches the user's own territory. A `pg_cron` job (built into every Supabase project, no new extension install) runs daily, calling a `SECURITY DEFINER` function that soft-deletes (`deleted_at`) territories where `last_defended_at` is older than the grace period. No stored decay "state" column — "at risk" is computed on read (`last_defended_at + grace_period < now()`) rather than duplicated as a flag that could drift out of sync.
2. **Bounty zones** — new `public.bounty_zones` table: `id uuid pk`, `center geography(Point,4326)`, `radius_m numeric`, `multiplier numeric default 2.0`, `active_from timestamptz`, `active_until timestamptz nullable` (null = indefinite), `created_at`. Public-read RLS (everyone sees active zones), no client write. `submit_run()` checks whether the new capture intersects an active zone and returns a separate `bonus_area_sqm` in its response for scoring/leaderboard purposes — the stored polygon/`area_sqm` always reflects the true captured shape; the multiplier boosts credited score, not literal geometry (scaling real map polygons by an arbitrary multiplier would falsify the map itself).
3. **Rivalry** — new `public.territory_captures` event log: `id`, `winner_id`, `loser_id nullable` (null when capturing unclaimed land), `area_taken_sqm`, `created_at`. Populated by `submit_run()` whenever the rival-subtraction branch fires. New `current_rival()` RPC returns the other party in the caller's most recent row where they appear as either `winner_id` or `loser_id` with a non-null counterpart. This same log doubles as the source for the leaderboard's Weekly window (sum `area_taken_sqm` per user over the trailing 7 days) without needing a separate rolling-stats table.
4. **Nearby leaderboard** — add `public.profiles.last_run_location geography(Point,4326) nullable` + GiST index; `submit_run()` sets it to the new run's centroid on every successful submission (reuses data a run already produces — no new tracking surface, consistent with the privacy NFR above). New `nearby_leaderboard(radius_m, time_window)` RPC using `ST_DWithin` against that column (per current PostGIS guidance: index the geography column directly and let `ST_DWithin` use it — do not compute a bounding box manually). Extend `squad_leaderboard`/add `global_leaderboard` with the same `time_window` param (`all_time` reads existing `territories.area_sqm` sums; `weekly` reads `territory_captures`).
5. **Resilience (checkpointing + encrypted queue)** — client-only, no Supabase schema change. Local Drift schema gains a lightweight checkpoint table (run id, latest points/state, last-write timestamp) written every ~10s while a run is active and cleared on normal completion/abandon; the whole local database moves to an encrypted `NativeDatabase` executor (`sqlcipher_flutter_libs` via `drift/native`'s encrypted-executor support), with the passphrase generated once and stored via `flutter_secure_storage` (Android Keystore / iOS Keychain-backed) rather than derived from anything guessable.

Each of the above ships as its own migration file (per this project's existing one-concern-per-migration convention), applied via the Supabase CLI (`supabase db query --linked` to iterate, hand-authored migration file + `supabase migration repair` to record — `apply_migration`-style tools that auto-stamp a version on every call make iteration and clean history impossible, confirmed the hard way earlier in this project).

---

## 4. Corrected Technology Matrix (verified July 2026)

| Package | Plan said | Use now | Notes |
|---|---|---|---|
| Flutter SDK | — | latest stable 3.4x | Impeller default/only on Android API 29+; Dart 3.9+ |
| flutter_bloc | ^8.1.5 | **^9.1.1** | |
| supabase_flutter | ^2.0.0 | **^2.16.0** | includes Realtime v2 client, anonymous sign-in |
| drift + sqlite3_flutter_libs | ^2.26.0 | **^2.34.0** | |
| offline_first_sync_drift | ^0.1.1 | **REMOVED** | hand-rolled outbox (C5) |
| google_mlkit_pose_detection | ^0.14.0 | **^0.15.0** | community-maintained; beta API (H5) |
| camera | ^0.10.6 | **^0.12.0** | `ImageFormatGroup.nv21` on Android |
| flutter_foreground_task | ^9.2.2 | **^10.0.0** | major-version API changes vs plan |
| geolocator | ^14.0.3 | ^14.x ✓ | `Position.isMocked` |
| kalman_dr | ^0.2.0 | **^0.4.4, pin exact + fork-ready** | golden tests required |
| flutter_map + latlong2 | ^6.0.0 | **^8.3.0** | + `flutter_map_cancellable_tile_provider`; commercial/self-hosted tiles (C3) |
| android_alarm_manager_plus | ^3.0.0 | **REPLACED by `alarm` ^5.5.0** | (H1) |
| flutter_adaptive_scaffold | (UI plan) | **REMOVED** | discontinued (C1); hand-rolled breakpoints |
| get_it + injectable | ^7.7.0 | latest (get_it 8.x) | |
| turf | ^0.0.12 | ^0.0.12 ✓ | client pre-checks only |
| **Add:** permission_handler | — | latest | runtime permission UX |
| **Add:** dynamic_color | — | latest | Material You seeded schemes |
| **Add:** wakelock_plus | — | latest | keep screen on during workout |
| **Add:** connectivity_plus | — | latest | sync engine trigger |
| **Add:** sentry_flutter (or Crashlytics) | — | latest | alarm failures must be observable |
| **Add:** patrol | — | latest (dev) | native-dialog integration tests (permissions, notifications) |
| **Add:** motor *(optional)* | — | latest | M3E-style spring motion, else hand-rolled `SpringSimulation` |

**Android config:** AGP ≥ 8.7, Kotlin 2.x, `compileSdk/targetSdk 36`, `minSdk 26` (ML Kit and FSI behavior below 26 isn't worth supporting), 16 KB page-size verification in CI (emulator image), R8 + `--obfuscate --split-debug-info` for release.

**Manifest permissions (final set):** `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` (or `USE_EXACT_ALARM` — see note), `USE_FULL_SCREEN_INTENT`, `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (alarm ringing), `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `CAMERA`. **Dropped:** `ACCESS_BACKGROUND_LOCATION` (H3). *Note:* as a genuine alarm app, Awaken qualifies for `USE_EXACT_ALARM` (granted automatically, no user prompt, but Play reviews the claim) — prefer it over `SCHEDULE_EXACT_ALARM` and delete the degraded-inexact fallback UI complexity.

---

## 5. UI/UX Plan Amendments

The psychological framing, screen inventory, typography scale, and shape-tension guidance in the UI/UX plan all stand. Changes:

1. **Design system = "M3 Expressive-inspired," built in-app** (C2). Create `core/theme/`: `MotionTokens` (the four spring configs from the plan's Table 2, expressed as `SpringDescription`s), `ShapeTokens` (corner radii incl. 48 dp XXL), seeded `ColorScheme` light/dark via `dynamic_color` with brand fallback. Variable-font weight animation via `GoogleFonts` Roboto Flex axes.
2. **Adaptive layout without the dead package** (C1): a single `WindowSizeClass` helper (compact < 600 ≤ medium < 840 ≤ expanded) driving `NavigationBar` ↔ `NavigationRail` and one `ListDetail` composable. **V1 ships compact-only**; medium/expanded arrive in Phase 8. Foldable/tablet polish is not on the critical path to validating the product.
3. **Edge-to-edge audit** (C7): every screen wrapped in `SafeArea`-aware scaffolds; test with gesture nav + display cutouts.
4. **Alarm ring screen reality check** (C6/H4): design both variants as first-class — full-screen takeover *and* heads-up-notification entry path. The HUN path is not a degraded edge case; it is what users see whenever they're actively using the phone.
5. **Verification screen**: add explicit low-light and camera-permission-revoked states, a "can't do this exercise today" accessibility path (logged, streak-affecting, but never trapping), and a 3-rep calibration intro on first use.
6. **Map screen**: attribution overlay (required by every tile provider), offline tile cache note ("map unavailable offline — run still records" state), and the isMocked/velocity flag surfaced as a neutral "GPS quality" indicator rather than an accusation.

---

## 6. Phased Roadmap

Ordering principle: **retire the two existential risks first** (pose verification viability, alarm reliability on real OEM devices) before investing in the territory/social superstructure.

**Phase 0 — Foundations (week 1–2).** Repo + git init, CI (GitHub Actions: analyze, test, build, 16 KB-page emulator smoke), flavors (dev/prod), Supabase project + anonymous auth, DI skeleton, theme/motion tokens, decision records (bloc-vs-riverpod, outbox-vs-PowerSync — recommendations: bloc, outbox).

**Phase 1 — Alarm core (week 2–5). ⚠ Risk-retirement milestone.** `alarm` package integration; native Kotlin: FSI/exact-alarm capability checks, lock-screen activity flags; notification channels; boot restore; OEM battery-exemption onboarding (H4); reliability self-test. **Exit criterion: alarm fires reliably from killed state on ≥ 4 physical devices incl. one Xiaomi/HyperOS and one Samsung, screen off, 30+ min after kill.**

**Phase 2 — Pose verification (week 3–7, overlaps). ⚠ Risk-retirement milestone.** Camera NV21 stream → ML Kit STREAM mode; frame-drop governor (process-latest); joint-angle rep state machine (squat first, then push-up); `ValueNotifier` + `RepaintBoundary` overlay; thermal test (15-min continuous session on a mid-range device); calibration flow. **Exit criterion: 20 squats counted with ≥ 95% accuracy across 5 body types/lighting conditions, < 45 °C device temp, on a Snapdragon 6-series phone.**

**Phase 3 — Offline-first data layer (week 6–9).** Drift schema + migrations; outbox engine (transactional enqueue, connectivity-triggered drain, `next_attempt_at` backoff, idempotent upserts on UUID PK); Supabase schema + RLS; anonymous-auth-first guest flow with account linking (H8); sync-status chip. Property-based tests: no write path exists that skips the outbox.

**Phase 4 — Alarm ⇄ verification integration (week 8–10).** Full loop: schedule → ring → verify → dismiss → session logged → synced. Wake-up tax (bounded multiplier); streak logic; celebration hero moment. Beta gate: internal testing track opens here — the core product is now testable.

**Phase 5 — Territory (week 10–15).** FGS run tracking (`flutter_foreground_task` 10.x, location type, while-in-use only — H3); EKF smoothing + golden-trajectory tests; RDP simplification; anti-cheat client gates (isMocked, velocity); map rendering (flutter_map 8, culling, commercial tiles — C3); PostGIS RPC pipeline (§3, corrected SQL — C4); territory shading + capture celebration.

**Phase 6 — Squad & social (week 14–18).** Squad CRUD; Realtime Broadcast with throttled telemetry contract (H6); presence; leaderboards (polled, geography-computed areas); streak tiers.

**Phase 7 — Hardening & Play compliance (week 17–20).** Play Console: alarm-app categorization, FSI declaration, FGS-location declaration + demo video (H2), data-safety form, prominent location disclosure. Play Integrity spot-checks on suspicious runs (H7). Sentry wiring with alarm-failure breadcrumbs. Patrol E2E: permission flows, alarm fire, run tracking. Battery/thermal profiling passes (DevTools + Impeller frame timings). Accessibility review (TalkBack on ring + verification screens — a user who can't see the skeleton must still be able to dismiss).

**Phase 8 — Launch & post-launch (week 20+).** Closed → open testing → production rollout by % stages. Then: medium/expanded adaptive layouts, more exercise types, iOS feasibility spike (FSI/exact-alarm equivalents differ materially — explicitly out of scope for v1).

Timeline assumes 1–2 experienced Flutter devs; treat as relative sequencing, not promises.

---

## 7. Risk Register (top 8)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| OEM task-killers suppress alarms | High | Fatal to core loop | Phase 1 exit criterion on real devices; battery-exemption onboarding; reliability self-test; Sentry telemetry on missed alarms |
| Pose accuracy unacceptable across body types/lighting | Medium | Fatal to core loop | Phase 2 exit criterion; calibration flow; per-exercise tunable thresholds server-delivered (remote config) |
| ML Kit pose (beta) breaks or stalls | Medium | High | Wrapper isolated behind Domain interface; MediaPipe pose_landmarker platform-channel fallback documented |
| Play rejects FSI/alarm categorization | Low-Med | High | Genuine alarm app + declarations done early (Phase 7 checklist started in Phase 1); HUN fallback fully functional regardless |
| Tile-provider cost blowup | Medium | Medium | Free-tier provider + aggressive tile caching; PMTiles self-host escape hatch |
| Supabase Realtime cost/connection ceiling | Medium | Medium | Throttled broadcast contract; polling fallback; budget alerts |
| `kalman_dr` / `turf` abandonment | Medium | Low-Med | Exact pins, golden tests, fork-ready; authoritative math server-side |
| GPS spoofing / driving-capture cheating | High | Medium (economy integrity) | Layered anti-cheat (H7); server-authoritative awards; shadow-flagging rather than instant bans |

---

## 8. Testing & Quality Strategy

- **Unit:** rep state machine (recorded landmark fixtures), EKF golden trajectories, outbox invariants (property-based: every local write ⇒ outbox row in same txn), tax/streak math.
- **Widget:** alarm ring states, verification overlay rebuild-isolation (assert paint count via `RepaintBoundary` debug flags), sync chip states.
- **Integration (Patrol):** permission grant/deny matrices, alarm fire from terminated state, run start/stop with FGS notification.
- **Backend:** pgTAP or SQL test harness for the territory RPC (closure, self-intersection, difference, area floors, RLS denial cases).
- **Device lab minimum:** Pixel (stock, 16 KB page), Samsung (One UI), Xiaomi (HyperOS), one Android Go/low-RAM unit.
- **Performance budgets:** ring-screen cold start < 2 s from FSI; verification steady-state ≥ 10 processed FPS / 60 rendered FPS; run tracking ≤ 6%/h battery.

---

## 9. Key Sources

- flutter_adaptive_scaffold discontinuation: https://github.com/flutter/flutter/issues/162965 · umbrella: https://github.com/flutter/flutter/issues/162960
- M3 Expressive in Flutter (not planned in core): https://github.com/flutter/flutter/issues/168813
- Play target-API policy (API 36 by 31 Aug 2026): https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB page-size requirement: https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html
- FSI limits & alarm-app policy: https://source.android.com/docs/core/permissions/fsi-limits · https://support.google.com/googleplay/android-developer/answer/13392821
- Background activity-start restrictions (Android 16 strict mode): https://developer.android.com/guide/components/activities/background-starts
- alarm package: https://pub.dev/packages/alarm · flutter_foreground_task: https://pub.dev/packages/flutter_foreground_task
- ML Kit pose detection: https://developers.google.com/ml-kit/vision/pose-detection · Flutter wrapper: https://pub.dev/packages/google_mlkit_pose_detection · MediaPipe successor path: https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker
- flutter_map v8: https://pub.dev/packages/flutter_map · docs: https://docs.fleaflet.dev/
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits · PowerSync + Supabase: https://docs.powersync.com/integrations/supabase/guide
- Offline-first outbox pattern reference: https://medium.com/@fintasys/offline-first-flutter-drift-as-the-source-of-truth-supabase-as-a-sync-target-eab7c43523ce
- OEM battery-killer reference: https://dontkillmyapp.com
- Drift encrypted executor: https://drift.simonbinder.eu/platforms/encryption/ · sqlcipher_flutter_libs: https://pub.dev/packages/sqlcipher_flutter_libs · sqflite_sqlcipher (alternative): https://pub.dev/packages/sqflite_sqlcipher
- Supabase Cron / pg_cron: https://supabase.com/docs/guides/cron · https://supabase.com/docs/guides/database/extensions/pg_cron
- PostGIS `ST_DWithin` + geography indexing guidance: https://postgis.net/docs/ST_DWithin.html · https://blog.cleverelephant.ca/2021/05/indexes-and-queries.html
