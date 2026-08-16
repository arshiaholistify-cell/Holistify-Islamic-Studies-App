-- ============================================================
-- Holistify Islamic Studies App — Assignments, Targets & Implementation migration
-- Run this in Supabase SQL Editor
-- ============================================================

create table if not exists is_plan_assignments (
  id                  uuid primary key default gen_random_uuid(),
  lesson_plan_id      uuid references is_lesson_plans(id) on delete cascade,
  class_name          text not null,
  assigned_date       date default current_date,
  due_date            date,
  status              text default 'assigned' check (status in ('assigned','implemented','missed')),
  implemented_at      timestamptz,
  outcomes_achieved   jsonb default '[]', -- [{outcome:"...", achieved:true}]
  notes               text default '',
  created_by          uuid references is_profiles(id) on delete set null,
  created_at          timestamptz default now()
);

create table if not exists is_targets (
  id            uuid primary key default gen_random_uuid(),
  curriculum_id uuid references is_curricula(id) on delete set null,
  chapter_id    uuid references is_curriculum_chapters(id) on delete set null,
  class_name    text not null,
  title         text not null,
  target_date   date,
  status        text default 'active' check (status in ('active','achieved','missed')),
  notes         text default '',
  created_by    uuid references is_profiles(id) on delete set null,
  created_at    timestamptz default now()
);

alter table is_plan_assignments enable row level security;
alter table is_targets enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='is_plan_assignments' and policyname='is_plan_assignments_select') then
    create policy "is_plan_assignments_select" on is_plan_assignments for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_plan_assignments' and policyname='is_plan_assignments_write') then
    create policy "is_plan_assignments_write" on is_plan_assignments for all to authenticated using (is_facilitator()) with check (is_facilitator());
  end if;

  if not exists (select 1 from pg_policies where tablename='is_targets' and policyname='is_targets_select') then
    create policy "is_targets_select" on is_targets for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_targets' and policyname='is_targets_write') then
    create policy "is_targets_write" on is_targets for all to authenticated using (is_facilitator()) with check (is_facilitator());
  end if;
end $$;
