"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import ShareMenu from "@/components/ShareMenu";
import DayCard, { type DayMediaItem } from "./DayCard";

interface MediaItem extends DayMediaItem {
  bytes: number;
  createdAt: string;
  takenAt: string;
}

type UploadState = { name: string; status: "pending" | "uploading" | "done" | "error"; message?: string };

function uploadWithProgress(url: string, form: FormData, onProgress: (loadedBytes: number) => void): Promise<{ ok: boolean; data: unknown }> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(e.loaded);
    };
    xhr.onload = () => {
      let data: unknown = {};
      try {
        data = JSON.parse(xhr.responseText);
      } catch {
        /* non-JSON error body, leave data empty */
      }
      resolve({ ok: xhr.status >= 200 && xhr.status < 300, data });
    };
    xhr.onerror = () => reject(new Error("네트워크 오류"));
    xhr.send(form);
  });
}

function dayKey(iso: string) {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function dayLabel(key: string) {
  const d = new Date(`${key}T00:00:00`);
  return d.toLocaleDateString("ko-KR", { year: "numeric", month: "long", day: "numeric", weekday: "short" });
}

export default function AlbumMediaSection({
  albumId,
  isOwner,
  albumTitle,
}: {
  albumId: string;
  isOwner: boolean;
  coverMediaId: string | null;
  albumTitle: string;
}) {
  const [media, setMedia] = useState<MediaItem[] | null>(null);
  const [uploads, setUploads] = useState<UploadState[]>([]);
  const [uploadPercent, setUploadPercent] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const isUploading = uploads.length > 0 && uploads.some((u) => u.status === "pending" || u.status === "uploading");

  const load = useCallback(async () => {
    const res = await fetch(`/api/albums/${albumId}/media`);
    if (res.ok) {
      const data = await res.json();
      setMedia(data.media);
    }
  }, [albumId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial fetch-on-mount, setState is async (post-await)
    load();
  }, [load]);

  async function onFilesSelected(files: FileList | null) {
    if (!files || files.length === 0) return;
    setError(null);
    const list = Array.from(files);

    const initRes = await fetch(`/api/albums/${albumId}/uploads/init`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ files: list.map((f) => ({ bytes: f.size, mime: f.type })) }),
    });
    if (!initRes.ok) {
      const data = await initRes.json();
      setError(data.message ?? "업로드를 시작할 수 없습니다");
      return;
    }

    setUploads(list.map((f) => ({ name: f.name, status: "pending" })));
    setUploadPercent(0);

    const totalBytes = list.reduce((sum, f) => sum + f.size, 0) || 1;
    const loadedByFile = new Array(list.length).fill(0);
    const reportProgress = (i: number, loaded: number) => {
      loadedByFile[i] = loaded;
      const totalLoaded = loadedByFile.reduce((sum, n) => sum + n, 0);
      setUploadPercent(Math.min(100, Math.round((totalLoaded / totalBytes) * 100)));
    };

    for (let i = 0; i < list.length; i++) {
      const file = list[i];
      setUploads((prev) => prev.map((u, idx) => (idx === i ? { ...u, status: "uploading" } : u)));
      try {
        const form = new FormData();
        form.append("file", file);
        // Fallback for files with no embedded taken-date metadata (e.g. screenshots, exported
        // slides) — the browser always knows the local file's last-modified time.
        form.append("lastModified", String(file.lastModified));
        const { ok, data } = await uploadWithProgress(`/api/albums/${albumId}/media`, form, (loaded) => reportProgress(i, loaded));
        reportProgress(i, file.size); // this file is done regardless of outcome, count its full size
        if (!ok) {
          const message = (data as { message?: string })?.message;
          setUploads((prev) => prev.map((u, idx) => (idx === i ? { ...u, status: "error", message } : u)));
          continue;
        }
        setUploads((prev) => prev.map((u, idx) => (idx === i ? { ...u, status: "done" } : u)));
      } catch {
        reportProgress(i, file.size);
        setUploads((prev) => prev.map((u, idx) => (idx === i ? { ...u, status: "error", message: "네트워크 오류" } : u)));
      }
    }
    await load();
  }

  // Group by taken-date (EXIF/video creation_time, falling back to upload time) so a photo taken
  // last week but uploaded today still lands on the day it was actually taken.
  const groups = new Map<string, MediaItem[]>();
  for (const m of media ?? []) {
    const key = dayKey(m.takenAt ?? m.createdAt);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(m);
  }
  for (const items of groups.values()) {
    items.sort((a, b) => new Date(a.takenAt ?? a.createdAt).getTime() - new Date(b.takenAt ?? b.createdAt).getTime());
  }

  return (
    <div className="mt-6">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <button
          onClick={() => inputRef.current?.click()}
          className="rounded bg-amber-400 px-4 py-2 text-sm font-medium text-black hover:bg-amber-300"
        >
          사진/동영상 업로드
        </button>
        <input
          ref={inputRef}
          type="file"
          multiple
          accept="image/jpeg,image/png,image/heic,image/heif,image/webp,video/mp4,video/quicktime"
          className="hidden"
          onChange={(e) => onFilesSelected(e.target.files)}
        />
        <ShareMenu title={albumTitle} description="사진첩 공유" path={`/albums/${albumId}`} />
      </div>

      {error && <p className="mb-3 text-sm text-red-500">{error}</p>}

      {uploads.length > 0 && (
        <div className="mb-4">
          <div className="mb-2 flex items-center justify-between text-xs text-zinc-500">
            <span>업로드 중... {uploadPercent}%</span>
            <span>
              {uploads.filter((u) => u.status === "done").length}/{uploads.length}개 완료
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
            <div className="h-full rounded-full bg-amber-400 transition-all duration-200" style={{ width: `${uploadPercent}%` }} />
          </div>
          <ul className="mt-3 flex flex-col gap-1 text-xs">
            {uploads.map((u, i) => (
              <li key={i} className="flex items-center gap-2">
                <span className="w-40 truncate">{u.name}</span>
                <span
                  className={
                    u.status === "done"
                      ? "text-green-600"
                      : u.status === "error"
                        ? "text-red-500"
                        : "text-zinc-500"
                  }
                >
                  {u.status === "pending" && "대기중"}
                  {u.status === "uploading" && "업로드 중..."}
                  {u.status === "done" && "완료"}
                  {u.status === "error" && (u.message ?? "실패")}
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="relative">
        {isUploading && (
          <div className="absolute inset-0 z-10 flex items-start justify-center bg-zinc-100/70 pt-12 backdrop-blur-[1px] dark:bg-zinc-100/30">
            <div className="flex flex-col items-center gap-2 rounded-lg bg-white/90 px-6 py-4 text-sm shadow dark:bg-zinc-900/90">
              <span className="font-medium">사진을 업로드하고 있어요...</span>
              <div className="h-1.5 w-40 overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
                <div className="h-full rounded-full bg-amber-400 transition-all duration-200" style={{ width: `${uploadPercent}%` }} />
              </div>
            </div>
          </div>
        )}

        {media === null ? (
          <p className="text-sm text-zinc-500">불러오는 중...</p>
        ) : media.length === 0 ? (
          <p className="text-sm text-zinc-500">아직 업로드된 사진이 없습니다.</p>
        ) : (
          [...groups.entries()]
            .sort((a, b) => b[0].localeCompare(a[0]))
            .map(([key, items]) => (
              <DayCard key={key} albumId={albumId} albumTitle={albumTitle} dayKey={key} dayLabel={dayLabel(key)} items={items} />
            ))
        )}
      </div>

      {isOwner && <p className="mt-4 text-xs text-zinc-400">사진을 삭제하면 휴지통으로 이동하며, 30일 후 자동으로 완전 삭제됩니다.</p>}
    </div>
  );
}
