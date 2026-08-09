import fs from "node:fs/promises";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership, requireOwner } from "@/lib/album-access";
import { absoluteMediaPath, absoluteVariantPath } from "@/lib/paths";
import { invalidateStorageLevelCache } from "@/lib/storage-status";
import { handleApiError, ApiError } from "@/lib/api-error";

export const runtime = "nodejs";

export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const membership = await requireMembership(id, user.id);

    const album = await prisma.album.findUnique({
      where: { id },
      include: {
        owner: { select: { id: true, nickname: true } },
        members: { include: { user: { select: { id: true, nickname: true } } } },
      },
    });
    if (!album) throw new ApiError(404, "ALBUM_NOT_FOUND", "사진첩을 찾을 수 없습니다");

    return NextResponse.json({
      id: album.id,
      title: album.title,
      description: album.description,
      owner: album.owner,
      shareEnabled: album.shareEnabled,
      coverMediaId: album.coverMediaId,
      myRole: membership.role,
      members: album.members.map((m) => ({ id: m.user.id, nickname: m.user.nickname, role: m.role })),
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id: albumId } = await ctx.params;
    const user = await requireUser();
    await requireOwner(albumId, user.id);

    const media = await prisma.media.findMany({ where: { albumId }, include: { variants: true } });

    // The DB rows (members, media, variants, reactions, comments, invites) cascade-delete via the
    // schema's onDelete: Cascade — only the on-disk files and the loosely-referenced access logs
    // need cleaning up by hand afterward.
    await prisma.album.delete({ where: { id: albumId } });
    await prisma.accessLog.deleteMany({ where: { albumId } });

    await Promise.all(
      media.flatMap((m) => [
        fs.unlink(absoluteMediaPath(m.path)).catch(() => {}),
        ...m.variants.map((v) => fs.unlink(absoluteVariantPath(v.path)).catch(() => {})),
      ]),
    );
    invalidateStorageLevelCache();

    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
