import { describe, expect, it } from "vitest";
import { DEFAULT_AFTER_LOGIN, safeNextPath } from "./redirect";

describe("safeNextPath", () => {
  it.each([
    ["/account", "/account"],
    ["/artists/123?tab=works#top", "/artists/123?tab=works#top"],
    ["/feed?category=oc", "/feed?category=oc"],
  ])("keeps same-site path %s", (input, expected) => {
    expect(safeNextPath(input)).toBe(expected);
  });

  it.each([
    [null],
    [undefined],
    [""],
    ["account"],
    ["https://evil.example/phish"],
    ["//evil.example"],
    ["/\\evil.example"],
    ["\\\\evil.example"],
    ["/%2F%2Fevil.example"],
    ["/%5Cevil.example"],
    ["/%2Fevil.example"],
    ["/%6Cogin"],
    ["/LOGIN"],
    ["/%E0%A4%A"],
    ["/ok\u0000"],
    ["/ok\nLocation: https://evil.example"],
    ["javascript:alert(1)"],
    ["/login"],
    ["/login?next=/account"],
    ["/auth/callback?code=x"],
    ["/" + "a".repeat(600)],
  ])("falls back for unsafe or looping value %j", (input) => {
    expect(safeNextPath(input as string | null | undefined)).toBe(DEFAULT_AFTER_LOGIN);
  });

  it("keeps an encoded newline as data rather than a header break", () => {
    // %0d%0a stays percent-encoded in the path, so it cannot inject a header.
    expect(safeNextPath("/search?q=%0d%0a")).toBe("/search?q=%0d%0a");
  });

  it("honours a custom fallback", () => {
    expect(safeNextPath("//evil", "/")).toBe("/");
  });
});
