import fs from "node:fs/promises";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { absoluteMediaPath, absoluteTrashPath, ensureParentDir } from "@/lib/paths";
import { invalidateStorageLevelCache } from "@/lib/storage-status";
import { handleApiError, ApiError } from "@/lib/api-error";

export const runtime = "nodejs";

async function loadMediaWithAccess(id: string, userId: string) {
  const media = await prisma.media.findUnique({ where: { id } });
  if (!media || media.deletedAt) throw new ApiError(404, "MEDIA_NOT_FOUND", "삭제되었거나 존재하지 않는 사진입니다");
  await requireMembership(media.albumId, userId);
  return media;
}

export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const media = await loadMediaWithAccess(id, user.id);
    const withVariants = await prisma.media.findUnique({ where: { id: media.id }, include: { variants: true, uploader: { select: { nickname: true } }, album: { select: { title: true, ownerId: true } } } });

    return NextResponse.json({
      id: media.id,
      albumId: media.albumId,
      albumTitle: withVariants?.album.title,
      originalFilename: media.originalFilename,
      mime: media.mime,
      bytes: Number(media.bytes),
      width: media.width,
      height: media.height,
      createdAt: media.createdAt,
      uploader: withVariants?.uploader.nickname,
      isOwner: withVariants?.album.ownerId === user.id,
      variants: withVariants?.variants.map((v) => ({ kind: v.kind })) ?? [],
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const media = await loadMediaWithAccess(id, user.id);

    const album = await prisma.album.findUnique({ where: { id: media.albumId } });
    const isOwner = album?.ownerId === user.id;
    const isUploader = media.uploaderId === user.id;
    if (!isOwner && !isUploader && user.role !== "admin") {
      throw new ApiError(403, "NOT_ALLOWED", "삭제 권한이 없습니다");
    }

    const srcAbs = absoluteMediaPath(media.path);
    const trashAbs = absoluteTrashPath(media.path);
    try {
      ensureParentDir(trashAbs);
      await fs.rename(srcAbs, trashAbs);
    } catch (err) {
      console.error("[media-delete] failed to move file to trash", err);
    }

    await prisma.media.update({ where: { id: media.id }, data: { deletedAt: new Date() } });
    invalidateStorageLevelCache();

    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
