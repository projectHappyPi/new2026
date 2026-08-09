import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import NicknameForm from "./NicknameForm";

export default async function NicknameOnboardingPage({ searchParams }: PageProps<"/onboarding/nickname">) {
  const { next } = await searchParams;
  const user = await getSessionUser();
  if (!user) redirect("/login");
  if (user.onboarded) redirect(typeof next === "string" ? next : "/albums");

  return <NicknameForm initialNickname={user.nickname} next={typeof next === "string" ? next : "/albums"} />;
}
