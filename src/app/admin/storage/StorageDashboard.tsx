"use client";

import { useCallback, useEffect, useState } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import { formatBytes } from "@/lib/format";

interface StorageData {
  total: number;
  quota: number;
  used: number;
  free: number;
  percent: number;
  level: "ok" | "warn" | "alert" | "block";
  trashBytes: number;
  mediaCount: number;
  albumCount: number;
  trend: { dailyAvgBytes: number | null; daysRemaining: number | null };
  topAlbums: { albumId: string; title: string; owner: string; bytes: number; mediaCount: number }[];
}

interface HistoryPoint {
  date: string;
  usedBytes: number;
}

const LEVEL_LABEL: Record<StorageData["level"], string> = { ok: "정상", warn: "주의", alert: "경고", block: "차단" };
const LEVEL_COLOR: Record<StorageData["level"], string> = {
  ok: "#71717a",
  warn: "#f59e0b",
  alert: "#f97316",
  block: "#ef4444",
};

export default function StorageDashboard({ thresholds }: { thresholds: { warn: number; alert: number; block: number } }) {
  const [data, setData] = useState<StorageData | null>(null);
  const [history, setHistory] = useState<HistoryPoint[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [statusRes, historyRes] = await Promise.all([
      fetch("/api/admin/storage"),
      fetch("/api/admin/storage/history?days=30"),
    ]);
    if (statusRes.ok) setData(await statusRes.json());
    if (historyRes.ok) {
      const h = await historyRes.json();
      setHistory(h.history);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial fetch-on-mount, setState is async (post-await)
    load();
  }, [load]);

  async function recalculate() {
    setBusy("recalculate");
    setNotice(null);
    try {
      await fetch("/api/admin/storage/recalculate", { method: "POST" });
      await load();
      setNotice("재집계가 완료되었습니다");
    } finally {
      setBusy(null);
    }
  }

  async function purgeTrash() {
    if (!confirm("휴지통을 즉시 비웁니다. 이 작업은 되돌릴 수 없습니다. 계속할까요?")) return;
    setBusy("purge");
    setNotice(null);
    try {
      const res = await fetch("/api/admin/storage/purge-trash", { method: "POST" });
      const result = await res.json();
      await load();
      setNotice(`휴지통 비우기 완료 (${result.purged}개 삭제)`);
    } finally {
      setBusy(null);
    }
  }

  if (!data) {
    return <div className="mx-auto max-w-4xl px-4 py-8 text-sm text-zinc-500">불러오는 중...</div>;
  }

  const daysRemaining = data.trend.daysRemaining;
  const monthsRemaining = daysRemaining !== null ? Math.max(0, Math.round(daysRemaining / 30)) : null;
  const exhaustionDate =
    daysRemaining !== null
      ? // eslint-disable-next-line react-hooks/purity -- display-only estimate derived from already-fetched data, not used for logic/hydration
        new Date(Date.now() + daysRemaining * 86_400_000).toLocaleDateString("ko-KR", { year: "numeric", month: "long" })
      : null;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-semibold">스토리지</h1>

      {data.level === "block" && (
        <div className="mb-4 rounded bg-red-600 px-4 py-2 text-sm font-medium text-white">신규 업로드가 차단되었습니다</div>
      )}

      {notice && <p className="mb-4 text-sm text-green-600">{notice}</p>}

      <div className="mb-6 rounded border border-black/10 p-4 dark:border-white/10">
        <div className="mb-1 h-4 w-full overflow-hidden rounded-full bg-zinc-200 dark:bg-zinc-800">
          <div
            className="h-full rounded-full transition-all"
            style={{ width: `${Math.min(100, data.percent)}%`, backgroundColor: LEVEL_COLOR[data.level] }}
          />
        </div>
        <div className="mt-2 flex items-center justify-between text-sm">
          <span>
            {formatBytes(data.used)} / {formatBytes(data.quota)}
          </span>
          <span style={{ color: LEVEL_COLOR[data.level] }} className="font-medium">
            {data.percent.toFixed(0)}% 사용 중 · {LEVEL_LABEL[data.level]}
          </span>
        </div>

        <dl className="mt-4 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
          <div>
            <dt className="text-zinc-500">여유 공간</dt>
            <dd className="font-medium">{formatBytes(data.free)}</dd>
          </div>
          <div>
            <dt className="text-zinc-500">휴지통</dt>
            <dd className="flex items-center gap-2 font-medium">
              {formatBytes(data.trashBytes)}
              <button
                onClick={purgeTrash}
                disabled={busy === "purge"}
                className="rounded border border-black/15 px-2 py-0.5 text-xs font-normal hover:bg-black/5 disabled:opacity-50 dark:border-white/20 dark:hover:bg-white/10"
              >
                비우기
              </button>
            </dd>
          </div>
          <div>
            <dt className="text-zinc-500">일 평균 증가</dt>
            <dd className="font-medium">{data.trend.dailyAvgBytes !== null ? formatBytes(data.trend.dailyAvgBytes) : "산출 중"}</dd>
          </div>
          <div>
            <dt className="text-zinc-500">소진 예상</dt>
            <dd className="font-medium">
              {monthsRemaining !== null ? `약 ${monthsRemaining}개월 (${exhaustionDate})` : "산출 중"}
            </dd>
          </div>
        </dl>
      </div>

      <div className="mb-6 rounded border border-black/10 p-4 dark:border-white/10">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-medium">최근 30일 증가 추이</h2>
          <button
            onClick={recalculate}
            disabled={busy === "recalculate"}
            className="rounded border border-black/15 px-2 py-1 text-xs hover:bg-black/5 disabled:opacity-50 dark:border-white/20 dark:hover:bg-white/10"
          >
            {busy === "recalculate" ? "재집계 중..." : "전체 재집계"}
          </button>
        </div>
        {history.length < 2 ? (
          <p className="text-sm text-zinc-500">데이터가 쌓이는 중입니다.</p>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={history}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-zinc-200 dark:stroke-zinc-800" />
              <XAxis dataKey="date" tick={{ fontSize: 11 }} minTickGap={20} />
              <YAxis tickFormatter={(v) => formatBytes(v)} width={70} tick={{ fontSize: 11 }} />
              <Tooltip formatter={(v) => formatBytes(Number(v))} />
              <Line type="monotone" dataKey="usedBytes" stroke="#f59e0b" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="mb-6 rounded border border-black/10 p-4 dark:border-white/10">
        <h2 className="mb-3 text-sm font-medium">사진첩별 사용량</h2>
        {data.topAlbums.length === 0 ? (
          <p className="text-sm text-zinc-500">데이터가 없습니다.</p>
        ) : (
          <ol className="flex flex-col gap-1 text-sm">
            {data.topAlbums.map((a, i) => (
              <li key={a.albumId} className="flex items-center justify-between border-b border-black/5 py-1 last:border-0 dark:border-white/5">
                <span>
                  {i + 1}. {a.title} <span className="text-zinc-500">{a.owner}</span>
                </span>
                <span className="text-zinc-500">
                  {formatBytes(a.bytes)} · {a.mediaCount.toLocaleString()}개
                </span>
              </li>
            ))}
          </ol>
        )}
      </div>

      <div className="rounded border border-black/10 p-4 text-sm text-zinc-500 dark:border-white/10">
        임계치 &nbsp; 주의 {thresholds.warn}% / 경고 {thresholds.alert}% / 차단 {thresholds.block}%
      </div>
    </div>
  );
}
