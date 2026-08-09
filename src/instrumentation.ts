export async function register() {
  if (process.env.NEXT_RUNTIME !== "nodejs") return;

  const { getEnv } = await import("@/lib/env");
  const { ensureStorageDirs } = await import("@/lib/paths");
  const { ensureShareCoverImage } = await import("@/lib/share-cover");
  const { startSchedulers } = await import("@/lib/scheduler");

  getEnv(); // throws & stops boot if required env vars are missing
  ensureStorageDirs();
  await ensureShareCoverImage();
  startSchedulers();
}
