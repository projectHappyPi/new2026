import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { handleApiError, ApiError } from "@/lib/api-error";

const REACTION_TYPES = ["like", "cute", "funny", "wow"] as const;
const bodySchema = z.object({ type: z.enum(REACTION_TYPES) });

async function loadAccessibleMedia(id: string, userId: string) {
  const media = await prisma.media.findUnique({ where: { id } });
  if (!media || media.deletedAt) throw new ApiError(404, "MEDIA_NOT_FOUND", "삭제되었거나 존재하지 않는 사진입니다");
  await requireMembership(media.albumId, userId);
  return media;
}

async function reactionSummary(mediaId: string, userId: string) {
  const reactions = await prisma.reaction.findMany({ where: { mediaId } });
  const counts: Record<string, number> = {};
  let myReaction: string | null = null;
  for (const r of reactions) {
    counts[r.type] = (counts[r.type] ?? 0) + 1;
    if (r.userId === userId) myReaction = r.type;
  }
  return { reactionCounts: counts, myReaction };
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const media = await loadAccessibleMedia(id, user.id);
    const body = bodySchema.parse(await req.json());

    await prisma.reaction.upsert({
      where: { mediaId_userId: { mediaId: media.id, userId: user.id } },
      create: { mediaId: media.id, userId: user.id, type: body.type },
      update: { type: body.type },
    });

    return NextResponse.json(await reactionSummary(media.id, user.id));
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const media = await loadAccessibleMedia(id, user.id);

    await prisma.reaction
      .delete({ where: { mediaId_userId: { mediaId: media.id, userId: user.id } } })
      .catch(() => {
        /* no existing reaction, nothing to remove */
      });

    return NextResponse.json(await reactionSummary(media.id, user.id));
  } catch (err) {
    return handleApiError(err);
  }
}
