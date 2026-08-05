"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useShareActions } from "@/components/ShareMenu";

export default function MediaViewer({
  albumId,
  mediaId,
  albumTitle,
  originalFilename,
  mime,
  uploader,
  createdAt,
  canManage,
  canSetCover,
}: {
  albumId: string;
  mediaId: string;
  albumTitle: string;
  originalFilename: string;
  mime: string;
  uploader: string;
  createdAt: string;
  canManage: boolean;
  canSetCover: boolean;
}) {
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const isVideo = mime.startsWith("video/");
  const date = new Date(createdAt).toLocaleString("ko-KR");
  const { kakaoEnabled, shareKakao, copyLink } = useShareActions({
    title: albumTitle,
    description: "사진 보기",
    path: `/albums/${albumId}/media/${mediaId}`,
  });

  async function onDelete() {
    if (!confirm("이 사진을 휴지통으로 이동할까요?")) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/media/${mediaId}`, { method: "DELETE" });
      if (res.ok) {
        router.push(`/albums/${albumId}`);
        router.refresh();
      }
    } finally {
      setBusy(false);
    }
  }

  async function onSetCover() {
    setBusy(true);
    try {
      const res = await fetch(`/api/albums/${albumId}/cover`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mediaId }),
      });
      if (res.ok) setNotice("커버로 지정되었습니다");
    } finally {
      setBusy(false);
      setMenuOpen(false);
    }
  }

  async function onCopyLink() {
    await copyLink();
    setNotice("링크가 복사되었습니다");
    setMenuOpen(false);
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-6">
      <div className="mb-4 flex items-center justify-between">
        <Link href={`/albums/${albumId}`} className="text-sm text-zinc-500 hover:underline">
          ← {albumTitle}
        </Link>
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setMenuOpen((v) => !v)}
            className="rounded border border-black/15 px-3 py-1 text-sm hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10"
          >
            ⋮
          </button>
          {menuOpen && (
            <div className="absolute right-0 z-10 mt-1 w-56 rounded border border-black/10 bg-white p-1 text-sm shadow-lg dark:border-white/10 dark:bg-zinc-900">
              {kakaoEnabled && (
                <button
                  onClick={() => {
                    shareKakao();
                    setMenuOpen(false);
                  }}
                  className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/10"
                >
                  카카오톡으로 공유
                </button>
              )}
              <button onClick={onCopyLink} className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/10">
                링크 복사
              </button>
              {kakaoEnabled && (
                <p className="px-3 py-1 text-[11px] text-zinc-400">받는 사람이 멤버가 아니면 참여 신청 화면이 열립니다</p>
              )}
              <a
                href={`/api/media/${mediaId}/file?download=1`}
                className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/10"
              >
                원본 다운로드
              </a>
              {(canSetCover || canManage) && <div className="my-1 border-t border-black/10 dark:border-white/10" />}
              {canSetCover && (
                <button
                  disabled={busy}
                  onClick={onSetCover}
                  className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 disabled:opacity-50 dark:hover:bg-white/10"
                >
                  커버로 지정 (개설자)
                </button>
              )}
              {canManage && (
                <button
                  disabled={busy}
                  onClick={onDelete}
                  className="block w-full rounded px-3 py-2 text-left text-red-500 hover:bg-black/5 disabled:opacity-50 dark:hover:bg-white/10"
                >
                  삭제
                </button>
              )}
            </div>
          )}
        </div>
      </div>

      {notice && <p className="mb-3 text-sm text-green-600">{notice}</p>}

      <div className="flex items-center justify-center rounded bg-black">
        {isVideo ? (
          <video controls className="max-h-[75vh] w-full" src={`/api/media/${mediaId}/file`} />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={`/api/media/${mediaId}/file`} alt={originalFilename} className="max-h-[75vh] w-full object-contain" />
        )}
      </div>

      <p className="mt-3 text-xs text-zinc-500">
        {uploader} · {date}
      </p>
    </div>
  );
}
