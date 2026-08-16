-- ============================================================
-- Holistify Islamic Studies App — Textbooks migration
-- Run this in Supabase SQL Editor
-- ============================================================
--
-- Lets facilitators upload a textbook (PDF, with real per-page text via
-- PDF.js, or docx/txt as a single page) against a curriculum, then link
-- each chapter to a page range within it. The generator pulls just that
-- page range's text as reference content and can cite the page numbers
-- in the generated lesson plan.

create table if not exists is_textbooks (
  id             uuid primary key default gen_random_uuid(),
  curriculum_id  uuid references is_curricula(id) on delete cascade,
  title          text not null,
  pages          jsonb not null default '[]', -- [{page:1,text:"..."}, ...]
  page_count     int default 0,
  created_by     uuid references is_profiles(id) on delete set null,
  created_at     timestamptz default now()
);

alter table is_textbooks enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='is_textbooks' and policyname='is_textbooks_select') then
    create policy "is_textbooks_select" on is_textbooks for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_textbooks' and policyname='is_textbooks_write') then
    create policy "is_textbooks_write" on is_textbooks for all to authenticated using (is_facilitator()) with check (is_facilitator());
  end if;
end $$;

alter table is_curriculum_chapters
  add column if not exists textbook_id  uuid references is_textbooks(id) on delete set null,
  add column if not exists page_start   int,
  add column if not exists page_end     int;
