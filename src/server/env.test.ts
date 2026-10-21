import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const { parseServerEnv } = await import("./env");

const valid = {
  NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_xxxxxxxxxxxxxxxxxxxx",
  SUPABASE_SECRET_KEY: "sb_secret_xxxxxxxxxxxxxxxxxxxxxxxxxx",
};

describe("parseServerEnv", () => {
  it("accepts a complete environment", () => {
    expect(parseServerEnv(valid)).toEqual(valid);
  });

  it("names missing variables without leaking values", () => {
    const rest = { ...valid, SUPABASE_SECRET_KEY: undefined };
    expect(() => parseServerEnv(rest)).toThrow(/SUPABASE_SECRET_KEY/);
    expect(() => parseServerEnv(rest)).not.toThrow(/sb_publishable/);
  });

  it("rejects a malformed URL", () => {
    expect(() => parseServerEnv({ ...valid, NEXT_PUBLIC_SUPABASE_URL: "not a url" })).toThrow(
      /NEXT_PUBLIC_SUPABASE_URL/,
    );
  });
});
