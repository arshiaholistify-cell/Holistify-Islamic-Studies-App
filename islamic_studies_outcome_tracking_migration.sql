-- ============================================================
-- Holistify Islamic Studies App — Submissions & Outcome Tracking migration
-- Run this in Supabase SQL Editor
-- ============================================================

alter table is_plan_assignments
  add column if not exists submissions jsonb default '[]'; -- [{student_id, student_name, submitted, submitted_at}]

create table if not exists is_outcome_tracking (
  id                uuid primary key default gen_random_uuid(),
  student_id        uuid references is_profiles(id) on delete cascade,
  lesson_plan_id    uuid references is_lesson_plans(id) on delete cascade,
  chapter_id        uuid references is_curriculum_chapters(id) on delete set null,
  learning_outcome  text not null,
  achieved          boolean not null,
  marked_by         uuid references is_profiles(id) on delete set null,
  marked_at         timestamptz default now(),
  unique(student_id, lesson_plan_id, learning_outcome)
);

alter table is_outcome_tracking enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='is_outcome_tracking' and policyname='is_outcome_tracking_select') then
    create policy "is_outcome_tracking_select" on is_outcome_tracking for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_outcome_tracking' and policyname='is_outcome_tracking_write') then
    create policy "is_outcome_tracking_write" on is_outcome_tracking for all to authenticated using (is_facilitator()) with check (is_facilitator());
  end if;
end $$;
