-- ============================================================
-- Holistify Islamic Studies App — PIN-login migration
-- Run this in Supabase SQL Editor AFTER islamic_studies_schema.sql
-- ============================================================
--
-- Switches signup/login from Supabase Auth email+password (which was
-- hitting the built-in email sender's rate limit) to a name + 4-digit
-- PIN flow, matching the Earlyverse Lesson Planner app's UX.
--
-- Security model: is_profiles.id still equals auth.users.id, but that
-- auth.users row is now a "synthetic" account (fake internal email,
-- random password) created by the is-signup Edge Function using the
-- service role key — no email is ever sent. After a name+PIN match,
-- the is-login Edge Function signs that synthetic account in and hands
-- the browser a real Supabase session, so auth.uid() and every existing
-- RLS policy on is_profiles / is_curricula / etc keep working exactly
-- as before.
--
-- pin_hash / synthetic credentials live in a SEPARATE table with RLS
-- enabled and no policies at all, so only the service-role key (used
-- only inside the Edge Functions, never shipped to the browser) can
-- ever read or write them — a plain `select *` from the app can never
-- accidentally expose them the way a same-table column would.

create table if not exists is_profile_secrets (
  id                  uuid primary key references is_profiles(id) on delete cascade,
  pin_hash            text not null,
  synthetic_email     text not null,
  synthetic_password  text not null,
  created_at          timestamptz default now()
);

alter table is_profile_secrets enable row level security;
-- Intentionally no policies: default-deny for anon/authenticated.
-- Only the service role (Edge Functions) can read/write this table.
