# VibeStream Supabase Database Schema

This document describes the Supabase database schema used by VibeStream.

---

## Tables Overview

| Table | Purpose |
|-------|---------|
| `app_users` | Core user account data (linked to auth.users) |
| `profiles` | User profiles (multiple per account, like Netflix profiles) |
| `profile_preferences` | Quiz/preference answers per profile |
| `media_titles` | Movie/TV show metadata from TMDB/OMDB |
| `streaming_providers` | Master list of streaming providers (Netflix, Disney+, etc.) |
| `title_streaming_availability` | Links titles to providers per region |
| `recommendation_sessions` | Mood quiz sessions with AI responses |
| `recommendation_items` | Individual recommendations per session |
| `profile_title_interactions` | User interactions (likes, dislikes, feedback, etc.) |
| `profile_favorites` | User's favorite titles (dedicated favorites list) |
| `app_feedback` | User feedback about the app itself |

---

## Detailed Schema

### `app_users`
Core user account information, linked to Supabase Auth.

```sql
CREATE TABLE public.app_users (
  id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  display_name text,
  avatar_url text,
  region text NOT NULL DEFAULT 'SE'::text,
  locale text NOT NULL DEFAULT 'en'::text,
  subscription_tier text NOT NULL DEFAULT 'free'::text,
  last_active_profile_id uuid,
  CONSTRAINT app_users_pkey PRIMARY KEY (id),
  CONSTRAINT app_users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT app_users_last_active_profile_fk FOREIGN KEY (last_active_profile_id) REFERENCES public.profiles(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key, matches `auth.users.id` |
| `created_at` | timestamptz | Account creation timestamp |
| `display_name` | text | Optional display name |
| `avatar_url` | text | Profile avatar URL |
| `region` | text | User region code (default: 'SE') |
| `locale` | text | Language locale (default: 'en') |
| `subscription_tier` | text | Subscription tier ('free' or 'premium') |
| `last_active_profile_id` | uuid | FK to last used profile |

---

### `profiles`
Multiple profiles per user (like Netflix profiles).

```sql
CREATE TABLE public.profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  context_type text,
  emoji text,
  avatar_url text,
  description text,
  country_code text,
  country_name text,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_users(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK to app_users |
| `name` | text | Profile name |
| `context_type` | text | Profile context (e.g., 'family', 'solo') |
| `emoji` | text | Profile emoji avatar |
| `avatar_url` | text | Profile image URL |
| `description` | text | Profile description |
| `country_code` | text | ISO 3166-1 alpha-2 country code (e.g., SE, US, GB) |
| `country_name` | text | Human-readable country name |
| `is_default` | boolean | Is this the default profile |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |
| `deleted_at` | timestamptz | Soft delete timestamp |

---

### `profile_preferences`
Stores quiz/onboarding answers per profile.

```sql
CREATE TABLE public.profile_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL UNIQUE,
  answers jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profile_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT profile_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `profile_id` | uuid | FK to profiles (unique) |
| `answers` | jsonb | Quiz/preference answers |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

---

### `media_titles`
Movie and TV show metadata from TMDB/OMDB.

```sql
CREATE TABLE public.media_titles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tmdb_id bigint NOT NULL,
  tmdb_type text NOT NULL CHECK (tmdb_type = ANY (ARRAY['movie'::text, 'tv'::text])),
  title text NOT NULL,
  overview text,
  genres text[],
  year integer,
  runtime_minutes integer,
  poster_url text,
  backdrop_url text,
  imdb_id text,
  imdb_rating numeric,
  age_rating text,
  raw_tmdb jsonb,
  raw_omdb jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  director text,
  starring text[],
  CONSTRAINT media_titles_pkey PRIMARY KEY (id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `tmdb_id` | bigint | The Movie Database ID |
| `tmdb_type` | text | 'movie' or 'tv' |
| `title` | text | Title name |
| `overview` | text | Plot summary |
| `genres` | text[] | Array of genre names |
| `year` | integer | Release year |
| `runtime_minutes` | integer | Runtime in minutes |
| `poster_url` | text | Poster image URL |
| `backdrop_url` | text | Backdrop image URL |
| `imdb_id` | text | IMDB ID |
| `imdb_rating` | numeric | IMDB rating (0-10) |
| `age_rating` | text | Age rating (PG, R, etc.) |
| `raw_tmdb` | jsonb | Raw TMDB API response |
| `raw_omdb` | jsonb | Raw OMDB API response |
| `director` | text | Director name |
| `starring` | text[] | Array of main cast |

---

### `recommendation_sessions`
Mood quiz sessions with AI-generated recommendations.

```sql
CREATE TABLE public.recommendation_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  session_type text NOT NULL, -- 'mood_quiz', 'quick_match', etc.
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  openai_response jsonb,
  mood_label text,
  mood_tags text[],
  top_title_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT recommendation_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT recommendation_sessions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id),
  CONSTRAINT recommendation_sessions_top_title_id_fkey FOREIGN KEY (top_title_id) REFERENCES public.media_titles(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `profile_id` | uuid | FK to profiles |
| `session_type` | text | 'mood_quiz', 'quick_match', etc. |
| `input_payload` | jsonb | Quiz answers/input data |
| `openai_response` | jsonb | Raw AI response |
| `mood_label` | text | Detected mood label |
| `mood_tags` | text[] | Mood/vibe tags |
| `top_title_id` | uuid | FK to best match title |
| `created_at` | timestamptz | Session timestamp |

---

### `recommendation_items`
Individual recommendations within a session.

```sql
CREATE TABLE public.recommendation_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  title_id uuid NOT NULL,
  rank_index integer NOT NULL,
  openai_reason text,
  match_score integer CHECK (match_score IS NULL OR match_score >= 0 AND match_score <= 100),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT recommendation_items_pkey PRIMARY KEY (id),
  CONSTRAINT recommendation_items_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.recommendation_sessions(id),
  CONSTRAINT recommendation_items_title_id_fkey FOREIGN KEY (title_id) REFERENCES public.media_titles(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `session_id` | uuid | FK to recommendation_sessions |
| `title_id` | uuid | FK to media_titles |
| `rank_index` | integer | Position in results (0-indexed) |
| `openai_reason` | text | AI explanation for recommendation |
| `match_score` | integer | Match percentage (0-100) |
| `created_at` | timestamptz | Creation timestamp |

---

### `profile_title_interactions`
All user interactions with titles (likes, dislikes, feedback, etc.).

```sql
CREATE TABLE public.profile_title_interactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  title_id uuid NOT NULL,
  session_id uuid,
  action text NOT NULL, -- 'like', 'dislike', 'skip', 'open', 'play', 'complete', 'feedback'
  rating smallint,
  source text,
  extra jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profile_title_interactions_pkey PRIMARY KEY (id),
  CONSTRAINT profile_title_interactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id),
  CONSTRAINT profile_title_interactions_title_id_fkey FOREIGN KEY (title_id) REFERENCES public.media_titles(id),
  CONSTRAINT profile_title_interactions_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.recommendation_sessions(id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `profile_id` | uuid | FK to profiles |
| `title_id` | uuid | FK to media_titles |
| `session_id` | uuid | FK to recommendation_sessions (optional) |
| `action` | text | Interaction type (see below) |
| `rating` | smallint | Rating value (context-dependent) |
| `source` | text | Where interaction occurred |
| `extra` | jsonb | Additional data |
| `created_at` | timestamptz | Interaction timestamp |

#### Action Types
| Action | Description | Sentiment |
|--------|-------------|-----------|
| `impression` | Title was shown to user | Neutral |
| `open` | User opened title details | Neutral |
| `play` | User started watching | Neutral |
| `complete` | User finished watching | Soft exclude |
| `like` | User liked/swiped right | Positive |
| `dislike` | User disliked/swiped left | Negative (hard exclude) |
| `skip` | User skipped | Negative |
| `feedback` | User submitted detailed feedback | Based on rating/tags |

#### Source Values
| Source | Description |
|--------|-------------|
| `onboarding_swipe` | During onboarding flow |
| `quick_match` | Quick match feature |
| `mood_results` | After mood quiz results |
| `home` | From home page |
| `title_details` | From title details page |

---

### `profile_favorites`
Dedicated table for user's favorite titles (separate from interactions for cleaner queries).

```sql
CREATE TABLE IF NOT EXISTS public.profile_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title_id UUID NOT NULL REFERENCES public.media_titles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(profile_id, title_id)
);

-- Index for faster queries
CREATE INDEX idx_profile_favorites_profile_id ON profile_favorites(profile_id);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `profile_id` | uuid | FK to profiles (CASCADE delete) |
| `title_id` | uuid | FK to media_titles (CASCADE delete) |
| `created_at` | timestamptz | When title was favorited |

#### RLS Policies
```sql
ALTER TABLE profile_favorites ENABLE ROW LEVEL SECURITY;

-- Users can view favorites for their own profiles
CREATE POLICY "Users can view own favorites" ON profile_favorites
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

-- Users can add favorites to their own profiles
CREATE POLICY "Users can add own favorites" ON profile_favorites
  FOR INSERT WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

-- Users can remove their own favorites
CREATE POLICY "Users can delete own favorites" ON profile_favorites
  FOR DELETE USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );
```

---

## Feedback Storage Strategy

User feedback is stored in `profile_title_interactions` with `action = 'feedback'`:

```json
{
  "profile_id": "uuid",
  "title_id": "uuid",
  "session_id": "uuid (optional)",
  "action": "feedback",
  "rating": 4,  // Mood match rating (1-5)
  "source": "title_details",
  "extra": {
    "feedback_text": "Great recommendation but a bit slow",
    "would_watch_again": true,
    "quick_tags": ["Great acting", "Too slow"]
  }
}
```

### Feedback Fields in `extra`
| Field | Type | Description |
|-------|------|-------------|
| `feedback_text` | string | Optional written feedback |
| `would_watch_again` | boolean | Preference for similar content |
| `quick_tags` | string[] | Selected quick feedback tags |

### How Feedback Improves Recommendations

The edge function (`create_recommendation_session`) analyzes feedback to build user preference signals:

1. **Mood Match Rating (1-5)**
   - Rating ≥ 4 → **Positive sentiment** (boost similar genres/moods)
   - Rating ≤ 2 → **Negative sentiment** (hard exclude title, reduce similar recommendations)
   - Rating = 3 → **Neutral sentiment** (soft exclude, won't recommend same title again)

2. **Would Watch Again**
   - `true` → **Positive sentiment** for the feedback action
   - `false` → Implicit negative preference

3. **Quick Tags Sentiment Detection**
   The edge function looks for specific keywords in `quick_tags`:
   
   | Sentiment | Keywords Detected | Example Tags |
   |-----------|-------------------|--------------|
   | **Positive** | "great", "amazing", "excellent" | "Great acting", "Amazing story", "Excellent pacing" |
   | **Negative** | "too slow", "boring", "bad" | "Too slow", "Boring plot", "Bad ending" |
   | **Neutral** | Other tags | "Predictable", "Too emotional", "Wrong genre" |

4. **Feedback Weight by Recency**
   - Last 7 days: **1.0 weight** (full impact)
   - Last 30 days: **0.5 weight**
   - Older: **0.25 weight**

5. **Exclusion Rules**
   - **Hard Exclude:** Titles with negative sentiment are NEVER recommended again
   - **Soft Exclude:** Completed titles or neutral ratings are avoided but not strictly banned

---

## Entity Relationships

```
auth.users
    └── app_users (1:1)
            └── profiles (1:N)
                    ├── profile_preferences (1:1)
                    ├── recommendation_sessions (1:N)
                    │       └── recommendation_items (1:N)
                    │               └── media_titles (N:1)
                    ├── profile_title_interactions (1:N)
                    │       ├── media_titles (N:1)
                    │       └── recommendation_sessions (N:1, optional)
                    └── profile_favorites (1:N)
                            └── media_titles (N:1)
```

---

## Indexes (Recommended)

```sql
-- Fast lookup for user profiles
CREATE INDEX idx_profiles_user_id ON profiles(user_id);

-- Fast lookup for sessions by profile
CREATE INDEX idx_recommendation_sessions_profile_id ON recommendation_sessions(profile_id);

-- Fast lookup for items by session
CREATE INDEX idx_recommendation_items_session_id ON recommendation_items(session_id);

-- Fast lookup for interactions by profile and title
CREATE INDEX idx_profile_title_interactions_profile_id ON profile_title_interactions(profile_id);
CREATE INDEX idx_profile_title_interactions_title_id ON profile_title_interactions(title_id);

-- Filter by action type
CREATE INDEX idx_profile_title_interactions_action ON profile_title_interactions(action);

-- Fast lookup for favorites by profile
CREATE INDEX idx_profile_favorites_profile_id ON profile_favorites(profile_id);
```

---

## Row Level Security (RLS)

All tables should have RLS enabled. Example policies:

```sql
-- app_users: Users can only read/update their own data
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON app_users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own data" ON app_users
  FOR UPDATE USING (auth.uid() = id);

-- profiles: Users can manage their own profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own profiles" ON profiles
  FOR ALL USING (user_id = auth.uid());

-- profile_title_interactions: Users can manage interactions for their profiles
ALTER TABLE profile_title_interactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own interactions" ON profile_title_interactions
  FOR ALL USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

-- profile_favorites: Users can manage favorites for their profiles
ALTER TABLE profile_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own favorites" ON profile_favorites
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );
CREATE POLICY "Users can add own favorites" ON profile_favorites
  FOR INSERT WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );
CREATE POLICY "Users can delete own favorites" ON profile_favorites
  FOR DELETE USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );
```

---

### `app_feedback`
User feedback about the VibeStream app itself (not title feedback).

```sql
CREATE TABLE IF NOT EXISTS public.app_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  feedback_text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK to app_users (CASCADE delete) |
| `profile_id` | uuid | FK to profiles (CASCADE delete) |
| `feedback_text` | text | User's feedback (max 400 chars enforced by app) |
| `created_at` | timestamptz | When feedback was submitted |

#### RLS Policies
```sql
ALTER TABLE app_feedback ENABLE ROW LEVEL SECURITY;

-- Users can view their own feedback
CREATE POLICY "Users can view own feedback" ON app_feedback
  FOR SELECT USING (user_id = auth.uid());

-- Users can submit feedback
CREATE POLICY "Users can submit feedback" ON app_feedback
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can delete their own feedback
CREATE POLICY "Users can delete own feedback" ON app_feedback
  FOR DELETE USING (user_id = auth.uid());
```

---

---

### `streaming_providers`
Master list of streaming providers (Netflix, Disney+, Hulu, etc.).

```sql
CREATE TABLE public.streaming_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tmdb_provider_id integer NOT NULL UNIQUE,
  name text NOT NULL,
  logo_url text,
  display_priority integer NOT NULL DEFAULT 100,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT streaming_providers_pkey PRIMARY KEY (id)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `tmdb_provider_id` | integer | TMDB Watch Provider ID (unique) |
| `name` | text | Provider name (Netflix, Disney+, etc.) |
| `logo_url` | text | Provider logo URL from TMDB |
| `display_priority` | integer | Lower = higher priority for display ordering |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

#### RLS Policies
```sql
ALTER TABLE streaming_providers ENABLE ROW LEVEL SECURITY;

-- All users can read streaming providers (public catalog)
CREATE POLICY "Anyone can read providers" ON streaming_providers
  FOR SELECT USING (true);
```

---

### `title_streaming_availability`
Junction table linking media_titles to streaming_providers per region.

```sql
CREATE TABLE public.title_streaming_availability (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title_id uuid NOT NULL REFERENCES public.media_titles(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.streaming_providers(id) ON DELETE CASCADE,
  region text NOT NULL DEFAULT 'SE',
  availability_type text NOT NULL DEFAULT 'flatrate' CHECK (availability_type IN ('flatrate', 'rent', 'buy', 'free', 'ads')),
  watch_link text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT title_streaming_availability_pkey PRIMARY KEY (id),
  UNIQUE(title_id, provider_id, region, availability_type)
);
```

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `title_id` | uuid | FK to media_titles |
| `provider_id` | uuid | FK to streaming_providers |
| `region` | text | ISO 3166-1 alpha-2 country code (SE, US, GB, etc.) |
| `availability_type` | text | How available: flatrate, rent, buy, free, ads |
| `watch_link` | text | Direct link to watch on provider |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

#### Availability Types
| Type | Description |
|------|-------------|
| `flatrate` | Included with subscription (Netflix, Disney+, etc.) |
| `rent` | Available for rental |
| `buy` | Available for purchase |
| `free` | Free with ads or completely free |
| `ads` | Free with ads |

#### RLS Policies
```sql
ALTER TABLE title_streaming_availability ENABLE ROW LEVEL SECURITY;

-- All users can read streaming availability (public catalog)
CREATE POLICY "Anyone can read availability" ON title_streaming_availability
  FOR SELECT USING (true);
```

---

## Entity Relationships (Updated)

```
auth.users
    └── app_users (1:1)
            └── profiles (1:N)
                    ├── profile_preferences (1:1)
                    ├── recommendation_sessions (1:N)
                    │       └── recommendation_items (1:N)
                    │               └── media_titles (N:1)
                    │                       └── title_streaming_availability (1:N)
                    │                               └── streaming_providers (N:1)
                    ├── profile_title_interactions (1:N)
                    │       ├── media_titles (N:1)
                    │       └── recommendation_sessions (N:1, optional)
                    └── profile_favorites (1:N)
                            └── media_titles (N:1)
```

---

*Last updated: July 2025*
