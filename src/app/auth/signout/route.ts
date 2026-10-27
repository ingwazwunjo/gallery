import { NextResponse, type NextRequest } from "next/server";
import { serverSupabase } from "@/server/supabase/server";
import { isSameOriginRequest, requestHost } from "@/lib/auth/origin";

/** Sign out. POST only, and only from our own pages, so another site cannot log users out. */
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get("origin"), requestHost(request.headers))) {
    return new NextResponse(null, { status: 403 });
  }
  const supabase = await serverSupabase();
  try {
    await supabase.auth.signOut({ scope: "local" });
  } catch {
    // Even if the auth server is unreachable, signOut clears the local session cookies first.
  }
  // Relative Location: the browser resolves it against the host it actually used.
  return new NextResponse(null, {
    status: 303,
    headers: { Location: "/login", "Cache-Control": "private, no-store" },
  });
}
