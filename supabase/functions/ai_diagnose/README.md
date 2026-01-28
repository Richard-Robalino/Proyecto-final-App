# ai_diagnose (Supabase Edge Function)

Esta función agrega un valor extra (IA) al flujo de creación de solicitudes:

- El cliente describe el problema (texto).
- La función devuelve:
  - categoría sugerida
  - urgencia
  - resumen estructurado
  - preguntas de aclaración
  - rango de precio aproximado
  - advertencias de seguridad

## Variables de entorno
- `OPENAI_API_KEY` (opcional)
- `OPENAI_MODEL` (opcional; default: `gpt-4o-mini`)

Si no defines `OPENAI_API_KEY`, la función funciona igual en modo heurístico (sin IA externa).
