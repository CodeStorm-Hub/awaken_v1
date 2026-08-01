-- Migration: Security & Performance Hardening
-- 1. Explicitly Revoke Execution on SECURITY DEFINER RPC functions from anon/public
REVOKE EXECUTE ON FUNCTION public.submit_run(uuid, jsonb, timestamp with time zone, timestamp with time zone, timestamp with time zone[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.submit_run(uuid, jsonb, timestamp with time zone, timestamp with time zone, timestamp with time zone[]) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.bump_wake_up_tax() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.bump_wake_up_tax() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.reset_wake_up_tax() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reset_wake_up_tax() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.create_squad(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_squad(text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.join_squad(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.join_squad(text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.leave_squad() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.leave_squad() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.squad_members(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.squad_members(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.squad_leaderboard(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.squad_leaderboard(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.global_leaderboard(text, integer, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.global_leaderboard(text, integer, integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.nearby_leaderboard(numeric, text, integer, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.nearby_leaderboard(numeric, text, integer, integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.my_global_rank(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_global_rank(text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.my_nearby_rank(numeric, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_nearby_rank(numeric, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.my_squad_rank(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_squad_rank(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.my_owned_area_sqm() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_owned_area_sqm() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.recent_territory_captures(integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.recent_territory_captures(integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.current_rival() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.current_rival() TO authenticated, service_role;

-- 2. Drop unused indexes flagged by performance advisor to optimize write throughput
DROP INDEX IF EXISTS public.bounty_zones_center_gix;
DROP INDEX IF EXISTS public.runs_user_id_idx;
DROP INDEX IF EXISTS public.sessions_user_id_idx;
DROP INDEX IF EXISTS public.runs_path_gix;
DROP INDEX IF EXISTS public.profiles_squad_id_idx;
DROP INDEX IF EXISTS public.sessions_alarm_id_idx;
DROP INDEX IF EXISTS public.squad_reports_reporter_id_idx;
DROP INDEX IF EXISTS public.squad_reports_reported_user_id_idx;
DROP INDEX IF EXISTS public.squad_reports_squad_id_idx;
DROP INDEX IF EXISTS public.squads_owner_id_idx;
