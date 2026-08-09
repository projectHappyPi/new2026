import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import sharp from "sharp";
import ffmpegPath from "ffmpeg-static";
import exifr from "exifr";
import { getEnv } from "./env";
import { buildMediaPath, buildVariantPath, absoluteMediaPath, absoluteVariantPath, ensureParentDir } from "./paths";

const IMAGE_MIME = new Set(["image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"]);
const VIDEO_MIME = new Set(["video/mp4", "video/quicktime"]);

export interface ProcessedVariant {
  kind: string;
  path: string;
  bytes: number;
  width: number;
  height: number;
}

export interface ProcessedMedia {
  path: string;
  bytes: number;
  width?: number;
  height?: number;
  takenAt?: Date;
  variants: ProcessedVariant[];
}

function extFromFilename(filename: string) {
  const ext = path.extname(filename).replace(/^\./, "").toLowerCase();
  return ext || "bin";
}

async function generateImageVariants(
  sourceBuffer: Buffer,
  albumId: string,
  mediaId: string,
): Promise<ProcessedVariant[]> {
  const env = getEnv();
  const variants: ProcessedVariant[] = [];
  for (const size of env.THUMB_SIZES_LIST) {
    const variantRelative = buildVariantPath(albumId, mediaId, `thumb_${size}`);
    const variantAbs = absoluteVariantPath(variantRelative);
    ensureParentDir(variantAbs);
    const resized = sharp(sourceBuffer, { failOn: "none" }).rotate().resize({ width: size, withoutEnlargement: true }).webp({ quality: 82 });
    const info = await resized.toFile(variantAbs);
    variants.push({
      kind: `thumb_${size}`,
      path: variantRelative,
      bytes: info.size,
      width: info.width,
      height: info.height,
    });
  }
  return variants;
}

async function extractImageTakenAt(buffer: Buffer): Promise<Date | undefined> {
  try {
    // Some re-saved/re-shared JPEGs (e.g. messenger apps) keep the capture date only in the XMP
    // packet rather than classic EXIF tags — exifr only reads XMP when explicitly enabled.
    const exif = await exifr.parse(buffer, {
      pick: ["DateTimeOriginal", "CreateDate", "ModifyDate"],
      xmp: true,
    });
    const taken = exif?.DateTimeOriginal ?? exif?.CreateDate ?? exif?.ModifyDate;
    if (taken instanceof Date && !Number.isNaN(taken.getTime())) return taken;
    console.warn("[media-processing] no usable taken-date tag found in EXIF/XMP, falling back to file lastModified");
    return undefined;
  } catch (err) {
    console.warn("[media-processing] EXIF/XMP parse failed, falling back to file lastModified", err);
    return undefined;
  }
}

function runFfmpeg(args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    if (!ffmpegPath) {
      return reject(
        new Error(
          "ffmpeg-static did not resolve a binary path for this platform. Try deleting node_modules/ffmpeg-static and running `npm install` again.",
        ),
      );
    }
    execFile(ffmpegPath, args, { maxBuffer: 1024 * 1024 * 10 }, (err, _stdout, stderr) => {
      // ffmpeg always writes its info/progress to stderr even on success, so don't treat it as failure by itself.
      if (err && !err.killed) {
        if ((err as NodeJS.ErrnoException).code === "ENOENT") {
          return reject(
            new Error(
              `ffmpeg binary not found at ${ffmpegPath}. The ffmpeg-static postinstall step likely failed to download it — try deleting node_modules/ffmpeg-static and running \`npm install\` again.`,
            ),
          );
        }
        return reject(err);
      }
      resolve(stderr ?? "");
    });
  });
}

function parseCreationTime(ffmpegStderr: string): Date | undefined {
  const match = ffmpegStderr.match(/creation_time\s*:\s*([0-9T:.Z-]+)/i);
  if (!match) return undefined;
  const parsed = new Date(match[1]);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

async function extractVideoFrame(buffer: Buffer, originalFilename: string): Promise<{ frame: Buffer; takenAt?: Date }> {
  const env = getEnv();
  const ext = extFromFilename(originalFilename);
  const tmpIn = path.join(/* turbopackIgnore: true */ env.TEMP_UPLOAD_ROOT, `${randomUUID()}.${ext}`);
  const tmpOut = path.join(/* turbopackIgnore: true */ env.TEMP_UPLOAD_ROOT, `${randomUUID()}.jpg`);
  await fs.writeFile(tmpIn, buffer);

  try {
    // Probe container metadata (creation_time) and grab a frame in one pass; seeking to 1s covers most
    // clips, falling back to the very first frame for anything shorter.
    let stderr = "";
    try {
      stderr = await runFfmpeg(["-y", "-ss", "00:00:01", "-i", tmpIn, "-frames:v", "1", "-q:v", "3", tmpOut]);
    } catch {
      // ignore, retried below if no output file was produced
    }
    const gotFrame = await fs
      .stat(tmpOut)
      .then((s) => s.size > 0)
      .catch(() => false);
    if (!gotFrame) {
      stderr = await runFfmpeg(["-y", "-i", tmpIn, "-frames:v", "1", "-q:v", "3", tmpOut]);
    }

    const frame = await fs.readFile(tmpOut);
    return { frame, takenAt: parseCreationTime(stderr) };
  } finally {
    await fs.unlink(tmpIn).catch(() => {});
    await fs.unlink(tmpOut).catch(() => {});
  }
}

export async function processUpload(opts: {
  albumId: string;
  mediaId: string;
  originalFilename: string;
  mime: string;
  buffer: Buffer;
  /** Browser-reported File.lastModified — fallback taken-date for files with no embedded metadata
   * (screenshots, exported slides, etc.) where EXIF/container creation_time extraction finds nothing. */
  clientLastModified?: Date;
}): Promise<ProcessedMedia> {
  const ext = extFromFilename(opts.originalFilename);
  const { relative } = buildMediaPath(opts.albumId, ext);
  const absPath = absoluteMediaPath(relative);
  ensureParentDir(absPath);
  await fs.writeFile(absPath, opts.buffer);

  const result: ProcessedMedia = { path: relative, bytes: opts.buffer.byteLength, variants: [] };

  if (IMAGE_MIME.has(opts.mime)) {
    try {
      const metadata = await sharp(opts.buffer, { failOn: "none" }).metadata();
      result.width = metadata.width;
      result.height = metadata.height;
      result.variants = await generateImageVariants(opts.buffer, opts.albumId, opts.mediaId);
    } catch (err) {
      console.error("[media-processing] thumbnail generation failed, keeping original only", err);
    }
    result.takenAt = await extractImageTakenAt(opts.buffer);
  } else if (VIDEO_MIME.has(opts.mime)) {
    // No server-side transcoding of the video itself in this lightweight stack — the original plays
    // back directly via <video>. We only pull a single frame (for the grid thumbnail) and the
    // container's creation_time (for day-grouping) via the bundled ffmpeg-static binary.
    try {
      const { frame, takenAt } = await extractVideoFrame(opts.buffer, opts.originalFilename);
      const metadata = await sharp(frame).metadata();
      result.width = metadata.width;
      result.height = metadata.height;
      result.variants = await generateImageVariants(frame, opts.albumId, opts.mediaId);
      result.takenAt = takenAt;
    } catch (err) {
      console.error("[media-processing] video thumbnail generation failed, keeping original only", err);
    }
  }

  if (!result.takenAt && opts.clientLastModified) {
    result.takenAt = opts.clientLastModified;
  }

  return result;
}

export async function deleteVariantFiles(paths: string[]) {
  await Promise.all(
    paths.map((p) =>
      fs.unlink(absoluteVariantPath(p)).catch(() => {
        /* best effort */
      }),
    ),
  );
}
