import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";

export async function GET(_req: Request, ctx: { params: Promise<{ token: string }> }) {
  const { token } = await ctx.params;
  const invite = await prisma.invite.findUnique({
    where: { token },
    include: { album: { include: { owner: { select: { nickname: true } } } } },
  });

  if (!invite) {
    return NextResponse.json({ valid: false, reason: "NOT_FOUND" }, { status: 404 });
  }
  const expired = invite.expiresAt.getTime() < Date.now();
  const exhausted = invite.useCount >= invite.maxUses;
  if (expired || exhausted) {
    return NextResponse.json({ valid: false, reason: expired ? "EXPIRED" : "EXHAUSTED" }, { status: 410 });
  }

  const user = await getSessionUser();
  let alreadyMember = false;
  if (user) {
    const membership = await prisma.albumMember.findUnique({
      where: { albumId_userId: { albumId: invite.albumId, userId: user.id } },
    });
    alreadyMember = Boolean(membership);
  }

  return NextResponse.json({
    valid: true,
    albumId: invite.albumId,
    albumTitle: invite.album.title,
    owner: invite.album.owner.nickname,
    loggedIn: Boolean(user),
    alreadyMember,
  });
}
