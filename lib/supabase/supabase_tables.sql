-- VibeStream Database Schema
-- This file contains all table definitions for the VibeStream application

-- ====================================
-- 1. APP USERS TABLE
-- ====================================
-- Stores application user data linked to Supabase auth.users
CREATE TABLE IF NOT EXISTS public.app_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  display_name TEXT,
  avatar_url TEXT,
  region TEXT NOT NULL DEFAULT 'SE',
  locale TEXT NOT NULL DEFAULT 'en',
  last_active_profile_id UUID
);

CREATE INDEX IF NOT EXISTS idx_app_users_id ON public.app_users(id);

COMMENT ON TABLE public.app_users IS 'Application user data linked to Supabase auth';
COMMENT ON COLUMN public.app_users.last_active_profile_id IS 'The most recently used profile for this user';

-- ====================================
-- 2. USER PROFILES TABLE
-- ====================================
-- Stores user profiles for different watching preferences
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '👤',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON public.user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_created_at ON public.user_profiles(created_at DESC);

COMMENT ON TABLE public.user_profiles IS 'User profiles for personalized watching preferences';

-- ====================================
-- 3. MEDIA TITLES TABLE
-- ====================================
-- Stores movie and TV show metadata
CREATE TABLE IF NOT EXISTS public.media_titles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_id TEXT NOT NULL,
  imdb_id TEXT,
  title TEXT NOT NULL,
  description TEXT,
  poster_url TEXT,
  backdrop_url TEXT,
  release_date DATE,
  type TEXT NOT NULL CHECK (type IN ('movie', 'series')),
  genres TEXT[] NOT NULL DEFAULT '{}',
  runtime_minutes INTEGER,
  imdb_rating NUMERIC(3,1),
  vote_count INTEGER,
  vibe_tags TEXT[] NOT NULL DEFAULT '{}',
  vibe_explanation TEXT,
  streaming_providers JSONB DEFAULT '[]',
  age_rating TEXT,
  director TEXT,
  starring TEXT[] NOT NULL DEFAULT '{}',
  year INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_media_titles_tmdb_id_type ON public.media_titles(tmdb_id, type);
CREATE INDEX IF NOT EXISTS idx_media_titles_genres ON public.media_titles USING GIN(genres);
CREATE INDEX IF NOT EXISTS idx_media_titles_type ON public.media_titles(type);
CREATE INDEX IF NOT EXISTS idx_media_titles_imdb_rating ON public.media_titles(imdb_rating DESC NULLS LAST);

COMMENT ON TABLE public.media_titles IS 'Movies and TV shows catalog';
COMMENT ON COLUMN public.media_titles.type IS 'Content type: movie or series';
COMMENT ON COLUMN public.media_titles.vibe_tags IS 'Mood/vibe tags for recommendations';
COMMENT ON COLUMN public.media_titles.streaming_providers IS 'Available streaming platforms (JSON array)';

-- ====================================
-- 4. RECOMMENDATION SESSIONS TABLE
-- ====================================
-- Stores recommendation session metadata
CREATE TABLE IF NOT EXISTS public.recommendation_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  session_type TEXT NOT NULL CHECK (session_type IN ('onboarding', 'quick_match', 'mood')),
  mood_input JSONB NOT NULL DEFAULT '{}',
  mood_tags TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_profile_id ON public.recommendation_sessions(profile_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_created_at ON public.recommendation_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_session_type ON public.recommendation_sessions(session_type);

COMMENT ON TABLE public.recommendation_sessions IS 'Recommendation session metadata';
COMMENT ON COLUMN public.recommendation_sessions.session_type IS 'Type of recommendation: onboarding, quick_match, or mood';
COMMENT ON COLUMN public.recommendation_sessions.mood_input IS 'User input data for this session (JSON)';
COMMENT ON COLUMN public.recommendation_sessions.mood_tags IS 'Derived mood tags for this session';

-- ====================================
-- 5. RECOMMENDATION ITEMS TABLE
-- ====================================
-- Stores individual recommendations within sessions
CREATE TABLE IF NOT EXISTS public.recommendation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.recommendation_sessions(id) ON DELETE CASCADE,
  title_id UUID NOT NULL REFERENCES public.media_titles(id) ON DELETE CASCADE,
  rank_index INTEGER NOT NULL,
  openai_reason TEXT,
  match_score INTEGER CHECK (match_score IS NULL OR (match_score >= 0 AND match_score <= 100)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendation_items_session_id ON public.recommendation_items(session_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_items_title_id ON public.recommendation_items(title_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_items_rank ON public.recommendation_items(rank_index);
CREATE INDEX IF NOT EXISTS idx_recommendation_items_created_at ON public.recommendation_items(created_at DESC);

COMMENT ON TABLE public.recommendation_items IS 'Individual recommendations within sessions';
COMMENT ON COLUMN public.recommendation_items.rank_index IS 'Position in the recommendation list (0-based)';
COMMENT ON COLUMN public.recommendation_items.openai_reason IS 'AI-generated explanation for this recommendation';
COMMENT ON COLUMN public.recommendation_items.match_score IS 'AI-calculated mood match percentage (0-100)';

-- ====================================
-- 6. PROFILE FAVORITES TABLE
-- ====================================
-- Stores user's favorite titles (clean, dedicated table)
CREATE TABLE IF NOT EXISTS public.profile_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  title_id UUID NOT NULL REFERENCES public.media_titles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(profile_id, title_id)
);

CREATE INDEX IF NOT EXISTS idx_profile_favorites_profile_id ON public.profile_favorites(profile_id);
CREATE INDEX IF NOT EXISTS idx_profile_favorites_title_id ON public.profile_favorites(title_id);
CREATE INDEX IF NOT EXISTS idx_profile_favorites_created_at ON public.profile_favorites(created_at DESC);

COMMENT ON TABLE public.profile_favorites IS 'User favorite titles per profile';
COMMENT ON COLUMN public.profile_favorites.profile_id IS 'The profile that favorited this title';
COMMENT ON COLUMN public.profile_favorites.title_id IS 'The favorited media title';

-- ====================================
-- FOREIGN KEY UPDATES
-- ====================================
-- Link last_active_profile_id to user_profiles after all tables are created
ALTER TABLE public.app_users
DROP CONSTRAINT IF EXISTS fk_app_users_last_active_profile;

ALTER TABLE public.app_users
ADD CONSTRAINT fk_app_users_last_active_profile 
FOREIGN KEY (last_active_profile_id) 
REFERENCES public.user_profiles(id) 
ON DELETE SET NULL;

-- ====================================
-- 7. APP FEEDBACK TABLE
-- ====================================
-- Stores user feedback about the app itself (not title feedback)
CREATE TABLE IF NOT EXISTS public.app_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  feedback_text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_feedback_user_id ON public.app_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_app_feedback_created_at ON public.app_feedback(created_at DESC);

COMMENT ON TABLE public.app_feedback IS 'User feedback about the VibeStream app';
COMMENT ON COLUMN public.app_feedback.user_id IS 'The user who submitted the feedback';
COMMENT ON COLUMN public.app_feedback.feedback_text IS 'Feedback content (max 400 chars enforced by app)';

-- ====================================
-- 8. STREAMING PROVIDERS TABLE
-- ====================================
-- Master list of streaming providers (Netflix, Disney+, etc.)
CREATE TABLE IF NOT EXISTS public.streaming_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_provider_id INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  logo_url TEXT,
  display_priority INTEGER NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_streaming_providers_tmdb_id ON public.streaming_providers(tmdb_provider_id);
CREATE INDEX IF NOT EXISTS idx_streaming_providers_priority ON public.streaming_providers(display_priority);

COMMENT ON TABLE public.streaming_providers IS 'Master list of streaming providers (Netflix, Disney+, etc.)';
COMMENT ON COLUMN public.streaming_providers.tmdb_provider_id IS 'TMDB Watch Provider ID';
COMMENT ON COLUMN public.streaming_providers.display_priority IS 'Lower = higher priority for display ordering';

-- ====================================
-- 9. TITLE STREAMING AVAILABILITY TABLE
-- ====================================
-- Junction table linking media_titles to streaming_providers per region
CREATE TABLE IF NOT EXISTS public.title_streaming_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id UUID NOT NULL REFERENCES public.media_titles(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES public.streaming_providers(id) ON DELETE CASCADE,
  region TEXT NOT NULL DEFAULT 'SE',
  availability_type TEXT NOT NULL DEFAULT 'flatrate' CHECK (availability_type IN ('flatrate', 'rent', 'buy', 'free', 'ads')),
  watch_link TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(title_id, provider_id, region, availability_type)
);

CREATE INDEX IF NOT EXISTS idx_title_streaming_title_id ON public.title_streaming_availability(title_id);
CREATE INDEX IF NOT EXISTS idx_title_streaming_provider_id ON public.title_streaming_availability(provider_id);
CREATE INDEX IF NOT EXISTS idx_title_streaming_region ON public.title_streaming_availability(region);
CREATE INDEX IF NOT EXISTS idx_title_streaming_type ON public.title_streaming_availability(availability_type);

COMMENT ON TABLE public.title_streaming_availability IS 'Links media_titles to streaming_providers per region';
COMMENT ON COLUMN public.title_streaming_availability.region IS 'ISO 3166-1 alpha-2 country code (SE, US, GB, etc.)';
COMMENT ON COLUMN public.title_streaming_availability.availability_type IS 'flatrate=subscription, rent, buy, free, ads';
COMMENT ON COLUMN public.title_streaming_availability.watch_link IS 'Direct link to watch on provider (from TMDB)';
