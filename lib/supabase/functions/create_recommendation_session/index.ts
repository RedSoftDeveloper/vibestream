// lib/supabase/functions/create_recommendation_session/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import OpenAI from "npm:openai@4.20.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY")!;
const OMDB_API_KEY = Deno.env.get("OMDB_API_KEY")!;

const openai = new OpenAI({ apiKey: OPENAI_API_KEY });

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, accept",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const SSE_HEADERS = {
  ...CORS_HEADERS,
  "Content-Type": "text/event-stream",
  "Cache-Control": "no-cache",
  "Connection": "keep-alive",
};

const HISTORY_WINDOW_DAYS = 120;
const MAX_HISTORY_FETCH = 300;
const CANDIDATES_COUNT = 12;
const FINAL_COUNT = 5;
const TOPUP_MAX_ATTEMPTS = 1;
const NOTES_MAX = 10;
const GENRES_MAX = 10;
const API_TIMEOUT_MS = 5000;

type SessionType = "onboarding" | "mood" | "quick_match";
type TmdbType = "movie" | "tv";
type InteractionAction =
  | "impression"
  | "open"
  | "play"
  | "complete"
  | "like"
  | "dislike"
  | "skip"
  | "feedback";

type AvailabilityType = "flatrate" | "free" | "ads" | "rent" | "buy";

interface LogContext {
  reqId: string;
  userId?: string | null;
  profileId?: string;
}

interface TmdbSearchResult {
  tmdb_id: number;
  tmdb_type: TmdbType;
  tmdb_title: string;
}

interface WatchProvider {
  provider_id: number;
  name: string;
  logo_url: string | null;
}

interface WatchProviderWithAvailability extends WatchProvider {
  availability_type: AvailabilityType;
}

interface WatchProvidersResult {
  link: string | null;
  providers: WatchProvider[];
  providerAvailability: WatchProviderWithAvailability[];
}

interface MediaTitle {
  id: string;
  tmdb_id: number;
  tmdb_type: TmdbType;
  title: string;
  overview: string | null;
  genres: string[];
  year: number | null;
  runtime_minutes: number | null;
  poster_url: string | null;
  backdrop_url: string | null;
  imdb_id: string | null;
  imdb_rating: number | null;
  age_rating: string | null;
  director: string | null;
  starring: string[] | null;
  raw_tmdb: any;
  raw_omdb: any;
  created_at: string;
  updated_at: string;
}

interface TmdbDetails {
  id: number;
  title?: string;
  name?: string;
  overview?: string;
  genres?: Array<{ id: number; name: string }>;
  release_date?: string;
  first_air_date?: string;
  runtime?: number;
  episode_run_time?: number[];
  poster_path?: string;
  backdrop_path?: string;
  imdb_id?: string;
  external_ids?: { imdb_id?: string };
  credits?: {
    cast?: Array<{ name: string; order: number }>;
    crew?: Array<{ name: string; job: string }>;
  };
  created_by?: Array<{ name: string }>;
}

interface OmdbResponse {
  Response: string;
  imdbRating?: string;
  Rated?: string;
  [key: string]: any;
}

interface OpenAIItem {
  title: string;
  tmdb_type: TmdbType;
  tmdb_search_query: string;
  primary_genres: string[];
  tone_tags: string[];
  reason: string;
  match_score: number;
}

interface OpenAIResponse {
  mood_label: string;
  mood_tags: string[];
  items: OpenAIItem[];
}

interface RecommendationCard {
  title_id: string;
  title: string;
  year: string;
  duration: string;
  genres: string[];
  rating: string;
  age_rating: string;
  quote: string;
  description: string;
  poster_url: string | null;
  match_score: number | null;
  tmdb_type: TmdbType;
  director: string;
  starring: string[];
  watch_provider_link: string | null;
  watch_providers: WatchProvider[];
}

const RequestBodySchema = z.object({
  profile_id: z.string().uuid(),
  session_type: z.enum(["onboarding", "mood", "quick_match"]),
  mood_input: z.record(z.any()).optional().default({}),
  content_types: z.array(z.enum(["movie", "tv"])).optional(),
  stream: z.boolean().optional().default(false),
});

type RequestBody = z.infer<typeof RequestBodySchema>;

function normalizeTitle(s: string): string {
  return (s || "").toLowerCase().replace(/[^a-z0-9\s]/g, " ").replace(/\s+/g, " ").trim();
}

function nowIso(): string {
  return new Date().toISOString();
}

function daysAgoIso(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

function log(ctx: LogContext, msg: string, extra?: unknown): void {
  const ts = new Date().toISOString();
  const base =
    `[create_recommendation_session][${ts}][req:${ctx.reqId}]` +
    (ctx.userId ? `[user:${ctx.userId}]` : "[user:unknown]") +
    (ctx.profileId ? `[profile:${ctx.profileId}]` : "");
  if (extra !== undefined) console.log(base + " " + msg, extra);
  else console.log(base + " " + msg);
}

function parseContentTypes(body: RequestBody): TmdbType[] {
  const raw = body.content_types ?? (body.mood_input as any)?.content_types ?? [];
  const list = Array.isArray(raw) ? raw : [];
  const cleaned = list.map((x: any) => String(x).toLowerCase().trim()).filter((x: string) => x === "movie" || x === "tv") as TmdbType[];
  const unique = Array.from(new Set(cleaned));
  return unique.length > 0 ? unique : ["movie"];
}

function stripCodeFences(s: string): string {
  let out = (s || "").trim();
  if (out.startsWith("```json")) out = out.slice(7).trim();
  else if (out.startsWith("```")) out = out.slice(3).trim();
  if (out.endsWith("```")) out = out.slice(0, -3).trim();
  return out;
}

function extractFirstJsonObject(s: string): string | null {
  const text = stripCodeFences(s);
  const start = text.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (esc) {
      esc = false;
      continue;
    }
    if (ch === "\\") {
      esc = true;
      continue;
    }
    if (ch === `"`) inStr = !inStr;
    if (inStr) continue;
    if (ch === "{") depth++;
    if (ch === "}") depth--;
    if (depth === 0) return text.slice(start, i + 1);
  }
  return null;
}

function getFeedbackWeight(createdAtIso: string): number {
  const ms = Date.now() - new Date(createdAtIso).getTime();
  const days = ms / (24 * 60 * 60 * 1000);
  if (days <= 7) return 1.0;
  if (days <= 30) return 0.5;
  return 0.25;
}

function getNoteFromExtra(extra: any): string | null {
  const s = typeof extra?.feedback_text === "string" ? extra.feedback_text.trim() : "";
  if (s) return s;
  const fallback = typeof extra?.notes === "string" ? extra.notes.trim() : "";
  return fallback || null;
}

function getFeedbackSentiment(action: InteractionAction, rating: number | null, extra: any): "positive" | "negative" | "neutral" {
  const wouldWatchAgain = extra?.would_watch_again === true;
  const quickTags: string[] = Array.isArray(extra?.quick_tags) ? extra.quick_tags.map((x: any) => String(x).toLowerCase()) : [];
  const hasNegativeTag = quickTags.some((t) => t.includes("too slow")) || quickTags.some((t) => t.includes("boring")) || quickTags.some((t) => t.includes("bad"));
  const hasPositiveTag = quickTags.some((t) => t.includes("great")) || quickTags.some((t) => t.includes("amazing")) || quickTags.some((t) => t.includes("excellent"));

  if (rating !== null) {
    if (rating >= 4) return "positive";
    if (rating <= 2) return "negative";
    if (rating === 3) return "neutral";
  }
  if (action === "feedback" && wouldWatchAgain) return "positive";
  if (action === "feedback" && hasNegativeTag) return "negative";
  if (action === "feedback" && hasPositiveTag) return "positive";
  if (action === "like") return "positive";
  if (action === "dislike") return "negative";
  if (action === "skip") return "negative";
  return "neutral";
}

function topKeysByScore(m: Map<string, number>, max: number): string[] {
  return Array.from(m.entries()).sort((a, b) => b[1] - a[1]).slice(0, max).map((x) => x[0]);
}

function topNotes(list: Array<{ text: string; w: number; at: string }>, max: number): string[] {
  return list.sort((a, b) => b.w - a.w).slice(0, max).map((x) => x.text);
}

async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = API_TIMEOUT_MS): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof Error && error.name === "AbortError") throw new Error(`Request timeout after ${timeoutMs}ms: ${url}`);
    throw error;
  }
}

function buildSystemPrompt(
  itemsCount: number,
  allowedTypes: TmdbType[],
  hardExcludedTitles: string[],
  softExcludedTitles: string[],
  positiveSignals: { genres: string[]; notes: string[]; tags: string[] },
  negativeSignals: { genres: string[]; notes: string[]; tags: string[]; titles: string[] },
): string {
  const allowed = allowedTypes.join(", ");
  const hardEx = hardExcludedTitles.slice(0, 120).join(", ");
  const softEx = softExcludedTitles.slice(0, 120).join(", ");
  const likeGenres = positiveSignals.genres.slice(0, GENRES_MAX).join(", ");
  const avoidGenres = negativeSignals.genres.slice(0, GENRES_MAX).join(", ");
  const avoidTitles = negativeSignals.titles.slice(0, 40).join(", ");
  const likeTags = positiveSignals.tags.slice(0, 20).join(", ");
  const avoidTags = negativeSignals.tags.slice(0, 20).join(", ");
  const notes = positiveSignals.notes.concat(negativeSignals.notes).slice(0, NOTES_MAX).join(" | ");

  return `
You are VibeStream's recommendation engine.

Goal:
Generate EXACTLY ${itemsCount} recommendations based on long-term taste + recent feedback + current mood.

USER FEEDBACK SIGNALS:
- User tends to enjoy genres: [${likeGenres || "unknown"}]
- User tends to avoid genres: [${avoidGenres || "unknown"}]
- User tends to enjoy vibes/tags: [${likeTags || "unknown"}]
- User tends to avoid vibes/tags: [${avoidTags || "unknown"}]
- Titles user disliked or reacted negatively to: [${avoidTitles || "none"}]
- Recent feedback notes: [${notes || "none"}]

STRICT RULES:
1) HARD EXCLUDE: NEVER recommend any title in this list: [${hardEx}]
2) SOFT EXCLUDE: Do NOT recommend these exact watched/completed titles: [${softEx}]
3) Do NOT recommend sequels/prequels/spin-offs/remakes of HARD EXCLUDED titles.
4) Each recommendation must be UNIQUE (no duplicates).
5) ONLY use these content types: [${allowed}] (tmdb_type must be one of them).
6) Return ONLY a JSON object, no markdown, no code fences, no commentary.

OUTPUT SCHEMA (exact):
{
  "mood_label": string,
  "mood_tags": string[],
  "items": [
    {
      "title": string,
      "tmdb_type": "movie" | "tv",
      "tmdb_search_query": string,
      "primary_genres": string[],
      "tone_tags": string[],
      "reason": string,
      "match_score": number
    }
  ]
}

Constraints:
- items length must be exactly ${itemsCount}.
- title must be only the name (no year).
- match_score must be integer 70..99.
- primary_genres 1..3, tone_tags 2..5.
`.trim();
}

async function callOpenAI(
  ctx: LogContext,
  promptObj: unknown,
  itemsCount: number,
  allowedTypes: TmdbType[],
  hardExcludedTitles: string[],
  softExcludedTitles: string[],
  positiveSignals: { genres: string[]; notes: string[]; tags: string[] },
  negativeSignals: { genres: string[]; notes: string[]; tags: string[]; titles: string[] },
): Promise<OpenAIResponse> {
  const baseSystem = buildSystemPrompt(itemsCount, allowedTypes, hardExcludedTitles, softExcludedTitles, positiveSignals, negativeSignals);
  const system1 = baseSystem + `\n\nFINAL OUTPUT RULE: Return ONLY the JSON object.`;
  const system2 = baseSystem + `\n\nYOU MUST FIX OUTPUT: Return ONLY valid JSON object matching schema.`;

  async function runOnce(system: string, temperature?: number): Promise<OpenAIResponse> {
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      ...(temperature !== undefined ? { temperature } : {}),
      messages: [
        { role: "system", content: system },
        { role: "user", content: JSON.stringify(promptObj) },
      ],
    });
    const raw = completion.choices[0]?.message?.content?.trim() ?? "";
    log(ctx, "OpenAI raw response (first 500 chars)", raw.slice(0, 500));
    const cleaned = stripCodeFences(raw);
    try {
      return JSON.parse(cleaned) as OpenAIResponse;
    } catch {
      const maybe = extractFirstJsonObject(raw);
      if (!maybe) throw new Error("OpenAI returned non-JSON output");
      return JSON.parse(maybe) as OpenAIResponse;
    }
  }

  log(ctx, `Calling OpenAI for ${itemsCount} candidates`, { allowedTypes, hardExcludedCount: hardExcludedTitles.length, softExcludedCount: softExcludedTitles.length });
  try {
    const payload = await runOnce(system1, 0.8);
    if (!payload || !Array.isArray(payload.items) || payload.items.length !== itemsCount) throw new Error("Invalid items length");
    return payload;
  } catch (e) {
    log(ctx, "OpenAI parse failed, retry once with low temperature", { error: String(e) });
    const payload = await runOnce(system2, 0.2);
    if (!payload || !Array.isArray(payload.items) || payload.items.length !== itemsCount) throw new Error("Invalid items length");
    return payload;
  }
}

async function tmdbSearchOne(ctx: LogContext, searchQuery: string, tmdbType: TmdbType): Promise<TmdbSearchResult | null> {
  const encoded = encodeURIComponent(searchQuery);
  const url = `https://api.themoviedb.org/3/search/${tmdbType}?api_key=${TMDB_API_KEY}&language=en-US&query=${encoded}`;
  try {
    const res = await fetchWithTimeout(url);
    if (!res.ok) {
      const t = await res.text();
      log(ctx, "TMDB search failed", { url, status: res.status, body: t.slice(0, 500) });
      return null;
    }
    const json = await res.json();
    const first = json?.results?.[0];
    if (!first?.id) return null;
    return { tmdb_id: Number(first.id), tmdb_type: tmdbType, tmdb_title: first.title || first.name || searchQuery };
  } catch (error) {
    log(ctx, "TMDB search error", { searchQuery, tmdbType, error: String(error) });
    return null;
  }
}

async function tmdbGetDetails(ctx: LogContext, tmdbId: number, tmdbType: TmdbType): Promise<TmdbDetails | null> {
  const url = `https://api.themoviedb.org/3/${tmdbType}/${tmdbId}?api_key=${TMDB_API_KEY}&language=en-US&append_to_response=credits,external_ids`;
  try {
    const res = await fetchWithTimeout(url);
    if (!res.ok) {
      log(ctx, "TMDB details failed", { tmdbId, tmdbType, status: res.status });
      return null;
    }
    return (await res.json()) as TmdbDetails;
  } catch (error) {
    log(ctx, "TMDB details error", { tmdbId, tmdbType, error: String(error) });
    return null;
  }
}

async function tmdbWatchProviders(ctx: LogContext, tmdbId: number, tmdbType: TmdbType): Promise<any> {
  const url = `https://api.themoviedb.org/3/${tmdbType}/${tmdbId}/watch/providers?api_key=${TMDB_API_KEY}`;
  try {
    const res = await fetchWithTimeout(url);
    if (!res.ok) {
      const t = await res.text();
      log(ctx, "TMDB watch/providers failed", { url, status: res.status, body: t.slice(0, 300) });
      return null;
    }
    return await res.json();
  } catch (error) {
    log(ctx, "TMDB watch providers error", { tmdbId, tmdbType, error: String(error) });
    return null;
  }
}

async function omdbGetDetails(ctx: LogContext, imdbId: string): Promise<OmdbResponse | null> {
  const url = `https://www.omdbapi.com/?apikey=${OMDB_API_KEY}&i=${encodeURIComponent(imdbId)}`;
  try {
    const res = await fetchWithTimeout(url);
    if (!res.ok) return null;
    const json = (await res.json()) as OmdbResponse;
    if (json && json.Response === "True") return json;
    return null;
  } catch (error) {
    log(ctx, "OMDB error", { imdbId, error: String(error) });
    return null;
  }
}

function pickProvidersForRegion(watchJson: any, region: string): WatchProvidersResult {
  const regionData = watchJson?.results?.[region] ?? null;
  if (!regionData) return { link: null, providers: [], providerAvailability: [] };

  const providerAvailability: WatchProviderWithAvailability[] = [];
  const availabilityTypes: Array<{ key: string; type: AvailabilityType }> = [
    { key: "flatrate", type: "flatrate" },
    { key: "free", type: "free" },
    { key: "ads", type: "ads" },
    { key: "rent", type: "rent" },
    { key: "buy", type: "buy" },
  ];

  for (const { key, type } of availabilityTypes) {
    const list = regionData[key];
    if (Array.isArray(list)) {
      for (const p of list) {
        if (p?.provider_id != null && p?.provider_name) {
          providerAvailability.push({
            provider_id: p.provider_id,
            name: p.provider_name,
            logo_url: p.logo_path ? `https://image.tmdb.org/t/p/w92${p.logo_path}` : null,
            availability_type: type,
          });
        }
      }
    }
  }

  const seen = new Set<number>();
  const providers = providerAvailability
    .filter((p) => (seen.has(p.provider_id) ? false : (seen.add(p.provider_id), true)))
    .map(({ provider_id, name, logo_url }) => ({ provider_id, name, logo_url }));

  return { link: regionData.link ?? null, providers, providerAvailability };
}

async function storeStreamingProviders(
  ctx: LogContext,
  supabaseAdmin: any,
  titleId: string,
  providerAvailability: WatchProviderWithAvailability[],
  region: string,
  watchProviderLink: string | null,
): Promise<void> {
  if (providerAvailability.length === 0) return;
  try {
    const uniqueProviders = new Map<number, { tmdb_provider_id: number; name: string; logo_url: string | null }>();
    for (const p of providerAvailability) {
      if (!uniqueProviders.has(p.provider_id)) uniqueProviders.set(p.provider_id, { tmdb_provider_id: p.provider_id, name: p.name, logo_url: p.logo_url });
    }

    const { data: upsertedProviders, error: providerErr } = await supabaseAdmin.from("streaming_providers").upsert(Array.from(uniqueProviders.values()), { onConflict: "tmdb_provider_id", ignoreDuplicates: false }).select("id, tmdb_provider_id");
    if (providerErr) {
      log(ctx, "Error upserting streaming_providers", providerErr);
      return;
    }

    const providerIdMap = new Map<number, string>();
    for (const p of upsertedProviders ?? []) providerIdMap.set(p.tmdb_provider_id, p.id);

    const { error: deleteErr } = await supabaseAdmin.from("title_streaming_availability").delete().eq("title_id", titleId).eq("region", region);
    if (deleteErr) log(ctx, "Error deleting old title_streaming_availability", deleteErr);

    const availabilityRecords = providerAvailability
      .map((p) => ({ title_id: titleId, provider_id: providerIdMap.get(p.provider_id), region, availability_type: p.availability_type, watch_link: watchProviderLink }))
      .filter((r) => r.provider_id != null);

    if (availabilityRecords.length > 0) {
      const { error: insertErr } = await supabaseAdmin.from("title_streaming_availability").insert(availabilityRecords);
      if (insertErr) log(ctx, "Error inserting title_streaming_availability", insertErr);
      else log(ctx, `Stored ${availabilityRecords.length} streaming availability records for title ${titleId}`);
    }
  } catch (err) {
    log(ctx, "Exception in storeStreamingProviders", err);
  }
}

async function getOrCreateMediaTitle(
  ctx: LogContext,
  supabaseAdmin: any,
  tmdbId: number,
  tmdbType: TmdbType,
  fallbackTitle: string,
  userRegion: string,
): Promise<{ mediaTitle: MediaTitle | null; watchProviders: WatchProvidersResult }> {
  const { data: existing, error: existingErr } = await supabaseAdmin.from("media_titles").select("*").eq("tmdb_id", tmdbId).eq("tmdb_type", tmdbType).maybeSingle();
  if (existingErr) log(ctx, "Error checking media_titles cache", existingErr);

  const needsEnrich = !existing || (existing.imdb_rating == null && existing.imdb_id == null) || existing.director == null || existing.starring == null;

  const [details, watchJson] = await Promise.all([
    needsEnrich ? tmdbGetDetails(ctx, tmdbId, tmdbType) : Promise.resolve(null),
    tmdbWatchProviders(ctx, tmdbId, tmdbType),
  ]);

  const watchProviders = watchJson ? pickProvidersForRegion(watchJson, userRegion) : { link: null, providers: [], providerAvailability: [] };
  if (!needsEnrich && existing) return { mediaTitle: existing as MediaTitle, watchProviders };
  if (!details) return { mediaTitle: (existing as MediaTitle) ?? null, watchProviders };

  const imdbId = tmdbType === "movie" ? (details.imdb_id ?? null) : (details.external_ids?.imdb_id ?? null);
  const omdbJson = imdbId ? await omdbGetDetails(ctx, imdbId) : null;

  const imdbRating = omdbJson?.imdbRating && omdbJson.imdbRating !== "N/A" ? Number.parseFloat(omdbJson.imdbRating) : null;
  const ageRating = omdbJson?.Rated && omdbJson.Rated !== "N/A" ? omdbJson.Rated : null;

  const credits = details.credits ?? null;
  const castNames: string[] = Array.isArray(credits?.cast) ? credits.cast.slice(0, 5).map((c: any) => c?.name).filter(Boolean) : [];

  let director: string | null = null;
  if (tmdbType === "movie") {
    const crew = Array.isArray(credits?.crew) ? credits.crew : [];
    director = crew.find((c: any) => c?.job === "Director")?.name ?? null;
  } else {
    const creators = Array.isArray(details.created_by) ? details.created_by : [];
    director = creators.length > 0 ? creators.map((x: any) => x?.name).filter(Boolean).slice(0, 2).join(", ") : null;
  }

  const genres = (details.genres ?? []).map((g: any) => g?.name).filter(Boolean);
  const dateStr = tmdbType === "movie" ? (details.release_date ?? "") : (details.first_air_date ?? "");
  const yearValue = dateStr ? Number.parseInt(String(dateStr).slice(0, 4)) : null;
  const runtime = tmdbType === "movie" ? (details.runtime ?? null) : Array.isArray(details.episode_run_time) ? (details.episode_run_time[0] ?? null) : null;

  const posterBase = "https://image.tmdb.org/t/p/w500";
  const posterUrl = details.poster_path ? posterBase + details.poster_path : null;
  const backdropUrl = details.backdrop_path ? posterBase + details.backdrop_path : null;
  const title = tmdbType === "movie" ? (details.title ?? fallbackTitle) : (details.name ?? fallbackTitle);

  const row = {
    tmdb_id: tmdbId,
    tmdb_type: tmdbType,
    title,
    overview: details.overview ?? null,
    genres,
    year: yearValue,
    runtime_minutes: runtime,
    poster_url: posterUrl,
    backdrop_url: backdropUrl,
    imdb_id: imdbId,
    imdb_rating: imdbRating,
    age_rating: ageRating,
    director,
    starring: castNames.length > 0 ? castNames : null,
    raw_tmdb: details,
    raw_omdb: omdbJson,
    updated_at: nowIso(),
  };

  if (existing) {
    const { data: updated, error: upErr } = await supabaseAdmin.from("media_titles").update(row).eq("id", existing.id).select().single();
    if (upErr) {
      log(ctx, "Error updating existing media_titles", upErr);
      return { mediaTitle: existing as MediaTitle, watchProviders };
    }
    return { mediaTitle: updated as MediaTitle, watchProviders };
  }

  const { data: inserted, error: insertErr } = await supabaseAdmin.from("media_titles").insert({ ...row, created_at: nowIso() }).select().single();
  if (insertErr) {
    log(ctx, "Error inserting media_titles", insertErr);
    const { data: again } = await supabaseAdmin.from("media_titles").select("*").eq("tmdb_id", tmdbId).eq("tmdb_type", tmdbType).maybeSingle();
    return { mediaTitle: (again as MediaTitle) ?? null, watchProviders };
  }
  return { mediaTitle: inserted as MediaTitle, watchProviders };
}

async function getUserRegion(ctx: LogContext, supabaseUser: any, profileId: string): Promise<string> {
  try {
    const { data: profile } = await supabaseUser.from("profiles").select("country_code, user_id").eq("id", profileId).maybeSingle();
    if (profile?.country_code) {
      log(ctx, `Using profile country_code: ${profile.country_code}`);
      return profile.country_code;
    }
    if (profile?.user_id) {
      const { data: appUser } = await supabaseUser.from("app_users").select("region").eq("id", profile.user_id).maybeSingle();
      if (appUser?.region) {
        log(ctx, `Using app_users region: ${appUser.region}`);
        return appUser.region;
      }
    }
    log(ctx, "No region found, defaulting to US");
    return "US";
  } catch (error) {
    log(ctx, "Error getting user region, defaulting to US", error);
    return "US";
  }
}

async function processCandidatesParallel(
  ctx: LogContext,
  items: OpenAIItem[],
  supabaseAdmin: any,
  contentTypes: TmdbType[],
  excludedNormalizedTitles: Set<string>,
  excludedTmdbKeys: Set<string>,
  chosenNorm: Set<string>,
  userRegion: string,
  maxChoose: number,
): Promise<Array<{ item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult }>> {
  const searchPromises = items.map(async (it) => {
    const title = String(it?.title || "").trim();
    if (!title) return null;
    const norm = normalizeTitle(title);
    if (chosenNorm.has(norm) || excludedNormalizedTitles.has(norm)) return null;

    const tmdbTypeRaw = String(it?.tmdb_type || "").toLowerCase().trim();
    const tmdbType: TmdbType | null = tmdbTypeRaw === "movie" || tmdbTypeRaw === "tv" ? (tmdbTypeRaw as TmdbType) : null;
    const typeToUse: TmdbType | null = tmdbType && contentTypes.includes(tmdbType) ? tmdbType : null;
    if (!typeToUse) return null;

    const searchQuery = String(it?.tmdb_search_query || it?.title || "").trim();
    const hit = await tmdbSearchOne(ctx, searchQuery, typeToUse);
    if (!hit) return null;

    const tmdbKey = `${hit.tmdb_type}:${hit.tmdb_id}`;
    if (excludedTmdbKeys.has(tmdbKey)) return null;

    return { item: it, hit, norm, tmdbKey };
  });

  const searchResults = await Promise.all(searchPromises);
  const validSearchResults = searchResults.filter((r) => r !== null) as Array<{ item: OpenAIItem; hit: TmdbSearchResult; norm: string; tmdbKey: string }>;

  const enrichPromises = validSearchResults.slice(0, maxChoose).map(async ({ item, hit, norm, tmdbKey }) => {
    const { mediaTitle, watchProviders } = await getOrCreateMediaTitle(ctx, supabaseAdmin, hit.tmdb_id, hit.tmdb_type, item.title, userRegion);
    if (!mediaTitle) return null;
    excludedNormalizedTitles.add(norm);
    excludedTmdbKeys.add(tmdbKey);
    chosenNorm.add(norm);
    return { item, mediaRow: mediaTitle, watchProviders };
  });

  const enrichResults = await Promise.all(enrichPromises);
  return enrichResults.filter((r) => r !== null) as Array<{ item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult }>;
}

// Sequential processing for streaming - processes one candidate at a time
async function processCandidatesSequential(
  ctx: LogContext,
  items: OpenAIItem[],
  supabaseAdmin: any,
  contentTypes: TmdbType[],
  excludedNormalizedTitles: Set<string>,
  excludedTmdbKeys: Set<string>,
  chosenNorm: Set<string>,
  userRegion: string,
  maxChoose: number,
  onCardReady?: (card: { item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult }, index: number) => void,
): Promise<Array<{ item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult }>> {
  const chosen: Array<{ item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult }> = [];
  let processedCount = 0;

  for (const it of items) {
    if (chosen.length >= maxChoose) break;
    
    const title = String(it?.title || "").trim();
    if (!title) continue;
    
    const norm = normalizeTitle(title);
    if (chosenNorm.has(norm) || excludedNormalizedTitles.has(norm)) continue;

    const tmdbTypeRaw = String(it?.tmdb_type || "").toLowerCase().trim();
    const tmdbType: TmdbType | null = tmdbTypeRaw === "movie" || tmdbTypeRaw === "tv" ? (tmdbTypeRaw as TmdbType) : null;
    const typeToUse: TmdbType | null = tmdbType && contentTypes.includes(tmdbType) ? tmdbType : null;
    if (!typeToUse) continue;

    const searchQuery = String(it?.tmdb_search_query || it?.title || "").trim();
    const hit = await tmdbSearchOne(ctx, searchQuery, typeToUse);
    if (!hit) continue;

    const tmdbKey = `${hit.tmdb_type}:${hit.tmdb_id}`;
    if (excludedTmdbKeys.has(tmdbKey)) continue;

    const { mediaTitle, watchProviders } = await getOrCreateMediaTitle(ctx, supabaseAdmin, hit.tmdb_id, hit.tmdb_type, it.title, userRegion);
    if (!mediaTitle) continue;

    excludedNormalizedTitles.add(norm);
    excludedTmdbKeys.add(tmdbKey);
    chosenNorm.add(norm);

    const result = { item: it, mediaRow: mediaTitle, watchProviders };
    chosen.push(result);

    // Notify callback that a card is ready
    if (onCardReady) {
      onCardReady(result, chosen.length - 1);
    }

    processedCount++;
  }

  return chosen;
}

function buildRecommendationCard(
  chosen: { item: OpenAIItem; mediaRow: MediaTitle; watchProviders: WatchProvidersResult },
): RecommendationCard {
  const t = chosen.mediaRow;
  let duration = "";
  if (t.runtime_minutes) {
    const hours = Math.floor(t.runtime_minutes / 60);
    const mins = t.runtime_minutes % 60;
    duration = hours > 0 ? `${hours}h ${mins}m` : `${mins}m`;
  }
  return {
    title_id: t.id,
    title: t.title,
    year: t.year?.toString() ?? "",
    duration,
    genres: t.genres ?? [],
    rating: t.imdb_rating?.toString() ?? "",
    age_rating: t.age_rating ?? "",
    quote: chosen.item?.reason ?? "",
    description: t.overview ?? "",
    poster_url: t.poster_url,
    match_score: chosen.item?.match_score ?? null,
    tmdb_type: t.tmdb_type,
    director: t.director ?? "",
    starring: t.starring ?? [],
    watch_provider_link: chosen.watchProviders.link,
    watch_providers: chosen.watchProviders.providers,
  };
}

serve(async (req: Request) => {
  const reqId = crypto.randomUUID();
  const ctx: LogContext = { reqId };

  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: CORS_HEADERS });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(JSON.stringify({ error: "Missing Authorization Bearer token" }), { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const jwt = authHeader.slice(7);
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${jwt}` } } });
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: userInfo, error: userErr } = await supabaseUser.auth.getUser(jwt);
    if (userErr || !userInfo?.user) {
      return new Response(JSON.stringify({ error: "Invalid or expired token" }), { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    ctx.userId = userInfo.user.id;

    const rawBody = await req.json();
    const validationResult = RequestBodySchema.safeParse(rawBody);
    if (!validationResult.success) {
      return new Response(JSON.stringify({ error: "Invalid request body", details: validationResult.error.errors }), { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const body = validationResult.data;
    ctx.profileId = body.profile_id;

    const session_type = body.session_type as SessionType;
    const mood_input = body.mood_input;
    const content_types = parseContentTypes(body);
    const shouldStream = body.stream === true;

    log(ctx, "Incoming request", { profile_id: body.profile_id, session_type, content_types, stream: shouldStream });

    const windowStart = daysAgoIso(HISTORY_WINDOW_DAYS);
    const [profileResult, prefsResult, interactionsResult, userRegion] = await Promise.all([
      supabaseUser.from("profiles").select("*").eq("id", body.profile_id).single(),
      supabaseUser.from("profile_preferences").select("answers").eq("profile_id", body.profile_id).maybeSingle(),
      supabaseAdmin
        .from("profile_title_interactions")
        .select(`title_id, action, rating, extra, created_at, title:media_titles(title, tmdb_id, tmdb_type, genres)`)
        .eq("profile_id", body.profile_id)
        .gte("created_at", windowStart)
        .order("created_at", { ascending: false })
        .limit(MAX_HISTORY_FETCH),
      getUserRegion(ctx, supabaseUser, body.profile_id),
    ]);

    const { data: profile, error: profileErr } = profileResult;
    if (profileErr || !profile) {
      log(ctx, "Profile not found or unauthorized", profileErr);
      return new Response(JSON.stringify({ error: "Profile not found or not owned by user" }), { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const { data: prefs } = prefsResult;
    const { data: interactions, error: interactionsErr } = interactionsResult;
    if (interactionsErr) log(ctx, "Interactions fetch error", interactionsErr);

    const hardExcludedNormalized = new Set<string>();
    const softExcludedNormalized = new Set<string>();
    const excludedTmdbKeys = new Set<string>();
    const hardExcludedTitlesForPrompt: string[] = [];
    const softExcludedTitlesForPrompt: string[] = [];

    const posGenreScore = new Map<string, number>();
    const negGenreScore = new Map<string, number>();
    const posTagScore = new Map<string, number>();
    const negTagScore = new Map<string, number>();
    const negativeTitlesForPrompt: string[] = [];
    const positiveNotes: Array<{ text: string; w: number; at: string }> = [];
    const negativeNotes: Array<{ text: string; w: number; at: string }> = [];

    for (const i of interactions ?? []) {
      const t = (i as any).title;
      const titleStr = t?.title ? String(t.title) : "";
      const norm = titleStr ? normalizeTitle(titleStr) : "";
      const action = String((i as any).action) as InteractionAction;
      const rating = (i as any).rating == null ? null : Number((i as any).rating);
      const extra = (i as any).extra ?? {};
      const createdAt = String((i as any).created_at ?? "");
      const w = createdAt ? getFeedbackWeight(createdAt) : 0.25;
      const sentiment = getFeedbackSentiment(action, rating, extra);
      const quickTags: string[] = Array.isArray(extra?.quick_tags) ? extra.quick_tags.map((x: any) => String(x)) : [];

      if (titleStr && norm) {
        if (sentiment === "negative") {
          hardExcludedNormalized.add(norm);
          hardExcludedTitlesForPrompt.push(titleStr);
          negativeTitlesForPrompt.push(titleStr);
        } else if (action === "complete" || (rating !== null && rating === 3)) {
          softExcludedNormalized.add(norm);
          softExcludedTitlesForPrompt.push(titleStr);
        }

        if (t?.tmdb_id && t?.tmdb_type) {
          const key = `${t.tmdb_type}:${t.tmdb_id}`;
          if (sentiment === "negative") excludedTmdbKeys.add(key);
          if (action === "complete" || (rating !== null && rating === 3)) excludedTmdbKeys.add(key);
        }
      }

      const genres: string[] = Array.isArray(t?.genres) ? t.genres.map((g: any) => String(g)).filter(Boolean) : [];
      if (genres.length > 0) {
        if (sentiment === "positive") for (const g of genres) posGenreScore.set(g, (posGenreScore.get(g) ?? 0) + w);
        else if (sentiment === "negative") for (const g of genres) negGenreScore.set(g, (negGenreScore.get(g) ?? 0) + w);
      }

      if (quickTags.length > 0) {
        if (sentiment === "positive") for (const tg of quickTags) posTagScore.set(tg, (posTagScore.get(tg) ?? 0) + w);
        else if (sentiment === "negative") for (const tg of quickTags) negTagScore.set(tg, (negTagScore.get(tg) ?? 0) + w);
      }

      const note = getNoteFromExtra(extra);
      if (note) {
        if (sentiment === "negative") negativeNotes.push({ text: note, w, at: createdAt || nowIso() });
        else if (sentiment === "positive") positiveNotes.push({ text: note, w, at: createdAt || nowIso() });
      }
    }

    const positiveGenres = topKeysByScore(posGenreScore, GENRES_MAX);
    const negativeGenres = topKeysByScore(negGenreScore, GENRES_MAX);
    const positiveTags = topKeysByScore(posTagScore, 20);
    const negativeTags = topKeysByScore(negTagScore, 20);
    const positiveNotesTop = topNotes(positiveNotes, Math.ceil(NOTES_MAX / 2));
    const negativeNotesTop = topNotes(negativeNotes, Math.floor(NOTES_MAX / 2));

    const { data: recentSessions, error: sessErr } = await supabaseAdmin.from("recommendation_sessions").select("id, created_at").eq("profile_id", body.profile_id).gte("created_at", daysAgoIso(90)).order("created_at", { ascending: false }).limit(60);
    if (sessErr) log(ctx, "Recent sessions fetch error", sessErr);

    const sessionIds = (recentSessions ?? []).map((s: any) => s.id);
    let recentItems: any[] = [];
    if (sessionIds.length > 0) {
      const { data: itemsData, error: itemsErr } = await supabaseAdmin.from("recommendation_items").select(`title_id, title:media_titles(title, tmdb_id, tmdb_type)`).in("session_id", sessionIds).limit(400);
      if (itemsErr) log(ctx, "Recent recommendation_items fetch error", itemsErr);
      recentItems = itemsData ?? [];
    }

    const recommendedNormalized = new Set<string>();
    for (const ri of recentItems ?? []) {
      const t = ri.title;
      if (t?.title) recommendedNormalized.add(normalizeTitle(String(t.title)));
      if (t?.tmdb_id && t?.tmdb_type) excludedTmdbKeys.add(`${t.tmdb_type}:${t.tmdb_id}`);
    }

    const excludedNormalizedTitles = new Set<string>();
    for (const n of hardExcludedNormalized) excludedNormalizedTitles.add(n);
    for (const n of softExcludedNormalized) excludedNormalizedTitles.add(n);
    for (const n of recommendedNormalized) excludedNormalizedTitles.add(n);

    log(ctx, "Feedback signals built", { hardExcluded: hardExcludedNormalized.size, softExcluded: softExcludedNormalized.size, recentRecommended: recommendedNormalized.size, positiveGenresCount: positiveGenres.length, negativeGenresCount: negativeGenres.length, userRegion });

    const promptObj = {
      profile_id: body.profile_id,
      session_type,
      content_types,
      profile_preferences: prefs?.answers ?? {},
      recent_interactions: (interactions ?? []).slice(0, 50).map((i: any) => ({
        title_id: i.title_id,
        title: i.title?.title ?? null,
        tmdb_id: i.title?.tmdb_id ?? null,
        tmdb_type: i.title?.tmdb_type ?? null,
        action: i.action,
        rating: i.rating ?? null,
        created_at: i.created_at,
        feedback_text: getNoteFromExtra(i.extra ?? {}),
        would_watch_again: i.extra?.would_watch_again ?? null,
        quick_tags: Array.isArray(i.extra?.quick_tags) ? i.extra.quick_tags : [],
        genres: Array.isArray(i.title?.genres) ? i.title.genres : [],
      })),
      feedback_signals: {
        user_tends_to_enjoy_genres: positiveGenres,
        user_tends_to_avoid_genres: negativeGenres,
        user_tends_to_enjoy_tags: positiveTags,
        user_tends_to_avoid_tags: negativeTags,
        recent_feedback_notes_positive: positiveNotesTop,
        recent_feedback_notes_negative: negativeNotesTop,
      },
      mood_input,
    };

    const positiveSignals = { genres: positiveGenres, notes: positiveNotesTop, tags: positiveTags };
    const negativeSignals = { genres: negativeGenres, notes: negativeNotesTop, tags: negativeTags, titles: negativeTitlesForPrompt };
    const chosenNorm = new Set<string>();

    // Get OpenAI candidates
    const payload1 = await callOpenAI(ctx, promptObj, CANDIDATES_COUNT, content_types, Array.from(new Set(hardExcludedTitlesForPrompt)), Array.from(new Set(softExcludedTitlesForPrompt)), positiveSignals, negativeSignals);
    
    let finalMoodLabel = payload1.mood_label ?? "";
    let finalMoodTags = Array.isArray(payload1.mood_tags) ? payload1.mood_tags : [];

    // STREAMING MODE
    if (shouldStream) {
      log(ctx, "Starting streaming mode");
      
      // Create session first (without cards)
      const { data: session, error: sessionErr } = await supabaseAdmin
        .from("recommendation_sessions")
        .insert({
          profile_id: body.profile_id,
          session_type,
          input_payload: { ...(mood_input as any), content_types },
          openai_response: {
            mood_label: finalMoodLabel,
            mood_tags: finalMoodTags,
            content_types,
            feedback_signals_used: {
              user_tends_to_enjoy_genres: positiveGenres,
              user_tends_to_avoid_genres: negativeGenres,
              user_tends_to_enjoy_tags: positiveTags,
              user_tends_to_avoid_tags: negativeTags,
              recent_feedback_notes_positive: positiveNotesTop,
              recent_feedback_notes_negative: negativeNotesTop,
            },
            candidates_payload: payload1,
          },
          mood_label: finalMoodLabel,
          mood_tags: finalMoodTags,
          top_title_id: null,
          created_at: nowIso(),
        })
        .select()
        .single();

      if (sessionErr || !session) {
        log(ctx, "Failed to insert recommendation_sessions", sessionErr);
        return new Response(JSON.stringify({ error: "Failed to create recommendation session" }), { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
      }

      // Set up SSE stream
      const stream = new ReadableStream({
        async start(controller) {
          const encoder = new TextEncoder();
          
          // Helper to send SSE event
          const sendEvent = (data: any) => {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`));
          };

          try {
            // Send session started event
            sendEvent({
              type: "session_started",
              session_id: session.id,
              profile_id: body.profile_id,
              session_type,
              total_expected: FINAL_COUNT,
              created_at: session.created_at,
            });

            const allCards: RecommendationCard[] = [];
            const recItems: any[] = [];

            // Process candidates sequentially and stream each card
            const chosen = await processCandidatesSequential(
              ctx,
              payload1.items,
              supabaseAdmin,
              content_types,
              excludedNormalizedTitles,
              excludedTmdbKeys,
              chosenNorm,
              userRegion,
              FINAL_COUNT,
              (result, index) => {
                // Callback when card is ready - send it immediately
                const card = buildRecommendationCard(result);
                allCards.push(card);
                
                // Store recommendation item in DB
                recItems.push({
                  session_id: session.id,
                  title_id: result.mediaRow.id,
                  rank_index: index,
                  openai_reason: result.item?.reason ?? null,
                  match_score: result.item?.match_score ?? null,
                  created_at: nowIso(),
                });

                // Store streaming providers
                if (result.watchProviders.providerAvailability.length > 0) {
                  storeStreamingProviders(ctx, supabaseAdmin, result.mediaRow.id, result.watchProviders.providerAvailability, userRegion, result.watchProviders.link).catch((err) => {
                    log(ctx, "Error storing streaming providers during stream", err);
                  });
                }

                // Send card event
                log(ctx, `Streaming card ${index + 1}/${FINAL_COUNT}: ${card.title}`);
                sendEvent({
                  type: "card",
                  card,
                  index,
                });
              }
            );

            // Handle top-up if needed
            if (chosen.length < FINAL_COUNT) {
              const missing = FINAL_COUNT - chosen.length;
              log(ctx, "Top-up needed during streaming", { missing });

              const chosenTitles = chosen.map((c) => String(c.item?.title || "")).filter(Boolean);
              const topupPromptObj = { ...promptObj, topup_missing_count: missing, already_selected_titles: chosenTitles, instruction: `Return exactly ${missing} additional items that are not excluded and not already selected.` };

              for (let attempt = 0; attempt < TOPUP_MAX_ATTEMPTS && chosen.length < FINAL_COUNT; attempt++) {
                const payload2 = await callOpenAI(ctx, topupPromptObj, missing, content_types, Array.from(new Set(hardExcludedTitlesForPrompt.concat(chosenTitles))), Array.from(new Set(softExcludedTitlesForPrompt.concat(chosenTitles))), positiveSignals, negativeSignals);
                if (!finalMoodLabel && payload2.mood_label) finalMoodLabel = payload2.mood_label;
                if ((!finalMoodTags || finalMoodTags.length === 0) && Array.isArray(payload2.mood_tags)) finalMoodTags = payload2.mood_tags;

                await processCandidatesSequential(
                  ctx,
                  payload2.items,
                  supabaseAdmin,
                  content_types,
                  excludedNormalizedTitles,
                  excludedTmdbKeys,
                  chosenNorm,
                  userRegion,
                  missing - (chosen.length - allCards.length),
                  (result, relativeIndex) => {
                    const absoluteIndex = allCards.length;
                    const card = buildRecommendationCard(result);
                    allCards.push(card);
                    chosen.push(result);

                    recItems.push({
                      session_id: session.id,
                      title_id: result.mediaRow.id,
                      rank_index: absoluteIndex,
                      openai_reason: result.item?.reason ?? null,
                      match_score: result.item?.match_score ?? null,
                      created_at: nowIso(),
                    });

                    if (result.watchProviders.providerAvailability.length > 0) {
                      storeStreamingProviders(ctx, supabaseAdmin, result.mediaRow.id, result.watchProviders.providerAvailability, userRegion, result.watchProviders.link).catch((err) => {
                        log(ctx, "Error storing streaming providers during topup", err);
                      });
                    }

                    log(ctx, `Streaming topup card ${absoluteIndex + 1}/${FINAL_COUNT}: ${card.title}`);
                    sendEvent({
                      type: "card",
                      card,
                      index: absoluteIndex,
                    });
                  }
                );
              }
            }

            // Insert all recommendation items at once
            if (recItems.length > 0) {
              const { error: itemsErr } = await supabaseAdmin.from("recommendation_items").insert(recItems);
              if (itemsErr) log(ctx, "Failed to insert recommendation_items", itemsErr);
            }

            // Update session with top_title_id
            if (allCards.length > 0) {
              const topTitleId = recItems[0]?.title_id;
              if (topTitleId) {
                await supabaseAdmin.from("recommendation_sessions").update({ top_title_id: topTitleId }).eq("id", session.id);
              }
            }

            // Send completion event
            log(ctx, `Streaming complete with ${allCards.length} cards`);
            sendEvent({
              type: "complete",
              id: session.id,
              profile_id: body.profile_id,
              session_type,
              mood_input: { ...(mood_input as any), content_types },
              created_at: session.created_at,
              cards: allCards,
            });

            controller.close();
          } catch (error) {
            log(ctx, "Error during streaming", error);
            sendEvent({
              type: "error",
              message: String(error),
            });
            controller.close();
          }
        },
      });

      return new Response(stream, { status: 200, headers: SSE_HEADERS });
    }

    // NON-STREAMING MODE (original behavior)
    let chosen = await processCandidatesParallel(ctx, payload1.items, supabaseAdmin, content_types, excludedNormalizedTitles, excludedTmdbKeys, chosenNorm, userRegion, FINAL_COUNT);

    if (chosen.length < FINAL_COUNT) {
      const missing = FINAL_COUNT - chosen.length;
      log(ctx, "Top-up needed", { missing });

      const chosenTitles = chosen.map((c) => String(c.item?.title || "")).filter(Boolean);
      const topupPromptObj = { ...promptObj, topup_missing_count: missing, already_selected_titles: chosenTitles, instruction: `Return exactly ${missing} additional items that are not excluded and not already selected.` };

      for (let attempt = 0; attempt < TOPUP_MAX_ATTEMPTS; attempt++) {
        const payload2 = await callOpenAI(ctx, topupPromptObj, missing, content_types, Array.from(new Set(hardExcludedTitlesForPrompt.concat(chosenTitles))), Array.from(new Set(softExcludedTitlesForPrompt.concat(chosenTitles))), positiveSignals, negativeSignals);
        if (!finalMoodLabel && payload2.mood_label) finalMoodLabel = payload2.mood_label;
        if ((!finalMoodTags || finalMoodTags.length === 0) && Array.isArray(payload2.mood_tags)) finalMoodTags = payload2.mood_tags;

        const topupChosen = await processCandidatesParallel(ctx, payload2.items, supabaseAdmin, content_types, excludedNormalizedTitles, excludedTmdbKeys, chosenNorm, userRegion, missing);
        chosen = chosen.concat(topupChosen);
        if (chosen.length >= FINAL_COUNT) break;
      }
    }

    if (chosen.length === 0) {
      return new Response(JSON.stringify({ error: "Could not generate recommendations after filtering" }), { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const finalChosen = chosen.slice(0, FINAL_COUNT);
    const sessionOpenAiResponse = {
      mood_label: finalMoodLabel,
      mood_tags: finalMoodTags,
      content_types,
      feedback_signals_used: {
        user_tends_to_enjoy_genres: positiveGenres,
        user_tends_to_avoid_genres: negativeGenres,
        user_tends_to_enjoy_tags: positiveTags,
        user_tends_to_avoid_tags: negativeTags,
        recent_feedback_notes_positive: positiveNotesTop,
        recent_feedback_notes_negative: negativeNotesTop,
      },
      candidates_payload: payload1,
      selected_titles: finalChosen.map((c) => ({ title: c.mediaRow?.title, tmdb_id: c.mediaRow?.tmdb_id, tmdb_type: c.mediaRow?.tmdb_type, match_score: c.item?.match_score ?? null })),
    };

    const { data: session, error: sessionErr } = await supabaseAdmin
      .from("recommendation_sessions")
      .insert({
        profile_id: body.profile_id,
        session_type,
        input_payload: { ...(mood_input as any), content_types },
        openai_response: sessionOpenAiResponse,
        mood_label: finalMoodLabel,
        mood_tags: finalMoodTags,
        top_title_id: finalChosen[0].mediaRow.id,
        created_at: nowIso(),
      })
      .select()
      .single();

    if (sessionErr || !session) {
      log(ctx, "Failed to insert recommendation_sessions", sessionErr);
      return new Response(JSON.stringify({ error: "Failed to create recommendation session" }), { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const recItems = finalChosen.map((c, idx) => ({ session_id: session.id, title_id: c.mediaRow.id, rank_index: idx, openai_reason: c.item?.reason ?? null, match_score: c.item?.match_score ?? null, created_at: nowIso() }));
    const { error: itemsErr } = await supabaseAdmin.from("recommendation_items").insert(recItems);
    if (itemsErr) log(ctx, "Failed to insert recommendation_items", itemsErr);

    await Promise.all(
      finalChosen.map((c) =>
        c.watchProviders.providerAvailability.length > 0
          ? storeStreamingProviders(ctx, supabaseAdmin, c.mediaRow.id, c.watchProviders.providerAvailability, userRegion, c.watchProviders.link)
          : Promise.resolve(),
      ),
    );

    const cards: RecommendationCard[] = finalChosen.map((c) => buildRecommendationCard(c));

    log(ctx, "Successfully created recommendation session", { sessionId: session.id, cardsCount: cards.length, userRegion });
    return new Response(JSON.stringify({ id: session.id, profile_id: body.profile_id, session_type, mood_input: { ...(mood_input as any), content_types }, created_at: session.created_at, cards }), { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  } catch (err) {
    console.error(err);
    log(ctx, "Fatal error in recommendation session creation", { error: String(err) });
    return new Response(JSON.stringify({ error: "Internal server error", details: String(err) }), { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  }
});
