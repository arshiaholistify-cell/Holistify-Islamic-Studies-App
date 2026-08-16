-- ============================================================
-- Holistify Islamic Studies App — Lesson duration migration
-- Run this in Supabase SQL Editor
-- ============================================================

alter table is_lesson_plans
  add column if not exists duration text default '';
