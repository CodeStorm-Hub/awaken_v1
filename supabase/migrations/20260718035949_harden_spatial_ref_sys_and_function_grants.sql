-- spatial_ref_sys is owned by supabase_admin, not postgres, so RLS can't
-- be enabled here (ALTER TABLE requires ownership). Revoking the write
-- grants directly closes the actual exploitable gap (anon/authenticated
-- could INSERT/UPDATE/DELETE/TRUNCATE PostGIS's SRID reference data) even
-- without RLS.
revoke insert, update, delete, truncate on public.spatial_ref_sys from anon, authenticated, public;

-- Unnecessary EXECUTE surface for the unauthenticated anon role.
revoke execute on function public.submit_run(uuid, jsonb, timestamptz, timestamptz) from public, anon;
revoke execute on function public.st_estimatedextent(text, text) from public, anon;
revoke execute on function public.st_estimatedextent(text, text, text) from public, anon;
revoke execute on function public.st_estimatedextent(text, text, text, boolean) from public, anon;
