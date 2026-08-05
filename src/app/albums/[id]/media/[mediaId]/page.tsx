import { redirect } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";
import MediaViewer from "./MediaViewer";

export default async function MediaViewerPage({ params }: PageProps<"/albums/[id]/media/[mediaId]">) {
  const { id: albumId, mediaId } = await params;

  const user = await getSessionUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/albums/${albumId}/media/${mediaId}`)}`);

  const membership = await prisma.albumMember.findUnique({
    where: { albumId_userId: { albumId, userId: user.id } },
  });
  if (!membership && user.role !== "admin") {
    redirect(`/invite-required?albumId=${albumId}`);
  }

  const media = await prisma.media.findUnique({
    where: { id: mediaId },
    include: { album: { select: { title: true, ownerId: true } }, uploader: { select: { nickname: true } } },
  });

  if (!media || media.albumId !== albumId) {
    return (
      <div className="mx-auto max-w-sm px-4 py-20 text-center">
        <h1 className="mb-2 text-xl font-semibold">삭제된 사진입니다</h1>
        <a href={`/albums/${albumId}`} className="text-sm underline">
          타임라인으로 돌아가기
        </a>
      </div>
    );
  }
  if (media.deletedAt) {
    return (
      <div className="mx-auto max-w-sm px-4 py-20 text-center">
        <h1 className="mb-2 text-xl font-semibold">삭제된 사진입니다</h1>
        <a href={`/albums/${albumId}`} className="text-sm underline">
          타임라인으로 돌아가기
        </a>
      </div>
    );
  }

  const isOwner = media.album.ownerId === user.id;
  const isUploader = media.uploaderId === user.id;

  return (
    <MediaViewer
      albumId={albumId}
      mediaId={media.id}
      albumTitle={media.album.title}
      originalFilename={media.originalFilename}
      mime={media.mime}
      uploader={media.uploader.nickname}
      createdAt={media.createdAt.toISOString()}
      canManage={isOwner || isUploader || user.role === "admin"}
      canSetCover={isOwner}
    />
  );
}
