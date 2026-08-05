import checkDiskSpace from "check-disk-space";
import { getEnv } from "./env";
import { prisma } from "./prisma";

export type StorageLevel = "ok" | "warn" | "alert" | "block";

export interface StorageStatus {
  total: number;
  quota: number;
  used: number;
  free: number;
  percent: number;
  level: StorageLevel;
}

export async function getStorageStatus(): Promise<StorageStatus> {
  const env = getEnv();
  const disk = await checkDiskSpace(env.STORAGE_CHECK_PATH);
  const total = env.STORAGE_TOTAL_BYTES_OVERRIDE || disk.size;
  const quota = env.STORAGE_QUOTA_BYTES || total;
  const used = total - disk.free;
  const percent = quota > 0 ? (used / quota) * 100 : 0;

  const level: StorageLevel =
    percent >= env.STORAGE_BLOCK_PERCENT
      ? "block"
      : percent >= env.STORAGE_ALERT_PERCENT
        ? "alert"
        : percent >= env.STORAGE_WARN_PERCENT
          ? "warn"
          : "ok";

  return { total, quota, used, free: disk.free, percent, level };
}

// Redis 대체: 단일 Node 프로세스 내 인메모리 캐시 (TTL 초 단위).
let cachedLevel: { level: StorageLevel; free: number; expiresAt: number } | null = null;

export async function getCachedStorageLevel(): Promise<{ level: StorageLevel; free: number }> {
  const env = getEnv();
  const now = Date.now();
  if (cachedLevel && cachedLevel.expiresAt > now) {
    return { level: cachedLevel.level, free: cachedLevel.free };
  }
  const status = await getStorageStatus();
  cachedLevel = {
    level: status.level,
    free: status.free,
    expiresAt: now + env.STORAGE_LEVEL_CACHE_TTL_SECONDS * 1000,
  };
  return { level: status.level, free: status.free };
}

export function invalidateStorageLevelCache() {
  cachedLevel = null;
}

export async function getTrashBytes(): Promise<number> {
  const result = await prisma.media.aggregate({
    where: { deletedAt: { not: null } },
    _sum: { bytes: true },
  });
  return Number(result._sum.bytes ?? BigInt(0));
}

export async function getTopAlbums(limit = 10) {
  const albums = await prisma.album.findMany({
    include: {
      owner: { select: { nickname: true } },
      media: { select: { bytes: true, deletedAt: true, variants: { select: { bytes: true } } } },
    },
  });

  const ranked = albums.map((album) => {
    const bytes = album.media.reduce((sum, m) => {
      const variantBytes = m.variants.reduce((vs, v) => vs + Number(v.bytes), 0);
      return sum + Number(m.bytes) + variantBytes;
    }, 0);
    const mediaCount = album.media.filter((m) => !m.deletedAt).length;
    return {
      albumId: album.id,
      title: album.title,
      owner: album.owner.nickname,
      bytes,
      mediaCount,
    };
  });

  return ranked.sort((a, b) => b.bytes - a.bytes).slice(0, limit);
}

export async function getServiceUsageBytes(): Promise<number> {
  const [mediaSum, variantSum] = await Promise.all([
    prisma.media.aggregate({ _sum: { bytes: true } }),
    prisma.mediaVariant.aggregate({ _sum: { bytes: true } }),
  ]);
  return Number(mediaSum._sum.bytes ?? BigInt(0)) + Number(variantSum._sum.bytes ?? BigInt(0));
}

export async function computeTrend(): Promise<{ dailyAvgBytes: number | null; daysRemaining: number | null }> {
  const rows = await prisma.storageStats.findMany({
    orderBy: { date: "desc" },
    take: 30,
  });
  if (rows.length < 7) {
    return { dailyAvgBytes: null, daysRemaining: null };
  }
  const sorted = [...rows].sort((a, b) => a.date.localeCompare(b.date));
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  const daySpan = Math.max(
    1,
    Math.round((new Date(last.date).getTime() - new Date(first.date).getTime()) / 86_400_000),
  );
  const bytesDelta = Number(last.usedBytes) - Number(first.usedBytes);
  const dailyAvgBytes = bytesDelta / daySpan;

  if (dailyAvgBytes <= 0) {
    return { dailyAvgBytes: Math.max(dailyAvgBytes, 0), daysRemaining: null };
  }
  const daysRemaining = Number(last.freeBytes) / dailyAvgBytes;
  return { dailyAvgBytes, daysRemaining };
}
