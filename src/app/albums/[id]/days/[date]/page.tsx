import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";

export default async function AlbumDayPage({ params }: PageProps<"/albums/[id]/days/[date]">) {
  const { id: albumId, date } = await params;

  const user = await getSessionUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/albums/${albumId}/days/${date}`)}`);

  const membership = await prisma.albumMember.findUnique({
    where: { albumId_userId: { albumId, userId: user.id } },
  });
  if (!membership && user.role !== "admin") {
    redirect(`/invite-required?albumId=${albumId}`);
  }

  const album = await prisma.album.findUnique({ where: { id: albumId }, select: { title: true } });
  if (!album) {
    return (
      <div className="mx-auto max-w-sm px-4 py-20 text-center">
        <h1 className="text-xl font-semibold">사진첩을 찾을 수 없습니다</h1>
      </div>
    );
  }

  const dayStart = new Date(`${date}T00:00:00`);
  const dayEnd = new Date(dayStart.getTime() + 86_400_000);

  const media = await prisma.media.findMany({
    where: {
      albumId,
      deletedAt: null,
      OR: [
        { takenAt: { gte: dayStart, lt: dayEnd } },
        { takenAt: null, createdAt: { gte: dayStart, lt: dayEnd } },
      ],
    },
    orderBy: { createdAt: "asc" },
    include: { variants: true },
  });

  const label = dayStart.toLocaleDateString("ko-KR", { year: "numeric", month: "long", day: "numeric", weekday: "short" });

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link href={`/albums/${albumId}`} className="text-sm text-zinc-500 hover:underline">
        ← {album.title}
      </Link>
      <h1 className="mb-4 mt-2 text-xl font-semibold">{label}</h1>

      {media.length === 0 ? (
        <p className="text-sm text-zinc-500">이 날짜에 등록된 사진이 없습니다.</p>
      ) : (
        <div className="grid grid-cols-3 gap-1 sm:grid-cols-4 md:grid-cols-5">
          {media.map((m) => (
            <Link
              key={m.id}
              href={`/albums/${albumId}/media/${m.id}`}
              className="relative aspect-square overflow-hidden rounded bg-zinc-200 dark:bg-zinc-800"
            >
              {m.variants.some((v) => v.kind === "thumb_800") ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={`/api/media/${m.id}/variant/thumb_800`} alt={m.originalFilename} className="h-full w-full object-cover" loading="lazy" />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-2xl">
                  {m.mime.startsWith("video/") ? "🎬" : "🖼️"}
                </div>
              )}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
