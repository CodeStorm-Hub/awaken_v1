-- Column-level REVOKE alone doesn't restrict anything while the broader
-- table-level UPDATE grant (from Supabase's default ALTER DEFAULT
-- PRIVILEGES on public schema) is still in effect — table-level UPDATE
-- implies UPDATE on every column regardless of column-level revokes.
-- Confirmed live via has_column_privilege() still returning true for
-- streak_tier/squad_id after the previous migration's column-only revoke.
-- The correct pattern: revoke the table-level grant entirely, then
-- re-grant UPDATE only on the columns that are legitimately client-owned.
revoke update on public.profiles from anon, authenticated;
grant update (display_name, territory_color) on public.profiles to anon, authenticated;
