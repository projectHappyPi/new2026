import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { handleApiError, ApiError } from "@/lib/api-error";

export async function POST(_req: Request, ctx: { params: Promise<{ token: string }> }) {
  try {
    const { token } = await ctx.params;
    const user = await requireUser();

    const invite = await prisma.invite.findUnique({ where: { token } });
    if (!invite) throw new ApiError(404, "INVITE_NOT_FOUND", "초대 링크를 찾을 수 없습니다");
    if (invite.expiresAt.getTime() < Date.now()) throw new ApiError(410, "INVITE_EXPIRED", "만료된 초대 링크입니다");
    if (invite.useCount >= invite.maxUses) throw new ApiError(410, "INVITE_EXHAUSTED", "사용 횟수를 초과한 초대 링크입니다");

    const existing = await prisma.albumMember.findUnique({
      where: { albumId_userId: { albumId: invite.albumId, userId: user.id } },
    });

    if (!existing) {
      await prisma.$transaction([
        prisma.albumMember.create({ data: { albumId: invite.albumId, userId: user.id, role: "member" } }),
        prisma.invite.update({ where: { id: invite.id }, data: { useCount: { increment: 1 } } }),
        prisma.accessLog.create({
          data: { userId: user.id, albumId: invite.albumId, action: "join" },
        }),
      ]);
    }

    return NextResponse.json({ albumId: invite.albumId });
  } catch (err) {
    return handleApiError(err);
  }
}
