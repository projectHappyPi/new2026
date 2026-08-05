"use client";

import { useEffect, useRef, useState } from "react";

interface ShareConfig {
  shareEnabled: boolean;
  kakaoEnabled: boolean;
  kakaoJsKey: string | null;
  shareCoverImageUrl: string;
  webBaseUrl: string;
}

let configPromise: Promise<ShareConfig> | null = null;
function loadConfig(): Promise<ShareConfig> {
  if (!configPromise) {
    configPromise = fetch("/api/share/config").then((r) => r.json());
  }
  return configPromise;
}

let kakaoInitPromise: Promise<void> | null = null;
function loadKakaoSdk(jsKey: string): Promise<void> {
  if (kakaoInitPromise) return kakaoInitPromise;
  kakaoInitPromise = new Promise((resolve, reject) => {
    if (typeof window === "undefined") return resolve();
    const w = window as unknown as { Kakao?: { init: (k: string) => void; isInitialized: () => boolean } };
    if (w.Kakao?.isInitialized()) return resolve();
    const script = document.createElement("script");
    script.src = "https://t1.kakaocdn.net/kakao_js_sdk/2.7.2/kakao.min.js";
    script.onload = () => {
      w.Kakao?.init(jsKey);
      resolve();
    };
    script.onerror = () => reject(new Error("kakao sdk load failed"));
    document.head.appendChild(script);
  });
  return kakaoInitPromise;
}

export function useShareActions({ title, description, path }: { title: string; description: string; path: string }) {
  const [config, setConfig] = useState<ShareConfig | null>(null);

  useEffect(() => {
    loadConfig().then(setConfig);
  }, []);

  const url = config ? `${config.webBaseUrl}${path}` : "";

  async function logShare() {
    fetch("/api/share", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path }),
    }).catch(() => {});
  }

  async function shareKakao() {
    if (!config?.kakaoEnabled || !config.kakaoJsKey) return;
    await loadKakaoSdk(config.kakaoJsKey);
    const w = window as unknown as { Kakao?: { Share: { sendDefault: (opts: unknown) => void } } };
    w.Kakao?.Share.sendDefault({
      objectType: "feed",
      content: {
        title,
        description,
        imageUrl: config.shareCoverImageUrl,
        link: { webUrl: url, mobileWebUrl: url },
      },
      buttons: [{ title: "사진첩 열기", link: { webUrl: url, mobileWebUrl: url } }],
    });
    logShare();
  }

  async function copyLink() {
    await navigator.clipboard.writeText(url);
    logShare();
  }

  return {
    ready: Boolean(config) && Boolean(config?.shareEnabled),
    kakaoEnabled: Boolean(config?.kakaoEnabled),
    shareKakao,
    copyLink,
  };
}

export default function ShareMenu({
  title,
  description,
  path,
  compact = false,
  label = "카카오톡으로 공유",
}: {
  title: string;
  description: string;
  path: string;
  compact?: boolean;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const { ready, kakaoEnabled, shareKakao, copyLink } = useShareActions({ title, description, path });

  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  if (!ready) return null;

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((v) => !v)}
        className={
          compact
            ? "text-xs text-zinc-500 underline"
            : "rounded border border-black/15 px-3 py-2 text-sm hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10"
        }
      >
        {compact ? label : "공유"}
      </button>
      {open && (
        <div className="absolute right-0 z-10 mt-1 w-48 rounded border border-black/10 bg-white p-1 text-sm shadow-lg dark:border-white/10 dark:bg-zinc-900">
          {kakaoEnabled && (
            <button
              onClick={() => {
                shareKakao();
                setOpen(false);
              }}
              className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/10"
            >
              카카오톡으로 공유
            </button>
          )}
          <button
            onClick={() => {
              copyLink();
              setCopied(true);
              setTimeout(() => setCopied(false), 1500);
            }}
            className="block w-full rounded px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/10"
          >
            {copied ? "링크가 복사되었습니다" : "링크 복사"}
          </button>
          <p className="px-3 py-1 text-[11px] text-zinc-400">받는 사람이 멤버가 아니면 참여 신청 화면이 열립니다</p>
        </div>
      )}
    </div>
  );
}
