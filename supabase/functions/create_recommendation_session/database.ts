
// supabase/functions/create_recommendation_session/database.ts
import { LogContext, MediaTitle, TmdbType, WatchProvidersResult, WatchProviderWithAvailability } from "./types.ts";
import { log, nowIso } from "./utils.ts";
import { tmdbGetDetails, tmdbWatchProviders } from "./tmdb.ts";
import { omdbGetDetails } from "./omdb.ts";
import { pickProvidersForRegion } from "./providers.ts";

export async function storeStreamingProviders(
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
      if (!uniqueProviders.has(p.provider_id)) {
        uniqueProviders.set(p.provider_id, { tmdb_provider_id: p.provider_id, name: p.name, logo_url: p.logo_url });
      }
    }

    const providersToUpsert = Array.from(uniqueProviders.values());
    const { data: upsertedProviders, error: providerErr } = await supabaseAdmin
      .from("streaming_providers")
      .upsert(providersToUpsert, { onConflict: "tmdb_provider_id", ignoreDuplicates: false })
      .select("id, tmdb_provider_id");

    if (providerErr) {
      log(ctx, "Error upserting streaming_providers", providerErr);
      return;
    }

    const providerIdMap = new Map<number, string>();
    for (const p of upsertedProviders ?? []) providerIdMap.set(p.tmdb_provider_id, p.id);

    const { error: deleteErr } = await supabaseAdmin.from("title_streaming_availability").delete().eq("title_id", titleId).eq("region", region);
    if (deleteErr) log(ctx, "Error deleting old title_streaming_availability", deleteErr);

    const availabilityRecords = providerAvailability
      .map((p) => ({
        title_id: titleId,
        provider_id: providerIdMap.get(p.provider_id),
        region,
        availability_type: p.availability_type,
        watch_link: watchProviderLink,
      }))
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

export async function getOrCreateMediaTitle(
  ctx: LogContext,
  supabaseAdmin: any,
  tmdbId: number,
  tmdbType: TmdbType,
  fallbackTitle: string,
  userRegion: string,
): Promise<{ mediaTitle: MediaTitle | null; watchProviders: WatchProvidersResult }> {
  const { data: existing, error: existingErr } = await supabaseAdmin.from("media_titles").select("*").eq("tmdb_id", tmdbId).eq("tmdb_type", tmdbType).maybeSingle();
  if (existingErr) log(ctx, "Error checking media_titles cache", existingErr);

  const needsEnrich =
    !existing ||
    (existing.imdb_rating == null && existing.imdb_id == null) ||
    existing.director == null ||
    existing.starring == null;

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

export async function getUserRegion(ctx: LogContext, supabaseUser: any, profileId: string): Promise<string> {
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
