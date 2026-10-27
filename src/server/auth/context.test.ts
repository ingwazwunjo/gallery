import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const user = "11111111-1111-4111-8111-111111111111";
const goodClaims = { sub: user, role: "authenticated", email: "ann@example.com" };
const jwt = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl";

// Behaviour of getClaims for the cookie client and the bearer client, set per test.
const cookieGetClaims = vi.fn();
const bearerGetClaims = vi.fn();
vi.mock("@/server/supabase/server", () => ({
  serverSupabase: async () => ({ auth: { getClaims: cookieGetClaims } }),
  bearerSupabase: () => ({ auth: { getClaims: bearerGetClaims } }),
}));

const { getAuthContext, requireAuth, verifiedClaims } = await import("./context");

const ok = (claims: unknown) => ({ data: { claims }, error: null });

beforeEach(() => {
  cookieGetClaims.mockReset();
  bearerGetClaims.mockReset();
});

describe("verifiedClaims", () => {
  it("returns claims on success", async () => {
    expect(await verifiedClaims({ auth: { getClaims: async () => ok(goodClaims) } })).toEqual(
      goodClaims,
    );
  });
  it("returns null on a reported error", async () => {
    expect(
      await verifiedClaims({
        auth: { getClaims: async () => ({ data: null, error: new Error("expired") }) },
      }),
    ).toBeNull();
  });
  it.each([
    ["SyntaxError (non-JSON token segment)", new SyntaxError("Unexpected token")],
    ["Invalid alg claim", new Error("Invalid alg claim")],
    ["DOMException (key/alg mismatch)", new DOMException("bad key", "InvalidAccessError")],
  ])("returns null when getClaims throws: %s", async (_, err) => {
    expect(
      await verifiedClaims({
        auth: {
          getClaims: async () => {
            throw err;
          },
        },
      }),
    ).toBeNull();
  });
});

describe("getAuthContext", () => {
  it("uses the cookie session when there is no Authorization header", async () => {
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    expect(await getAuthContext(new Request("http://x/"))).toEqual({
      userId: user,
      email: "ann@example.com",
      via: "cookie",
    });
  });

  it("uses a valid Bearer token", async () => {
    bearerGetClaims.mockResolvedValue(ok(goodClaims));
    const ctx = await getAuthContext(
      new Request("http://x/", { headers: { authorization: `Bearer ${jwt}` } }),
    );
    expect(ctx?.via).toBe("bearer");
    expect(bearerGetClaims).toHaveBeenCalledWith(jwt);
  });

  it("treats a forged Bearer token that makes getClaims throw as signed out, not a crash", async () => {
    bearerGetClaims.mockRejectedValue(new SyntaxError("Unexpected token"));
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    const ctx = await getAuthContext(
      new Request("http://x/", { headers: { authorization: `Bearer ${jwt}` } }),
    );
    expect(ctx).toBeNull();
    expect(cookieGetClaims).not.toHaveBeenCalled(); // never falls back to the cookie
  });

  it("treats a malformed Authorization header as signed out without falling back to the cookie", async () => {
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    expect(
      await getAuthContext(new Request("http://x/", { headers: { authorization: "Basic abc" } })),
    ).toBeNull();
    expect(cookieGetClaims).not.toHaveBeenCalled();
  });

  it("treats a cookie that makes getClaims throw as signed out", async () => {
    cookieGetClaims.mockRejectedValue(new Error("Invalid alg claim"));
    expect(await getAuthContext(new Request("http://x/"))).toBeNull();
  });
});

describe("requireAuth", () => {
  const post = (headers: Record<string, string>) =>
    new Request("http://localhost:3000/api/v1/x", { method: "POST", headers });

  it("throws AUTH_REQUIRED when signed out", async () => {
    cookieGetClaims.mockResolvedValue({ data: null, error: new Error("no session") });
    await expect(requireAuth(new Request("http://x/"))).rejects.toMatchObject({
      code: "AUTH_REQUIRED",
      status: 401,
    });
  });

  it("allows a cookie GET without Origin", async () => {
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    await expect(
      requireAuth(new Request("http://x/", { headers: { host: "artmatch.app" } })),
    ).resolves.toMatchObject({ userId: user });
  });

  it("allows a cookie POST from our own site, on any host", async () => {
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    await expect(
      requireAuth(post({ host: "artmatch.app", origin: "https://artmatch.app" })),
    ).resolves.toBeTruthy();
    await expect(
      requireAuth(post({ host: "127.0.0.1:3000", origin: "http://127.0.0.1:3000" })),
    ).resolves.toBeTruthy();
  });

  it.each([
    ["no Origin", { host: "artmatch.app" }],
    ["a foreign Origin", { host: "artmatch.app", origin: "https://evil.example" }],
  ])("rejects a cookie POST with %s (CSRF)", async (_, headers) => {
    cookieGetClaims.mockResolvedValue(ok(goodClaims));
    await expect(requireAuth(post(headers))).rejects.toMatchObject({
      code: "FORBIDDEN",
      status: 403,
    });
  });

  it("does not require Origin for a Bearer POST (no ambient credentials)", async () => {
    bearerGetClaims.mockResolvedValue(ok(goodClaims));
    await expect(requireAuth(post({ authorization: `Bearer ${jwt}` }))).resolves.toMatchObject({
      via: "bearer",
    });
  });
});
