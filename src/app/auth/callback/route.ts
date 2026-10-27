import { NextResponse, type NextRequest } from "next/server";
import { serverSupabase } from "@/server/supabase/server";
import { safeNextPath } from "@/lib/auth/redirect";

/**
 * Google sends the user back here with a one-time `code` (PKCE). We exchange it for a session,
 * which sets the auth cookies, then continue to a same-site path only.
 */
export async function GET(request: NextRequest) {
  const url = request.nextUrl;
  const next = safeNextPath(url.searchParams.get("next"));
  const code = url.searchParams.get("code");

  if (code) {
    const supabase = await serverSupabase();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return noStore(NextResponse.redirect(new URL(next, url.origin)));
  }

  const failed = new URL("/login", url.origin);
  failed.searchParams.set("error", "oauth");
  failed.searchParams.set("next", next);
  return noStore(NextResponse.redirect(failed));
}

function noStore(response: NextResponse) {
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
