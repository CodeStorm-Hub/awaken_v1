# Awaken Codebase, UI, Dependency, and Supabase Review

**Review date:** 2026-07-25  
**Application scope:** `lib/` — 150/150 Dart files reviewed  
**Dependency scope:** `pubspec.yaml` and `pubspec.lock`  
**Backend scope:** Supabase `awaken-dev` (`qxxkydisyqnodskmymla`)  
**Review mode:** Read-only analysis; no application code, database schema, or production data was changed.

> This report reflects the repository and live backend state observed on 2026-07-25. Supabase row counts, advisors, deployed functions, and package latest versions can change after this date.

---

## 1. Executive summary

Awaken has a strong foundation: feature-first organization, mostly clean domain boundaries, coherent generated DI, a polished Material 3-inspired visual system, a correct app-wide alarm overlay, transactional Drift entity/outbox writes, anonymous-first Supabase authentication, RLS on every public table, and server-controlled territory mutation.

The project is not yet release-ready. Several issues threaten core data integrity, alarm reliability, run tracking, and multiplayer trust:

1. **Local data and outbox rows are not owned or partitioned by user.** Signing out or deleting an account leaves alarms, sessions, GPS paths, statistics, native alarms, and queued mutations available to the next identity. Queued data can be uploaded under another user.
2. **Alarm preview is destructive.** Completing or skipping a preview executes the production completion path, potentially cancelling a real future alarm, advancing recurrence, logging a streak session, and changing wake-up tax.
3. **Native alarm failures are ignored.** `Alarm.set()`/`Alarm.stop()` boolean results are discarded, so UI/cache state can claim an alarm is active or dismissed when the native operation failed.
4. **Android run tracking is currently blocked or unreliable.** The required foreground-service manifest declaration is absent, the location service starts before runtime permission is secured, and the service handler does not own GPS collection or persistence.
5. **The live territory RPC path is unsafe and likely broken.** `submit_run()` and `territories_set_area()` use a malformed one-entry `search_path` (`"public, extensions"`), while PostGIS is installed in `extensions`. The RPC also lacks server-side velocity validation and idempotent retry behavior.
6. **Outbox delivery is not safe under account changes, ordering failures, or ambiguous network outcomes.** Backoff timestamps do not schedule future work, later mutations can overtake failed earlier ones, and duplicate run submissions cannot converge.
7. **Authoritative backend fields remain client-writable.** Users can directly modify `profiles.squad_id`, `profiles.streak_tier`, and `user_stats.current_tax_multiplier`, bypassing invite, progression, and tax rules.
8. **Squad live activity is both insecure and incomplete.** Realtime channels are public, membership is not enforced through `realtime.messages` RLS, Presence identity is client-trusted, telemetry has no receiver, and Presence tracking is never invoked.
9. **Account deletion is incomplete.** The Edge Function can fail for squad owners/report participants due to FK ordering, while the client retains sensitive local data even after reporting deletion success.
10. **Test coverage is far below the risk profile.** Static analysis passes, but the full test suite currently fails due to an uncancelled UI timer. There are no backend SQL tests, squad tests, bootstrap/auth-transition tests, run lifecycle tests, or real-device alarm reliability evidence in the repository.

### Overall readiness

| Area | Assessment | Release posture |
|---|---|---|
| Architecture and DI | Good baseline; presentation sometimes bypasses BLoC and plugin boundaries | Improve, not blocking alone |
| Alarm scheduling/ringing | Correct overlay and package settings, but destructive preview, recurrence, native-result, and startup risks | **Blocker** |
| Pose verification | Correct plugin isolation and frame dropping; lifecycle, subscription, accuracy, and repaint isolation gaps | **Blocker until device validated** |
| Offline sync | Transactional local writes are strong; ownership, retry, ordering, pull convergence, and idempotency are unsafe | **Blocker** |
| Territory tracking | Client filtering exists; Android service setup/lifecycle and iOS path are incomplete | **Blocker** |
| Territory backend | Correct geometry model/RLS direction; malformed search path and missing anti-cheat/idempotency | **Blocker** |
| Squad/social | Useful RPC structure and polling; authorization and live telemetry are incomplete | **Blocker for social launch** |
| UI/UX | Visually coherent and mostly accessible; several misleading/dead states and responsive issues | Beta-ready after fixes |
| Dependencies | Generally current and plan-aligned; several unused/EOL/override concerns | Maintenance work |
| Testing/observability | Analyze clean; tests not green; Sentry and Patrol not wired | **Blocker for confidence** |

---

## 2. Review methodology and coverage

The review included:

- Every Dart file under `lib/`, including generated DI and Drift code.
- Every application feature: core/bootstrap, home, onboarding, profile, shell, alarm, verification, territory, squad, and sync.
- All pages, widgets, custom painters, dialogs, sheets, themes, and responsive shell code.
- `pubspec.yaml`, all resolved direct versions in `pubspec.lock`, dependency usage, overrides, and `flutter pub outdated` output.
- Existing relevant tests.
- The authoritative `awaken_app_refined_plan.md` and project rules in `CLAUDE.md`.
- Live Supabase public schema, constraints, indexes, policies, grants, functions, triggers, extensions, migrations, Realtime publication state, advisors, and aggregate data health.
- Validation with `flutter analyze`, `flutter test`, and `flutter pub outdated`.

Generated files were not treated as handwritten design, but were checked for consistency with source declarations and registrations.

---

## 3. Priority remediation plan

### P0 — Correctness and security blockers

1. Partition all local user-owned data and outbox rows by immutable owner UID, or use one database per account. Block cross-owner drain attempts.
2. Define account transition semantics: cancel native alarms, stop tracking/sync, clear or switch local partitions, close squad channels, and remove user-scoped preferences on sign-out/deletion.
3. Make alarm preview side-effect-free.
4. Check every native alarm operation result and expose actionable reliability failures.
5. Fix recurrence calculation so repair can select a valid occurrence later on the current day.
6. Replace UUID `hashCode` alarm IDs with a specified stable persisted integer mapping.
7. Add the Android location foreground-service manifest declaration and request/check permission before service start.
8. Move run collection/checkpointing into a lifecycle-safe platform-specific architecture; implement a separate iOS background-location path.
9. Fix the live PostGIS function search paths using separate schema entries or fully qualified `extensions.ST_*` functions.
10. Change the run payload/RPC contract to carry per-point timestamps and server-verifiable metadata; enforce speed, timing, coordinate, count, and payload limits server-side.
11. Make `submit_run()` idempotent for repeated `p_run_id` delivery.
12. Remove direct client write access to authoritative `profiles.squad_id`, `profiles.streak_tier`, and tax progression.
13. Make squad channels private and add `realtime.messages` membership policies; bind live identity to authenticated server state.
14. Repair account-deletion FK ordering and clear local data after remote deletion.

### P1 — Reliability and convergence

1. Schedule outbox wake-up for the earliest `next_attempt_at`, and trigger on app resume and auth restoration.
2. Preserve same-entity mutation ordering or compact/version operations safely.
3. Add permanent/transient error classification, dead-letter handling, error details, and user-visible sync state.
4. Replace one-time pull hydration with owner-scoped incremental convergence, including remote deletes/tombstones.
5. Make local/remote session nullability consistent.
6. Add camera and run app-lifecycle handling, cancellation tokens/session generations, and subscription cleanup.
7. Reconcile territory cache deletions and viewport eviction; preserve polygon holes.
8. Implement functional Presence/Broadcast reception and correct channel subscription/ref-count lifecycle.
9. Initialize Sentry and capture bootstrap, alarm, sync, camera, and location failures without storing frames or raw paths.

### P2 — UX, accessibility, and maintainability

1. Put notification rationale, Android battery exemption, OEM autostart, and reliability testing into onboarding.
2. Add explicit loading/error/retry states instead of rendering failures as zero/empty data.
3. Remove or implement fabricated daily-goal content.
4. Hide Android battery controls on iOS and present platform-appropriate guidance.
5. Respect reduced-motion settings and test large text/landscape/narrow layouts.
6. Make map attribution always visible and add offline/style-load states.
7. Replace raw backend exception text with typed domain failures and safe messages.
8. Move Home/Profile/Onboarding asynchronous state into testable Cubits or equivalent view models.

---

## 4. Detailed application findings

## 4.1 Bootstrap, configuration, DI, and app composition

### Strengths

- `Env.load()` precedes Supabase and DI initialization.
- Generated `injection.config.dart` is internally consistent with reviewed constructors and registrations.
- `SupabaseClient` and `AppDatabase` are provided through a module rather than constructed in presentation code.
- The alarm ring surface is correctly installed in `MaterialApp.builder`, so it can cover every route.
- The underlying route tree is pointer-blocked and excluded from semantics while an alarm is ringing.
- Dynamic light/dark schemes and persisted theme mode are implemented.

### High findings

- **Alarm-critical startup can fail before any UI exists.** Alarm initialization and recurrence reconciliation occur before `runApp()` (`lib/main_common.dart:49-56`). A thrown exception can leave no recovery screen.
- **Auth, pull, and cache rearm are coupled in one broad catch.** A network/auth/pull error prevents local alarm rearm (`lib/main_common.dart:62-73`), even though local rearm should work offline.
- **Offline first launch has no auth retry coordinator.** Failed anonymous sign-in is swallowed; sync does not later create a session when connectivity returns.
- **Production uses the development environment.** `lib/main_prod.dart:3-8` loads the same `.env.client` as development.
- **Notification permission is requested before rationale UI.** This reduces grant quality and contradicts the onboarding plan (`lib/main_common.dart:42-47`).
- **Sentry is installed but not initialized.** Bootstrap exceptions and mission-critical failures are not observable.

### Medium/low findings

- Theme persistence can race initial loading with a user change (`lib/core/theme/theme_mode_cubit.dart:14-35`).
- `SystemCapabilities` directly calls an Android-only MethodChannel and is not intrinsically safe on iOS (`lib/core/platform/system_capabilities.dart:8-47`).
- Motion/shape token classes exist but many widgets hardcode curves, durations, and radii.
- Roboto Flex is obtained through `google_fonts` without a bundled font asset, creating potential first-use network/offline/privacy inconsistency.
- Global scrollbar suppression reduces wide-screen/desktop discoverability.
- `mapStyleFallbackUrl` is defined but unused.

---

## 4.2 Home dashboard

### Implemented functionality

- Next alarm summary.
- Current wake-up streak.
- Owned-area summary.
- Squad rank.
- Achievement unlock presentation.
- Recent verified workouts and run activity.
- Quick navigation to run and squad areas.

### Findings

- **Next alarm selection is not domain-correct.** `_nextAlarm()` sorts all alarms without filtering inactive, stale one-shot, or future recurring eligibility (`lib/features/home/presentation/pages/home_page.dart:38-43`).
- **Daily goal is fabricated.** The UI hardcodes 70% and `14 / 20 squats completed`, with a nonfunctional chevron (`home_page.dart:276-329`).
- Presentation resolves use cases through global GetIt and creates streams during build, producing repeated subscriptions and inconsistent state/error handling.
- Stream errors are generally rendered as valid zero/empty values.
- Relative activity labels and time-based greetings can become stale without another rebuild.
- Unknown exercise values are mislabeled as push-ups rather than handled explicitly.

---

## 4.3 Onboarding and battery reliability

### Implemented functionality

- Three-page product carousel.
- Persisted onboarding completion flag.
- Android battery-optimization status/request UI.
- OEM autostart settings deep-link attempt.
- Lifecycle refresh after returning from settings.

### Findings

- **Battery reliability is not part of first-run onboarding.** Users proceed directly from the carousel to the shell; battery setup is only reachable from Profile.
- **Notification rationale is absent before the OS prompt.** The request occurs during bootstrap.
- Android battery operations and Android-specific text are exposed on iOS.
- The battery page lacks robust busy/error/outcome handling.
- When opened from Profile, the page shows a disabled `Continue` button because no callback is supplied.
- Onboarding preference failure can leave a blank startup state; completion persistence is fire-and-forget.
- Fixed-size, non-scrollable content risks overflow under landscape, small height, split screen, or large text.
- Continuous and transition animations do not honor reduced-motion preferences.

---

## 4.4 Profile and authentication

### Implemented functionality

- Anonymous session creation.
- Anonymous-to-email linking.
- Anonymous-to-Google identity linking.
- Theme selection.
- Sign-out.
- Server-side account deletion through an authenticated Edge Function.
- Navigation to reliability and battery settings.
- Real streak and territory summaries.

### Critical/high findings

- **Cross-account local data exposure and corruption.** Sign-out explicitly retains local data, while local tables/outbox rows have no owner. The next anonymous or linked account can see and upload the prior account’s data.
- **Account deletion retains local GPS paths, alarms, sessions, stats, outbox payloads, and native alarm schedules.** This contradicts the UI’s permanent-deletion claim.
- Anonymous sign-out can make the remote anonymous identity unrecoverable while leaving its cache behind.
- The live deletion function can fail for squad owners and report participants because it deletes squads/profile without first resolving `profiles.squad_id` and `squad_reports` FKs.

### Medium findings

- Raw Supabase/Edge Function exceptions and response bodies can be displayed directly to users.
- Email forms lack a proper `Form`, password policy validation, autofill hints, inline errors, and submission locking.
- Anonymous-account copy incorrectly says progress is stored “on this device only,” even though data is synced to a remote anonymous UID.
- Presentation owns async flows directly rather than through a testable state layer.
- Hardcoded avatar initials do not reflect actual profile metadata.

---

## 4.5 Application shell and responsive navigation

### Strengths

- Four clear destinations: Home, Alarms, Territory, Squad.
- `IndexedStack` preserves tab state.
- Compact `NavigationBar` switches to `NavigationRail` at wider widths.

### Findings

- Wider-layout support is partial rather than a complete window-size/list-detail strategy.
- Rail/system inset behavior needs explicit edge-to-edge testing.
- Global scrollbar removal is questionable on wide/desktop-style layouts.
- There are no tests at 600/840 dp breakpoints, large text, cutouts, or keyboard navigation.

---

## 4.6 Alarm feature

### Implemented functionality

- Native scheduling through `alarm` 5.5.0.
- Drift/outbox persistence.
- Enable/disable/delete.
- Weekday recurrence.
- App-wide ring overlay.
- Workout verification handoff.
- Wake-up tax and local streak calculation.
- Cache rearm and recurrence reconciliation.
- Reliability self-test UI.

### Strong decisions

- `androidStopAlarmOnTermination: false` is explicit.
- Ring UI is global rather than tied to the root route.
- The ring overlay steps aside while verification is active.
- Disabled alarms remain editable in Drift.
- Wake-up tax is bounded.
- Accessibility skip stops the alarm and records a failed/skipped session rather than trapping the user.

### Critical finding: destructive preview

`AlarmListPage` opens a real alarm as a preview (`alarm_list_page.dart:190-201`), but preview completion invokes the production path (`alarm_ring_page.dart:96-100`; `alarm_repository_impl.dart:225-255`). A preview can:

- stop the real future native alarm;
- advance a recurring alarm past its upcoming occurrence;
- log a streak-eligible session;
- reset or increase tax;
- create misleading remote history.

Preview must use a separate, side-effect-free model and completion callback.

### High findings

- **Same-day recurring occurrence can be skipped.** `nextOccurrenceAfter()` begins at tomorrow, which is wrong for startup repair when today’s selected time is still ahead (`alarm_schedule.dart:46-60`).
- **Native IDs depend on UUID `hashCode`.** This is not a specified persistent cross-run/platform contract (`alarm_payload.dart:51-54`). Persist a stable native ID or use a documented stable mapping with collision handling.
- **`Alarm.set()` and `Alarm.stop()` results are ignored.** Visible/cache state can diverge from native state (`alarm_repository_impl.dart:156-230`).
- **Startup reconciliation may replace a currently ringing recurring alarm.** The repair path does not explicitly exclude active ring state.
- **Local cache rearm is incorrectly network-coupled.** Auth/pull failure prevents local recovery.
- UI operations often do not await completion before implying success.
- Malformed or legacy payloads can terminate streams/startup because parsing uses unchecked casts and enum lookup.

### Medium findings

- One-shot completion leaves an active past row in Drift/backend even though it disappears from the native-derived list.
- Same-second alarms may replace one another because `allowSameSecondScheduling` is not set.
- Reliability-test success is in-memory and cannot persist through a true task kill; test alarms are not robustly cleaned up.
- Session `startedAt` and `completedAt` are both assigned at completion, preventing duration/latency measurement.
- Alarm list ordering has no explicit chronological contract.
- Wake-up tax read-modify-write is not atomic.
- `penaltyGraceWindow` is defined but unused.
- The full-screen/force-kill design is Android-centric; equivalent iOS reliability behavior is not defined or tested.

---

## 4.7 Pose verification

### Implemented functionality

- Front-camera initialization.
- Android NV21 and iOS BGRA8888 requests.
- ML Kit base model in stream mode.
- Busy-flag frame dropping.
- Pose-to-domain mapping.
- Squat and push-up angle state machine.
- Three-rep calibration phase.
- Skeleton painter and progress UI.
- Wakelock during verification.
- Accessibility escape path.

### Strengths

- Camera and ML Kit are isolated behind data/domain interfaces.
- Frames are neither persisted nor transmitted by the reviewed code.
- Camera audio is disabled.
- Domain rep logic is independent of plugin types.
- Threshold hysteresis reduces simple boundary flicker.

### High findings

- **Cubit subscriptions leak.** `VerificationCubit.begin()` does not retain/cancel its repository subscription; the singleton repository outlives each page (`verification_cubit.dart:38-54`).
- **Camera lifecycle is unhandled.** The app does not dispose/reinitialize on inactive/resumed transitions.
- **Initialization or ML failures can strand the user on an indefinite spinner.** There is no controlled error/retry/escape state during initialization.
- **In-flight frames can emit into a stopped or replacement session.** Stop does not await/cancel inference or use a generation token.
- **Rep validation is too permissive for the stated 95% target.** A single low/high threshold frame can count; there is no minimum duration, consecutive-frame confirmation, cooldown, direction validation, whole-body form, or push-up body-line check. A standing arm curl can satisfy the elbow-angle rule.
- Left/right chain selection can switch between frames, allowing unrelated sides to complete one repetition.
- **The entire camera stack rebuilds for each pose state.** The planned `ValueNotifier`/`RepaintBoundary` isolation is not implemented, and the configured target processing FPS is not enforced.

### Medium findings

- Calibration is repeated every alarm and does not actually tune thresholds.
- YUV fallback passes only the first plane, which is invalid for multi-plane YUV devices.
- Skeleton projection stretches coordinates without matching camera preview crop/fit transforms; overlay alignment can drift.
- Overall average confidence can hide low confidence in the specific joints used for counting.
- Dynamic rep/status changes are not exposed as semantic live regions.
- Animations ignore reduced-motion settings.
- No feature-level privacy control exists for automatic squad workout telemetry.

---

## 4.8 Territory tracking and map

### Implemented functionality

- Geolocator stream and scripted E2E provider.
- Kalman smoothing.
- Mock, timestamp, dead-reckoning, and velocity gates.
- Distance and loop-closure tracking.
- Android foreground-task wrapper.
- Wakelock during active run.
- RDP path simplification.
- Transactional local run/outbox creation.
- Server `submit_run()` invocation.
- MapLibre vector maps, path/markers, territory fills, viewport bbox refresh.
- Pending/rejected/captured result UI.

### Critical findings

- **Android foreground service is not declared in the app manifest.** The `flutter_foreground_task` location service element with `android:foregroundServiceType="location"` is absent.
- **Foreground service starts before location permission is obtained.** Android 14+ can reject the location FGS on a first run before the UI can show permission guidance.
- **The foreground task handler is empty.** GPS collection and the entire active path remain in the main isolate’s memory. Activity/process loss can leave an empty notification service while tracking silently stops and the path disappears.
- **Run payload lacks per-point timestamps.** The server cannot perform required consecutive-fix speed validation.

### High findings

- iOS uses the same conceptual foreground-task path without a deliberate Core Location lifecycle/recovery implementation.
- Start failures do not share a comprehensive cleanup path; false active state, leaked wakelock, or leaked service are possible.
- `RunTrackingCubit` leaks repository subscriptions.
- Very inaccurate GPS fixes are displayed as poor quality but still accepted into distance and geometry.
- Territory cache only upserts, never reconciles remote soft deletion or rival geometry removal.
- Every cached polygon is watched/rendered, so panning grows global cache and redraw cost.
- “Owned area” is a sum of only encountered cached territories, not necessarily the user’s total.
- Polygon interior rings are dropped, painting authoritative holes as owned land.
- Capture UI can remain permanently busy when an exception occurs because `_busy` lacks `try/finally` recovery.
- OSM attribution is behind an interaction button instead of continuously visible.

### Medium findings

- Viewport requests are un-debounced, uncancelled, limited to 500 without pagination, and lack antimeridian handling.
- No map style-load/offline state exists despite the plan requirement that runs continue when the map is unavailable.
- Simplification can move a marginal run below server length/validity without a matching client preview.
- `TerritoryPage` imports `geolocator` directly, bypassing the data/domain plugin boundary.
- Permanently denied and disabled-location states have no settings deep-link or differentiated guidance.
- Dedicated `TerritoryRemoteDatasource.submitRun()` duplicates logic that `SyncWorker` implements independently.
- Dense horizontal controls need large-text/narrow-screen adaptation.

---

## 4.9 Squad and social

### Implemented functionality

- Squad create/join/leave RPCs.
- Invite-code display/copy.
- 20-second leaderboard polling.
- Rank calculation.
- Presence model and UI.
- Throttled run/workout telemetry publishing.
- Member report UI and table insert.

### Strengths

- Leaderboard polling follows the message-budget plan.
- Squad RPCs authenticate the caller and check membership in their current definitions.
- Definer functions use an empty search path for squad operations.
- Telemetry is throttled to three seconds.
- Loaded, empty, loading, and error visual states exist.

### High findings

- **Realtime channels are public.** Channels do not use private configuration and there are no membership policies on `realtime.messages`.
- **Live activity is functionally disconnected.** Telemetry is sent but no `onBroadcast` receiver exists; `trackPresence()` has no caller.
- Presence tracking can race subscription completion.
- Channel retain/release accounting can reset or leak channels.
- Presence identity (`user_id`, name, activity) is trusted from client payloads, permitting impersonation.
- `squad_reports` only checks `reporter_id = auth.uid()`; it does not verify that reporter and target belong to the stated squad.
- Repository squad/channel caches survive auth-user changes.

### Medium findings

- Backend/network failures are converted into “not in a squad,” conflating failure with valid empty state.
- Leave has no confirmation, progress, or robust error handling; the backend also permits an owner to leave without transfer/lifecycle handling.
- Create/join/report surfaces can display raw backend exceptions.
- Dense invite/member/leaderboard layouts need large-text and narrow-width tests.

---

## 4.10 Offline-first Drift and outbox

### Implemented functionality

- Drift database with alarms, sessions, runs, territories, user stats, and outbox.
- Transactional entity mutation plus outbox enqueue.
- Connectivity-triggered drain.
- Exponential backoff metadata.
- Generic Supabase upserts/deletes.
- Dedicated run RPC branch.
- One-time alarm/user-stat hydration.
- Sync status stream.

### Strong foundation

- Entity writes and enqueue operations occur in one Drift transaction.
- UUIDs are client-generated.
- Only due entries are selected.
- Reentrant in-process drains are guarded.
- Run submission uses the server-authoritative RPC rather than direct territory writes.
- SQLite is created in the background.
- Generated `database.g.dart` matches the six declared tables and passes analysis.

### Critical findings

- **Outbox and local rows have no immutable owner.** The worker stamps whichever user is active at drain time onto queued payloads (`sync_worker.dart:59-60`, `104-106`).
- **Run retry is not idempotent.** A committed server result with a lost response leaves a queued retry that repeatedly fails on the run primary key.

### High findings

- Skipped sessions allow `completedAt == null` locally, while live `sessions.completed_at` is `NOT NULL`; these entries are permanently unsyncable.
- `nextAttemptAt` is stored but no timer/lifecycle job wakes the worker when it becomes due.
- Later operations for the same entity continue after an earlier failure and can overtake it, restoring stale state or applying delayed deletes.
- Pull is one-time hydration: it exits when any local alarm exists and never converges cross-device updates/deletes.
- Pull only restores alarms and user stats; sessions and runs are not restored.
- Partial pull success can permanently suppress retry of later datasets.
- Every exception is retried identically forever; there is no permanent error classification, dead letter, max attempt, retained error, or telemetry.
- Territory cache cannot represent or apply `deleted_at`.

### Medium findings

- Local schema omits sync-critical ownership and deletion fields and is materially different from the backend.
- Local checks are weaker than server checks, allowing durable poison payloads.
- Outbox due query lacks an index and bounded batches.
- Auth absence silently returns and has no retry trigger on auth-state change.
- Sync status is non-replaying and appears unused by UI.
- Tax increment calculation is not atomic.
- Pull parsing uses brittle direct casts and aborts on one malformed row.
- Applying an authoritative run result does not update local `updatedAt`.
- First backoff delay is effectively twice the configured initial delay.

---

## 5. UI and component inventory

| Surface | Implementation status | Review summary |
|---|---|---|
| Startup gate | Implemented | Persisted but blank/errorless during preference load; no bootstrap recovery UI |
| Onboarding carousel | Implemented | Strong visual identity; incomplete permission/reliability sequence; responsive and reduced-motion gaps |
| Battery exemption | Implemented for Android concepts | Not platform-adaptive; dead `Continue` state from Profile; weak errors/busy states |
| App shell | Implemented | Clear four-tab navigation; partial wide-layout polish |
| Home | Mostly implemented | Real data for most cards; fabricated daily goal; hidden errors |
| Alarm list/editor | Implemented | Polished cards and controls; destructive preview and non-awaited operations |
| Alarm ring | Implemented | Correct global takeover, safe area, clear tax/rep messaging, accessible escape |
| Alarm reliability test | Partial | Can schedule a test but cannot durably prove killed-state success |
| Verification | Implemented | Clear camera/progress/escape UI; needs lifecycle/error/performance isolation |
| Workout celebration sheet | Implemented | Strong completion moment; depends on correctness of completion result |
| Territory map | Implemented | Vector map, bbox refresh, filters; stale cache, attribution, offline, and area correctness gaps |
| Active run | Implemented | Strong metrics/loop/capture states; service lifecycle and exception trapping risks |
| Territory capture sheet | Implemented | Clear feedback; backend “delta” value can be overstated |
| Squad empty/create/join | Implemented | Clear flows; raw errors and authorization assumptions |
| Squad loaded/leaderboard | Implemented | Useful polling and semantics; live section is nonfunctional/insecure |
| Profile | Mostly implemented | Real auth/theme/settings; unsafe account transitions and deletion semantics |
| Appearance dialog | Implemented | Functional; persistence race remains |
| Email/Google linking | Implemented | Correct UID-preserving direction; weak validation/error lifecycle |
| Sign-out dialog | Implemented | Confirmation exists; operation is unsafe with unpartitioned local data |
| Delete-account dialog | Partial | Remote call exists; local data retained and backend FK failures possible |
| `ExpressiveFlower` | Reusable | Strong branding; should honor reduced motion |
| `ExpressiveLoader` | Reusable | Distinctive; continuous motion and progress semantics need work |
| `ExpressiveSwitch` | Reusable | Custom semantics exist; native keyboard/focus behavior is weaker than `Switch` |
| `StatTile` | Reusable | Consistent primitive; combined semantic labeling should be verified |
| `SkeletonPainter` | Reusable | Lightweight custom paint; transform/crop and repaint conditions are incomplete |
| Map controls/chips | Reusable local widgets | Good tooltips/hit targets; dense layouts need adaptive wrapping |

### Cross-cutting accessibility observations

Strengths:

- `SafeArea` is used on major alarm, verification, map, run, and squad surfaces.
- Several cards consolidate semantics rather than reading decorative children separately.
- Alarm overlay excludes the underlying route from accessibility traversal.
- Escape paths exist in mission-critical ring/verification flows.
- Many icon controls use tooltips and approximately 44×44 targets.

Gaps:

- Reduced-motion settings are not consistently honored.
- Dynamic rep/status values need semantic live regions.
- Maps need meaningful nonvisual equivalents beyond area totals.
- Ownership uses color heavily.
- Large text, landscape, compact height, and screen-reader order are largely untested.
- Custom switches/gesture controls need keyboard and focus validation.

---

## 6. Dependency review

Resolved versions below come from `pubspec.lock` at review time.

### Direct dependencies

| Package | Resolved | Usage and assessment |
|---|---:|---|
| `flutter` | SDK | Core application framework |
| `flutter_bloc` | 9.1.1 | Used; plan-aligned |
| `equatable` | 2.1.0 | Used for state/entities |
| `get_it` | 8.3.0 | Used; 9.2.1 resolvable, major upgrade requires review |
| `injectable` | 2.7.1+4 | Used; coordinate any 3.x upgrade with generator |
| `supabase_flutter` | 2.16.0 | Used; plan-aligned |
| `flutter_dotenv` | 6.0.1 | Used for client configuration |
| `drift` | 2.34.2 | Used; plan-aligned |
| `sqlite3_flutter_libs` | 0.5.42 | Candidate for removal; latest line is EOL and current Drift/sqlite build hooks can bundle SQLite |
| `path_provider` | 2.1.6 | Used for DB path |
| `path` | 1.9.1 | Used for path composition |
| `alarm` | 5.5.0 | Used; mission-critical and plan-aligned |
| `camera` | 0.12.0+2 | Used; plan-aligned |
| `google_mlkit_pose_detection` | 0.15.0 | Used; beta/community wrapper risk remains |
| `google_mlkit_commons` | 0.12.0 | Directly used for image metadata |
| `flutter_foreground_task` | 10.0.0 | Used; Android-centric assumptions and manifest/lifecycle issues |
| `geolocator` | 14.0.3 | Used |
| `kalman_dr` | 0.4.4 | Used; plan requests an exact pin but pubspec uses a caret constraint |
| `latlong2` | 0.9.1 | Used; 0.10.1 available |
| `turf` | 0.0.12 | No current imports; candidate for removal unless near-term pre-check work needs it |
| `maplibre_gl` | 0.26.2 | Used for vector maps |
| `uuid` | 4.6.0 | Used for client IDs |
| `permission_handler` | 12.0.3 | Used |
| `dynamic_color` | 1.8.1 | Used |
| `wakelock_plus` | 1.7.0 | Used |
| `connectivity_plus` | 6.1.5 | Used; 7.3.1 resolvable, major upgrade review needed |
| `sentry_flutter` | 9.25.0 | Installed but not initialized/imported; currently adds surface without observability |
| `motor` | 1.1.0 | No current imports; candidate for removal |
| `google_fonts` | 6.3.3 | Used; runtime-fetch concern; 8.2.0 resolvable |
| `shared_preferences` | 2.5.5 | Used for onboarding/theme |
| `google_sign_in` | 7.2.0 | Used for identity linking |

### Development dependencies

| Package | Resolved | Assessment |
|---|---:|---|
| `flutter_test` | SDK | Used |
| `flutter_lints` | 6.0.0 | Used through analysis config |
| `build_runner` | 2.15.1 | Required; 2.15.2 available |
| `drift_dev` | 2.34.0 | Required; behind runtime patch version and 2.34.5 available |
| `injectable_generator` | 2.12.1 | Required; coordinate with runtime package |
| `bloc_test` | 10.0.0 | Used |
| `mocktail` | 1.0.5 | Used |
| `patrol` | 3.20.0 | Installed but no integration tests; 4.8.0 is a major upgrade |

### Override

`flutter_fgbg: 0.7.1` is forced by `dependency_overrides`.

Risks:

- It bypasses normal dependency resolution.
- The reason is not documented next to the override.
- 0.8.0 exists and includes iOS packaging changes.
- Future `alarm` upgrades may remain pinned to an incompatible version.

Document the exact compatibility reason and removal condition, then test Android and iOS before changing it.

### `flutter pub outdated` summary

Direct packages with newer resolvable major versions included:

- `connectivity_plus` 7.3.1
- `get_it` 9.2.1
- `google_fonts` 8.2.0
- `injectable` 3.0.0
- `latlong2` 0.10.1
- `sqlite3_flutter_libs` 0.6.0+eol
- `patrol` 4.8.0

These are not automatic upgrade recommendations. Address correctness and security first; upgrade majors in isolated changes with platform/build/test validation.

### Dependency security/maintenance conclusion

No known package advisory was surfaced during the package review, but this does not remove maintenance risk. The highest-risk dependencies are those owning native alarm, camera/ML, foreground execution, and niche geospatial filtering. Keep those isolated, pinned deliberately, and covered by device/golden tests.

---

## 7. Supabase backend review

## 7.1 Project and extension state

- Project: `awaken-dev`
- Project ref: `qxxkydisyqnodskmymla`
- Region: `ap-southeast-1`
- PostgreSQL: 17.6
- PostGIS: 3.3.7 in `extensions`
- Status: active/healthy

Installed extensions relevant to the app include PostGIS, pgcrypto, uuid-ossp, pg_stat_statements, Supabase Vault, and PL/pgSQL. Keeping PostGIS outside `public` is a strength.

## 7.2 Public table inventory

| Table | Rows observed | RLS | Purpose and notes |
|---|---:|---|---|
| `profiles` | 10 | Enabled | User profile, color, streak tier, squad membership; authoritative columns too broadly writable |
| `alarms` | 13 | Enabled | 12 live, 1 soft-deleted; own-row `ALL` policy |
| `sessions` | 0 | Enabled | Workout history; `completed_at NOT NULL` conflicts with skipped local sessions |
| `runs` | 0 | Enabled | PostGIS LineString, own select/insert; no evidence of successful territory pipeline use |
| `territories` | 0 | Enabled | MultiPolygon, public read, no client mutation policy |
| `user_stats` | 1 | Enabled | Tax multiplier; currently client-writable |
| `squads` | 1 | Enabled | Squad metadata/invite/owner |
| `squad_reports` | 0 | Enabled | Moderation reports; membership relationship not enforced |

All current public tables have RLS enabled. `territories` correctly has no client insert/update/delete policy.

### Important schema strengths

- `runs.path` is `geometry(LineString, 4326)`.
- `territories.geom` is `geometry(MultiPolygon, 4326)`.
- Area calculation uses `::geography` rather than square degrees.
- GiST indexes exist on run paths and territory geometry.
- Common entities use UUID primary keys and soft-delete columns.
- Current stored rows showed no obvious orphan/check/geometry corruption in aggregate review.

## 7.3 Views

`territories_geojson` exposes live territories with GeoJSON conversion and uses `security_invoker=true`, preserving underlying RLS. This is a good posture for public map reads.

## 7.4 Functions and RPCs

| Function | Security | Assessment |
|---|---|---|
| `create_squad(text)` | Definer | Auth/current-membership checks; input/lifecycle/rate-limit hardening needed |
| `join_squad(text)` | Definer | Invite validation exists; bypassable through direct `profiles.squad_id` update |
| `leave_squad()` | Definer | Does not resolve owner lifecycle |
| `squad_members(uuid)` | Definer | Membership check exists; trusts writable membership and includes soft-deleted state |
| `squad_leaderboard(uuid)` | Definer | Membership check exists; trusts writable tier/membership and can count deleted/overlapping territories |
| `submit_run(...)` | Definer | **Malformed search path, no speed validation, no idempotency** |
| `territories_in_bbox(...)` | Invoker | Correct two-schema search path; needs bounds and a hard row cap |
| `territories_set_area()` | Invoker trigger helper | Geography formula correct; **malformed search path** |
| `recompute_streak_tier()` | Definer trigger helper | Public execute grant unnecessary; writable sessions and soft-delete/time semantics weaken authority |
| `handle_new_user()` | Definer trigger helper | Correctly ensures profile creation |
| `set_updated_at()` | Invoker trigger helper | Functional; API execute grants are broader than needed |

### Critical backend finding: malformed search path

The deployed definitions for `submit_run()` and `territories_set_area()` set:

```sql
SET search_path TO 'public, extensions'
```

This is one quoted schema name, not two entries. PostGIS is installed in `extensions`, and these functions call unqualified `ST_*` functions. By contrast, the later-fixed bbox function has separate `public, extensions` entries. Fix the definitions and add an executable backend test proving a valid run and area-trigger insert work.

### Critical backend finding: anti-cheat contract

`submit_run()` checks authentication, geometry type, total length, and closure. It does not enforce:

- per-segment speed/teleport limits;
- timestamp order or plausible duration;
- coordinate range;
- minimum/maximum point count;
- payload size;
- accuracy metadata;
- integrity evidence.

The client serializes only coordinates, so consecutive speed cannot be verified server-side. A modified client can submit an arbitrary closed polygon-producing line and receive trusted territory.

### High backend findings

- **Run submission is non-idempotent.** Duplicate `p_run_id` inserts fail instead of returning the existing authoritative result.
- **Profiles are over-writable.** Own-row update can change `squad_id`, `streak_tier`, timestamps, and deletion state.
- **Tax is client-authoritative.** Users can directly reset `user_stats.current_tax_multiplier`.
- **Squad channels lack Realtime authorization.** No private channel config or `realtime.messages` membership policy exists.
- **Account deletion FK handling is incomplete.** Squad owners/report participants can fail deletion.
- **Reports do not enforce squad relationships.** Only reporter identity is checked.
- **Soft-delete filters are inconsistent.** Policies and functions can continue to read/count deleted rows.
- **Streak calculation trusts client-writable sessions and can count soft-deleted/historical data incorrectly.**

### Territory correctness findings

- Returned `captured_area_sqm` is the full submitted polygon, not net new owned area.
- Own-territory merge selects only one intersecting own row; bridging multiple rows can leave overlaps and double-counted totals.
- No exclusion/uniqueness invariant prevents overlapping live own/rival rows under all concurrency cases.
- The bbox RPC accepts arbitrary coordinates and row limits without a server hard cap.

## 7.5 Triggers

Observed triggers include:

- auth user → profile creation;
- `updated_at` maintenance for profiles, alarms, sessions, runs;
- session insert/update → streak recomputation;
- territory insert/update → geography area recomputation.

There are no equivalent `updated_at` triggers for every table, and trigger helper functions have broader execute grants than necessary.

## 7.6 Realtime

- No application public table is enabled for Postgres Changes.
- The current squad design uses Broadcast/Presence rather than table replication.
- No custom `realtime.messages` policies were present.
- This is compatible with polling leaderboards but not with private squad live activity until private channels and membership RLS are implemented.

## 7.7 Authentication

Aggregate state observed:

- Anonymous authentication is active and aligns with the plan.
- Auth users have matching profiles.
- The account-deletion Edge Function is deployed with JWT verification.
- Leaked-password protection is disabled.

The advisor’s anonymous-access warnings must be interpreted in context: anonymous Supabase users are authenticated JWT users. Anonymous-first access is intentional, but abuse controls, CAPTCHA/rate limiting, cleanup of abandoned users, and restrictions on sensitive social actions remain important.

## 7.8 Migrations

Seventeen deployed migrations were listed, covering extensions, core tables, territory RPC/security hardening, recurrence/tax, PostGIS relocation, GeoJSON/bbox functions, squads, grants, and reports.

No checked-in `supabase/migrations/*.sql` directory was found, so deployed schema cannot be source-reviewed or reproduced from this repository. This is a significant operational gap: migrations and backend tests should be versioned with the app.

## 7.9 Advisor findings

### Security

Notable warnings:

- Public/anonymous execute access to `recompute_streak_tier()`.
- Authenticated access to several `SECURITY DEFINER` RPCs. Some are intentional APIs, but each must be manually hardened.
- Anonymous-auth access warnings due to the anonymous-first model.
- Leaked-password protection disabled.

References:

- [Anonymous SECURITY DEFINER executable](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
- [Authenticated SECURITY DEFINER executable](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Password security and leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

### Performance

- Missing covering indexes for `profiles.squad_id`, `sessions.alarm_id`, squad report FKs, and `squads.owner_id`.
- Nine RLS policies call `auth.uid()` per row instead of using `(select auth.uid())` init-plan optimization.
- Three indexes are currently unused, which is expected with empty run/session/territory tables and should not trigger premature removal.

References:

- [Unindexed foreign keys](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
- [Auth RLS initialization plan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)
- [Unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)

---

## 8. Testing and validation

## 8.1 Commands run

### Static analysis

```text
flutter analyze
```

Result: **passed — no issues found**.

### Full tests

```text
flutter test
```

Result: **failed — 30 passed, 1 failed**.

Failure:

- `test/features/alarm/alarm_list_page_test.dart`
- A zero-duration/delayed timer created by `_RiseInState.initState` remains pending after widget disposal (`lib/features/alarm/presentation/pages/alarm_list_page.dart:369-377`).

### Dependency status

```text
flutter pub outdated
```

Result: completed; several newer major versions are available as summarized in the dependency section.

## 8.2 Existing test strengths

- Alarm schedule has basic recurrence tests.
- Rep counter and pose mapper have unit coverage.
- Kalman behavior has a deterministic golden-style test.
- Outbox writer tests use a real in-memory Drift database and verify transaction rollback.
- Wake-up tax store has focused tests.

## 8.3 Highest-priority missing tests

### Alarm/device

- Preview has no production side effects.
- `Alarm.set`/`stop` false and exception behavior.
- Stable native alarm ID persistence/collision handling.
- Same-day recurrence repair, DST, timezone changes.
- Force-kill, screen-off, HUN/FSI, relaunch while ringing.
- Offline cache rearm when auth/pull fails.
- Samsung/Xiaomi physical-device reliability matrix.
- iOS alarm limitations and notification-entry behavior.

### Verification

- Camera permission/no-camera/init failure/retry.
- Lifecycle inactive/resume.
- Stop during in-flight inference and rapid restart.
- Subscription cancellation.
- Noise, side switching, confidence, minimum duration, false movements.
- Recorded landmark fixtures across body types/lighting.
- NV21/BGRA/multi-plane conversion.
- Skeleton crop/rotation alignment.
- Repaint isolation, processed FPS, thermal and battery budgets.
- TalkBack/VoiceOver escape path.

### Sync/account transitions

- User A offline writes → sign-out → User B login.
- Owner mismatch rejection.
- Auth restoration triggers drain.
- Scheduled backoff wake-up.
- Same-entity failed mutation ordering.
- Permanent versus transient failures/dead letter.
- Ambiguous committed-response-loss retry.
- Incremental pull/update/delete convergence.
- v1→v2→v3 Drift migrations with real rows.

### Territory/run

- Android 14+ FGS startup and manifest integration.
- Permission-before-service ordering.
- Background/screen-off/activity/process-loss recovery.
- iOS background path.
- Accuracy/stale/mock/DR/speed gates.
- RDP and closure/length boundary behavior.
- Cache eviction/deletion and polygon holes.
- Map offline/error/attribution states.

### Squad

- Private channel membership enforcement.
- Presence subscription ordering and identity validation.
- Broadcast reception and throttling.
- Channel ref-count cleanup.
- Auth-user switching.
- Create/join/leave/report errors and authorization.
- Owner leave lifecycle.

### Backend

Add pgTAP or an equivalent SQL harness for:

- valid open/closed run;
- too-short/invalid/oversized path;
- per-point speed and teleport rejection;
- idempotent duplicate run IDs;
- lost-response retry;
- self-intersection and polygon validity;
- rival subtraction and area floor;
- multiple-own-row merge;
- net newly captured area;
- concurrent overlapping submissions;
- RLS cross-user denial;
- direct territory mutation denial;
- profile/tax authoritative-column denial;
- report squad relationships;
- private Realtime membership;
- squad owner/report participant account deletion.

---

## 9. File-by-file coverage appendix

The following confirms that every Dart file under `lib/` was included. Generated files were consistency-reviewed rather than stylistically reviewed.

### Top-level application — 6

- `lib/app.dart`
- `lib/main.dart`
- `lib/main_common.dart`
- `lib/main_dev.dart`
- `lib/main_e2e.dart`
- `lib/main_prod.dart`

### Core — 15

- `lib/core/config/env.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/di/injection.dart`
- `lib/core/di/injection.config.dart` *(generated; registration consistency checked)*
- `lib/core/di/register_module.dart`
- `lib/core/error/failures.dart`
- `lib/core/platform/system_capabilities.dart`
- `lib/core/router/navigator_key.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/expressive_widgets.dart`
- `lib/core/theme/motion_tokens.dart`
- `lib/core/theme/no_scrollbar_behavior.dart`
- `lib/core/theme/shape_tokens.dart`
- `lib/core/theme/theme_mode_cubit.dart`
- `lib/core/usecase/usecase.dart`

### Home — 5

- `lib/features/home/data/repositories/home_activity_repository_impl.dart`
- `lib/features/home/domain/entities/recent_activity_entry.dart`
- `lib/features/home/domain/repositories/home_activity_repository.dart`
- `lib/features/home/domain/usecases/watch_recent_activity.dart`
- `lib/features/home/presentation/pages/home_page.dart`

### Onboarding — 13

- `lib/features/onboarding/data/datasources/onboarding_local_datasource.dart`
- `lib/features/onboarding/data/repositories/battery_exemption_repository_impl.dart`
- `lib/features/onboarding/data/repositories/onboarding_repository_impl.dart`
- `lib/features/onboarding/domain/entities/battery_exemption_status.dart`
- `lib/features/onboarding/domain/repositories/battery_exemption_repository.dart`
- `lib/features/onboarding/domain/repositories/onboarding_repository.dart`
- `lib/features/onboarding/domain/usecases/check_battery_exemption_status.dart`
- `lib/features/onboarding/domain/usecases/has_seen_onboarding.dart`
- `lib/features/onboarding/domain/usecases/mark_onboarding_seen.dart`
- `lib/features/onboarding/domain/usecases/open_oem_autostart_settings.dart`
- `lib/features/onboarding/domain/usecases/request_battery_exemption.dart`
- `lib/features/onboarding/presentation/pages/battery_exemption_page.dart`
- `lib/features/onboarding/presentation/pages/onboarding_page.dart`

### Profile — 11

- `lib/features/profile/data/datasources/auth_remote_datasource.dart`
- `lib/features/profile/data/repositories/auth_repository_impl.dart`
- `lib/features/profile/domain/entities/app_user.dart`
- `lib/features/profile/domain/repositories/auth_repository.dart`
- `lib/features/profile/domain/usecases/delete_account.dart`
- `lib/features/profile/domain/usecases/ensure_auth_session.dart`
- `lib/features/profile/domain/usecases/link_with_email.dart`
- `lib/features/profile/domain/usecases/link_with_google.dart`
- `lib/features/profile/domain/usecases/sign_out.dart`
- `lib/features/profile/domain/usecases/watch_current_user.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`

### Shell — 1

- `lib/features/shell/presentation/pages/app_shell_page.dart`

### Alarm — 23

- `lib/features/alarm/data/datasources/alarm_local_datasource.dart`
- `lib/features/alarm/data/datasources/wake_up_tax_store.dart`
- `lib/features/alarm/data/models/alarm_payload.dart`
- `lib/features/alarm/data/repositories/alarm_repository_impl.dart`
- `lib/features/alarm/domain/entities/alarm_schedule.dart`
- `lib/features/alarm/domain/repositories/alarm_repository.dart`
- `lib/features/alarm/domain/usecases/cancel_alarm.dart`
- `lib/features/alarm/domain/usecases/complete_alarm_workout.dart`
- `lib/features/alarm/domain/usecases/dismiss_alarm.dart`
- `lib/features/alarm/domain/usecases/rearm_alarms_from_cache.dart`
- `lib/features/alarm/domain/usecases/reconcile_recurring_alarms.dart`
- `lib/features/alarm/domain/usecases/schedule_alarm.dart`
- `lib/features/alarm/domain/usecases/set_alarm_active.dart`
- `lib/features/alarm/domain/usecases/watch_alarms.dart`
- `lib/features/alarm/domain/usecases/watch_current_streak.dart`
- `lib/features/alarm/domain/usecases/watch_current_tax_multiplier.dart`
- `lib/features/alarm/domain/usecases/watch_ringing_alarm.dart`
- `lib/features/alarm/presentation/bloc/alarm_cubit.dart`
- `lib/features/alarm/presentation/bloc/alarm_state.dart`
- `lib/features/alarm/presentation/pages/alarm_list_page.dart`
- `lib/features/alarm/presentation/pages/alarm_reliability_test_page.dart`
- `lib/features/alarm/presentation/pages/alarm_ring_page.dart`
- `lib/features/alarm/presentation/widgets/workout_celebration_sheet.dart`

### Verification — 16

- `lib/features/verification/data/datasources/camera_datasource.dart`
- `lib/features/verification/data/datasources/pose_detector_datasource.dart`
- `lib/features/verification/data/mappers/pose_mapper.dart`
- `lib/features/verification/data/repositories/pose_verification_repository_impl.dart`
- `lib/features/verification/domain/entities/body_pose.dart`
- `lib/features/verification/domain/entities/verification_result.dart`
- `lib/features/verification/domain/entities/verification_state.dart`
- `lib/features/verification/domain/repositories/pose_verification_repository.dart`
- `lib/features/verification/domain/services/joint_angle.dart`
- `lib/features/verification/domain/services/rep_counter.dart`
- `lib/features/verification/domain/usecases/start_verification_session.dart`
- `lib/features/verification/domain/usecases/stop_verification_session.dart`
- `lib/features/verification/domain/usecases/watch_verification_state.dart`
- `lib/features/verification/presentation/bloc/verification_cubit.dart`
- `lib/features/verification/presentation/pages/verification_page.dart`
- `lib/features/verification/presentation/widgets/skeleton_painter.dart`

### Territory — 29

- `lib/features/territory/data/datasources/geolocator_location_provider.dart`
- `lib/features/territory/data/datasources/location_provider_factory.dart`
- `lib/features/territory/data/datasources/run_foreground_service.dart`
- `lib/features/territory/data/datasources/scripted_location_provider.dart`
- `lib/features/territory/data/datasources/territory_remote_datasource.dart`
- `lib/features/territory/data/mappers/path_simplifier.dart`
- `lib/features/territory/data/mappers/territory_mapper.dart`
- `lib/features/territory/data/repositories/run_tracking_repository_impl.dart`
- `lib/features/territory/data/repositories/territory_repository_impl.dart`
- `lib/features/territory/domain/entities/geo_bounds.dart`
- `lib/features/territory/domain/entities/gps_quality.dart`
- `lib/features/territory/domain/entities/run_capture_result.dart`
- `lib/features/territory/domain/entities/run_track_state.dart`
- `lib/features/territory/domain/entities/territory.dart`
- `lib/features/territory/domain/entities/track_point.dart`
- `lib/features/territory/domain/repositories/run_tracking_repository.dart`
- `lib/features/territory/domain/repositories/territory_repository.dart`
- `lib/features/territory/domain/usecases/abandon_run.dart`
- `lib/features/territory/domain/usecases/capture_run.dart`
- `lib/features/territory/domain/usecases/refresh_territories.dart`
- `lib/features/territory/domain/usecases/start_run.dart`
- `lib/features/territory/domain/usecases/watch_owned_area.dart`
- `lib/features/territory/domain/usecases/watch_run_state.dart`
- `lib/features/territory/domain/usecases/watch_territories.dart`
- `lib/features/territory/presentation/bloc/run_tracking_cubit.dart`
- `lib/features/territory/presentation/pages/active_run_page.dart`
- `lib/features/territory/presentation/pages/territory_page.dart`
- `lib/features/territory/presentation/widgets/territory_capture_sheet.dart`
- `lib/features/territory/presentation/widgets/territory_map_style.dart`

### Squad — 17

- `lib/features/squad/data/datasources/squad_remote_datasource.dart`
- `lib/features/squad/data/repositories/squad_repository_impl.dart`
- `lib/features/squad/domain/entities/leaderboard_entry.dart`
- `lib/features/squad/domain/entities/squad.dart`
- `lib/features/squad/domain/entities/squad_presence_member.dart`
- `lib/features/squad/domain/entities/streak_tier.dart`
- `lib/features/squad/domain/repositories/squad_repository.dart`
- `lib/features/squad/domain/usecases/create_squad.dart`
- `lib/features/squad/domain/usecases/join_squad.dart`
- `lib/features/squad/domain/usecases/leave_squad.dart`
- `lib/features/squad/domain/usecases/watch_leaderboard.dart`
- `lib/features/squad/domain/usecases/watch_my_rank.dart`
- `lib/features/squad/domain/usecases/watch_my_squad.dart`
- `lib/features/squad/domain/usecases/watch_squad_presence.dart`
- `lib/features/squad/presentation/bloc/squad_cubit.dart`
- `lib/features/squad/presentation/bloc/squad_state.dart`
- `lib/features/squad/presentation/pages/squad_page.dart`

### Sync — 14

- `lib/sync/connectivity/connectivity_watcher.dart`
- `lib/sync/local/database.dart`
- `lib/sync/local/database.g.dart` *(generated; schema/mapping consistency checked)*
- `lib/sync/local/tables/alarms_table.dart`
- `lib/sync/local/tables/runs_table.dart`
- `lib/sync/local/tables/sessions_table.dart`
- `lib/sync/local/tables/sync_outbox_table.dart`
- `lib/sync/local/tables/territories_table.dart`
- `lib/sync/local/tables/user_stats_table.dart`
- `lib/sync/outbox/local_writer.dart`
- `lib/sync/outbox/outbox_operation.dart`
- `lib/sync/outbox/sync_worker.dart`
- `lib/sync/pull/pull_down_sync.dart`
- `lib/sync/sync_status.dart`

**Total: 150 Dart files.**

---

## 10. Final assessment

Awaken’s design direction is sound and several difficult foundational choices are already correct: the alarm overlay is globally placed, native alarm termination behavior is explicit, verification plugins are isolated, local writes are transactionally queued, territory mutation is server-side, PostGIS types and geography area math are appropriate, anonymous auth preserves a stable remote UID, and every public table has RLS.

The current implementation nevertheless has cross-account privacy/data-integrity risks and release-blocking correctness gaps in all three mission-critical loops:

- **Alarm:** preview/native-result/recurrence/startup reliability.
- **Verification:** lifecycle, state isolation, accuracy, and performance.
- **Territory:** foreground execution, process recovery, server-verifiable anti-cheat, and RPC correctness.

The most efficient next milestone is a focused hardening phase rather than additional feature work. Resolve P0 ownership/security/correctness issues, add backend migrations/tests to source control, make the existing suite green, then validate the core loops on real Android and iOS devices before expanding UI or social functionality.
