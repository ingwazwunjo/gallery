import "server-only";
import { bearerSupabase, serverSupabase } from "@/server/supabase/server";
import { isSafeMethod, isSameOriginRequest, requestHost } from "@/lib/auth/origin";
import { ApiError } from "@/server/http/errors";
import { authContextFromClaims, bearerToken, type AuthContext } from "./claims";

export type { AuthContext } from "./claims";

type ClaimsClient = {
  auth: { getClaims: (jwt?: string) => Promise<{ data: unknown; error: unknown }> };
};

/**
 * getClaims() verifies a token's signature and expiry. It reports most failures as { error }, but
 * some malformed tokens (non-JSON segments, unexpected `alg`) make it throw. Either way the caller
 * is simply not signed in: a forged token must look exactly like a missing one, never like a 500.
 */
export async function verifiedClaims(client: ClaimsClient, jwt?: string): Promise<unknown | null> {
  try {
    const { data, error } = await client.auth.getClaims(jwt);
    if (error || !data || typeof data !== "object") return null;
    return (data as { claims?: unknown }).claims ?? null;
  } catch {
    return null;
  }
}

/**
 * Identifies the caller from a verified access token: `Authorization: Bearer` first (mobile/API),
 * otherwise the session cookie (web). It never trusts getSession() data read straight from a cookie.
 *
 * Returns null when nobody is signed in. A header that is present but invalid is treated the same
 * way and never falls back to the cookie.
 */
export async function getAuthContext(request?: Request): Promise<AuthContext | null> {
  const header = request?.headers.get("authorization") ?? null;
  const token = bearerToken(header);
  if (header && !token) return null;

  if (token) {
    return authContextFromClaims(await verifiedClaims(bearerSupabase(token), token), "bearer");
  }
  return authContextFromClaims(await verifiedClaims(await serverSupabase()), "cookie");
}

/**
 * Same as getAuthContext, but throws a 401 ApiError when nobody is signed in.
 *
 * For cookie sessions on a state-changing method (POST, PUT, PATCH, DELETE) it also requires the
 * request to come from our own site, so no future route can forget CSRF protection. Bearer requests
 * are exempt: browsers never attach that header cross-site on their own.
 */
export async function requireAuth(request: Request): Promise<AuthContext> {
  const ctx = await getAuthContext(request);
  if (!ctx) throw new ApiError("AUTH_REQUIRED");
  if (ctx.via === "cookie" && !isSafeMethod(request.method)) {
    const h = request.headers;
    if (!isSameOriginRequest(h.get("origin"), requestHost(h))) throw new ApiError("FORBIDDEN");
  }
  return ctx;
}
