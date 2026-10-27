import { z } from "zod";

/**
 * Public Supabase settings, safe to ship to the browser.
 * Each variable is referenced literally so Next.js can inline it into client bundles.
 */
const publicEnvSchema = z.object({
  url: z.url(),
  publishableKey: z.string().min(20),
});

export type PublicSupabaseEnv = z.infer<typeof publicEnvSchema>;

export function publicSupabaseEnv(): PublicSupabaseEnv {
  const result = publicEnvSchema.safeParse({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL,
    publishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
  if (!result.success) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (see .env.example)",
    );
  }
  return result.data;
}
