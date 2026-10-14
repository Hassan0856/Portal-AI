-- =====================================================================
-- PortalAI — Reference RLS Policies for Existing Tables:
-- 1. public.guardian_resident_links
-- 2. public.guardian_resident_emails
-- 3. public.profiles
-- =====================================================================

-- ─── 1. guardian_resident_links ──────────────────────────────────────
alter table if exists public.guardian_resident_links enable row level security;

-- Guardians can read links where they are the guardian; residents can read links where they are the resident
drop policy if exists "Guardians and residents can view their links" on public.guardian_resident_links;
create policy "Guardians and residents can view their links"
  on public.guardian_resident_links for select
  using (auth.uid() = guardian_user_id or auth.uid() = resident_user_id);

-- ─── 2. guardian_resident_emails ─────────────────────────────────────
alter table if exists public.guardian_resident_emails enable row level security;

-- SELECT: Guardian can view emails only for residents they are actively linked to
drop policy if exists "Guardians can view emails for linked residents" on public.guardian_resident_emails;
create policy "Guardians can view emails for linked residents"
  on public.guardian_resident_emails for select
  using (
    auth.uid() = guardian_user_id
    and exists (
      select 1 from public.guardian_resident_links gl
      where gl.guardian_user_id = auth.uid()
        and gl.resident_user_id = guardian_resident_emails.resident_user_id
    )
  );

-- INSERT: Guardian can insert emails only for residents they are actively linked to
drop policy if exists "Guardians can add emails for linked residents" on public.guardian_resident_emails;
create policy "Guardians can add emails for linked residents"
  on public.guardian_resident_emails for insert
  with check (
    auth.uid() = guardian_user_id
    and exists (
      select 1 from public.guardian_resident_links gl
      where gl.guardian_user_id = auth.uid()
        and gl.resident_user_id = guardian_resident_emails.resident_user_id
    )
  );

-- UPDATE: Guardian can only update rows they created
drop policy if exists "Guardians can update their email entries" on public.guardian_resident_emails;
create policy "Guardians can update their email entries"
  on public.guardian_resident_emails for update
  using (auth.uid() = guardian_user_id)
  with check (auth.uid() = guardian_user_id);

-- DELETE: Guardian can only delete rows they created
drop policy if exists "Guardians can delete their email entries" on public.guardian_resident_emails;
create policy "Guardians can delete their email entries"
  on public.guardian_resident_emails for delete
  using (auth.uid() = guardian_user_id);

-- ─── 3. profiles (Optional but recommended) ──────────────────────────
-- Allows guardians to read display names of residents they are linked to
drop policy if exists "Guardians can view linked resident profiles" on public.profiles;
create policy "Guardians can view linked resident profiles"
  on public.profiles for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.guardian_resident_links gl
      where gl.guardian_user_id = auth.uid()
        and gl.resident_user_id = profiles.user_id
    )
  );
