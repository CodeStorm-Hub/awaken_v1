-- A skipped (unverified) session is a legitimate real event the client
-- must be able to sync — `completed_at` being NOT NULL made every skip
-- outbox entry permanently unpushable (the client's local `completedAt` is
-- already nullable for exactly this reason; the server column never
-- matched it). No CHECK/FK depends on this column, so relaxing it is safe.
alter table public.sessions alter column completed_at drop not null;
