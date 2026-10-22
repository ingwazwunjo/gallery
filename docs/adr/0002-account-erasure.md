# ADR 0002 — Accounts are erased by anonymisation, history and evidence are kept

- Status: accepted (founder decision, 2026-10-22)
- Date: 2026-10-22

## Context

Under Thai PDPA a user may ask for their personal data to be erased. The platform also has to keep
records that other people depend on: a buyer's commission history, an artist's quotes, reports of
stolen art and the admin audit log. Deleting rows outright either fails (foreign keys) or destroys
another party's history and evidence.

## Decision

Erasure anonymises the account instead of deleting it:

- `profiles`: `display_name` becomes a fixed placeholder ("ผู้ใช้ที่ลบบัญชีแล้ว"), `avatar_path` and
  `birth_date` are cleared, `deleted_at` is set. A check constraint guarantees an erased profile holds
  no birth date or avatar.
- Contact handles, verification records, saved artworks, swipes and experiment assignments of the
  user are deleted (they matter to no one else).
- Artworks are soft-deleted (`deleted_at`) and their files removed from storage.
- The login (`auth.users`) has its email and phone scrubbed through the Supabase admin API and is
  banned. Its row stays because `profiles.id` references it **without** a cascade.
- Commission requests, request history, reports and audit entries are kept, pointing at the
  anonymised profile.

Database rules that make this the only path:

- No `on delete cascade` from `auth.users`, `profiles` or `artist_profiles` to anything that carries
  history. Deleting a login, a profile with history, or an artist with artworks fails.
- `request_events` cannot be deleted, so a request with history cannot be deleted either.
- A hard delete of an artwork is reserved for illegal content an admin must purge. Its impressions,
  swipes, saves and style tags go with it; a commission request that referenced it keeps everything
  except `artwork_id`.

## Consequences

- The erasure flow (a definer function plus a server call to the Supabase admin API) is built as its
  own feature before public launch; until then erasure requests are handled manually by the founder
  following this ADR.
- The other party in a commission still sees that the work happened, with an anonymous name.
- Legal review of retention periods for kept records is still needed before launch.
