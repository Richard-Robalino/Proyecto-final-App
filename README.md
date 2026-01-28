# TecniGO — Propuesta 1 (Servicios Técnicos a Domicilio)
**Stack:** Flutter + Supabase (Auth, Postgres, Storage, Edge Functions) + OpenStreetMap

Este repositorio contiene TODO lo necesario para ejecutar la **Propuesta 1** del documento:
- Registro diferenciado (Cliente / Técnico)
- Verificación de técnicos por certificaciones
- Perfil técnico (tarifa base, radio cobertura, especialidades, bio)
- Portafolio con fotos (trabajos previos)
- Geolocalización + Mapa OpenStreetMap:
  - Cliente ve técnicos cercanos (radio configurable)
  - Técnico ve solicitudes cercanas (radio configurable)
  - Ruta OSM (OSRM) para ir al cliente cuando el trabajo está asignado
- Flujo completo:
  - Cliente crea solicitud
  - Técnico envía cotización
  - Cliente acepta una cotización
  - Técnico actualiza estado: en camino → en progreso → completado
  - Reseñas bidireccionales (cliente ↔ técnico)
- ⭐ Extra para “impresionar”: **Asistente IA** (Edge Function `ai_diagnose`)
  - Sugiere categoría y urgencia
  - Genera resumen + preguntas de aclaración + advertencias

> Nota: La Propuesta 2 no está incluida porque **tú harás solo la Propuesta 1**.

---

## 1) Backend (Supabase)

### 1.1 Crear proyecto
1. Crea un proyecto en Supabase.
2. Ve a **SQL Editor**.

### 1.2 Ejecutar el esquema
En SQL Editor, ejecuta en este orden:

1) `supabase/schema.sql`  
2) `supabase/storage.sql`

Con esto se crean:
- Tablas, enums, triggers, funciones, RLS (seguridad)
- Categorías iniciales
- Buckets y políticas para Storage

### 1.3 Storage (Buckets)
Se crean (si ejecutaste `storage.sql`):
- `avatars` (público)
- `request_photos` (público en demo)
- `portfolio` (público)
- `certifications` (lectura solo autenticados)

> Para demo de examen, dejarlos públicos simplifica MUCHO (sin Signed URLs).  
> Si quieres modo “producción real”, se puede endurecer políticas y usar signed urls.

### 1.4 Auth
En Supabase → **Authentication → Providers**:
- Email habilitado.
- Para demo rápida: desactiva “Confirm email” o usa cuentas ya confirmadas.

### 1.5 Edge Function (Asistente IA)
Esta función se llama desde Flutter y vive en:
- `supabase/functions/ai_diagnose/index.ts`

**Deploy con Supabase CLI:**
```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase functions deploy ai_diagnose
```

**Opcional (IA real con OpenAI):**
En Supabase → Settings → Edge Functions → Secrets:
- `OPENAI_API_KEY` = tu key
- `OPENAI_MODEL` = `gpt-4o-mini` (o el que tengas)

Si NO pones `OPENAI_API_KEY`, igual funciona con modo heurístico (sin IA externa).

---

## 2) App Flutter

### 2.1 Requisitos
- Flutter instalado (SDK estable)
- Android Studio / VS Code
- Emulador o celular con GPS

### 2.2 Configurar variables de entorno
En `app/`:
1) Copia `.env.example` a `.env`
2) Coloca tus credenciales:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

### 2.3 Instalar dependencias
```bash
cd app
flutter pub get
```

### 2.4 Ejecutar
```bash
flutter run
```

> La app solicita permisos de ubicación (GPS) para mapa y distancias.

---

## 3) Demo recomendada (para el inge)
1) Registrarte como **Cliente**:
   - Crear solicitud
   - Usar **Asistente IA**
2) Registrarte como **Técnico**:
   - En perfil:
     - Editar tarifa base + radio + bio
     - Agregar especialidades
     - Subir certificación
     - Subir 1–2 fotos al portafolio
3) (Admin rápido) Aprobar al técnico en Supabase:
   - SQL Editor:
   ```sql
   update technician_profiles
   set verification_status = 'approved'
   where id = 'UUID_DEL_TECNICO';

   update technician_certifications
   set status = 'approved'
   where technician_id = 'UUID_DEL_TECNICO';
   ```
4) Volver a la app técnico:
   - Ver solicitudes cercanas
   - Enviar cotización
5) Volver a la app cliente:
   - Ver cotizaciones, aceptar una
6) Técnico:
   - Ver ruta OSM, marcar estados (en camino → en progreso → completado)
7) Cliente:
   - Calificar técnico
8) Técnico:
   - Calificar cliente (cuando ya está completado)
9) Estado final: `rated`

---

## 4) Estructura del proyecto

- `supabase/schema.sql` → DB completo (tablas + RLS + triggers + RPCs)
- `supabase/storage.sql` → buckets + políticas de storage
- `supabase/functions/ai_diagnose/` → Edge Function IA
- `app/` → Flutter app

---

## 5) Notas importantes
- Para que los técnicos puedan cotizar, deben estar `verification_status='approved'`.
- El flujo de estados está controlado por RPCs y RLS:
  - Cliente puede cancelar (`cancelled`)
  - Técnico solo puede avanzar estados si tiene el trabajo asignado
- Las reseñas se permiten solo cuando el request está `completed`.
- Para producción, se recomienda:
  - Bucket `request_photos` privado + signed urls
  - Rate limiting en Edge Functions
  - Moderación básica de contenido

---

Si necesitas que lo dejemos con **notificaciones push** (FCM) o **chat** cliente-técnico (real-time), también se puede agregar como mejora extra.
