import { redirect } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";
import InviteAcceptButton from "./InviteAcceptButton";

export default async function InvitePage({ params }: PageProps<"/invite/[token]">) {
  const { token } = await params;

  const invite = await prisma.invite.findUnique({
    where: { token },
    include: { album: { include: { owner: { select: { nickname: true } } } } },
  });

  if (!invite) {
    return <InviteMessage title="유효하지 않은 초대 링크입니다" />;
  }
  // eslint-disable-next-line react-hooks/purity -- server component; evaluated per-request, not memoized render
  const expired = invite.expiresAt.getTime() < Date.now();
  const exhausted = invite.useCount >= invite.maxUses;
  if (expired || exhausted) {
    return <InviteMessage title={expired ? "만료된 초대 링크입니다" : "사용 횟수를 초과한 초대 링크입니다"} />;
  }

  const user = await getSessionUser();
  if (!user) {
    return (
      <InviteMessage title={`"${invite.album.title}" 사진첩 초대`}>
        <p className="mb-4 text-sm text-zinc-500">
          {invite.album.owner.nickname}님이 사진첩에 초대했습니다. 로그인 후 참여할 수 있습니다.
        </p>
        <a
          href={`/login?next=${encodeURIComponent(`/invite/${token}`)}`}
          className="inline-block rounded bg-amber-400 px-4 py-2 text-sm font-medium text-black hover:bg-amber-300"
        >
          로그인하고 참여하기
        </a>
      </InviteMessage>
    );
  }

  const membership = await prisma.albumMember.findUnique({
    where: { albumId_userId: { albumId: invite.albumId, userId: user.id } },
  });
  if (membership) {
    redirect(`/albums/${invite.albumId}`);
  }

  return (
    <InviteMessage title={`"${invite.album.title}" 사진첩 초대`}>
      <p className="mb-4 text-sm text-zinc-500">{invite.album.owner.nickname}님이 사진첩에 초대했습니다.</p>
      <InviteAcceptButton token={token} albumId={invite.albumId} />
    </InviteMessage>
  );
}

function InviteMessage({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <div className="mx-auto max-w-sm px-4 py-20 text-center">
      <h1 className="mb-4 text-xl font-semibold">{title}</h1>
      {children}
    </div>
  );
}
