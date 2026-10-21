# ADR 0001 — Clients read through RLS, all writes go through database functions

- Status: accepted
- Date: 2026-10-21

## Context

Supabase exposes every table in `public` to the browser through PostgREST. If clients can write
tables directly, any rule enforced only in a Route Handler (status transitions, prices, moderation)
can be bypassed by calling the API with the user's own token.

## Decision

1. Every table in `public` has RLS enabled.
2. `anon` and `authenticated` have **no** INSERT / UPDATE / DELETE / TRUNCATE privilege on any table.
3. Every write goes Route Handler → `SECURITY DEFINER` function, which checks `auth.uid()`, the
   business rule and writes history/audit rows in the same transaction.
4. Every function in `public` sets `search_path = ''` and starts with execute revoked from `public`;
   it is granted to `authenticated` (or `anon`) only when a client must call it.
5. `profiles` exposes only `id, display_name, avatar_path, created_at` to clients (column grants).
   Client code must select explicit columns, never `select *` on `profiles`.
6. `request_events` and `admin_audit_log` are append-only, enforced by triggers.

`supabase/tests/00_privileges.test.sql` checks rules 1, 2, 4 and 5 so a migration that breaks them fails CI.

## Consequences

- Business rules live in SQL, with pgTAP tests next to them.
- The service/secret key is needed only for work no user can do (image processing, scheduled jobs).
- Slightly more SQL to write per feature, in exchange for a single place where rules are enforced.
