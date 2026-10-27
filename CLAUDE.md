# ArtMatch — rules for working in this repo

Mobile-first marketplace where Thai buyers swipe through artworks and send commission requests
to Thai artists. Stack: Next.js (App Router) + TypeScript, Supabase (Postgres, Auth, Storage), Zod, Vitest.

@AGENTS.md

## Non-negotiables

- **RLS first.** Clients only read. Every write = Route Handler → `SECURITY DEFINER` function.
  See `docs/adr/0001-database-access.md`.
- Clients start with no privileges. A new table clients may read needs an explicit `grant select`
  (list columns if any are private) plus a policy, and an update to the allow-lists in
  `supabase/tests/00_privileges.test.sql`.
- Every new function: `set search_path = ''`, `revoke execute ... from public`, then grant only what
  clients need. Helpers used inside policies go in schema `private`, never `public`.
- Every view in `public` must be `with (security_invoker = true)`.
- Never `select *` in client-facing code; `profiles`, `artworks`, `reports` and
  `artist_verifications` have column grants that reject it.
- Never hard-delete rows that history depends on; accounts are erased by anonymisation
  (`docs/adr/0002-account-erasure.md`).
- **Identity on the server comes only from `getAuthContext()` / `requireAuth()`**
  (`src/server/auth/context.ts`), which verifies the token with `getClaims()`. Never trust
  `getSession()` or a user id sent in a request body. `src/proxy.ts` only refreshes the session.
- Any redirect target taken from the URL goes through `safeNextPath()`. State-changing routes
  that rely on cookies are POST-only and check `isSameOriginRequest()`.
- API errors use `ApiError` / `errorResponse()` (`src/server/http/errors.ts`): stable code + Thai
  message, never a raw error message.
- Ship each feature with its migration, Zod schema, authorization and tests in the same change.
- Never edit an applied migration; add a new one.
- Never claim tests pass without running them.
- Do not add features outside the MVP scope without the founder's approval.

## Product decisions in force

- 18+ only (birth date checked at onboarding). No NSFW content in the MVP.
- Artist contact handles (LINE / X / Discord) are revealed only after the artist quotes. No chat.
- Artists must be verified by SMS OTP before their work is public. Never store ID numbers or ID images.
- `confirmed` = buyer accepts the quoted price (counts as a commission). `completed` = buyer confirms delivery.
- Login: email OTP + Google. LINE Login after beta.
- Money is integer THB in columns ending `_thb`.

## Commands

| Task                          | Command                                                               |
| ----------------------------- | --------------------------------------------------------------------- |
| Dev server                    | `npm run dev`                                                         |
| Lint / types / format         | `npm run lint` · `npm run typecheck` · `npm run format:check`         |
| Unit tests                    | `npm test`                                                            |
| Local Supabase (Docker)       | `npx supabase start` · `npm run db:reset`                             |
| Database tests (Docker)       | `npm run db:test`                                                     |
| Database tests without Docker | `npm run db:test:local` (plain Postgres + pgTAP; CI is authoritative) |

## Auth notes (B6)

- Access tokens are verified locally (`getClaims`), so a sign-out, ban or erasure takes effect for an
  already-issued token only when it expires (`jwt_expiry`, 1 hour). Anything that must stop at once
  (suspension, erasure) is also enforced inside the database functions, not only at login.
- Before beta: CAPTCHA on the login form (`[auth.captcha]` + `captchaToken`) and a custom SMTP
  provider. Without them anyone can drain the email quota, and Supabase's built-in email only reaches
  the project team's own addresses.
