import { describe, expect, it } from "vitest";
import { authContextFromClaims, bearerToken } from "./claims";

const user = "11111111-1111-4111-8111-111111111111";

describe("authContextFromClaims", () => {
  it("accepts a signed-in user", () => {
    expect(
      authContextFromClaims({ sub: user, role: "authenticated", email: "a@b.co" }, "cookie"),
    ).toEqual({
      userId: user,
      email: "a@b.co",
      via: "cookie",
    });
  });

  it("allows a user without an email (e.g. phone-only)", () => {
    expect(authContextFromClaims({ sub: user, role: "authenticated" }, "bearer")?.email).toBeNull();
  });

  it.each([
    ["anon key claims", { role: "anon" }],
    ["service role claims", { sub: user, role: "service_role" }],
    ["anonymous sign-in", { sub: user, role: "authenticated", is_anonymous: true }],
    ["sub that is not a uuid", { sub: "admin", role: "authenticated" }],
    ["no claims", null],
    ["a string", "authenticated"],
  ])("rejects %s", (_, claims) => {
    expect(authContextFromClaims(claims, "cookie")).toBeNull();
  });
});

describe("bearerToken", () => {
  const jwt = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl";

  it("extracts a JWT", () => {
    expect(bearerToken(`Bearer ${jwt}`)).toBe(jwt);
  });

  it.each([
    [null],
    [""],
    ["Basic dXNlcjpwYXNz"],
    [`bearer ${jwt}`],
    ["Bearer not-a-jwt"],
    [`Bearer ${jwt} extra`],
    [`Bearer ${jwt}.extra`],
  ])("rejects %j", (header) => {
    expect(bearerToken(header as string | null)).toBeNull();
  });
});
