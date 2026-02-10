
// supabase/functions/create_recommendation_session/omdb.ts
import { LogContext, OmdbResponse } from "./types.ts";
import { OMDB_API_KEY } from "./config.ts";
import { fetchWithTimeout, log } from "./utils.ts";

export async function omdbGetDetails(ctx: LogContext, imdbId: string): Promise<OmdbResponse | null> {
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
