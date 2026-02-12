-- Recommendation usage tracking (daily aggregate + per-session dedupe)
-- Security + performance goals:
-- - Counters updated atomically in Postgres (single round-trip from Edge Function)
-- - Dedupe by session_id to avoid double-counting retries
-- - Enforce profile ownership via auth.uid()

-- Tables
CREATE TABLE IF NOT EXISTS public.profile_recommendation_usage_daily (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  usage_date date NOT NULL,
  recommendations_used integer NOT NULL DEFAULT 0,
  sessions_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_id, usage_date)
);

CREATE TABLE IF NOT EXISTS public.recommendation_usage_events (
  session_id uuid PRIMARY KEY REFERENCES public.recommendation_sessions(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recommendations_used integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profile_recommendation_usage_daily_profile_date
  ON public.profile_recommendation_usage_daily(profile_id, usage_date);

-- RLS
ALTER TABLE public.profile_recommendation_usage_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_usage_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- profile_recommendation_usage_daily policies
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profile_recommendation_usage_daily' AND policyname = 'Users can view own daily usage'
  ) THEN
    CREATE POLICY "Users can view own daily usage" ON public.profile_recommendation_usage_daily
      FOR SELECT USING (
        profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
      );
  END IF;

  -- recommendation_usage_events policies
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'recommendation_usage_events' AND policyname = 'Users can view own usage events'
  ) THEN
    CREATE POLICY "Users can view own usage events" ON public.recommendation_usage_events
      FOR SELECT USING (
        profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
      );
  END IF;
END $$;

-- RPC: increment_daily_recommendation_usage
-- Parameters:
-- - profile_id: profile to bill
-- - session_id: created recommendation session id (dedupe key)
-- - recommendations_count: number of recommendations returned to the user
-- - daily_limit: optional hard cap (enforced atomically to avoid races)
CREATE OR REPLACE FUNCTION public.increment_daily_recommendation_usage(
  profile_id uuid,
  session_id uuid,
  recommendations_count integer,
  daily_limit integer DEFAULT NULL
)
RETURNS TABLE (
  usage_date date,
  recommendations_used integer,
  sessions_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_date date := (now() AT TIME ZONE 'utc')::date;
  v_row public.profile_recommendation_usage_daily%ROWTYPE;
BEGIN
  IF recommendations_count IS NULL OR recommendations_count <= 0 THEN
    RAISE EXCEPTION 'recommendations_count must be > 0';
  END IF;

  -- Ownership check (caller JWT)
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = profile_id AND p.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Dedupe retries
  IF EXISTS (SELECT 1 FROM public.recommendation_usage_events e WHERE e.session_id = session_id) THEN
    SELECT * INTO v_row
    FROM public.profile_recommendation_usage_daily d
    WHERE d.profile_id = increment_daily_recommendation_usage.profile_id AND d.usage_date = v_date;

    RETURN QUERY SELECT v_date, COALESCE(v_row.recommendations_used, 0), COALESCE(v_row.sessions_count, 0);
    RETURN;
  END IF;

  -- Lock the daily row to avoid race conditions
  INSERT INTO public.profile_recommendation_usage_daily (profile_id, usage_date, recommendations_used, sessions_count)
  VALUES (profile_id, v_date, 0, 0)
  ON CONFLICT (profile_id, usage_date) DO NOTHING;

  SELECT * INTO v_row
  FROM public.profile_recommendation_usage_daily d
  WHERE d.profile_id = increment_daily_recommendation_usage.profile_id AND d.usage_date = v_date
  FOR UPDATE;

  IF daily_limit IS NOT NULL AND (v_row.recommendations_used + recommendations_count) > daily_limit THEN
    RAISE EXCEPTION 'daily_limit_exceeded';
  END IF;

  INSERT INTO public.recommendation_usage_events (session_id, profile_id, recommendations_used)
  VALUES (session_id, profile_id, recommendations_count);

  UPDATE public.profile_recommendation_usage_daily d
  SET recommendations_used = d.recommendations_used + recommendations_count,
      sessions_count = d.sessions_count + 1,
      updated_at = now()
  WHERE d.profile_id = increment_daily_recommendation_usage.profile_id AND d.usage_date = v_date
  RETURNING * INTO v_row;

  RETURN QUERY SELECT v_date, v_row.recommendations_used, v_row.sessions_count;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_daily_recommendation_usage(uuid, uuid, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_daily_recommendation_usage(uuid, uuid, integer, integer) TO authenticated;
