import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { handleApiError } from "@/lib/api-error";

const bodySchema = z.object({ content: z.string().trim().min(1).max(1000) });

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string; date: string }> }) {
  try {
    const { id: albumId, date } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);

    const comments = await prisma.comment.findMany({
      where: { albumId, dayKey: date },
      orderBy: { createdAt: "asc" },
      include: { user: { select: { nickname: true } } },
    });

    return NextResponse.json({
      comments: comments.map((c) => ({
        id: c.id,
        content: c.content,
        author: c.user.nickname,
        createdAt: c.createdAt,
      })),
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string; date: string }> }) {
  try {
    const { id: albumId, date } = await ctx.params;
    const user = await requireUser();
    await requireMembership(albumId, user.id);
    const body = bodySchema.parse(await req.json());

    const comment = await prisma.comment.create({
      data: { albumId, dayKey: date, userId: user.id, content: body.content },
      include: { user: { select: { nickname: true } } },
    });

    return NextResponse.json(
      { id: comment.id, content: comment.content, author: comment.user.nickname, createdAt: comment.createdAt },
      { status: 201 },
    );
  } catch (err) {
    return handleApiError(err);
  }
}
