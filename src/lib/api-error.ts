import { NextResponse } from "next/server";

export class ApiError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function handleApiError(err: unknown) {
  if (err instanceof ApiError) {
    return NextResponse.json({ code: err.code, message: err.message }, { status: err.status });
  }
  if (err instanceof Error && err.name === "UNAUTHORIZED") {
    return NextResponse.json({ code: "UNAUTHORIZED", message: "로그인이 필요합니다" }, { status: 401 });
  }
  if (err instanceof Error && err.name === "FORBIDDEN") {
    return NextResponse.json({ code: "FORBIDDEN", message: "권한이 없습니다" }, { status: 403 });
  }
  console.error(err);
  return NextResponse.json({ code: "INTERNAL_ERROR", message: "서버 오류가 발생했습니다" }, { status: 500 });
}
