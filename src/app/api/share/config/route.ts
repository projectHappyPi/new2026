import { NextResponse } from "next/server";
import { getEnv } from "@/lib/env";

export async function GET() {
  const env = getEnv();
  return NextResponse.json({
    shareEnabled: env.SHARE_ENABLED,
    kakaoEnabled: env.KAKAO_ENABLED && Boolean(env.KAKAO_JS_KEY),
    kakaoJsKey: env.KAKAO_JS_KEY ?? null,
    shareCoverImageUrl: env.SHARE_COVER_IMAGE_URL,
    webBaseUrl: env.WEB_BASE_URL,
  });
}
