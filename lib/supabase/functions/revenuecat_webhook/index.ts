/// RevenueCat Webhook handler for keeping `public.app_users.subscription_tier` in sync.
///
/// Expected integration contract:
/// - RevenueCat `app_user_id` should be set to the Supabase Auth user id (UUID).
///   (i.e., when you configure Purchases in the client, identify with user.id)
/// - This function updates `public.app_users.subscription_tier` to 'premium' or 'free'.
///
/// Security:
/// - Validates a shared secret provided via header:
///   - `Authorization: Bearer <secret>` OR
///   - `x-revenuecat-webhook-secret: <secret>`
///
/// Configuration:
/// - Set `REVENUECAT_WEBHOOK_SECRET`
/// - Optionally set `REVENUECAT_PREMIUM_ENTITLEMENTS` (comma-separated)
/// - Optionally set `REVENUECAT_PREMIUM_PRODUCT_IDS` (comma-separated)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-revenuecat-webhook-secret",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type RevenueCatEventContainer = {
  api_version?: string;
  event?: RevenueCatEvent;
};

type RevenueCatEvent = {
  type?: string;
  app_user_id?: string;
  product_id?: string;
  entitlement_ids?: string[];
  expiration_at_ms?: number | null;
  purchased_at_ms?: number | null;
  environment?: string;
  [key: string]: unknown;
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

function getBearerToken(authorizationHeader: string | null): string | null {
  if (!authorizationHeader) return null;
  const parts = authorizationHeader.split(" ");
  if (parts.length !== 2) return null;
  if (parts[0].toLowerCase() !== "bearer") return null;
  return parts[1];
}

function parseCsvEnv(envValue: string | undefined): string[] {
  if (!envValue) return [];
  return envValue
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function isPremiumFromEvent(event: RevenueCatEvent, nowMs: number, premiumEntitlements: string[], premiumProductIds: string[]): boolean {
  const entitlementIds = Array.isArray(event.entitlement_ids) ? event.entitlement_ids : [];
  const hasPremiumEntitlement = premiumEntitlements.length > 0
    ? entitlementIds.some((id) => premiumEntitlements.includes(id))
    : entitlementIds.includes("premium");

  const hasPremiumProduct = premiumProductIds.length > 0
    ? (typeof event.product_id === "string" && premiumProductIds.includes(event.product_id))
    : false;

  const hasAnyPremiumMarker = hasPremiumEntitlement || hasPremiumProduct;
  if (!hasAnyPremiumMarker) return false;

  // If RevenueCat provides an expiration timestamp, ensure it's still active.
  const exp = typeof event.expiration_at_ms === "number" ? event.expiration_at_ms : null;
  if (exp === null) return true; // treat as non-expiring lifetime.

  return exp > nowMs;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse(405, { error: "Method not allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  if (!secret) return jsonResponse(500, { error: "Missing REVENUECAT_WEBHOOK_SECRET" });

  const bearer = getBearerToken(req.headers.get("authorization"));
  const headerSecret = req.headers.get("x-revenuecat-webhook-secret");
  const providedSecret = bearer ?? headerSecret;

  if (!providedSecret || providedSecret !== secret) {
    return jsonResponse(401, { error: "Unauthorized" });
  }

  let payload: RevenueCatEventContainer;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse(400, { error: "Invalid JSON" });
  }

  const event = payload.event;
  if (!event || typeof event !== "object") return jsonResponse(400, { error: "Missing event" });

  const appUserId = typeof event.app_user_id === "string" ? event.app_user_id : "";
  if (!appUserId) {
    return jsonResponse(400, { error: "Missing event.app_user_id" });
  }

  const premiumEntitlements = parseCsvEnv(Deno.env.get("REVENUECAT_PREMIUM_ENTITLEMENTS"));
  const premiumProductIds = parseCsvEnv(Deno.env.get("REVENUECAT_PREMIUM_PRODUCT_IDS"));

  const nowMs = Date.now();
  const shouldBePremium = isPremiumFromEvent(event, nowMs, premiumEntitlements, premiumProductIds);
  const newTier = shouldBePremium ? "premium" : "free";

  // Use service role to bypass RLS for server-side updates.
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, { error: "Missing Supabase environment variables" });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "X-Client-Info": "vibestream-revenuecat-webhook" } },
  });

  const { data, error } = await supabase
    .from("app_users")
    .update({ subscription_tier: newTier })
    .eq("id", appUserId)
    .select("id, subscription_tier")
    .maybeSingle();

  if (error) {
    return jsonResponse(500, {
      error: "Failed updating app_users.subscription_tier",
      details: error.message,
      app_user_id: appUserId,
    });
  }

  if (!data) {
    // Not found: returning 200 prevents webhook retries if you already deleted the user.
    return jsonResponse(200, {
      ok: true,
      updated: false,
      reason: "app_user_id not found in app_users",
      app_user_id: appUserId,
      desired_tier: newTier,
    });
  }

  return jsonResponse(200, {
    ok: true,
    updated: true,
    app_user_id: data.id,
    subscription_tier: data.subscription_tier,
    event_type: event.type ?? null,
    environment: event.environment ?? null,
  });
});
