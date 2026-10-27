import { describe, expect, it } from "vitest";
import { authErrorMessage } from "./messages";
import { isSafeMethod, isSameOriginRequest, requestHost } from "./origin";
import { emailSchema, otpSchema } from "./schemas";
import { isAuthCookieName } from "../supabase/cookie-options";

describe("isSameOriginRequest", () => {
  it.each([
    ["https://artmatch.app", "artmatch.app"],
    ["http://127.0.0.1:3000", "127.0.0.1:3000"],
    ["http://localhost:3000", "localhost:3000"],
    ["https://ArtMatch.app", "artmatch.app"],
    ["https://artmatch.app", "artmatch.app, internal-proxy:8080"],
  ])("accepts Origin %s for host %s", (origin, host) => {
    expect(isSameOriginRequest(origin, host)).toBe(true);
  });

  it.each([
    [null, "artmatch.app"],
    ["https://artmatch.app", null],
    ["null", "artmatch.app"],
    ["https://evil.example", "artmatch.app"],
    ["https://artmatch.app.evil.example", "artmatch.app"],
    ["https://artmatch.app:8443", "artmatch.app"],
    ["http://localhost:3000", "127.0.0.1:3000"],
    ["file:///etc/passwd", "artmatch.app"],
    ["javascript:alert(1)", "artmatch.app"],
  ])("rejects Origin %j for host %j", (origin, host) => {
    expect(isSameOriginRequest(origin as string | null, host as string | null)).toBe(false);
  });
});

describe("requestHost", () => {
  it("prefers x-forwarded-host (behind a proxy)", () => {
    expect(
      requestHost(new Headers({ host: "internal:3000", "x-forwarded-host": "artmatch.app" })),
    ).toBe("artmatch.app");
  });
  it("falls back to host", () =>
    expect(requestHost(new Headers({ host: "artmatch.app" }))).toBe("artmatch.app"));
});

describe("isSafeMethod", () => {
  it.each(["GET", "HEAD", "OPTIONS", "get"])("%s is safe", (m) =>
    expect(isSafeMethod(m)).toBe(true),
  );
  it.each(["POST", "PUT", "PATCH", "DELETE"])("%s is not", (m) =>
    expect(isSafeMethod(m)).toBe(false),
  );
});

describe("isAuthCookieName", () => {
  it.each(["sb-owjdwfisygqsbcvcmvoz-auth-token", "sb-127-auth-token.0", "sb-abc-auth-token.12"])(
    "matches %s",
    (n) => expect(isAuthCookieName(n)).toBe(true),
  );
  it.each(["sb-abc-auth-token-code-verifier", "session", "sb--auth-token", "x-sb-abc-auth-token"])(
    "ignores %s",
    (n) => expect(isAuthCookieName(n)).toBe(false),
  );
});

describe("emailSchema", () => {
  it("trims and lowercases", () =>
    expect(emailSchema.parse("  Ann@Example.COM ")).toBe("ann@example.com"));
  it.each(["", "ann", "ann@", "@example.com", "a b@example.com"])("rejects %j", (v) =>
    expect(emailSchema.safeParse(v).success).toBe(false),
  );
});

describe("otpSchema", () => {
  it("accepts 6 digits", () => expect(otpSchema.parse(" 012345 ")).toBe("012345"));
  it.each(["12345", "1234567", "12a456", "", "١٢٣٤٥٦"])("rejects %j", (v) =>
    expect(otpSchema.safeParse(v).success).toBe(false),
  );
});

describe("authErrorMessage", () => {
  const generic = authErrorMessage({});
  it("maps rate limits", () => {
    expect(authErrorMessage({ status: 429 })).toContain("ถี่เกินไป");
    expect(authErrorMessage({ code: "over_email_send_rate_limit" })).toContain("ถี่เกินไป");
  });
  it("maps a wrong or expired code", () =>
    expect(authErrorMessage({ code: "otp_expired" })).toContain("หมดอายุ"));
  it.each(["user_banned", "signup_disabled", "user_not_found", "email_address_not_authorized"])(
    "does not reveal account state for %s",
    (code) => expect(authErrorMessage({ code })).toBe(generic),
  );
  it("never echoes the raw server message", () => {
    expect(
      authErrorMessage({ message: "User user@x.com not found in table auth.users" }),
    ).not.toContain("user@x.com");
  });
});
