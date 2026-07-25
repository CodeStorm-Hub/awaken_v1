-- Squad Realtime channels were public (no private config, no
-- realtime.messages policy) — any authenticated (or even anonymous, per
-- the client's anon-first model) client could subscribe to any squad's
-- 'squad:<uuid>' topic and read/send Presence & Broadcast traffic for a
-- squad they don't belong to. Per Supabase's Realtime Authorization model,
-- a single SELECT policy on realtime.messages governs both receiving and
-- sending on a private channel (checked once at subscription time, then
-- cached for the life of that connection).
create policy "squad members can use their squad's realtime channel"
on "realtime"."messages"
for select
to authenticated
using (
  realtime.topic() = 'squad:' || (
    select squad_id::text from public.profiles where id = (select auth.uid())
  )
);
