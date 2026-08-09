import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { getCachedStorageLevel } from "@/lib/storage-status";

export async function GET() {
  const user = await getSessionUser();
  if (!user) return NextResponse.json({ show: false });

  const { level } = await getCachedStorageLevel();
  const show = level === "alert" || level === "block";
  return NextResponse.json({
    show,
    level,
    message: level === "block" ? "신규 업로드가 차단되었습니다 (서버 저장 공간 부족)" : "서버 저장 공간이 얼마 남지 않았습니다",
  });
}
