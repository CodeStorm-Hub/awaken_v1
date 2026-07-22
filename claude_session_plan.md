I'll start by mapping the codebase, then review the docs and the Supabase database, and finish with a full remaining-implementation plan.

Database confirmed: 6 tables + `submit_run` RPC, no squad tables, no edge functions. Now reading the presentation pages to separate real features from mock UIs.

The alarm→verification loop (Phase 4) is already wired — dismissal goes through the camera verification page. Let me check the sync layer, the remaining wiring, and outstanding TODOs.

Let me check Supabase advisors for any outstanding backend issues, then update my stale phase-status memory and write up the plan.

The existing memory is detailed and mostly accurate — I'll just append a dated correction (territory/squad now contain mock UI pages, not empty scaffolds) and fix the index line.

I've completed the full review — codebase, packages, the refined plan, and the live Supabase database. Here's everything, ending with the remaining-implementation plan.

# 1. Existing features & functionality (real, working)

**Alarm core (Phase 1 ✅)**
- Schedule / cancel / dismiss alarms via the `alarm` package (foreground-service ringing, survives app kill, boot restore), with `androidStopAlarmOnTermination: false`
- Days-of-week recurrence (`AlarmSchedule.recurringDays` + `nextOccurrenceAfter`), hybrid rescheduling: re-arm after each ring + `ReconcileRecurringAlarms` self-heal on every launch
- Native Kotlin `system_capabilities` MethodChannel: FSI/exact-alarm checks, OEM autostart deep links, lock-screen flags
- Battery-exemption onboarding page + alarm reliability self-test page
- `AlarmRingPage` shown as a `MaterialApp.builder` overlay so it takes over from any navigation depth; back button blocked

**Pose verification (Phase 2 ✅ code-complete; hardware exit criterion never run)**
- Camera NV21 stream → ML Kit pose detection, frame-drop governor, calibration flow, joint-angle rep state machine (squat + push-up, unit-tested), skeleton `CustomPaint` overlay, permission-denied and no-pose states, accessibility escape hatch ("I can't do this exercise today")

**Offline-first sync (Phase 3 ✅)**
- Drift database (alarms, sessions, runs, territories, user_stats, sync_outbox) with a real v1→v2 migration
- `LocalWriter` — single transactional write-seam (domain write + outbox enqueue in one transaction), `SyncWorker` — connectivity-triggered drain with exponential `next_attempt_at` backoff
- Anonymous-auth-first guest flow (`EnsureAuthSession` per plan H8)

**Alarm ⇄ verification integration (Phase 4 ✅)**
- Ring → "Start workout to dismiss" → `VerificationPage` → `completeWorkout` → session logged through the outbox → celebration sheet
- Global per-user wake-up tax (×1.5 steps, capped ×4, reset on success; synced via `user_stats`)
- Streak computed from local sessions (`WatchCurrentStreak`), shown on home/profile

**Foundations (Phase 0 ✅)** — dev/prod flavors, get_it/injectable DI, M3-Expressive-style theme (motion/shape tokens, `dynamic_color`, `motor`), CI with 16KB-page smoke job, ADRs (BLoC, hand-rolled outbox).

**Packages present but entirely unused so far:** `flutter_foreground_task`, `geolocator`, `kalman_dr`, `flutter_map`, `latlong2`, `turf`, `wakelock_plus`, `sentry_flutter` (declared, no wiring found). These are all Phase 5/7 dependencies bought early.

# 2. Mock / presentation-only UI implementations

All from the "Design 2" Claude Design handoff (PR #1):

| Screen | What's fake |
|---|---|
| [territory_page.dart](lib/features/territory/presentation/pages/territory_page.dart) | Entire map — painted street grid, 3 hardcoded polygon blobs, static squad dots, "0.21 km² captured", inert center/layers buttons. Literally labeled "Map data placeholder" |
| [active_run_page.dart](lib/features/territory/presentation/pages/active_run_page.dart) | Whole run — 1-second timer simulates distance, loop "closes" after 8 s, captured area is `Random()`, no GPS at all |
| [territory_capture_sheet.dart](lib/features/territory/presentation/widgets/territory_capture_sheet.dart) | Celebration sheet fed by the fake capture |
| [squad_page.dart](lib/features/squad/presentation/pages/squad_page.dart) | 100% mock — fake members, static leaderboard, "Cheer" just shows a snackbar. No squad feature exists anywhere (client or DB) |
| [home_page.dart](lib/features/home/presentation/pages/home_page.dart) | Next alarm + streak are **real**; mocked: "0.21 km² owned", "#3 squad rank", 70% daily goal, achievements row, activity feed |
| [profile_page.dart](lib/features/profile/presentation/pages/profile_page.dart) | Streak real; reliability/battery rows route to real pages; **inert**: "Migrate to cloud", Notifications, Appearance, Sign out; "0.21 km²" territory tile |
| [onboarding_page.dart](lib/features/onboarding/presentation/pages/onboarding_page.dart) | No persisted has-seen flag — carousel shows on **every** cold start |
| [alarm_list_page.dart](lib/features/alarm/presentation/pages/alarm_list_page.dart) | Enabled/disabled toggle is presentation-only (not persisted) |

# 3. Docs & database review

I read `awaken_app_refined_plan.md` in full (the other two root docs are explicitly superseded background per CLAUDE.md; `docs/decisions.md` ADRs confirm BLoC + hand-rolled outbox). Supabase project **awaken-dev** (`qxxkydisyqnodskmymla`): 6 tables (`profiles`, `alarms`, `sessions`, `runs`, `territories`, `user_stats`), all RLS-enabled, 11 migrations, PostGIS relocated to `extensions` schema, `submit_run()` SECURITY DEFINER RPC in place, **no squad tables, no edge functions, zero rows**. The only security advisory is `submit_run` being callable by `authenticated` — intentional by design. Note the org also has an older unused "Awaken" project (`nankdbntvvopnfvvvaoo`) you may want to delete to avoid confusion.

**One known landmine for Phase 5** (recorded in my project memory): `LocalWriter.insertRun` sends `'path': pathGeoJson` as a raw GeoJSON string into `runs.path` which is PostGIS `geometry` — this will not auto-cast. It must go through `ST_GeomFromGeoJSON` (best: stop syncing runs via generic outbox upsert and route them through `submit_run()` instead).

# 4. Remaining implementation plan

You're at the end of Phase 4. Remaining work maps to plan Phases 5–8 plus a cleanup phase the plan doesn't have (because the mock UI shell didn't exist when it was written).

## Phase 5 — Territory (the big one, ~4–5 weeks)

**5a. Run-tracking engine (`features/territory/domain` + `data`)**
1. `RunTrackingRepository` interface: `startRun()`, `watchRunState()` (position, distance, loop-closed flag, GPS quality), `stopRun()`.
2. Foreground service via `flutter_foreground_task` 10.x (location type, while-in-use only — H3); persistent notification; `wakelock_plus` during active run; add `ACCESS_FINE_LOCATION` + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` to the manifest (background location stays out).
3. `geolocator` stream → `kalman_dr` EKF smoothing (pin exact version; add golden-trajectory tests against recorded GPS traces per plan §2.3 — this is the fork-readiness insurance).
4. Client gates: `Position.isMocked` discard, velocity gate (< ~7 m/s sustained), surfaced as a neutral "GPS quality" chip.
5. Loop-closure pre-check with `turf` (`start↔end < 30 m`, min length 400 m) — client-side UX only, server stays authoritative.
6. RDP simplification before upload.

**5b. Submission pipeline**
7. On capture: `LocalWriter.insertRun` locally, but replace the generic outbox upsert for runs with a dedicated outbox operation that calls `submit_run(p_run_id, p_path, …)` — this also fixes the geometry-cast bug above. Handle the RPC's rejected/accepted verdict → write `integrity_verdict`/`rejected_reason` back locally.
8. New use cases: `StartRun`, `StopRun`, `WatchRunState`, `SubmitRun`, `WatchTerritories`.
9. Territory read model: fetch own + nearby territories (add a `territories_in_bbox` RPC or PostGIS-backed view; `territories` is already public-read) into the Drift `territories` table for offline map rendering.

**5c. Real map UI**
10. Replace `TerritoryPage`'s painted mock with `flutter_map` 8 + `flutter_map_cancellable_tile_provider`; **pick a tile provider now** (C3 — MapTiler/Stadia free tier; never OSM public tiles); attribution overlay; offline "map unavailable — run still records" state.
11. Rewire `ActiveRunPage` to the real run state stream (keep the existing visual design — it's good); territory polygons from `geom` GeoJSON → `PolygonLayer` with culling; keep `TerritoryCaptureSheet` but feed it the RPC's real area delta.
12. Home/Profile: replace "0.21 km²" with a real `WatchOwnedArea` use case.

**Exit criterion:** a real outdoor run closes a loop, `submit_run` awards territory, it renders on the map, and a second account's overlapping run carves it via `ST_Difference`.

## Phase 6 — Squad & social (~3–4 weeks)

1. **DB migrations**: `squads` (id, name, invite_code, created_by), `squad_members` (squad_id, user_id, joined_at, unique per user for v1), RLS (members read their squad; join via invite-code RPC to avoid enumerable squads), leaderboard as a polled RPC/view computing `ST_Area(geom::geography)` per member.
2. **Client feature stack**: `SquadRepository` (create/join/leave, watch members, poll leaderboard), profile `display_name`/`territory_color` editing (profiles table already supports it).
3. **Realtime, budgeted (H6)**: Presence for online status; Broadcast for live workout/run status at ≤1 message per 2–3 s aggregate state; "Cheer" as a broadcast event. Polling (60 s+) for the leaderboard — never realtime.
4. Rewire `SquadPage` (empty/no-squad state + create/join flow are new screens the mock doesn't have), home page squad rank + activity feed (derive feed from sessions/runs/territory events), streak tiers (`profiles.streak_tier` exists but nothing updates it — add trigger or client logic).

## Phase 6.5 — Auth & mock-UI debt (can overlap 5/6, ~1–2 weeks)

The plan's H8 second half plus every inert control:
1. **Account linking**: "Migrate to cloud" → link email/Google OAuth to the anonymous user (`linkIdentity` — same uid, zero re-keying); Sign out with a "guest data stays on device" warning; the Phase 3b offline-first-launch re-key fallback TODO in `main_common.dart`.
2. Onboarding has-seen flag (simple key-value store or Drift settings table) + move the blunt `Permission.notification.request()` into a proper rationale step in the carousel (plan §5).
3. Alarm enabled-toggle persistence; Notifications & Appearance settings screens (or cut them — decide, don't ship inert rows).
4. Pull-down sync: on fresh install after sign-in, hydrate Drift from Supabase (today sync is push-only — a reinstall loses alarms/streak even though the cloud has them).

## Phase 7 — Hardening & Play compliance (~3 weeks)

- Play Console workstream: alarm-app categorization, FSI declaration, FGS-location declaration **with demo video** (record it from the Phase 5 flow early), data-safety form, prominent location disclosure.
- Play Integrity verdict attached to suspicious run submissions (H7).
- Wire up `sentry_flutter` (it's in pubspec, unused) with alarm-failure breadcrumbs; missed-alarm telemetry.
- Patrol E2E (permission matrices, alarm-from-terminated, run FGS); pgTAP tests for `submit_run` (closure, self-intersection, area floors, RLS denial).
- The two deferred hardware exit criteria: **Phase 1** (alarm survives kill + 30 min screen-off on ≥4 physical devices incl. Xiaomi/Samsung) and **Phase 2** (20 squats ≥95% accuracy, 5 body types, <45 °C on a Snapdragon 6-series). These are release blockers that no amount of code closes — schedule real devices.
- Edge-to-edge/`SafeArea` audit, TalkBack pass on ring + verification screens, battery/thermal profiling on Impeller.
- Create the real prod Supabase project + `.env` split (`main_prod.dart` TODO), or decommission the stray "Awaken" project.

## Phase 8 — Launch

Internal → closed → open testing → staged production rollout. Post-launch: medium/expanded layouts, more exercise types, daily-goal + achievements as real domain concepts (currently pure mock — I'd cut them from v1 UI or back them with sessions data cheaply).

**Recommended order:** 5a → 5b → 5c → 6.5 (overlapping) → 6 → 7 → 8. Territory first because it's the largest unknown (GPS/FGS/OEM behavior needs real-world iteration time), squad depends on territory areas for its leaderboard, and 6.5 is parallelizable filler work. Want me to start on Phase 5a (the run-tracking foreground service + geolocator/EKF pipeline)?