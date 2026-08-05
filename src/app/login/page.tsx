"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") || "/albums";
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [kakaoEnabled, setKakaoEnabled] = useState(false);

  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((d) => setKakaoEnabled(Boolean(d.kakaoEnabled)))
      .catch(() => {});
  }, []);

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
    <div className="mx-auto flex max-w-sm flex-col gap-6 px-4 py-16">
      <h1 className="text-2xl font-semibold">로그인</h1>
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

      {kakaoEnabled && (
        <a
          href={`/api/auth/kakao/start?next=${encodeURIComponent(next)}`}
          className="rounded bg-[#FEE500] px-3 py-2 text-center font-medium text-black hover:brightness-95"
        >
          카카오로 로그인
        </a>
      )}

      <p className="text-sm text-zinc-500">
        계정이 없으신가요? <Link href="/register" className="underline">회원가입</Link>
      </p>
    </div>
  );
}
