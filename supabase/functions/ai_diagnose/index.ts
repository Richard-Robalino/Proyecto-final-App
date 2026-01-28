// supabase/functions/ai_diagnose/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * ✅ Fix VS Code/TypeScript:
 * En proyectos Flutter, TS a veces no reconoce el global Deno (aunque en runtime sí existe).
 * Esta declaración solo es para el editor (no rompe nada en Supabase).
 */
declare const Deno: {
  serve: (
    handler: (req: Request) => Response | Promise<Response>,
  ) => void;
};

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  // ✅ Preflight CORS SIEMPRE 200
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    // ✅ Auth opcional (en demo)
    const REQUIRE_AUTH = false;
    const auth = req.headers.get("authorization") ?? "";
    const hasBearer = auth.toLowerCase().startsWith("bearer ");

    if (REQUIRE_AUTH && !hasBearer) {
      return json({ error: "Unauthorized (missing Bearer token)" }, 401);
    }

    const body = await req.json().catch(() => ({} as Record<string, unknown>));
    const description = String((body as any)?.description ?? "").trim();

    let summary = "";
    let confidence = 0.65;
    let actions: string[] = [];

    if (!description) {
      summary =
        "Describe el problema (equipo, marca/modelo, síntomas) para sugerir un diagnóstico.";
      confidence = 0.4;
      actions = [
        "Escribe el equipo y marca/modelo",
        "Indica qué falla exactamente (no enciende, ruido, fuga, etc.)",
        "Agrega foto/video si es posible",
      ];
    } else {
      const d = description.toLowerCase();

      if (d.includes("no enciende") || d.includes("no prende")) {
        summary =
          "Parece un problema de alimentación eléctrica o fuente (cable, toma, fusible interno o placa).";
        actions = [
          "Prueba otro enchufe/toma eléctrica",
          "Verifica cable y cargador (si aplica)",
          "Si huele a quemado o hubo chispa: NO lo enciendas y solicita técnico",
        ];
      } else if (d.includes("fuga") || d.includes("gotea") || d.includes("agua")) {
        summary =
          "Posible fuga por manguera/sello/empaque. Se recomienda cortar el agua/energía y revisar conexiones.";
        actions = [
          "Cierra la llave de agua (si aplica) y desconecta energía",
          "Revisa mangueras y uniones visibles",
          "Toma fotos de la zona de fuga para el técnico",
        ];
      } else if (d.includes("ruido") || d.includes("vibra")) {
        summary =
          "Puede ser desbalance, pieza floja o desgaste de rodamientos/ventilador. Conviene revisar fijaciones y estado de partes móviles.";
        actions = [
          "Revisa tornillos/soportes y nivelación",
          "Evita usar el equipo si el ruido aumenta",
          "Describe cuándo ocurre (al arrancar, en carga, constante)",
        ];
      } else {
        summary =
          "Diagnóstico preliminar: puede ser una falla común de conexión/consumo/ajuste. Un técnico puede confirmar en sitio con pruebas básicas.";
        actions = [
          "Indica marca/modelo y tiempo de uso",
          "Describe síntomas y cuándo empezó",
          "Adjunta fotos del equipo y del área de instalación",
        ];
      }
    }

    return json({
      ok: true,
      auth_present: hasBearer,
      summary,
      confidence,
      actions,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
