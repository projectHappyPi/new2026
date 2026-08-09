import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { getEnv } from "@/lib/env";
import StorageDashboard from "./StorageDashboard";

export default async function AdminStoragePage() {
  const user = await getSessionUser();
  if (!user) redirect("/login?next=/admin/storage");
  if (user.role !== "admin") redirect("/albums");

  const env = getEnv();
  return (
    <StorageDashboard
      thresholds={{
        warn: env.STORAGE_WARN_PERCENT,
        alert: env.STORAGE_ALERT_PERCENT,
        block: env.STORAGE_BLOCK_PERCENT,
      }}
    />
  );
}
