# Modernization Assessment — Awaken

*Repo: `/home/syed/workspace/awaken_v1` · Assessed at commit `0d86b49` (2026-08-04) · Assessment date 2026-08-07*

## Executive Summary

Awaken is a Flutter-based gamified alarm/fitness app (camera-verified alarm dismissal, GPS
territory-capture runs, squads/leaderboards) targeting Android and iOS on a shared
Supabase/Postgres+PostGIS backend, currently ~25K lines of Dart application code plus thin
native shims (313 LOC Kotlin, 229 LOC Swift). The codebase is well-architected (consistent
feature-first Clean Architecture, BLoC state management, offline-first outbox sync) and its
security posture is solid — the review found no critical or high-severity vulnerabilities, only
one medium-severity brute-forceable invite code and a scope-creep permission declaration. The
headline risk is **platform parity, not code quality**: this app was recently retargeted from
Android-only to Android+iOS, and both the architecture and technical-debt review independently
converged on the same unfinished seam — iOS background location/run-tracking is declared in
`Info.plist` but not implemented, and the Android-oriented foreground-service call is invoked
unconditionally on iOS rather than being branched around. Recommendation: this is a **Refactor**
engagement (harden the existing modern stack in place), not a rewrite or version uplift — no
`/modernize-uplift`/`/modernize-transform`/`/modernize-reimagine` routing is needed; the punch
list below is normal engineering backlog.

## System Inventory

Manual LOC count (no `scc`/`cloc`/`lizard` available in this environment — fallback per the
assessment skill's Step 1 contingency: `find` + `wc -l`, generated files excluded):

| Area | LOC | Files |
|---|---|---|
| `lib/` (Dart, excl. `*.g.dart`/generated/`injection.config.dart`) | 24,977 | ~234 |
| `test/` (Dart) | 3,598 | — |
| `android/` (Kotlin/Java, excl. `build/`) | 313 | — |
| `ios/` (Swift/Obj-C, excl. `Pods/`) | 229 | — |
| `supabase/` (SQL migrations) | 2,910 | — |
| Generated Dart (`*.g.dart`, `injection.config.dart`, l10n) | 7,725 | — |

**Per-feature `lib/` breakdown:**

| Feature | LOC | Files |
|---|---|---|
| territory | 7,871 | 48 |
| alarm | 3,592 | 36 |
| squad | 3,326 | 39 |
| profile | 2,429 | 26 |
| core | 2,251 | 18 |
| verification | 1,869 | 16 |
| sync | 1,054 | 15 |
| home | 1,303 | 7 |
| onboarding | 1,093 | 13 |
| shell | 306 | 1 |

**Largest files** (proxy for complexity, no CCN tool available): `territory_page.dart` (2,365
LOC), `active_run_page.dart` (1,141), `home_page.dart` (923), `territory_map_style.dart` (915),
`verification_page.dart` (798), `auth_dialog.dart` (694), `expressive_widgets.dart` (570),
`alarm_ring_page.dart` (542).

**Technology fingerprint:** Dart SDK `^3.12.2`; `flutter_bloc ^9.1.1` (BLoC/Cubit, per
[ADR-001](docs/decisions.md)); `get_it`+`injectable` DI; `drift ^2.34.3` offline-first local DB
with a hand-rolled outbox (per [ADR-002](docs/decisions.md)); `supabase_flutter ^2.16.0` backend;
`alarm ^5.5.0`, `camera ^0.12.0`, `google_mlkit_pose_detection ^0.15.0`,
`flutter_foreground_task ^10.0.0`, `geolocator ^14.0.3`, `maplibre_gl ^0.26.2`. Test presence:
`test/` mirrors `lib/features/`, but coverage is uneven (see Technical Debt). Two build flavors
(`dev`/`prod`) share one Supabase project by design.

## Architecture-at-a-Glance

Nine domains: **App shell & bootstrap**, **Core infra** (DI/env/theme), **Platform bridge**
(Android-only `system_capabilities` MethodChannel), **Sync engine** (Drift + outbox, the
mandatory write path for Alarm), and the seven features (**Alarm**, **Verification**,
**Territory**, **Squad**, **Profile**, **Onboarding**, **Home**). Alarm is the only feature that
routes writes through the shared outbox; Territory, Squad, and Profile call Supabase directly via
`SECURITY DEFINER` RPCs — a deliberate, documented split, not an inconsistency. Full dependency
diagram: [ARCHITECTURE.mmd](ARCHITECTURE.mmd).

**Verified Android/iOS asymmetries** (the architecture agent independently confirmed CLAUDE.md's
known gaps and found one new one):

1. `SystemCapabilities` MethodChannel (`lib/core/platform/system_capabilities.dart`) is
   Android-only by design, correctly double-gated at every call site (`Platform.isAndroid`
   checks in `alarm_repository_impl.dart` and `battery_exemption_repository_impl.dart`) — safe,
   but means iOS alarms get none of the FSI/exact-alarm/screen-pinning-lockdown/OEM-autostart
   hardening Android gets.
2. `RunForegroundService.start()`/`stop()` (`lib/features/territory/data/datasources/run_foreground_service.dart`)
   is called **unconditionally** from `run_tracking_repository_impl.dart:164,441` with no
   platform guard — on iOS this hits a notification-only shim that grants no real background
   execution context, silently doing nothing useful rather than being branched around.
3. **New finding:** `ios/Runner/Info.plist:75-82` declares
   `NSLocationAlwaysAndWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription` /
   `UIBackgroundModes: [location]` — but no code path anywhere in `lib/features/territory/**`
   ever requests `LocationPermission.always`; every call site only checks/requests
   default (when-in-use) permission. The iOS binary is provisioned for background location it
   doesn't use.
4. Android deliberately omits `ACCESS_BACKGROUND_LOCATION` to stay in Play's foreground-only
   review tier (documented, intentional); iOS's Info.plist has no matching restraint, so the two
   platforms' declared privacy postures currently diverge even though neither exercises "always"
   location today.
5. Camera image-format handling (NV21 Android / BGRA8888 iOS, read from the actual reported
   format rather than trusted) is correctly cross-platform — verified sound, not a gap.

## Production Runtime Profile

No production telemetry, APM, or observability MCP server was available in this session — this
step is skipped per the assessment skill's contingency. Notably, the technical-debt review found
that Sentry (`lib/main_common.dart`) is wired throughout the codebase but **`SENTRY_DSN` is empty
in the committed `.env.client`**, so none of the app's existing `Sentry.captureException` calls
are currently reaching a real project in any build cut from this checkout — there is no
production error visibility today regardless of what a telemetry query would show.

## Technical Debt

Ranked by remediation value (12 findings; full detail with file:line evidence from the
sub-agent). Several items claimed by the repo's own `tech-debt-audit.md` (2026-07-30) were
independently re-verified as **already fixed** — see the "confirmed not current debt" note below;
don't re-flag them.

1. **`RunForegroundService.start()` called unconditionally on iOS** — the concrete code-level
   form of CLAUDE.md's documented "iOS needs its own path, still open" gap. Add a
   `Platform.isAndroid` guard or an explicit iOS branch rather than relying on the plugin being
   harmless there.
2. **Zero Cubit-level test coverage on the three highest-risk state machines** —
   `alarm_cubit.dart`, `run_tracking_cubit.dart`, `verification_cubit.dart` have no direct
   presentation-layer tests, despite repository/domain tests existing alongside them. These own
   alarm dismissal, GPS anti-cheat filtering, and rep-counting — the core gamification/safety
   logic.
3. **Duplicated submitting-dialog state machine** — `squad/presentation/widgets/text_prompt_dialog.dart`
   and `profile/presentation/widgets/edit_name_dialog.dart` are near-identical (same controller
   lifecycle, submit-lock, error styling, action row); the duplication is even acknowledged in a
   comment but never factored out. Low effort, and extracting it would also help close #2.
4. **`.env.client` is force-tracked in git, contradicting CLAUDE.md's "both are gitignored"
   claim** — `.gitignore` ignores `.env.*` then explicitly un-ignores `.env.client`, plus a
   redundant dead second entry under an unrelated comment block. Not a live secret leak (content
   is client-safe by design), but the doc/config mismatch should be cleaned up.
5. **`territory_page.dart` (2,365 LOC) mixes 9 `setState()` calls into an otherwise BLoC-standard
   app** — a deliberate, in-file-documented optimization to avoid full-page rebuilds on a 1Hz
   tick, not naive misuse, but still the largest and least-approachable file in the repo by a
   wide margin. Worth a decomposition pass (map-layer / HUD / presence-polling) even though each
   piece is individually justified.
6. **Sentry DSN is unset, so all the error-visibility work already done in the repos is currently
   a no-op in production** — `squad_repository_impl.dart` and `run_tracking_repository_impl.dart`
   both have Sentry-reporting error handling with comments explaining it exists "so a
   persistently-failing fetch is visible in prod" — but it isn't, because no DSN is configured.
   Cheap, high-value fix.
7. **`active_run_page.dart` (1,141 LOC) and `home_page.dart` (923 LOC) size not independently
   confirmed as justified** (lower confidence — flagged for an SME follow-up pass, unlike
   `territory_page.dart` which has an in-file rationale).
8. **`AlarmReliabilityTestPage` is wired from two separate entry points** (alarm list page and
   profile page) instead of one shared entry — a legitimate, documented diagnostic feature, just
   duplicated navigation wiring.
9. **Release build silently falls back to debug keystore signing when `android/key.properties` is
   absent** (`android/app/build.gradle.kts:76-79`) — confirmed the file doesn't exist in this
   checkout; a real release-blocker if `flutter build apk --release --flavor prod` is run today
   without first generating an upload keystore.
10. `main_prod.dart` pointing at the same Supabase project as dev is **confirmed intentional**,
    not debt — included only so a future reviewer doesn't re-flag it without context.
11. Squad's presence-write `catch (_) {}` (`squad_repository_impl.dart:369-373`) is deliberately
    best-effort (a denied/missing GPS fix must never block presence tracking) — not a bug, but
    it's the one remaining unlogged catch in an otherwise Sentry-logged file; a breadcrumb (not a
    full capture) would make the failure *rate* visible.
12. **Minor version drift** on `postgrest`/`supabase`/`storage_client`/`realtime_client` and
    `permission_handler_android` — opportunistic only, no CVEs apparent, `flutter analyze` clean.

**Confirmed NOT current debt** (stale claims in root `tech-debt-audit.md` that don't hold up
against current code): squad "god files"/`ChangeNotifier` usage (squad was already split up,
uses BLoC throughout), "zero squad test coverage" (tests now exist — CLAUDE.md itself is stale on
this point), silent error-swallowing without telemetry (now Sentry-logged, module DSN issue
aside — see #6), scattered magic numbers (now centralized in `AppConstants`), unused iOS
background modes (`Info.plist` now only declares `location`), thin ProGuard rules (now
comprehensively populated with rationale comments).

## Security Findings

No critical or high-severity issues. No hardcoded secrets found — `.env.client`'s committed
values (Supabase publishable key, Google OAuth client IDs) and the Firebase/Google API key in
`GoogleService-Info.plist` are all client-safe-by-design identifiers restricted by
package/bundle ID + cert fingerprint on Google's side, not leaked credentials. No SQL/shell
injection surface found (no dynamic SQL, no `Process.run` call sites). No untrusted
deserialization. RLS policies and `SECURITY DEFINER` RPCs (incl. `submit_run`) are correctly
scoped; a prior IDOR class (unscoped `squad_reports` insert, public Realtime squad channels) was
found already fixed in migration history, not currently open.

| ID | CWE | Severity | Location | Summary |
|---|---|---|---|---|
| SEC-001 | CWE-799 Insufficient Attempts Limiting | Medium | `supabase/migrations/20260722173905_add_squad_social_phase6.sql:69-96` (`join_squad`) | 6-char invite codes drawn from a 16-char hex alphabet (~16.7M space) with no rate limit or lockout on `join_squad` — brute-forceable to join an arbitrary private squad and read its members' leaderboard/display data. |
| SEC-002 | CWE-1263/CWE-250 Overly Broad Permission Request | Medium | `ios/Runner/Info.plist:75-79` | Declares Always-location usage strings + `UIBackgroundModes: location` ahead of the feature that needs them (see Architecture finding #3) — inflates the App Store privacy ask for a capability the app doesn't yet use. |
| SEC-003 | CWE-20 Improper Input Validation | Low | `supabase/migrations/20260722173905_...sql:45-47` (`create_squad`); `squads.name`, `profiles.display_name` | No upper-bound length check on squad name / display name (unlike `squad_reports.reason`, which has one) — storage/index bloat and client-rendering-cost risk, not exploitable beyond nuisance. |
| SEC-004 | CWE-209 Sensitive Error Message | Low | `supabase/functions/delete-account/index.ts` (multiple lines) | Raw Postgres error text is returned directly to the client on every failure path; self-only operation so low exploitability, but leaks schema/constraint detail unnecessarily. |

## Documentation Gaps

1. CLAUDE.md states `.env.client` is gitignored — it isn't (Technical Debt #4); a new contributor
   following the doc literally will be surprised.
2. CLAUDE.md's iOS scope note doesn't mention the specific `Info.plist` Always-location
   over-declaration (Architecture #3 / SEC-002) — worth folding into the existing scope-note
   paragraph so it's tracked alongside the other known iOS gaps.
3. CLAUDE.md claims squad has "no test coverage yet" — stale; tests now exist. Should be updated
   or removed so it stops steering future sessions to skip writing squad tests under a false
   premise.
4. No doc currently explains why `RunForegroundService` is called unconditionally on both
   platforms rather than being Android-gated like `SystemCapabilities` — a future contributor
   fixing #1 in Technical Debt would benefit from a one-line rationale (or lack of one) recorded
   in CLAUDE.md once resolved.
5. The Sentry DSN-unset state (Technical Debt #6) isn't mentioned anywhere — someone reading the
   Sentry-logging comments in `squad_repository_impl.dart`/`run_tracking_repository_impl.dart`
   would reasonably assume production visibility exists when it currently doesn't.

## Relative Scale

`lib/` = 24,977 SLOC (Dart, generated code excluded). COCOMO-II basic complexity index:
`2.94 × (24.977)^1.10 ≈ 101`. **This is a relative size/complexity signal only** — useful for
comparing this codebase against other systems in a portfolio, not a timeline or cost estimate. It
assumes traditional human-team productivity, which does not apply to agentic modernization work;
no schedule, person-month figure, or dollar amount is implied by this number.

## Recommended Modernization Pattern

**Refactor (in place).** This is a live, actively-developed application already on a current,
appropriate stack (Flutter/Dart, BLoC, Supabase/Postgres) with a deliberate, well-reasoned
architecture — it does not need a version uplift, a cross-stack rewrite, or a greenfield rebuild.
The work identified here is standard hardening backlog: close the iOS platform-parity gaps
(Architecture #1-4, Technical Debt #1), fix the two medium security findings (SEC-001, SEC-002),
wire up production error visibility (Technical Debt #6), and add presentation-layer test coverage
for the three core state machines (Technical Debt #2). None of `/modernize-uplift`,
`/modernize-transform`, or `/modernize-reimagine` apply — this punch list is regular engineering
work, sequenced by the ranking above.
