import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { ApiError, ERRORS, errorResponse, toErrorBody } from "./errors";

describe("toErrorBody", () => {
  it("maps an ApiError to its status and Thai message", () => {
    expect(toErrorBody(new ApiError("AUTH_REQUIRED"))).toEqual({
      status: 401,
      body: { error: { code: "AUTH_REQUIRED", message: ERRORS.AUTH_REQUIRED.message } },
    });
  });

  it("includes details when given", () => {
    expect(
      toErrorBody(new ApiError("CONFLICT", { expected_version: 3 })).body.error.details,
    ).toEqual({
      expected_version: 3,
    });
  });

  it("maps a Zod error to 400 with field names only", () => {
    const result = z.object({ email: z.email() }).safeParse({ email: "secret-value" });
    const { status, body } = toErrorBody(result.error);
    expect(status).toBe(400);
    expect(body.error.details).toEqual({ fields: ["email"] });
    expect(JSON.stringify(body)).not.toContain("secret-value");
  });

  it("never leaks the message of an unexpected error", () => {
    const { status, body } = toErrorBody(new Error("password=hunter2 at db.internal:5432"));
    expect(status).toBe(500);
    expect(body.error.code).toBe("INTERNAL");
    expect(JSON.stringify(body)).not.toContain("hunter2");
  });

  it("gives every code a status and a message", () => {
    for (const [code, def] of Object.entries(ERRORS)) {
      expect(def.status, code).toBeGreaterThanOrEqual(400);
      expect(def.message.length, code).toBeGreaterThan(0);
    }
  });
});

describe("errorResponse", () => {
  it("returns JSON that is never cached", async () => {
    const res = errorResponse(new ApiError("NOT_FOUND"));
    expect(res.status).toBe(404);
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(await res.json()).toEqual({
      error: { code: "NOT_FOUND", message: ERRORS.NOT_FOUND.message },
    });
  });

  it("logs unexpected errors on the server", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    errorResponse(new Error("boom"));
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });
});
