"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import AppIcon from "@/components/AppIcon";

export default function NicknameForm({ initialNickname, next }: { initialNickname: string; next: string }) {
  const router = useRouter();
  const [nickname, setNickname] = useState(initialNickname);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/nickname", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nickname }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "닉네임 저장에 실패했습니다");
        return;
      }
      router.push(next);
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-[70vh] max-w-sm flex-col items-center justify-center gap-6 px-4 py-16 text-center">
      <AppIcon size={72} />
      <div>
        <h1 className="text-xl font-bold">환영해요!</h1>
        <p className="mt-2 text-sm text-zinc-500">
          카카오 계정으로 가입이 완료됐어요.
          <br />
          가족들에게 보여질 닉네임을 정해주세요.
        </p>
      </div>
      <form onSubmit={onSubmit} className="flex w-full flex-col gap-3 text-left">
        <input
          required
          maxLength={30}
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
          className="rounded border border-black/15 bg-transparent px-3 py-2 text-center dark:border-white/20"
        />
        <p className="text-center text-xs text-zinc-400">카카오 프로필 이름을 기본값으로 가져왔어요 — 원하는 이름으로 바꿀 수 있습니다.</p>
        {error && <p className="text-center text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={loading || !nickname.trim()}
          className="rounded bg-amber-400 px-3 py-2 font-medium text-black hover:bg-amber-300 disabled:opacity-50"
        >
          {loading ? "저장 중..." : "Pickle 시작하기"}
        </button>
      </form>
    </div>
  );
}
