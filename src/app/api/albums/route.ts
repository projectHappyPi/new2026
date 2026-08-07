import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/auth";
import { handleApiError } from "@/lib/api-error";

const createSchema = z.object({
  title: z.string().min(1).max(60),
  description: z.string().max(300).optional(),
});

export async function GET() {
  try {
    const user = await requireUser();
    const memberships = await prisma.albumMember.findMany({
      where: { userId: user.id },
      include: {
        album: {
          include: {
            owner: { select: { nickname: true } },
            _count: { select: { media: { where: { deletedAt: null } } } },
          },
        },
      },
      orderBy: { joinedAt: "desc" },
    });

    const albums = memberships.map((m) => ({
      id: m.album.id,
      title: m.album.title,
      description: m.album.description,
      owner: m.album.owner.nickname,
      role: m.role,
      mediaCount: m.album._count.media,
      coverMediaId: m.album.coverMediaId,
      createdAt: m.album.createdAt,
    }));

    return NextResponse.json({ albums });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = createSchema.parse(await req.json());

    const album = await prisma.album.create({
      data: {
        title: body.title,
        description: body.description,
        ownerId: user.id,
        members: {
          create: { userId: user.id, role: "owner" },
        },
      },
    });

    return NextResponse.json({ id: album.id, title: album.title }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
