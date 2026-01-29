-- =========================================================
-- CONFIGURACIÓN ADICIONAL PARA ADMINISTRADORES
-- Ejecuta esto después del schema principal
-- =========================================================

-- 1) Crear usuario admin inicial (ajusta el email)
-- IMPORTANTE: Primero debes crear el usuario en Supabase Auth Dashboard
-- Luego ejecuta esto para darle rol de admin:

-- Ejemplo (reemplaza con tu UUID de admin):
-- update public.profiles
-- set role = 'admin'
-- where id = 'TU-UUID-AQUI';

-- 2) Función helper para promover usuario a admin
create or replace function public.promote_to_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  -- Solo ejecutable por super admin o desde SQL directo
  select au.id into v_user_id
  from auth.users au
  where au.email = p_email;

  if v_user_id is null then
    raise exception 'User not found with email: %', p_email;
  end if;

  update public.profiles
  set role = 'admin'
  where id = v_user_id;

  raise notice 'User % promoted to admin', p_email;
end;
$$;

-- Ejemplo de uso (ejecutar manualmente):
-- select public.promote_to_admin('admin@ejemplo.com');

-- 3) Dashboard Stats (vista rápida para el admin)
create or replace view public.admin_dashboard_stats as
select
  (select count(*) from public.service_requests where status = 'requested') as requested_count,
  (select count(*) from public.service_requests where status = 'accepted') as accepted_count,
  (select count(*) from public.service_requests where status = 'in_progress') as in_progress_count,
  (select count(*) from public.service_requests where status = 'completed') as completed_count,
  (select count(*) from public.technician_profiles where verification_status = 'pending') as pending_verifications,
  (select count(*) from public.profiles where role = 'client') as total_clients,
  (select count(*) from public.profiles where role = 'technician') as total_technicians,
  (select count(*) from public.reviews) as total_reviews;

-- 4) Función para obtener estadísticas completas
create or replace function public.admin_get_dashboard_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'requests', jsonb_build_object(
      'requested', (select count(*) from public.service_requests where status = 'requested'),
      'accepted', (select count(*) from public.service_requests where status = 'accepted'),
      'in_progress', (select count(*) from public.service_requests where status = 'in_progress'),
      'completed', (select count(*) from public.service_requests where status = 'completed')
    ),
    'pending_verifications', (select count(*) from public.technician_profiles where verification_status = 'pending'),
    'users', jsonb_build_object(
      'clients', (select count(*) from public.profiles where role = 'client'),
      'technicians', (select count(*) from public.profiles where role = 'technician'),
      'admins', (select count(*) from public.profiles where role = 'admin')
    ),
    'reviews', (select count(*) from public.reviews)
  );
$$;

-- =========================================================
-- INSTRUCCIONES DE USO:
-- 1. Ejecuta primero schema.sql
-- 2. Luego ejecuta este archivo
-- 3. Crea un usuario en Supabase Dashboard
-- 4. Ejecuta: select public.promote_to_admin('tu-email@ejemplo.com');
-- =========================================================
