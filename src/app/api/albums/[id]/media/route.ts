import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { assertUploadAllowed } from "@/lib/upload-gate";
import { invalidateStorageLevelCache } from "@/lib/storage-status";
import { getEnv } from "@/lib/env";
import { processUpload } from "@/lib/media-processing";
import { handleApiError, ApiError } from "@/lib/api-error";

export const runtime = "nodejs";

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id: albumId } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);
    const env = getEnv();

    const form = await req.formData();
    const file = form.get("file");
    if (!(file instanceof File)) {
      throw new ApiError(400, "FILE_REQUIRED", "업로드할 파일이 없습니다");
    }
    if (!env.ALLOWED_MIME_LIST.includes(file.type)) {
      throw new ApiError(400, "UNSUPPORTED_MIME", `지원하지 않는 파일 형식입니다: ${file.type}`);
    }
    if (file.size > env.UPLOAD_MAX_FILE_BYTES) {
      throw new ApiError(400, "FILE_TOO_LARGE", "파일 크기가 최대 허용치를 초과했습니다");
    }

    await assertUploadAllowed(file.size);

    const mediaId = randomUUID();
    const buffer = Buffer.from(await file.arrayBuffer());
    const processed = await processUpload({
      albumId,
      mediaId,
      originalFilename: file.name,
      mime: file.type,
      buffer,
    });

    const media = await prisma.media.create({
      data: {
        id: mediaId,
        albumId,
        uploaderId: user.id,
        originalFilename: file.name,
        mime: file.type,
        bytes: BigInt(processed.bytes),
        width: processed.width,
        height: processed.height,
        path: processed.path,
        takenAt: processed.takenAt,
        variants: {
          create: processed.variants.map((v) => ({
            kind: v.kind,
            path: v.path,
            bytes: BigInt(v.bytes),
            width: v.width,
            height: v.height,
          })),
        },
      },
      include: { variants: true },
    });

    await prisma.accessLog.create({
      data: { userId: user.id, albumId, mediaId: media.id, action: "upload" },
    });
    invalidateStorageLevelCache();

    return NextResponse.json(
      {
        id: media.id,
        originalFilename: media.originalFilename,
        mime: media.mime,
        bytes: Number(media.bytes),
        width: media.width,
        height: media.height,
        createdAt: media.createdAt,
        takenAt: media.takenAt ?? media.createdAt,
        variants: media.variants.map((v) => ({ kind: v.kind, bytes: Number(v.bytes) })),
      },
      { status: 201 },
    );
  } catch (err) {
    return handleApiError(err);
  }
}

export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id: albumId } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);

    const media = await prisma.media.findMany({
      where: { albumId, deletedAt: null },
      orderBy: { createdAt: "desc" },
      include: { variants: true, uploader: { select: { nickname: true } }, reactions: true },
    });

    return NextResponse.json({
      media: media.map((m) => {
        const counts: Record<string, number> = {};
        let myReaction: string | null = null;
        for (const r of m.reactions) {
          counts[r.type] = (counts[r.type] ?? 0) + 1;
          if (r.userId === user.id) myReaction = r.type;
        }
        return {
          id: m.id,
          originalFilename: m.originalFilename,
          mime: m.mime,
          bytes: Number(m.bytes),
          width: m.width,
          height: m.height,
          createdAt: m.createdAt,
          takenAt: m.takenAt ?? m.createdAt,
          uploader: m.uploader.nickname,
          isVideo: m.mime.startsWith("video/"),
          thumbKinds: m.variants.map((v) => v.kind),
          reactionCounts: counts,
          myReaction,
        };
      }),
    });
  } catch (err) {
    return handleApiError(err);
  }
}
