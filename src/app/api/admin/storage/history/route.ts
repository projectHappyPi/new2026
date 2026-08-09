import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { handleApiError } from "@/lib/api-error";

export async function GET(req: NextRequest) {
  try {
    await requireAdmin();
    const days = Math.min(365, Math.max(1, Number(req.nextUrl.searchParams.get("days") ?? 30)));

    const rows = await prisma.storageStats.findMany({
      orderBy: { date: "desc" },
      take: days,
    });

    return NextResponse.json({
      history: rows
        .slice()
        .reverse()
        .map((r) => ({
          date: r.date,
          usedBytes: Number(r.usedBytes),
          freeBytes: Number(r.freeBytes),
          totalBytes: Number(r.totalBytes),
          level: r.level,
        })),
    });
  } catch (err) {
    return handleApiError(err);
  }
}
