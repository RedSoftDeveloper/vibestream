
// supabase/functions/create_recommendation_session/openai.ts
import OpenAI from "npm:openai@4.20.1";
import { LogContext, OpenAIResponse, TmdbType } from "./types.ts";
import { GENRES_MAX, NOTES_MAX, OPENAI_API_KEY } from "./config.ts";
import { extractFirstJsonObject, log, stripCodeFences } from "./utils.ts";

const openai = new OpenAI({ apiKey: OPENAI_API_KEY });

export function buildSystemPrompt(
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

export async function callOpenAI(
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

  log(ctx, `Calling OpenAI for ${itemsCount} candidates`, {
    allowedTypes,
    hardExcludedCount: hardExcludedTitles.length,
    softExcludedCount: softExcludedTitles.length,
  });

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
