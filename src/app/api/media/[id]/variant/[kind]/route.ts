import fs from "node:fs/promises";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { absoluteVariantPath } from "@/lib/paths";
import { handleApiError, ApiError } from "@/lib/api-error";

export const runtime = "nodejs";

export async function GET(_req: Request, ctx: { params: Promise<{ id: string; kind: string }> }) {
  try {
    const { id, kind } = await ctx.params;
    const user = await requireUser();
    const media = await prisma.media.findUnique({ where: { id } });
    if (!media || media.deletedAt) throw new ApiError(404, "MEDIA_NOT_FOUND", "삭제되었거나 존재하지 않는 사진입니다");
    await requireMembership(media.albumId, user.id);

    const variant = await prisma.mediaVariant.findFirst({ where: { mediaId: id, kind } });
    if (!variant) throw new ApiError(404, "VARIANT_NOT_FOUND", "썸네일을 찾을 수 없습니다");

    const data = await fs.readFile(absoluteVariantPath(variant.path));
    return new NextResponse(new Uint8Array(data), {
      headers: {
        "Content-Type": "image/webp",
        "Content-Length": String(data.byteLength),
        "Cache-Control": "private, max-age=3600",
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}
