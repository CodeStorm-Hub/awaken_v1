# Awaken — Codebase & Database Comprehensive Review Analysis

**Date**: August 1, 2026  
**Target Platform**: Android & iOS (Flutter 3.12.2+)  
**Backend & Database**: Supabase PostgreSQL 17.6 (`awaken-dev`) + Drift Offline-First SQLite  

---

## Executive Summary

The **Awaken** project is a high-concept gamified alarm and fitness application featuring real-time territory capture, squad mechanics, and pose-detection alarm verification. The codebase follows **Clean Architecture** principles with **BLoC** state management, **GetIt/Injectable** dependency injection, an **Offline-First Drift database**, and **Supabase Flutter** backend sync.

Overall Code Health: **A- / 90%**  
Database Health & Security: **B+ / 84%** (Identified SECURITY DEFINER RPC warnings and unindexed foreign keys)

---

## 1. Codebase & Architecture Analysis

### 1.1 Architecture & Layering
* **Pattern**: Feature-driven Clean Architecture (`presentation`, `domain`, `data`).
* **State Management**: `flutter_bloc` (^9.1.1) + `equatable` (^2.0.7).
* **Dependency Injection**: `get_it` + `injectable` with code generation via `build_runner`.
* **Offline-First Storage**: `drift` (^2.34.3) acting as the single source of truth for local state, synchronizing with Supabase when online (`lib/sync`).

### 1.2 Feature Modules & Key Packages
| Feature Module | Technology / Package | Key Functionality & Status |
| :--- | :--- | :--- |
| **Alarm & Scheduling** | `alarm` (^5.5.0), `wakelock_plus` | Replaced legacy alarm managers; schedules native alarms on Android/iOS. |
| **Biometric Verification** | `google_mlkit_pose_detection`, `camera` | Uses device camera & MLKit to verify physical wake-up poses (e.g. squats). |
| **Territory & Map** | `maplibre_gl` (^0.26.2), `geolocator` | Renders vector maps with MapLibre Native; tracks user runs and territory captures. |
| **Kalman Filtering** | `kalman_dr` (0.4.4) | Smooths raw GPS jitter for accurate territory area calculations. |
| **Squads & Leaderboard** | `supabase_flutter`, `realtime` | Live squad activity feeds, leaderboard RPCs, and squad chat channels. |

---

## 2. Supabase Database Review

### 2.1 Schema Overview (`qxxkydisyqnodskmymla`)
- **Tables**: `profiles`, `alarms`, `runs`, `territories`, `territory_captures`, `user_stats`, `bounty_zones`, `squads`, `squad_reports`, `active_runs`, `sessions`.
- **Row Level Security (RLS)**: Enforced on 100% of public tables.

### 2.2 Security Advisor Audit (`get_advisors security`)
⚠️ **Warnings Identified**:
1. **Executable `SECURITY DEFINER` RPC Functions**:
   - `bump_wake_up_tax()`, `create_squad()`, `submit_run()`, `join_squad()`, `leave_squad()`, `global_leaderboard()`, `nearby_leaderboard()` are defined as `SECURITY DEFINER` and executable by the `authenticated` role.
   - *Risk*: Users can invoke these functions via `/rest/v1/rpc/*` with elevated permissions.
   - *Fix*: Change non-administrative RPCs to `SECURITY INVOKER` or restrict `EXECUTE` permissions.
2. **Leaked Password Protection**:
   - Currently disabled in Supabase Auth config. Enable HaveIBeenPwned integration.

### 2.3 Performance Advisor Audit (`get_advisors performance`)
ℹ️ **Unindexed Foreign Keys (Query Latency Risks)**:
The following foreign keys lack covering indexes, which may cause slow `JOIN` and delete operations as data scales:
- `public.profiles.squad_id` (`profiles_squad_id_fkey`)
- `public.runs.user_id` (`runs_user_id_fkey`)
- `public.sessions.alarm_id` (`sessions_alarm_id_fkey`)
- `public.sessions.user_id` (`sessions_user_id_fkey`)
- `public.squads.owner_id` (`squads_owner_id_fkey`)
- `public.squad_reports.reporter_id`, `reported_user_id`, `squad_id`

---

## 3. Key Recommendations & Action Plan

### Priority 1: Supabase Indexing & Security Hardening
Run the following SQL migrations on Supabase:

```sql
-- 1. Create missing covering indexes for Foreign Keys
CREATE INDEX IF NOT EXISTS idx_profiles_squad_id ON public.profiles(squad_id);
CREATE INDEX IF NOT EXISTS idx_runs_user_id ON public.runs(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_alarm_id ON public.sessions(alarm_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_squads_owner_id ON public.squads(owner_id);

-- 2. Alter non-admin RPCs to SECURITY INVOKER
ALTER FUNCTION public.submit_run(uuid, jsonb, timestamp with time zone, timestamp with time zone, timestamp with time zone[]) SECURITY INVOKER;
ALTER FUNCTION public.create_squad(text) SECURITY INVOKER;
```

### Priority 2: Flutter Android & iOS Native Tuning
- **Android Background Execution**: Verify foreground service notification channels for `flutter_foreground_task` so Android 14+ (API 34+) does not kill territory tracking in background.
- **iOS Location & Camera**: Ensure `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSCameraUsageDescription` keys are descriptive in `ios/Runner/Info.plist`.
- **MapLibre GPS Performance**: Apply the newly created `flutter_maplibre_performance.md` rule: update camera smoothly via `animateCamera()` without calling `setState()` on high-frequency location ticks.

---

## Summary Ratings Matrix

| Domain | Rating | Remarks |
| :--- | :--- | :--- |
| **Architecture & Structure** | 🟢 Excellent (95%) | Clean Architecture + BLoC + Injectable DI |
| **Offline-First Data Sync** | 🟢 Excellent (92%) | Drift SQLite + Supabase Sync engine |
| **Database Schema & RLS** | 🟡 Good (85%) | RLS enabled on all tables; needs FK indexes |
| **Database Security** | 🟡 Needs Attention (82%) | Convert `SECURITY DEFINER` RPCs to `SECURITY INVOKER` |
| **Flutter Mobile Performance** | 🟢 Excellent (90%) | Native MapLibre + Kalman filter for tracking |
