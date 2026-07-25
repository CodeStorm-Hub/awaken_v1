-- Rivalry (refined territory plan, item 3). A single "current rival" per
-- user, not a persistent multi-rival system — computed from the most
-- recent row where the user appears on either side of a contested
-- capture. This event log doubles as the leaderboard's Weekly-window data
-- source (sum area_taken_sqm per user over the trailing 7 days).

create table public.territory_captures (
  id uuid primary key default extensions.gen_random_uuid(),
  winner_id uuid not null references public.profiles(id),
  loser_id uuid references public.profiles(id), -- null when capturing unclaimed land
  area_taken_sqm double precision not null check (area_taken_sqm >= 0),
  created_at timestamptz not null default now()
);

create index territory_captures_winner_idx on public.territory_captures (winner_id, created_at desc);
create index territory_captures_loser_idx on public.territory_captures (loser_id, created_at desc) where loser_id is not null;

alter table public.territory_captures enable row level security;

-- Read-only for participants; writes happen exclusively from submit_run()
-- (SECURITY DEFINER), same posture as territories/runs.
create policy "territory_captures_select_own" on public.territory_captures
  for select
  using ((select auth.uid()) = winner_id or (select auth.uid()) = loser_id);

revoke insert, update, delete on public.territory_captures from anon, authenticated;

-- Returns the other party in the caller's most recent contested capture,
-- either direction (they beat someone, or someone beat them).
create or replace function public.current_rival()
returns table (rival_id uuid, rival_display_name text, area_taken_sqm double precision, as_winner boolean, occurred_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  return query
    select
      case when c.winner_id = v_uid then c.loser_id else c.winner_id end,
      p.display_name,
      c.area_taken_sqm,
      c.winner_id = v_uid,
      c.created_at
    from public.territory_captures c
    join public.profiles p on p.id = (case when c.winner_id = v_uid then c.loser_id else c.winner_id end)
    where (c.winner_id = v_uid or c.loser_id = v_uid)
      and (case when c.winner_id = v_uid then c.loser_id else c.winner_id end) is not null
    order by c.created_at desc
    limit 1;
end;
$$;

revoke all on function public.current_rival() from public, anon;
grant execute on function public.current_rival() to authenticated;
