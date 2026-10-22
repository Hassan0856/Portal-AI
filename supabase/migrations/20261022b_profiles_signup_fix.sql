-- =====================================================================
-- Portal AI v4.1b: sign up creates the profiles row, and no more
-- "infinite recursion detected in policy for relation profiles".
-- Run once in Supabase -> SQL Editor (safe to run again).
-- =====================================================================

-- ─── 1. Policies on profiles and links without loops ─────────────────
-- The error came from a profiles policy that reads guardian_resident_links
-- while a links policy reads profiles. The checks now run inside
-- security-definer functions, which read the tables without RLS, so no
-- policy ever calls another policy.

create or replace function public.is_linked_with(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from guardian_resident_links l
                  where (l.guardian_user_id = auth.uid() and l.resident_user_id = p_user)
                     or (l.resident_user_id = auth.uid() and l.guardian_user_id = p_user));
$$;

do $$
declare p record;
begin
  for p in
    select tablename, policyname from pg_policies
     where schemaname = 'public' and tablename in ('profiles', 'guardian_resident_links')
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.guardian_resident_links enable row level security;

-- Your own row, plus the names of people you are linked to.
create policy "own or linked profile" on public.profiles
  for select to authenticated
  using (user_id = auth.uid() or public.is_linked_with(user_id));

-- Each side sees its own links. Links are added and removed only through
-- redeem_link_code() / remove_link().
create policy "own links" on public.guardian_resident_links
  for select to authenticated
  using (auth.uid() = guardian_user_id or auth.uid() = resident_user_id);

-- ─── 2. Sign up creates the profiles row ─────────────────────────────
-- The app sends the chosen role and name with the sign up (user metadata).

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.raw_user_meta_data->>'role', '') in ('resident', 'guardian') then
    insert into public.profiles (user_id, role, display_name)
    values (new.id,
            new.raw_user_meta_data->>'role',
            coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
                     split_part(new.email, '@', 1)))
    on conflict (user_id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Accounts made before this trigger: the app calls this after log in when
-- the account has no profiles row yet. It only ever creates the caller's
-- own row, from the role chosen at sign up.
create or replace function public.ensure_my_profile()
returns json language plpgsql volatile security definer set search_path = public as $$
declare u auth.users; r text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  select * into u from auth.users where id = auth.uid();
  r := u.raw_user_meta_data->>'role';
  if r in ('resident', 'guardian') then
    insert into profiles (user_id, role, display_name)
    values (u.id, r, coalesce(nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
                              split_part(u.email, '@', 1)))
    on conflict (user_id) do nothing;
  end if;
  return (select json_build_object('role', role, 'display_name', display_name)
            from profiles where user_id = auth.uid());
end $$;
revoke execute on function public.ensure_my_profile() from public, anon;
grant  execute on function public.ensure_my_profile() to authenticated;

-- Fill in rows for everyone who already signed up without one.
insert into public.profiles (user_id, role, display_name)
select u.id, u.raw_user_meta_data->>'role',
       coalesce(nullif(trim(u.raw_user_meta_data->>'display_name'), ''), split_part(u.email, '@', 1))
  from auth.users u
 where u.raw_user_meta_data->>'role' in ('resident', 'guardian')
   and not exists (select 1 from public.profiles p where p.user_id = u.id);

-- Check
select p.role, p.display_name, u.email
  from public.profiles p join auth.users u on u.id = p.user_id
 order by p.created_at desc;
