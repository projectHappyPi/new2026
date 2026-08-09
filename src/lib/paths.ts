import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { getEnv } from "./env";

const REQUIRED_DIRS = ["MEDIA_ROOT", "VARIANT_ROOT", "TEMP_UPLOAD_ROOT", "TRASH_ROOT"] as const;

let initialized = false;

/** Creates the media/variants/tmp/trash roots and verifies they're writable. Call once at boot. */
export function ensureStorageDirs() {
  if (initialized) return;
  const env = getEnv();
  for (const key of REQUIRED_DIRS) {
    const dir = env[key];
    fs.mkdirSync(dir, { recursive: true });
    const probe = path.join(dir, `.write-check-${randomUUID()}`);
    try {
      fs.writeFileSync(probe, "ok");
      fs.unlinkSync(probe);
    } catch (err) {
      throw new Error(`[storage] ${key}(${dir}) 에 쓰기 권한이 없습니다: ${(err as Error).message}`);
    }
  }
  initialized = true;
}

function pad2(n: number) {
  return String(n).padStart(2, "0");
}

/** {MEDIA_ROOT}/{albumId}/{yyyy}/{mm}/{uuid}.{ext} 규칙에 따른 상대/절대 경로를 만든다. */
export function buildMediaPath(albumId: string, ext: string, now = new Date()) {
  const yyyy = String(now.getFullYear());
  const mm = pad2(now.getMonth() + 1);
  const filename = `${randomUUID()}${ext ? `.${ext.replace(/^\./, "")}` : ""}`;
  const relative = path.posix.join(albumId, yyyy, mm, filename);
  return { relative, filename };
}

export function absoluteMediaPath(relative: string) {
  return path.join(getEnv().MEDIA_ROOT, relative);
}

export function absoluteVariantPath(relative: string) {
  return path.join(getEnv().VARIANT_ROOT, relative);
}

export function absoluteTrashPath(relative: string) {
  return path.join(getEnv().TRASH_ROOT, relative);
}

export function buildVariantPath(albumId: string, mediaId: string, kind: string, now = new Date()) {
  const yyyy = String(now.getFullYear());
  const mm = pad2(now.getMonth() + 1);
  const relative = path.posix.join(albumId, yyyy, mm, `${mediaId}.${kind}.webp`);
  return relative;
}

export function ensureParentDir(absPath: string) {
  fs.mkdirSync(path.dirname(absPath), { recursive: true });
}
