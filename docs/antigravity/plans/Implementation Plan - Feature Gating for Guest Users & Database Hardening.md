# Implementation Plan - Feature Gating for Guest Users & Database Hardening

This plan details the implementation strategy to restrict **Guest / Unauthenticated Users** exclusively to the **Alarm & Workout Verification** feature, while gating **Territory & Squad** features behind account registration. It also includes database security hardening and performance optimizations.

---

## 🔒 Feature Access Matrix

| Feature | Guest / Unauthenticated User | Authenticated User |
| :--- | :--- | :--- |
| **Alarms & Scheduling** | ✅ **Full Access** (100% Local) | ✅ **Full Access** (Synced) |
| **Workout Verification (Squat/Pushup)** | ✅ **Full Access** (Camera ML Kit) | ✅ **Full Access** |
| **Local Streak & Alarm Reliability** | ✅ **Full Access** | ✅ **Full Access** |
| **Territory Mapping & GPS Runs** | 🛑 **Gated** (Prompts Sign-Up) | ✅ **Full Access** |
| **Squads & Social Chat** | 🛑 **Gated** (Prompts Sign-Up) | ✅ **Full Access** |
| **Global / Nearby Leaderboards** | 🛑 **Gated** (Prompts Sign-Up) | ✅ **Full Access** |

---

## 📱 Part 1: App & UI Implementation Plan

### 1. App Shell & Navigation Guard
#### [MODIFY] [app_shell_page.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/shell/presentation/pages/app_shell_page.dart)
- Monitor user auth state via `AuthRepository.userChanges` / `ProfileCubit`.
- When a Guest user taps the **Territory** (index 2) or **Squad** (index 3) tab, present an expressive **"Unlock Territory & Squads"** glassmorphism modal (`AuthDialog` in signup mode) instead of switching tabs.

### 2. Territory Page Gating Card
#### [NEW] [territory_gate_card.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/widgets/territory_gate_card.dart)
#### [MODIFY] [territory_page.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/territory/presentation/pages/territory_page.dart)
- Create a premium Material 3 glassmorphism feature gate widget with an interactive map preview background, lock icon, and copy:
  > **"Claim Your Realm"**  
  > *Sign up for an Awaken account to map your GPS runs, claim territory, defend your borders, and compete in squads.*
- Primary Button: **"Create Free Account"** (triggers `AuthDialog(mode: AuthDialogMode.link)`).
- Secondary Button: **"Sign In"**.
- If a guest user accesses `TerritoryPage`, render this gate widget instead of starting GPS background location tracking or MapLibre compositing.

### 3. Home Page Action Card Updates
#### [MODIFY] [home_page.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/home/presentation/pages/home_page.dart)
- Keep the **"Alarms & Morning Routine"** action card fully interactive for all users.
- Add a subtle lock badge (`Icons.lock_outline`) to the **"Territory & Start Run"** action card for guest users. Tapping it surfaces the Sign Up modal.

### 4. Squads Page Feature Gate
#### [MODIFY] [squad_page.dart](file:///j:/GitHub/flutter_projects/awaken/lib/features/squad/presentation/pages/squad_page.dart)
- Render an expressive registration callout for guest users explaining squad features (chat, joint territory defense, member streaks) with a 1-tap Sign Up button.

---

## 🛡️ Part 2: Supabase Database Hardening & Security

### 1. `submit_run` Anti-Guest Security Assertion
In the PostgreSQL database function `submit_run`, enforce an explicit check rejecting runs submitted by anonymous sessions:
```sql
IF (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE THEN
    RAISE EXCEPTION 'Account registration required to claim territory';
END IF;
```

### 2. RPC Authorization Hardening
#### [NEW] [20260801000001_security_and_performance_hardening.sql](file:///j:/GitHub/flutter_projects/awaken/supabase/migrations/20260801000001_security_and_performance_hardening.sql)
- Revoke `EXECUTE` on `submit_run`, `create_squad`, `join_squad`, `leave_squad`, `squad_members`, `squad_leaderboard`, `global_leaderboard`, `nearby_leaderboard`, `my_global_rank`, `my_nearby_rank`, `my_squad_rank`, `my_owned_area_sqm`, `recent_territory_captures`, `current_rival`, `bump_wake_up_tax`, `reset_wake_up_tax` from `anon` and `public`.
- Grant `EXECUTE` exclusively to `authenticated` and `service_role`.

### 3. Performance Index Cleanup
- Drop 10 unused indexes (`runs_path_gix`, `runs_user_id_idx`, `sessions_user_id_idx`, `profiles_squad_id_idx`, `sessions_alarm_id_idx`, `squad_reports_*_idx`, `bounty_zones_center_gix`) to boost write throughput.

---

## 🧪 Verification Plan

### Automated Tests
- Run `flutter test` to ensure alarm unit tests and UI widget tests pass cleanly.
- Run `dart-mcp-server` `analyze_files` on `lib/` to ensure 0 static analysis diagnostics.
- Apply migration `20260801000001_security_and_performance_hardening.sql` to `awaken-dev` using Supabase MCP.
- Run Supabase security & performance advisor diagnostics to verify lint resolution.

### Manual Verification
1. **Guest User Flow**: Launch app as Guest -> Alarms work 100% -> Tapping Territory or Squad tab shows the "Create Account to Claim Territory" modal.
2. **Authenticated User Flow**: Sign in with Google / Email -> Territory tab unlocks, map renders, GPS run tracking and squad features become available.
