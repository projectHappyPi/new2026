"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import AppIcon from "@/components/AppIcon";
import KakaoStartButton from "@/components/KakaoStartButton";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") || "/albums";
  const [showEmailForm, setShowEmailForm] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "로그인에 실패했습니다");
        return;
      }
      router.push(next);
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-[70vh] max-w-sm flex-col items-center justify-center gap-8 px-4 py-16">
      <div className="flex flex-col items-center gap-3 text-center">
        <AppIcon size={80} />
        <h1 className="text-2xl font-extrabold tracking-tight">Pickle</h1>
        <p className="text-sm text-zinc-500">남는건 사진뿐!</p>
      </div>

      <div className="flex w-full flex-col gap-3">
        <KakaoStartButton next={next} label="카카오로 시작하기" />

        {!showEmailForm && (
          <button
            type="button"
            onClick={() => setShowEmailForm(true)}
            className="text-center text-xs text-zinc-500 underline"
          >
            이메일로 로그인
          </button>
        )}

        {showEmailForm && (
          <form onSubmit={onSubmit} className="flex flex-col gap-3">
            <input
              type="email"
              required
              placeholder="이메일"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="rounded border border-black/15 bg-transparent px-3 py-2 dark:border-white/20"
            />
            <input
              type="password"
              required
              placeholder="비밀번호"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="rounded border border-black/15 bg-transparent px-3 py-2 dark:border-white/20"
            />
            {error && <p className="text-sm text-red-500">{error}</p>}
            <button
              type="submit"
              disabled={loading}
              className="rounded bg-amber-400 px-3 py-2 font-medium text-black hover:bg-amber-300 disabled:opacity-50"
            >
              {loading ? "로그인 중..." : "로그인"}
            </button>
          </form>
        )}

        <p className="text-center text-sm text-zinc-500">
          계정이 없으신가요? <Link href="/register" className="underline">회원가입</Link>
        </p>
      </div>
    </div>
  );
}
