
// supabase/functions/create_recommendation_session/candidates.ts
import { LogContext, MediaTitle, OpenAIItem, TmdbSearchResult, TmdbType, WatchProvidersResult } from "./types.ts";
import { normalizeTitle } from "./utils.ts";
import { tmdbSearchOne } from "./tmdb.ts";
import { getOrCreateMediaTitle } from "./database.ts";

export async function processCandidatesParallel(
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
