import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth";
import { runTrashPurge } from "@/lib/scheduler";
import { handleApiError } from "@/lib/api-error";

export async function POST() {
  try {
    await requireAdmin();
    // "만료 대기 없이 휴지통 즉시 비우기": purge everything currently in trash, ignoring the retention window.
    const purged = await runTrashPurge(new Date());
    return NextResponse.json({ ok: true, purged });
  } catch (err) {
    return handleApiError(err);
  }
}
