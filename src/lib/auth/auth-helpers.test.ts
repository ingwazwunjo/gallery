import { describe, expect, it } from "vitest";
import { authErrorMessage } from "./messages";
import { isSameOriginRequest } from "./origin";
import { emailSchema, otpSchema } from "./schemas";

describe("isSameOriginRequest", () => {
  const site = "https://artmatch.example";
  it("accepts our own origin", () => expect(isSameOriginRequest(site, site)).toBe(true));
  it.each([
    [null],
    ["null"],
    ["https://evil.example"],
    ["http://artmatch.example"],
    ["https://artmatch.example.evil.example"],
    ["https://artmatch.example:8443"],
  ])("rejects %j", (origin) =>
    expect(isSameOriginRequest(origin as string | null, site)).toBe(false),
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
  it("maps rate limits", () => {
    expect(authErrorMessage({ status: 429 })).toContain("ถี่เกินไป");
    expect(authErrorMessage({ code: "over_email_send_rate_limit" })).toContain("ถี่เกินไป");
  });
  it("maps a wrong or expired code", () =>
    expect(authErrorMessage({ code: "otp_expired" })).toContain("หมดอายุ"));
  it("never echoes the raw server message", () => {
    expect(
      authErrorMessage({ message: "User user@x.com not found in table auth.users" }),
    ).not.toContain("user@x.com");
  });
});
