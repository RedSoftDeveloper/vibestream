
// supabase/functions/create_recommendation_session/feedback.ts
import { InteractionAction } from "./types.ts";

export function getFeedbackWeight(createdAtIso: string): number {
  const ms = Date.now() - new Date(createdAtIso).getTime();
  const days = ms / (24 * 60 * 60 * 1000);
  if (days <= 7) return 1.0;
  if (days <= 30) return 0.5;
  return 0.25;
}

export function getNoteFromExtra(extra: any): string | null {
  const s = typeof extra?.feedback_text === "string" ? extra.feedback_text.trim() : "";
  if (s) return s;
  const fallback = typeof extra?.notes === "string" ? extra.notes.trim() : "";
  return fallback || null;
}

export function getFeedbackSentiment(
  action: InteractionAction,
  rating: number | null,
  extra: any,
): "positive" | "negative" | "neutral" {
  const wouldWatchAgain = extra?.would_watch_again === true;
  const quickTags: string[] = Array.isArray(extra?.quick_tags) ? extra.quick_tags.map((x: any) => String(x).toLowerCase()) : [];
  const hasNegativeTag = quickTags.some((t) => t.includes("too slow")) || quickTags.some((t) => t.includes("boring")) || quickTags.some((t) => t.includes("bad"));
  const hasPositiveTag = quickTags.some((t) => t.includes("great")) || quickTags.some((t) => t.includes("amazing")) || quickTags.some((t) => t.includes("excellent"));

  if (rating !== null) {
    if (rating >= 4) return "positive";
    if (rating <= 2) return "negative";
    if (rating === 3) return "neutral";
  }
  if (action === "feedback" && wouldWatchAgain) return "positive";
  if (action === "feedback" && hasNegativeTag) return "negative";
  if (action === "feedback" && hasPositiveTag) return "positive";
  if (action === "like") return "positive";
  if (action === "dislike") return "negative";
  if (action === "skip") return "negative";
  return "neutral";
}

export function topKeysByScore(m: Map<string, number>, max: number): string[] {
  return Array.from(m.entries()).sort((a, b) => b[1] - a[1]).slice(0, max).map((x) => x[0]);
}

export function topNotes(list: Array<{ text: string; w: number; at: string }>, max: number): string[] {
  return list.sort((a, b) => b.w - a.w).slice(0, max).map((x) => x.text);
}
