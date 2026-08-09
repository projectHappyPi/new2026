import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { handleApiError } from "@/lib/api-error";

const REACTION_TYPES = ["like", "cute", "funny", "wow"] as const;
const bodySchema = z.object({ type: z.enum(REACTION_TYPES) });

async function reactionSummary(albumId: string, dayKey: string, userId: string) {
  const reactions = await prisma.dayReaction.findMany({ where: { albumId, dayKey } });
  const counts: Record<string, number> = {};
  let myReaction: string | null = null;
  for (const r of reactions) {
    counts[r.type] = (counts[r.type] ?? 0) + 1;
    if (r.userId === userId) myReaction = r.type;
  }
  return { reactionCounts: counts, myReaction };
}

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string; date: string }> }) {
  try {
    const { id: albumId, date } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);

    return NextResponse.json(await reactionSummary(albumId, date, user.id));
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string; date: string }> }) {
  try {
    const { id: albumId, date } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);
    const body = bodySchema.parse(await req.json());

    await prisma.dayReaction.upsert({
      where: { albumId_dayKey_userId: { albumId, dayKey: date, userId: user.id } },
      create: { albumId, dayKey: date, userId: user.id, type: body.type },
      update: { type: body.type },
    });

    return NextResponse.json(await reactionSummary(albumId, date, user.id));
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: NextRequest, ctx: { params: Promise<{ id: string; date: string }> }) {
  try {
    const { id: albumId, date } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);

    await prisma.dayReaction
      .delete({ where: { albumId_dayKey_userId: { albumId, dayKey: date, userId: user.id } } })
      .catch(() => {
        /* no existing reaction, nothing to remove */
      });

    return NextResponse.json(await reactionSummary(albumId, date, user.id));
  } catch (err) {
    return handleApiError(err);
  }
}
