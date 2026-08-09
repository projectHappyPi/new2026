import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({ nickname: z.string().trim().min(1).max(30) });

export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = bodySchema.parse(await req.json());

    if (body.nickname !== user.nickname) {
      const taken = await prisma.user.findUnique({ where: { nickname: body.nickname } });
      if (taken) throw new ApiError(409, "NICKNAME_TAKEN", "이미 사용 중인 닉네임입니다");
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { nickname: body.nickname, onboarded: true },
    });

    return NextResponse.json({ id: updated.id, nickname: updated.nickname });
  } catch (err) {
    return handleApiError(err);
  }
}
