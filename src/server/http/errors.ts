import { z } from "zod";

/**
 * Every API error has a stable code (for clients and logs) and a Thai message (for people).
 * Responses use one envelope: { "error": { "code", "message", "details"? } }.
 */
export const ERRORS = {
  VALIDATION_FAILED: { status: 400, message: "ข้อมูลที่ส่งมาไม่ถูกต้อง" },
  AUTH_REQUIRED: { status: 401, message: "กรุณาเข้าสู่ระบบก่อน" },
  ACCOUNT_SUSPENDED: { status: 403, message: "บัญชีนี้ถูกระงับการใช้งาน" },
  FORBIDDEN: { status: 403, message: "คุณไม่มีสิทธิ์ทำรายการนี้" },
  NOT_FOUND: { status: 404, message: "ไม่พบข้อมูลที่ต้องการ" },
  CONFLICT: { status: 409, message: "ข้อมูลถูกเปลี่ยนไปแล้ว กรุณาโหลดใหม่แล้วลองอีกครั้ง" },
  RATE_LIMITED: { status: 429, message: "ทำรายการถี่เกินไป กรุณารอสักครู่แล้วลองใหม่" },
  INTERNAL: { status: 500, message: "ระบบขัดข้อง กรุณาลองใหม่อีกครั้ง" },
} as const;

export type ErrorCode = keyof typeof ERRORS;

export class ApiError extends Error {
  readonly status: number;
  constructor(
    readonly code: ErrorCode,
    readonly details?: Record<string, unknown>,
  ) {
    super(code);
    this.status = ERRORS[code].status;
  }
}

export type ErrorBody = {
  error: { code: ErrorCode; message: string; details?: Record<string, unknown> };
};

/** Maps any thrown value to a status and envelope. Unknown errors never leak their message. */
export function toErrorBody(err: unknown): { status: number; body: ErrorBody } {
  if (err instanceof ApiError) {
    return {
      status: err.status,
      body: {
        error: {
          code: err.code,
          message: ERRORS[err.code].message,
          ...(err.details ? { details: err.details } : {}),
        },
      },
    };
  }
  if (err instanceof z.ZodError) {
    const fields = err.issues.map((i) => i.path.join(".") || "(root)");
    return {
      status: 400,
      body: {
        error: {
          code: "VALIDATION_FAILED",
          message: ERRORS.VALIDATION_FAILED.message,
          details: { fields },
        },
      },
    };
  }
  return { status: 500, body: { error: { code: "INTERNAL", message: ERRORS.INTERNAL.message } } };
}

export function errorResponse(err: unknown): Response {
  const { status, body } = toErrorBody(err);
  if (status >= 500) console.error(err);
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

export function okResponse<T>(data: T, init?: ResponseInit): Response {
  return Response.json(
    { data },
    { ...init, headers: { "Cache-Control": "no-store", ...init?.headers } },
  );
}
