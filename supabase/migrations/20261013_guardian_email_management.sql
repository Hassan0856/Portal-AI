-- =====================================================================
-- PortalAI — Additive Migration: Guardian Resident Email Management
-- Date: 2026-10-13
--
-- This migration adds ONE new table and its RLS policies.
-- It does NOT modify any existing table, column, index, trigger,
-- or policy. It is fully safe to apply to the live database.
-- =====================================================================

-- ─── Table: resident_contact_emails ──────────────────────────────────
-- Stores additional contact email addresses managed by a guardian on
-- behalf of an authorised resident.
--
-- IMPORTANT: Adding an email here does NOT create any Supabase Auth
-- account, does NOT grant any application role, and does NOT mark the
-- address as verified. Status is always 'saved'.
-- ─────────────────────────────────────────────────────────────────────
create table if not exists public.resident_contact_emails (
  id           uuid        primary key default gen_random_uuid(),

  -- The resident whose contact emails are being managed.
  -- References profiles.user_id (live table primary key).
  resident_id  uuid        not null
                 references public.profiles(user_id) on delete cascade,

  -- The guardian who added this entry. Always set to auth.uid() on insert
  -- (enforced by the INSERT RLS policy's WITH CHECK clause).
  guardian_id  uuid        not null
                 references public.profiles(user_id) on delete cascade,

  -- The stored email address (lower-cased at the service layer).
  email        text        not null,

  -- Optional free-text label (e.g. "Emergency contact"). Editable.
  label        text,

  -- Always 'saved'. Verification is out of scope for this feature.
  status       text        not null default 'saved'
                 check (status in ('saved')),

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Prevent duplicate emails for the same resident (guardian-agnostic).
  constraint unique_resident_email unique (resident_id, email)
);

-- Indexes for fast lookup by guardian or by resident.
create index if not exists idx_rce_resident on public.resident_contact_emails(resident_id);
create index if not exists idx_rce_guardian on public.resident_contact_emails(guardian_id);

-- ─── Row Level Security ───────────────────────────────────────────────
alter table public.resident_contact_emails enable row level security;

-- SELECT — a guardian may only read emails for residents they are
--          actively linked to via guardian_relationships.
create policy "Guardian can view emails for their residents"
  on public.resident_contact_emails for select
  using (
    auth.uid() = guardian_id
    and exists (
      select 1
      from   public.guardian_relationships gr
      where  gr.guardian_id = auth.uid()
        and  gr.resident_id = resident_contact_emails.resident_id
        and  gr.status      = 'active'
    )
  );

-- INSERT — guardian_id MUST equal auth.uid() (prevents forging another
--          guardian's ID) AND the guardian must be actively linked to
--          the target resident.
create policy "Guardian can add emails for their residents"
  on public.resident_contact_emails for insert
  with check (
    auth.uid() = guardian_id
    and exists (
      select 1
      from   public.guardian_relationships gr
      where  gr.guardian_id = auth.uid()
        and  gr.resident_id = resident_contact_emails.resident_id
        and  gr.status      = 'active'
    )
  );

-- UPDATE — only the guardian who owns the row may update it (label edits).
--          The WITH CHECK ensures they cannot change guardian_id to impersonate
--          another guardian.
create policy "Guardian can edit their own email entries"
  on public.resident_contact_emails for update
  using     (auth.uid() = guardian_id)
  with check (auth.uid() = guardian_id);

-- DELETE — only the guardian who created the row may delete it.
create policy "Guardian can delete their own email entries"
  on public.resident_contact_emails for delete
  using (auth.uid() = guardian_id);

-- ─── Note on resident access ──────────────────────────────────────────
-- No SELECT, INSERT, UPDATE, or DELETE policy exists for residents.
-- Residents have zero access to this table at the database level,
-- regardless of any client-side navigation or request manipulation.
-- ─────────────────────────────────────────────────────────────────────
