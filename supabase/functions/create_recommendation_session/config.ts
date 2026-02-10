
// supabase/functions/create_recommendation_session/config.ts

export const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
export const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
export const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY")!;
export const OMDB_API_KEY = Deno.env.get("OMDB_API_KEY")!;

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

export const HISTORY_WINDOW_DAYS = 120;
export const MAX_HISTORY_FETCH = 300;
export const CANDIDATES_COUNT = 12;
export const FINAL_COUNT = 5;
export const TOPUP_MAX_ATTEMPTS = 1;
export const NOTES_MAX = 10;
export const GENRES_MAX = 10;
export const API_TIMEOUT_MS = 5000;
