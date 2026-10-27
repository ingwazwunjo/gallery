import "server-only";
import { bearerSupabase, serverSupabase } from "@/server/supabase/server";
import { authContextFromClaims, bearerToken, type AuthContext } from "./claims";
import { ApiError } from "@/server/http/errors";

export type { AuthContext } from "./claims";

/**
 * Identifies the caller from a verified access token: `Authorization: Bearer` first (mobile/API),
 * otherwise the session cookie (web). Uses getClaims(), which verifies the token's signature and
 * expiry; it never trusts getSession() data read straight from a cookie.
 *
 * Returns null when nobody is signed in. A header that is present but invalid is treated the same
 * way, so a caller cannot tell a forged token from a missing one.
 */
export async function getAuthContext(request?: Request): Promise<AuthContext | null> {
  const header = request?.headers.get("authorization") ?? null;
  const token = bearerToken(header);
  if (header && !token) return null;

  if (token) {
    const { data, error } = await bearerSupabase(token).auth.getClaims(token);
    if (error || !data) return null;
    return authContextFromClaims(data.claims, "bearer");
  }

  const supabase = await serverSupabase();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data) return null;
  return authContextFromClaims(data.claims, "cookie");
}

/** Same as getAuthContext, but throws a 401 ApiError when nobody is signed in. */
export async function requireAuth(request?: Request): Promise<AuthContext> {
  const ctx = await getAuthContext(request);
  if (!ctx) throw new ApiError("AUTH_REQUIRED");
  return ctx;
}
