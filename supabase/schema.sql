-- =========================================================
-- TECNIGO / Servicios Técnicos a Domicilio (Supabase)
-- Base de datos + RLS + RPCs + Triggers
-- =========================================================
-- Requisitos cubiertos del documento:
-- - Auth con registro diferenciado (cliente / técnico) + verificación de técnico
-- - Perfiles + portafolio con fotos (Storage)
-- - Cotizaciones: solicitud -> presupuestos -> comparar -> aceptar
-- - Geolocalización: OSM, técnicos cercanos por radio, rutas
-- - Flujo de estados completo
-- - Valoraciones bidireccionales + métricas de confianza
-- Documento: PROYECTO EXAMEN 2 - Desarrollo Apps Móviles
-- =========================================================

-- 0) EXTENSIONES
create extension if not exists pgcrypto;
create extension if not exists postgis;

-- 1) TIPOS (ENUMS)
do $$ begin
  create type public.user_role as enum ('client', 'technician', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.verification_status as enum ('pending', 'approved', 'rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_status as enum (
    'requested',     -- Solicitud
    'quoted',        -- Cotización (al menos 1 presupuesto)
    'accepted',      -- Aceptada
    'on_the_way',    -- En camino
    'in_progress',   -- En progreso
    'completed',     -- Completado
    'rated',         -- Calificado (ambas reseñas)
    'cancelled'      -- Cancelada
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.quote_status as enum ('sent', 'accepted', 'rejected', 'withdrawn');
exception when duplicate_object then null; end $$;

-- 2) HELPERS
create or replace function public.timestamptz_now()
returns timestamptz language sql immutable as $$ select now(); $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 3) TABLAS CORE
-- 3.1 Perfiles base (públicos)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null,
  full_name text not null,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true
);

create trigger if not exists trg_profiles_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

-- 3.2 Perfil privado (teléfono, etc.) — para “detalle pro” y privacidad
create table if not exists public.profile_private (
  id uuid primary key references public.profiles(id) on delete cascade,
  phone text,
  updated_at timestamptz not null default now()
);

create trigger if not exists trg_profile_private_updated_at
before update on public.profile_private
for each row execute procedure public.set_updated_at();

-- 3.3 Técnicos (datos + verificación)
create table if not exists public.technician_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  bio text,
  base_rate numeric(10,2) not null default 0,               -- tarifa base (ej: por hora)
  coverage_radius_km numeric(5,2) not null default 10,      -- radio de cobertura
  verification_status public.verification_status not null default 'pending',
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);

create trigger if not exists trg_technician_profiles_updated_at
before update on public.technician_profiles
for each row execute procedure public.set_updated_at();

-- 3.4 Categorías (plomero, electricista, etc.)
create table if not exists public.service_categories (
  id bigint generated always as identity primary key,
  name text not null unique,
  icon text,
  created_at timestamptz not null default now()
);

-- 3.5 Especialidades (many-to-many)
create table if not exists public.technician_specialties (
  technician_id uuid not null references public.technician_profiles(id) on delete cascade,
  category_id bigint not null references public.service_categories(id) on delete cascade,
  primary key (technician_id, category_id)
);

-- 3.6 Ubicación del técnico (lat/lng + geography generado)
create table if not exists public.technician_locations (
  technician_id uuid primary key references public.technician_profiles(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  location geography(point, 4326) generated always as
    (st_setsrid(st_makepoint(lng, lat), 4326)::geography) stored,
  updated_at timestamptz not null default now()
);

create index if not exists idx_technician_locations_location
on public.technician_locations using gist(location);

-- 3.7 Solicitudes de servicio (cliente)
create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete restrict,
  category_id bigint not null references public.service_categories(id),
  title text not null,
  description text not null,
  address text,
  lat double precision not null,
  lng double precision not null,
  location geography(point, 4326) generated always as
    (st_setsrid(st_makepoint(lng, lat), 4326)::geography) stored,
  scheduled_for timestamptz,
  status public.request_status not null default 'requested',
  accepted_quote_id uuid,
  ai_summary jsonb, -- extra IA (valor agregado)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger if not exists trg_service_requests_updated_at
before update on public.service_requests
for each row execute procedure public.set_updated_at();

create index if not exists idx_service_requests_location
on public.service_requests using gist(location);

create index if not exists idx_service_requests_status
on public.service_requests(status);

-- 3.8 Fotos de solicitud (Storage)
create table if not exists public.request_photos (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  path text not null,
  created_at timestamptz not null default now()
);

-- 3.9 Cotizaciones / Presupuestos
create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  technician_id uuid not null references public.technician_profiles(id) on delete restrict,
  price numeric(10,2) not null,
  estimated_minutes int not null,
  message text,
  status public.quote_status not null default 'sent',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(request_id, technician_id)
);

create trigger if not exists trg_quotes_updated_at
before update on public.quotes
for each row execute procedure public.set_updated_at();

create index if not exists idx_quotes_request_id
on public.quotes(request_id);

-- 3.10 Timeline / Eventos del flujo
create table if not exists public.request_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  status public.request_status not null,
  actor_id uuid references public.profiles(id),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_request_events_request_id
on public.request_events(request_id, created_at);

-- 3.11 Portafolio (técnico)
create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technician_profiles(id) on delete cascade,
  title text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.portfolio_photos (
  id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references public.portfolio_items(id) on delete cascade,
  path text not null,
  created_at timestamptz not null default now()
);

-- 3.12 Certificaciones (técnico) — para verificación
create table if not exists public.technician_certifications (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technician_profiles(id) on delete cascade,
  title text not null,
  issuer text,
  issued_date date,
  file_path text not null,  -- Storage path
  status public.verification_status not null default 'pending',
  reviewer_notes text,
  created_at timestamptz not null default now()
);

-- 3.13 Reseñas bidireccionales
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique(request_id, reviewer_id, reviewee_id)
);

create index if not exists idx_reviews_reviewee
on public.reviews(reviewee_id);

-- 4) SEEDS (categorías por defecto)
insert into public.service_categories(name, icon)
values
 ('Plomería', 'plumbing'),
 ('Electricidad', 'bolt'),
 ('Cerrajería', 'lock'),
 ('Albañilería', 'construction'),
 ('Aire Acondicionado', 'ac_unit'),
 ('Reparación Electrodomésticos', 'home_repair_service')
on conflict (name) do nothing;

-- 5) VISTAS / MÉTRICAS (confianza)
create or replace view public.technician_metrics as
select
  tp.id as technician_id,
  coalesce(avg(r.rating), 0)::numeric(3,2) as avg_rating,
  coalesce(count(r.id), 0)::int as total_reviews,
  coalesce(count(sr.id) filter (where sr.status in ('completed','rated')), 0)::int as completed_jobs
from public.technician_profiles tp
left join public.reviews r
  on r.reviewee_id = tp.id
left join public.quotes q
  on q.technician_id = tp.id and q.status = 'accepted'
left join public.service_requests sr
  on sr.accepted_quote_id = q.id
group by tp.id;

-- 6) TRIGGERS AUTOMÁTICOS PARA FLUJO
-- 6.1 Cuando llega la primera cotización, pasar request a 'quoted'
create or replace function public.on_quote_insert_set_request_quoted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.service_requests
  set status = 'quoted'
  where id = new.request_id
    and status = 'requested';

  insert into public.request_events(request_id, status, actor_id, note)
  values (new.request_id, 'quoted', new.technician_id, 'Primera cotización recibida');

  return new;
end;
$$;

drop trigger if exists trg_quote_insert_set_request_quoted on public.quotes;
create trigger trg_quote_insert_set_request_quoted
after insert on public.quotes
for each row execute procedure public.on_quote_insert_set_request_quoted();

-- 6.2 Cuando existen 2 reseñas (cliente->técnico y técnico->cliente), marcar request como 'rated'
create or replace function public.on_review_insert_maybe_set_rated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.reviews
  where request_id = new.request_id;

  if v_count >= 2 then
    update public.service_requests
    set status = 'rated'
    where id = new.request_id
      and status = 'completed';

    insert into public.request_events(request_id, status, actor_id, note)
    values (new.request_id, 'rated', new.reviewer_id, 'Servicio calificado por ambas partes');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_review_insert_set_rated on public.reviews;
create trigger trg_review_insert_set_rated
after insert on public.reviews
for each row execute procedure public.on_review_insert_maybe_set_rated();

-- 7) RPCs (operaciones atómicas / seguras)

-- 7.1 Aceptar una cotización (cliente)
create or replace function public.accept_quote(p_quote_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request_id uuid;
  v_client_id uuid;
begin
  select q.request_id into v_request_id
  from public.quotes q
  where q.id = p_quote_id;

  if v_request_id is null then
    raise exception 'Quote not found';
  end if;

  select sr.client_id into v_client_id
  from public.service_requests sr
  where sr.id = v_request_id;

  if v_client_id <> auth.uid() then
    raise exception 'Not allowed (only the owner client can accept)';
  end if;

  -- Marcar la cotización elegida como accepted y el resto como rejected
  update public.quotes
  set status = case when id = p_quote_id then 'accepted' else 'rejected' end,
      updated_at = now()
  where request_id = v_request_id
    and status in ('sent');

  -- Actualizar request
  update public.service_requests
  set accepted_quote_id = p_quote_id,
      status = 'accepted',
      updated_at = now()
  where id = v_request_id;

  insert into public.request_events(request_id, status, actor_id, note)
  values (v_request_id, 'accepted', auth.uid(), 'Cotización aceptada');
end;
$$;

-- 7.2 Actualizar el estado (cliente cancela / técnico avanza)
create or replace function public.set_request_status(
  p_request_id uuid,
  p_new_status public.request_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.service_requests%rowtype;
  v_tech_id uuid;
  v_actor uuid := auth.uid();
begin
  select * into v_req from public.service_requests where id = p_request_id;

  if v_req.id is null then
    raise exception 'Request not found';
  end if;

  -- Técnico asignado (si existe)
  select q.technician_id into v_tech_id
  from public.quotes q
  where q.id = v_req.accepted_quote_id;

  -- Reglas de transición (mínimas)
  if p_new_status = 'cancelled' then
    if v_actor <> v_req.client_id then
      raise exception 'Only client can cancel';
    end if;
    if v_req.status not in ('requested','quoted','accepted') then
      raise exception 'Cannot cancel at this stage';
    end if;

  elsif p_new_status in ('on_the_way','in_progress','completed') then
    if v_actor <> v_tech_id then
      raise exception 'Only assigned technician can advance the job';
    end if;

    if p_new_status = 'on_the_way' and v_req.status <> 'accepted' then
      raise exception 'Invalid transition';
    end if;
    if p_new_status = 'in_progress' and v_req.status <> 'on_the_way' then
      raise exception 'Invalid transition';
    end if;
    if p_new_status = 'completed' and v_req.status <> 'in_progress' then
      raise exception 'Invalid transition';
    end if;

  else
    raise exception 'Unsupported status transition';
  end if;

  update public.service_requests
  set status = p_new_status,
      updated_at = now()
  where id = p_request_id;

  insert into public.request_events(request_id, status, actor_id, note)
  values (p_request_id, p_new_status, v_actor, p_note);
end;
$$;

-- 7.3 Obtener técnicos cercanos (para mapa del cliente)
create or replace function public.get_nearby_technicians(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision,
  p_category_id bigint default null
)
returns table (
  technician_id uuid,
  full_name text,
  avatar_path text,
  base_rate numeric,
  verification_status public.verification_status,
  avg_rating numeric,
  total_reviews int,
  lat double precision,
  lng double precision,
  distance_km double precision
)
language sql
stable
as $$
  with tech as (
    select
      tp.id as technician_id,
      p.full_name,
      p.avatar_path,
      tp.base_rate,
      tp.verification_status,
      tl.lat,
      tl.lng,
      (st_distance(tl.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography) / 1000.0) as distance_km
    from public.technician_profiles tp
    join public.profiles p on p.id = tp.id
    join public.technician_locations tl on tl.technician_id = tp.id
    where tp.verification_status = 'approved'
      and st_dwithin(tl.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography, p_radius_km * 1000.0)
      and (p_category_id is null or exists (
        select 1
        from public.technician_specialties ts
        where ts.technician_id = tp.id
          and ts.category_id = p_category_id
      ))
  )
  select
    t.technician_id,
    t.full_name,
    t.avatar_path,
    t.base_rate,
    t.verification_status,
    coalesce(m.avg_rating, 0)::numeric(3,2) as avg_rating,
    coalesce(m.total_reviews, 0)::int as total_reviews,
    t.lat,
    t.lng,
    t.distance_km
  from tech t
  left join (
    select reviewee_id as technician_id,
           avg(rating)::numeric(3,2) as avg_rating,
           count(*)::int as total_reviews
    from public.reviews
    group by reviewee_id
  ) m on m.technician_id = t.technician_id
  order by t.distance_km asc;
$$;

-- 7.4 Obtener solicitudes cercanas (para tablero del técnico)
create or replace function public.get_nearby_requests(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision,
  p_category_id bigint default null
)
returns table (
  request_id uuid,
  title text,
  description text,
  category_id bigint,
  client_id uuid,
  lat double precision,
  lng double precision,
  distance_km double precision,
  created_at timestamptz
)
language sql
stable
as $$
  select
    sr.id as request_id,
    sr.title,
    sr.description,
    sr.category_id,
    sr.client_id,
    sr.lat,
    sr.lng,
    (st_distance(sr.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography) / 1000.0) as distance_km,
    sr.created_at
  from public.service_requests sr
  where sr.status in ('requested','quoted')
    and st_dwithin(sr.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography, p_radius_km * 1000.0)
    and (p_category_id is null or sr.category_id = p_category_id)
  order by distance_km asc, sr.created_at desc;
$$;

-- 8) AUTH: Trigger para crear perfil al registrarse
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_full_name text;
begin
  v_role := coalesce(new.raw_user_meta_data->>'role', 'client');
  v_full_name := coalesce(new.raw_user_meta_data->>'full_name', '');

  insert into public.profiles(id, role, full_name)
  values (new.id, v_role::public.user_role, v_full_name)
  on conflict (id) do nothing;

  insert into public.profile_private(id, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'phone', null))
  on conflict (id) do nothing;

  if v_role = 'technician' then
    insert into public.technician_profiles(id)
    values (new.id)
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- 9) RLS (Row Level Security)
alter table public.profiles enable row level security;
alter table public.profile_private enable row level security;
alter table public.technician_profiles enable row level security;
alter table public.service_categories enable row level security;
alter table public.technician_specialties enable row level security;
alter table public.technician_locations enable row level security;
alter table public.service_requests enable row level security;
alter table public.request_photos enable row level security;
alter table public.quotes enable row level security;
alter table public.request_events enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.portfolio_photos enable row level security;
alter table public.technician_certifications enable row level security;
alter table public.reviews enable row level security;

-- 9.1 PROFILES
drop policy if exists "profiles_select_all_auth" on public.profiles;
create policy "profiles_select_all_auth"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- 9.2 PROFILE_PRIVATE (solo dueño)
drop policy if exists "profile_private_select_own" on public.profile_private;
create policy "profile_private_select_own"
on public.profile_private for select
to authenticated
using (auth.uid() = id);

drop policy if exists "profile_private_upsert_own" on public.profile_private;
create policy "profile_private_upsert_own"
on public.profile_private for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "profile_private_update_own" on public.profile_private;
create policy "profile_private_update_own"
on public.profile_private for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- 9.3 TECHNICIAN_PROFILES
drop policy if exists "technician_profiles_select_all_auth" on public.technician_profiles;
create policy "technician_profiles_select_all_auth"
on public.technician_profiles for select
to authenticated
using (true);

drop policy if exists "technician_profiles_update_own" on public.technician_profiles;
create policy "technician_profiles_update_own"
on public.technician_profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- 9.4 SERVICE_CATEGORIES (solo lectura)
drop policy if exists "service_categories_read_all" on public.service_categories;
create policy "service_categories_read_all"
on public.service_categories for select
to authenticated
using (true);

-- 9.5 TECHNICIAN_SPECIALTIES
drop policy if exists "tech_specs_select_all" on public.technician_specialties;
create policy "tech_specs_select_all"
on public.technician_specialties for select
to authenticated
using (true);

drop policy if exists "tech_specs_manage_own" on public.technician_specialties;
create policy "tech_specs_manage_own"
on public.technician_specialties for insert
to authenticated
with check (auth.uid() = technician_id);

drop policy if exists "tech_specs_delete_own" on public.technician_specialties;
create policy "tech_specs_delete_own"
on public.technician_specialties for delete
to authenticated
using (auth.uid() = technician_id);

-- 9.6 TECHNICIAN_LOCATIONS
drop policy if exists "tech_locations_select_all" on public.technician_locations;
create policy "tech_locations_select_all"
on public.technician_locations for select
to authenticated
using (true);

drop policy if exists "tech_locations_upsert_own" on public.technician_locations;
create policy "tech_locations_upsert_own"
on public.technician_locations for insert
to authenticated
with check (auth.uid() = technician_id);

drop policy if exists "tech_locations_update_own" on public.technician_locations;
create policy "tech_locations_update_own"
on public.technician_locations for update
to authenticated
using (auth.uid() = technician_id)
with check (auth.uid() = technician_id);

-- 9.7 SERVICE_REQUESTS
drop policy if exists "service_requests_insert_client" on public.service_requests;
create policy "service_requests_insert_client"
on public.service_requests for insert
to authenticated
with check (auth.uid() = client_id);

-- cliente ve sus solicitudes
drop policy if exists "service_requests_select_client_own" on public.service_requests;
create policy "service_requests_select_client_own"
on public.service_requests for select
to authenticated
using (auth.uid() = client_id);

-- técnico ve solicitudes cercanas (solo requested/quoted)
drop policy if exists "service_requests_select_tech_nearby" on public.service_requests;
create policy "service_requests_select_tech_nearby"
on public.service_requests for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'technician'
  )
  and status in ('requested','quoted')
);

-- técnico y cliente ven solicitudes asignadas (accepted+)
drop policy if exists "service_requests_select_assigned" on public.service_requests;
create policy "service_requests_select_assigned"
on public.service_requests for select
to authenticated
using (
  auth.uid() = client_id
  or exists (
    select 1
    from public.quotes q
    where q.id = accepted_quote_id
      and q.technician_id = auth.uid()
  )
);

-- cliente puede cancelar/editar mientras no esté completado (simplificado)
drop policy if exists "service_requests_update_client_limited" on public.service_requests;
create policy "service_requests_update_client_limited"
on public.service_requests for update
to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id and status in ('requested','quoted','cancelled'));

-- 9.8 REQUEST_PHOTOS (participantes)
drop policy if exists "request_photos_insert_client" on public.request_photos;
create policy "request_photos_insert_client"
on public.request_photos for insert
to authenticated
with check (
  exists (
    select 1 from public.service_requests sr
    where sr.id = request_id and sr.client_id = auth.uid()
  )
);

drop policy if exists "request_photos_select_participants" on public.request_photos;
create policy "request_photos_select_participants"
on public.request_photos for select
to authenticated
using (
  exists (
    select 1 from public.service_requests sr
    left join public.quotes q on q.id = sr.accepted_quote_id
    where sr.id = request_id
      and (sr.client_id = auth.uid() or q.technician_id = auth.uid())
  )
);

-- 9.9 QUOTES
drop policy if exists "quotes_select_client_own_requests" on public.quotes;
create policy "quotes_select_client_own_requests"
on public.quotes for select
to authenticated
using (
  exists (
    select 1 from public.service_requests sr
    where sr.id = request_id and sr.client_id = auth.uid()
  )
);

drop policy if exists "quotes_select_tech_own" on public.quotes;
create policy "quotes_select_tech_own"
on public.quotes for select
to authenticated
using (technician_id = auth.uid());

-- técnico inserta cotización si está aprobado
drop policy if exists "quotes_insert_tech_approved" on public.quotes;
create policy "quotes_insert_tech_approved"
on public.quotes for insert
to authenticated
with check (
  technician_id = auth.uid()
  and exists (
    select 1 from public.technician_profiles tp
    where tp.id = auth.uid()
      and tp.verification_status = 'approved'
  )
);

-- técnico puede retirar su cotización
drop policy if exists "quotes_update_tech_own" on public.quotes;
create policy "quotes_update_tech_own"
on public.quotes for update
to authenticated
using (technician_id = auth.uid())
with check (technician_id = auth.uid());

-- 9.10 REQUEST_EVENTS (solo lectura para participantes)
drop policy if exists "request_events_select_participants" on public.request_events;
create policy "request_events_select_participants"
on public.request_events for select
to authenticated
using (
  exists (
    select 1 from public.service_requests sr
    left join public.quotes q on q.id = sr.accepted_quote_id
    where sr.id = request_id
      and (sr.client_id = auth.uid() or q.technician_id = auth.uid())
  )
);

-- 9.11 PORTFOLIO
drop policy if exists "portfolio_select_all_auth" on public.portfolio_items;
create policy "portfolio_select_all_auth"
on public.portfolio_items for select
to authenticated
using (true);

drop policy if exists "portfolio_manage_own" on public.portfolio_items;
create policy "portfolio_manage_own"
on public.portfolio_items for insert
to authenticated
with check (technician_id = auth.uid());

drop policy if exists "portfolio_update_own" on public.portfolio_items;
create policy "portfolio_update_own"
on public.portfolio_items for update
to authenticated
using (technician_id = auth.uid())
with check (technician_id = auth.uid());

drop policy if exists "portfolio_delete_own" on public.portfolio_items;
create policy "portfolio_delete_own"
on public.portfolio_items for delete
to authenticated
using (technician_id = auth.uid());

-- portfolio photos
drop policy if exists "portfolio_photos_select_all_auth" on public.portfolio_photos;
create policy "portfolio_photos_select_all_auth"
on public.portfolio_photos for select
to authenticated
using (true);

drop policy if exists "portfolio_photos_insert_own" on public.portfolio_photos;
create policy "portfolio_photos_insert_own"
on public.portfolio_photos for insert
to authenticated
with check (
  exists (
    select 1 from public.portfolio_items pi
    where pi.id = portfolio_id and pi.technician_id = auth.uid()
  )
);

-- 9.12 CERTIFICATIONS
drop policy if exists "certifications_select_own" on public.technician_certifications;
create policy "certifications_select_own"
on public.technician_certifications for select
to authenticated
using (technician_id = auth.uid());

drop policy if exists "certifications_insert_own" on public.technician_certifications;
create policy "certifications_insert_own"
on public.technician_certifications for insert
to authenticated
with check (technician_id = auth.uid());

drop policy if exists "certifications_update_own" on public.technician_certifications;
create policy "certifications_update_own"
on public.technician_certifications for update
to authenticated
using (technician_id = auth.uid())
with check (technician_id = auth.uid());

-- 9.13 REVIEWS (participantes)
drop policy if exists "reviews_select_all_auth" on public.reviews;
create policy "reviews_select_all_auth"
on public.reviews for select
to authenticated
using (true);

drop policy if exists "reviews_insert_participants" on public.reviews;
create policy "reviews_insert_participants"
on public.reviews for insert
to authenticated
with check (
  reviewer_id = auth.uid()
  and exists (
    select 1
    from public.service_requests sr
    left join public.quotes q on q.id = sr.accepted_quote_id
    where sr.id = request_id
      and sr.status = 'completed'
      and (
        -- cliente califica al técnico
        (sr.client_id = auth.uid() and reviewee_id = q.technician_id)
        -- técnico califica al cliente
        or (q.technician_id = auth.uid() and reviewee_id = sr.client_id)
      )
  )
);

-- 10) FUNCIONES ADMIN

-- 10.1 Contar solicitudes por estado
create or replace function public.admin_count_requests_by_status(p_status text)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.service_requests
  where status = p_status::public.request_status;
$$;

-- 10.2 Contar técnicos pendientes de verificación
create or replace function public.admin_count_pending_verifications()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.technician_profiles
  where verification_status = 'pending';
$$;

-- 10.3 Obtener solicitudes por estado con detalles (CORREGIDO)
create or replace function public.admin_get_requests_by_status(p_status text)
returns table (
  id uuid,
  service_type text,
  description text,
  status text,
  created_at timestamptz,
  user_id uuid,
  technician_id uuid,
  client_name text,
  client_email text,
  technician_name text,
  technician_email text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    sr.id,
    sc.name as service_type,
    sr.description,
    sr.status::text,
    sr.created_at,
    sr.client_id as user_id,
    q.technician_id,
    pc.full_name as client_name,
    auc.email as client_email,
    pt.full_name as technician_name,
    aut.email as technician_email
  from public.service_requests sr
  join public.service_categories sc on sc.id = sr.category_id
  join public.profiles pc on pc.id = sr.client_id
  left join auth.users auc on auc.id = sr.client_id
  left join public.quotes q on q.id = sr.accepted_quote_id
  left join public.profiles pt on pt.id = q.technician_id
  left join auth.users aut on aut.id = q.technician_id
  where sr.status = p_status::public.request_status
  order by sr.created_at desc;
$$;

-- 10.4 Obtener técnicos pendientes de verificación
create or replace function public.admin_get_pending_verifications()
returns table (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  role text,
  is_verified boolean,
  experience_years int,
  specialties text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id as user_id,
    p.full_name,
    au.email,
    pp.phone,
    p.role::text,
    false as is_verified,
    0 as experience_years,
    array(
      select sc.name
      from public.technician_specialties ts
      join public.service_categories sc on sc.id = ts.category_id
      where ts.technician_id = p.id
    ) as specialties
  from public.profiles p
  join auth.users au on au.id = p.id
  left join public.profile_private pp on pp.id = p.id
  join public.technician_profiles tp on tp.id = p.id
  where p.role = 'technician'
    and tp.verification_status = 'pending'
  order by p.created_at asc;
$$;

-- 10.5 Aprobar o rechazar técnico
create or replace function public.admin_verify_technician(
  p_user_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Verificar que el usuario actual sea admin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Unauthorized: Only admins can verify technicians';
  end if;

  if p_approve then
    -- Aprobar
    update public.technician_profiles
    set verification_status = 'approved',
        verified_at = now()
    where id = p_user_id;
  else
    -- Rechazar (marcar como rejected o eliminar)
    update public.technician_profiles
    set verification_status = 'rejected'
    where id = p_user_id;
    
    -- Opcional: eliminar usuario completamente
    -- delete from auth.users where id = p_user_id;
  end if;
end;
$$;

-- 10.6 Vista consolidada de usuarios (para admin)
create or replace view public.admin_users_view as
select
  p.id,
  p.role::text,
  p.full_name,
  au.email,
  pp.phone,
  p.created_at,
  p.is_active,
  case
    when p.role = 'technician' then tp.verification_status::text
    else null
  end as verification_status,
  case
    when p.role = 'technician' then (
      select count(*)::int
      from public.service_requests sr
      join public.quotes q on q.id = sr.accepted_quote_id
      where q.technician_id = p.id
        and sr.status in ('completed', 'rated')
    )
    else 0
  end as completed_jobs,
  case
    when p.role = 'technician' then (
      select avg(r.rating)::numeric(3,2)
      from public.reviews r
      where r.reviewee_id = p.id
    )
    else null
  end as avg_rating
from public.profiles p
join auth.users au on au.id = p.id
left join public.profile_private pp on pp.id = p.id
left join public.technician_profiles tp on tp.id = p.id;

-- 11) RLS PARA FUNCIONES ADMIN
-- Las funciones con security definer ya incluyen verificación de permisos internamente

-- Permitir a los admins ver todo
drop policy if exists "admin_full_access_profiles" on public.profiles;
create policy "admin_full_access_profiles"
on public.profiles for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

drop policy if exists "admin_full_access_requests" on public.service_requests;
create policy "admin_full_access_requests"
on public.service_requests for select
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

drop policy if exists "admin_full_access_quotes" on public.quotes;
create policy "admin_full_access_quotes"
on public.quotes for select
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

drop policy if exists "admin_full_access_tech_profiles" on public.technician_profiles;
create policy "admin_full_access_tech_profiles"
on public.technician_profiles for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- ...existing code...
