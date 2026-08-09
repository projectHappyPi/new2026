import { NextRequest, NextResponse } from "next/server";
import { getEnv } from "@/lib/env";

export async function GET(req: NextRequest) {
  const env = getEnv();
  if (!env.KAKAO_ENABLED) {
    return NextResponse.json(
      { code: "KAKAO_DISABLED", message: "카카오 로그인이 설정되지 않았습니다 (KAKAO_REST_API_KEY / KAKAO_JS_KEY 필요)" },
      { status: 404 },
    );
  }
  const next = req.nextUrl.searchParams.get("next") ?? "/albums";
  const authorizeUrl = new URL("https://kauth.kakao.com/oauth/authorize");
  authorizeUrl.searchParams.set("client_id", env.KAKAO_REST_API_KEY!);
  authorizeUrl.searchParams.set("redirect_uri", env.KAKAO_REDIRECT_URI ?? `${env.APP_BASE_URL}/api/auth/kakao/callback`);
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("state", encodeURIComponent(next));

  return NextResponse.redirect(authorizeUrl.toString());
}
