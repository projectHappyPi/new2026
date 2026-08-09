"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function InviteAcceptButton({ token, albumId }: { token: string; albumId: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function accept() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/invite/${token}/accept`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "참여에 실패했습니다");
        return;
      }
      router.push(`/albums/${albumId}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <button
        onClick={accept}
        disabled={loading}
        className="rounded bg-amber-400 px-4 py-2 text-sm font-medium text-black hover:bg-amber-300 disabled:opacity-50"
      >
        {loading ? "참여 중..." : "사진첩 참여하기"}
      </button>
      {error && <p className="mt-2 text-sm text-red-500">{error}</p>}
    </div>
  );
}
