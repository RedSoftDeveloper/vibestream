
// supabase/functions/create_recommendation_session/utils.ts
import { LogContext, RequestBody, TmdbType } from "./types.ts";
import { API_TIMEOUT_MS } from "./config.ts";

export function normalizeTitle(s: string): string {
  return (s || "").toLowerCase().replace(/[^a-z0-9\s]/g, " ").replace(/\s+/g, " ").trim();
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function daysAgoIso(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

export function log(ctx: LogContext, msg: string, extra?: unknown): void {
  const ts = new Date().toISOString();
  const base =
    `[create_recommendation_session][${ts}][req:${ctx.reqId}]` +
    (ctx.userId ? `[user:${ctx.userId}]` : "[user:unknown]") +
    (ctx.profileId ? `[profile:${ctx.profileId}]` : "");
  if (extra !== undefined) console.log(base + " " + msg, extra);
  else console.log(base + " " + msg);
}

export function parseContentTypes(body: RequestBody): TmdbType[] {
  const raw = body.content_types ?? (body.mood_input as any)?.content_types ?? [];
  const list = Array.isArray(raw) ? raw : [];
  const cleaned = list
    .map((x: any) => String(x).toLowerCase().trim())
    .filter((x: string) => x === "movie" || x === "tv") as TmdbType[];
  const unique = Array.from(new Set(cleaned));
  return unique.length > 0 ? unique : ["movie"];
}

export function stripCodeFences(s: string): string {
  let out = (s || "").trim();
  if (out.startsWith("```json")) out = out.slice(7).trim();
  else if (out.startsWith("```")) out = out.slice(3).trim();
  if (out.endsWith("```")) out = out.slice(0, -3).trim();
  return out;
}

export function extractFirstJsonObject(s: string): string | null {
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

export async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = API_TIMEOUT_MS): Promise<Response> {
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
