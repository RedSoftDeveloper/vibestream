-- Adds subscription tier used for server-side entitlement checks.
-- Expected values: 'free' | 'premium'

ALTER TABLE public.app_users
ADD COLUMN IF NOT EXISTS subscription_tier text NOT NULL DEFAULT 'free';

-- Optional: index for faster filtering/analytics (not required for core flows)
CREATE INDEX IF NOT EXISTS idx_app_users_subscription_tier ON public.app_users(subscription_tier);
