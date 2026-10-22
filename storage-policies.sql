-- Optional private Storage bucket setup for GoLearnMS.
-- File paths are validated by policies:
--   golearn-materials: <class_uuid>/<filename>
--   golearn-submissions: <assignment_uuid>/<student_uuid>/<filename>
--   golearn-avatars: <profile_uuid>/<filename>
-- Review your MIME allowlist and quota before applying in production.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('golearn-materials','golearn-materials',false,52428800,array[
    'application/pdf','image/png','image/jpeg','image/webp','text/plain','video/mp4','video/webm',
    'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]),
  ('golearn-submissions','golearn-submissions',false,52428800,array[
    'application/pdf','image/png','image/jpeg','image/webp','text/plain','video/mp4','video/webm',
    'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]),
  ('golearn-avatars','golearn-avatars',false,1048576,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

-- Material objects can only be read by a class member/teacher/admin and written by the class teacher.
drop policy if exists "golearn_materials_select_authorized" on storage.objects;
create policy "golearn_materials_select_authorized" on storage.objects for select to authenticated
using (
  bucket_id='golearn-materials' and public.is_account_active() and
  (public.has_admin_access() or public.is_class_teacher(((storage.foldername(name))[1])::uuid)
   or public.is_class_member(((storage.foldername(name))[1])::uuid))
);
drop policy if exists "golearn_materials_teacher_insert" on storage.objects;
create policy "golearn_materials_teacher_insert" on storage.objects for insert to authenticated
with check (
  bucket_id='golearn-materials' and public.is_account_active() and
  public.is_class_teacher(((storage.foldername(name))[1])::uuid)
);
drop policy if exists "golearn_materials_teacher_update" on storage.objects;
create policy "golearn_materials_teacher_update" on storage.objects for update to authenticated
using (bucket_id='golearn-materials' and public.is_account_active() and public.is_class_teacher(((storage.foldername(name))[1])::uuid))
with check (bucket_id='golearn-materials' and public.is_account_active() and public.is_class_teacher(((storage.foldername(name))[1])::uuid));
drop policy if exists "golearn_materials_teacher_delete" on storage.objects;
create policy "golearn_materials_teacher_delete" on storage.objects for delete to authenticated
using (bucket_id='golearn-materials' and public.is_account_active() and public.is_class_teacher(((storage.foldername(name))[1])::uuid));

-- A student sees their own submission objects; their class teacher and admins can inspect them.
drop policy if exists "golearn_submissions_select_authorized" on storage.objects;
create policy "golearn_submissions_select_authorized" on storage.objects for select to authenticated
using (
  bucket_id='golearn-submissions' and public.is_account_active() and
  (public.has_admin_access() or (storage.foldername(name))[2]=auth.uid()::text or
   public.is_class_teacher(public.assignment_class_id(((storage.foldername(name))[1])::uuid)))
);
drop policy if exists "golearn_submissions_student_insert" on storage.objects;
create policy "golearn_submissions_student_insert" on storage.objects for insert to authenticated
with check (
  bucket_id='golearn-submissions' and public.is_account_active() and
  (storage.foldername(name))[2]=auth.uid()::text and
  public.is_class_member(public.assignment_class_id(((storage.foldername(name))[1])::uuid))
);
drop policy if exists "golearn_submissions_student_update" on storage.objects;
create policy "golearn_submissions_student_update" on storage.objects for update to authenticated
using (bucket_id='golearn-submissions' and public.is_account_active() and (storage.foldername(name))[2]=auth.uid()::text)
with check (bucket_id='golearn-submissions' and public.is_account_active() and (storage.foldername(name))[2]=auth.uid()::text);
drop policy if exists "golearn_submissions_student_delete" on storage.objects;
create policy "golearn_submissions_student_delete" on storage.objects for delete to authenticated
using (bucket_id='golearn-submissions' and public.is_account_active() and (storage.foldername(name))[2]=auth.uid()::text);

-- Private avatars: owner/admin can read directly. Other authorized views should use short-lived signed URLs from server code.
drop policy if exists "golearn_avatar_select_owner_admin" on storage.objects;
create policy "golearn_avatar_select_owner_admin" on storage.objects for select to authenticated
using (bucket_id='golearn-avatars' and public.is_account_active() and ((storage.foldername(name))[1]=auth.uid()::text or public.has_admin_access()));
drop policy if exists "golearn_avatar_insert_owner" on storage.objects;
create policy "golearn_avatar_insert_owner" on storage.objects for insert to authenticated
with check (bucket_id='golearn-avatars' and public.is_account_active() and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "golearn_avatar_update_owner" on storage.objects;
create policy "golearn_avatar_update_owner" on storage.objects for update to authenticated
using (bucket_id='golearn-avatars' and public.is_account_active() and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='golearn-avatars' and public.is_account_active() and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "golearn_avatar_delete_owner" on storage.objects;
create policy "golearn_avatar_delete_owner" on storage.objects for delete to authenticated
using (bucket_id='golearn-avatars' and public.is_account_active() and (storage.foldername(name))[1]=auth.uid()::text);
