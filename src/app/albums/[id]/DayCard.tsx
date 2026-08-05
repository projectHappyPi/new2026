"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { REACTION_TYPES, REACTION_META, totalReactions } from "@/lib/reactions";
import ShareMenu from "@/components/ShareMenu";

export interface DayMediaItem {
  id: string;
  originalFilename: string;
  mime: string;
  uploader: string;
  isVideo: boolean;
  thumbKinds: string[];
  reactionCounts: Record<string, number>;
}

interface CommentItem {
  id: string;
  content: string;
  author: string;
  createdAt: string;
}

function Thumb({ item, albumId, className }: { item: DayMediaItem; albumId: string; className: string }) {
  const hasReactions = totalReactions(item.reactionCounts) > 0;
  return (
    <Link href={`/albums/${albumId}/media/${item.id}`} className={`relative block overflow-hidden bg-zinc-200 dark:bg-zinc-800 ${className}`}>
      {item.thumbKinds.includes("thumb_800") ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={`/api/media/${item.id}/variant/thumb_800`} alt={item.originalFilename} className="h-full w-full object-cover" loading="lazy" />
      ) : (
        <div className="flex h-full w-full items-center justify-center text-2xl">{item.isVideo ? "🎬" : "🖼️"}</div>
      )}
      {item.isVideo && <span className="absolute left-1 top-1 rounded bg-black/60 px-1 text-[10px] text-white">▶</span>}
      {hasReactions && (
        <span className="absolute bottom-1.5 right-1.5 flex h-6 w-6 items-center justify-center rounded-full bg-white text-sm shadow dark:bg-zinc-900">
          ❤️
        </span>
      )}
    </Link>
  );
}

export default function DayCard({
  albumId,
  albumTitle,
  dayKey,
  dayLabel,
  items,
}: {
  albumId: string;
  albumTitle: string;
  dayKey: string;
  dayLabel: string;
  items: DayMediaItem[];
}) {
  const [comments, setComments] = useState<CommentItem[] | null>(null);
  const [commentText, setCommentText] = useState("");
  const [posting, setPosting] = useState(false);
  const [showComments, setShowComments] = useState(false);

  const loadComments = useCallback(async () => {
    const res = await fetch(`/api/albums/${albumId}/days/${dayKey}/comments`);
    if (res.ok) {
      const data = await res.json();
      setComments(data.comments);
    }
  }, [albumId, dayKey]);

  useEffect(() => {
    if (showComments && comments === null) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- lazy fetch on expand, setState is async (post-await)
      loadComments();
    }
  }, [showComments, comments, loadComments]);

  async function submitComment(e: React.FormEvent) {
    e.preventDefault();
    const content = commentText.trim();
    if (!content) return;
    setPosting(true);
    try {
      const res = await fetch(`/api/albums/${albumId}/days/${dayKey}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content }),
      });
      if (res.ok) {
        setCommentText("");
        await loadComments();
        setShowComments(true);
      }
    } finally {
      setPosting(false);
    }
  }

  const photoCount = items.filter((i) => !i.isVideo).length;
  const videoCount = items.filter((i) => i.isVideo).length;
  const big = items[0];
  const small1 = items[1];
  const small2 = items[2];
  const extraCount = items.length > 3 ? items.length - 2 : 0;

  const totals: Record<string, number> = {};
  for (const item of items) {
    for (const [type, count] of Object.entries(item.reactionCounts)) {
      totals[type] = (totals[type] ?? 0) + count;
    }
  }
  const uploader = big?.uploader;

  return (
    <div className="mb-6 overflow-hidden rounded-lg border border-black/10 dark:border-white/10">
      <div className="flex items-center justify-between px-3 pt-3">
        <h2 className="text-sm font-medium text-zinc-500">{dayLabel}</h2>
        <ShareMenu
          title={albumTitle}
          description={`${dayLabel} · 사진 ${photoCount}장`}
          path={`/albums/${albumId}/days/${dayKey}`}
          compact
          label="이 날짜 공유"
        />
      </div>

      {items.length === 0 ? null : (
        <div className="mt-2 grid h-64 grid-cols-3 grid-rows-2 gap-0.5 px-3">
          <Thumb item={big} albumId={albumId} className="col-span-2 row-span-2" />
          {small1 && <Thumb item={small1} albumId={albumId} className="col-span-1 row-span-1" />}
          {small2 &&
            (extraCount > 0 ? (
              <Link href={`/albums/${albumId}/days/${dayKey}`} className="relative col-span-1 row-span-1 block overflow-hidden bg-zinc-200 dark:bg-zinc-800">
                {small2.thumbKinds.includes("thumb_800") && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={`/api/media/${small2.id}/variant/thumb_800`} alt="" className="h-full w-full object-cover" loading="lazy" />
                )}
                <div className="absolute inset-0 flex items-center justify-center bg-black/55 px-1 text-center text-xs font-medium leading-tight text-white">
                  {photoCount}장의 사진{videoCount > 0 ? ` + ${videoCount}개의 동영상` : ""}
                </div>
              </Link>
            ) : (
              <Thumb item={small2} albumId={albumId} className="col-span-1 row-span-1" />
            ))}
        </div>
      )}

      <div className="flex flex-col gap-2 px-3 py-3">
        <div className="flex flex-wrap items-center gap-3 text-sm">
          {REACTION_TYPES.filter((t) => (totals[t] ?? 0) > 0).map((t) => (
            <span key={t} className="flex items-center gap-1 text-zinc-600 dark:text-zinc-400">
              <span>{REACTION_META[t].emoji}</span>
              <span className="text-xs">{totals[t]}</span>
            </span>
          ))}
          <button onClick={() => setShowComments((v) => !v)} className="flex items-center gap-1 text-zinc-500 hover:underline">
            💬 <span className="text-xs">{comments?.length ?? ""} 댓글</span>
          </button>
          {uploader && <span className="ml-auto text-xs text-zinc-400">By {uploader}</span>}
        </div>

        {showComments && (
          <div className="flex flex-col gap-2 border-t border-black/5 pt-2 dark:border-white/5">
            {comments === null ? (
              <p className="text-xs text-zinc-400">불러오는 중...</p>
            ) : comments.length === 0 ? (
              <p className="text-xs text-zinc-400">아직 댓글이 없습니다.</p>
            ) : (
              <ul className="flex flex-col gap-1">
                {comments.map((c) => (
                  <li key={c.id} className="text-xs">
                    <span className="font-medium">{c.author}</span> <span className="text-zinc-500">{c.content}</span>
                  </li>
                ))}
              </ul>
            )}
            <form onSubmit={submitComment} className="flex gap-2">
              <input
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
                placeholder="댓글 달기"
                className="flex-1 rounded border border-black/10 bg-transparent px-2 py-1 text-xs dark:border-white/10"
              />
              <button
                type="submit"
                disabled={posting || !commentText.trim()}
                className="rounded bg-amber-400 px-3 py-1 text-xs font-medium text-black hover:bg-amber-300 disabled:opacity-50"
              >
                등록
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}
