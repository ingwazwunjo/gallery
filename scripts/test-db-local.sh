#!/usr/bin/env bash
# Run migrations + seed + pgTAP tests against a throwaway plain Postgres, without Docker.
# Prefer `npm run db:test` (real Supabase via Docker). Use this only when Docker is unavailable.
# Requires: Postgres binaries (initdb, pg_ctl), the pgtap extension and pg_prove on this machine.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_BIN="${PG_BIN:-$(dirname "$(command -v pg_ctl 2>/dev/null || ls -d /usr/lib/postgresql/*/bin/pg_ctl | tail -1)")}"
WORK="$(mktemp -d)"
PORT="${PGPORT_TEST:-54399}"

cleanup() { "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

"$PG_BIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null

export PGHOST="$WORK" PGPORT="$PORT" PGUSER=postgres PGDATABASE=postgres
PSQL=(psql -v ON_ERROR_STOP=1 -q -X)

"${PSQL[@]}" -f "$ROOT/tests/db/supabase-stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "migrate  $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
echo "seed     seed.sql"
"${PSQL[@]}" -f "$ROOT/supabase/seed.sql"

pg_prove --ext .sql "$ROOT"/supabase/tests/*.test.sql
