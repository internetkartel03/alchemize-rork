-- Provisional limits: 20 requests per UTC hour and 100 per UTC day per signed-in user.
-- Review these defaults before applying the migration.

create table if not exists public.ai_request_usage (
  user_id uuid primary key references auth.users (id) on delete cascade,
  hour_window_started_at timestamptz not null,
  hourly_count integer not null default 0 check (hourly_count >= 0),
  day_window date not null,
  daily_count integer not null default 0 check (daily_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.ai_request_usage enable row level security;
revoke all on table public.ai_request_usage from public, anon, authenticated;

create or replace function public.consume_ai_request()
returns table (allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_hour_window timestamptz;
  v_day_window date;
  v_stored_hour timestamptz;
  v_hourly_count integer;
  v_stored_day date;
  v_daily_count integer;
begin
  if v_user_id is null then
    return query select false, 3600;
    return;
  end if;

  v_hour_window := date_trunc('hour', v_now at time zone 'UTC') at time zone 'UTC';
  v_day_window := (v_now at time zone 'UTC')::date;

  insert into public.ai_request_usage (
    user_id,
    hour_window_started_at,
    hourly_count,
    day_window,
    daily_count,
    updated_at
  ) values (
    v_user_id,
    v_hour_window,
    0,
    v_day_window,
    0,
    v_now
  ) on conflict (user_id) do nothing;

  select usage.hour_window_started_at, usage.hourly_count, usage.day_window, usage.daily_count
    into v_stored_hour, v_hourly_count, v_stored_day, v_daily_count
    from public.ai_request_usage as usage
    where usage.user_id = v_user_id
    for update;

  if v_stored_hour <> v_hour_window then
    v_hourly_count := 0;
    update public.ai_request_usage
      set hour_window_started_at = v_hour_window, hourly_count = 0
      where user_id = v_user_id;
  end if;

  if v_stored_day <> v_day_window then
    v_daily_count := 0;
    update public.ai_request_usage
      set day_window = v_day_window, daily_count = 0
      where user_id = v_user_id;
  end if;

  if v_hourly_count >= 20 then
    return query select false, greatest(1, ceil(extract(epoch from (v_hour_window + interval '1 hour' - v_now)))::integer);
    return;
  end if;

  if v_daily_count >= 100 then
    return query select false, greatest(1, ceil(extract(epoch from (((v_day_window + 1)::timestamp at time zone 'UTC') - v_now)))::integer);
    return;
  end if;

  update public.ai_request_usage
    set hourly_count = v_hourly_count + 1,
        daily_count = v_daily_count + 1,
        updated_at = v_now
    where user_id = v_user_id;

  return query select true, 0;
end;
$$;

revoke all on function public.consume_ai_request() from public, anon;
grant execute on function public.consume_ai_request() to authenticated;

comment on table public.ai_request_usage is
  'Private per-user AI request counters. Provisional limits are enforced by consume_ai_request().';
comment on function public.consume_ai_request() is
  'Atomically consumes one authenticated AI request quota: 20 per UTC hour and 100 per UTC day; review before deployment.';
