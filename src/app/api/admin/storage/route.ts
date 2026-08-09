import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { getStorageStatus, getTrashBytes, getTopAlbums, computeTrend } from "@/lib/storage-status";
import { handleApiError } from "@/lib/api-error";

export async function GET() {
  try {
    await requireAdmin();

    const [status, trashBytes, mediaCount, albumCount, topAlbums, trend] = await Promise.all([
      getStorageStatus(),
      getTrashBytes(),
      prisma.media.count({ where: { deletedAt: null } }),
      prisma.album.count(),
      getTopAlbums(10),
      computeTrend(),
    ]);

    return NextResponse.json({
      ...status,
      trashBytes,
      mediaCount,
      albumCount,
      trend,
      topAlbums,
    });
  } catch (err) {
    return handleApiError(err);
  }
}
