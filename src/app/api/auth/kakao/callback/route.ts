import { NextRequest, NextResponse } from "next/server";
import { getEnv } from "@/lib/env";
import { prisma } from "@/lib/prisma";
import { setSessionCookie, isAdminIdentity } from "@/lib/auth";

export async function GET(req: NextRequest) {
  const env = getEnv();
  if (!env.KAKAO_ENABLED) {
    return NextResponse.json({ code: "KAKAO_DISABLED", message: "카카오 로그인이 설정되지 않았습니다" }, { status: 404 });
  }

  const code = req.nextUrl.searchParams.get("code");
  const state = req.nextUrl.searchParams.get("state");
  const next = state ? decodeURIComponent(state) : "/albums";
  if (!code) {
    return NextResponse.redirect(new URL(`/login?error=kakao_missing_code`, env.APP_BASE_URL));
  }

  try {
    const redirectUri = env.KAKAO_REDIRECT_URI ?? `${env.APP_BASE_URL}/api/auth/kakao/callback`;
    const tokenRes = await fetch("https://kauth.kakao.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        client_id: env.KAKAO_REST_API_KEY!,
        redirect_uri: redirectUri,
        code,
        ...(env.KAKAO_CLIENT_SECRET ? { client_secret: env.KAKAO_CLIENT_SECRET } : {}),
      }),
    });
    if (!tokenRes.ok) throw new Error(`kakao token exchange failed: ${tokenRes.status}`);
    const tokenJson = (await tokenRes.json()) as { access_token: string };

    const profileRes = await fetch("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${tokenJson.access_token}` },
    });
    if (!profileRes.ok) throw new Error(`kakao profile fetch failed: ${profileRes.status}`);
    const profile = (await profileRes.json()) as {
      id: number;
      kakao_account?: { profile?: { nickname?: string }; email?: string };
    };

    const kakaoId = String(profile.id);
    const nickname = profile.kakao_account?.profile?.nickname ?? `카카오사용자${kakaoId.slice(-4)}`;

    let user = await prisma.user.findUnique({ where: { kakaoId } });
    if (!user) {
      const userCount = await prisma.user.count();
      const role = userCount === 0 || isAdminIdentity({ kakaoId }) ? "admin" : "member";
      user = await prisma.user.create({ data: { kakaoId, nickname, role } });
    }

    await setSessionCookie(user.id, user.role);
    return NextResponse.redirect(new URL(next, env.APP_BASE_URL));
  } catch (err) {
    console.error("[kakao-callback]", err);
    return NextResponse.redirect(new URL(`/login?error=kakao_failed`, env.APP_BASE_URL));
  }
}
