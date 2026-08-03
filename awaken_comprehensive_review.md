# Awaken App — Comprehensive Codebase & UI/UX Review

> **Scope:** Full analysis of `lib/`, `supabase/`, and `pubspec.yaml` for features, architecture, UI/UX, database schema, and design system.

---

## 1. App Identity

**Awaken** is a gamified alarm + fitness Android app with two core loops:
1. **Alarm Dismissal:** alarms are dismissed only by completing camera-verified physical exercises (squats / push-ups), verified in real-time by on-device ML Kit pose detection.
2. **Territory Capture:** outdoor runs that close a geographic loop claim ground on a shared, real-time map — driving competition, rivalry, and social gameplay.

---

## 2. Package Dependency Audit

### Core Runtime Dependencies

| Package | Role |
|---|---|
| `supabase_flutter` | Remote backend: auth, realtime presence, remote DB |
| `drift` + `drift_flutter` | SQLite ORM — local source of truth (offline-first) |
| `get_it` + `injectable` | Service locator + code-gen DI |
| `flutter_bloc` | State management (Cubit/Bloc pattern) |
| `alarm` | Native alarm scheduling (foreground service, FSI) |
| `camera` | Camera feed for pose verification |
| `google_mlkit_pose_detection` | On-device ML Kit pose detection |
| `maplibre_gl` | Vector-tile map rendering (OpenFreeMap) |
| `geolocator` | GPS position stream |
| `permission_handler` | Runtime permission management |
| `go_router` | Declarative routing |
| `google_sign_in` | Google OAuth |
| `google_fonts` | Custom font loading |
| `flutter_dotenv` | Env config loading |
| `connectivity_plus` | Offline/online detection |
| `shared_preferences` | Lightweight persistent flags |

### Dev Dependencies

| Package | Role |
|---|---|
| `build_runner` | Code gen orchestrator |
| `drift_dev` | Drift schema code gen |
| `injectable_generator` | DI code gen |
| `flutter_lints` | Lint rules |
| `mockito` | Mock generation for tests |

---

## 3. Architecture

### Pattern: Feature-First Clean Architecture

```
lib/
├── core/                     # Shared infrastructure
│   ├── constants/            # AppConstants (e.g. penalty cap = 4.0x)
│   ├── di/                   # GetIt + injectable wiring (injection.dart / injection.config.dart)
│   ├── error/                # Failure types
│   ├── theme/                # Design system (see §5)
│   ├── usecase/              # Base UseCase abstract class
│   └── config/               # Env loading
│
├── sync/                     # Offline-first sync layer
│   ├── database/             # Drift AppDatabase schema
│   ├── outbox/               # Hand-rolled outbox engine (SyncWorker)
│   ├── connectivity/         # ConnectivityWatcher
│   └── sync_status.dart      # SyncStatus enum (idle/syncing/offline/error)
│
└── features/                 # Feature modules (each = presentation/domain/data)
    ├── onboarding/
    ├── alarm/
    ├── verification/
    ├── territory/
    ├── squad/
    ├── profile/
    ├── home/
    └── shell/
```

### Layered Structure (per feature)

```
feature/
  data/
    datasources/    # Local (Drift) + Remote (Supabase) datasources
    repositories/   # Concrete repository implementations
  domain/
    entities/       # Pure data classes
    repositories/   # Abstract repository interfaces
    usecases/       # Single-responsibility use cases (UseCase<Params, Return>)
  presentation/
    bloc/           # Cubit/Bloc state management
    pages/          # Full-screen routes
    widgets/        # Reusable page-scoped widgets
```

### Navigation

- **GoRouter** for route definitions
- **App Shell** (`AppShellPage`) with `IndexedStack` + `AdaptiveNavScaffold` for main tab navigation
- **Global Alarm Lockdown Overlay** in `MaterialApp.builder` (`_AlarmRingOverlay`) — ensures ringing alarm always takes over, regardless of navigation depth

---

## 4. Features & Functionalities

### 4.1 Onboarding Feature (`features/onboarding/`)

**Pages:**
- `OnboardingPage` — state machine: Marketing Carousel → Notification Rationale → Battery Exemption
- `BatteryExemptionPage` — OEM battery/autostart settings guide
- `AlarmReliabilityTestPage` — optional ~90s self-test scheduling (Profile → reachable)

**Functionalities:**
- 3-card `PageView` marketing carousel with swipe + page indicator + animated dots
- Back navigation between all steps (no one-way trapping)
- Runtime `POST_NOTIFICATIONS` permission request (Android 13+) with explicit rationale
- Battery exemption flow with OEM-specific instructions
- Persisted "seen" flag via `SharedPreferences` (`HasSeenOnboarding` use case)
- `reduce_motion` accessibility guard on all carousel animations

---

### 4.2 Alarm Feature (`features/alarm/`)

**Pages:**
- `AlarmListPage` — main alarm management dashboard
- `AlarmRingPage` — full-screen lock-screen alarm ring UI
- `AlarmReliabilityTestPage` — diagnostic self-test page

**Key Widgets:**
- `_AlarmCard` — per-alarm card with `ExpressiveSwitch`, time, days, rep count
- `WorkoutCelebrationSheet` — modal bottom sheet post-dismissal ("hero moment")

**Functionalities:**
- Create / edit / delete alarms with time, exercise mode, target rep count
- Toggle alarm active/inactive via `ExpressiveSwitch`
- Recurrence support (days of week)
- **Wake-Up Tax:** snooze penalty multiplier (1.0–4.0x), ramps reps up on repeated dismissal failures; shown as `WakeUpTaxMeter` inline widget
- Global alarm lockdown: `_AlarmRingOverlay` in `MaterialApp.builder` blocks all UI until dismissed
- Workout verification gate: `AlarmRingPage` pushes `VerificationPage` and awaits result
- Streak tracking: `WatchCurrentStreak` use case
- `_RiseIn` staggered entry animation on alarm list
- Responsive card layout via `LayoutBuilder` (compact/expanded)
- Empty state with `ExpressiveFlower` + CTA

---

### 4.3 Verification Feature (`features/verification/`)

**Pages:**
- `VerificationPage` — camera + ML Kit pose pipeline UI

**Key Widgets:**
- `SkeletonPainter` — `CustomPainter` skeleton overlay on camera feed
- `_CameraView` — camera preview + skeleton + rep counter + progress overlay

**Functionalities:**
- Front camera NV21 stream → ML Kit `PoseDetector` in STREAM mode
- Frame-drop governor (in-flight frame drops next, no queue buildup)
- Joint-angle rep state machine (`AngleRepCounter`):
  - Squats: hip-knee-ankle angle
  - Push-ups: shoulder-elbow-wrist angle
  - Dead zone between down/up thresholds prevents noisy flicker
- 3-rep calibration phase before real counting starts
- States: initializing / permission denied / camera error / calibrating / counting / complete
- `PopScope` with mid-progress exit confirmation dialog
- App lifecycle pause/resume handling (camera yield on background)
- `_ViewKind` scoped `BlocBuilder` — prevents camera preview rebuilds on every rep update
- "I can't do this exercise today" escape hatch always visible

---

### 4.4 Territory Feature (`features/territory/`)

**Pages:**
- `TerritoryPage` — interactive territory map
- `ActiveRunPage` — live GPS run tracking map

**Key Widgets:**
- `MapStyleLoader` — tiered OpenFreeMap style loading with fallbacks
- `MapStyleOverlays` / `TerritoryBasemapRecolor` — Pokémon GO-inspired basemap tinting
- `TerritoryMapStyle` — GeoJSON source + style layer management
- `TerritoryCaptureSheet` — modal sheet shown after run completion
- `OsmAttribution` — required OSM attribution overlay

**Functionalities (TerritoryPage):**
- Real vector-tile rendering via `maplibre_gl` (replaced `flutter_map`)
- Territory polygons via single `GeoJsonSource` + `FillLayerProperties` / `LineLayerProperties` (imperative, no map tear-down)
- Owned territory: solid fill + solid outline layer
- Rival territory: separate animated "ant path" dashed outline (`_antPathTimer`, 14-step dash sequence)
- At-risk territory: pulsing outline via `_pulseTimer` + `setLayerProperties`
- 3D skyline view: fill-extrusion layer + camera tilt toggle (`_is3D`)
- Bounty zones: clustered point markers + translucent radius fills
- Neutral zone ring (unclaimed capturable ground indicator)
- Squad heatmap overlay toggle (own `GeoJsonSource` + `FillLayer`)
- Sync status banner (offline/error)
- Rival panel with "Steal back" CTA (opens `ActiveRunPage` focused on rival zone)
- `_styleReady` guard prevents premature style-layer calls

**Functionalities (ActiveRunPage):**
- Real-time GPS path rendering on `maplibre_gl` map
- Kalman-smoothed GPS point interpolation
- Live stat tiles: elapsed time / distance / pace
- Auto-follow camera with manual override toggle
- Route `Line` annotation + start/current position `Circle` markers
- `submit_run()` SECURITY DEFINER RPC call on finish
- `TerritoryCaptureSheet` shown after successful submission

---

### 4.5 Squad Feature (`features/squad/`)

**Pages:**
- `SquadPage` — squad overview + leaderboard

**Key Widgets / Sheets:**
- `WeeklyRecapSheet` — weekly reset ceremony modal
- `_LeaderboardsSheet` — global + nearby + squad leaderboard tabs
- `_SquadMemberCard` — member row with streak tier ring

**Functionalities:**
- Create squad / join by invite code
- View squad members + territory area
- Real-time presence via Supabase Realtime (broadcast channel)
- Squad leaderboard (area, weekly/all-time toggle)
- Global leaderboard
- Nearby leaderboard (SECURITY DEFINER function — returns distance/area, never raw coordinates)
- Weekly reset ceremony (animated transition, `WeeklyResetLocalDatasource`)
- Live territory capture feed (recent captures by squad members)
- Leaderboard rank chip (`SquadCubit` state)
- `_WeeklyResetCeremonyGate` wrapper for ceremony timing

---

### 4.6 Profile Feature (`features/profile/`)

**Pages:**
- `ProfilePage` — user profile, settings, auth management

**Key Widgets:**
- `CurrentUserAvatarButton` — top-bar avatar present in Home/Territory/Squad
- `ProfileAvatarButton` — 44×44 tappable avatar with `StreakTierAvatarRing`
- `_InitialAvatar` — letter fallback when no photo available

**Functionalities:**
- Anonymous auth (Supabase anonymous sign-in at first boot)
- Guest → linked account upgrade (email + password / Google OAuth)
- Password reset email
- Edit display name (inline dialog)
- Sign out
- Delete account
- Theme toggle (light/dark/system) via `ThemeModeCubit`
- Navigate to "Alarm reliability" test page
- Navigate to "Battery & location" settings page
- Avatar: Google provider photo → initial letter fallback with `StreakTierAvatarRing`
- Stat summary: streak, territory area, rank
- `WakeUpTaxMeter` visibility

---

### 4.7 Home Feature (`features/home/`)

**Pages:**
- `HomePage` — app dashboard / landing screen

**Functionalities:**
- Streak stat tile + territory area tile + rank tile
- Quick-nav CTAs: "Open Alarms", "Open Territory", "Open Squad"
- Recent activity feed with relative timestamps ("5m ago", "2h ago") via `Timer.periodic`
- `HomeCubit` streams from alarm, territory, and activity repositories
- Responsive layout via `LayoutBuilder`

---

### 4.8 App Shell (`features/shell/`)

**Pages:**
- `AppShellPage` — adaptive tab shell

**Functionalities:**
- 4-tab navigation: Home / Alarms / Territory / Squad
- `IndexedStack` — preserves tab state (scroll, animations) across switches
- Compact (<600dp): `AppleGlassContainer` bottom nav bar with `NavigationBar`
- Medium+ (≥600dp): `NavigationRail` sidebar
- `_ShellSyncBadge` — non-intrusive sync status indicator (top-right corner)
- `AdaptiveNavScaffold` — `@visibleForTesting` for widget-testable adaptive chrome

---

## 5. Design System

### 5.1 Theme Architecture

**Files:**
- [app_theme.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/app_theme.dart) — centralized `ThemeData` (light + dark), `ColorScheme.fromSeed`
- [semantic_colors.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/semantic_colors.dart) — `ThemeExtension<AppSemanticColors>` for domain roles
- [motion_tokens.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/motion_tokens.dart) — M3 Expressive spring physics tokens
- [shape_tokens.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/shape_tokens.dart) — corner-radius scale
- [expressive_widgets.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/expressive_widgets.dart) — shared design component library
- [gamification_widgets.dart](file:///j:/GitHub/flutter_projects/awaken/lib/core/theme/gamification_widgets.dart) — streak ring, wake-up tax meter

### 5.2 Color System

| Role | Usage |
|---|---|
| `ColorScheme.fromSeed` | Auto-generates full M3 palette from seed |
| Light canvas | `0xFFF2F2F7` (iOS system grouped background) |
| Dark canvas | `0xFF1C1C1E` (iOS dark background) |
| `secondaryLabelColor()` | Light: `0xFF6E6E73` / Dark: `0xFF8E8E93` (WCAG AA compliant) |
| `AppSemanticColors.territory*` | Domain-specific: owned / rival / at-risk territory |
| `AppSemanticColors.warning*` / `bountyGold` | Wake-up tax / bounty zone gold |
| Streak Tier Ring | None → Bronze `#B08D57` → Silver `#A8AEB8` → Gold (bountyGold) |

### 5.3 Typography

- **Google Fonts** (`google_fonts` package)
- "Emphatic Typography" aesthetic: large display weights (w800), negative letter-spacing
- Scale uses `TextTheme`: `displayLarge` (57px bold) → `bodyMedium` (14px / 1.4 line height)
- Tabular figures (`FontFeature.tabularFigures()`) on numeric stat tiles

### 5.4 Shape Tokens

| Token | Radius | Usage |
|---|---|---|
| `small` | 8dp | Internal grouped-list items |
| `medium` | 12dp | Cards, minor surfaces |
| `mediumLarge` | 16dp | Default glass container |
| `large` | 18dp | — |
| `largeExtra` | 20dp | — |
| `extraLarge` | 24dp | Major cards, outer grouped list |
| `extraLargeExtra` | 28dp | Bottom sheets, nav bar |
| `extraExtraLarge` | 32dp | — |
| `pill` | 999dp | Buttons, chips, switches |
| `sharpWarning` | 0dp | Wake-up tax container (intentional tension) |

### 5.5 Motion Tokens

| Token | Duration | Curve / Spring | Usage |
|---|---|---|---|
| `fastEffects` | 150ms | `easeOut` | Toggles, button presses, color changes |
| `fastSpatial` | 350ms | `easeOutBack` | Badge pop-ins, expanding cards |
| `defaultSpatial` | 500ms | `easeOutBack` | Page transitions, sliding panels |
| `expressiveFastSpatial` | ~350ms | Spring (d=0.42, k=1670) | Attention-grabbing layout changes |
| `expressiveDefaultSpatial` | ~500ms | Spring (d=0.38, k=1210) | Standard spatial transitions |
| `expressiveFastEffects` | ~150ms | Spring (d=0.31, k=940) | Micro-interactions |
| `standardDefaultSpatial` | ~500ms | Spring (d=0.27, k=1060) | List/navigation secondary animations |

### 5.6 Component Library (`expressive_widgets.dart`)

| Component | Description |
|---|---|
| `AppleGlassContainer` | Authentic iOS glassmorphism: `BackdropFilter`, translucent tints, gradient + shadow |
| `ExpressiveFlower` | M3 Expressive badge shape (two stacked squares, one rotated 45°); optional `animatePop` spring-in |
| `ExpressiveLoader` | Morphing squircle spinner (shape + rotation loop animation) |
| `ExpressiveSwitch` | Growing-thumb M3 pill switch with animated thumb + check icon |
| `StatTile` | Colored stat block (icon / value / label) with `hasError` state |
| `ProfileAvatarButton` | 44×44 tappable avatar with `Semantics` label |
| `groupedItemRadius()` | Calculates per-item corner radius for grouped list pattern |
| `secondaryLabelColor()` | WCAG AA secondary text color (brightness-adaptive) |
| `avatarInitial()` | Safe single-letter fallback (guards empty string crash) |

### 5.7 Gamification Widgets (`gamification_widgets.dart`)

| Component | Description |
|---|---|
| `StreakTierAvatarRing` | Sweep-gradient ring around avatar: bronze / silver / gold |
| `WakeUpTaxMeter` | Animated horizontal penalty meter with warning semantics |

---

## 6. UI Screen Map

```
App Entry (main_dev.dart / main_prod.dart)
  └── AwakenApp (app.dart)
        ├── _AlarmRingOverlay [GLOBAL OVERLAY — always on top]
        │     └── AlarmRingPage (when alarm ringing)
        └── GoRouter
              ├── StartupFlowPage (auth + onboarding gate)
              │     └── OnboardingPage (first run only)
              │           ├── _MarketingCarousel (3 cards)
              │           ├── _NotificationRationaleCard
              │           └── BatteryExemptionPage
              │
              └── AppShellPage (main app — AdaptiveNavScaffold)
                    ├── [0] HomePage
                    │     └── (CTAs navigate via callbacks to tabs)
                    │
                    ├── [1] AlarmListPage
                    │     └── → AlarmEditSheet (bottom sheet — create/edit)
                    │
                    ├── [2] TerritoryPage
                    │     ├── → ActiveRunPage (full-screen run)
                    │     │     └── → TerritoryCaptureSheet (on finish)
                    │     └── → Rival detail panel (inline)
                    │
                    └── [3] SquadPage
                          ├── → _LeaderboardsSheet (modal bottom sheet)
                          └── → WeeklyRecapSheet (modal, weekly reset)

                    [All main tabs]
                          └── → ProfilePage (push via CurrentUserAvatarButton)
                                ├── → AlarmReliabilityTestPage
                                └── → BatteryExemptionPage

     AlarmRingPage (launched from overlay)
           └── → VerificationPage (push — camera + rep counter)
                 └── → WorkoutCelebrationSheet (on success, modal bottom sheet)
                       └── pops back to shell
```

---

## 7. Supabase Database Schema (Live — `awaken-dev`, `ap-southeast-1`)

> Project: **qxxkydisyqnodskmymla** · Status: `ACTIVE_HEALTHY` · Postgres 17.6.1 + PostGIS

### Tables (11 total)

| Table | Rows | RLS | Purpose |
|---|---|---|---|
| `profiles` | 29 | ✅ | User identity, streak, territory color, squad membership, last GPS location, avatar URL |
| `alarms` | 25 | ✅ | Scheduled alarms with exercise mode, rep count, penalty multiplier, recurrence days |
| `sessions` | 10 | ✅ | Workout session records (alarm ID, reps completed, exercise mode) |
| `runs` | 2 | ✅ | Completed runs: route path (geography LineString), start/end, distance, integrity verdict |
| `territories` | 2 | ✅ | Claimed polygons (geom MultiPolygon/PostGIS), area, health, last_defended_at |
| `territory_captures` | 2 | ✅ | Capture events: winner_id, loser_id, area_taken_sqm, capture location |
| `user_stats` | 3 | ✅ | Per-user wake-up tax multiplier (default 1.0) |
| `squads` | 3 | ✅ | Squad identity: name, 6-char invite_code, owner_id |
| `squad_reports` | 0 | ✅ | User reports within a squad: reporter_id, reported_user_id, reason |
| `bounty_zones` | 2 | ✅ | Temporary bonus zones: center (geography Point), radius_m, multiplier (default 2.0), active window |
| `active_runs` | 0 | ✅ | In-progress run state: path (jsonb), point_timestamps, distance_m — cleared after submit |

### Full Column Reference

#### `profiles`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | — (FK → auth.users) |
| `display_name` | text | YES | — |
| `territory_color` | text | NO | `'#2E7D32'` |
| `streak_tier` | smallint | NO | `0` |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |
| `deleted_at` | timestamptz | YES | — |
| `squad_id` | uuid | YES | — (FK → squads) |
| `last_run_location` | geography(Point,4326) | YES | — |
| `avatar_url` | text | YES | — |

#### `alarms`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | — |
| `user_id` | uuid | NO | — |
| `scheduled_time` | timestamptz | NO | — |
| `exercise_mode` | text | NO | — (check: squat/pushup) |
| `required_reps` | smallint | NO | — |
| `penalty_multiplier` | numeric(3,2) | NO | `1.0` (max 4.0) |
| `is_active` | boolean | NO | `true` |
| `recurring_days` | text | NO | `''` (comma-separated day indices) |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |
| `deleted_at` | timestamptz | YES | — |

#### `territories`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | — |
| `user_id` | uuid | NO | — |
| `geom` | geometry(MultiPolygon,4326) | NO | — |
| `area_sqm` | double precision | NO | `0` (computed via trigger) |
| `health` | smallint | NO | `100` (0–100) |
| `last_defended_at` | timestamptz | NO | `now()` |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |
| `deleted_at` | timestamptz | YES | — |

#### `runs`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | — |
| `user_id` | uuid | NO | — |
| `path` | geography(LineString) | NO | — |
| `is_closed_loop` | boolean | NO | `false` |
| `started_at` | timestamptz | NO | — |
| `ended_at` | timestamptz | NO | — |
| `point_count` | integer | NO | — |
| `distance_m` | double precision | YES | — |
| `integrity_verdict` | text | YES | — (anti-cheat result) |
| `rejected_reason` | text | YES | — |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |
| `deleted_at` | timestamptz | YES | — |

#### `sessions`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | — |
| `user_id` | uuid | NO | — |
| `alarm_id` | uuid | YES | — |
| `reps_completed` | smallint | NO | — |
| `exercise_mode` | text | NO | `'squat'` |
| `started_at` | timestamptz | NO | `now()` |
| `completed_at` | timestamptz | YES | — |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |
| `deleted_at` | timestamptz | YES | — |

#### `bounty_zones`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | `gen_random_uuid()` |
| `center` | geography(Point,4326) | NO | — |
| `radius_m` | numeric | NO | — |
| `multiplier` | numeric | NO | `2.0` |
| `active_from` | timestamptz | NO | `now()` |
| `active_until` | timestamptz | YES | — |
| `created_at` | timestamptz | NO | `now()` |

#### `territory_captures`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `id` | uuid | NO | `gen_random_uuid()` |
| `winner_id` | uuid | NO | — |
| `loser_id` | uuid | YES | — (null = unclaimed land) |
| `area_taken_sqm` | double precision | NO | — |
| `location` | geography(Point) | YES | — |
| `created_at` | timestamptz | NO | `now()` |

#### `active_runs`
| Column | Type | Nullable | Default |
|---|---|---|---|
| `user_id` | uuid | NO | — |
| `run_id` | uuid | NO | — |
| `started_at` | timestamptz | NO | — |
| `path` | jsonb | NO | — |
| `point_timestamps` | timestamptz[] | YES | — |
| `distance_m` | double precision | NO | `0` |
| `updated_at` | timestamptz | NO | `now()` |

#### `squad_reports`
| Column | Type | Nullable |
|---|---|---|
| `id` | uuid | NO |
| `reporter_id` | uuid | NO |
| `reported_user_id` | uuid | NO |
| `squad_id` | uuid | NO |
| `reason` | text | NO |
| `created_at` | timestamptz | NO |

### Views

| View | Definition | Purpose |
|---|---|---|
| `territories_geojson` | SELECT + `ST_AsGeoJSON(geom)` WHERE `deleted_at IS NULL` | GeoJSON convenience view (not used by app — `territories_in_bbox` RPC used instead) |

### Stored Functions / RPCs (26 total)

#### Client-Callable (SECURITY DEFINER, `authenticated` role)

| Function | Signature | Purpose |
|---|---|---|
| `submit_run` | `(p_run_id, p_path jsonb, p_started_at, p_ended_at, p_point_timestamps[])` | Server-authoritative: closes loop, merges polygon, captures territory, applies bounty multiplier |
| `create_squad` | `(p_name text)` | Creates squad + assigns caller as owner/member, generates unique 6-char invite code |
| `join_squad` | `(p_invite_code text)` | Joins squad by code; guards already-in-squad |
| `leave_squad` | `()` | Removes caller from squad; owner can't leave (must transfer first) |
| `squad_leaderboard` | `(p_squad_id uuid, p_time_window text)` | Weekly/all-time squad rankings by area_sqm |
| `squad_members` | `(p_squad_id uuid)` | Returns members of caller's squad (guards non-member access) |
| `global_leaderboard` | `(p_time_window text, p_row_limit int, p_offset int)` | Global paginated rankings |
| `nearby_leaderboard` | `(p_radius_m numeric, p_time_window text, p_row_limit int, p_offset int)` | Proximity rankings via `last_run_location`; never returns raw coords |
| `my_global_rank` | `(p_time_window text)` | Caller's global rank |
| `my_squad_rank` | `(p_squad_id uuid, p_time_window text)` | Caller's squad rank |
| `my_nearby_rank` | `(p_radius_m numeric, p_time_window text)` | Caller's proximity rank |
| `my_owned_area_sqm` | `()` | Total claimed area for caller |
| `current_rival` | `()` | Returns the user who has captured the most of the caller's territory |
| `my_territories_at_risk` | `()` | Returns caller's territories below health threshold |
| `recent_territory_captures` | `(p_row_limit int)` | Recent capture events visible to caller |
| `territories_in_bbox` | `(min_lon, min_lat, max_lon, max_lat)` | Returns territories in a bounding box (antimeridian-safe, capped) |
| `active_bounty_zones` | `()` | Currently active bounty zones |
| `bump_wake_up_tax` | `()` | Increments the caller's `current_tax_multiplier` (max 4.0) |
| `reset_wake_up_tax` | `()` | Resets multiplier to 1.0 after successful workout |

#### Internal / Trigger Functions

| Function | Trigger Target | Purpose |
|---|---|---|
| `handle_new_user()` | `auth.users` INSERT | Auto-creates `profiles` row on signup |
| `set_updated_at()` | All tables UPDATE | Maintains `updated_at` timestamp |
| `territories_set_area()` | `territories` INSERT/UPDATE | Computes `area_sqm` via `ST_Area(geom::geography)` |
| `recompute_streak_tier()` | `sessions` INSERT | Updates `profiles.streak_tier` after each workout |
| `expire_decayed_territories()` | Scheduled (cron) | Sets `deleted_at` on territories with health = 0 |
| `seed_daily_bounty_zones()` | Scheduled (cron) | Generates daily bounty zones |
| `_area_for_window()` | Called by leaderboard RPCs | Shared helper: area within time window |

### RLS Policies (Live)

| Table | Policy | Command | Roles | Condition |
|---|---|---|---|---|
| `profiles` | `profiles_select_own` | SELECT | public | `auth.uid() = id` |
| `profiles` | `profiles_insert_own` | INSERT | public | `auth.uid() = id` |
| `profiles` | `profiles_update_own` | UPDATE | public | `auth.uid() = id` |
| `alarms` | `alarms_all_own` | ALL | public | `auth.uid() = user_id` |
| `sessions` | `sessions_all_own` | ALL | public | `auth.uid() = user_id` |
| `runs` | `runs_select_own` | SELECT | public | `auth.uid() = user_id` |
| `runs` | `runs_insert_own` | INSERT | public | `auth.uid() = user_id` |
| `territories` | `territories_select_all` | SELECT | public | `true` (world-readable) |
| `territory_captures` | `territory_captures_select_own` | SELECT | public | `uid = winner_id OR uid = loser_id` |
| `user_stats` | `user_stats_all_own` | ALL | public | `auth.uid() = user_id` |
| `squads` | `squads_select_member` | SELECT | public | `id = profiles.squad_id` (subquery) |
| `squad_reports` | `squad_reports_insert_own` | INSERT | authenticated | reporter = uid + both parties in same squad |
| `bounty_zones` | `bounty_zones_select_active` | SELECT | public | `active_from <= now() AND (active_until IS NULL OR active_until > now())` |
| `active_runs` | `active_runs_upsert_own` | INSERT | authenticated | `auth.uid() = user_id` |
| `active_runs` | `active_runs_select_own` | SELECT | authenticated | `auth.uid() = user_id` |
| `active_runs` | `active_runs_update_own` | UPDATE | authenticated | `auth.uid() = user_id` |
| `active_runs` | `active_runs_delete_own` | DELETE | authenticated | `auth.uid() = user_id` |

### Realtime

- **Squad presence** via `realtime.messages` broadcast channel — policy: squad members can use their squad's channel
- **Territory changes** streamed via Supabase Realtime on `territories` table

---

## 7b. Security Advisor Findings (Live)

### WARNINGs (from `get_advisors` security scan)

> **Note:** All `authenticated_security_definer_function_executable` warnings are **by design** — these are intentional client-callable RPCs. The warning is Supabase's generic advisory for any `SECURITY DEFINER` callable by authenticated users; it does not indicate a vulnerability when the function is explicitly meant to be called by the app.

| Severity | Finding | Function(s) | Assessment |
|---|---|---|---|
| WARN | `authenticated_security_definer_function_executable` | `submit_run`, `create_squad`, `join_squad`, `leave_squad`, `squad_leaderboard`, `squad_members`, `global_leaderboard`, `nearby_leaderboard`, `my_*` helpers, `current_rival`, `territories_in_bbox`, `active_bounty_zones`, `recent_territory_captures` | ✅ **Intentional** — these are the app's client-facing API endpoints. Each function uses `security definer` to enforce server-side validation. |
| WARN | `authenticated_security_definer_function_executable` | `bump_wake_up_tax`, `reset_wake_up_tax` | ⚠️ **Review needed** — `bump_wake_up_tax` can be called directly by the client via REST. A malicious client could artificially inflate another user's tax... but the RLS is keyed to `auth.uid()` so only a user's own multiplier can be bumped. Risk is self-harm only (user bumps their own tax). Low risk, but consider if this should only be callable server-side. |
| WARN | `auth_allow_anonymous_sign_ins` | All public tables | ✅ **Expected** — The app uses Supabase Anonymous Auth by design (Phase 0). Anonymous users need read/write access to their own data. RLS still enforces `auth.uid() = user_id`, so anonymous users can only access their own rows. |
| WARN | `auth_allow_anonymous_sign_ins` | `realtime.messages` | ✅ **Expected** — Squad realtime channel is intentionally open to anonymous users who are squad members (squad membership is checked in the policy). |
| WARN | `auth_leaked_password_protection` | Auth | ⚠️ **Action recommended** — HaveIBeenPwned password leak protection is disabled. Should be enabled in the Supabase Auth dashboard before public launch. |

### No Critical Issues Found

- ✅ All tables have RLS enabled
- ✅ No table has public write access without authentication
- ✅ Territory writes are server-authoritative (`submit_run` SECURITY DEFINER — no client INSERT on `territories`)
- ✅ `nearby_leaderboard` never exposes raw GPS coordinates — returns distance/area only
- ✅ No materialized views
- ✅ PostGIS `spatial_ref_sys` is the only table without RLS (system table, read-only SRID reference — known accepted advisory)

---

## 8. Sync Architecture

### Offline-First Strategy

```
User Action → Drift (local SQLite) → [SyncWorker outbox] → Supabase
                     ↑                                            ↓
              Source of Truth                            Remote sync target
```

- **Drift** (`AppDatabase`) acts as the authoritative local store
- **SyncWorker** (outbox engine) drains pending writes when online
- **ConnectivityWatcher** monitors network state, triggers sync resume
- **SyncStatus** stream (idle/syncing/offline/error) exposed via `_ShellSyncBadge` globally

---

## 9. Responsive Layout Strategy

### Breakpoints

| Width | Nav Style | Layout |
|---|---|---|
| < 600dp | `NavigationBar` (bottom) wrapped in `AppleGlassContainer` pill | Mobile compact |
| ≥ 600dp | `NavigationRail` (left sidebar) | Tablet/foldable |

### Techniques Used

| Technique | Where |
|---|---|
| `LayoutBuilder` | `AlarmListPage` card layout, `OnboardingPage` scroll safety, `AlarmCard` compact/expanded |
| `MediaQuery.sizeOf()` | `AdaptiveNavScaffold` breakpoint detection |
| `MediaQuery.disableAnimationsOf()` | All animated widgets — reduce-motion guard |
| `SingleChildScrollView` + `ConstrainedBox(minHeight)` | Onboarding cards (large text scale / short device) |
| `FittedBox(scaleDown)` | `StatTile` value overflow safety |
| `IndexedStack` | Tab state preservation across switches |

---

## 10. State Management Summary

| Feature | State Approach |
|---|---|
| Alarm list / ringing | `AlarmCubit` (Bloc) |
| Home dashboard | `HomeCubit` (Bloc) |
| Squad / leaderboard | `SquadCubit` (Bloc) |
| Profile / auth | `ProfileCubit` (Bloc) |
| Verification / rep counting | `VerificationCubit` (Bloc) |
| Run tracking | `RunTrackingCubit` (Bloc) |
| Theme mode | `ThemeModeCubit` (Bloc) |
| Sync status | `SyncWorker.status` (Stream) |
| Wake-up tax | `WakeUpTaxStore` (Stream via ValueNotifier) |
| Streak | `WatchCurrentStreak` use case (Stream) |

---

## 11. Accessibility Audit

### Implemented Correctly ✅

- `secondaryLabelColor()` is WCAG AA compliant in both light (4.5:1) and dark (~5.5:1) modes
- All interactive touch targets: `SizedBox(44×44)` minimum (WCAG 2.5.5) — verified across avatar buttons, leaderboard icon, back button
- `Semantics` labels on `ProfileAvatarButton`, `StreakTierAvatarRing`, `WakeUpTaxMeter`, `ExpressiveSwitch`
- `MediaQuery.disableAnimationsOf()` guard on every animated widget
- `Tooltip` on all icon-only controls
- `PopScope` exit confirmation when mid-workout in `VerificationPage`

### Potential Gaps ⚠️

- Map elements (territory polygons, route lines, bounty zones) have no semantic overlay — screen readers can't describe map content
- Skeleton painter overlay in `VerificationPage` has no semantic description of pose quality
- `AlarmRingPage` lockdown overlay uses `ExcludeSemantics` on underlying content — correct, but the alarm ring UI itself should be fully describable by screen readers

---

## 12. Known Issues & Roadmap Status

| Phase | Status | Notes |
|---|---|---|
| Phase 0 — Foundations | ✅ Complete | Project structure, DI, theme, Supabase schema, CI |
| Phase 1 — Alarm core | ✅ Feature-complete (emulator) | Needs physical device testing (Xiaomi/Samsung) |
| Phase 2 — Pose verification | ✅ Implemented, not device-verified | Accuracy target (≥95% @ 20 squats, 5 body types) unvalidated |
| Phase 3 — Offline-first | ✅ Implemented (Drift + outbox) | Running in production |
| Phase 4 — Alarm→verification wiring | ✅ Complete | AlarmRingPage fully wired to VerificationPage |
| Phase 5 — Territory | ✅ Implemented | MapLibre migration complete, ANT-path animation, 3D skyline |
| Phase 6 — Squad/social | ✅ Implemented | Realtime presence, leaderboards, weekly reset ceremony |
| Phase 6.5 — Profile/auth | ✅ Implemented | Anonymous → linked account, Google OAuth |

### Open Technical Debt

1. `ShapeTokens` constants not yet wired to all call sites — feature code still uses inline `BorderRadius.circular(N)` literals at many points
2. Physical device alarm reliability not validated (OEM battery optimizers: Xiaomi HyperOS, Samsung One UI)
3. ML Kit accuracy not validated on real hardware across body types / lighting
4. Supabase Anonymous Sign-ins must be manually enabled in the dashboard
5. `territories_geojson_view` created but MapLibre integration uses `get_territories_in_bbox` RPC instead — view may be vestigial
