import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { authCookieOptions, isAuthCookieName } from "@/lib/supabase/cookie-options";
import { publicSupabaseEnv } from "@/lib/supabase/public-env";

/**
 * Keeps the Supabase session fresh on every page request: if the access token is about to expire,
 * getClaims() refreshes it and the new cookies are written to both the request (for the page being
 * rendered) and the response (for the browser).
 *
 * This is NOT authorization. Pages and Route Handlers still verify the user themselves
 * (getAuthContext) and the database enforces RLS.
 */
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  const { url, publishableKey } = publicSupabaseEnv();

  const supabase = createServerClient(url, publishableKey, {
    cookieOptions: authCookieOptions,
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (toSet, headers) => {
        toSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        toSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        // Responses that carry auth cookies must never be cached by a CDN.
        Object.entries(headers).forEach(([key, value]) => response.headers.set(key, value));
      },
    },
  });

  // Do not put code between client creation and this call: it is what triggers the refresh.
  try {
    await supabase.auth.getClaims();
  } catch {
    // A malformed session cookie (e.g. planted by a sibling subdomain) can make getClaims throw.
    // Drop it so the user is simply signed out instead of every page failing with a 500.
    return withoutAuthCookies(request);
  }

  return response;
}

function withoutAuthCookies(request: NextRequest) {
  const stale = request.cookies.getAll().filter((c) => isAuthCookieName(c.name));
  stale.forEach((c) => request.cookies.delete(c.name));
  const response = NextResponse.next({ request });
  stale.forEach((c) => response.cookies.set(c.name, "", { ...authCookieOptions, maxAge: 0 }));
  response.headers.set("Cache-Control", "private, no-cache, no-store, must-revalidate, max-age=0");
  return response;
}

export const config = {
  // Every route except static files and images.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
