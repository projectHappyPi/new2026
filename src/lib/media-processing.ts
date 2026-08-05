import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import { getEnv } from "./env";
import { buildMediaPath, buildVariantPath, absoluteMediaPath, absoluteVariantPath, ensureParentDir } from "./paths";

const IMAGE_MIME = new Set(["image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"]);

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
  variants: ProcessedVariant[];
}

function extFromFilename(filename: string) {
  const ext = path.extname(filename).replace(/^\./, "").toLowerCase();
  return ext || "bin";
}

export async function processUpload(opts: {
  albumId: string;
  mediaId: string;
  originalFilename: string;
  mime: string;
  buffer: Buffer;
}): Promise<ProcessedMedia> {
  const env = getEnv();
  const ext = extFromFilename(opts.originalFilename);
  const { relative } = buildMediaPath(opts.albumId, ext);
  const absPath = absoluteMediaPath(relative);
  ensureParentDir(absPath);
  await fs.writeFile(absPath, opts.buffer);

  const result: ProcessedMedia = { path: relative, bytes: opts.buffer.byteLength, variants: [] };

  if (IMAGE_MIME.has(opts.mime)) {
    try {
      const image = sharp(opts.buffer, { failOn: "none" });
      const metadata = await image.metadata();
      result.width = metadata.width;
      result.height = metadata.height;

      for (const size of env.THUMB_SIZES_LIST) {
        const variantRelative = buildVariantPath(opts.albumId, opts.mediaId, `thumb_${size}`);
        const variantAbs = absoluteVariantPath(variantRelative);
        ensureParentDir(variantAbs);
        const resized = sharp(opts.buffer, { failOn: "none" }).rotate().resize({ width: size, withoutEnlargement: true }).webp({ quality: 82 });
        const info = await resized.toFile(variantAbs);
        result.variants.push({
          kind: `thumb_${size}`,
          path: variantRelative,
          bytes: info.size,
          width: info.width,
          height: info.height,
        });
      }
    } catch (err) {
      console.error("[media-processing] thumbnail generation failed, keeping original only", err);
    }
  }
  // video/*: no server-side transcoding in this lightweight stack (no ffmpeg dependency).
  // Original is kept and played back directly via <video> in the browser.

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
