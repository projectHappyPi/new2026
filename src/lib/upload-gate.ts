import { getCachedStorageLevel } from "./storage-status";
import { getEnv } from "./env";
import { ApiError } from "./api-error";

/** Mirrors SPEC 1.4: checked on every upload start, not just the hourly batch. */
export async function assertUploadAllowed(requestedBytes: number) {
  const env = getEnv();
  const { level, free } = await getCachedStorageLevel();

  if (level === "block") {
    throw new ApiError(507, "STORAGE_FULL", "서버 저장 공간이 부족합니다");
  }
  if (free - requestedBytes < env.STORAGE_MIN_FREE_BUFFER_BYTES) {
    throw new ApiError(507, "STORAGE_FULL", "서버 저장 공간이 부족합니다");
  }
}
