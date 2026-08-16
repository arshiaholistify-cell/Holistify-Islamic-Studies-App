-- ============================================================
-- Holistify Islamic Studies App — Qur'anic Learning Journey migration
-- Run this in Supabase SQL Editor
-- ============================================================
--
-- Facilitators assign a surah (or ayah range) for memorisation to a
-- class or an individual student. Students listen to the assigned
-- passage (Arabic text + audio from a choice of reciters, pulled live
-- from the free, open api.alquran.cloud service — no key required),
-- then record and submit their own recitation for feedback.
--
-- Audio is recorded client-side as compressed opus/webm at a low
-- bitrate (~32kbps mono) to minimise storage. Recordings are kept for
-- 6 months (`expires_at`); nothing is ever auto-deleted — once a
-- recording passes its expiry date it shows up in the facilitator's
-- "Retention" tab, where a facilitator must explicitly choose to
-- delete it or extend it another 6 months.

create table if not exists is_quran_assignments (
  id            uuid primary key default gen_random_uuid(),
  class_name    text not null,
  student_id    uuid references is_profiles(id) on delete cascade, -- null = whole class
  surah_number  int not null,
  surah_name    text not null,
  ayah_start    int not null default 1,
  ayah_end      int not null,
  reciter       text default 'ar.alafasy',
  due_date      date,
  notes         text default '',
  created_by    uuid references is_profiles(id) on delete set null,
  created_at    timestamptz default now()
);

create table if not exists is_recitations (
  id                     uuid primary key default gen_random_uuid(),
  assignment_id          uuid references is_quran_assignments(id) on delete set null,
  student_id             uuid references is_profiles(id) on delete cascade,
  surah_number           int not null,
  surah_name             text not null,
  ayah_start             int,
  ayah_end               int,
  audio_path             text not null,   -- path inside the quran-recitations storage bucket
  duration_seconds       numeric,
  file_size_bytes         int,
  status                 text default 'pending' check (status in ('pending','reviewed')),
  facilitator_feedback   text default '',
  reviewed_by            uuid references is_profiles(id) on delete set null,
  reviewed_at            timestamptz,
  created_at             timestamptz default now(),
  expires_at             timestamptz default (now() + interval '6 months'),
  retention_extended_at  timestamptz,
  deleted_at             timestamptz
);

alter table is_quran_assignments enable row level security;
alter table is_recitations enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='is_quran_assignments' and policyname='is_quran_assignments_select') then
    create policy "is_quran_assignments_select" on is_quran_assignments for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_quran_assignments' and policyname='is_quran_assignments_write') then
    create policy "is_quran_assignments_write" on is_quran_assignments for all to authenticated using (is_facilitator()) with check (is_facilitator());
  end if;

  if not exists (select 1 from pg_policies where tablename='is_recitations' and policyname='is_recitations_select') then
    create policy "is_recitations_select" on is_recitations for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='is_recitations' and policyname='is_recitations_insert_own') then
    create policy "is_recitations_insert_own" on is_recitations for insert to authenticated with check (student_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='is_recitations' and policyname='is_recitations_update') then
    create policy "is_recitations_update" on is_recitations for update to authenticated using (is_facilitator() or student_id = auth.uid()) with check (is_facilitator() or student_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='is_recitations' and policyname='is_recitations_delete') then
    create policy "is_recitations_delete" on is_recitations for delete to authenticated using (is_facilitator());
  end if;
end $$;

-- ============================================================
-- Storage: private bucket for recitation audio
-- ============================================================

insert into storage.buckets (id, name, public)
values ('quran-recitations', 'quran-recitations', false)
on conflict (id) do nothing;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='objects' and schemaname='storage' and policyname='quran_recitations_student_upload') then
    create policy "quran_recitations_student_upload" on storage.objects for insert to authenticated
      with check (bucket_id = 'quran-recitations' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where tablename='objects' and schemaname='storage' and policyname='quran_recitations_read') then
    create policy "quran_recitations_read" on storage.objects for select to authenticated
      using (bucket_id = 'quran-recitations' and ((storage.foldername(name))[1] = auth.uid()::text or is_facilitator()));
  end if;
  if not exists (select 1 from pg_policies where tablename='objects' and schemaname='storage' and policyname='quran_recitations_delete') then
    create policy "quran_recitations_delete" on storage.objects for delete to authenticated
      using (bucket_id = 'quran-recitations' and is_facilitator());
  end if;
end $$;
