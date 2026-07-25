## Context

`CODEBASE_SUPABASE_REVIEW.md` documents ~100 findings across the Awaken codebase and the live `awaken-dev` Supabase project. Every Critical/High finding was independently re-verified against actual source (file:line) and live DB state (`pg_proc.proconfig`, `pg_policies`, advisors) in this conversation — confirmed accurate with only minor phrasing nuances on a few Medium items. The app is not release-ready: three mission-critical loops (alarm, territory/anti-cheat, offline sync) have correctness/security defects, plus a live-exploitable cross-account data leak and a broken backend RPC (`submit_run` search_path). This plan sequences fixes so the most dangerous/broken things land first, backed by current best-practice research (Supabase docs, Postgres/RLS guidance, `flutter_foreground_task`/Android 14 requirements, Sentry Flutter docs, OSM attribution rules, offline-sync outbox patterns).

Goal: take the app from "several release blockers, live security bugs" to "hardened, testable, source-controlled" — DB first (it's live and actively wrong), then the three mission-critical client loops, then sync/outbox correctness, then UI/UX/accessibility polish, then dependency cleanup.

---

## Phase 0 — Source-control the backend + unblock testing (do first, low risk)

1. **Pull the 17 deployed migrations into the repo.** Use `mcp__5d4f3e29…__list_migrations` / Supabase CLI (`supabase db pull`) to create `supabase/migrations/*.sql` checked into git. Every fix below becomes a new migration file from this point on — no more direct `execute_sql`/`apply_migration` without a corresponding committed file.
2. **Fix the failing test.** `lib/features/alarm/presentation/pages/alarm_list_page.dart:375` (`_RiseInState.initState`'s `Future.delayed`) — store the timer, cancel it in `dispose()`. Unblocks `flutter test` going green, which every later phase depends on for regression safety.
3. **Initialize Sentry.** `sentry_flutter: ^9.25.0` is already a dependency but never called. Per current Sentry Flutter docs: call `SentryFlutter.init()` wrapping `bootstrap()`'s body in `main_common.dart`, set `tracesSampleRate` conservatively, and use `beforeSend` to strip GPS coordinates/camera frame data before events leave the device (the plan explicitly requires this — no raw paths/frames in telemetry). Wire it to catch the pre-`runApp()` exceptions fixed in Phase 1 item 1.

## Phase 1 — P0: Live security & correctness blockers

### 1a. Database (do first — it's live and actively broken)

- **Fix `search_path` on `submit_run()` and `territories_set_area()`.** Confirmed live: both have `search_path="public, extensions"` as one malformed quoted literal instead of two schema entries — `ST_*` calls likely fail today. Per Supabase/Postgres current guidance, the recommended fix is `SET search_path = ''` with every reference fully qualified (`extensions.ST_MakeValid`, `public.territories`, etc.) — safer than the two-schema form because it removes resolution ambiguity entirely rather than just fixing the string. Ship as a migration; add a smoke-test migration/SQL call that inserts a real closed run and asserts `territories_set_area()`'s trigger fires without error.
- **Add server-side anti-cheat validation to `submit_run()`.** Currently only checks auth/geometry-type/length/closure. Add: per-segment speed cap (requires per-point timestamps — see client change below), timestamp monotonicity, coordinate bounds, min/max point count, payload size cap. PostGIS pattern: compute consecutive-point speed from `ST_Distance(geography)` / time-delta between points in the submitted array server-side, reject if it exceeds a plausible running speed.
- **Make `submit_run()` idempotent on `p_run_id`.** Change the insert to `ON CONFLICT (id) DO UPDATE`-style upsert or an early `SELECT ... WHERE id = p_run_id` check that returns the existing authoritative result instead of erroring on duplicate delivery — required for the outbox retry fix in Phase 2.
- **Lock down client-writable authoritative columns.** RLS confirmed: `profiles_update_own` and `user_stats_all_own` are row-scoped only, no column restriction — `squad_id`, `streak_tier`, `current_tax_multiplier` are directly writable. Per Supabase's own guidance, RLS cannot restrict columns; the documented approach is Postgres column-level `GRANT`/`REVOKE` (`REVOKE UPDATE (squad_id, streak_tier) ON public.profiles FROM authenticated`, similarly for `user_stats.current_tax_multiplier`) combined with dedicated `SECURITY DEFINER` RPCs (already have `join_squad`/`leave_squad`) that are the only path to change those columns.
- **Make squad Realtime channels private + add `realtime.messages` RLS.** Per current Supabase Realtime Authorization docs: client subscribes with `private: true`; add RLS policies on `realtime.messages` keyed off `profiles.squad_id` membership, checking `realtime.messages.extension = 'broadcast'`/`'presence'` appropriately. Update `squad_remote_datasource.dart:54`'s `channel()` call to pass `RealtimeChannelConfig(private: true)`.
- **Harden `squad_reports`.** Add a check (RLS `WITH CHECK` or trigger) that `reporter_id`'s squad matches the reported member's squad, not just `reporter_id = auth.uid()`.
- **Repair account-deletion FK ordering.** In the `delete-account` Edge Function (source doesn't exist in-repo — pull it via `list_edge_functions`/`get_edge_function` first, then add it to source control under `supabase/functions/`): resolve `profiles.squad_id` (transfer/dissolve ownership) and delete `squad_reports` rows referencing the user before deleting `squads`/`profiles`.
- **Revoke unnecessary public execute grants** on `recompute_streak_tier()` (anon-executable per advisor) and tighten the other flagged `SECURITY DEFINER` RPC grants to `authenticated` only where appropriate.
- **Performance advisor cleanup** (low-risk, bundle into the same migration pass): add missing FK indexes (`profiles.squad_id`, `sessions.alarm_id`, `squad_reports` FKs, `squads.owner_id`); rewrite the 9 flagged RLS policies to use `(select auth.uid())` instead of bare `auth.uid()` for the init-plan optimization.
- **Enable leaked-password protection** in Supabase Auth settings.

### 1b. Client — data ownership & account transitions (Critical, cross-account leak)

- **Add an owner column to every local table + the outbox**, and partition all local reads/writes by it. Confirmed: `sync_outbox_table.dart` has no owner column; `sync_worker.dart:105` stamps whichever `auth.uid()` is active at drain time. Add `TextColumn get ownerId => text()()` to `SyncOutbox`, `AlarmsTable`, `SessionsTable`, `RunsTable`, `TerritoriesTable`, `UserStatsTable` (Drift migration bump), populate it at write time (`local_writer.dart`) from the currently authenticated user, and scope every query (`watchAlarms`, outbox drain, pull) by `ownerId == currentUserId`.
- **Define and implement account-transition semantics.** New use case (e.g. `ClearLocalUserData`) called from both `SignOut` (`lib/features/profile/domain/usecases/sign_out.dart`) and `DeleteAccount` (`delete_account.dart`) before/after the remote call: cancel all native alarms (loop `Alarm.stop()`/checked, per Phase 1c), stop `SyncWorker`/`RunTrackingCubit` if active, wipe or filter local Drift tables to the outgoing owner, close squad Realtime channels, clear cached squad/channel state (`squad_repository_impl.dart`'s `_cachedSquad`/`_channels` maps — confirmed to survive auth changes).

### 1c. Client — alarm reliability (Critical/High)

- **Make preview side-effect-free.** `alarm_ring_page.dart:96` calls `cubit.completeWorkout(...)` unconditionally. Add a preview-only completion path in `AlarmCubit`/`CompleteAlarmWorkout` (or a new `PreviewCompleteWorkout` no-op use case) that skips native `Alarm.stop()`, recurrence advance, session insert, and tax mutation when `isPreview == true`.
- **Check every `Alarm.set()`/`Alarm.stop()` result.** `alarm_repository_impl.dart:158,196,210,216,229` discard the `Future<bool>`. Capture the result, throw/return a typed `Failure` on `false`, surface it as a user-visible reliability warning (ties into the existing self-test UI).
- **Fix `nextOccurrenceAfter()`** (`alarm_schedule.dart:46-60`) to consider `from`'s own day (loop from `daysAhead = 0`, guard against returning a time already in the past for today only when appropriate) so same-day startup repair works.
- **Replace UUID `hashCode` native IDs** (`alarm_payload.dart:51-54`) with a persisted stable integer — add an `IntColumn get nativeId => integer().autoIncrement()()`-backed mapping table or reuse the Drift row's own autoincrement id, generated once at alarm creation and never derived from `hashCode` again.
- **Decouple local rearm from network/auth.** In `main_common.dart:62-73`, split the single `try/catch` into two: local `RearmAlarmsFromCache` runs unconditionally first; `EnsureAuthSession`/`PullDownSync` run in their own try/catch afterward so a network failure can't block offline alarm recovery.
- **Exclude the currently-ringing alarm from reconciliation** (`reconcile_recurring_alarms.dart`) by checking `watchRingingAlarm()`'s current value before rescheduling.
- **Wrap `AlarmPayload.fromJson`** (`alarm_payload.dart:30-41`) in try/catch, skip/log malformed rows instead of throwing inside the `watchAlarms()` stream listener.
- **Set `allowSameSecondScheduling: true`** in the `AlarmSettings` construction (`alarm_repository_impl.dart:48-69`).

### 1d. Client — territory/run tracking (Critical, Android-blocking)

- **Add the manifest foreground-service declaration.** Per current `flutter_foreground_task`/Android 14 docs: add `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService" android:exported="false" android:foregroundServiceType="location" />` inside `<application>` in `android/app/src/main/AndroidManifest.xml` (currently completely absent — confirmed).
- **Reorder permission-before-service-start.** `run_tracking_repository_impl.dart:61-81` starts `_foregroundService.start()` before `provider.start()` requests permission. Swap: request/verify location permission first (surface a guided rationale if denied), only then start the foreground service.
- **Implement the actual foreground task handler.** `run_foreground_service.dart:16-25`'s `onStart/onRepeatEvent/onDestroy` are empty. Move GPS collection into the `TaskHandler` (per the plugin's documented pattern) so tracking survives main-isolate/activity loss, with `sendDataToMain`/port communication back to the UI isolate for live display, and persist checkpoints so a killed process doesn't lose the in-progress path.
- **Add per-point timestamps to the run payload.** `TrackPoint` already has `timestamp` (`track_point.dart:9`), but `PathSimplifier`/`territory_remote_datasource.dart`/`sync_worker.dart:_pushRun` strip it before sending. Change the GeoJSON/JSON payload to carry `[lng, lat, epoch_ms]` or a parallel timestamps array so the server-side speed check (Phase 1a) has data to validate against.
- **Add comprehensive start-failure cleanup** in `run_tracking_repository_impl.dart` — wrap `_foregroundService.start()` and `WakelockPlus.enable()` in the same try/catch as the permission check, calling a `_teardown()` on any failure so no leaked wakelock/service/`isTracking:true` state survives an error.
- **Cancel `RunTrackingCubit`'s subscription** in `close()` (currently never stored/cancelled).
- **Wrap `_busy = true/false` in try/finally** in `active_run_page.dart:166-201`'s `_capture`.

## Phase 2 — P1: Sync/outbox reliability & convergence

- **Idempotent run retry**: once `submit_run()` is idempotent (Phase 1a), `sync_worker.dart:_pushRun` can safely resend on ambiguous network failure without special client-side dedup logic — verify with a test that double-calls `_pushRun` for the same `p_run_id`.
- **Wake the worker when `nextAttemptAt` becomes due**, not only on connectivity toggle — add a periodic check (e.g. `Timer.periodic` at a coarse interval, or reschedule a single `Timer` to the earliest due `nextAttemptAt` after each drain) in `SyncWorker`.
- **Preserve per-entity mutation order.** In `drainOutbox()`'s loop, group `due` by `(entityTable, entityId)` and stop processing later entries for an entity once an earlier one for that same entity fails in this pass, instead of the current flat unordered attempt-everything loop.
- **Add error classification + dead-letter handling.** Add an `errorType`/`lastError`/`maxAttempts` set of columns to `SyncOutbox` (Drift migration); on permanent-looking failures (e.g. HTTP 4xx / constraint violation) stop retrying and surface via `SyncStatus`; keep retrying only transient (network) failures.
- **Fix `sessions.completedAt` nullability mismatch** — either allow `NULL` on the live `sessions.completed_at` column for skipped sessions (migration) or stop creating local skipped-session rows with a null `completedAt` and use a sentinel/synthetic timestamp instead — pick whichever matches the actual product semantics for "skipped" (recommend relaxing the server constraint since a skip is a legitimate real event).
- **Replace one-time pull hydration with incremental convergence.** `pull_down_sync.dart`'s `hasLocalAlarms` early-return prevents any future re-pull. Track a `lastPulledAt` watermark per table, always attempt a delta pull (`updated_at > lastPulledAt`) on each sync cycle, and extend pull to cover `sessions`/`runs`, including soft-delete tombstones.
- **Territory cache reconciliation**: add `deletedAt` to `TerritoriesTable` (matches the backend's soft-delete column), apply it during territory refresh, and evict/limit cached rows outside the current viewport instead of unbounded accumulation (`territory_page.dart`).
- **Fix first-backoff math.** `_backoffDelay`'s `1 << attempt` with `attempt = entry.attemptCount + 1` starting at 1 doubles the nominal initial delay on the very first retry. Change to `1 << (attempt - 1)` (or start `attemptCount` semantics at 0-indexed) so the first retry actually waits `syncInitialBackoff`.
- **Add an index + `LIMIT`** to the outbox due-query (`sync_outbox_table.dart`, `sync_worker.dart:63-66`).
- **Implement functional squad Presence/Broadcast reception.** Add an `onBroadcast` listener in `squad_remote_datasource.dart` wired to a stream the `SquadCubit`/UI consumes, and call `trackPresence()` from `RunTrackingCubit`/`VerificationCubit` (currently defined but never invoked) — do this only after Phase 1a's private-channel/RLS work so it's not exposing more than it should.
- **Fix channel retain/release accounting** so `trackPresence`/`broadcastTelemetry` participate in the same ref-count as `watchPresenceState`, preventing premature channel teardown.
- **Verification lifecycle hardening**: add `WidgetsBindingObserver` to `VerificationPage`/camera datasource for inactive/resumed transitions; store and cancel `VerificationCubit.begin()`'s subscription; add an error/retry/escape state for the `initializing` phase instead of an indefinite spinner; add a generation token so stale in-flight frames can't affect a restarted session.
- **Tighten rep-counting accuracy** (`rep_counter.dart`): add minimum hold duration, consecutive-frame confirmation, and a cooldown between reps; fix multi-plane YUV handling in the fallback path (`pose_mapper.dart:54`, use all planes not just `.first`) per ML Kit's documented multi-plane image format requirements; fix skeleton-painter scaling to account for `CameraPreview`'s actual crop/fit rather than naive stretch.

## Phase 3 — P2: UI/UX, accessibility, maintainability

- **Remove the fabricated daily-goal card** (`home_page.dart:83-84,316-328`) or wire it to a real use case if the feature is wanted — don't ship hardcoded 70%/"14/20 squats" with a dead chevron.
- **Fix `_nextAlarm()`** (`home_page.dart:38-43`) to filter by `isActive` and real eligibility before picking the "next" alarm.
- **Add error states to Home's `StreamBuilder`s** instead of `?? 0`/`?? []` masking failures as legitimate zero data.
- **Move Home/Profile/Onboarding async flows into Cubits** (matches the existing `ThemeModeCubit` pattern already used elsewhere) instead of calling use cases directly from `StatelessWidget`s via `getIt`.
- **Replace raw exception display** (`profile_page.dart`'s `Text('$e')` in three places, squad create/join/report dialogs) with mapped, typed `Failure` messages.
- **Add proper `Form`/validation/autofill hints/submission-locking** to the email-link dialog (`profile_page.dart:390-431`).
- **Fix the "on this device only" copy** (`profile_page.dart:126`) to accurately describe anonymous-but-synced storage.
- **Fix dead `Continue` button** on `BatteryExemptionPage` when opened from Profile (`battery_exemption_page.dart:17,176`) — supply a no-op or "back" callback for that entry point.
- **Move battery-exemption + notification-rationale + reliability-test into first-run onboarding** (`onboarding_page.dart`), showing rationale before the OS permission prompt (reorder `main_common.dart:47`'s `Permission.notification.request()` to fire from onboarding instead of bootstrap).
- **Gate Android-only battery copy/controls behind `Platform.isAndroid`** on the generic body text, not just the OEM-specific block.
- **Add `MediaQuery.of(context).disableAnimations` checks** to `ExpressiveFlower`, onboarding's `AnimatedContainer`, and verification/alarm animations.
- **Add `Semantics(liveRegion: true)`** around dynamic rep-count/status text in `verification_page.dart`.
- **Make OSM attribution continuously visible**, not tap-to-reveal — per OSMF's guidance that mobile apps may use a startup splash/one-time interaction only if the ongoing map view doesn't otherwise show it; safest compliant fix is switching MapLibre's `attributionButtonPosition` usage to render the attribution text directly on-screen rather than behind the info-button tap target (`territory_page.dart:236-237`, `active_run_page.dart:283-284`).
- **Add map style-load/offline error state** to `territory_page.dart`/`active_run_page.dart` (`onMapError`/style-load failure handling currently absent).
- **`TerritoryPage`: route location access through the domain `LocationProviderFactory`** instead of importing `geolocator` directly.
- **De-duplicate `TerritoryRemoteDatasource.submitRun()`** — since it's dead code (only `sync_worker.dart` actually calls the RPC), delete it or make `sync_worker.dart` call through it instead of re-implementing.
- **Debounce/cancel-in-flight viewport bbox requests**, add antimeridian-safe bounds handling, and paginate/cap `territories_in_bbox` server-side (ties into Phase 1a's RPC hardening).
- **Confirmation dialog + loading/error state for "Leave squad"** (`squad_page.dart:456`, `squad_cubit.dart:81-83`).
- **Distinguish backend/network failure from "no squad" state** in `squad_cubit.dart`'s `_refreshMySquad` catch block.
- **Add wide-layout/breakpoint/keyboard-nav tests** for `app_shell_page.dart` (none currently exist).

## Phase 4 — Dependency & maintenance cleanup (low risk, do last)

- Remove unused `turf` and `motor` (zero imports confirmed).
- Document the `flutter_fgbg: 0.7.1` override's exact compatibility reason and removal condition, or resolve it and drop the override.
- Pin `kalman_dr` to an exact version (`0.4.4`, no caret) per the plan's stated requirement.
- Evaluate `sqlite3_flutter_libs` removal now that Drift/sqlite build hooks can bundle SQLite directly (EOL package).
- Defer major-version bumps (`connectivity_plus`, `get_it`, `google_fonts`, `injectable`, `latlong2`, `patrol`) to isolated PRs after the above phases are green, each with its own platform/build/test validation pass.
- Fix `main_prod.dart` once a separate prod Supabase project exists (tracked but blocked on infra decision — flag to user, don't silently point prod at dev longer than necessary).

## Verification

- After Phase 0: `flutter test` fully green; Sentry receiving a manually-triggered test event.
- After Phase 1a: run the SQL smoke test for `submit_run`/`territories_set_area` via `execute_sql`; re-run `get_advisors(type: security)` and confirm the anon/authenticated `SECURITY DEFINER` and column-writability warnings are gone or intentionally accepted; attempt a direct `profiles.squad_id` update as a non-privileged test JWT and confirm it's rejected.
- After Phase 1b/1c/1d: new widget/unit tests per §8.3 of the review (preview side-effect test, same-day recurrence test, sign-out/delete-account local-data-cleared test, FGS manifest present via `flutter build apk` manifest inspection) — build out incrementally, don't require all of §8.3 before shipping each fix.
- After Phase 1d: manual device test — force-kill during an active run, confirm the path persists (this specifically needs real Android hardware per the plan's Phase 1 exit criterion).
- After Phase 2: manual test of the sign-out → different-account → sign-in flow with pending outbox rows, confirming no cross-account data appears.
- After Phase 3: run through onboarding → alarm → verification → run → squad flows in the Browser/device preview tool with a screen reader and at 200% text scale.
- Throughout: `flutter analyze` stays clean; every new migration gets committed to `supabase/migrations/` (Phase 0 item 1) so the schema is reproducible from source control from this point forward.
