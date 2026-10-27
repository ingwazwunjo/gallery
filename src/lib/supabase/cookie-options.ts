import type { CookieOptionsWithName } from "@supabase/ssr";

/**
 * Auth cookie settings shared by the browser client, the server client and proxy.ts.
 * `secure` keeps the session off plain HTTP in production (browsers still accept Secure
 * cookies on http://localhost, so `next start` keeps working locally).
 */
export const authCookieOptions: CookieOptionsWithName = {
  sameSite: "lax",
  path: "/",
  secure: process.env.NODE_ENV === "production",
};

/** Supabase auth cookies are named sb-<project-ref>-auth-token (optionally chunked: .0, .1, …). */
export function isAuthCookieName(name: string): boolean {
  return /^sb-[a-z0-9]+-auth-token(\.\d+)?$/i.test(name);
}
