import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/prisma";
import { getSessionUser } from "@/lib/auth";
import { REACTION_META, type ReactionType } from "@/lib/reactions";

const ACCESS_LABEL: Record<string, string> = {
  view: "사진첩 접속",
  join: "초대로 참여",
  upload: "사진 업로드",
  share: "공유",
  download: "다운로드",
};

interface ActivityRow {
  kind: "access" | "reaction";
  actor: string;
  detail: string;
  createdAt: Date;
}

function formatWhen(d: Date) {
  return new Date(d).toLocaleString("ko-KR", { month: "long", day: "numeric", hour: "numeric", minute: "2-digit" });
}

export default async function AlbumActivityPage({ params }: PageProps<"/albums/[id]/activity">) {
  const { id: albumId } = await params;
  const user = await getSessionUser();
  if (!user) redirect(`/login?next=${encodeURIComponent(`/albums/${albumId}/activity`)}`);

  const album = await prisma.album.findUnique({ where: { id: albumId }, select: { id: true, title: true, ownerId: true } });
  if (!album) notFound();
  if (album.ownerId !== user.id && user.role !== "admin") redirect(`/albums/${albumId}`);

  const [accessLogs, reactions, dayReactions] = await Promise.all([
    prisma.accessLog.findMany({
      where: { albumId, action: { in: ["view", "join", "upload", "share", "download"] } },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: { user: { select: { nickname: true } } },
    }),
    prisma.reaction.findMany({
      where: { media: { albumId } },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: { user: { select: { nickname: true } }, media: { select: { originalFilename: true } } },
    }),
    prisma.dayReaction.findMany({
      where: { albumId },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: { user: { select: { nickname: true } } },
    }),
  ]);

  const rows: ActivityRow[] = [
    ...accessLogs
      .filter((a) => a.user)
      .map((a) => ({
        kind: "access" as const,
        actor: a.user!.nickname,
        detail: ACCESS_LABEL[a.action] ?? a.action,
        createdAt: a.createdAt,
      })),
    ...reactions.map((r) => ({
      kind: "reaction" as const,
      actor: r.user.nickname,
      detail: `${REACTION_META[r.type as ReactionType]?.emoji ?? "❔"} ${REACTION_META[r.type as ReactionType]?.label ?? r.type} · ${r.media.originalFilename}`,
      createdAt: r.createdAt,
    })),
    ...dayReactions.map((r) => ({
      kind: "reaction" as const,
      actor: r.user.nickname,
      detail: `${REACTION_META[r.type as ReactionType]?.emoji ?? "❔"} ${REACTION_META[r.type as ReactionType]?.label ?? r.type} · ${r.dayKey} 전체`,
      createdAt: r.createdAt,
    })),
  ]
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
    .slice(0, 150);

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <Link href={`/albums/${albumId}`} className="text-xs text-zinc-500 hover:underline">
        ‹ {album.title}
      </Link>
      <h1 className="mt-2 mb-1 text-2xl font-semibold">활동 기록</h1>
      <p className="mb-6 text-xs text-zinc-500">접속 기록과 반응 기록을 시간순으로 모아봅니다 · 개설자만 볼 수 있어요</p>

      {rows.length === 0 ? (
        <p className="text-sm text-zinc-500">아직 활동 기록이 없습니다.</p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/5 dark:divide-white/5">
          {rows.map((r, i) => (
            <li key={i} className="flex items-center gap-3 py-2.5 text-sm">
              <span
                className={`flex-none rounded-full px-2 py-0.5 text-[10px] font-bold ${
                  r.kind === "access"
                    ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400"
                    : "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400"
                }`}
              >
                {r.kind === "access" ? "접속" : "반응"}
              </span>
              <span className="font-medium">{r.actor}</span>
              <span className="flex-1 truncate text-zinc-500">{r.detail}</span>
              <span className="flex-none text-xs text-zinc-400">{formatWhen(r.createdAt)}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
