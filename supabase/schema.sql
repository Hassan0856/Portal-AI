-- ====================================================================
-- DO NOT RUN THIS FILE ON THE v4 PROJECT.
-- It is an older, different schema (security_events, profiles.id, ...)
-- and it would clash with the v4 tables the app and n8n now use.
-- The v4 schema is in Build Guide v4.0, sections 3.1 to 3.5.
-- ====================================================================

-- ====================================================================
-- Portal AI - Supabase Database Schema, RLS, Storage & Realtime Setup
-- ====================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pg_cron";

-- 2. PROFILES TABLE
-- Maps auth.users to application roles (resident or guardian)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('resident', 'guardian')),
  identifier text not null, -- Guardian ID or Resident ID
  email text not null,
  full_name text,
  reference_photo_url text, -- Storage path in security-snapshots bucket
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for fast lookup by identifier and email
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_email on public.profiles(email);
create index if not exists idx_profiles_identifier on public.profiles(identifier);

-- 3. GUARDIAN RELATIONSHIPS TABLE
-- Connects a Resident with their appointed Guardian(s)
create table if not exists public.guardian_relationships (
  id uuid primary key default gen_random_uuid(),
  resident_id uuid not null references public.profiles(id) on delete cascade,
  guardian_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'pending', 'revoked')),
  created_at timestamptz not null default now(),
  constraint unique_resident_guardian unique (resident_id, guardian_id)
);

create index if not exists idx_guardian_rel_resident on public.guardian_relationships(resident_id);
create index if not exists idx_guardian_rel_guardian on public.guardian_relationships(guardian_id);

-- 4. SECURITY EVENTS TABLE
-- AI-detected security events and camera captures
create table if not exists public.security_events (
  id text primary key default gen_random_uuid()::text,
  resident_id uuid references public.profiles(id) on delete cascade,
  score integer not null check (score >= 1 and score <= 10),
  location text not null,
  timestamp timestamptz not null default now(),
  type text not null, -- 'Motion', 'Person detected', 'Unrecognised face'
  description text not null,
  snapshot_path text, -- Private storage object path in security-snapshots
  created_at timestamptz not null default now()
);

create index if not exists idx_security_events_timestamp on public.security_events(timestamp desc);
create index if not exists idx_security_events_score on public.security_events(score);
create index if not exists idx_security_events_resident on public.security_events(resident_id);

-- 5. MESSAGES TABLE
-- System and risk alerts received by residents and guardians
create table if not exists public.messages (
  id text primary key default gen_random_uuid()::text,
  recipient_id uuid references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('highRisk', 'activity', 'system', 'lowRisk', 'general')),
  title text not null,
  description text not null,
  score integer check (score >= 1 and score <= 10),
  location text,
  timestamp timestamptz not null default now(),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_recipient on public.messages(recipient_id);
create index if not exists idx_messages_timestamp on public.messages(timestamp desc);
create index if not exists idx_messages_kind on public.messages(kind);

-- 6. USER SETTINGS TABLE
-- Syncs notification preferences between devices and cloud
create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  system_updates boolean not null default true,
  activity_alerts boolean not null default true,
  updated_at timestamptz not null default now()
);

-- 7. ROW LEVEL SECURITY (RLS) POLICIES
alter table public.profiles enable row level security;
alter table public.guardian_relationships enable row level security;
alter table public.security_events enable row level security;
alter table public.messages enable row level security;
alter table public.user_settings enable row level security;

-- Profiles RLS
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Guardians can view linked residents profile"
  on public.profiles for select
  using (
    exists (
      select 1 from public.guardian_relationships
      where guardian_id = auth.uid()
        and resident_id = profiles.id
        and status = 'active'
    )
  );

-- Guardian Relationships RLS
create policy "Users can view their relationships"
  on public.guardian_relationships for select
  using (auth.uid() = resident_id or auth.uid() = guardian_id);

create policy "Residents can manage guardian relationships"
  on public.guardian_relationships for all
  using (auth.uid() = resident_id);

-- Security Events RLS
create policy "Users can view security events"
  on public.security_events for select
  using (
    resident_id = auth.uid()
    or exists (
      select 1 from public.guardian_relationships
      where guardian_id = auth.uid()
        and resident_id = security_events.resident_id
        and status = 'active'
    )
    or resident_id is null -- allow demo/public sample rows
  );

create policy "Authenticated users can insert security events"
  on public.security_events for insert
  with check (auth.role() = 'authenticated');

-- Messages RLS
create policy "Users can view own messages"
  on public.messages for select
  using (
    recipient_id = auth.uid()
    or recipient_id is null -- allow global/demo messages
  );

create policy "Users can update own messages read status"
  on public.messages for update
  using (recipient_id = auth.uid());

-- User Settings RLS
create policy "Users can view own settings"
  on public.user_settings for select
  using (user_id = auth.uid());

create policy "Users can upsert own settings"
  on public.user_settings for all
  using (user_id = auth.uid());

-- 8. STORAGE CONFIGURATION: PRIVATE `security-snapshots` BUCKET
-- Note: Do NOT make this bucket public!
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'security-snapshots',
  'security-snapshots',
  false, -- PRIVATE BUCKET
  10485760, -- 10MB limit
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set public = false;

-- Storage RLS Policies
create policy "Authenticated users can upload snapshots"
  on storage.objects for insert
  with check (
    bucket_id = 'security-snapshots'
    and auth.role() = 'authenticated'
  );

create policy "Authenticated users can read snapshots"
  on storage.objects for select
  using (
    bucket_id = 'security-snapshots'
    and auth.role() = 'authenticated'
  );

-- 9. DATA RETENTION POLICY ENFORCEMENT
-- 48 hours for snapshots, 30 days for messages
create or replace function public.cleanup_expired_portal_data()
returns void
language plpgsql
security definer
as $$
begin
  -- 1. Delete security events snapshots older than 48 hours
  delete from public.security_events
  where timestamp < now() - interval '48 hours';

  -- 2. Delete messages older than 30 days
  delete from public.messages
  where timestamp < now() - interval '30 days';
end;
$$;

-- Schedule daily cron job at 3:00 AM UTC (if pg_cron is enabled in Supabase project)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'cleanup_expired_portal_data_daily',
      '0 3 * * *',
      'select public.cleanup_expired_portal_data();'
    );
  end if;
end $$;

-- 10. REALTIME CONFIGURATION
-- Enable realtime publication on security_events and messages tables
alter publication supabase_realtime add table public.security_events;
alter publication supabase_realtime add table public.messages;

-- 11. INITIAL SEED DATA (For initial dashboard inspection)
insert into public.security_events (id, score, location, timestamp, type, description)
values
  ('1', 9, 'Living Room', now() - interval '20 minutes', 'Unrecognised face', 'An unrecognised person was detected inside the living room. Check the snapshot and contact your guardian if needed.'),
  ('2', 5, 'Main Entrance', now() - interval '44 minutes', 'Person detected', 'A person lingered at the main entrance for several seconds.'),
  ('3', 2, 'Staircase', now() - interval '50 minutes', 'Motion', 'Routine movement on the staircase.'),
  ('4', 2, 'Balcony', now() - interval '50 minutes', 'Motion', 'Light movement on the balcony, consistent with wind.')
on conflict (id) do nothing;

insert into public.messages (id, kind, title, score, location, timestamp, description)
values
  ('m1', 'highRisk', 'High Risk Alert', 9, 'Front Door', now() - interval '20 minutes', 'Unusual activity detected at your door. Please check the snapshot.'),
  ('m2', 'activity', 'Activity Detected', 5, 'Main Entrance', now() - interval '2 hours', 'Motion detected. No immediate threat.'),
  ('m3', 'system', 'System Update', null, null, now() - interval '1 day', 'The app has been updated to version 2.1.0.'),
  ('m4', 'lowRisk', 'Low Risk Alert', 2, 'Staircase', now() - interval '1 day', 'Routine activity detected.'),
  ('m5', 'general', 'General Message', null, null, now() - interval '2 days', 'Welcome to PORTAL AI. Stay safe!')
on conflict (id) do nothing;
