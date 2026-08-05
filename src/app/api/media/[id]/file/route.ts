import fs from "node:fs/promises";
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { absoluteMediaPath } from "@/lib/paths";
import { handleApiError, ApiError } from "@/lib/api-error";

export const runtime = "nodejs";

export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    const media = await prisma.media.findUnique({ where: { id } });
    if (!media || media.deletedAt) throw new ApiError(404, "MEDIA_NOT_FOUND", "삭제되었거나 존재하지 않는 사진입니다");
    await requireMembership(media.albumId, user.id);

    const download = req.nextUrl.searchParams.get("download") === "1";
    const data = await fs.readFile(absoluteMediaPath(media.path));

    if (download) {
      await prisma.accessLog.create({
        data: { userId: user.id, albumId: media.albumId, mediaId: media.id, action: "download" },
      });
    }

    return new NextResponse(new Uint8Array(data), {
      headers: {
        "Content-Type": media.mime,
        "Content-Length": String(data.byteLength),
        "Cache-Control": "private, max-age=300",
        ...(download
          ? { "Content-Disposition": `attachment; filename*=UTF-8''${encodeURIComponent(media.originalFilename)}` }
          : {}),
      },
    });
  } catch (err) {
    return handleApiError(err);
  }
}
