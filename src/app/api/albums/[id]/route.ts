import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { handleApiError, ApiError } from "@/lib/api-error";

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
