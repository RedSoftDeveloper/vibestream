
// supabase/functions/create_recommendation_session/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

import {
  CANDIDATES_COUNT,
  CORS_HEADERS,
  FINAL_COUNT,
  GENRES_MAX,
  HISTORY_WINDOW_DAYS,
  MAX_HISTORY_FETCH,
  NOTES_MAX,
  SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY,
  SUPABASE_URL,
  TOPUP_MAX_ATTEMPTS,
} from "./config.ts";

import { LogContext, RecommendationCard, RequestBodySchema, SessionType, InteractionAction } from "./types.ts";
import { daysAgoIso, log, nowIso, parseContentTypes, normalizeTitle } from "./utils.ts";
import { getFeedbackSentiment, getFeedbackWeight, getNoteFromExtra, topKeysByScore, topNotes } from "./feedback.ts";
import { getUserRegion, storeStreamingProviders } from "./database.ts";
import { callOpenAI } from "./openai.ts";
import { processCandidatesParallel } from "./candidates.ts";

type SubscriptionTier = "free" | "premium";

function startOfTodayUtcIso() {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
  return start.toISOString();
}

async function getSubscriptionTier(ctx: LogContext, supabaseAdmin: any, userId: string): Promise<SubscriptionTier> {
  try {
    const { data, error } = await supabaseAdmin.from("app_users").select("subscription_tier").eq("id", userId).maybeSingle();
    if (error) {
      log(ctx, "Subscription tier lookup failed; defaulting to free", { error: String(error) });
      return "free";
    }

    const raw = (data as any)?.subscription_tier;
    const tier = typeof raw === "string" ? raw.toLowerCase() : "free";
    return tier === "premium" ? "premium" : "free";
  } catch (e) {
    log(ctx, "Subscription tier lookup threw; defaulting to free", { error: String(e) });
    return "free";
  }
}

async function countTodaySessionsForUser(ctx: LogContext, supabaseAdmin: any, userId: string): Promise<number> {
  const start = startOfTodayUtcIso();
  try {
    const { data: profiles, error: profilesErr } = await supabaseAdmin.from("profiles").select("id").eq("user_id", userId);
    if (profilesErr) {
      log(ctx, "Profiles lookup failed for daily usage", { error: String(profilesErr) });
      return 0;
    }

    const profileIds = (profiles ?? []).map((p: any) => String(p.id)).filter(Boolean);
    if (profileIds.length === 0) return 0;

    const { count, error: countErr } = await supabaseAdmin
      .from("recommendation_sessions")
      .select("id", { count: "exact", head: true })
      .in("profile_id", profileIds)
      .gte("created_at", start);

    if (countErr) {
      log(ctx, "Daily session count failed", { error: String(countErr) });
      return 0;
    }

    return typeof count === "number" ? count : 0;
  } catch (e) {
    log(ctx, "Daily session count threw", { error: String(e) });
    return 0;
  }
}

serve(async (req: Request) => {
  const reqId = crypto.randomUUID();
  let userId: string | null = null;
  let profileId: string | undefined = undefined;
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

    userId = userInfo.user.id;
    ctx.userId = userId;

    const rawBody = await req.json();
    const validationResult = RequestBodySchema.safeParse(rawBody);
    if (!validationResult.success) {
      return new Response(JSON.stringify({ error: "Invalid request body", details: validationResult.error.errors }), { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    const body = validationResult.data;
    profileId = body.profile_id;
    ctx.profileId = profileId;

    const session_type = body.session_type as SessionType;
    const mood_input = body.mood_input;
    const content_types = parseContentTypes(body);

    log(ctx, "Incoming request", { profile_id: profileId, session_type, content_types });

    const windowStart = daysAgoIso(HISTORY_WINDOW_DAYS);
    const [profileResult, prefsResult, interactionsResult, userRegion] = await Promise.all([
      supabaseUser.from("profiles").select("*").eq("id", profileId).single(),
      supabaseUser.from("profile_preferences").select("answers").eq("profile_id", profileId).maybeSingle(),
      supabaseAdmin
        .from("profile_title_interactions")
        .select(`title_id, action, rating, extra, created_at, title:media_titles(title, tmdb_id, tmdb_type, genres)`)
        .eq("profile_id", profileId)
        .gte("created_at", windowStart)
        .order("created_at", { ascending: false })
        .limit(MAX_HISTORY_FETCH),
      getUserRegion(ctx, supabaseUser, profileId),
    ]);

    const { data: profile, error: profileErr } = profileResult;
    if (profileErr || !profile) {
      log(ctx, "Profile not found or unauthorized", profileErr);
      return new Response(JSON.stringify({ error: "Profile not found or not owned by user" }), { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }

    // --- Daily recommendation limit enforcement (authoritative, server-side) ---
    // We do this AFTER verifying the profile is owned by the user, but BEFORE any OpenAI/TMDB work.
    const tier = await getSubscriptionTier(ctx, supabaseAdmin, userId);
    const dailyLimit = tier === "premium" ? 50 : 5;
    const usedToday = await countTodaySessionsForUser(ctx, supabaseAdmin, userId);
    if (usedToday >= dailyLimit) {
      log(ctx, "Daily recommendation limit reached", { tier, dailyLimit, usedToday });
      return new Response(
        JSON.stringify({
          error: "daily_limit_reached",
          message: tier === "premium"
            ? `You've reached your ${dailyLimit}/day recommendation limit.`
            : `You've reached your free ${dailyLimit}/day recommendation limit. Upgrade to Premium for more.`,
          tier,
          daily_limit: dailyLimit,
          used_today: usedToday,
        }),
        { status: 429, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
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

    const { data: recentSessions, error: sessErr } = await supabaseAdmin
      .from("recommendation_sessions")
      .select("id, created_at")
      .eq("profile_id", profileId)
      .gte("created_at", daysAgoIso(90))
      .order("created_at", { ascending: false })
      .limit(60);
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

    log(ctx, "Feedback signals built", {
      hardExcluded: hardExcludedNormalized.size,
      softExcluded: softExcludedNormalized.size,
      recentRecommended: recommendedNormalized.size,
      positiveGenresCount: positiveGenres.length,
      negativeGenresCount: negativeGenres.length,
      userRegion,
    });

    const promptObj = {
      profile_id: profileId,
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

    const payload1 = await callOpenAI(
      ctx,
      promptObj,
      CANDIDATES_COUNT,
      content_types,
      Array.from(new Set(hardExcludedTitlesForPrompt)),
      Array.from(new Set(softExcludedTitlesForPrompt)),
      positiveSignals,
      negativeSignals,
    );

    let chosen = await processCandidatesParallel(ctx, payload1.items, supabaseAdmin, content_types, excludedNormalizedTitles, excludedTmdbKeys, chosenNorm, userRegion, FINAL_COUNT);
    let finalMoodLabel = payload1.mood_label ?? "";
    let finalMoodTags = Array.isArray(payload1.mood_tags) ? payload1.mood_tags : [];

    if (chosen.length < FINAL_COUNT) {
      const missing = FINAL_COUNT - chosen.length;
      log(ctx, "Top-up needed", { missing });
      const chosenTitles = chosen.map((c) => String(c.item?.title || "")).filter(Boolean);
      const topupPromptObj = { ...promptObj, topup_missing_count: missing, already_selected_titles: chosenTitles, instruction: `Return exactly ${missing} additional items that are not excluded and not already selected.` };

      for (let attempt = 0; attempt < TOPUP_MAX_ATTEMPTS; attempt++) {
        const payload2 = await callOpenAI(
          ctx,
          topupPromptObj,
          missing,
          content_types,
          Array.from(new Set(hardExcludedTitlesForPrompt.concat(chosenTitles))),
          Array.from(new Set(softExcludedTitlesForPrompt.concat(chosenTitles))),
          positiveSignals,
          negativeSignals,
        );

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
        profile_id: profileId,
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

    const recItems = finalChosen.map((c, idx) => ({
      session_id: session.id,
      title_id: c.mediaRow.id,
      rank_index: idx, // 0-based
      openai_reason: c.item?.reason ?? null,
      match_score: c.item?.match_score ?? null,
      created_at: nowIso(),
    }));

    const { error: itemsErr } = await supabaseAdmin.from("recommendation_items").insert(recItems);
    if (itemsErr) log(ctx, "Failed to insert recommendation_items", itemsErr);

    await Promise.all(
      finalChosen.map((c) =>
        c.watchProviders.providerAvailability.length > 0
          ? storeStreamingProviders(ctx, supabaseAdmin, c.mediaRow.id, c.watchProviders.providerAvailability, userRegion, c.watchProviders.link)
          : Promise.resolve(),
      ),
    );

    const cards: RecommendationCard[] = finalChosen.map((c) => {
      const t = c.mediaRow;
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
        quote: c.item?.reason ?? "",
        description: t.overview ?? "",
        poster_url: t.poster_url,
        match_score: c.item?.match_score ?? null,
        tmdb_type: t.tmdb_type,
        director: t.director ?? "",
        starring: t.starring ?? [],
        watch_provider_link: c.watchProviders.link,
        watch_providers: c.watchProviders.providers,
      };
    });

    log(ctx, "Successfully created recommendation session", { sessionId: session.id, cardsCount: cards.length, userRegion });

    return new Response(
      JSON.stringify({ id: session.id, profile_id: profileId, session_type, mood_input: { ...(mood_input as any), content_types }, created_at: session.created_at, cards }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error(err);
    log(ctx, "Fatal error in recommendation session creation", { error: String(err) });
    return new Response(JSON.stringify({ error: "Internal server error", details: String(err) }), { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  }
});
