import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";
import InviteBox from "./InviteBox";
import AlbumMediaSection from "./AlbumMediaSection";

export default async function AlbumDetailPage({ params }: PageProps<"/albums/[id]">) {
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/albums/${id}`)}`);

  const membership = await prisma.albumMember.findUnique({
    where: { albumId_userId: { albumId: id, userId: user.id } },
  });
  if (!membership && user.role !== "admin") {
    redirect(`/invite-required?albumId=${id}`);
  }

  const album = await prisma.album.findUnique({
    where: { id },
    include: { owner: { select: { nickname: true } }, members: { include: { user: { select: { nickname: true } } } } },
  });
  if (!album) notFound();

  const isOwner = album.ownerId === user.id;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">{album.title}</h1>
          {album.description && <p className="mt-1 text-sm text-zinc-500">{album.description}</p>}
          <p className="mt-1 text-xs text-zinc-500">
            개설자 {album.owner.nickname} · 멤버 {album.members.length}명
          </p>
        </div>
        {isOwner && (
          <div className="w-full sm:w-72">
            <InviteBox albumId={album.id} />
          </div>
        )}
      </div>

      <AlbumMediaSection albumId={album.id} isOwner={isOwner} coverMediaId={album.coverMediaId} albumTitle={album.title} />
    </div>
  );
}
