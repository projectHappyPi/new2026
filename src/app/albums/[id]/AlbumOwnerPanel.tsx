"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

interface Member {
  id: string;
  nickname: string;
}

export default function AlbumOwnerPanel({ albumId, members: initialMembers }: { albumId: string; members: Member[] }) {
  const router = useRouter();
  const [members, setMembers] = useState(initialMembers);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function kick(memberId: string) {
    if (!confirm("이 멤버를 사진첩에서 강퇴할까요?")) return;
    const res = await fetch(`/api/albums/${albumId}/members/${memberId}`, { method: "DELETE" });
    if (res.ok) {
      setMembers((prev) => prev.filter((m) => m.id !== memberId));
    } else {
      const data = await res.json();
      setError(data.message ?? "강퇴에 실패했습니다");
    }
  }

  async function deleteAlbum() {
    if (!confirm("정말 이 사진첩을 삭제할까요? 안의 모든 사진/동영상이 함께 영구 삭제되며 되돌릴 수 없습니다.")) return;
    setDeleting(true);
    setError(null);
    try {
      const res = await fetch(`/api/albums/${albumId}`, { method: "DELETE" });
      if (res.ok) {
        router.push("/albums");
        router.refresh();
        return;
      }
      const data = await res.json();
      setError(data.message ?? "삭제에 실패했습니다");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <details className="mb-6 rounded border border-black/10 dark:border-white/10">
      <summary className="cursor-pointer px-4 py-2 text-sm font-medium text-zinc-500">사진첩 관리 (개설자)</summary>
      <div className="flex flex-col gap-3 border-t border-black/5 px-4 py-3 dark:border-white/5">
        {error && <p className="text-sm text-red-500">{error}</p>}

        {members.length > 0 && (
          <div>
            <div className="mb-1 text-xs font-medium text-zinc-500">멤버</div>
            <ul className="flex flex-col gap-1">
              {members.map((m) => (
                <li key={m.id} className="flex items-center justify-between text-sm">
                  <span>{m.nickname}</span>
                  <button onClick={() => kick(m.id)} className="text-xs text-red-500 hover:underline">
                    강퇴
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}

        <button
          onClick={deleteAlbum}
          disabled={deleting}
          className="self-start rounded border border-red-500/40 px-3 py-1.5 text-xs font-medium text-red-500 hover:bg-red-500/10 disabled:opacity-50"
        >
          {deleting ? "삭제 중..." : "사진첩 삭제"}
        </button>
      </div>
    </details>
  );
}
