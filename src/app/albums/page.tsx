"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

interface AlbumSummary {
  id: string;
  title: string;
  description?: string | null;
  owner: string;
  role: string;
  mediaCount: number;
  createdAt: string;
}

export default function AlbumsPage() {
  const router = useRouter();
  const [albums, setAlbums] = useState<AlbumSummary[] | null>(null);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await fetch("/api/albums");
    if (res.status === 401) {
      router.push("/login");
      return;
    }
    const data = await res.json();
    setAlbums(data.albums);
  }, [router]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial fetch-on-mount, setState is async (post-await)
    load();
  }, [load]);

  async function onCreate(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setCreating(true);
    try {
      const res = await fetch("/api/albums", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, description: description || undefined }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "생성에 실패했습니다");
        return;
      }
      setTitle("");
      setDescription("");
      await load();
    } finally {
      setCreating(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-semibold">사진첩</h1>

      <form onSubmit={onCreate} className="mb-8 flex flex-col gap-2 rounded border border-black/10 p-4 dark:border-white/10">
        <div className="text-sm font-medium">새 사진첩 만들기</div>
        <div className="flex gap-2">
          <input
            required
            placeholder="사진첩 이름 (예: 우리아기)"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="flex-1 rounded border border-black/15 bg-transparent px-3 py-2 text-sm dark:border-white/20"
          />
          <button
            type="submit"
            disabled={creating}
            className="rounded bg-amber-400 px-4 py-2 text-sm font-medium text-black hover:bg-amber-300 disabled:opacity-50"
          >
            만들기
          </button>
        </div>
        <input
          placeholder="설명 (선택)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="rounded border border-black/15 bg-transparent px-3 py-2 text-sm dark:border-white/20"
        />
        {error && <p className="text-sm text-red-500">{error}</p>}
      </form>

      {albums === null ? (
        <p className="text-sm text-zinc-500">불러오는 중...</p>
      ) : albums.length === 0 ? (
        <p className="text-sm text-zinc-500">아직 사진첩이 없습니다. 위에서 새로 만들어보세요.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {albums.map((a) => (
            <li key={a.id}>
              <Link
                href={`/albums/${a.id}`}
                className="flex items-center justify-between rounded border border-black/10 p-4 hover:bg-black/5 dark:border-white/10 dark:hover:bg-white/5"
              >
                <div>
                  <div className="font-medium">{a.title}</div>
                  <div className="text-xs text-zinc-500">
                    {a.owner} · {a.mediaCount}개 · {a.role === "owner" ? "개설자" : "멤버"}
                  </div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
