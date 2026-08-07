"use client";

import { useEffect, useState } from "react";

export default function KakaoStartButton({ next, label }: { next: string; label: string }) {
  const [kakaoEnabled, setKakaoEnabled] = useState(false);

  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((d) => setKakaoEnabled(Boolean(d.kakaoEnabled)))
      .catch(() => {});
  }, []);

  if (!kakaoEnabled) return null;

  return (
    <a
      href={`/api/auth/kakao/start?next=${encodeURIComponent(next)}`}
      className="flex items-center justify-center gap-2 rounded bg-[#FEE500] px-3 py-2 text-center font-medium text-black hover:brightness-95"
    >
      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
        <path
          d="M12 3C6.48 3 2 6.58 2 11c0 2.79 1.86 5.24 4.66 6.66-.2.75-.75 2.75-.86 3.18-.14.53.19.53.4.38.17-.12 2.68-1.82 3.77-2.56.66.1 1.34.15 2.03.15 5.52 0 10-3.58 10-8s-4.48-8-10-8Z"
          fill="#241900"
        />
      </svg>
      {label}
    </a>
  );
}
