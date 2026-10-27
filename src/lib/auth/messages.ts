/** Matches `max_frequency` for auth emails in supabase/config.toml. */
export const RESEND_COOLDOWN_SECONDS = 60;

type AuthErrorLike = { status?: number; code?: string; message?: string };

const GENERIC = "เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง";

/**
 * Thai message for a Supabase Auth error. Never echoes the raw message, and never reveals anything
 * about a specific address (whether it has an account, or is banned): those cases get the generic text.
 */
export function authErrorMessage(error: AuthErrorLike): string {
  const code = error.code ?? "";
  if (error.status === 429 || code.startsWith("over_") || code === "too_many_requests") {
    return "ขอรหัสหรือลองเข้าสู่ระบบถี่เกินไป กรุณารอสักครู่แล้วลองใหม่";
  }
  if (code === "otp_expired" || code === "invalid_credentials" || code === "bad_code_verifier") {
    return "รหัสไม่ถูกต้องหรือหมดอายุแล้ว กรุณาขอรหัสใหม่";
  }
  if (code === "email_address_invalid" || code === "validation_failed") {
    return "กรุณากรอกอีเมลให้ถูกต้อง";
  }
  if (code === "provider_disabled") {
    return "วิธีเข้าสู่ระบบนี้ยังไม่เปิดใช้งาน";
  }
  return GENERIC;
}
