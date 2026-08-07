import Link from "next/link";
import { getSessionUser } from "@/lib/auth";
import LogoutButton from "./LogoutButton";

export default async function NavBar() {
  const user = await getSessionUser();

  return (
    <header className="border-b border-black/10 dark:border-white/10">
      <div className="mx-auto flex max-w-4xl items-center justify-between px-4 py-3">
        <Link href="/albums" className="text-lg font-semibold tracking-tight">
          Pickle
        </Link>
        <nav className="flex items-center gap-4 text-sm">
          {user ? (
            <>
              <Link href="/albums" className="hover:underline">
                사진첩
              </Link>
              {user.role === "admin" && (
                <Link href="/admin/storage" className="hover:underline">
                  관리자
                </Link>
              )}
              <span className="text-zinc-500">{user.nickname}</span>
              <LogoutButton />
            </>
          ) : (
            <>
              <Link href="/login" className="hover:underline">
                로그인
              </Link>
              <Link href="/register" className="hover:underline">
                회원가입
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
