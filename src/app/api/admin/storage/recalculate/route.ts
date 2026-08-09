import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth";
import { runStorageCheck } from "@/lib/scheduler";
import { handleApiError } from "@/lib/api-error";

export async function POST() {
  try {
    await requireAdmin();
    await runStorageCheck();
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
