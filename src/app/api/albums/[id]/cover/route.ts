import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireOwner } from "@/lib/album-access";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({ mediaId: z.string() });

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id: albumId } = await ctx.params;
    const user = await requireUser();
    await requireOwner(albumId, user.id);
    const body = bodySchema.parse(await req.json());

    const media = await prisma.media.findUnique({ where: { id: body.mediaId } });
    if (!media || media.albumId !== albumId || media.deletedAt) {
      throw new ApiError(404, "MEDIA_NOT_FOUND", "사진을 찾을 수 없습니다");
    }

    await prisma.album.update({ where: { id: albumId }, data: { coverMediaId: body.mediaId } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
