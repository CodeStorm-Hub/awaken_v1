create table public.runs (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  path geometry(LineString, 4326) not null,
  is_closed_loop boolean not null default false,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  point_count integer not null check (point_count >= 0),
  distance_m double precision, -- ST_Length(path::geography), set server-side
  -- anti-cheat (plan H7): client isMocked/velocity gates are advisory only;
  -- these columns hold the server-authoritative verdict.
  integrity_verdict text check (integrity_verdict in ('trusted', 'suspicious', 'rejected')),
  rejected_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index runs_user_id_idx on public.runs(user_id) where deleted_at is null;
create index runs_path_gix on public.runs using gist(path);

alter table public.runs enable row level security;

-- Users can insert/select their own runs, but never update the
-- integrity/verdict columns directly — only the SECURITY DEFINER RPC does.
create policy "runs_select_own" on public.runs
  for select using (auth.uid() = user_id);

create policy "runs_insert_own" on public.runs
  for insert with check (auth.uid() = user_id);

create trigger runs_set_updated_at
  before update on public.runs
  for each row execute function public.set_updated_at();
