import { z } from "zod";
import path from "node:path";

function csv(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function intCsv(value: string | undefined): number[] {
  return csv(value).map((s) => Number(s));
}

const rawSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  APP_PORT: z.coerce.number().default(3000),
  APP_BASE_URL: z.string().url().default("http://localhost:3000"),
  WEB_BASE_URL: z.string().url().default("http://localhost:3000"),
  TZ: z.string().default("Asia/Seoul"),

  DATABASE_URL: z.string().default("file:./data/db/bebelog.sqlite"),

  MEDIA_ROOT: z.string().default("./data/media"),
  VARIANT_ROOT: z.string().default("./data/variants"),
  TEMP_UPLOAD_ROOT: z.string().default("./data/tmp"),
  TRASH_ROOT: z.string().default("./data/trash"),

  STORAGE_CHECK_PATH: z.string().default("./data"),
  STORAGE_TOTAL_BYTES_OVERRIDE: z.coerce.number().optional(),
  STORAGE_QUOTA_BYTES: z.coerce.number().optional(),
  STORAGE_WARN_PERCENT: z.coerce.number().default(80),
  STORAGE_ALERT_PERCENT: z.coerce.number().default(90),
  STORAGE_BLOCK_PERCENT: z.coerce.number().default(95),
  STORAGE_CHECK_CRON: z.string().default("0 * * * *"),
  STORAGE_ALERT_COOLDOWN_HOURS: z.coerce.number().default(24),
  STORAGE_LEVEL_CACHE_TTL_SECONDS: z.coerce.number().default(60),
  STORAGE_MIN_FREE_BUFFER_BYTES: z.coerce.number().default(1073741824),

  UPLOAD_MAX_FILE_BYTES: z.coerce.number().default(5368709120),
  UPLOAD_MAX_BATCH_COUNT: z.coerce.number().default(100),
  ALLOWED_MIME: z.string().default("image/jpeg,image/png,image/heic,image/heif,image/webp,video/mp4,video/quicktime"),

  THUMB_SIZES: z.string().default("200,800,1600"),
  KEEP_ORIGINAL: z
    .string()
    .default("true")
    .transform((v) => v === "true"),

  JWT_SECRET: z.string().min(16, "JWT_SECRET 은 최소 16자 이상이어야 합니다 (openssl rand -hex 32)"),
  JWT_ACCESS_EXPIRES_MIN: z.coerce.number().default(60 * 24 * 30),

  KAKAO_REST_API_KEY: z.string().optional(),
  KAKAO_JS_KEY: z.string().optional(),
  KAKAO_CLIENT_SECRET: z.string().optional(),
  KAKAO_REDIRECT_URI: z.string().optional(),

  ADMIN_KAKAO_IDS: z.string().optional(),
  ADMIN_EMAILS: z.string().optional(),
  ADMIN_ALERT_EMAIL: z.string().email("ADMIN_ALERT_EMAIL 은 필수값입니다 (스토리지 경고 수신 주소)"),

  INVITE_DEFAULT_EXPIRE_DAYS: z.coerce.number().default(7),
  INVITE_DEFAULT_MAX_USES: z.coerce.number().default(10),
  INVITE_TOKEN_LENGTH: z.coerce.number().default(16),

  ACCESS_LOG_RETENTION_DAYS: z.coerce.number().default(90),
  TRASH_RETENTION_DAYS: z.coerce.number().default(30),
  PURGE_CRON: z.string().default("0 4 * * *"),

  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),
  SMTP_USER: z.string().optional(),
  SMTP_PASSWORD: z.string().optional(),
  MAIL_FROM: z.string().default("BebeLog <noreply@bebelog.example.com>"),

  SHARE_COVER_IMAGE_URL: z.string().default("http://localhost:3000/static/share-cover.png"),
  SHARE_ENABLED: z
    .string()
    .default("true")
    .transform((v) => v === "true"),
});

export type RawEnv = z.infer<typeof rawSchema>;

function resolveAbs(p: string) {
  return path.isAbsolute(p) ? p : path.resolve(/* turbopackIgnore: true */ process.cwd(), p);
}

function parseEnv() {
  // Empty-string env vars (unset ★ placeholders like `KAKAO_JS_KEY=`) should behave as
  // "not provided" so optional fields fall back to their defaults instead of coercing to "" or 0.
  const cleaned = Object.fromEntries(Object.entries(process.env).map(([k, v]) => [k, v === "" ? undefined : v]));
  const parsed = rawSchema.safeParse(cleaned);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  - ${i.path.join(".")}: ${i.message}`).join("\n");
    console.error(`[env] 필수 환경변수 검증 실패, 부팅을 중단합니다:\n${issues}`);
    throw new Error("환경변수 검증 실패: .env 파일을 확인하세요 (.env.example 참고)");
  }
  const raw = parsed.data;

  const kakaoEnabled = Boolean(raw.KAKAO_REST_API_KEY && raw.KAKAO_JS_KEY);
  const mailEnabled = Boolean(raw.SMTP_HOST && raw.SMTP_USER && raw.SMTP_PASSWORD);

  return {
    ...raw,
    MEDIA_ROOT: resolveAbs(raw.MEDIA_ROOT),
    VARIANT_ROOT: resolveAbs(raw.VARIANT_ROOT),
    TEMP_UPLOAD_ROOT: resolveAbs(raw.TEMP_UPLOAD_ROOT),
    TRASH_ROOT: resolveAbs(raw.TRASH_ROOT),
    STORAGE_CHECK_PATH: resolveAbs(raw.STORAGE_CHECK_PATH),
    ALLOWED_MIME_LIST: csv(raw.ALLOWED_MIME),
    THUMB_SIZES_LIST: intCsv(raw.THUMB_SIZES),
    ADMIN_KAKAO_IDS_LIST: csv(raw.ADMIN_KAKAO_IDS),
    ADMIN_EMAILS_LIST: csv(raw.ADMIN_EMAILS).map((e) => e.toLowerCase()),
    KAKAO_ENABLED: kakaoEnabled,
    MAIL_ENABLED: mailEnabled,
  };
}

let cached: ReturnType<typeof parseEnv> | null = null;

export function getEnv() {
  if (!cached) cached = parseEnv();
  return cached;
}
