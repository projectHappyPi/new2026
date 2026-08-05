import { prisma } from "./prisma";
import { ApiError } from "./api-error";

export async function requireMembership(albumId: string, userId: string, adminBypass = true) {
  const membership = await prisma.albumMember.findUnique({
    where: { albumId_userId: { albumId, userId } },
  });
  if (membership) return membership;

  if (adminBypass) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (user?.role === "admin") return { albumId, userId, role: "owner" as const, joinedAt: new Date(), id: "admin-bypass" };
  }

  throw new ApiError(403, "NOT_A_MEMBER", "이 사진첩의 멤버가 아닙니다");
}

export async function requireOwner(albumId: string, userId: string) {
  const membership = await requireMembership(albumId, userId);
  if (membership.role !== "owner") {
    throw new ApiError(403, "NOT_OWNER", "개설자만 가능한 작업입니다");
  }
  return membership;
}
