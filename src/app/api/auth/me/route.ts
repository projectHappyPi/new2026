import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { getEnv } from "@/lib/env";

export async function GET() {
  const user = await getSessionUser();
  const env = getEnv();
  if (!user) {
    return NextResponse.json({ user: null, kakaoEnabled: env.KAKAO_ENABLED });
  }
  return NextResponse.json({
    user: { id: user.id, email: user.email, nickname: user.nickname, role: user.role },
    kakaoEnabled: env.KAKAO_ENABLED,
  });
}
