import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { handleApiError } from "@/lib/api-error";

const bodySchema = z.object({ nickname: z.string().min(1).max(30) });

export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = bodySchema.parse(await req.json());

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { nickname: body.nickname, onboarded: true },
    });

    return NextResponse.json({ id: updated.id, nickname: updated.nickname });
  } catch (err) {
    return handleApiError(err);
  }
}
