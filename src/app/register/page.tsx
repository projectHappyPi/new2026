"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function RegisterPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [nickname, setNickname] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, nickname }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "회원가입에 실패했습니다");
        return;
      }
      router.push("/albums");
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col gap-6 px-4 py-16">
      <h1 className="text-2xl font-semibold">회원가입</h1>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <input
          type="text"
          required
          placeholder="닉네임"
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
          className="rounded border border-black/15 bg-transparent px-3 py-2 dark:border-white/20"
        />
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
          minLength={8}
          placeholder="비밀번호 (8자 이상)"
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
          {loading ? "가입 중..." : "회원가입"}
        </button>
      </form>
      <p className="text-sm text-zinc-500">
        이미 계정이 있으신가요? <Link href="/login" className="underline">로그인</Link>
      </p>
    </div>
  );
}
