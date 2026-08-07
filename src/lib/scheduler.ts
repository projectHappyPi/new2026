import cron from "node-cron";
import { prisma } from "./prisma";
import { getEnv } from "./env";
import { getStorageStatus, invalidateStorageLevelCache, type StorageLevel } from "./storage-status";
import { sendMail } from "./mailer";
import { absoluteTrashPath, absoluteVariantPath } from "./paths";
import fs from "node:fs/promises";

const LEVEL_RANK: Record<StorageLevel, number> = { ok: 0, warn: 1, alert: 2, block: 3 };

async function getFlag(key: string) {
  const row = await prisma.systemFlag.findUnique({ where: { key } });
  return row?.value ?? null;
}

async function setFlag(key: string, value: string) {
  await prisma.systemFlag.upsert({
    where: { key },
    create: { key, value },
    update: { value },
  });
}

function todayKey(tz: string) {
  return new Date().toLocaleDateString("en-CA", { timeZone: tz }); // yyyy-mm-dd
}

async function runStorageCheck() {
  const env = getEnv();
  try {
    const status = await getStorageStatus();
    invalidateStorageLevelCache();

    await prisma.storageStats.upsert({
      where: { date: todayKey(env.TZ) },
      create: {
        date: todayKey(env.TZ),
        usedBytes: BigInt(Math.round(status.used)),
        freeBytes: BigInt(Math.round(status.free)),
        totalBytes: BigInt(Math.round(status.total)),
        level: status.level,
      },
      update: {
        usedBytes: BigInt(Math.round(status.used)),
        freeBytes: BigInt(Math.round(status.free)),
        totalBytes: BigInt(Math.round(status.total)),
        level: status.level,
      },
    });

    const prevLevelRaw = (await getFlag("storage_last_level")) as StorageLevel | null;
    const prevLevel: StorageLevel = prevLevelRaw ?? "ok";
    await setFlag("storage_last_level", status.level);

    const rose = LEVEL_RANK[status.level] > LEVEL_RANK[prevLevel];
    if (status.level === "ok") {
      await setFlag("storage_block_flag", "false");
      await setFlag("storage_banner", "false");
    } else if (rose) {
      const lastAlertKey = `storage_alert_last_${status.level}`;
      const lastAlertAt = await getFlag(lastAlertKey);
      const cooldownMs = env.STORAGE_ALERT_COOLDOWN_HOURS * 3_600_000;
      const canAlert = !lastAlertAt || Date.now() - new Date(lastAlertAt).getTime() > cooldownMs;

      if (canAlert) {
        await setFlag(lastAlertKey, new Date().toISOString());
        const pct = status.percent.toFixed(1);
        await sendMail({
          to: env.ADMIN_ALERT_EMAIL,
          subject: `[Pickle] 스토리지 ${status.level.toUpperCase()} - 사용률 ${pct}%`,
          text: `현재 스토리지 사용률이 ${pct}% 로 '${status.level}' 단계에 도달했습니다.\n사용량: ${status.used} / ${status.quota} bytes\n여유공간: ${status.free} bytes`,
        });
      }
      if (status.level === "alert" || status.level === "block") {
        await setFlag("storage_banner", "true");
      }
      if (status.level === "block") {
        await setFlag("storage_block_flag", "true");
      }
    }
  } catch (err) {
    console.error("[scheduler] storage check failed", err);
  }
}

/** Permanently deletes trashed media older than `cutoff` (defaults to the retention window). Returns count purged. */
async function runTrashPurge(cutoff?: Date): Promise<number> {
  const env = getEnv();
  try {
    const effectiveCutoff = cutoff ?? new Date(Date.now() - env.TRASH_RETENTION_DAYS * 86_400_000);
    const targets = await prisma.media.findMany({
      where: { deletedAt: { not: null, lt: effectiveCutoff } },
      include: { variants: true },
    });

    for (const media of targets) {
      // Soft-delete moves the physical file from MEDIA_ROOT to TRASH_ROOT but keeps
      // media.path unchanged (same relative path, different root) — see DELETE /api/media/[id].
      await fs.unlink(absoluteTrashPath(media.path)).catch(() => {});
      for (const v of media.variants) {
        await fs.unlink(absoluteVariantPath(v.path)).catch(() => {});
      }
      await prisma.mediaVariant.deleteMany({ where: { mediaId: media.id } });
      await prisma.media.delete({ where: { id: media.id } });
    }
    if (targets.length > 0) invalidateStorageLevelCache();
    return targets.length;
  } catch (err) {
    console.error("[scheduler] trash purge failed", err);
    return 0;
  }
}

async function runAccessLogRetention() {
  const env = getEnv();
  try {
    const cutoff = new Date(Date.now() - env.ACCESS_LOG_RETENTION_DAYS * 86_400_000);
    await prisma.accessLog.deleteMany({ where: { createdAt: { lt: cutoff } } });
  } catch (err) {
    console.error("[scheduler] access log retention failed", err);
  }
}

let started = false;

export function startSchedulers() {
  if (started) return;
  started = true;
  const env = getEnv();

  cron.schedule(env.STORAGE_CHECK_CRON, runStorageCheck, { timezone: env.TZ });
  cron.schedule(env.PURGE_CRON, () => {
    runTrashPurge();
    runAccessLogRetention();
  }, { timezone: env.TZ });

  // Run once at boot so the dashboard has data immediately instead of waiting for the first tick.
  runStorageCheck();
}

export { runStorageCheck, runTrashPurge };
