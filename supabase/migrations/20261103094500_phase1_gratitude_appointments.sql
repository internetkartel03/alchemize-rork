-- Phase 1: gratitude_entries + appointments for the Supabase-backed data services.
--
-- Matches expo/services/gratitude.service.ts and expo/services/appointments.service.ts exactly:
--   * quoted camelCase columns ("entryDate", "gratitude1".."gratitude3", "createdAt")
--   * client-generated text primary keys (grat_<epoch>_<rand>, apt_<epoch>_<rand>)
--   * user_id uuid referencing auth.users, set from the authenticated session
--   * epoch-millisecond timestamps stored as bigint
--   * unique (user_id, "entryDate") because gratitude upserts on that conflict target
--
-- Access is owner-only for the `authenticated` role. No anon policies exist and
-- anon privileges are revoked, so only a signed-in session can read or write rows
-- and only within its own user_id.

-- ---------------------------------------------------------------------------
-- gratitude_entries
-- ---------------------------------------------------------------------------
create table if not exists public.gratitude_entries (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  "entryDate" bigint not null,
  "gratitude1" text not null,
  "gratitude2" text,
  "gratitude3" text,
  reflection text,
  "createdAt" bigint not null,
  constraint gratitude_entries_user_id_entry_date_key unique (user_id, "entryDate")
);

create index if not exists gratitude_entries_user_id_entry_date_idx
  on public.gratitude_entries (user_id, "entryDate" desc);

alter table public.gratitude_entries enable row level security;

-- Supabase grants PUBLIC/anon by default; remove both, then grant CRUD to authenticated only.
revoke all on table public.gratitude_entries from public;
revoke all on table public.gratitude_entries from anon;
grant select, insert, update, delete on table public.gratitude_entries to authenticated;

drop policy if exists "gratitude_entries_select_own" on public.gratitude_entries;
create policy "gratitude_entries_select_own"
  on public.gratitude_entries
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "gratitude_entries_insert_own" on public.gratitude_entries;
create policy "gratitude_entries_insert_own"
  on public.gratitude_entries
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "gratitude_entries_update_own" on public.gratitude_entries;
create policy "gratitude_entries_update_own"
  on public.gratitude_entries
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "gratitude_entries_delete_own" on public.gratitude_entries;
create policy "gratitude_entries_delete_own"
  on public.gratitude_entries
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- appointments
-- ---------------------------------------------------------------------------
create table if not exists public.appointments (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null,
  date bigint not null,
  time text not null,
  category text not null default 'personal',
  notes text not null default '',
  reminder boolean not null default true,
  "createdAt" bigint not null,
  metadata text
);

create index if not exists appointments_user_id_date_time_idx
  on public.appointments (user_id, date, time);

alter table public.appointments enable row level security;

revoke all on table public.appointments from public;
revoke all on table public.appointments from anon;
grant select, insert, update, delete on table public.appointments to authenticated;

drop policy if exists "appointments_select_own" on public.appointments;
create policy "appointments_select_own"
  on public.appointments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "appointments_insert_own" on public.appointments;
create policy "appointments_insert_own"
  on public.appointments
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "appointments_update_own" on public.appointments;
create policy "appointments_update_own"
  on public.appointments
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "appointments_delete_own" on public.appointments;
create policy "appointments_delete_own"
  on public.appointments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
