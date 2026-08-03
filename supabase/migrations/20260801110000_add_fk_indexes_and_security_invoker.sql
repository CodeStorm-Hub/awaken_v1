-- Migration: Foreign Key Indexes & SECURITY INVOKER Hardening
-- Date: 2026-08-01

-- 1. Create Covering B-Tree Indexes on Foreign Keys for Performance
CREATE INDEX IF NOT EXISTS idx_profiles_squad_id ON public.profiles(squad_id);
CREATE INDEX IF NOT EXISTS idx_runs_user_id ON public.runs(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_alarm_id ON public.sessions(alarm_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_squads_owner_id ON public.squads(owner_id);
CREATE INDEX IF NOT EXISTS idx_squad_reports_reporter_id ON public.squad_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_squad_reports_reported_user_id ON public.squad_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_squad_reports_squad_id ON public.squad_reports(squad_id);

-- 2. Convert User-Facing RPC Functions to SECURITY INVOKER for Strict RLS Enforcement
ALTER FUNCTION public.submit_run(uuid, jsonb, timestamp with time zone, timestamp with time zone, timestamp with time zone[]) SECURITY INVOKER;
ALTER FUNCTION public.create_squad(text) SECURITY INVOKER;
ALTER FUNCTION public.join_squad(text) SECURITY INVOKER;
ALTER FUNCTION public.leave_squad() SECURITY INVOKER;
ALTER FUNCTION public.bump_wake_up_tax() SECURITY INVOKER;
ALTER FUNCTION public.reset_wake_up_tax() SECURITY INVOKER;
ALTER FUNCTION public.current_rival() SECURITY INVOKER;
ALTER FUNCTION public.my_owned_area_sqm() SECURITY INVOKER;
ALTER FUNCTION public.recent_territory_captures(integer) SECURITY INVOKER;
ALTER FUNCTION public.squad_members(uuid) SECURITY INVOKER;
ALTER FUNCTION public.global_leaderboard(text, integer, integer) SECURITY INVOKER;
ALTER FUNCTION public.nearby_leaderboard(numeric, text, integer, integer) SECURITY INVOKER;
ALTER FUNCTION public.squad_leaderboard(uuid, text) SECURITY INVOKER;
ALTER FUNCTION public.my_global_rank(text) SECURITY INVOKER;
ALTER FUNCTION public.my_nearby_rank(numeric, text) SECURITY INVOKER;
ALTER FUNCTION public.my_squad_rank(uuid, text) SECURITY INVOKER;
