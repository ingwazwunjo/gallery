import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
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
  await supabase.auth.getClaims();

  return response;
}

export const config = {
  // Every route except static files and images.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
