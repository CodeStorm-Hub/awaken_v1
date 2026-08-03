# Awaken — Per-Screen UI/UX Review

> Applied skills: `flutter-apply-architecture-best-practices` · `flutter-build-responsive-layout`
> Methodology: MVVM architecture audit, breakpoint verification (600dp), WCAG 2.1 AA, M3 Expressive design system compliance, per-screen UX flow.

---

## Screen Inventory

| # | Screen | Feature Module | Route / Trigger |
|---|---|---|---|
| 1 | Onboarding — Marketing Carousel | `onboarding` | First run, `StartupFlowPage` |
| 2 | Onboarding — Notification Rationale | `onboarding` | Step 2 of onboarding |
| 3 | Onboarding — Battery Exemption | `onboarding` | Step 3 of onboarding |
| 4 | Home Page | `home` | Shell tab 0 |
| 5 | Alarm List Page | `alarm` | Shell tab 1 |
| 6 | Alarm Ring Page | `alarm` | Global overlay (+ preview push) |
| 7 | Verification Page | `verification` | Pushed from AlarmRingPage |
| 8 | Territory Page | `territory` | Shell tab 2 |
| 9 | Active Run Page | `territory` | Pushed from TerritoryPage |
| 10 | Squad Page | `squad` | Shell tab 3 |
| 11 | Profile Page | `profile` | Pushed from CurrentUserAvatarButton |
| 12 | Workout Celebration Sheet | `alarm` | Modal bottom sheet post-dismissal |
| 13 | Leaderboards Sheet | `squad` | Modal bottom sheet |
| 14 | Weekly Recap Sheet | `squad` | Modal bottom sheet (weekly reset) |

---

## Screen 1: Onboarding — Marketing Carousel (`_MarketingCarousel`)

### Visual Design
- **Background:** Full-screen tinted with the card's `bg` color (`primaryContainer` → `tertiaryContainer` → `secondaryContainer`) — each card has its own color theme, creating a strong visual rhythm as the user swipes
- **Hero element:** `ExpressiveFlower` (150px) with `animatePop: true` spring-in — big, centered, celebratory
- **Typography:** 32px / w800 / -0.6 letter-spacing title, 16px body — emphatic but readable
- **Page indicator:** Animated pill dots — active pill uses `flex: 3` (vs `flex: 1` for inactive) + `AnimatedContainer` with `easeOutCubic`, respects `disableAnimations`
- **Buttons:** `FilledButton` (pill shape, 60px height), `TextButton` "Skip intro" in same container

### UX Flow
- ✅ `PageView` swipe gesture — universal expectation for carousels, properly implemented
- ✅ `didUpdateWidget` syncs `PageController` to external button-driven index changes — no double-animation bug
- ✅ "Skip intro" only skips marketing, not permission setup — correct and intentional
- ✅ ConstrainedBox + SingleChildScrollView prevents overflow on short devices / large text scale
- ⚠️ **Issue:** No "swipe left" affordance on the last card — user might swipe right infinitely. The `PageView` is bounded (`itemCount: 3`) so left-swipe beyond card 0 is naturally dead — good. But there's no visual indicator that card 3 is the last (only the absence of "Skip" + "Next"→"Continue" label)

### Accessibility
- ✅ `MediaQuery.disableAnimationsOf()` guards all animations
- ⚠️ `ExpressiveFlower` icons have no semantic labels — screen reader won't describe the alarm/map/groups icons
- ⚠️ `PageView` has no `Semantics` page count/index — TalkBack won't announce "slide 1 of 3"

### Architecture Adherence (Architecture Skill)
- ✅ View is UI-only (`StatefulWidget`, no business logic)
- ✅ `_OnboardingPageState` is the single source of truth for card index, matching MVVM pattern
- ✅ `_MarketingCarousel` receives callbacks, not repositories — correct separation

### Responsive Layout (Responsive Skill)
- ✅ `LayoutBuilder` + `ConstrainedBox(minHeight)` — short-content centering on all screen heights
- ✅ `ConstrainedBox(maxWidth: 290)` — limits reading width on tablets
- ⚠️ On tablets (>600dp), the `ConstrainedBox(maxWidth: 290)` is tight — text reads fine but the 150px flower is disproportionately small on a 10" screen. Consider scaling `ExpressiveFlower` size with `MediaQuery.sizeOf()`

---

## Screen 2: Onboarding — Notification Rationale (`_NotificationRationaleCard`)

### Visual Design
- **Layout:** Left-aligned content (header + title), `Expanded` body copy, bottom CTA — reads like a standard permission rationale sheet
- **Hero:** `ExpressiveFlower` (64px) with `borderColor: scheme.outline` — correct fix for light theme invisibility
- **Typography:** 30px / bold / -0.4 title, `bodyLarge` body in `onSurfaceVariant` — correct M3 semantic usage
- **CTA:** Full-width pill `FilledButton` (56px height), disabled + spinner while requesting

### UX Flow
- ✅ Back button (44×44) to marketing carousel — two-way navigation (previously one-way)
- ✅ `_requestingNotificationPermission` guard prevents double-tap race condition
- ✅ Never blocks onboarding on denial outcome — correct: permission denial → still advances
- ✅ Loading state on "Continue" button while OS dialog is up — prevents user confusion
- ⚠️ **Issue:** The explanation text references "full-screen-intent" and "silently blocks" — slightly technical for a general audience. Could soften: "Without this, your alarm might not appear on screen when you're sleeping."

### Accessibility
- ✅ `IconButton` back button with `tooltip: 'Back'`
- ✅ Button disabled state communicated via `onPressed: requesting ? null : onContinue`
- ⚠️ Loading state (`CircularProgressIndicator` replacing "Continue" text) has no semantic label — screen reader won't know what's happening

### Architecture Adherence
- ✅ Pure UI widget — permission logic is in `_OnboardingPageState._continueFromNotificationRationale()`
- ✅ `StatelessWidget` — all state lives in the parent (correct)

### Responsive Layout
- ✅ `SafeArea` + `Column` with `Expanded` for body — text won't overflow under floating keyboard
- ⚠️ No `maxWidth` constraint — on tablets the `Padding(20, 0, 20, 0)` stretches the body text to the full tablet width, which can exceed the 75-char ideal line length

---

## Screen 3: Onboarding — Battery Exemption (`BatteryExemptionPage`)

> Not fully read in this review, but structure follows same `_NotificationRationaleCard` pattern.

### Key Notes
- OEM-specific instructions (Xiaomi, Samsung, etc.) — most important practical step for alarm reliability
- Back navigation implemented to notification rationale step
- ✅ Reachable from Profile page post-onboarding for users who skipped or need to re-do it

---

## Screen 4: Home Page (`HomePage`)

### Visual Design
- **App bar:** `AppleGlassContainer` pill (22dp radius) — glassmorphic header with `BackdropFilter`
  - Left: greeting text + "Awaken" app name
  - Right: streak flame pill (animated) + `StreakTierAvatarRing` around `CurrentUserAvatarButton`
- **Stats row:** 3 `StatTile`s in a `Row` — streak, owned area, rank — with `hasError` state for all
- **Wake-up tax:** `WakeUpTaxMeter` shown conditionally when multiplier > 1.0
- **Next alarm card:** `_NextAlarmCardBloc` — a distinct card showing next upcoming alarm
- **Activity feed:** List of `_ActivityEntry` items with relative timestamps

### UX Flow
- ✅ `RefreshIndicator` with `AlwaysScrollableScrollPhysics` — pull to refresh works on short content
- ✅ `Timer.periodic` refreshes relative timestamps ("5m ago") without full page rebuilds
- ✅ New user: "Dismiss an alarm or capture territory to build your stats." — helpful empty state for zero stats
- ✅ CTAs (`onOpenAlarms`, `onOpenTerritory`, `onOpenSquad`) navigate via shell callbacks — no coupling to Navigator
- ⚠️ **Issue:** The greeting text + "Awaken" name takes two lines; on small phones (360dp wide) the streak pill + avatar row might crowd the right side. No width constraint on the left column, so if greeting is long it could push against the right row

### Accessibility
- ✅ `StreakTierAvatarRing` has `Semantics(label: '${tier.label} streak tier')`
- ✅ `CurrentUserAvatarButton` has `Semantics(label: 'Profile', button: true)`
- ✅ `StatTile` `hasError` state exposes "Couldn't load" + `errorContainer` color
- ⚠️ Streak flame pill has no semantic label — reads as plain text number "5" with no context for screen readers
- ⚠️ `_ActivityEntry` items — unclear if each row has a meaningful semantic label

### Architecture Adherence
- ✅ `HomeCubit` drives all state — no direct data-fetching in `build()`
- ✅ `BlocProvider<HomeCubit>` scoped to this page — not global, correct for page-local state
- ✅ `_NextAlarmCardBloc` reads `AlarmCubit` (shell-level cubit) — correct cross-feature reference
- ⚠️ `Timer.periodic` for relative timestamp refresh lives in `_RecentActivitySection` widget — this is a presentational concern but could be argued to belong in the Cubit

### Responsive Layout
- ✅ `SingleChildScrollView` with bottom padding (120dp) — clears nav bar
- ✅ `StatTile` uses `FittedBox(scaleDown)` to prevent number overflow
- ⚠️ Stats row doesn't adapt to tablet: 3 tiles at equal `Expanded` flex look fine on mobile but could become wide, awkward blocks on a 10" tablet. Consider a `GridView.builder` or `maxWidth` constraint at ≥600dp
- ⚠️ No `LayoutBuilder` breakpoint switch for the activity feed — on tablets the list stretches edge-to-edge, violating the "max 75 chars per line" guideline

---

## Screen 5: Alarm List Page (`AlarmListPage`)

### Visual Design
- **App bar:** `AppleGlassContainer` pill — "Alarms" title + count subtitle + battery/debug/avatar buttons
- **Alarm cards:** `_AlarmCard` with `groupedItemRadius` (large outer corners, small inner) — creates a connected list aesthetic
  - Time: large bold display
  - Exercise chips: icon + label (squat/push-up)
  - Day-of-week row: individual day chips
  - `ExpressiveSwitch` (M3 pill switch with animated thumb)
- **Empty state:** `_EmptyState` with `ExpressiveFlower` + CTA to add first alarm
- **FAB:** Positioned `FloatingActionButton` (bottom right, above nav bar) to add new alarm
- **`_RiseIn` animation:** Staggered slide-in on item entry (keyed by alarm ID, not index)

### UX Flow
- ✅ `ValueKey(alarm.id)` on `_RiseIn` — correct: delete/reorder doesn't re-animate adjacent items
- ✅ Bottom padding 120dp — list scrolls clear of FAB + glassmorphic nav bar
- ✅ `LayoutBuilder` — compact vs expanded card layout
- ✅ "tap to preview" subtitle — discoverable preview flow
- ⚠️ **Issue:** No swipe-to-delete gesture on alarm cards — common iOS/Android pattern users expect. Delete is only accessible via card tap → edit sheet → delete button — requires 3 taps
- ⚠️ **Issue:** The "bug_report" icon in the app bar for the self-test is confusing to non-technical users — it suggests "report a bug" not "test alarm reliability"
- ⚠️ **Issue:** The "battery_charging_full" icon in the app bar maps to battery exemption settings, which is not obvious

### Accessibility
- ✅ All icon buttons are 44×44 with `Tooltip`
- ✅ `ExpressiveSwitch` has `Semantics(toggled, label: 'Alarm on/off', button: true)`
- ✅ `ExpressiveSwitch` tap target is 56×48 (exceeds 44×44)
- ⚠️ `_AlarmCard` as a whole has no semantic label that describes the entire alarm (time + exercise + enabled/disabled) to screen readers who might not explore all child elements

### Architecture Adherence
- ✅ `AlarmCubit` is provided by `AppShellPage`'s ancestor — alarm list is a pure observer
- ✅ All mutations (create/delete/toggle) go through `AlarmCubit` use cases
- ✅ `_AlarmCard` is a pure display widget — all callbacks go up to page

### Responsive Layout
- ✅ `LayoutBuilder` inside the card adapts layout
- ✅ Bottom padding 120dp prevents FAB overlap
- ⚠️ On tablets (≥600dp): The single-column alarm list with wide cards reads as an unoptimized phone layout. Consider a 2-column `GridView` or centered `ConstrainedBox(maxWidth: 600)` for tablets

---

## Screen 6: Alarm Ring Page (`AlarmRingPage`)

### Visual Design
- **Background:** Full-screen `scheme.errorContainer` — deliberate urgency color (red/danger family)
- **Time display:** 16px tabular-figures clock in `onErrorContainer` — subtle but present
- **Ringing bell animation:** 
  - `ExpressiveFlower(128px)` in `scheme.error` with bell icon
  - Dual expanding-ring pulse animation (two staggered `_ringAt` painters at 0° and 180° offset)
  - Bell `_wiggle`: -8° to +8° `easeInOut`, 250ms loop
- **Rep count:** 84px / w800 / -3 letter-spacing — maximum visual emphasis
- **Wake-up tax pill:** `scheme.error` colored pill with warning icon — only shown if tax > 1.0x
- **CTA button (`_StartWorkoutButton`):** Shape-morphs pill→rounded-rect on press (`animateContainer` border-radius 24→999)

### UX Flow
- ✅ `PopScope(canPop: isPreview)` — back blocked for real alarms, allowed for preview
- ✅ Double-tap guard via `_startingWorkout` synchronous flag — prevents double camera sessions
- ✅ `cubit.setVerificationInProgress(true/false)` — steps overlay aside so `VerificationPage` is visible
- ✅ Loading state ("Opening camera…") while camera/ML Kit warms up — no silent blank screen
- ✅ Haptic feedback (`mediumImpact()`) on successful dismissal
- ⚠️ **Issue:** "Time to squat!" and "Time to push up!" headers are grammatically inconsistent — should be "Time to squat!" / "Time to do push-ups!" or both in noun form ("Squats" / "Push-ups")
- ⚠️ **Issue:** No visible escape hatch from the real-alarm ring screen for users who genuinely cannot exercise — the only exit is completing verification or the physical device's OS-level alarm stop. A "Can't exercise today?" option (logged but allowed) should exist even on real alarms

### Accessibility
- ✅ `_StartWorkoutButton` has `Semantics(button: true, label: 'Start workout to dismiss')`
- ✅ `_RingingBell` checks `disableAnimationsOf` in `didChangeDependencies` (not `initState` — correct fix)
- ⚠️ No `liveRegion` on the clock or rep count — screen readers won't announce the time or rep count changes
- ⚠️ The pulse-ring animation is purely visual — correct, it adds urgency but has audio/haptic fallbacks (ringtone + vibration)

### Architecture Adherence
- ✅ `AlarmRingPage` reads from `AlarmCubit` via `context.watch` — reactive, no direct use case calls
- ✅ Business logic (complete workout, dismiss) flows through `AlarmCubit.completeWorkout()`
- ✅ `_RingingBell`, `_StartWorkoutButton` are private widget classes — not helper methods returning Widget (correct per rules)

### Responsive Layout
- ✅ `SafeArea` + centered `Column` — adapts to all screen heights
- ✅ `Flexible` on the header text — won't overflow on small screens
- ⚠️ 128px flower + 84px rep count + button may be cramped on very short devices (e.g., Galaxy Fold outer screen). The `Stack`+`Positioned(bottom: 8)` button approach doesn't guarantee the central content won't overlap on screens shorter than ~600px

---

## Screen 7: Verification Page (`VerificationPage`)

### Visual Design
- **Background:** Full-screen black (`Colors.black`) — maximizes camera contrast
- **Camera layer:** `CameraPreview` mirrored horizontally (front camera "mirror" expectation) via `Matrix4.rotationY(π)`
- **Skeleton overlay:** `SkeletonPainter` (`CustomPainter`) — joint dots + bone lines on detected pose
- **Status banner** (`_StatusBanner`): Semi-transparent frosted pill with pulsing red recording dot + status text
- **Rep segments** (`_RepSegments`): Row of ≤20 animated fill segments — smart bucketing for >20 target reps
- **Rep counter** (`_RepCounter`): 176px circular progress ring — `_RingPainter` fills clockwise, contains large rep digit + "of N" label
- **Completion:** `ExpressiveFlower(animatePop)` + "Done" pill button replaces counter

### UX Flow
- ✅ `buildWhen` on top-level `BlocBuilder` — only rebuilds view kind on status category changes (not every frame)
- ✅ `RepaintBoundary` isolates camera texture from skeleton/overlay repaints
- ✅ `_RepCounter` uses `BlocConsumer` — bump animation triggers as side effect of rep increase, not on rebuild
- ✅ `_StatusBanner` is `Semantics(liveRegion: true)` — screen reader announces status changes
- ✅ `_RepCounter` is `Semantics(liveRegion: true, label: 'N of M squats')` — rep count announced
- ✅ "I can't do this exercise today" escape hatch always visible (except when complete)
- ✅ `PopScope` with confirmation dialog when mid-progress
- ✅ `openAppSettings()` shortcut in permission-denied state
- ⚠️ **Issue:** `_StatusBanner` message "Can't see you clearly — step back or find better light." uses `circular(18)` — wraps to 2 lines on narrow phones. The fix (non-pill radius) was applied but the message itself is still quite long. Consider shortening to "Step back & find better light."
- ⚠️ **Issue:** No live audio/haptic confirmation per rep for users holding the phone at arm's length — the `_triggerBump()` haptic + scale bump are good, but the visual counter is face-down during a push-up

### Accessibility
- ✅ `liveRegion` on both status banner and rep counter
- ✅ `ExcludeSemantics` on visual ring/digits (semantic label covers it)
- ✅ `AppLifecycleState` pause/resume — camera yields properly on background
- ⚠️ Skeleton painter has no semantic description of pose quality (good/bad form)
- ⚠️ Dark background with white text — contrast is fine, but the frosted banner (`Colors.black.withOpacity(0.54)`) against a bright camera background could drop below 4.5:1 in some lighting

### Architecture Adherence
- ✅ `VerificationCubit` drives all state — camera/ML Kit are injected via DI
- ✅ `_CameraView` is a `StatelessWidget` that reads from DI singleton — not tightly coupled to state
- ✅ `SkeletonPainter` is a pure `CustomPainter` — pure presentation, no logic
- ✅ App lifecycle management in `_VerificationViewState` (not in Cubit) — correct: UI concern

### Responsive Layout
- ✅ `Stack(fit: StackFit.expand)` — camera fills entire screen correctly on all aspect ratios
- ✅ `SafeArea` wraps the overlay column — safe on notched screens
- ✅ `_RepSegments` uses `Row + Expanded` — adapts to any width
- ⚠️ The 176px rep-counter circle is fixed-size — on tablets it will appear small and off-center. Consider scaling with `MediaQuery.sizeOf()` on larger screens

---

## Screen 8: Territory Page (`TerritoryPage`)

### Visual Design
- **Full-screen MapLibre map** — OpenFreeMap vector tiles with Pokémon GO-inspired basemap recolor
- **Territory fills:** GeoJSON source + fill/outline layers; owned = solid, rival = animated ant-path dashes
- **At-risk territories:** Pulsing red outline layer animated via `_pulseTimer`
- **3D skyline:** Fill-extrusion layer visible only when `_is3D` + camera tilt = 45°
- **Bounty zones:** Clustered point markers + translucent radius fills
- **Neutral zone ring:** Subtle capturable-ground indicator around user position
- **Squad heatmap:** Toggle overlay with its own GeoJSON source
- **UI Chrome:**
  - Sync status banner (offline/error)
  - Rival panel with stats + "Steal back" CTA
  - GPS fix indicator
  - "3D" / squad heatmap / rival toggle controls
  - Avatar button (top-right)

### UX Flow
- ✅ Map widget built exactly once — never wrapped in `BlocBuilder`, imperative updates via controller
- ✅ `_styleReady` guard prevents premature `addGeoJsonSource`/`addLayer` calls
- ✅ `_antPathTimer` + `_antPathDashSequence` — animated marching dashes on rival territory
- ✅ "Steal back" CTA opens `ActiveRunPage` focused on rival's location
- ⚠️ **Issue:** Map UI controls (3D toggle, squad heatmap toggle, rival toggle) need clear iconography — these are non-obvious to first-time users
- ⚠️ **Issue:** Territory map has no legend — user can't distinguish owned vs rival vs at-risk without prior knowledge of the color system
- ⚠️ **Issue:** `OSM attribution` must be visible per OpenStreetMap/OpenFreeMap licensing — verify it's always legible against the map background

### Accessibility
- ❌ **Major gap:** Map content (polygons, bounty zones, squad heatmap) has no semantic overlay — completely invisible to screen readers. This is a platform limitation of `maplibre_gl` (native map view), but there's no fallback text description of what the map shows
- ✅ Sync badge has `Tooltip` with descriptive message
- ⚠️ Floating action buttons/controls need `Semantics` labels

### Architecture Adherence
- ✅ Use cases injected via `getIt<WatchTerritories>()` etc. — no direct Supabase calls in page
- ✅ Map-layer state (`_territoryLayersReady`, `_styleReady`) is page-local — correct (UI concern)
- ⚠️ `TerritoryPage` is a 2177-line `StatefulWidget` — extremely large. Per architecture best practices (SOLID, single responsibility), this should be decomposed into:
  - `TerritoryMapController` (map lifecycle)
  - `TerritoryLayerManager` (layer add/update logic)
  - `SquadHeatmapManager`
  - `BountyZoneManager`
  - `RivalController`

### Responsive Layout
- ✅ `MapLibreMap` fills available space via `Expanded`/`Stack`
- ✅ `SafeArea` wraps UI chrome
- ⚠️ At ≥600dp (NavigationRail mode), the map's right-edge controls may be covered by the rail — the `Stack`-positioned overlays need to account for the rail's width in the medium-window layout

---

## Screen 9: Active Run Page (`ActiveRunPage`)

### Visual Design
- **Full-screen map** with route `Line` annotation + start/current `Circle` markers
- **Stats overlay:** `AppleGlassContainer` pill chips for elapsed time / distance / pace
- **Auto-follow indicator:** Camera auto-lock icon — tappable to unlock
- **Stop button:** Large pill `FilledButton` at bottom
- **Style:** Same Pokémon GO-inspired basemap recolor as TerritoryPage

### UX Flow
- ✅ Map built once, `BlocListener` updates annotations imperatively — no rebuild on every GPS tick
- ✅ `focusLocation` param — "Steal back" CTA opens page pre-centered on rival's zone
- ✅ `_autoFollow` toggle — user can pan freely, camera stops auto-following
- ✅ `TerritoryCaptureSheet` shown after `submit_run()` success
- ⚠️ **Issue:** No "End run early?" confirmation dialog — user could accidentally tap "Stop" mid-run with no undo

### Accessibility
- ⚠️ Stat chip values read as plain numbers — no context ("00:42" reads as "42" not "42 seconds")
- ⚠️ Map has no semantic description of the route

### Architecture Adherence
- ✅ `RunTrackingCubit` drives all run state
- ✅ `submit_run()` called through repository use case — not directly from page

### Responsive Layout
- ✅ Full-screen map fills all form factors
- ⚠️ Stat chips are positioned with fixed padding — on very wide tablets they may cluster to the left unnecessarily

---

## Screen 10: Squad Page (`SquadPage`)

### Visual Design
- **App bar:** `AppleGlassContainer` pill — "Squad" + squad name subtitle + leaderboard icon + avatar
- **No-squad state:** `ExpressiveFlower` + "You're not in a squad" copy + "Create squad" / "Join by code" buttons
- **Loaded state:**
  - Squad member cards with avatar initials, streak tier rings, territory area
  - Territory capture feed (recent captures with relative timestamps)
  - Rank chip

### UX Flow
- ✅ `_WeeklyResetCeremonyGate` — weekly reset ceremony modal triggered automatically on reset day
- ✅ Leaderboard icon (44×44, WCAG compliant) opens `_LeaderboardsSheet`
- ✅ `SquadCubit` handles all squad state + retry
- ⚠️ **Issue:** No way to leave a squad from this screen — leave/remove requires digging into settings (if it exists at all)
- ⚠️ **Issue:** Invite code not visible from the Squad tab — user needs to navigate to create-squad flow to find it. An invite code share button should be prominent on the main squad view

### Accessibility
- ✅ Leaderboard icon target is 44×44
- ✅ `ExpressiveLoader` with reduce-motion guard for loading state
- ⚠️ Squad member cards likely lack descriptive semantic labels combining all member info (name + area + tier)

### Architecture Adherence
- ✅ `SquadCubit` scoped inside `SquadPage` via `BlocProvider` — not global
- ✅ `_WeeklyResetCeremonyGate` is a separate widget class — correct (not a helper method)
- ✅ `getIt<SquadCubit>()` — DI registered cubit

### Responsive Layout
- ⚠️ Member list is a `Column` in a `SingleChildScrollView` — works on mobile but on tablets with `NavigationRail`, there's no width constraint; member cards stretch edge-to-edge
- ⚠️ Consider a `GridView.builder` for member cards on ≥600dp screens

---

## Screen 11: Profile Page (`ProfilePage`)

### Visual Design
- **App bar:** `AppleGlassContainer` pill — back arrow (iOS chevron) + "Profile" title
- **User card:** Glassmorphic card with `StreakTierAvatarRing` avatar + name (editable) + email
- **Stats row:** streak / area / rank `StatTile`s
- **Settings sections:** Grouped list rows (appearance, alarm reliability, battery, sign-in methods)
- **Auth section:** Guest upgrade row (email + Google) / sign-out / delete account

### UX Flow
- ✅ `StreakTierAvatarRing` wraps avatar — streak tier glanceable at a glance
- ✅ Edit name: `InkWell` (44×44) pencil icon → `_showEditNameDialog` — inline
- ✅ Google Sign-In: `GoogleLogo` + proper branding
- ✅ Sign-out confirmation via dialog
- ✅ Delete account: destructive, should require confirmation — verify this is implemented
- ✅ `ProfileCubit` watches current user + streak + area + rank
- ⚠️ **Issue:** "Progress syncs across devices" subtitle for linked accounts is positive but doesn't appear until you scroll — the most valuable user-education moment (why link an account?) is below the fold on small phones

### Accessibility
- ✅ All icon buttons 44×44 with `Tooltip`
- ✅ Avatar fallback uses `avatarInitial()` — safe for empty strings
- ✅ `Image.network` has `errorBuilder` + `loadingBuilder`
- ⚠️ Delete account row needs clear `Semantics` label indicating destructive action

### Architecture Adherence
- ✅ `ProfileCubit` drives all user data — no direct Supabase calls in UI
- ✅ Auth use cases injected: `SignInWithGoogle`, `LinkWithEmail`, `DeleteAccount`, etc.
- ✅ `ThemeModeCubit` for theme toggle — correct separation

### Responsive Layout
- ✅ `SingleChildScrollView` — all content scrollable
- ⚠️ On tablets: the user card and settings list stretch full width. Wrapping in `Center` + `ConstrainedBox(maxWidth: 560)` would produce a much better tablet layout

---

## Screen 12: Workout Celebration Sheet (`WorkoutCelebrationSheet`)

### Visual Design
- **Modal bottom sheet** — `surfaceContainerLow` background, 28dp top corners
- **Drag handle:** 36×4 pill indicator
- **`ExpressiveFlower(116px)`** with trophy icon + `animatePop: true` — celebratory spring-in
- **Stat chips:** Reps completed (secondaryContainer) + streak (tertiaryContainer) — asymmetric corner radii create a unified pill pair
- **CTA:** Full-width "Nice!" pill button

### UX Flow
- ✅ `isDismissible: false` + `enableDrag: false` — user must tap "Nice!" to proceed, preventing accidental dismissal of the celebration moment
- ✅ `SingleChildScrollView` — prevents overflow at large text scale
- ✅ Haptic feedback (`mediumImpact`) before showing sheet
- ✅ `StreamBuilder<int>` for live streak — shows current streak immediately after completion

### Accessibility
- ⚠️ No `Semantics` on the celebration sheet as a whole — screen reader won't announce it's a "congratulations" moment
- ✅ Stat chips are readable as text

---

## Screen 13: Leaderboards Sheet (`_LeaderboardsSheet`)

### UX Flow
- Three-tab modal: Squad / Nearby / Global
- `isScrollControlled: true` for full-height display
- ⚠️ Nearby leaderboard depends on `last_run_location` — users who've never run see an empty list with no explanation

---

## Screen 14: Weekly Recap Sheet (`WeeklyRecapSheet`)

### UX Flow
- Triggered automatically by `_WeeklyResetCeremonyGate` on weekly reset
- Should show previous week's stats before reset
- ✅ `WeeklyResetLocalDatasource` persists "has shown ceremony" flag

---

## App Shell — `AppShellPage` / `AdaptiveNavScaffold`

### Visual Design
- **Compact (<600dp):** `NavigationBar` inside `AppleGlassContainer(blurAmount: 25)` pill — authentic glassmorphic iOS tab bar
  - 64px height, `extendBody: true` (content behind nav bar, correct)
  - Selected: `scheme.primary` icon + `0.15` alpha indicator
  - Unselected: `secondaryLabelColor()` (WCAG AA)
  - `BackdropFilter` blur creates real glass effect
- **Medium+ (≥600dp):** Standard `NavigationRail` — no glassmorphism, solid background

### UX Flow
- ✅ `IndexedStack` preserves scroll/animation state across tab switches
- ✅ `late final List<Widget> _pages` built in `initState` — widgets not recreated on tab switch
- ✅ `_ShellSyncBadge` stream updates independently — no shell rebuild for sync state changes

### Responsive Layout
- ✅ `MediaQuery.sizeOf(context).width >= 600` breakpoint — correct per responsive skill (uses `MediaQuery.sizeOf`, not `OrientationBuilder`)
- ✅ `NavigationRail` on medium+ with `Expanded(child: body)` — correct rail+content layout
- ⚠️ The glassmorphic nav bar `Padding(16, 0, 16, 8)` creates side margins — on very narrow screens (<375dp), this leaves only ~343dp content width, which could cause overflow in some edge cases

---

## Cross-Cutting Architecture Review

### Adherence to Architecture Skill

| Principle | Status | Notes |
|---|---|---|
| Domain layer (use cases) | ✅ Fully implemented | All features have use case classes |
| Repository pattern | ✅ Implemented | Local (Drift) + remote (Supabase) sources |
| MVVM pattern | ✅ via Cubit/Bloc | Cubits = ViewModel role |
| DI with constructor injection | ✅ `get_it` + `injectable` | All registered |
| Private widget classes (not helper methods) | ✅ All screens use `class _FooWidget extends StatelessWidget` | Correct |
| Build methods lean (no logic) | ✅ Generally respected | `TerritoryPage` has complex build that warrants decomposition |
| Separation UI/business logic | ✅ | Only minor `Timer.periodic` case in Home |

### Adherence to Responsive Layout Skill

| Check | Status | Notes |
|---|---|---|
| `MediaQuery.sizeOf()` for breakpoints | ✅ | Used in `AdaptiveNavScaffold` |
| `LayoutBuilder` for parent-space decisions | ✅ | Alarm list, onboarding |
| No `OrientationBuilder` for layout switching | ✅ | Not used |
| No device-type checks | ✅ | Width-based breakpoints only |
| `Expanded`/`Flexible` for space distribution | ✅ | Used correctly throughout |
| `ConstrainedBox` maxWidth on large screens | ⚠️ | Applied in onboarding; missing in Squad, Profile, Home activity feed |
| `ListView.builder` for long lists | ⚠️ | Activity feed uses `Column` — for short lists this is acceptable, but should use `ListView.builder` if feed can grow |
| No orientation lock | ✅ | Not locked |
| Multi-input support (mouse/keyboard) | ⚠️ | No explicit keyboard shortcut support; mouse hover works via Material ink |

---

## Summary of Key UI/UX Issues & Recommendations

### High Priority

| Issue | Screen(s) | Recommendation |
|---|---|---|
| No escape hatch from real alarm ring | AlarmRingPage | Add "Can't exercise today?" with streak penalty warning |
| `TerritoryPage` 2177-line monolith | TerritoryPage | Decompose into sub-components per SRP |
| Map has no accessibility description | Territory, ActiveRun | Add a text-mode summary panel or screen-reader-only description |
| No swipe-to-delete on alarm cards | AlarmListPage | Add `Dismissible` widget wrapping each alarm card |
| Invite code not visible on Squad tab | SquadPage | Add a share/copy invite code button on the squad header |

### Medium Priority

| Issue | Screen(s) | Recommendation |
|---|---|---|
| No `ConstrainedBox(maxWidth)` on tablets | Profile, Squad, Home | Add `Center` + `ConstrainedBox(maxWidth: 600)` |
| Stat row not adapted for tablets | Home, Profile | Switch to `GridView` or `Row` with constrained tile width at ≥600dp |
| App bar icons not intuitive | AlarmListPage | Replace `bug_report` with `fact_check` or `alarm_on`; `battery_charging_full` with `settings` |
| `ExpressiveFlower` icons have no semantic labels | Onboarding, empty states | Add `Semantics(label: '...')` wrappers |
| No territory map legend | TerritoryPage | Add a collapsible legend chip (owned/rival/at-risk/bounty) |

### Low Priority

| Issue | Screen(s) | Recommendation |
|---|---|---|
| Marketing card flower size fixed on tablets | Onboarding | Scale with `MediaQuery.sizeOf().width * 0.35` |
| Grammar inconsistency "push up!" | AlarmRingPage | Normalize to "Time to push up!" or "Push-ups!" |
| Notification rationale text too technical | Onboarding step 2 | Soften for general audience |
| Leaderboard empty state for no-run users | LeaderboardsSheet | Add "Start a run to appear on the nearby leaderboard" |
