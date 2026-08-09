import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireOwner } from "@/lib/album-access";
import { handleApiError, ApiError } from "@/lib/api-error";

export async function DELETE(_req: Request, ctx: { params: Promise<{ id: string; userId: string }> }) {
  try {
    const { id: albumId, userId: targetUserId } = await ctx.params;
    const user = await requireUser();
    await requireOwner(albumId, user.id);

    const album = await prisma.album.findUnique({ where: { id: albumId } });
    if (!album) throw new ApiError(404, "ALBUM_NOT_FOUND", "사진첩을 찾을 수 없습니다");
    if (album.ownerId === targetUserId) {
      throw new ApiError(400, "CANNOT_REMOVE_OWNER", "개설자는 강퇴할 수 없습니다");
    }

    await prisma.albumMember.delete({
      where: { albumId_userId: { albumId, userId: targetUserId } },
    });

    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
