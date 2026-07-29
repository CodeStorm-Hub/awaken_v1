# Hardening Session Status — Handoff Notes

**Purpose:** Record of what was implemented across the hardening session(s) that worked through
`CODEBASE_SUPABASE_REVIEW.md`, and an explicit list of what's still open. Written so a new session
can pick up directly without re-deriving context. Findings were re-verified against actual current
source on 2026-07-26 (not just checked off from memory) — see verification notes per item.

**Scope excluded by explicit user direction:** Appium-based automated test infrastructure and
anything requiring physical iOS hardware. These remain open and are called out below where they
intersect a finding.

---

## 1. What was implemented this session

### Territory capture — real bugs found via live user bug report (2026-07-26, outside the original review)
User reported a completed, closed-loop run not showing up as captured territory, with screenshots.
Two compounding bugs found and fixed:
- **`SyncWorker.drainOutbox()`'s connectivity pre-check could false-negative.** It gates on
  `ConnectivityWatcher.isOnline` — a local `connectivity_plus` network-interface check, not actual
  reachability, which can report stale/wrong right after a network transition.
  `RunTrackingRepositoryImpl.captureRun()`'s synchronous best-effort push (right after a run is
  saved, while the user is actively watching) relied on this gate and silently fell through to the
  "will sync once back online" pending state even while genuinely online. Fixed with a
  `skipConnectivityCheck` param on `drainOutbox()`, used only at this interactive call site — the
  periodic/background drain keeps the optimization. (`sync_worker.dart`,
  `run_tracking_repository_impl.dart`.)
- **`TerritoryPage` never refreshed on return from a run.** Even with a successful `submit_run()`,
  the local territories cache only refreshes on camera movement (`onCameraIdle`) — a captured
  territory stayed invisible until the user happened to pan/zoom. `submit_run()` also doesn't write
  the local territories cache directly (only the `runs` row); the bbox pull is what actually brings
  the new/updated territory down. Fixed by awaiting the `Navigator.push` to `ActiveRunPage` and
  refreshing territories + rival/at-risk state immediately on return. (`territory_page.dart`.)
- **`TerritoryPage` and `ActiveRunPage` could show two different "current location"s for the same
  device**, caught from a second user report with screenshots. Root cause:
  `LocationProviderFactory.getCurrentPosition()` (used to center the territory map) called
  `Geolocator.getCurrentPosition()` directly — a one-shot call Android's `FusedLocationProviderClient`
  is documented to allow answering from a cached recent fix instead of forcing a new acquisition —
  while `ActiveRunPage` reads a continuous position *stream* (via the same factory's `create()`),
  which can't serve a stale cached value the same way. Fixed by routing the one-shot call through
  the identical `LocationProvider` stream (taking its first emission, 10s timeout), so both screens
  now always read from the same underlying source and can no longer disagree. Side benefit: this
  also closes a minor anti-cheat inconsistency — the live stream already discards
  platform-flagged-mocked positions (H7); the one-shot call previously didn't.
  (`location_provider_factory.dart`.)

**Verification:** `flutter analyze` and the full `flutter test` suite (57 tests) both clean after
each fix. The connectivity/refresh-on-return fixes were **not** confirmed via a live end-to-end
capture — the Android emulator used this session discards all `adb emu geo fix`-injected positions
(`GeolocatorLocationProvider._onPosition`'s `isMocked` anti-cheat filter, by design) and separately
had `FusedLocationProvider` throttling injected fixes ("too fast"/"too close") even when spaced out,
so a real closed-loop run couldn't be driven through the emulator this session. **The user should
verify on their own device** (where the original report came from) after rebuilding.

### Alarm feature (`lib/features/alarm/`)
- **Preview is now side-effect-free.** `AlarmListPage` opens `AlarmRingPage(isPreview: true)`;
  `AlarmRepositoryImpl.completeWorkout(..., isPreview: false)` returns immediately via
  `if (isPreview) return;` before touching native alarm state, recurrence, session logging, or tax.
  (`alarm_list_page.dart:191-193`, `alarm_repository_impl.dart:352-359`, threaded through
  `alarm_cubit.dart:67-74`.)
- **`nextOccurrenceAfter()` fixed** to loop from `daysAhead = 0` (today included), fixing same-day
  startup repair. (`alarm_schedule.dart:57-58`.)
- **Native alarm IDs** now derived via FNV-1a hash over UTF-8 bytes instead of `String.hashCode`.
  (`alarm_payload.dart:61-68`.)
- **`Alarm.set()`/`Alarm.stop()` results checked** — wrappers throw `AlarmOperationFailure` on
  `false`; a best-effort variant reports failures to Sentry instead of silently discarding them.
  (`alarm_repository_impl.dart:50-83`.)
- **Startup reconciliation excludes the currently-ringing alarm** so it can't be clobbered mid-ring.
  (`alarm_repository_impl.dart:419-436`.)
- **Local cache rearm decoupled from auth/network** — `RearmAlarmsFromCache` now runs in its own
  try/catch, separate from `EnsureAuthSession`/`PullDownSync`, so offline local recovery still
  works. (`main_common.dart:147-177`, explicitly commented as the P0 fix.)
- **`allowSameSecondScheduling: true`** set on `AlarmSettings`. (`alarm_repository_impl.dart:134`.)
- **Malformed/legacy alarm payloads no longer crash `watchAlarms()`** — `fromJson` wrapped in
  try/catch, reports to Sentry and skips the bad row instead of throwing into the stream.
  (`alarm_repository_impl.dart:156-167`.)
- **Real bug found and fixed mid-session (not in the original review):** `_AlarmRingOverlay` could
  paint over a *real* ringing alarm's own pushed `VerificationPage` forever, making genuine alarms
  undismissable. Fixed via a new `AlarmState.verificationInProgress` flag.
- **Real bug found and fixed mid-session:** `MediaQuery.disableAnimationsOf(context)` was being
  called from `initState()` in `alarm_ring_page.dart` and `verification_page.dart`, which throws
  (`dependOnInheritedWidgetOfExactType` requires `didChangeDependencies()` or later). Fixed by
  moving the check + animation start into `didChangeDependencies()` with a `_startedAnimating` guard
  in both files.
- **New: Alarm-dismiss "lockdown" via Android Screen Pinning.** Per explicit user request to make
  the alarm harder to bypass (full Device-Owner/kiosk mode was explained as infeasible for a normal
  Play Store app and explicitly declined by the user in favor of this): added
  `startAlarmLockdown()`/`stopAlarmLockdown()` to the native `system_capabilities` MethodChannel
  (`MainActivity.kt`, wrapping `startLockTask()`/`stopLockTask()`), exposed through
  `SystemCapabilities`, `AlarmRepository.engageRingLockdown()`/`releaseRingLockdown()`, and two new
  use cases (`engage_alarm_lockdown.dart`, `release_alarm_lockdown.dart`). Wired into
  `_AlarmRingOverlay` in `app.dart` via a `BlocConsumer` listener keyed off ringing-alarm
  transitions, engaged for the whole ring→verify loop. **Live-verified** on emulator: real OS
  "App is pinned" dialog appears, ring/verify flow works pinned, unpins cleanly on completion/skip.

### Pose verification (`lib/features/verification/`)
- **`VerificationCubit` subscription leak fixed** — subscription stored and cancelled before each
  new `begin()`. (`verification_cubit.dart:37,63,65,110`.)
- **Camera lifecycle handled** — `WidgetsBindingObserver` added to the verification page; pauses/
  resumes the camera and cubit session on app inactive/paused/hidden/resumed.
  (`verification_page.dart:47-74`, `verification_cubit.dart:94-106`,
  `camera_datasource.dart:49-57`.)
- **Init failure/retry/escape states added** — `_InitializingView`/`_CameraErrorView` with retry and
  an escape path, replacing the indefinite spinner. (`verification_page.dart:95-166`.)
- **Generation token added** so in-flight frames from a stopped/replaced session can't emit stale
  results. (`pose_verification_repository_impl.dart:39,46,73,88-91`.)
- **Rep counting hardened** — minimum-hold-duration, consecutive-frame confirmation, and a cooldown
  between reps added to `AngleRepCounter`. (`rep_counter.dart:74-136`.)
- **Multi-plane YUV fallback fixed** — all planes concatenated for `yuv420` instead of just the
  first. (`pose_mapper.dart:68-83`.)
- **Live-region semantics added** for the status banner and rep counter.
  (`verification_page.dart:296-297, 421-423`.)

### Territory / run tracking (`lib/features/territory/`)
- **Android foreground-service manifest declaration added.**
  (`AndroidManifest.xml:59-62`, `foregroundServiceType="location"`.)
- **Permission-before-service-start ordering fixed** — location permission requested before the
  foreground service starts. (`run_tracking_repository_impl.dart:135-149`.)
- **Per-point timestamps now sent to the server** — `track_point.dart`, `path_simplifier.dart`,
  and `sync_worker.dart` (`p_point_timestamps`) carry timestamps through to `submit_run()`.
- **Start-failure cleanup added** — `_foregroundService.start()`/`WakelockPlus.enable()` wrapped
  with a `_teardown()` on failure so no leaked wakelock/service/state survives an error.
  (`run_tracking_repository_impl.dart:143-155`.)
- **`RunTrackingCubit` subscription leak fixed** — cancelled before re-subscribing and in `close()`.
  (`run_tracking_cubit.dart:49-50,71-77`.)
- **Territory cache soft-delete reconciliation added** — `deletedAt` column plus tombstone/
  reappear-clear logic. (`territories_table.dart`, `territory_repository_impl.dart:67-96`.)
- **Capture UI `_busy` flag now reset in `finally`.** (`active_run_page.dart:167-216`.)
- **OSM attribution now always visible**, not tap-to-reveal. (`territory_page.dart:335-349`,
  `active_run_page.dart:306-312`.)
- **Map style-load failure state added** — 15s timeout surfaces a failure UI.
  (`territory_page.dart:53-61`.)
- **`TerritoryPage` no longer imports `geolocator` directly** — goes through the domain
  `GetCurrentPosition` use case.
- **Duplicate `TerritoryRemoteDatasource.submitRun()` removed** — only `SyncWorker._pushRun` submits
  runs now.
- **Stale-response guard added for viewport bbox refresh** (monotonic `_refreshRequestId`), though
  note: no debounce was added — see Remaining Gaps.
- **New this session — Territory v2 (decay/bounty/rivalry):** `submit_run()` rewritten to bump
  `territories.last_defended_at` on own-territory create/merge, log `territory_captures` rows,
  apply bounty-zone multipliers as separate response fields (never scaling the stored polygon),
  update `profiles.last_run_location`. New `active_bounty_zones()` RPC. New client-side entities
  (`rival.dart`, `territory_at_risk.dart`, `bounty_zone.dart`), repository methods, use cases, and
  UI (bounty-zone map layer, at-risk banner, rival card on `territory_page.dart`; bounty badge on
  `territory_capture_sheet.dart`; bonus area folded into capture display on `active_run_page.dart`).
- **New this session — antimeridian-safe bbox queries** — `territories_in_bbox()` rewritten to
  split into two envelopes when `min_lng > max_lng` (viewport straddling ±180°), using
  `OPERATOR(extensions.&&)` (required because bare `&&` doesn't resolve under `search_path=''`).
  Live-verified both normal and wraparound cases.
- **New this session — squad leaderboards:** nearby/global × all-time/weekly leaderboard RPCs, repo
  methods, use cases, and a leaderboard sheet on `squad_page.dart`.

### Supabase backend (see `supabase/migrations/`, now checked into git)
- **`search_path` fixed** on `submit_run()` and `territories_set_area()` — was a malformed
  single-string `'public, extensions'`; now `set search_path = ''` with every reference fully
  qualified (`extensions.ST_*`, `public.*`).
  (`20260725031613_fix_search_path_and_harden_submit_run.sql:8-18,20-34`.)
- **Server-side anti-cheat validation added to `submit_run()`** — coordinate bounds, per-segment
  speed/timestamp checks, aggregate average-speed gate, payload size/point-count bounds.
  (same migration, lines 82-139.)
- **`submit_run()` made idempotent** — looks up `p_run_id` and returns the stored authoritative
  result on retry instead of erroring. (same migration, lines 66-80.)
- **Authoritative columns locked down** — `profiles.squad_id`/`streak_tier` and
  `user_stats.current_tax_multiplier` are no longer client-writable (column-level `REVOKE` +
  dedicated RPCs `bump_wake_up_tax()`/`reset_wake_up_tax()`).
  (`20260725031839_...sql`, `20260725031930_...sql`, `20260725032045_...sql`.)
- **RLS/index performance hardening** — all flagged policies rewritten to `(select auth.uid())`;
  missing FK-covering indexes added. (`20260724221744_rls_initplan_and_fk_index_hardening.sql`.)
- **`squad_reports` hardened** — insert policy now requires reporter and reported user to currently
  share the same `squad_id`, not just `reporter_id = auth.uid()`.
  (`20260725031839_...sql:20-33`.)
- **Squad Realtime made private** — client channel uses `RealtimeChannelConfig(private: true)`;
  a `realtime.messages` SELECT policy scoped to the caller's `profiles.squad_id` was added.
  (`squad_remote_datasource.dart:102-105`, `20260725035115_squad_realtime_authorization.sql:9-17`.)
- **`sessions.completed_at` made nullable** to match legitimate locally-skipped sessions.
  (`20260726000012_sessions_completed_at_nullable.sql`.)
- **Account-deletion Edge Function pulled into source control and fixed** —
  `supabase/functions/delete-account/index.ts` now explicitly resolves squad ownership/reports
  before deleting squads/profile, fixing the FK-ordering failure for squad owners and report
  participants.
- **All 17+ deployed migrations pulled into `supabase/migrations/*.sql`** and are now
  source-reviewable/reproducible (was previously entirely undocumented in-repo).

### Sync / outbox (`lib/sync/`)
- **Account-transition data ownership fixed** (no per-row owner column, but full-wipe strategy
  adopted as the accepted alternative for this single-active-identity app):
  `AppDatabase.clearAllLocalData()` wipes `syncOutbox`/`sessions`/`runs`/`territories`/`alarms`/
  `userStats`/`runCheckpoints`/`syncMeta` in one transaction. Called from
  `AuthRepositoryImpl._clearIdentityState()` on `signInWithPassword`, `signInWithGoogle`,
  `signOut`, and `deleteAccount` — and that same method now also **cancels all native alarms** and
  **resets squad realtime/channel state** before the wipe, and wraps the wipe in
  `SyncWorker.pauseFor(...)` to avoid racing an in-flight drain.
  (`auth_repository_impl.dart:36-146`, `database.dart:74-85`.)
- **Outbox wake-up timer added** — `Timer.periodic` (60s) drains independent of connectivity
  toggles. (`sync_worker.dart:33-56`.)
- **Same-entity mutation ordering preserved** — due entries ordered by
  `(entityTable, entityId, createdAt)`; later entries for an entity already failed this pass are
  skipped. (`sync_worker.dart:112-141`.)
- **Error classification + dead-letter handling added** — `errorType`/`lastError`/`maxAttempts`
  columns on the outbox table; permanent vs. transient errors classified.
  (`sync_worker.dart:219-259`, `sync_outbox_table.dart:20-27`.)
- **Incremental pull convergence** — `PullDownSync.run()` now runs every drain cycle (not once),
  with per-table watermarks; `sessions` added to what's pulled (alarms/user_stats already were).
  (`pull_down_sync.dart:33-40, 17-21, 128-171`.)
- **Outbox due-query indexed and bounded** — `@TableIndex` on `nextAttemptAt`; query capped with
  `.limit(100)`. (`sync_outbox_table.dart:9`, `sync_worker.dart:119`.)
- **First-backoff math fixed** — `1 << (attempt - 1)` so the first retry waits exactly
  `syncInitialBackoff`, not double it. (`sync_worker.dart:261-267`.)

### Squad (`lib/features/squad/`)
- **`onBroadcast` receiver implemented** and `trackPresence()` is now actually called (from
  `VerificationCubit` and `RunTrackingCubit`). (`squad_remote_datasource.dart:173-185`,
  `verification_cubit.dart:70`, `run_tracking_cubit.dart:57`.)
- **Channel retain/release accounting fixed** via explicit ref-counts plus a standing retain for
  tracked presence so it can't be torn down prematurely. (`squad_remote_datasource.dart:16-27`.)
- **Repository squad/channel caches now cleared on account transition** —
  `resetForAccountTransition()` called from the auth-transition flow above.
  (`squad_repository_impl.dart:304-312`.)
- **Backend/network failure no longer conflated with "no squad"** — only the very first fetch
  fails open to null; later failures retain the last-known cached squad state.
  (`squad_repository_impl.dart:82-110`.)
- **Leave-squad confirmation, loading, and error handling added.**
  (`squad_page.dart:692-722`, `squad_cubit.dart:97-106`.)
- **Raw backend exceptions replaced with friendly messages** across squad dialogs via
  `squad_error_message.dart`.

### Bootstrap / DI (`lib/main_common.dart`, `lib/core/`)
- **Sentry initialized** — `SentryFlutter.init()` wraps bootstrap, with PII-scrubbing
  `beforeSend`/`beforeBreadcrumb` hooks (strips GPS/frame data per project requirement).
  (`main_common.dart:79-101`.)
- **Notification permission moved to onboarding** — no longer requested bluntly from bootstrap.
- **`flutter test` fully green** — the uncancelled `_RiseInState` timer in
  `alarm_list_page.dart` now cancelled in `dispose()`.

### Home / Profile / Onboarding / Shell (Phase 3 UI work)
- **Home:** `_nextAlarm()` now filters by `isActive`; fabricated "Today's goal" card removed
  (not backed by any real domain concept); moved off 4 nested `StreamBuilder`s (including two
  duplicate `WatchOwnedArea` subscriptions) onto a new `HomeCubit`/`HomeState` with explicit
  per-field error flags instead of masking failures as zero/empty data.
- **Profile:** moved off nested `StreamBuilder`s onto `ProfileCubit`/`ProfileState`; raw exceptions
  replaced with `friendlyAuthErrorMessage(e)`; anonymous-account copy corrected (no longer claims
  "on this device only"); hardcoded avatar initial replaced by `CurrentUserAvatarButton` (real
  profile photo/initial) reused across Home/Alarms/Territory/Squad; submission-locking + autofill
  hints added to the email-link dialog (though see Remaining Gaps re: `Form`/validators).
- **Onboarding restructured**: `[3 marketing cards] → notification rationale card → battery
  exemption` — "Skip" only skips the marketing cards, never the permission-setup steps. Battery
  page's generic body text now platform-gated (`Platform.isAndroid ? ... : "iOS doesn't have this
  ...`), not just the OEM-specific block. Dead `Continue` button fixed when opened from Profile
  (`onContinue ?? () => Navigator.of(context).maybePop()`).
- **Shell:** extracted testable `AdaptiveNavScaffold` from `AppShellPage`; added
  `test/features/shell/app_shell_page_test.dart` covering breakpoint switching, destination
  selection, and keyboard-navigation reachability.

### Dependencies
- `turf` and `motor` removed (both unused).
- `kalman_dr` pinned to exact `0.4.4` (no caret), with a comment noting it's intentional.
- **Note:** the review's claimed `flutter_fgbg: 0.7.1` dependency override no longer exists in
  `pubspec.yaml` at all — either already removed in a prior session or the review's snapshot was
  stale by the time of writing. No action needed; flagging so it isn't chased as a phantom item.

### Infrastructure note (not a review finding, but relevant to future sessions)
Two test files were found silently corrupted mid-session (reduced to a single line of whitespace,
no corresponding edit made by the assistant) — consistent with the Windows file-lock/AV
interference already documented in this repo's `CLAUDE.md` (previously only observed affecting
Kotlin incremental-compiler caches, not source files). Recovered via `git checkout --` /
reconstruction from `git show HEAD:<path>`. If `flutter analyze`/`flutter test` suddenly shows mass
"Illegal character" errors in a file you didn't touch, check `git diff --stat` for a `Bin X -> Y
bytes` binary diff — that's the signature of this issue.

---

## 2. Remaining gaps (from the original review, still open)

**Verification method note:** this list was produced by two passes. The first pass sampled the
significant/representative findings from each review section. The second pass (triggered by the
user catching that the MapLibre `mapStyleFallbackUrl` gap had been missed) went back through the
review's remaining Medium/High bullets — including several genuine High-severity items that were
skipped the first time (verification's camera-rebuild/FPS issue, rep-counter left/right chain
locking, territory's unbounded cached-polygon rendering, "owned area" undercounting, GPS-quality
not gating acceptance, and multiple backend territory-correctness items). Both passes read current
source directly rather than trusting the original review's line numbers. A small number of
low-priority, repeated-pattern items (e.g. "dense controls need large-text/narrow-width handling,"
which recurs near-identically across Territory/Squad/Onboarding) were consolidated rather than
listed per-occurrence. If a third pass turns up more, that's the nature of an 88+ finding review —
treat this document as thorough, not provably exhaustive.

Organized by area, in rough priority order within each area.

### Map / tiles
- [x] **`Env.mapStyleFallbackUrl` now wired up + a third self-hosted tier added.** New
      `MapStyleLoader` (`lib/features/territory/presentation/widgets/map_style_loader.dart`)
      escalates: primary (`Env.mapStyleUrl`) → configured hosted fallback
      (`Env.mapStyleFallbackUrl`) → bundled self-hosted tile Worker (`Env.tileWorkerUrl` +
      `assets/map/fallback_style.json`) → failure overlay with a manual **Retry** button. Since
      `maplibre_gl` 0.26.2 has no live style-swap API (`styleString` is creation-only), each
      escalation gives the `MapLibreMap` a new `ValueKey` to force native-view recreation — both
      `territory_page.dart` and `active_run_page.dart` reset their stale Fill/Line/Circle handles
      and re-sync onto the fresh view when this happens (`_onMapCreated`).
- [x] **`active_run_page.dart` now has full map style-load failure handling** — same
      `MapStyleLoader`/timeout/retry/overlay treatment as the territory page (previously had none at
      all).
- [x] **Self-hosted tile fallback added and deployed** (`infra/tile-worker/`) — a vendored, adapted
      copy of Protomaps' official Cloudflare Worker (byte-range reads over an R2-hosted `.pmtiles`
      file). Backing data: a global, maxzoom-6 Protomaps OSM extract (~45MB, `generate_basemap.sh`
      regenerates it) — country/city-level detail, intended as a last-resort tier only, **not** a
      replacement for OpenFreeMap as primary (street-level detail globally would mean ~1TB+ storage,
      a real ongoing cost/maintenance commitment that was deliberately declined). Live at
      `https://awaken-tile-fallback.codestormhub.workers.dev`; `TILE_WORKER_BASE_URL` in
      `.env.client` points at it. Cost: $0/month (well inside R2 + Workers free tiers).
      **Live-verified on an Android emulator** (forced primary failure via an unreachable
      `MAP_STYLE_URL`): escalation timing confirmed via logcat (primary fails, 15s timeout fires,
      fallback loads clean), and a real bug was caught and fixed in the process — `_onStyleLoaded`'s
      camera zoom (15, tuned for full-detail tiers) overzoomed the z6 fallback data into an
      illegible blown-up single-color tile fragment. Fixed via `MapStyleLoader.dataMaxZoom` (6 for
      the bundled tier, `null`/unclamped otherwise) clamping all 5 camera-zoom call sites across both
      map pages. Re-verified live: fallback now renders legibly (rivers/roads/boundaries/labels) at
      the clamped zoom instead of a color blob.
- [x] **Manual zoom in/out buttons added** to both map pages (primary tier only, per explicit
      scope) — `CameraUpdate.zoomIn()`/`zoomOut()`, a tap-target/accessibility affordance alongside
      the pinch gesture that already reached the full unbounded zoom range
      (`MapLibreMap`'s default `minMaxZoomPreference`). Live-verified: zoom-in reached individual
      building outlines, zoom-out reached whole-city view, both correctly re-rendering real
      OpenFreeMap data at each level. Deliberately *not* wired to `MapStyleLoader.dataMaxZoom` (would
      let a user manually re-trigger the overzoom-blob issue above on the fallback tier) — noted as
      a possible follow-up, not done, per explicit scope ("just for the primary tier").

### Territory / run tracking — genuinely hard, Appium/hardware-gated
- [ ] **Foreground task handler is still empty.** `run_foreground_service.dart`'s
      `onStart/onRepeatEvent/onDestroy` don't own GPS collection or persistence — it still lives in
      the main isolate. A killed/backgrounded process can silently lose the in-progress path. This
      needs the plugin's documented `TaskHandler` pattern with `sendDataToMain`/port communication
      and checkpoint persistence. **Requires real-device force-kill testing to verify — out of
      reach without Appium/hardware, but the code fix itself doesn't need a device.**
- [ ] **No iOS-specific background-location path.** Still reuses the Android-style
      `flutter_foreground_task` config; CLAUDE.md already documents this as an open item requiring
      a dedicated `geolocator` background-location implementation for iOS. **Blocked on iOS
      hardware for verification, and is real feature work either way.**

### Territory — correctness gaps found in the second pass (no hardware needed)
- [ ] **"Owned area" still undercounts.** `watchOwnedAreaSqm()` sums only locally-cached
      `territories` rows — not a true server-side total. A user who hasn't panned the map over all
      of their territory sees a wrong (lower) number. (`territory_repository_impl.dart:51-60`.)
- [ ] **GPS accuracy/quality doesn't actually gate distance/geometry.** `RunTrackingRepositoryImpl.
      _onPosition` computes and displays a `GpsQuality` chip, but poor-accuracy fixes are still
      appended into `points`/`distanceMeters` — only dead-reckoning-extrapolation and non-positive-
      time gates drop points, not accuracy itself. (`run_tracking_repository_impl.dart:168-238`.)
- [ ] **No client-side pre-submission validity check after RDP simplification.** A marginal run can
      simplify down below the server's length/validity threshold with no matching client preview
      warning before submission. (`path_simplifier.dart`, `run_tracking_repository_impl.dart:311-321`.)
- [ ] **No differentiated guidance for permanently-denied vs. disabled location.** One generic
      message with a Close button for all denial states; no `openAppSettings()`/
      `Geolocator.openLocationSettings()` call anywhere. (`active_run_page.dart:617-645`.)
- [ ] **Dense control rows (stat tiles, action rows, bottom bar) don't wrap/scroll** for narrow
      screens or large text scale — fixed `Row`/`Expanded` throughout `active_run_page.dart` and
      `territory_page.dart`. (Same underlying pattern recurs in Squad's invite/member/leaderboard
      layouts — not separately itemized.)
- [x] **Polygon interior rings (holes) now modeled and rendered.** `Territory.rings` (flattened
      outer-ring-only list) replaced with `Territory.polygons` (`List<List<List<LatLng>>>` — one
      entry per MultiPolygon component, each itself the full ring list: index 0 outer boundary, any
      further rings are interior holes). `TerritoryMapper.polygonsFromMultiPolygonGeoJson` now keeps
      every ring instead of dropping all but the first. `territory_page.dart._redrawFills` now
      creates one `Fill` per polygon *component* with its complete ring list as that Fill's
      `geometry` (confirmed via `maplibre_gl_platform_interface`'s source that `FillOptions.geometry`
      is exactly `List<List<LatLng>>` — one ring list per fill — which is what makes a hole render
      as an actual hole instead of a second opaque fill painted on top), instead of the old
      one-Fill-per-ring loop. New `test/features/territory/data/mappers/territory_mapper_test.dart`
      (6 tests) locks in hole/no-hole/multi-component parsing and `boundsOf` correctness — there was
      no prior test coverage for this mapper at all.
- [x] **Debounce added to viewport bbox refresh.** `onCameraIdle` now calls
      `_scheduleRefreshForCurrentView()` (400ms `Timer`, cancelled/reset per idle event) instead of
      firing `_refreshForCurrentView()` directly — a rapid pan/zoom/pan sequence now fires one
      network request after it settles rather than one per idle event. The existing
      `_refreshRequestId` stale-response guard still handles out-of-order *results*; this handles
      redundant *requests*. (`territory_page.dart`.)
- [ ] **Generic pull sync still excludes `runs`** — `territories` has its own bbox-scoped
      refresh path and `sessions`/`alarms`/`user_stats` are pulled, but there's no equivalent
      incremental pull for `runs`.

### Backend — territory correctness (found in second pass, `submit_run()`/`territories_in_bbox()`)
- [x] **`captured_area_sqm` now genuinely net-new; own-territory merge now unions ALL intersecting
      rows, not just one.** Both fixed together in
      `20260726000016_submit_run_net_new_area_and_full_own_merge.sql` (applied live on
      `qxxkydisyqnodskmymla`), since a correct net-new calculation needs the same all-intersecting-
      rows lookup as the merge fix: own rows are now found via a locked id-array query, unioned
      (`v_own_union`), and `captured_area_sqm` = `ST_Area(ST_Difference(new polygon, v_own_union))`
      — a run entirely over already-owned land now correctly reports 0 new area instead of the full
      polygon. The merge now folds *every* touched own row into one canonical row (soft-deleting
      the rest), not just the first (`limit 1`) match. `v_delta_sqm` renamed to
      `v_territory_area_sqm` (it always held the merged territory's total area, not a delta — the
      old name was misleading, not itself a bug; semantics unchanged). The bounty bonus and
      unclaimed-land leaderboard credit both read the same `v_captured_area_sqm` variable, so they
      were fixed for free. **Verified**: two isolated `ST_Difference` sanity checks via
      `execute_sql` (50%-overlap → net-new is exactly half; 100%-overlap re-run → net-new is
      exactly 0), plus `get_advisors` shows no new findings (only pre-existing ones: intentional
      `SECURITY DEFINER` RPCs, anonymous-sign-ins-by-design, leaked-password-protection still off
      per item below). **Not verified**: a live end-to-end `submit_run()` RPC call through the app
      (would need a real device/emulator run reaching a real closed loop over previously-owned
      territory) — the fix is proven at the geometry-math level, not through the full app flow.
- [ ] **No `EXCLUDE` constraint or advisory lock preventing overlapping own/rival rows under
      concurrency.** Only row-level `for update` locks on *already-intersecting* rows at query time
      — doesn't prevent concurrent inserts of new overlapping geometry.
- [x] **`territories_in_bbox()` now has a server-side hard row cap and coordinate-bounds
      validation.** Fixed in `20260726000017_territories_in_bbox_cap_and_bounds.sql` (applied live).
      Converted `language sql` → `language plpgsql` to allow `raise exception` (matching
      `submit_run()`'s own bounds-check style): out-of-range lat (`< -90`/`> 90`) or lng
      (`< -180`/`> 180`), or inverted lat bounds, now raises instead of silently matching nothing or
      erroring deep inside PostGIS. `row_limit` is now clamped server-side via
      `greatest(1, least(row_limit, 500))` regardless of what the caller passes — a caller-supplied
      huge value can no longer force an unbounded scan/return. `min_lng > max_lng` (the existing,
      intentional antimeridian-wraparound case) is deliberately still accepted, not rejected.
      **Verified live** via `execute_sql`: valid bbox returns normally; `min_lat = -100` correctly
      raises `'invalid latitude bounds'`; `row_limit = 999999999` no longer errors (silently
      clamped); the antimeridian wraparound case (`min_lng=170, max_lng=-170`) still works.
      `get_advisors` shows no new findings.

### Alarm — small, no hardware needed
- [x] **`penaltyGraceWindow` constant removed** (was unused, `app_constants.dart:12`) — user chose
      removal over defining grace-period behavior.
- [ ] **Reliability self-test can't survive a real task kill and doesn't clean up its test alarm.**
      `_phase`/`_testAlarmId`/`_measuredDelay` are plain in-memory `State` fields with no
      persistence; the scheduled test alarm is never cancelled on dispose/re-run/timeout.
      (`alarm_reliability_test_page.dart:32-83`.)
- [ ] **Alarm toggle switch still flips before its underlying call resolves.** Delete and schedule
      flows were fixed to `await` + show errors, but the on/off toggle
      (`alarm_list_page.dart:174-179`) is still a fire-and-forget `VoidCallback` — a failed
      `setActive()` (which can now throw `AlarmOperationFailure`) leaves the switch showing the
      wrong state.
- [ ] **Wake-up tax bump RPC is still a non-atomic read-then-write** under the hood
      (`select ... into v_current` then a separate upsert, no row lock) — the client-bypass vector
      is closed (columns are locked down and the RPC is the only path), but concurrent calls to the
      RPC itself can still race and lose an update.
      (`20260725032045_lock_user_stats_and_add_tax_rpcs.sql:17-30`.)

### Verification — real gaps found in second pass, no hardware needed
- [x] **Left/right rep-counting chain now locked for the duration of a rep.** `_selectSide` picks
      the higher-confidence side only while neutral; a `_lockedIsLeft` flag locks in whichever side
      is driving a descent as soon as `_belowStreak` starts, and only unlocks back to neutral or on
      rep completion — so a user can no longer complete a rep by switching sides mid-way. Added a
      regression test (`rep_counter_test.dart` — "switching to a higher-confidence straight side
      mid-descent...") that fails against the old always-recompute logic. (`rep_counter.dart`.)
- [ ] **Entire camera stack still rebuilds on every pose-state change; no FPS throttle.** The whole
      widget tree including `CameraPreview` is inside one `BlocBuilder`; no `ValueNotifier`/
      `RepaintBoundary` isolation and no processing-FPS throttle exist anywhere in
      `verification_page.dart` or `pose_verification_repository_impl.dart` — this was a planned
      performance isolation from the original design that never got built.
- [ ] **Calibration phase is cosmetic.** It counts down 3 reps using the same fixed thresholds the
      whole time — it doesn't actually tune per-user thresholds from the calibration data.
      (`rep_counter.dart:35-64`, `pose_verification_repository_impl.dart:44-55,112-132`.)
- [ ] **No privacy control for automatic squad workout telemetry.** No opt-out setting exists
      anywhere under Profile for the throttled telemetry broadcast during a verified workout.
- [ ] **Several verification animations still ignore reduced-motion**, even though the pulse
      indicator and progress dots were fixed: the rep-segment fill `AnimatedContainer`
      (`verification_page.dart:359`), the rep-bump `AnimatedScale` (`:425`), and the completion
      `ExpressiveFlower(animatePop: true)` (`:447`) all animate unconditionally.
- [ ] **`SkeletonPainter` still stretches X/Y independently** without matching the camera preview's
      actual crop/fit transform (`CameraPreview`'s internal letterboxing). Overlay can visibly drift
      from the real pose on some aspect ratios. Fix is a `BoxFit`-aware transform in
      `skeleton_painter.dart:35-39`.

### Sync / outbox — found in second pass
- [x] **`SyncStatus` now surfaced in the UI** — new `_SyncStatusBanner` on `TerritoryPage`
      (`StreamBuilder<SyncStatus>` on `SyncWorker.status`), hidden on `idle`, shows
      syncing/offline/error with a manual "Retry" button on error. Prompted by a live user bug
      report (captured territory never appeared) where DB inspection via Supabase MCP confirmed
      `runs`/`territories` had 0 rows server-side — the capture was stuck silently in the local
      outbox with no way for the user to see it. Also fixed a real bug found while wiring this up:
      `SyncWorker.status` was a plain broadcast stream with no replay — a UI that mounted after the
      last status change (the exact case here, `TerritoryPage` opening well after the last drain
      cycle) would show nothing until the *next* transition. Same class of bug as
      `SquadRepositoryImpl._mySquadController` (see `engineering_gotchas` memory) — this stream had
      just never had a consumer before to hit it. Fixed via `_emitStatus()` tracking `_lastStatus`
      and an `async*` getter that replays it to new subscribers before continuing live.
      (`sync_worker.dart`, `territory_page.dart`.)
- [ ] **A single malformed row during pull still aborts the entire pull pass** for that table (no
      per-row try/catch in `_pullAlarms`/`_pullSessions`), so the watermark never advances past a
      poison row and the same failure repeats every drain cycle. (`pull_down_sync.dart:79-105,142-165`.)
- [ ] **Applying an authoritative run result doesn't refresh local `updatedAt`.** `_pushRun` writes
      back all the server-computed fields but not a timestamp. (`sync_worker.dart:175-204`.)
- [ ] **No client-side pre-validation mirroring server anti-cheat rules before enqueueing** — a
      payload that will always fail server validation now correctly gets dead-lettered instead of
      retrying forever (that part was fixed), but it's still caught after a wasted round-trip rather
      than before enqueueing.

### Backend — grants/triggers/auth config, found in second pass
- [ ] **`user_stats` has no `updated_at` trigger** — relies on the RPC bodies manually setting
      `now()`, unlike alarms/sessions/runs/profiles/territories which all have real triggers.
- [ ] **`set_updated_at()` and `territories_set_area()` still have broader-than-necessary `EXECUTE`
      grants** — only `recompute_streak_tier()` got its public grant revoked.
- [ ] **Leaked-password protection is still disabled.** This is a Supabase Auth dashboard setting,
      not something a migration can fix — needs to be flipped directly in the dashboard
      (Authentication → Policies → Password Security).
- [ ] **`squad_members()`/`squad_leaderboard()` have no comment acknowledging the `profiles.squad_id`/
      `streak_tier` lockdown** — the fix is real (those columns are locked), but purely
      documentation/traceability, not a functional gap.

### Cross-cutting UI polish — found in second pass
- [ ] **Motion/shape design tokens are still not referenced anywhere.** `motion_tokens.dart`/
      `shape_tokens.dart` exist as unused documentation; `expressive_widgets.dart`, `alarm_ring_page.
      dart`, etc. all hardcode their own `Duration`/`Curves`/`BorderRadius` literals independently.
      `shape_tokens.dart`'s own doc comment now admits it was never wired up.
- [ ] **Roboto Flex is still fetched at runtime via `GoogleFonts.robotoFlexTextTheme()`**, not
      bundled as a local asset — first-launch-offline / privacy-consistency risk remains.
- [ ] **Global scrollbar suppression (`NoScrollbarBehavior`) still applies unconditionally**,
      including on wide/desktop-style layouts where a scrollbar aids discoverability.
- [ ] **Home's greeting and relative-activity-time labels go stale without a rebuild** — no periodic
      timer; `_greeting()`/`_relativeTime()` only recompute when something else triggers a rebuild.
- [ ] **Unknown `ExerciseMode` values still silently render as "Push-ups"** via a boolean ternary
      (`home_page.dart:79`, same pattern in `alarm_list_page.dart:485,517`) instead of an explicit
      unknown-value case.
- [ ] **Onboarding-seen check/mark still has no error handling.** A failed `HasSeenOnboarding` check
      leaves the app on a blank `SizedBox.shrink()` indefinitely (`app.dart:92-99`); marking
      onboarding complete is still fire-and-forget (`app.dart:125`).
- [ ] **Onboarding marketing carousel still isn't scrollable** — fixed-size `Column`/`SizedBox`
      content with no `SingleChildScrollView`, will overflow under landscape/short/large-text
      conditions.
- [ ] **Sign-out confirmation dialog copy isn't tailored for unlinked anonymous users** — same
      reassuring "still safe in the cloud" copy is shown regardless of whether the user has actually
      linked an identity, even though an anonymous sign-out is genuinely unrecoverable.
- [ ] **Shell has no true list-detail dual-pane layout on wide screens** — the rail/bar breakpoint
      switch exists, but `body` is still the same single-pane `IndexedStack` at every width. Also no
      explicit `SafeArea`/edge-inset handling around the `NavigationRail` branch.
- [ ] **No in-app recovery screen if pre-`runApp()` alarm init/reconciliation throws.** Now at
      least captured by Sentry (wrapped in `SentryFlutter.init(appRunner: ...)`), but an uncaught
      exception there still kills startup with a blank screen instead of a recovery UI.
- [ ] **No retry coordinator for a failed anonymous sign-in on first launch.** Still just swallowed
      with a `TODO(Phase 3b)` comment; `ConnectivityWatcher` only gates `SyncWorker` drains, never
      retries `EnsureAuthSession`.
- [ ] **`main_prod.dart` still points at the dev Supabase project.** Explicitly acknowledged with a
      TODO — blocked on you provisioning a separate prod project. Not something to silently fix;
      flag when that infra decision is made.
- [x] **`ThemeModeCubit` load/set race fixed** — `_userSet` flag set by `setThemeMode()` and checked
      by `_load()` after its `getInstance()` await, so a user choice made during startup load can no
      longer be clobbered. (`theme_mode_cubit.dart`.)
- [x] **`SystemCapabilities` now has a class-level `Platform.isAndroid` guard.** Every method routes
      through a private `_invoke<T>(method, fallback)` helper that short-circuits to the method's
      safe fallback (`false`/`'unknown'`) on non-Android platforms before ever touching the channel
      — a new caller can no longer reintroduce the iOS `MissingPluginException` risk by forgetting
      its own `Platform.isAndroid` check. Existing call-site checks (e.g.
      `battery_exemption_repository_impl.dart`) are now redundant-but-harmless, left in place.
      (`system_capabilities.dart`.)

### Profile — small
- [x] **Email/password linking form now uses `Form`/`TextFormField` with `validator`s.** Added a
      `GlobalKey<FormState>`, split the old combined `_validate()` into per-field
      `_validateEmail`/`_validatePassword`, wrapped both fields in a `Form` with
      `AutovalidateMode.onUserInteraction`, and `_submitEmail()` now gates on
      `_formKey.currentState.validate()` — malformed email/short password are now caught client-side
      with inline per-field errors instead of only surfacing as a server rejection.
      (`profile_page.dart`.)

### Onboarding — small
- [x] **Battery-exemption "Allow" action now has a busy indicator and try/catch.** New
      `_requestExemption()` sets `_requestingExemption` before/after the call, wraps it in
      try/catch (a failure now shows a SnackBar instead of being silently swallowed), and the
      `_StatusRow`'s action slot swaps to a small `CircularProgressIndicator` while in flight (new
      `busy` param) instead of leaving the "Allow" button tappable mid-request.
      (`battery_exemption_page.dart`.)

### Squad — real security-relevant items
- [x] **Presence tracking now waits for subscribe confirmation.** `_channelFor()`'s `subscribe()`
      call takes a status callback that completes a per-squad `Completer` on
      `RealtimeSubscribeStatus.subscribed`; `trackPresence()`/`broadcastTelemetry()` await it before
      calling `.track()`/`.sendBroadcastMessage()`. Completer cleaned up in `_release()`/
      `closeAllChannels()`. (`squad_remote_datasource.dart`.)
- [ ] **Presence identity is still client-asserted, not server-verified.** The `user_id` in the
      Presence payload comes from local state (`squad_repository_impl.dart:266-283`) with nothing
      server-side checking it against the channel's authenticated JWT — impersonation within a
      squad's live-activity view is still theoretically possible. Would need either a Realtime
      Authorization hook or moving identity binding server-side.

### Shell — cosmetic
- [ ] **No large-text/`textScaleFactor` test** in `app_shell_page_test.dart`. (The missing 840dp
      breakpoint test is moot — 840dp isn't used anywhere in the app's actual breakpoint logic.)

### Testing (§8.3 of the original review — still largely open)
Most of the "highest-priority missing tests" list from the review is still open beyond what was
incidentally covered by the fixes above (e.g. `AdaptiveNavScaffold`'s new tests). Not itemized
individually here since it's a large, mostly-net-new-test-writing effort rather than a "fix a bug"
list — worth a dedicated pass if/when you want deeper regression coverage, especially:
- [x] **Sync/account-transition regression test added** —
  `test/sync/local/clear_all_local_data_test.dart` (2 tests): seeds every table
  `AppDatabase.clearAllLocalData()` is documented to cover (alarms, sessions, runs, territories,
  user_stats, run_checkpoints, sync_meta, sync_outbox), asserts the seed landed, wipes, asserts
  everything is empty — plus an idempotency check on an already-empty database. Exercises
  `clearAllLocalData()` directly against a real in-memory sqlite3 instance rather than mocking
  `AuthRepositoryImpl`'s full dependency graph, since the property that matters ("every
  locally-cached table is empty after the wipe") doesn't need any of that.
- [ ] **Backend pgTAP/SQL harness for `submit_run()` anti-cheat, idempotency, RLS denial cases** —
  still open, deliberately not attempted this pass. This is real new testing infrastructure (enable
  the pgTAP extension, write `.sql` test files, wire a runner), not a quick addition alongside the
  Dart regression test above — currently still only verified live/manually per-migration (see this
  session's `execute_sql`-based sanity checks for items #12-14 above), not committed as repeatable
  tests. Worth a dedicated pass.
- Squad private-channel/Presence tests.
- Device-dependent alarm/territory reliability matrices (Appium/hardware-gated, out of scope here).

---

## 3. Suggested order for a follow-up session

Cheapest, highest-value first (no hardware, no Appium, all in reach of a normal dev session):

1. [x] `penaltyGraceWindow` — removed (user chose removal over defining grace-period behavior).
2. [x] `ThemeModeCubit` race — fixed (`_userSet` guard).
3. [x] Presence subscribe-status race in squad (`squad_remote_datasource.dart`) — fixed (awaits
   `RealtimeSubscribeStatus.subscribed` before `.track()`/broadcast).
4. [x] Left/right rep-counting chain lock in `rep_counter.dart` — fixed (`_lockedIsLeft`), plus a
   regression test.
5. [~] `SkeletonPainter` crop/fit-aware scaling — investigated, found to be a **false positive**:
   the current stretch math already matches how `CameraPreview` renders in this app's actual
   `StackFit.expand` layout (verified against Flutter SDK source). Left as-is; not fixed because
   nothing was broken.
6. [x] Debounce viewport bbox refresh in `territory_page.dart` — fixed (400ms debounce timer).
7. [x] `SystemCapabilities` class-level `Platform.isAndroid` guard — fixed (`_invoke<T>` helper).
8. [x] Battery-exemption "Allow" busy/error handling — fixed (`_requestingExemption` +
   try/catch + `busy` spinner).
9. [x] Email-link `Form`/`TextFormField` validators — fixed (per-field validators, `Form` wrapper).

**Also done this session, outside this list:** the full map-tile self-hosted fallback tier
(§"Map / tiles" above — `MapStyleLoader`, `infra/tile-worker/` deployed and live, camera-zoom-clamp
bugfix found via live emulator testing) and manual zoom in/out buttons on both map pages.

Remaining from the original order:

10. [x] Per-row try/catch in `pull_down_sync.dart` — fixed (caught inside the transaction loop, per
    table, with Sentry reporting; watermark now advances past a poison row instead of stalling).
11. [x] Alarm toggle switch: await `setActive()` and revert the UI on failure — fixed
    (`_toggleActive`, try/catch + SnackBar, matching the delete/schedule pattern).
12. [x] Backend: `captured_area_sqm`/`v_delta_sqm` — fixed, net-new area, applied live + verified
    (see "Backend — territory correctness" above).
13. [x] Backend: union ALL intersecting own-territory rows — fixed in the same migration as #12.
14. [x] Backend: hard row cap + coordinate-bounds check on `territories_in_bbox()` — fixed and
    verified live.
15. Enable leaked-password protection in the Supabase Auth dashboard (not a code change).
16. [x] Polygon holes rendering — fixed (`Territory.polygons`, mapper, `_redrawFills`) + 6 new tests.
17. [~] Regression tests — sync/account-transition done (`clear_all_local_data_test.dart`,
    2 tests). `submit_run()` anti-cheat pgTAP harness is real new test infrastructure, deliberately
    deferred (see "Testing" section above).

Then, when ready to invest in the harder items:
18. Verification camera-stack `ValueNotifier`/`RepaintBoundary` isolation + FPS throttle — a real
    performance rework, not a one-line fix.
19. Foreground task handler real GPS-in-isolate implementation (code work is unblocked now;
    verification needs a real device).
20. iOS background-location path (real feature work, iOS-hardware-gated for verification).
21. Presence server-side identity verification (needs a design decision on approach — Realtime
    Authorization hook vs. other).
22. Territory "owned area" true server-side total (needs a new RPC or a full-scan strategy since
    the client only ever sees the currently-loaded viewport's cache).
