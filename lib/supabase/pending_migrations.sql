-- ====================================
-- STREAMING PROVIDERS TABLE (New)
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
-- TITLE STREAMING AVAILABILITY TABLE (New)
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

-- ====================================
-- STREAMING PROVIDERS POLICIES
-- ====================================
ALTER TABLE public.streaming_providers ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read streaming providers
DROP POLICY IF EXISTS streaming_providers_select_policy ON public.streaming_providers;
CREATE POLICY streaming_providers_select_policy ON public.streaming_providers
  FOR SELECT
  USING (true);

-- ====================================
-- TITLE STREAMING AVAILABILITY POLICIES
-- ====================================
ALTER TABLE public.title_streaming_availability ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read availability
DROP POLICY IF EXISTS title_streaming_availability_select_policy ON public.title_streaming_availability;
CREATE POLICY title_streaming_availability_select_policy ON public.title_streaming_availability
  FOR SELECT
  USING (true);

-- ====================================
-- ADD watch_provider_link TO media_titles
-- ====================================
-- Add column if it doesn't exist (for TMDB's watch page link)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'media_titles' 
    AND column_name = 'watch_provider_link'
  ) THEN
    ALTER TABLE public.media_titles ADD COLUMN watch_provider_link TEXT;
  END IF;
END $$;

COMMENT ON COLUMN public.media_titles.watch_provider_link IS 'TMDB watch provider page link for this title';
