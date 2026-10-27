import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

process.env.NEXT_PUBLIC_SUPABASE_URL = "http://127.0.0.1:54321";
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_test_xxxxxxxxxxxxxxxx";

type Cookies = {
  getAll: () => { name: string; value: string }[];
  setAll: (
    toSet: { name: string; value: string; options: object }[],
    headers: Record<string, string>,
  ) => void;
};
let behaviour: (cookies: Cookies) => Promise<unknown>;
vi.mock("@supabase/ssr", () => ({
  createServerClient: (_url: string, _key: string, opts: { cookies: Cookies }) => ({
    auth: { getClaims: () => behaviour(opts.cookies) },
  }),
}));

const { proxy } = await import("./proxy");

const request = (cookie: string) =>
  new NextRequest("http://localhost:3000/account", { headers: { cookie } });

beforeEach(() => {
  behaviour = async () => ({ data: null, error: null });
});

describe("proxy", () => {
  it("passes through when there is no session", async () => {
    const res = await proxy(request(""));
    expect(res.headers.get("x-middleware-next")).toBe("1");
    expect(res.cookies.getAll()).toEqual([]);
  });

  it("writes refreshed session cookies and no-cache headers to the response", async () => {
    behaviour = async (cookies) => {
      cookies.setAll([{ name: "sb-ref-auth-token", value: "fresh", options: { path: "/" } }], {
        "Cache-Control": "private, no-cache, no-store, must-revalidate, max-age=0",
      });
      return { data: { claims: {} }, error: null };
    };
    const res = await proxy(request("sb-ref-auth-token=stale"));
    expect(res.cookies.get("sb-ref-auth-token")?.value).toBe("fresh");
    expect(res.headers.get("cache-control")).toContain("no-store");
    // The page rendered in this request must also see the fresh cookie.
    expect(
      res.headers.get("x-middleware-request-cookie") ??
        res.headers.get("x-middleware-override-headers"),
    ).toBeTruthy();
  });

  it("clears auth cookies instead of crashing when a planted cookie makes getClaims throw", async () => {
    behaviour = async () => {
      throw new SyntaxError("Unexpected token");
    };
    const res = await proxy(
      request("sb-ref-auth-token=YWJj.YWJj.YWJj; sb-ref-auth-token.1=x; theme=dark"),
    );
    expect(res.headers.get("x-middleware-next")).toBe("1");
    const cleared = res.cookies.getAll().map((c) => [c.name, c.value, c.maxAge]);
    expect(cleared).toEqual([
      ["sb-ref-auth-token", "", 0],
      ["sb-ref-auth-token.1", "", 0],
    ]);
    expect(res.headers.get("cache-control")).toContain("no-store");
  });
});
