"use client";

import { useState } from "react";
import { REACTION_TYPES, REACTION_META, type ReactionType } from "@/lib/reactions";

export default function ReactionPicker({
  mediaId,
  initialCounts,
  initialMyReaction,
}: {
  mediaId: string;
  initialCounts: Record<string, number>;
  initialMyReaction: string | null;
}) {
  const [counts, setCounts] = useState(initialCounts);
  const [myReaction, setMyReaction] = useState<string | null>(initialMyReaction);
  const [busy, setBusy] = useState(false);

  async function pick(type: ReactionType) {
    if (busy) return;
    setBusy(true);
    try {
      const isUnpick = myReaction === type;
      const res = await fetch(`/api/media/${mediaId}/reactions`, {
        method: isUnpick ? "DELETE" : "POST",
        headers: isUnpick ? undefined : { "Content-Type": "application/json" },
        body: isUnpick ? undefined : JSON.stringify({ type }),
      });
      if (res.ok) {
        const data = await res.json();
        setCounts(data.reactionCounts);
        setMyReaction(data.myReaction);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center justify-center gap-2 rounded-full border border-black/10 bg-white/90 px-2 py-2 shadow-lg backdrop-blur dark:border-white/10 dark:bg-zinc-900/90">
      {REACTION_TYPES.map((type) => {
        const meta = REACTION_META[type];
        const active = myReaction === type;
        const count = counts[type] ?? 0;
        return (
          <button
            key={type}
            onClick={() => pick(type)}
            disabled={busy}
            className={`flex flex-col items-center gap-0.5 rounded-full px-3 py-1.5 text-xs transition-colors disabled:opacity-50 ${
              active ? "bg-amber-100 dark:bg-amber-400/20" : "hover:bg-black/5 dark:hover:bg-white/10"
            }`}
          >
            <span className="text-xl leading-none">{meta.emoji}</span>
            <span className="text-zinc-500">
              {meta.label}
              {count > 0 ? ` ${count}` : ""}
            </span>
          </button>
        );
      })}
    </div>
  );
}
