-- VibeStream Row Level Security Policies
-- This file contains all RLS policies for secure data access

-- ====================================
-- 1. APP USERS POLICIES
-- ====================================
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
DROP POLICY IF EXISTS app_users_select_policy ON public.app_users;
CREATE POLICY app_users_select_policy ON public.app_users
  FOR SELECT
  USING (auth.uid() = id);

-- Users can insert their own data (for signup)
DROP POLICY IF EXISTS app_users_insert_policy ON public.app_users;
CREATE POLICY app_users_insert_policy ON public.app_users
  FOR INSERT
  WITH CHECK (true);

-- Users can update their own data
DROP POLICY IF EXISTS app_users_update_policy ON public.app_users;
CREATE POLICY app_users_update_policy ON public.app_users
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (true);

-- Users can delete their own data
DROP POLICY IF EXISTS app_users_delete_policy ON public.app_users;
CREATE POLICY app_users_delete_policy ON public.app_users
  FOR DELETE
  USING (auth.uid() = id);

-- ====================================
-- 2. USER PROFILES POLICIES
-- ====================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profiles
DROP POLICY IF EXISTS user_profiles_select_policy ON public.user_profiles;
CREATE POLICY user_profiles_select_policy ON public.user_profiles
  FOR SELECT
  USING (
    user_id IN (SELECT id FROM public.app_users WHERE auth.uid() = id)
  );

-- Users can insert their own profiles
DROP POLICY IF EXISTS user_profiles_insert_policy ON public.user_profiles;
CREATE POLICY user_profiles_insert_policy ON public.user_profiles
  FOR INSERT
  WITH CHECK (
    user_id IN (SELECT id FROM public.app_users WHERE auth.uid() = id)
  );

-- Users can update their own profiles
DROP POLICY IF EXISTS user_profiles_update_policy ON public.user_profiles;
CREATE POLICY user_profiles_update_policy ON public.user_profiles
  FOR UPDATE
  USING (
    user_id IN (SELECT id FROM public.app_users WHERE auth.uid() = id)
  )
  WITH CHECK (
    user_id IN (SELECT id FROM public.app_users WHERE auth.uid() = id)
  );

-- Users can delete their own profiles
DROP POLICY IF EXISTS user_profiles_delete_policy ON public.user_profiles;
CREATE POLICY user_profiles_delete_policy ON public.user_profiles
  FOR DELETE
  USING (
    user_id IN (SELECT id FROM public.app_users WHERE auth.uid() = id)
  );

-- ====================================
-- 3. MEDIA TITLES POLICIES
-- ====================================
ALTER TABLE public.media_titles ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read media titles (public catalog)
DROP POLICY IF EXISTS media_titles_select_policy ON public.media_titles;
CREATE POLICY media_titles_select_policy ON public.media_titles
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only authenticated users can insert media titles (typically through edge functions)
DROP POLICY IF EXISTS media_titles_insert_policy ON public.media_titles;
CREATE POLICY media_titles_insert_policy ON public.media_titles
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Only authenticated users can update media titles
DROP POLICY IF EXISTS media_titles_update_policy ON public.media_titles;
CREATE POLICY media_titles_update_policy ON public.media_titles
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Only authenticated users can delete media titles
DROP POLICY IF EXISTS media_titles_delete_policy ON public.media_titles;
CREATE POLICY media_titles_delete_policy ON public.media_titles
  FOR DELETE
  USING (auth.role() = 'authenticated');

-- ====================================
-- 4. RECOMMENDATION SESSIONS POLICIES
-- ====================================
ALTER TABLE public.recommendation_sessions ENABLE ROW LEVEL SECURITY;

-- Users can read sessions for their own profiles
DROP POLICY IF EXISTS recommendation_sessions_select_policy ON public.recommendation_sessions;
CREATE POLICY recommendation_sessions_select_policy ON public.recommendation_sessions
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
    )
  );

-- Users can insert sessions for their own profiles
DROP POLICY IF EXISTS recommendation_sessions_insert_policy ON public.recommendation_sessions;
CREATE POLICY recommendation_sessions_insert_policy ON public.recommendation_sessions
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
    )
  );

-- Users can update sessions for their own profiles
DROP POLICY IF EXISTS recommendation_sessions_update_policy ON public.recommendation_sessions;
CREATE POLICY recommendation_sessions_update_policy ON public.recommendation_sessions
  FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
    )
  );

-- Users can delete sessions for their own profiles
DROP POLICY IF EXISTS recommendation_sessions_delete_policy ON public.recommendation_sessions;
CREATE POLICY recommendation_sessions_delete_policy ON public.recommendation_sessions
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
    )
  );

-- ====================================
-- 5. RECOMMENDATION ITEMS POLICIES
-- ====================================
ALTER TABLE public.recommendation_items ENABLE ROW LEVEL SECURITY;

-- Users can read items for their own sessions
DROP POLICY IF EXISTS recommendation_items_select_policy ON public.recommendation_items;
CREATE POLICY recommendation_items_select_policy ON public.recommendation_items
  FOR SELECT
  USING (
    session_id IN (
      SELECT id FROM public.recommendation_sessions 
      WHERE profile_id IN (
        SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Users can insert items for their own sessions
DROP POLICY IF EXISTS recommendation_items_insert_policy ON public.recommendation_items;
CREATE POLICY recommendation_items_insert_policy ON public.recommendation_items
  FOR INSERT
  WITH CHECK (
    session_id IN (
      SELECT id FROM public.recommendation_sessions 
      WHERE profile_id IN (
        SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Users can update items for their own sessions
DROP POLICY IF EXISTS recommendation_items_update_policy ON public.recommendation_items;
CREATE POLICY recommendation_items_update_policy ON public.recommendation_items
  FOR UPDATE
  USING (
    session_id IN (
      SELECT id FROM public.recommendation_sessions 
      WHERE profile_id IN (
        SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    session_id IN (
      SELECT id FROM public.recommendation_sessions 
      WHERE profile_id IN (
        SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Users can delete items for their own sessions
DROP POLICY IF EXISTS recommendation_items_delete_policy ON public.recommendation_items;
CREATE POLICY recommendation_items_delete_policy ON public.recommendation_items
  FOR DELETE
  USING (
    session_id IN (
      SELECT id FROM public.recommendation_sessions 
      WHERE profile_id IN (
        SELECT id FROM public.user_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- ====================================
-- 6. PROFILE FAVORITES POLICIES
-- ====================================
ALTER TABLE public.profile_favorites ENABLE ROW LEVEL SECURITY;

-- Users can read favorites for their own profiles
DROP POLICY IF EXISTS profile_favorites_select_policy ON public.profile_favorites;
CREATE POLICY profile_favorites_select_policy ON public.profile_favorites
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.profiles WHERE user_id = auth.uid()
    )
  );

-- Users can insert favorites for their own profiles
DROP POLICY IF EXISTS profile_favorites_insert_policy ON public.profile_favorites;
CREATE POLICY profile_favorites_insert_policy ON public.profile_favorites
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.profiles WHERE user_id = auth.uid()
    )
  );

-- Users can delete favorites for their own profiles
DROP POLICY IF EXISTS profile_favorites_delete_policy ON public.profile_favorites;
CREATE POLICY profile_favorites_delete_policy ON public.profile_favorites
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.profiles WHERE user_id = auth.uid()
    )
  );

-- ====================================
-- 7. APP FEEDBACK POLICIES
-- ====================================
ALTER TABLE public.app_feedback ENABLE ROW LEVEL SECURITY;

-- Users can read their own feedback
DROP POLICY IF EXISTS app_feedback_select_policy ON public.app_feedback;
CREATE POLICY app_feedback_select_policy ON public.app_feedback
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can insert their own feedback
DROP POLICY IF EXISTS app_feedback_insert_policy ON public.app_feedback;
CREATE POLICY app_feedback_insert_policy ON public.app_feedback
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own feedback
DROP POLICY IF EXISTS app_feedback_delete_policy ON public.app_feedback;
CREATE POLICY app_feedback_delete_policy ON public.app_feedback
  FOR DELETE
  USING (user_id = auth.uid());

-- ====================================
-- 8. STREAMING PROVIDERS POLICIES
-- ====================================
ALTER TABLE public.streaming_providers ENABLE ROW LEVEL SECURITY;

-- All users can read streaming providers (public catalog)
DROP POLICY IF EXISTS streaming_providers_select_policy ON public.streaming_providers;
CREATE POLICY streaming_providers_select_policy ON public.streaming_providers
  FOR SELECT
  USING (true);

-- ====================================
-- 9. TITLE STREAMING AVAILABILITY POLICIES
-- ====================================
ALTER TABLE public.title_streaming_availability ENABLE ROW LEVEL SECURITY;

-- All users can read streaming availability (public catalog)
DROP POLICY IF EXISTS title_streaming_availability_select_policy ON public.title_streaming_availability;
CREATE POLICY title_streaming_availability_select_policy ON public.title_streaming_availability
  FOR SELECT
  USING (true);
