import "server-only";
import { createServerClient } from "@supabase/ssr";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { publicSupabaseEnv } from "@/lib/supabase/public-env";

/**
 * Supabase client acting as the signed-in user, from the session cookie.
 * Create a new one per request; never share it between requests.
 */
export async function serverSupabase(): Promise<SupabaseClient> {
  // Read cookies first: it marks the caller as request-time, so prerendering stops here
  // instead of failing on missing configuration at build time.
  const cookieStore = await cookies();
  const { url, publishableKey } = publicSupabaseEnv();
  return createServerClient(url, publishableKey, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (toSet) => {
        try {
          toSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Server Components cannot set cookies. proxy.ts refreshes the session on every request,
          // so ignoring the write here is safe.
        }
      },
    },
  });
}

/**
 * Supabase client acting as the user who sent `Authorization: Bearer <access token>`.
 * Used by API clients without cookies (the future mobile app). The token is still verified
 * by getAuthContext before anything trusts it.
 */
export function bearerSupabase(accessToken: string): SupabaseClient {
  const { url, publishableKey } = publicSupabaseEnv();
  return createClient(url, publishableKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}
