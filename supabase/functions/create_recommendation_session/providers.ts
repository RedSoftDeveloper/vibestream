
// supabase/functions/create_recommendation_session/providers.ts
import { AvailabilityType, WatchProvidersResult, WatchProviderWithAvailability } from "./types.ts";

export function pickProvidersForRegion(watchJson: any, region: string): WatchProvidersResult {
  const regionData = watchJson?.results?.[region] ?? null;
  if (!regionData) return { link: null, providers: [], providerAvailability: [] };

  const providerAvailability: WatchProviderWithAvailability[] = [];
  const availabilityTypes: Array<{ key: string; type: AvailabilityType }> = [
    { key: "flatrate", type: "flatrate" },
    { key: "free", type: "free" },
    { key: "ads", type: "ads" },
    { key: "rent", type: "rent" },
    { key: "buy", type: "buy" },
  ];

  for (const { key, type } of availabilityTypes) {
    const list = regionData[key];
    if (Array.isArray(list)) {
      for (const p of list) {
        if (p?.provider_id != null && p?.provider_name) {
          providerAvailability.push({
            provider_id: p.provider_id,
            name: p.provider_name,
            logo_url: p.logo_path ? `https://image.tmdb.org/t/p/w92${p.logo_path}` : null,
            availability_type: type,
          });
        }
      }
    }
  }

  const seen = new Set<number>();
  const providers = providerAvailability
    .filter((p) => (seen.has(p.provider_id) ? false : (seen.add(p.provider_id), true)))
    .map(({ provider_id, name, logo_url }) => ({ provider_id, name, logo_url }));

  return { link: regionData.link ?? null, providers, providerAvailability };
}
