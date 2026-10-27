import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

vi.mock("server-only", () => ({}));

const exchangeCodeForSession = vi.fn();
const signOut = vi.fn();
vi.mock("@/server/supabase/server", () => ({
  serverSupabase: async () => ({ auth: { exchangeCodeForSession, signOut } }),
}));

const { GET: callback } = await import("./callback/route");
const { POST: signout } = await import("./signout/route");

beforeEach(() => {
  exchangeCodeForSession.mockReset();
  signOut.mockReset().mockResolvedValue({ error: null });
});

// Under `next start` the request URL is always localhost; the real host is only in the headers.
const req = (path: string, init: { method?: string; headers?: Record<string, string> } = {}) =>
  new NextRequest(new URL(path, "http://localhost:3000"), init);

describe("GET /auth/callback", () => {
  it("exchanges the code and continues to a same-site path, with a relative Location", async () => {
    exchangeCodeForSession.mockResolvedValue({ error: null });
    const res = await callback(
      req("/auth/callback?code=abc&next=%2Fartists%2F1", { headers: { host: "artmatch.app" } }),
    );
    expect(exchangeCodeForSession).toHaveBeenCalledWith("abc");
    expect(res.status).toBe(303);
    expect(res.headers.get("location")).toBe("/artists/1");
    expect(res.headers.get("cache-control")).toContain("no-store");
  });

  it.each(["//evil.example", "https://evil.example", "%2F%2Fevil.example", "/%2F%2Fevil.example"])(
    "never redirects off-site for next=%s",
    async (next) => {
      exchangeCodeForSession.mockResolvedValue({ error: null });
      const res = await callback(req(`/auth/callback?code=abc&next=${encodeURIComponent(next)}`));
      expect(res.headers.get("location")).toBe("/account");
    },
  );

  it("sends the user back to /login when there is no code", async () => {
    const res = await callback(req("/auth/callback?next=%2Faccount"));
    expect(exchangeCodeForSession).not.toHaveBeenCalled();
    expect(res.headers.get("location")).toBe("/login?error=oauth&next=%2Faccount");
  });

  it.each([
    [
      "an error result",
      () => exchangeCodeForSession.mockResolvedValue({ error: new Error("bad code") }),
    ],
    ["a thrown error", () => exchangeCodeForSession.mockRejectedValue(new Error("network"))],
  ])("sends the user back to /login on %s", async (_, arrange) => {
    arrange();
    const res = await callback(req("/auth/callback?code=abc"));
    expect(res.status).toBe(303);
    expect(res.headers.get("location")).toBe("/login?error=oauth&next=%2Faccount");
  });
});

describe("POST /auth/signout", () => {
  it.each([
    ["localhost", "localhost:3000", "http://localhost:3000"],
    ["127.0.0.1 (local dev)", "127.0.0.1:3000", "http://127.0.0.1:3000"],
    ["a real domain", "artmatch.app", "https://artmatch.app"],
  ])("signs out from our own site on %s", async (_, host, origin) => {
    const res = await signout(req("/auth/signout", { method: "POST", headers: { host, origin } }));
    expect(signOut).toHaveBeenCalledWith({ scope: "local" });
    expect(res.status).toBe(303);
    expect(res.headers.get("location")).toBe("/login");
    expect(res.headers.get("cache-control")).toContain("no-store");
  });

  it("signs out behind a reverse proxy (x-forwarded-host)", async () => {
    const res = await signout(
      req("/auth/signout", {
        method: "POST",
        headers: {
          host: "internal:3000",
          "x-forwarded-host": "artmatch.app",
          origin: "https://artmatch.app",
        },
      }),
    );
    expect(res.status).toBe(303);
  });

  it.each([
    ["no Origin", { host: "artmatch.app" }],
    ["a foreign Origin", { host: "artmatch.app", origin: "https://evil.example" }],
    ["Origin null", { host: "artmatch.app", origin: "null" }],
  ])("refuses %s", async (_, headers) => {
    const res = await signout(req("/auth/signout", { method: "POST", headers }));
    expect(res.status).toBe(403);
    expect(signOut).not.toHaveBeenCalled();
  });

  it("still redirects when the auth server is unreachable", async () => {
    signOut.mockRejectedValue(new Error("network"));
    const res = await signout(
      req("/auth/signout", {
        method: "POST",
        headers: { host: "artmatch.app", origin: "https://artmatch.app" },
      }),
    );
    expect(res.status).toBe(303);
  });
});
