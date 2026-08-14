-- ============================================================
-- Holistify Islamic Studies App — Admin role migration
-- Run this in Supabase SQL Editor
-- ============================================================
--
-- Adds a third role, 'admin', for Holistify staff to manage the
-- platform (view/deactivate any account, and later manage subscriptions).
--
-- Admins are NOT self-signup-able — the signup form only ever offers
-- facilitator/student. To make someone an admin, run:
--   update is_profiles set role = 'admin' where email = '<their synthetic/login email>';
-- (or update by id — find it in Authentication > Users in the dashboard)

alter table is_profiles drop constraint if exists is_profiles_role_check;
alter table is_profiles add constraint is_profiles_role_check check (role in ('facilitator','student','admin'));

-- Admins get every facilitator permission for free (superset), so no
-- existing RLS policy needs rewriting — they already check is_facilitator().
create or replace function is_facilitator()
returns boolean language sql stable security definer as $$
  select exists(select 1 from is_profiles where id = auth.uid() and role in ('facilitator','admin'));
$$;

create or replace function is_admin()
returns boolean language sql stable security definer as $$
  select exists(select 1 from is_profiles where id = auth.uid() and role = 'admin');
$$;

-- Admin-only: can update ANY profile (deactivate accounts, fix roles,
-- and later flip subscription fields), not just their own row.
do $$ begin
  if not exists (select 1 from pg_policies where tablename='is_profiles' and policyname='is_profiles_admin_update') then
    create policy "is_profiles_admin_update" on is_profiles for update to authenticated using (is_admin()) with check (is_admin());
  end if;
end $$;
