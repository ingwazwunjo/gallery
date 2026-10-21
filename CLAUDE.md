# ArtMatch — rules for working in this repo

Mobile-first marketplace where Thai buyers swipe through artworks and send commission requests
to Thai artists. Stack: Next.js (App Router) + TypeScript, Supabase (Postgres, Auth, Storage), Zod, Vitest.

@AGENTS.md

## Non-negotiables

- **RLS first.** Clients only read. Every write = Route Handler → `SECURITY DEFINER` function.
  See `docs/adr/0001-database-access.md`.
- Every new function in `public`: `set search_path = ''`, `revoke execute ... from public`,
  then grant only what clients need.
- Never select `*` from `profiles` in client-facing code (column grants will reject it).
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
