import { NextRequest, NextResponse } from "next/server";
import { customAlphabet } from "nanoid";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireOwner } from "@/lib/album-access";
import { getEnv } from "@/lib/env";
import { handleApiError } from "@/lib/api-error";

const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    await requireOwner(id, user.id);
    const env = getEnv();

    const nanoid = customAlphabet(alphabet, env.INVITE_TOKEN_LENGTH);
    const token = nanoid();
    const expiresAt = new Date(Date.now() + env.INVITE_DEFAULT_EXPIRE_DAYS * 86_400_000);

    const invite = await prisma.invite.create({
      data: {
        token,
        albumId: id,
        expiresAt,
        maxUses: env.INVITE_DEFAULT_MAX_USES,
      },
    });

    return NextResponse.json({
      token: invite.token,
      url: `${env.WEB_BASE_URL}/invite/${invite.token}`,
      expiresAt: invite.expiresAt,
      maxUses: invite.maxUses,
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    await requireOwner(id, user.id);
    const env = getEnv();

    const invites = await prisma.invite.findMany({
      where: { albumId: id, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json({
      invites: invites.map((i) => ({
        token: i.token,
        url: `${env.WEB_BASE_URL}/invite/${i.token}`,
        expiresAt: i.expiresAt,
        maxUses: i.maxUses,
        useCount: i.useCount,
      })),
    });
  } catch (err) {
    return handleApiError(err);
  }
}
