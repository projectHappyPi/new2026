"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function SettingsForm({ initialNickname, email }: { initialNickname: string; email: string | null }) {
  const router = useRouter();
  const [nickname, setNickname] = useState(initialNickname);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSaved(false);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/nickname", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nickname }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "저장에 실패했습니다");
        return;
      }
      setSaved(true);
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-sm px-4 py-16">
      <h1 className="mb-6 text-2xl font-semibold">설정</h1>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        {email && (
          <div>
            <div className="mb-1 text-xs text-zinc-500">이메일</div>
            <div className="rounded border border-black/10 px-3 py-2 text-sm text-zinc-500 dark:border-white/10">{email}</div>
          </div>
        )}
        <div>
          <label htmlFor="nickname" className="mb-1 block text-xs text-zinc-500">
            닉네임
          </label>
          <input
            id="nickname"
            required
            maxLength={30}
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            className="w-full rounded border border-black/15 bg-transparent px-3 py-2 dark:border-white/20"
          />
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
        {saved && <p className="text-sm text-green-600">저장되었습니다</p>}
        <button
          type="submit"
          disabled={loading || !nickname.trim()}
          className="rounded bg-amber-400 px-3 py-2 font-medium text-black hover:bg-amber-300 disabled:opacity-50"
        >
          {loading ? "저장 중..." : "저장"}
        </button>
      </form>
    </div>
  );
}
