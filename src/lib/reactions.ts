export const REACTION_TYPES = ["like", "cute", "funny", "wow"] as const;
export type ReactionType = (typeof REACTION_TYPES)[number];

export const REACTION_META: Record<ReactionType, { emoji: string; label: string }> = {
  like: { emoji: "👍", label: "좋아요" },
  cute: { emoji: "🥰", label: "귀여워" },
  funny: { emoji: "😆", label: "웃겨요" },
  wow: { emoji: "😮", label: "놀라워" },
};

export function totalReactions(counts: Record<string, number>): number {
  return Object.values(counts).reduce((sum, n) => sum + n, 0);
}
