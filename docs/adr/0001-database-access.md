# ADR 0001 — Clients read through RLS and column grants, all writes go through database functions

- Status: accepted (revised 2026-10-22 after the first security review)
- Date: 2026-10-21

## Context

Supabase exposes every table and view in `public` to the browser through PostgREST, and by default
grants `anon` and `authenticated` all privileges on new objects there. Any rule enforced only in a
Route Handler can be bypassed by calling the API directly with the user's own token. Row-level
security alone is not enough either: it filters rows, not columns.

## Decision

1. Every table in `public` has RLS enabled.
2. Clients start with **no** privileges in `public`: the RLS migration revokes everything and changes
   the default privileges so later tables, views, sequences and functions also start with none.
3. A table clients may read gets an explicit `grant select`, **listing columns** when some are private
   (`profiles`, `artworks`, `reports`, `artist_verifications`), plus a policy choosing the rows.
4. Every write goes Route Handler → `SECURITY DEFINER` function in `public`, which checks `auth.uid()`,
   the business rule, and writes history/audit rows in the same transaction.
5. Helpers used inside policies (`is_admin`, `artist_is_publishable`) live in schema `private`, which
   PostgREST does not expose, so they cannot be probed as RPC endpoints.
6. Every function sets `search_path = ''` and revokes execute from `public` explicitly (Postgres grants
   it to PUBLIC by a global default a schema-scoped revoke cannot remove).
7. Every view in `public` must be `security_invoker = true`, otherwise it runs with its owner's rights
   and bypasses RLS and column grants.
8. Public visibility is minimal: anonymous visitors see only verified, unsuspended, not-erased artists,
   their approved work, and reference data. No list of buyers or admins is reachable.
9. `request_events` and `admin_audit_log` are append-only, enforced by row triggers (UPDATE/DELETE)
   and statement triggers (TRUNCATE) that apply to every role.

`supabase/tests/00_privileges.test.sql` checks rules 1, 2, 3, 5, 6 and 7 with `has_*_privilege`, so a
grant made to PUBLIC is caught too, and fails CI if a migration breaks them. Adding a readable table,
an exposed column or a client-callable function means updating its allow-list on purpose.

## Consequences

- Business rules live in SQL with pgTAP tests next to them.
- Owners and admins read private columns (e.g. `rejection_reason`, `original_path`) through
  server-side functions added with the feature that needs them, never through the table.
- Client code must select explicit columns; `select *` on a column-granted table is rejected.
- The service/secret key is needed only for work no user can do (image processing, scheduled jobs).
