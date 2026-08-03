# Implementation Plan — Database & Mobile Recommendations Hardening

Execute all identified security, performance, and architecture recommendations for the **Awaken** Flutter app and **Supabase** backend database.

## Proposed Changes

### 1. Supabase Database Migration & Hardening

#### [NEW] [20260801110000_add_fk_indexes_and_security_invoker.sql](file:///j:/GitHub/flutter_projects/awaken/supabase/migrations/20260801110000_add_fk_indexes_and_security_invoker.sql)
- Re-create B-tree covering indexes on all foreign key columns flagged by Supabase performance advisors:
  - `idx_profiles_squad_id` on `public.profiles(squad_id)`
  - `idx_runs_user_id` on `public.runs(user_id)`
  - `idx_sessions_alarm_id` on `public.sessions(alarm_id)`
  - `idx_sessions_user_id` on `public.sessions(user_id)`
  - `idx_squads_owner_id` on `public.squads(owner_id)`
  - `idx_squad_reports_reporter_id`, `reported_user_id`, `squad_id`
- Alter non-administrative RPC functions to `SECURITY INVOKER` so they execute under the caller's context with RLS enforcement:
  - `submit_run`, `create_squad`, `join_squad`, `leave_squad`, `bump_wake_up_tax`, `reset_wake_up_tax`
- Execute the SQL migration directly on the `awaken-dev` Supabase project (`qxxkydisyqnodskmymla`).
- Run `get_advisors` (security & performance) to verify 0 unindexed foreign key warnings.

---

### 2. Android & iOS Native Platform Hardening

#### [MODIFY] [AndroidManifest.xml](file:///j:/GitHub/flutter_projects/awaken/android/app/src/main/AndroidManifest.xml)
- Verify and declare foreground service types (`location` and `specialUse`/`alarm`) for Android 14+ (API 34+) compatibility.

#### [MODIFY] [Info.plist](file:///j:/GitHub/flutter_projects/awaken/ios/Runner/Info.plist)
- Verify `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription`, and `NSCameraUsageDescription` strings for iOS App Store compliance.

---

### 3. Territory Tracking & MapLibre Optimization

#### [MODIFY] [territory_map_screen.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/screens/territory_map_screen.dart) (or BLoC/Widget)
- Audit map controller listeners: Ensure `Geolocator` position streams directly call `_mapController.animateCamera()` without triggering `setState()` on high-frequency location ticks.

---

## Verification Plan

### Automated Verification
- Run Supabase Advisors check: `get_advisors` (security & performance) to confirm FK indexes are active and warnings resolved.
- Run static analysis: `flutter analyze` or `dart analyze` to ensure clean Flutter codebase build.
- Run unit/widget tests: `flutter test`.

### Manual Verification
- Verify database query execution on Supabase via SQL interface.
