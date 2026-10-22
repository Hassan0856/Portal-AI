-- =====================================================================
-- Portal AI v4.1: resident <-> guardian linking
-- Run once in Supabase -> SQL Editor (safe to run again).
--
-- What it does
--   * Each door sensor (devices row) belongs to one resident.
--   * A guardian sees a resident's events, photos and messages only after
--     the resident shares a 6-digit link code and the guardian enters it.
--   * Every messages row is tagged with its resident, so the Messages
--     screen and the live feed only show your own household.
--   * n8n WF-00 calls push_target() to find which resident a push is for,
--     and sends it to that resident's own FCM topics (not to everyone).
--
-- n8n keeps using the service_role key, which bypasses RLS, so WF-01..07
-- keep working unchanged.
-- =====================================================================

-- ─── 1. Tables and columns ───────────────────────────────────────────

-- Who is linked to whom. Most projects already have this table.
create table if not exists public.guardian_resident_links (
  guardian_user_id uuid not null references auth.users(id) on delete cascade,
  resident_user_id uuid not null references auth.users(id) on delete cascade,
  created_at       timestamptz not null default now()
);
create unique index if not exists guardian_resident_links_pair
  on public.guardian_resident_links (guardian_user_id, resident_user_id);

-- The resident a door sensor belongs to.
alter table public.devices
  add column if not exists resident_user_id uuid references auth.users(id) on delete set null;

-- The resident a notification is about.
alter table public.messages
  add column if not exists resident_user_id uuid references auth.users(id) on delete cascade;
create index if not exists messages_resident_idx
  on public.messages (resident_user_id, created_at desc);

-- Short-lived codes a resident shares with a guardian.
create table if not exists public.link_codes (
  code             text primary key,
  resident_user_id uuid not null references auth.users(id) on delete cascade,
  expires_at       timestamptz not null default now() + interval '24 hours',
  created_at       timestamptz not null default now()
);
alter table public.link_codes enable row level security;  -- no policies: only the functions below touch it

-- ─── 2. Helper functions used by the policies ────────────────────────

-- True when the signed-in user is this resident or a guardian linked to them.
create or replace function public.can_see_resident(p_resident uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_resident is not null and (
    p_resident = auth.uid()
    or exists (select 1 from guardian_resident_links l
                where l.guardian_user_id = auth.uid()
                  and l.resident_user_id = p_resident));
$$;

-- True when the signed-in user may see this sensor's events.
create or replace function public.can_see_device(p_device text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from devices d
                  where d.id = p_device and public.can_see_resident(d.resident_user_id));
$$;

-- True when the signed-in user belongs to at least one household
-- (used for the shared tables: site_config, baseline, reports, faces).
create or replace function public.has_household()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from devices d where public.can_see_resident(d.resident_user_id));
$$;

-- The only resident with a sensor, when there is exactly one household.
-- Lets the digest and offline pushes (which name no event) reach that home.
create or replace function public.default_resident()
returns uuid language sql stable security definer set search_path = public as $$
  select case when count(distinct resident_user_id) = 1
              then min(resident_user_id::text)::uuid end
    from devices where resident_user_id is not null;
$$;

-- ─── 3. Row Level Security: only your own household ──────────────────
-- The old v4 policies let every signed-in account read everything
-- ("using (true)"). Policies add up, so all old read policies on these
-- tables are removed first. The app never writes to them (n8n does).
do $$
declare p record;
begin
  for p in
    select tablename, policyname from pg_policies
     where schemaname = 'public'
       and tablename in ('devices', 'events', 'messages', 'site_config', 'baseline', 'reports')
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

alter table public.devices     enable row level security;
alter table public.events      enable row level security;
alter table public.messages    enable row level security;
alter table public.site_config enable row level security;
alter table public.baseline    enable row level security;
alter table public.reports     enable row level security;

create policy "household reads devices" on public.devices
  for select to authenticated using (public.can_see_resident(resident_user_id));
create policy "household reads events" on public.events
  for select to authenticated using (public.can_see_device(device_id));
create policy "household reads messages" on public.messages
  for select to authenticated using (public.can_see_resident(resident_user_id));
create policy "household reads config" on public.site_config
  for select to authenticated using (public.has_household());
create policy "household reads baseline" on public.baseline
  for select to authenticated using (public.can_see_device(device_id));
create policy "household reads reports" on public.reports
  for select to authenticated using (public.has_household());

-- Reference photo list (no photos) only for people in a household.
create or replace view public.known_faces_public as
  select id, label, role, consent_by, created_at
    from public.known_faces
   where public.has_household();
revoke all on public.known_faces_public from anon, authenticated;
grant select on public.known_faces_public to authenticated;

-- Links: each side sees its own links.
alter table public.guardian_resident_links enable row level security;
drop policy if exists "Guardians and residents can view their links" on public.guardian_resident_links;
create policy "Guardians and residents can view their links"
  on public.guardian_resident_links for select to authenticated
  using (auth.uid() = guardian_user_id or auth.uid() = resident_user_id);

-- Profiles: your own, plus the names of people you are linked to.
alter table public.profiles enable row level security;
drop policy if exists "Guardians can view linked resident profiles" on public.profiles;
drop policy if exists "linked profiles" on public.profiles;
create policy "linked profiles" on public.profiles
  for select to authenticated
  using (user_id = auth.uid()
         or exists (select 1 from guardian_resident_links l
                     where (l.guardian_user_id = auth.uid() and l.resident_user_id = profiles.user_id)
                        or (l.resident_user_id = auth.uid() and l.guardian_user_id = profiles.user_id)));

-- ─── 4. Tag every message with its resident ──────────────────────────

create or replace function public.messages_fill_resident()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.resident_user_id is null and new.event_id is not null then
    select d.resident_user_id into new.resident_user_id
      from events e join devices d on d.id = e.device_id
     where e.id = new.event_id;
  end if;
  if new.resident_user_id is null and new.event_id is null then
    new.resident_user_id := public.default_resident();
  end if;
  return new;
end $$;

drop trigger if exists messages_fill_resident on public.messages;
create trigger messages_fill_resident before insert on public.messages
  for each row execute function public.messages_fill_resident();

-- ─── 5. Linking from the app ─────────────────────────────────────────

-- Resident: make a new 6-digit code (valid 24 hours; older codes stop working).
create or replace function public.create_link_code()
returns json language plpgsql volatile security definer set search_path = public as $$
declare c text; tries int := 0;
begin
  if not exists (select 1 from profiles where user_id = auth.uid() and role = 'resident') then
    raise exception 'Only a resident account can share a link code.';
  end if;
  delete from link_codes where resident_user_id = auth.uid() or expires_at < now();
  loop
    c := lpad((floor(random() * 1000000))::int::text, 6, '0');
    begin
      insert into link_codes (code, resident_user_id) values (c, auth.uid());
      exit;
    exception when unique_violation then
      tries := tries + 1;
      if tries > 20 then raise; end if;
    end;
  end loop;
  return json_build_object('code', c, 'expires_at', now() + interval '24 hours');
end $$;

-- Guardian: enter the code to link to that resident.
create or replace function public.redeem_link_code(p_code text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare r uuid; n text;
begin
  if not exists (select 1 from profiles where user_id = auth.uid() and role = 'guardian') then
    raise exception 'Only a guardian account can enter a link code.';
  end if;
  select resident_user_id into r from link_codes
   where code = trim(p_code) and expires_at > now();
  if r is null then
    raise exception 'This code is wrong or has expired. Ask for a new one.';
  end if;
  insert into guardian_resident_links (guardian_user_id, resident_user_id)
  values (auth.uid(), r) on conflict do nothing;
  delete from link_codes where code = trim(p_code);
  select display_name into n from profiles where user_id = r;
  return json_build_object('resident_user_id', r, 'display_name', n);
end $$;

-- Either side: list the people you are linked to.
create or replace function public.my_links()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(x order by x.linked_at), '[]'::json) from (
    select l.resident_user_id as user_id, 'resident' as role,
           p.display_name, l.created_at as linked_at
      from guardian_resident_links l left join profiles p on p.user_id = l.resident_user_id
     where l.guardian_user_id = auth.uid()
    union all
    select l.guardian_user_id, 'guardian', p.display_name, l.created_at
      from guardian_resident_links l left join profiles p on p.user_id = l.guardian_user_id
     where l.resident_user_id = auth.uid()
  ) x;
$$;

-- Either side: remove a link.
create or replace function public.remove_link(p_other uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  delete from guardian_resident_links
   where (guardian_user_id = auth.uid() and resident_user_id = p_other)
      or (resident_user_id = auth.uid() and guardian_user_id = p_other);
  get diagnostics n = row_count;
  return json_build_object('removed', n);
end $$;

revoke execute on function public.create_link_code()     from public, anon;
revoke execute on function public.redeem_link_code(text) from public, anon;
revoke execute on function public.my_links()             from public, anon;
revoke execute on function public.remove_link(uuid)      from public, anon;
grant  execute on function public.create_link_code()     to authenticated;
grant  execute on function public.redeem_link_code(text) to authenticated;
grant  execute on function public.my_links()             to authenticated;
grant  execute on function public.remove_link(uuid)      to authenticated;

-- ─── 6. Who a push is for (called by n8n WF-00, service_role only) ───

create or replace function public.push_target(p_event_id text default '', p_device_id text default '')
returns json language plpgsql stable security definer set search_path = public as $$
declare ev events; dev devices; cfg site_config; rid uuid;
begin
  if coalesce(p_event_id, '') ~ '^[0-9]+$' then
    select * into ev from events where id = p_event_id::bigint;
  end if;
  select * into dev from devices where id = coalesce(ev.device_id, nullif(p_device_id, ''));
  select * into cfg from site_config where id = 1;
  rid := case when dev.id is not null then dev.resident_user_id   -- the sensor's own resident
              else public.default_resident() end;                  -- digest / offline in a one-home setup
  return json_build_object(
    'resident_user_id', coalesce(rid::text, ''),
    'resident_name',    coalesce((select display_name from profiles where user_id = rid), cfg.resident_name, ''),
    'site_name',        coalesce(cfg.site_name, 'Home'),
    'location',         coalesce(dev.location, ''),
    'event_id',         coalesce(ev.id::text, ''),
    'event_type',       coalesce(ev.event_type, ''),
    'score',            ev.anomaly_score,
    'description',      coalesce(ev.description, ''),
    'reason',           coalesce(ev.reason, ''),
    'local_time',       coalesce(to_char(ev.occurred_at at time zone 'Asia/Kolkata', 'FMHH12:MI AM'), ''));
end $$;
revoke execute on function public.push_target(text, text) from public, anon, authenticated;
grant  execute on function public.push_target(text, text) to service_role;

-- Realtime stays on for the live feed (already added in v4 3.3).

-- ─── 7. Give each sensor its resident (EDIT THE EMAIL, then run) ─────
-- Until a sensor has a resident, nobody sees its events or gets its pushes.
--
-- update public.devices
--    set resident_user_id = (select id from auth.users where email = 'amma@example.com')
--  where id = 'front_door';
--
-- Tag the messages that already exist:
--
-- update public.messages m set resident_user_id = d.resident_user_id
--   from public.events e join public.devices d on d.id = e.device_id
--  where m.resident_user_id is null and m.event_id = e.id;
-- update public.messages set resident_user_id = public.default_resident()
--  where resident_user_id is null;
--
-- Optional, instead of codes in the app: link a guardian by email.
--
-- insert into public.guardian_resident_links (guardian_user_id, resident_user_id)
-- select g.id, r.id from auth.users g, auth.users r
--  where g.email = 'ravi@example.com' and r.email = 'amma@example.com'
-- on conflict do nothing;
--
-- Check:
-- select d.id, u.email as resident from public.devices d left join auth.users u on u.id = d.resident_user_id;
-- select * from public.guardian_resident_links;
