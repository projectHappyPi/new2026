import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { setSessionCookie } from "@/lib/auth";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(req: NextRequest) {
  try {
    const body = bodySchema.parse(await req.json());
    const email = body.email.toLowerCase();

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash) {
      throw new ApiError(401, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 올바르지 않습니다");
    }
    const valid = await bcrypt.compare(body.password, user.passwordHash);
    if (!valid) {
      throw new ApiError(401, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 올바르지 않습니다");
    }

    await setSessionCookie(user.id, user.role);
    return NextResponse.json({ id: user.id, email: user.email, nickname: user.nickname, role: user.role });
  } catch (err) {
    return handleApiError(err);
  }
}
