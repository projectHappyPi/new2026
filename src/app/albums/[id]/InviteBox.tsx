"use client";

import { useState } from "react";

export default function InviteBox({ albumId }: { albumId: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  async function createInvite() {
    setLoading(true);
    setCopied(false);
    try {
      const res = await fetch(`/api/albums/${albumId}/invites`, { method: "POST" });
      const data = await res.json();
      if (res.ok) setUrl(data.url);
    } finally {
      setLoading(false);
    }
  }

  async function copy() {
    if (!url) return;
    await navigator.clipboard.writeText(url);
    setCopied(true);
  }

  return (
    <div className="flex flex-col gap-2 rounded border border-black/10 p-3 text-sm dark:border-white/10">
      <div className="flex items-center justify-between">
        <span className="font-medium">초대 링크</span>
        <button onClick={createInvite} disabled={loading} className="text-xs underline disabled:opacity-50">
          {loading ? "생성 중..." : "새 링크 만들기"}
        </button>
      </div>
      {url && (
        <div className="flex items-center gap-2">
          <input readOnly value={url} className="flex-1 rounded border border-black/10 bg-transparent px-2 py-1 text-xs dark:border-white/10" />
          <button onClick={copy} className="rounded bg-amber-400 px-2 py-1 text-xs font-medium text-black hover:bg-amber-300">
            {copied ? "복사됨" : "복사"}
          </button>
        </div>
      )}
    </div>
  );
}
