# Awaken — Live UI/UX & Functional Review

**Method:** Live testing on a connected Android emulator (Android-MCP + adb logcat + Dart VM
Service for root-causing), cross-referenced against the 7 static screenshots in
`awaken_screenshots/` and the app's source. Screens exercised: onboarding, Home, Alarms
(schedule sheet + list), the alarm ring flow (a real scheduled alarm fired during testing),
Territory, Squad (including the create-squad flow end-to-end), and code review of Profile.
Skills applied: `frontend-design`, `mobile-app-ui-design`, `design-critique`,
`accessibility-review`, plus Flutter-specific architecture/responsive/layout-fix lenses.

---

## 0. ROOT-CAUSE FINDING (most consequential) — no Supabase auth session has ever been created on this device

Discovered while verifying the Squad fix live: creating a real squad through the (now-working)
UI returned `PostgrestException(message: permission denied for function create_squad, code:
42501, details: Unauthorized, hint: null)`. Traced this to `select count(*) from auth.users` on
the live project returning **0** — no anonymous (or any) session has ever actually been
established. `EnsureAuthSession()`'s `signInAnonymously()` call is failing every time, and
`main_common.dart`'s bootstrap silently swallows that failure (`catch (_) {}`, a pre-existing
TODO for the offline-first-launch fallback). The app has been running this entire session as a
fully unauthenticated client against the anon key — which is exactly why `create_squad`
(`authenticated`-only, correctly locked down) was rejected, and calls into question how much of
the sync/outbox pipeline has actually persisted anything to Supabase across prior sessions too.

**Root cause confirmed and now resolved**: Supabase's "Anonymous Sign-ins" provider toggle
had never been enabled in the project dashboard (confirmed directly against the auth API:
`POST /auth/v1/signup` returned `anonymous_provider_disabled` before, a real signed session
after). The user enabled it mid-session (a first attempt didn't take effect because the
settings page wasn't saved). After a hot restart, `auth.users` got a real row and the
create-squad flow completed successfully end-to-end — squad creation, invite code generation,
leaderboard, and `HomePage`'s "Squad rank" tile all now show real data (rank **#1**). This
confirms the entire Phase 6 squad stack (RLS, RPCs, client) works correctly once a session
exists — nothing else needed to change.

---

## Findings, ranked by severity

### 1. CRITICAL — Squad tab hung on a loading spinner forever (fixed and verified live)
**Confirmed live**: navigating to the Squad tab showed a centered spinner indefinitely (60+
seconds observed, never resolving), with no "Create a squad" / "Join with invite code" buttons
ever appearing — the entire Squad feature was unusable.

**Actual root cause** (found by re-testing after an initial fix didn't resolve it, then reading
the code closely): `SquadRepositoryImpl._mySquadController` is a *broadcast* `StreamController`,
which never replays past events to a listener that subscribes after they were added.
`HomePage`'s `WatchMyRank` stat tile and `SquadCubit` both independently call `watchMySquad()`;
whichever subscribes first (in practice `HomePage`, since it builds before the Squad tab's
`BlocProvider` inside the shell's `IndexedStack`) silently consumed the one-shot fetch's single
result. The other subscriber — `SquadCubit` — then waited forever with nothing to receive, since
the underlying fetch is guarded to run only once. Subscription order, not a thrown exception,
was the real cause; a first-pass fix (try/catch + timeout around the fetch) was correct
hardening but didn't by itself resolve the hang — which is why this was re-verified live rather
than assumed fixed from a code read alone.

**Fix**: `watchMySquad()` now caches the last-emitted value and replays it immediately to every
new subscriber before continuing to live updates — subscription order no longer matters. Also
hardened as defense-in-depth: the underlying fetch has a try/catch + 10s timeout (fails open to
"no squad" instead of hanging), and the leaderboard's polling loop no longer lets one failed
request kill the entire stream.

**Verified live after the fix**: the Squad tab now correctly shows the "Create a
squad"/"Join with invite code" empty state immediately, the create-squad dialog accepts input
correctly, and submitting it surfaces finding #0 above as a **proper error message with a "Try
again" button** — not a hang — confirming the error-state UI works as designed.

### 2. HIGH — Territory page: "map tiles not configured" notice was hidden behind the floating control bar (fixed and verified live)
**Confirmed live and in the static screenshots.** The notice text ("Map tiles not configured —
set MAP_TILE_URL_TEMPLATE in .env.client. Territory data still loads.") sat at a fixed position
near the bottom of the map, but the floating control bar (locate / Start run / layers) is pinned
on top of it at the same location, truncating the text mid-sentence and making it unreadable.
This was a Flutter `Stack`/`Positioned` layering bug, not a mock/data issue.

**Fix**: moved the notice into its own card below the "km² captured" chip, clear of the control
bar. **Verified live**: the full sentence is now readable.

### 3. MEDIUM — Alarm ring page gave zero feedback while "Start workout to dismiss" was processing
**Confirmed live**: tapping the button produced no visible change for several seconds (camera
open + ML Kit remote-config fetch, confirmed via logcat) before anything happened. There was no
pressed/loading state, so a user had no way to tell the tap registered — in testing this led to
repeated taps out of uncertainty. The flow does eventually complete correctly (logcat confirmed
`AlarmTriggerApiImpl`/`AndroidAlarm` stop+reschedule), so this was a perceived-responsiveness
gap, not a dead button — but on the app's single highest-stakes screen (per `CLAUDE.md`, alarm
reliability is the top risk), a multi-second silent gap is a real UX defect worth closing.

**Fix**: the button now flips to a "Opening camera…" loading scaffold immediately on tap instead
of a bare blank frame.

### 4. MEDIUM — Accessibility: onboarding's Skip/Next buttons remained exposed to assistive tech underneath the ringing alarm overlay
**Confirmed live** via the accessibility tree: while `AlarmRingPage` was visually on top (per
`app.dart`'s `_AlarmRingOverlay`, which stacks the ring page over whatever route is beneath —
here, the onboarding carousel, since onboarding hadn't been marked seen on this fresh install),
the onboarding page's "Skip"/"Next" buttons and body text were still present and labeled in the
semantics tree. A screen-reader user swiping through the screen during a ringing alarm could
reach and activate controls belonging to a page they cannot see — a real accessibility hazard,
and arguably a correctness one (the whole point of the ring overlay is that nothing else should
be reachable while an alarm rings).

**Fix**: wrapped the covered `child` in `_AlarmRingOverlay` with `ExcludeSemantics` +
`IgnorePointer` whenever an alarm is ringing.

### 5. CRITICAL — Alarm-ring "preview the wake-up flow" never exited under any outcome (fixed and verified live)
**Confirmed live** — found while re-testing after the Squad fix, and personally got stuck on
this exact screen for several minutes before diagnosing it. `AlarmListPage`'s "tap one to
preview the wake-up flow" pushes `AlarmRingPage` as a normal `MaterialPageRoute` with
`PopScope(canPop: false)`. That's correct for a *real* ringing alarm (the same widget is also
used as a raw `Stack` overlay with no route at all, via `_AlarmRingOverlay` — there, the
overlay just disappears once the native alarm stops). But for the *pushed preview* route,
nothing in `_startWorkout` ever calls `Navigator.pop()` — not on a verified completion (after
the celebration sheet), not on a skip, not on backing out of verification — and the back
button was hard-blocked. Every outcome left the preview permanently open; the only way out was
killing the app. Each repeated skip also kept escalating the real wake-up tax multiplier
(intentional design for the real flow, but surprising to hit repeatedly while just trying to
back out of a preview) up to its ×4.0 cap, which confirmed the cap logic itself is correct.

**Fix**: added an `isPreview` flag to `AlarmRingPage` (true only for the pushed-route usage).
When true: the back button is allowed (`canPop: widget.isPreview`), and `_startWorkout` pops
the route after every outcome (verified, skipped, or backed out of verification).

**Verified live**: pressed the system back button on a fresh preview after the fix — it
correctly returned to the Alarms list instead of staying stuck.

### 6. LOW/KNOWN — Home page mock data contradicts real data on the same screen
**Confirmed live**, but this is pre-existing, already-tracked debt (see project memory),
re-surfaced here because it's directly visible on one live screen: the Achievements row shows
"4-day streak" and "Squad player" as unlocked while the adjacent real "Day streak" stat reads 0
and the Squad tab (same session) reads "Not in a squad yet." Similarly, "Recent activity"
hardcodes "Joined Squad 'Sunrise Runners'" despite no such squad existing. This undermines trust
in the page's otherwise-real numbers. **Not fixed in this pass** (out of scope given everything
else found); flagged here for prioritization.

---

## Fixes applied in this pass
1. `SquadRepositoryImpl.watchMySquad()` — replays the last known value to every new subscriber
   (the real fix for #1); `_refreshMySquad()` and `watchLeaderboard()` also hardened with
   try/catch + timeout so a failed request fails open instead of hanging or dying silently.
2. `TerritoryPage` — repositioned the "map tiles not configured" notice so it never sits under
   the floating control bar.
3. `AlarmRingPage` — shows an explicit loading state instead of a blank frame while
   `_startWorkout` is in flight.
4. `_AlarmRingOverlay` (`app.dart`) — excludes the covered route's semantics/pointer events
   while an alarm is ringing.
5. `AlarmRingPage`/`AlarmListPage` — added an `isPreview` flag so the "preview the wake-up flow"
   entry point actually exits (back button + auto-pop on every outcome) instead of trapping the
   user permanently.

All five verified against `flutter analyze` (0 issues), `flutter test` (no new failures beyond
the one pre-existing flaky timer test), and live on the emulator via hot restart — including a
full real create-squad round trip (RLS + RPCs + client) once finding #0 was resolved.

## Resolved during this session
- **Finding #0 (Supabase Anonymous Sign-ins disabled)** — the user enabled it mid-session; a
  hot restart afterward produced a real `auth.users` row and a fully working squad create/
  leaderboard/rank flow. No further action needed here.

## Not fixed in this pass (recommend as next priorities)
1. Home page mock Achievements/Recent-activity vs. real data (item 6 above) — needs a real
   domain concept for achievements or the mock rows removed.
2. Everything already tracked in project memory's Phase 7 inventory (Play compliance, Sentry,
   Patrol/pgTAP tests, the two hardware exit criteria) is unaffected by this pass.
