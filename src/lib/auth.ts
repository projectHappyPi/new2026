import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";
import { getEnv } from "./env";
import { prisma } from "./prisma";

const SESSION_COOKIE = "bebelog_session";

function secretKey() {
  return new TextEncoder().encode(getEnv().JWT_SECRET);
}

export interface SessionPayload {
  sub: string; // user id
  role: string;
}

export async function createSessionToken(userId: string, role: string) {
  const env = getEnv();
  return new SignJWT({ role } satisfies Omit<SessionPayload, "sub">)
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${env.JWT_ACCESS_EXPIRES_MIN}m`)
    .sign(secretKey());
}

export async function setSessionCookie(userId: string, role: string) {
  const token = await createSessionToken(userId, role);
  const env = getEnv();
  const store = await cookies();
  store.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: env.JWT_ACCESS_EXPIRES_MIN * 60,
  });
}

export async function clearSessionCookie() {
  const store = await cookies();
  store.delete(SESSION_COOKIE);
}

async function verifyToken(token: string): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey());
    if (!payload.sub) return null;
    return { sub: payload.sub, role: String(payload.role ?? "member") };
  } catch {
    return null;
  }
}

export async function getSessionUser() {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const payload = await verifyToken(token);
  if (!payload) return null;

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) return null;
  return user;
}

export async function requireUser() {
  const user = await getSessionUser();
  if (!user) {
    const err = new Error("UNAUTHORIZED");
    err.name = "UNAUTHORIZED";
    throw err;
  }
  return user;
}

export async function requireAdmin() {
  const user = await requireUser();
  if (user.role !== "admin") {
    const err = new Error("FORBIDDEN");
    err.name = "FORBIDDEN";
    throw err;
  }
  return user;
}

export function isAdminIdentity(opts: { email?: string | null; kakaoId?: string | null }) {
  const env = getEnv();
  if (opts.email && env.ADMIN_EMAILS_LIST.includes(opts.email.toLowerCase())) return true;
  if (opts.kakaoId && env.ADMIN_KAKAO_IDS_LIST.includes(opts.kakaoId)) return true;
  return false;
}
