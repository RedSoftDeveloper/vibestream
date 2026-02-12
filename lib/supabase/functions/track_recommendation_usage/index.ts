// supabase/functions/track_recommendation_usage/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type TrackUsageBody = {
  profile_id?: string;
  session_id?: string;
  recommendations_used?: number;
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(JSON.stringify({ error: "Supabase env not configured" }), {
        status: 500,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = (await req.json()) as TrackUsageBody;
    const profileId = body.profile_id;
    const sessionId = body.session_id;
    const recommendationsUsed = body.recommendations_used;

    if (!profileId || !sessionId || recommendationsUsed === undefined || recommendationsUsed === null) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields",
          required: ["profile_id", "session_id", "recommendations_used"],
        }),
        { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } },
      );
    }

    if (!Number.isFinite(recommendationsUsed) || recommendationsUsed < 0) {
      return new Response(JSON.stringify({ error: "recommendations_used must be a non-negative number" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const { data, error } = await supabase.rpc("increment_daily_recommendation_usage", {
      p_profile_id: profileId,
      p_session_id: sessionId,
      p_recommendations_count: Math.floor(recommendationsUsed),
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message, code: error.code, details: error.details, hint: error.hint }),
        { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } },
      );
    }

    return new Response(JSON.stringify({ ok: true, data }), {
      status: 200,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  }
});
