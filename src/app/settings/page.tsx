import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import SettingsForm from "./SettingsForm";

export default async function SettingsPage() {
  const user = await getSessionUser();
  if (!user) redirect("/login?next=/settings");

  return <SettingsForm initialNickname={user.nickname} email={user.email} />;
}
