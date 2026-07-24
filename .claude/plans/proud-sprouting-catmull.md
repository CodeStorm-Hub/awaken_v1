# Implementation Plan: Session Findings + Appium E2E Infrastructure

## Context

This session's live testing, design critique, and accessibility review surfaced 31 findings across the territory feature and Home screen, plus two open items: (1) no automated way to verify a full realistic-pace loop-closure capture, and (2) the Home screen was the only one to get the deep two-skill (design-critique + accessibility-review) treatment. The user has since decided:
- Loop-closure verification should become a **real, permanent Appium-based E2E test**, covering both an Android emulator and a real iOS device (sideloaded via SideStore/iLoader, cable-connected, driven from Windows — no Mac available day-to-day, but GitHub Actions already builds unsigned IPAs, giving access to a macOS runner for anything that genuinely requires Xcode).
- The other 5 screens (Alarms, Territory, Active Run, Squad, Profile) should get the same deep design-critique + accessibility-review pass Home received, with fixes applied.

Researched Appium's actual docs (appium.io) rather than assuming: Android automation via the UiAutomator2 driver is standard and needs nothing unusual. **Real iOS device automation is the hard part** — Apple's XCTest framework (which Appium's XCUITest driver is built on) has no API to simulate GPS location on simulators *or* real hardware; `mobile: setLocation` simply doesn't work on iOS the way it does on Android. Building WebDriverAgent (WDA) normally requires `xcodebuild`, i.e. a Mac — but Appium's `usePreinstalledWDA`/`prebuiltWDAPath` capabilities (XCUITest driver ≥11.5.0, iOS ≥17) let a **pre-signed WDA app**, built once on any Mac (including a GitHub Actions macOS runner), be installed and driven from a non-Mac host via `go-ios`, with zero `xcodebuild` calls on the Windows machine. That solves "drive the iOS device from Windows" — but it does not solve "fake the GPS," since that's an OS-level restriction, not a WDA capability gap. The plan below builds a small in-app scripted-location test hook instead — the standard industry workaround for exactly this Apple limitation — so the *same* fixture-driven test works identically on both platforms.

---

## Part A — Code/design/accessibility fixes (from the 31 findings)

### A1. Bugs already fixed this session (no action needed, listed for completeness)
`RunTrackingRepositoryImpl._onPosition`'s velocity-gate bypass, dead-reckoning positions counted as distance, `Env.mapStyleUrl` empty-string fallback, and the `territories_in_bbox` search_path warning are all already fixed and verified. Not part of this plan's work.

### A2. Border-rendering artifact on paired quick-action buttons
**File:** `lib/features/home/presentation/pages/home_page.dart` (`_QuickAction`, lines ~563-607) and its two call sites (lines ~266-297).
**Fix:** Replace the two independently-decorated `_QuickAction` containers (each with its own asymmetric `BorderRadius` + one carrying `Border.all()`) with a single outer `Container`/`Material` using one uniform `BorderRadius.circular(999)` and one `Border.all()`, containing a `Row` of two `InkWell` regions separated by the existing 3px gap (or a `VerticalDivider`). This removes the asymmetric-radius-plus-border combination that produces the stray line under Impeller. Apply the same pattern anywhere else in the codebase using the same two-adjacent-bordered-containers shape (grep for `BorderRadius.horizontal` + `Border.all` pairs — e.g. check `active_run_page.dart`'s stat tiles if any use borders).

### A3. Destructive-action severity differentiation
**Files:** `lib/features/profile/presentation/pages/profile_page.dart` (Sign out, Delete account), `lib/features/squad/presentation/pages/squad_page.dart` (Leave squad).
**Fix:** Introduce a shared two-tier button style in `core/theme/` (or reuse `expressive_widgets.dart` if a suitable helper exists): reversible actions (Sign out, Leave squad) get a neutral/outlined style; only the genuinely irreversible action (Delete account) keeps the filled-red treatment. Confirmation dialogs stay as-is (already good, specific copy).

### A4. Achievements: locked-state guidance + accessibility semantics
**File:** `lib/features/home/presentation/pages/home_page.dart` (`_AchievementsRow`, lines ~354-405).
**Fix (design):** add a subtitle under each locked achievement showing distance-to-unlock (e.g. "3-day streak — 3 more days"), computed from the same `streak`/`areaSqm`/`squadSnapshot` values already in scope.
**Fix (a11y, WCAG 1.3.1):** wrap each tile in `Semantics(label: '${a.label}, ${a.unlocked ? "unlocked" : "locked"}')` so lock state isn't color-only.

### A5. Profile avatar touch target
**File:** `lib/features/home/presentation/pages/home_page.dart` (`_ProfileAvatar`, lines ~320-350) — also check `SquadPage`'s equivalent avatar circle (same 40x40 pattern was used there per this session's `territory_page.dart`/`squad_page.dart` review).
**Fix:** bump the tappable `InkWell`/`SizedBox` region to 44x44 (WCAG 2.5.5), keeping the 40px visual circle inset if the smaller size is the intended visual weight.

### A6. Tooltip → screen-reader label verification
**File:** same `_ProfileAvatar`. Confirm (don't just assume) that `Tooltip(message: 'Profile')` reaches TalkBack as the accessible name; if the captured semantics tree still shows only "G", wrap explicitly in `Semantics(label: 'Profile', button: true, excludeSemantics: true, child: ...)`.

### A7. Zero-state framing for streak/territory stats
**File:** `home_page.dart`'s stat-tile row (lines ~151-197). Add conditional copy for `streak == 0 && areaSqm == 0` (e.g. swap the stat value display for a short "Get started" prompt) so a fresh account doesn't read as broken next to a populated "#1" squad rank.

### A8. Empty-space problem on Alarms and Squad
**Files:** `lib/features/alarm/presentation/pages/alarm_list_page.dart` (or equivalent), `squad_page.dart`.
**Fix:** vertically center the existing content column when it doesn't fill the viewport (wrap in `Center`/`Align` with the scroll view, or use a `CustomScrollView` + `SliverFillRemaining` pattern), rather than leaving a large blank block above the FAB/below the card.

### A9. Corner-radius audit
Grep all `BorderRadius.circular`/`BorderRadius.horizontal` literals across `lib/features/**/presentation/` and cross-check against `core/theme/shape_tokens.dart`'s defined scale; replace ad hoc literals with token references where a matching token exists, flag any radius that doesn't fit the scale for a design decision.

### A10. "Start run" visual weight vs. "View alarms"
**File:** `home_page.dart`'s `_QuickAction` styling. If confirmed as unintentional (not a deliberate primary/secondary distinction), give "Start run" the stronger filled/high-contrast treatment currently reserved for "View alarms," since it's the core gamification-loop entry point.

---

## Part B — Deep design-critique + accessibility-review pass, remaining 5 screens

For each of **Alarms, Territory (map), Active Run, Squad, Profile**:
1. Launch the app on the Android emulator (Android-MCP), capture a fresh screenshot of the screen (and, where relevant, its key interactive states — e.g. Active Run's loop-closed state, Territory's layers sheet open).
2. Run `/design:design-critique` and `/design:accessibility-review` against each screenshot individually, same depth as the Home pass (read the actual widget source alongside the screenshot, don't guess contrast/target-size from pixels alone — this session's Home pass showed real value in cross-checking against code).
3. Triage findings the same way as Part A (bugs → design → a11y), and apply fixes screen-by-screen rather than batching all 5 screens' fixes into one giant diff — keeps each change reviewable and testable independently.
4. Re-run both skills once more after fixes land, to confirm the finding is actually resolved (mirrors this session's "verify the fix live" pattern used for the two GPS bugs).

---

## Part C — Appium E2E infrastructure (Android emulator + real iOS device)

### C1. In-app scripted-location test hook (shared by both platforms)
This is the piece that makes the iOS half possible at all, given Apple's XCTest has no location-simulation API for real hardware.

- New file: `lib/features/territory/data/datasources/scripted_location_provider.dart` — implements `kalman_dr`'s `LocationProvider` interface (same contract `GeolocatorLocationProvider` already implements), reading a bundled JSON fixture of `{lat, lng, tOffsetMs}` waypoints and replaying them on a `Timer` at real-world pace. Reuse the exact same realistic-pace out-and-back/square-loop shape already validated live this session (≤7 m/s, ≥400m total, closes within 30m) as the default fixture — it's already proven to trip the loop-closure logic correctly.
- Small DI change in `RunTrackingRepositoryImpl.startRun()` (currently constructs `GeolocatorLocationProvider()` inline): extract the location-provider construction behind an injectable factory (`LocationProvider Function()`), so a new build entrypoint can swap it.
- New entrypoint `lib/main_e2e.dart` (mirrors `main_dev.dart`/`main_prod.dart`, delegates to `main_common.dart`'s `bootstrap()` with an added `useScriptedLocation: true` flag) registers `ScriptedLocationProvider` in place of `GeolocatorLocationProvider` for this flavor only. Add a matching `e2e` product flavor in `android/app/build.gradle.kts` (same pattern as `dev`/`prod`) and an iOS scheme/configuration if the existing Xcode project structure supports flavors (check `ios/Runner.xcodeproj` — if not flavor-aware yet, a `--dart-define=E2E_SCRIPTED_LOCATION=true` checked in `main_common.dart`'s bootstrap is a lighter alternative to a full new flavor).
- This keeps every production code path completely untouched — the scripted provider only ever exists in the E2E build.

### C2. Android: Appium + UiAutomator2
- Standard, no unusual constraints. `npm i -g appium`, `appium driver install uiautomator2`, run against `emulator-5554` (already set up and proven this session) or any Android device.
- Capabilities: `platformName: Android`, `appium:automationName: UiAutomator2`, `appium:app: <path to e2e-flavor APK>` (or `appPackage`/`appActivity` if already installed).
- Test script (WebdriverIO or Python client — match whatever the team already uses elsewhere, or default to Python since it's the lowest-ceremony Appium client): launch app, tap Territory tab, tap Start run, wait for the scripted fixture to play out (fixed duration, known from the fixture), assert "Loop closed — ready to capture!" appears, tap Close loop & capture, assert either the `TerritoryCaptureSheet` appears or a specific accepted/pending outcome — this is the first time this session's manual testing gets turned into a repeatable, CI-runnable assertion instead of a one-off manual pass.

### C3. iOS: Appium + XCUITest driver, real device, no Xcode on the Windows host
1. **One-time WDA build (GitHub Actions macOS runner, not the Windows dev machine):** add a job to the existing CI workflow (alongside the unsigned-IPA build) that runs on `macos-latest`, builds `WebDriverAgentRunner-Runner.app` from the XCUITest driver's bundled WDA project (or `appium-webdriveragent` directly), signs it with the same free/personal-team Apple ID + provisioning already used for the app's sideload signing, strips the embedded `Frameworks/XC*` directories (per Appium's documented preinstalled-WDA setup), and publishes the resulting `.app`/`.ipa` as a build artifact.
2. **Install WDA on the device from Windows:** use `go-ios` (`ios install-app` or equivalent) to install the downloaded WDA artifact onto the real device over USB — no Xcode needed for this step, only for the one-time build in CI.
3. **Pairing/Developer Disk Image:** iOS 17+ personalized Developer Disk Image mounting is needed for XCTest sessions; use `pymobiledevice3` (pure Python, Windows-compatible) for device pairing and DDI mounting, since it reimplements the relevant Apple protocols without Xcode.
4. **Run Appium against the real device:** capabilities `platformName: ios`, `appium:automationName: XCUITest`, `appium:udid: <device-udid>`, `appium:usePreinstalledWDA: true`, `appium:updatedWDABundleId: <same bundle id used when signing WDA>`. XCUITest driver ≥11.5.0 talks to the device over `devicectl`/USB via `go-ios`'s port-forwarding, no macOS required on the Appium host itself.
5. Same test script logic as C2 — the scripted-location fixture from C1 makes the iOS run behave identically to Android, sidestepping the fact that real iOS hardware has no GPS-mocking API at all.
6. **Explicitly not pursued:** jailbreak-based location spoofing (introduces device/security risk disproportionate to the goal) and Xcode GPX-file simulation (requires a Mac actively attached, defeats the "Windows + sideloaded app" setup this is built for).

---

## Verification

- **Part A/B fixes:** `flutter analyze` (must stay at 0 issues, current baseline) + `flutter test` (same pre-existing flaky `alarm_list_page_test.dart` timer test, no new failures) after each screen's fixes land. Re-run the two design skills per-screen to confirm findings actually resolved, same as this session's pattern.
- **Part C (Android):** run the new Appium/UiAutomator2 script against `emulator-5554` locally, confirm the capture assertion passes with the scripted fixture (no manual `adb emu geo fix` scripting needed anymore — this replaces that ad hoc approach with something repeatable).
- **Part C (iOS):** first confirm the CI-built WDA artifact installs via `go-ios` and a bare `usePreinstalledWDA` session actually starts (no test logic yet) before wiring up the full capture test — isolates "is the iOS pipeline plumbing correct" from "does the app logic work," since this is genuinely new infrastructure with more moving parts than the Android side.
- Update project memory (`project_phase_status.md`) once each part lands, same as every prior session's pattern, noting what's now real vs. still open.
