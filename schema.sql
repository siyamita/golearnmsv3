-- GoLearnMS production database foundation for Supabase PostgreSQL.
-- Apply only in a new Supabase project after reviewing it. This is a schema/RLS baseline;
-- it does not connect the standalone index.html demo to Supabase.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (length(trim(full_name)) between 1 and 100),
  username text not null unique check (username ~ '^[A-Za-z0-9._-]{3,30}$'),
  email text not null unique,
  base_role text not null check (base_role in ('guru','siswa')),
  is_admin boolean not null default false,
  is_superadmin boolean not null default false,
  blocked boolean not null default false,
  institution text not null default '',
  nis text,
  nip text,
  cohort text,
  bio text not null default '',
  description text not null default '',
  avatar_path text,
  must_change_password boolean not null default false,
  last_login_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint superadmin_must_be_admin check (not is_superadmin or is_admin)
);
create unique index if not exists profiles_username_lower_uidx on public.profiles (lower(username));
create unique index if not exists profiles_email_lower_uidx on public.profiles (lower(email));

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 150),
  description text not null default '',
  join_code text not null unique check (join_code ~ '^[A-Za-z0-9-]{4,20}$'),
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.class_members (
  class_id uuid not null references public.classes(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete restrict,
  joined_at timestamptz not null default now(),
  primary key (class_id, student_id)
);

create table if not exists public.learning_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 180),
  description text not null default '',
  session_date date,
  sort_order integer not null default 1 check (sort_order > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.learning_materials (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.learning_sessions(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 180),
  material_type text not null check (material_type in ('file','link','embed')),
  storage_path text,
  external_url text,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint material_source_matches_type check (
    (material_type = 'file' and storage_path is not null and external_url is null) or
    (material_type in ('link','embed') and external_url is not null)
  )
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  session_id uuid references public.learning_sessions(id) on delete set null,
  title text not null check (length(trim(title)) between 1 and 180),
  instructions text not null,
  attachment_path text,
  attachment_url text,
  deadline_at timestamptz not null,
  status text not null default 'published' check (status in ('draft','published','closed')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete restrict,
  answer_text text not null default '',
  answer_url text,
  storage_path text,
  submitted_at timestamptz not null default now(),
  score numeric(5,2) check (score is null or score between 0 and 100),
  feedback text not null default '',
  graded_by uuid references public.profiles(id) on delete set null,
  graded_at timestamptz,
  unique (assignment_id, student_id),
  constraint submission_has_content check (length(trim(answer_text)) > 0 or answer_url is not null or storage_path is not null)
);

create table if not exists public.attendance_meetings (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  meeting_number integer not null check (meeting_number > 0),
  title text not null check (length(trim(title)) between 1 and 180),
  material_note text not null default '',
  meeting_date date not null,
  meeting_time time not null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (class_id, meeting_number)
);

create table if not exists public.attendance_records (
  meeting_id uuid not null references public.attendance_meetings(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete restrict,
  status text not null check (status in ('Hadir','Tidak Hadir','Izin','Sakit')),
  updated_by uuid not null references public.profiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  primary key (meeting_id, student_id)
);

create table if not exists public.visit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_at_event text not null check (role_at_event in ('admin','guru','siswa')),
  action text not null default 'page_view',
  occurred_at timestamptz not null default now()
);
create index if not exists visit_events_occurred_idx on public.visit_events(occurred_at desc);
create index if not exists visit_events_user_idx on public.visit_events(user_id, occurred_at desc);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (length(trim(body)) between 1 and 3000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists support_messages_thread_idx on public.support_messages(thread_id, created_at);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'Percakapan baru',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  content text not null check (length(content) <= 20000),
  provider text,
  token_count integer check (token_count is null or token_count >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.system_logs (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  severity text not null check (severity in ('info','warning','error','critical')),
  module text not null,
  summary text not null check (length(summary) <= 1000),
  status text not null default 'baru' check (status in ('baru','ditangani','selesai')),
  handled_by uuid references public.profiles(id) on delete set null,
  handled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  safe_details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists classes_updated_at on public.classes;
create trigger classes_updated_at before update on public.classes for each row execute function public.set_updated_at();
drop trigger if exists sessions_updated_at on public.learning_sessions;
create trigger sessions_updated_at before update on public.learning_sessions for each row execute function public.set_updated_at();
drop trigger if exists assignments_updated_at on public.assignments;
create trigger assignments_updated_at before update on public.assignments for each row execute function public.set_updated_at();
drop trigger if exists ai_conversations_updated_at on public.ai_conversations;
create trigger ai_conversations_updated_at before update on public.ai_conversations for each row execute function public.set_updated_at();

-- New profiles receive only a safe base role from auth metadata; admin flags are never client-set.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare safe_role text;
begin
  safe_role := case when new.raw_user_meta_data->>'base_role' = 'guru' then 'guru' else 'siswa' end;
  insert into public.profiles(id, full_name, username, email, base_role, institution)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), 'Pengguna Baru'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'username'), ''), 'user_' || substr(new.id::text,1,8)),
    lower(new.email),
    safe_role,
    coalesce(new.raw_user_meta_data->>'institution','')
  );
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.is_account_active()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and blocked = false and must_change_password = false);
$$;
create or replace function public.current_base_role()
returns text language sql stable security definer set search_path = public as $$
  select base_role from public.profiles where id = auth.uid() and blocked = false and must_change_password = false limit 1;
$$;
create or replace function public.has_admin_access()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and is_admin = true and blocked = false and must_change_password = false);
$$;
create or replace function public.is_superadmin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and is_superadmin = true and is_admin = true and blocked = false and must_change_password = false);
$$;
create or replace function public.is_class_teacher(p_class_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.classes where id = p_class_id and teacher_id = auth.uid()) and public.is_account_active();
$$;
create or replace function public.is_class_member(p_class_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.class_members where class_id = p_class_id and student_id = auth.uid()) and public.is_account_active();
$$;
create or replace function public.assignment_class_id(p_assignment_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select class_id from public.assignments where id = p_assignment_id;
$$;
create or replace function public.meeting_class_id(p_meeting_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select class_id from public.attendance_meetings where id = p_meeting_id;
$$;

-- RLS: enabled on all application tables.
alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.class_members enable row level security;
alter table public.learning_sessions enable row level security;
alter table public.learning_materials enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.attendance_meetings enable row level security;
alter table public.attendance_records enable row level security;
alter table public.visit_events enable row level security;
alter table public.support_messages enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.system_logs enable row level security;
alter table public.audit_events enable row level security;

-- PROFILE: safe user profile fields only; role and blocked flags are managed with privileged RPC.
create policy "profiles_read_self_or_admin" on public.profiles for select to authenticated
  using ((id = auth.uid() and blocked = false) or public.has_admin_access());
create policy "profiles_update_self" on public.profiles for update to authenticated
  using (id = auth.uid() and blocked = false) with check (id = auth.uid() and blocked = false);
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name, username, institution, nis, nip, cohort, bio, description, avatar_path, updated_at) on public.profiles to authenticated;

-- Classes and membership.
create policy "classes_read_authorized" on public.classes for select to authenticated
  using (public.is_account_active() and (public.has_admin_access() or teacher_id = auth.uid() or public.is_class_member(id)));
create policy "classes_teacher_insert" on public.classes for insert to authenticated
  with check (teacher_id = auth.uid() and public.current_base_role() = 'guru' and public.is_account_active());
create policy "classes_teacher_update" on public.classes for update to authenticated
  using (public.is_account_active() and teacher_id = auth.uid()) with check (public.is_account_active() and teacher_id = auth.uid());
create policy "classes_teacher_delete" on public.classes for delete to authenticated
  using (public.is_account_active() and teacher_id = auth.uid());
create policy "members_read_authorized" on public.class_members for select to authenticated
  using (public.is_account_active() and (student_id = auth.uid() or public.is_class_teacher(class_id) or public.has_admin_access()));
create policy "teacher_manage_members" on public.class_members for all to authenticated
  using (public.is_account_active() and public.is_class_teacher(class_id))
  with check (public.is_account_active() and public.is_class_teacher(class_id));

-- Joining by code is server-side and never trusts a class id supplied by the browser.
create or replace function public.join_class_by_code(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'Autentikasi diperlukan'; end if;
  if public.current_base_role() <> 'siswa' then raise exception 'Hanya siswa yang dapat bergabung'; end if;
  select id into target_id from public.classes where upper(join_code)=upper(trim(p_code)) and is_open limit 1;
  if target_id is null then raise exception 'Kode kelas tidak valid atau pendaftaran ditutup'; end if;
  insert into public.class_members(class_id,student_id) values(target_id,auth.uid()) on conflict do nothing;
  return target_id;
end; $$;
revoke all on function public.join_class_by_code(text) from public, anon;
grant execute on function public.join_class_by_code(text) to authenticated;

-- Sessions, materials, and assignments.
create policy "sessions_read_member" on public.learning_sessions for select to authenticated
  using (public.is_account_active() and (public.has_admin_access() or public.is_class_teacher(class_id) or public.is_class_member(class_id)));
create policy "sessions_teacher_write" on public.learning_sessions for all to authenticated
  using (public.is_account_active() and public.is_class_teacher(class_id)) with check (public.is_account_active() and public.is_class_teacher(class_id));
create policy "materials_read_member" on public.learning_materials for select to authenticated
  using (public.has_admin_access() or exists(select 1 from public.learning_sessions s where s.id=session_id and (public.is_class_teacher(s.class_id) or public.is_class_member(s.class_id))));
create policy "materials_teacher_write" on public.learning_materials for all to authenticated
  using (public.is_account_active() and created_by=auth.uid() and exists(select 1 from public.learning_sessions s where s.id=session_id and public.is_class_teacher(s.class_id)))
  with check (public.is_account_active() and created_by=auth.uid() and exists(select 1 from public.learning_sessions s where s.id=session_id and public.is_class_teacher(s.class_id)));
create policy "assignments_read_member" on public.assignments for select to authenticated
  using (public.is_account_active() and (public.has_admin_access() or public.is_class_teacher(class_id) or public.is_class_member(class_id)));
create policy "assignments_teacher_write" on public.assignments for all to authenticated
  using (public.is_account_active() and public.is_class_teacher(class_id)) with check (public.is_account_active() and public.is_class_teacher(class_id));

-- Submissions: scores are written through grade_submission(), not directly by clients.
create policy "submissions_read_owner_teacher_admin" on public.submissions for select to authenticated
  using (public.is_account_active() and (student_id=auth.uid() or public.is_class_teacher(public.assignment_class_id(assignment_id)) or public.has_admin_access()));
create policy "students_insert_own_submission" on public.submissions for insert to authenticated
  with check (public.is_account_active() and student_id=auth.uid() and public.current_base_role()='siswa' and public.is_class_member(public.assignment_class_id(assignment_id)));
create policy "students_update_own_ungraded_submission" on public.submissions for update to authenticated
  using (public.is_account_active() and student_id=auth.uid() and score is null) with check (public.is_account_active() and student_id=auth.uid() and score is null);
grant select, insert on public.submissions to authenticated;
grant update (answer_text, answer_url, storage_path) on public.submissions to authenticated;
create or replace function public.grade_submission(p_submission_id uuid,p_score numeric,p_feedback text)
returns void language plpgsql security definer set search_path = public as $$
declare class_owner uuid;
begin
  if p_score < 0 or p_score > 100 then raise exception 'Nilai harus 0 sampai 100'; end if;
  select c.teacher_id into class_owner from public.submissions s join public.assignments a on a.id=s.assignment_id join public.classes c on c.id=a.class_id where s.id=p_submission_id;
  if class_owner is null or class_owner<>auth.uid() then raise exception 'Tidak berwenang menilai tugas ini'; end if;
  update public.submissions set score=p_score,feedback=left(coalesce(p_feedback,''),5000),graded_by=auth.uid(),graded_at=now() where id=p_submission_id;
end; $$;
revoke all on function public.grade_submission(uuid,numeric,text) from public, anon;
grant execute on function public.grade_submission(uuid,numeric,text) to authenticated;

-- Teacher-only attendance writes. Students receive read-only access to their own records.
create policy "attendance_meetings_read_member" on public.attendance_meetings for select to authenticated
  using (public.is_account_active() and (public.has_admin_access() or public.is_class_teacher(class_id) or public.is_class_member(class_id)));
create policy "attendance_meetings_teacher_write" on public.attendance_meetings for all to authenticated
  using (public.is_account_active() and public.is_class_teacher(class_id)) with check (public.is_account_active() and public.is_class_teacher(class_id));
create policy "attendance_records_read_own_teacher_admin" on public.attendance_records for select to authenticated
  using (public.is_account_active() and (student_id=auth.uid() or public.is_class_teacher(public.meeting_class_id(meeting_id)) or public.has_admin_access()));
create or replace function public.set_attendance(p_meeting_id uuid,p_student_id uuid,p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if p_status not in ('Hadir','Tidak Hadir','Izin','Sakit') then raise exception 'Status presensi tidak valid'; end if;
  cid := public.meeting_class_id(p_meeting_id);
  if cid is null or not public.is_class_teacher(cid) then raise exception 'Tidak berwenang mengubah presensi'; end if;
  if not exists(select 1 from public.class_members where class_id=cid and student_id=p_student_id) then raise exception 'Siswa bukan peserta kelas'; end if;
  insert into public.attendance_records(meeting_id,student_id,status,updated_by,updated_at) values(p_meeting_id,p_student_id,p_status,auth.uid(),now())
  on conflict(meeting_id,student_id) do update set status=excluded.status,updated_by=excluded.updated_by,updated_at=now();
end; $$;
revoke all on function public.set_attendance(uuid,uuid,text) from public, anon;
grant execute on function public.set_attendance(uuid,uuid,text) to authenticated;

-- Visit events may only be written for the signed-in user; query access is admin-only.
create policy "visits_admin_read" on public.visit_events for select to authenticated using (public.has_admin_access());
create or replace function public.record_visit(p_role text,p_action text default 'page_view')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_account_active() then raise exception 'Autentikasi diperlukan'; end if;
  if p_role not in ('admin','guru','siswa') then raise exception 'Peran tidak valid'; end if;
  if p_role='admin' and not public.has_admin_access() then raise exception 'Akses admin diperlukan'; end if;
  insert into public.visit_events(user_id,role_at_event,action) values(auth.uid(),p_role,left(coalesce(p_action,'page_view'),100));
  update public.profiles set last_seen_at=now(),last_login_at=case when p_action='login' then now() else last_login_at end where id=auth.uid();
end; $$;
revoke all on function public.record_visit(text,text) from public, anon;
grant execute on function public.record_visit(text,text) to authenticated;

-- Support threads are private to their owner; admin can read all messages.
create policy "support_read_owner_admin" on public.support_messages for select to authenticated
  using (public.is_account_active() and (user_id=auth.uid() or public.has_admin_access()));
create policy "support_user_insert_own" on public.support_messages for insert to authenticated
  with check (public.is_account_active() and sender_id=auth.uid() and user_id=auth.uid());
create or replace function public.reply_support_message(p_user_id uuid,p_thread_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if not public.has_admin_access() then raise exception 'Akses admin diperlukan'; end if;
  if length(trim(coalesce(p_body,''))) not between 1 and 3000 then raise exception 'Pesan tidak valid'; end if;
  insert into public.support_messages(thread_id,user_id,sender_id,body) values(p_thread_id,p_user_id,auth.uid(),trim(p_body)) returning id into new_id;
  return new_id;
end; $$;
revoke all on function public.reply_support_message(uuid,uuid,text) from public, anon;
grant execute on function public.reply_support_message(uuid,uuid,text) to authenticated;

-- AI history belongs to the conversation owner. Calls to a provider must occur in a server API route.
create policy "ai_conversations_owner_admin_read" on public.ai_conversations for select to authenticated
  using (public.is_account_active() and (user_id=auth.uid() or public.has_admin_access()));
create policy "ai_conversations_owner_insert" on public.ai_conversations for insert to authenticated
  with check (public.is_account_active() and user_id=auth.uid());
create policy "ai_conversations_owner_update" on public.ai_conversations for update to authenticated
  using (user_id=auth.uid()) with check (public.is_account_active() and user_id=auth.uid());
create policy "ai_messages_owner_read" on public.ai_messages for select to authenticated
  using (public.is_account_active() and exists(select 1 from public.ai_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or public.has_admin_access())));
create policy "ai_messages_owner_insert_user" on public.ai_messages for insert to authenticated
  with check (public.is_account_active() and role='user' and exists(select 1 from public.ai_conversations c where c.id=conversation_id and c.user_id=auth.uid()));

-- System logs/audit can only be read by admins. Writes should originate from trusted server code.
create policy "system_logs_admin_read" on public.system_logs for select to authenticated using (public.has_admin_access());
create policy "system_logs_superadmin_update" on public.system_logs for update to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());
create policy "audit_admin_read" on public.audit_events for select to authenticated using (public.has_admin_access());

-- Explicit table grants support the RLS rules above. There are no public/anon data grants.
revoke all on public.classes, public.class_members, public.learning_sessions, public.learning_materials,
  public.assignments, public.attendance_meetings, public.attendance_records, public.visit_events,
  public.support_messages, public.ai_conversations, public.ai_messages, public.system_logs,
  public.audit_events from anon;
grant select, insert, update, delete on public.classes to authenticated;
grant select, insert, update, delete on public.class_members to authenticated;
grant select, insert, update, delete on public.learning_sessions to authenticated;
grant select, insert, delete on public.learning_materials to authenticated;
grant select, insert, update, delete on public.assignments to authenticated;
grant select, insert, update, delete on public.attendance_meetings to authenticated;
grant select on public.attendance_records to authenticated;
grant select on public.visit_events to authenticated;
grant select, insert on public.support_messages to authenticated;
grant select, insert, update on public.ai_conversations to authenticated;
grant select, insert on public.ai_messages to authenticated;
grant select, update on public.system_logs to authenticated;
grant select on public.audit_events to authenticated;

-- Admin promotion. Bootstrap first superadmin through a trusted server-side script using SUPABASE_SERVICE_ROLE_KEY.
create or replace function public.set_admin_role(p_target_user uuid,p_make_admin boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin dapat mengubah peran admin'; end if;
  if p_target_user=auth.uid() then raise exception 'Superadmin tidak dapat mengubah perannya sendiri melalui fungsi ini'; end if;
  if exists(select 1 from public.profiles where id=p_target_user and is_superadmin) then raise exception 'Akun superadmin dikelola melalui prosedur khusus'; end if;
  update public.profiles set is_admin=p_make_admin,is_superadmin=false,updated_at=now() where id=p_target_user;
  if not found then raise exception 'Profil pengguna tidak ditemukan'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,safe_details)
  values(auth.uid(),case when p_make_admin then 'grant_admin' else 'revoke_admin' end,'profile',p_target_user::text,jsonb_build_object('is_admin',p_make_admin));
end; $$;
revoke all on function public.set_admin_role(uuid,boolean) from public, anon;
grant execute on function public.set_admin_role(uuid,boolean) to authenticated;

create or replace function public.set_user_blocked(p_target_user uuid,p_blocked boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin dapat mengubah status blokir'; end if;
  if p_target_user=auth.uid() then raise exception 'Superadmin tidak dapat memblokir akunnya sendiri'; end if;
  if exists(select 1 from public.profiles where id=p_target_user and is_superadmin) then raise exception 'Akun superadmin tidak dapat diblokir melalui fungsi ini'; end if;
  update public.profiles set blocked=p_blocked,updated_at=now() where id=p_target_user;
  if not found then raise exception 'Profil pengguna tidak ditemukan'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,safe_details)
  values(auth.uid(),case when p_blocked then 'block_user' else 'unblock_user' end,'profile',p_target_user::text,jsonb_build_object('blocked',p_blocked));
end; $$;
revoke all on function public.set_user_blocked(uuid,boolean) from public, anon;
grant execute on function public.set_user_blocked(uuid,boolean) to authenticated;

-- Revoke broad default table privileges created by prior setup steps where possible.
revoke all on public.system_logs from anon;
revoke all on public.audit_events from anon;

-- Limited class roster fields avoid exposing private profile data to classmates.
create or replace function public.get_class_roster(p_class_id uuid)
returns table(profile_id uuid, full_name text, username text, institution text, base_role text, avatar_path text, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_account_active() then raise exception 'Akun tidak aktif'; end if;
  if not (public.has_admin_access() or public.is_class_teacher(p_class_id) or public.is_class_member(p_class_id)) then
    raise exception 'Tidak berwenang melihat daftar peserta kelas';
  end if;
  return query
    select p.id,p.full_name,p.username,p.institution,p.base_role,p.avatar_path,cm.joined_at
      from public.class_members cm join public.profiles p on p.id=cm.student_id
      where cm.class_id=p_class_id and p.blocked=false
    union all
    select p.id,p.full_name,p.username,p.institution,p.base_role,p.avatar_path,null::timestamptz
      from public.classes c join public.profiles p on p.id=c.teacher_id
      where c.id=p_class_id and p.blocked=false;
end; $$;
revoke all on function public.get_class_roster(uuid) from public, anon;
grant execute on function public.get_class_roster(uuid) to authenticated;

-- Leaderboard is recomputed from source submissions; clients cannot submit their own points.
create or replace function public.get_class_leaderboard(p_class_id uuid)
returns table(student_id uuid, average_score numeric, average_speed_points numeric, submissions_count bigint, graded_count bigint, final_score numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_account_active() then raise exception 'Akun tidak aktif'; end if;
  if not (public.has_admin_access() or public.is_class_teacher(p_class_id) or public.is_class_member(p_class_id)) then
    raise exception 'Tidak berwenang melihat leaderboard kelas';
  end if;
  return query
    with ranked_submissions as (
      select s.id as submission_id,s.student_id,s.score,
        rank() over(partition by s.assignment_id order by s.submitted_at asc) as rank_no,
        count(*) over(partition by s.assignment_id) as total_submissions
      from public.submissions s join public.assignments a on a.id=s.assignment_id
      where a.class_id=p_class_id and s.submitted_at is not null
    ), points as (
      select rs.submission_id,rs.student_id,rs.score,
        case when rs.total_submissions=1 then 100::numeric
          else greatest(10::numeric,least(100::numeric,
            100::numeric-((rs.rank_no-1)::numeric/(rs.total_submissions-1)::numeric)*90::numeric))
        end as speed_points
      from ranked_submissions rs
    ), summary as (
      select cm.student_id,
        avg(p.score) filter (where p.score is not null) as avg_score,
        avg(p.speed_points) as avg_speed,
        count(p.submission_id) as submission_count,
        count(p.score) as graded_count
      from public.class_members cm left join points p on p.student_id=cm.student_id
      where cm.class_id=p_class_id group by cm.student_id
    )
    select s.student_id,round(s.avg_score,2),round(s.avg_speed,2),s.submission_count,s.graded_count,
      round(coalesce(s.avg_score,0)*0.7+coalesce(s.avg_speed,0)*0.3,2)
    from summary s order by 6 desc,s.student_id;
end; $$;
revoke all on function public.get_class_leaderboard(uuid) from public, anon;
grant execute on function public.get_class_leaderboard(uuid) to authenticated;
