
// supabase/functions/create_recommendation_session/tmdb.ts
import { LogContext, TmdbDetails, TmdbSearchResult, TmdbType } from "./types.ts";
import { TMDB_API_KEY } from "./config.ts";
import { fetchWithTimeout, log } from "./utils.ts";

export async function tmdbSearchOne(ctx: LogContext, searchQuery: string, tmdbType: TmdbType): Promise<TmdbSearchResult | null> {
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

export async function tmdbGetDetails(ctx: LogContext, tmdbId: number, tmdbType: TmdbType): Promise<TmdbDetails | null> {
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

export async function tmdbWatchProviders(ctx: LogContext, tmdbId: number, tmdbType: TmdbType): Promise<any> {
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
