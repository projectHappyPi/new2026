import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { requireUser } from "@/lib/auth";
import { requireMembership } from "@/lib/album-access";
import { assertUploadAllowed } from "@/lib/upload-gate";
import { getEnv } from "@/lib/env";
import { handleApiError, ApiError } from "@/lib/api-error";

const bodySchema = z.object({
  files: z
    .array(z.object({ bytes: z.number().positive(), mime: z.string() }))
    .min(1)
    .max(1000),
});

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const user = await requireUser();
    await requireMembership(id, user.id);
    const env = getEnv();

    const body = bodySchema.parse(await req.json());
    if (body.files.length > env.UPLOAD_MAX_BATCH_COUNT) {
      throw new ApiError(400, "TOO_MANY_FILES", `한 번에 최대 ${env.UPLOAD_MAX_BATCH_COUNT}개까지 업로드할 수 있습니다`);
    }
    for (const f of body.files) {
      if (f.bytes > env.UPLOAD_MAX_FILE_BYTES) {
        throw new ApiError(400, "FILE_TOO_LARGE", "파일 크기가 최대 허용치를 초과했습니다");
      }
      if (!env.ALLOWED_MIME_LIST.includes(f.mime)) {
        throw new ApiError(400, "UNSUPPORTED_MIME", `지원하지 않는 파일 형식입니다: ${f.mime}`);
      }
    }

    const totalBytes = body.files.reduce((sum, f) => sum + f.bytes, 0);
    await assertUploadAllowed(totalBytes);

    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
