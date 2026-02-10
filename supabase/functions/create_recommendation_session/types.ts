
// supabase/functions/create_recommendation_session/types.ts
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export type SessionType = "onboarding" | "mood" | "quick_match";
export type TmdbType = "movie" | "tv";
export type InteractionAction =
  | "impression"
  | "open"
  | "play"
  | "complete"
  | "like"
  | "dislike"
  | "skip"
  | "feedback";

export type AvailabilityType = "flatrate" | "free" | "ads" | "rent" | "buy";

export interface LogContext {
  reqId: string;
  userId?: string | null;
  profileId?: string;
}

export interface TmdbSearchResult {
  tmdb_id: number;
  tmdb_type: TmdbType;
  tmdb_title: string;
}

export interface WatchProvider {
  provider_id: number;
  name: string;
  logo_url: string | null;
}

export interface WatchProviderWithAvailability extends WatchProvider {
  availability_type: AvailabilityType;
}

export interface WatchProvidersResult {
  link: string | null;
  providers: WatchProvider[];
  providerAvailability: WatchProviderWithAvailability[];
}

export interface MediaTitle {
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

export interface TmdbDetails {
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

export interface OmdbResponse {
  Response: string;
  imdbRating?: string;
  Rated?: string;
  [key: string]: any;
}

export interface OpenAIItem {
  title: string;
  tmdb_type: TmdbType;
  tmdb_search_query: string;
  primary_genres: string[];
  tone_tags: string[];
  reason: string;
  match_score: number;
}

export interface OpenAIResponse {
  mood_label: string;
  mood_tags: string[];
  items: OpenAIItem[];
}

export interface RecommendationCard {
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

// Zod schema
export const RequestBodySchema = z.object({
  profile_id: z.string().uuid(),
  session_type: z.enum(["onboarding", "mood", "quick_match"]),
  mood_input: z.record(z.any()).optional().default({}),
  content_types: z.array(z.enum(["movie", "tv"])).optional(),
});

export type RequestBody = z.infer<typeof RequestBodySchema>;
