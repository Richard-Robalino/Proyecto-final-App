-- =========================================================
-- STORAGE BUCKETS + POLICIES (Supabase)
-- Ejecuta esto después de crear tu proyecto
-- =========================================================

-- Buckets (puedes crearlos en Dashboard o por SQL)
insert into storage.buckets (id, name, public)
values
 ('avatars', 'avatars', true),
 ('request_photos', 'request_photos', true),
 ('portfolio', 'portfolio', true),
 ('certifications', 'certifications', true)
on conflict (id) do nothing;

-- Políticas para storage.objects
alter table storage.objects enable row level security;

-- ===== AVATARS =====
drop policy if exists "avatars_read_public" on storage.objects;
create policy "avatars_read_public"
on storage.objects for select
to public
using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and name like ('avatars/' || auth.uid() || '%')
);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and name like ('avatars/' || auth.uid() || '%')
)
with check (
  bucket_id = 'avatars'
  and name like ('avatars/' || auth.uid() || '%')
);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and name like ('avatars/' || auth.uid() || '%')
);

-- ===== PORTFOLIO =====
drop policy if exists "portfolio_read_public" on storage.objects;
create policy "portfolio_read_public"
on storage.objects for select
to public
using (bucket_id = 'portfolio');

drop policy if exists "portfolio_insert_own" on storage.objects;
create policy "portfolio_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'portfolio'
  and name like ('portfolio/' || auth.uid() || '/%')
);

drop policy if exists "portfolio_update_own" on storage.objects;
create policy "portfolio_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'portfolio'
  and name like ('portfolio/' || auth.uid() || '/%')
)
with check (
  bucket_id = 'portfolio'
  and name like ('portfolio/' || auth.uid() || '/%')
);

drop policy if exists "portfolio_delete_own" on storage.objects;
create policy "portfolio_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'portfolio'
  and name like ('portfolio/' || auth.uid() || '/%')
);

-- ===== CERTIFICATIONS =====
drop policy if exists "certifications_read_auth" on storage.objects;
create policy "certifications_read_auth"
on storage.objects for select
to authenticated
using (bucket_id = 'certifications');

drop policy if exists "certifications_insert_own" on storage.objects;
create policy "certifications_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'certifications'
  and name like ('certs/' || auth.uid() || '/%')
);

drop policy if exists "certifications_update_own" on storage.objects;
create policy "certifications_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'certifications'
  and name like ('certs/' || auth.uid() || '/%')
)
with check (
  bucket_id = 'certifications'
  and name like ('certs/' || auth.uid() || '/%')
);

drop policy if exists "certifications_delete_own" on storage.objects;
create policy "certifications_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'certifications'
  and name like ('certs/' || auth.uid() || '/%')
);

-- ===== REQUEST PHOTOS =====
drop policy if exists "request_photos_read_auth" on storage.objects;
create policy "request_photos_read_auth"
on storage.objects for select
to authenticated
using (bucket_id = 'request_photos');

drop policy if exists "request_photos_insert_auth" on storage.objects;
create policy "request_photos_insert_auth"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'request_photos'
  and name like 'requests/%'
);

drop policy if exists "request_photos_update_auth" on storage.objects;
create policy "request_photos_update_auth"
on storage.objects for update
to authenticated
using (bucket_id = 'request_photos')
with check (bucket_id = 'request_photos');

drop policy if exists "request_photos_delete_auth" on storage.objects;
create policy "request_photos_delete_auth"
on storage.objects for delete
to authenticated
using (bucket_id = 'request_photos');
