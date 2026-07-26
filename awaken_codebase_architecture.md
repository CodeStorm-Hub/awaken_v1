# Awaken — Codebase Architecture Audit

Date: 2026-07-26

## 1. Executive Summary

**Awaken** — gamified alarm + fitness Flutter app, Android+iOS (retargeted 2026-07-22, Android still lead). Alarm dismiss requires camera-verified exercise (ML Kit pose detection); outdoor runs closing geo loop capture "territory" on shared map, squad/leaderboard layer on top.

Stack: Flutter stable, `flutter_bloc` 9.1.1, `get_it`+`injectable` DI, `drift` 2.34 (local DB) syncing to Supabase (`awaken-dev`, Postgres 17 + PostGIS), `alarm` 5.5.0, `camera`+`google_mlkit_pose_detection`, `geolocator`+`kalman_dr` (EKF smoothing), `maplibre_gl` 0.26.2 + self-hosted PMTiles fallback, `sentry_flutter`.

Dev stage: **mid-hardening, pre-device-validation, pre-Play-compliance.** Phases 0-6 (foundations through squad/social) code-complete and unit-tested; Phase 5 (territory) exceeded original scope with an added "v2" layer (decay/bounty/rivalry). Phase 7 (hardening/Play compliance) and 8 (launch) not reached. A 2026-07-25 Supabase review found the app not release-ready (10 headline issues); a 2026-07-26 hardening session fixed the large majority. Biggest unclosed gap across both alarm and pose-verification phases: **their own exit criteria require real physical-device testing that has never run** — everything so far is emulator/unit-test verified only.

## 2. Architectural Blueprint

- **UI/Design system**: Feature-first Clean Architecture, `presentation/→domain/→data/` per feature. M3-Expressive-style hand-rolled tokens (`core/theme/`). Design-system doc (`_ds/`) exists only in a reference handoff copy, not live in repo — and is already stale (asserts Territory/Squad "no code," false now; `motion_tokens.dart`/`shape_tokens.dart` confirmed unused in practice, hardcoded literals used instead).
- **State management**: `flutter_bloc` Cubits everywhere (ADR-001, no Riverpod), all DI-registered via `injectable`. `UseCase<ReturnType,Params>` for one-shot ops, plain `Stream` `call()` for watch-ops (documented split, not inconsistency). No go_router — routing is plain imperative `Navigator`/`MaterialApp` (`lib/core/router/` is a stub, just a `GlobalKey`), plus the alarm ring page painted via `MaterialApp.builder` overlay (confirmed intact, not regressed to route-based).
- **Domain/Services**: `lib/sync/` = hand-rolled offline-first Drift outbox (ADR-002 over PowerSync) — `LocalWriter` is the sole write seam (transactional insert+enqueue), `SyncWorker` drains on connectivity + 60s belt-and-suspenders timer with exponential backoff + dead-letter classification, `PullDownSync` does incremental per-table watermark pulls (excludes `runs`/`territories`, which are geometry/bbox-scoped). One documented exception: `TerritoryRepositoryImpl` is pull-only, writes straight to `AppDatabase` (territories are server-authoritative, no client write path — correct by design).
- **Backend/Supabase**: project `awaken-dev`, RLS-scoped tables, `territories` mutated only via `submit_run()` `SECURITY DEFINER` RPC (validate closure→polygonize→`ST_Difference`/`ST_Union`). Server-side anti-cheat validation added (speed/timestamp/coordinate checks).
- **Native integrations**: Android `MainActivity.kt` exposes `system_capabilities` MethodChannel (FSI/exact-alarm checks, OEM autostart deep links, screen-pinning lockdown via `startLockTask`/`stopLockTask` — not true kiosk mode). Confirmed platform-gated on iOS (`Platform.isAndroid` check, safe fallback, not crash) — matches CLAUDE.md claim exactly. iOS has ML Kit-pinned Podfile deployment target (15.5) and usage strings, but no background-location code path (`flutter_foreground_task` is Android-only; iOS gap open per CLAUDE.md, confirmed still open in code).

## 3. Key Technical Strengths

- Offline-first outbox design is genuinely solid: single write seam, transactional, ordered drain, permanent-vs-transient error classification, dead-letter (3650-day defer, not delete), owner-partition wipe on account switch.
- Alarm reliability engineering exceeds typical Flutter apps: `androidStopAlarmOnTermination=false` correctly set with documented rationale, overlay-based ring page (empirically fixed once, now guarded by doc comment against regression), native FSI/exact-alarm capability checks, OEM autostart best-effort deep links for known-aggressive vendors (MIUI/ColorOS/Vivo/Huawei/Samsung).
- Territory anti-cheat moved server-side (client `isMocked` discard + server per-segment validation in `submit_run()`) — correct trust boundary.
- Map/tile cost risk resolved cleanly: 3-tier `MapStyleLoader` escalation (OpenFreeMap → hosted fallback → self-hosted PMTiles/Cloudflare-Worker+R2, $0/month), exactly matching the PMTiles-skill's prescribed pattern (bounded extract, last-resort tier only).
- Hardening session (2026-07-26) response to the Supabase review was thorough and re-verified against live source rather than checked off blind — fixed `search_path` bug that had broken `submit_run()`, made it idempotent, locked down authoritative columns to RPC-only writes, fixed account-deletion FK ordering, got full test suite green (57 tests).
- Docs hierarchy is coherent and self-correcting: CLAUDE.md and README.md agree on what's authoritative, and CLAUDE.md explicitly documents its own scope-change (Android-only → both platforms) rather than leaving stale claims.

## 4. Critical Insights & Vulnerabilities

**Release-blocking:**
- Android release build signs with the **debug key** (`build.gradle.kts:52`, explicit unresolved TODO) — not Play-Store-shippable as-is.
- No R8/ProGuard config at all.
- `main_prod.dart` still points at the dev Supabase project — no prod backend exists yet.
- Alarm reliability (Phase 1) and pose-verification accuracy (Phase 2) exit criteria — both require multi-device physical hardware testing (force-kill+30min screen-off; 5 body types/lighting ≥95% accuracy) — **never executed**. This is the single biggest risk: the app's core value prop (alarm that can't be dismissed without exercise) is unverified on real hardware.

**Architectural gaps:**
- Android foreground-task handler for run-tracking is still **empty** — GPS tracking lives in the main isolate, not the foreground service, meaning a killed process silently loses in-progress runs. Directly undercuts the territory feature's reliability story.
- iOS has zero background-location implementation despite Info.plist already declaring `NSLocationAlwaysAndWhenInUseUsageDescription` + `UIBackgroundModes: location` — capability declared ahead of code, will draw App Store review scrutiny for unused entitlement.
- "Owned area" stat is a client-cache-only sum, not a true server total — will drift.
- No concurrency-safe `EXCLUDE` constraint on overlapping territories server-side.
- Presence identity in squad realtime is still client-asserted, not server-verified.
- Leaked-password protection is disabled in Supabase Auth dashboard — manual flip needed, not a migration.

**Documentation drift:**
- Refined plan (§4, §2.1 C3) says `flutter_map`; actual app uses `maplibre_gl` — undocumented silent substitution. Outcome is architecturally sound (matches the maplibre-pmtiles-patterns skill's own prescribed pattern) but the plan doc itself was never updated.
- CLAUDE.md says notification permission is requested in `main_common.dart`'s `bootstrap()`; it's actually requested from the onboarding carousel now (`main_common.dart:123-132` documents the move) — stale line in CLAUDE.md.
- Design system reference doc (`_ds/`) only exists in a handoff copy, already describes territory/squad as unbuilt (false), and isn't tied to any commit — will keep drifting since nothing regenerates it.
- Stale cross-file TODO reference: `verification_page.dart:18` points at a TODO in `alarm_ring_page.dart` that no longer exists.

**Minor:**
- `analysis_options.yaml` uses only stock `flutter_lints` — no stricter analyzer rules (no `strict-casts`/`strict-inference`, no `very_good_analysis`).

## 5. Actionable Next Steps (priority order)

1. **Unblock release path**: add real Android signing config (replace debug-signing TODO), enable R8/ProGuard, stand up a separate prod Supabase project and point `main_prod.dart` at it.
2. **Run the exit criteria that were never run**: physical-device alarm reliability matrix (Xiaomi/HyperOS + Samsung minimum, force-kill + 30min screen-off + FSI/exact-alarm), pose-verification accuracy pass (5 body types/lighting, thermal/perf on Snapdragon 6-series). Everything downstream of these two numbers is provisional until this happens.
3. **Fix the run-tracking foreground-task handler** — move GPS collection into the actual foreground service isolate, not main isolate, so process death doesn't silently drop in-progress runs. This is the top functional gap in the territory feature.
4. **Close remaining hardening-status open items**: server-side GPS-accuracy gating on distance/geometry acceptance, `EXCLUDE` constraint for overlapping territories, server-verified squad presence identity, flip leaked-password protection in Supabase dashboard.
5. **Scope the iOS background-location path** (geolocator-based, not `flutter_foreground_task`) or roll back the premature Info.plist entitlements until it's built — current state (declared capability, no implementation) is the worse of the two options for App Store review.
6. **Reconcile docs**: update refined plan's map-engine section to say MapLibre not flutter_map, fix the notification-permission bootstrap claim in CLAUDE.md, either regenerate or timestamp/commit-pin the `_ds` design system doc so it stops asserting false things about territory/squad.
7. **Tighten linting**: consider stricter `analyzer:` rules given this is a safety/reliability-critical app (alarm dismissal logic, anti-cheat) — stock `flutter_lints` alone is thin for this risk profile.
8. **Play Console compliance workstream** (Phase 7, not started): FSI/alarm-category declarations, demo video, Patrol E2E suite (installed, unused per pubspec), accessibility pass.
