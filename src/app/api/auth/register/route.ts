import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { setSessionCookie, isAdminIdentity } from "@/lib/auth";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, "비밀번호는 8자 이상이어야 합니다"),
  nickname: z.string().min(1).max(30),
});

export async function POST(req: NextRequest) {
  try {
    const body = bodySchema.parse(await req.json());
    const email = body.email.toLowerCase();

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ApiError(409, "EMAIL_TAKEN", "이미 가입된 이메일입니다");
    }

    const userCount = await prisma.user.count();
    const passwordHash = await bcrypt.hash(body.password, 10);
    const role = userCount === 0 || isAdminIdentity({ email }) ? "admin" : "member";

    const user = await prisma.user.create({
      data: { email, passwordHash, nickname: body.nickname, role },
    });

    await setSessionCookie(user.id, user.role);
    return NextResponse.json({ id: user.id, email: user.email, nickname: user.nickname, role: user.role });
  } catch (err) {
    return handleApiError(err);
  }
}
