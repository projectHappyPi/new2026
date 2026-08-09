import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";

const bodySchema = z.object({ path: z.string() });

function parseShareTarget(path: string): { albumId?: string; mediaId?: string } {
  const mediaMatch = path.match(/^\/albums\/([^/]+)\/media\/([^/]+)/);
  if (mediaMatch) return { albumId: mediaMatch[1], mediaId: mediaMatch[2] };
  const dayMatch = path.match(/^\/albums\/([^/]+)\/days\//);
  if (dayMatch) return { albumId: dayMatch[1] };
  const albumMatch = path.match(/^\/albums\/([^/]+)/);
  if (albumMatch) return { albumId: albumMatch[1] };
  return {};
}

export async function POST(req: NextRequest) {
  const user = await getSessionUser();
  const body = bodySchema.parse(await req.json());
  const target = parseShareTarget(body.path);

  await prisma.accessLog.create({
    data: {
      userId: user?.id,
      albumId: target.albumId,
      mediaId: target.mediaId,
      action: "share",
    },
  });

  return NextResponse.json({ ok: true });
}
