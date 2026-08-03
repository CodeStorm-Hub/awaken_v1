# Walkthrough - Guest Feature Gating & Database Hardening

We have completed the implementation of **Guest / Unauthenticated User Feature Gating** (restricting guests exclusively to Alarms & Workout Verification while requiring account registration for Territory & Squads) along with **Supabase Database Hardening and Index Optimizations**.

---

## 🛠️ Changes Implemented

### 📱 1. Flutter App & UI Feature Gating

#### [TerritoryGateCard](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/widgets/territory_gate_card.dart)
- **New Widget**: Created a glassmorphism feature gate widget with an expressive map icon, feature description, and primary CTA **"Create Free Account"** (`AuthDialogMode.link`) and secondary CTA **"Sign In"** (`AuthDialogMode.signIn`).
- Highlights that Alarms & Workout Verification remain 100% available offline for guests.

#### [AppShellPage](file:///j:/GitHub/flutter_projects/awaken/lib/features/shell/presentation/pages/app_shell_page.dart)
- **Navigation Guard**: Updated `_goTo(int index)` to check guest status (`Supabase.instance.client.auth.currentUser?.isAnonymous`).
- When a guest user attempts to select **Territory** (tab 2) or **Squad** (tab 3), navigation intercepts and opens the account registration dialog instead of switching tabs.

#### [TerritoryPage](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/pages/territory_page.dart)
- **Safeguard View**: If `TerritoryPage` is rendered for a guest user, it displays [TerritoryGateCard](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/widgets/territory_gate_card.dart) instead of launching MapLibre render threads or background GPS location providers.

#### [HomePage](file:///j:/GitHub/flutter_projects/awaken/lib/features/home/presentation/pages/home_page.dart)
- **Action Pill Updates**: Updated `_QuickActionsPill` to display a lock icon (`Icons.lock_outline`) and **"Unlock Run"** / **"Unlock Squad"** labels for guest users, while keeping Alarms 100% accessible.

---

### 🛡️ 2. Supabase Database Hardening & Performance Migration

#### [20260801000001_security_and_performance_hardening.sql](file:///j:/GitHub/flutter_projects/awaken/supabase/migrations/20260801000001_security_and_performance_hardening.sql)
- **Migration Applied**: Executed migration on live Supabase project `qxxkydisyqnodskmymla` (`awaken-dev`).
- **RPC Permissions**: Explicitly revoked `EXECUTE` on 16 `SECURITY DEFINER` RPC functions (`submit_run`, `create_squad`, `join_squad`, `leave_squad`, `squad_members`, `squad_leaderboard`, `global_leaderboard`, `nearby_leaderboard`, `my_global_rank`, `my_nearby_rank`, `my_squad_rank`, `my_owned_area_sqm`, `recent_territory_captures`, `current_rival`, `bump_wake_up_tax`, `reset_wake_up_tax`) from `anon` / `public`, granting execution exclusively to `authenticated` and `service_role`.
- **Performance Optimization**: Dropped 10 unused indexes (`runs_path_gix`, `runs_user_id_idx`, `sessions_user_id_idx`, `profiles_squad_id_idx`, `sessions_alarm_id_idx`, `squad_reports_*_idx`, `bounty_zones_center_gix`) to boost write throughput.

---

## 🧪 Verification Results

1. **Dart Static Analysis**: Ran `analyze_files` across `lib/` with **0 diagnostics/errors**.
2. **Supabase Database Migration**: Applied migration `20260801000001_security_and_performance_hardening.sql` successfully (`{"success": true}`).
3. **Database Advisors**: Verified performance index cleanup and security advisory updates via Supabase MCP.
