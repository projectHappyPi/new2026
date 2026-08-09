import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { setSessionCookie, isAdminIdentity } from "@/lib/auth";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, "비밀번호는 8자 이상이어야 합니다"),
  nickname: z.string().max(30).optional(),
});

export async function POST(req: NextRequest) {
  try {
    const body = bodySchema.parse(await req.json());
    const email = body.email.toLowerCase();

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ApiError(409, "EMAIL_TAKEN", "이미 가입된 이메일입니다");
    }

    // Nickname is optional at signup — an empty one just shows the email until they set a
    // real nickname later from settings, rather than blocking registration on it.
    const nickname = body.nickname?.trim() || email;
    const nicknameTaken = await prisma.user.findUnique({ where: { nickname } });
    if (nicknameTaken) {
      throw new ApiError(409, "NICKNAME_TAKEN", "이미 사용 중인 닉네임입니다");
    }

    const userCount = await prisma.user.count();
    const passwordHash = await bcrypt.hash(body.password, 10);
    const role = userCount === 0 || isAdminIdentity({ email }) ? "admin" : "member";

    const user = await prisma.user.create({
      data: { email, passwordHash, nickname, role },
    });

    await setSessionCookie(user.id, user.role);
    return NextResponse.json({ id: user.id, email: user.email, nickname: user.nickname, role: user.role });
  } catch (err) {
    return handleApiError(err);
  }
}
