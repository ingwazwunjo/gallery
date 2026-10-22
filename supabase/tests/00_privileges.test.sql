-- Structural guarantees every future migration must keep. These use has_*_privilege, so a grant
-- made to PUBLIC (which anon and authenticated inherit) is caught as well as a direct grant.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

-- Every relation clients could reach in public: tables, partitioned tables, views, matviews, foreign tables.
create temp table t_rel as
  select c.oid, c.relname::text as name, c.relkind
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f');

select is(
  (select array_agg(name order by name) from t_rel
    where relkind in ('r', 'p') and not exists (
      select 1 from pg_class c where c.oid = t_rel.oid and c.relrowsecurity)),
  null,
  'every public table has RLS enabled'
);

select is(
  (select array_agg(name order by name) from t_rel where relkind = 'v'
     and not coalesce((select reloptions from pg_class where oid = t_rel.oid)
                      @> array['security_invoker=true'], false)),
  null,
  'every public view runs with the caller''s rights (security_invoker), so RLS applies'
);

select is(
  (select array_agg(format('%s:%s:%s', r.role, t.name, p.priv) order by 1)
     from t_rel t
     cross join (values ('anon'), ('authenticated')) r(role)
     cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) p(priv)
    where has_table_privilege(r.role, t.oid, p.priv)
       or (p.priv in ('INSERT', 'UPDATE', 'REFERENCES') and has_any_column_privilege(r.role, t.oid, p.priv))),
  null,
  'clients have no write, truncate, references or trigger privilege on anything in public'
);

select is(
  (select array_agg(name order by name) from t_rel where has_any_column_privilege('anon', oid, 'SELECT')),
  array['artist_profiles', 'artwork_styles', 'artworks', 'categories', 'profiles', 'styles'],
  'anon can read exactly the public catalogue relations'
);

select is(
  (select array_agg(name order by name) from t_rel
    where has_any_column_privilege('authenticated', oid, 'SELECT')),
  array['admin_audit_log', 'artist_contacts', 'artist_profiles', 'artist_verifications', 'artwork_styles',
        'artworks', 'categories', 'commission_requests', 'experiment_assignments', 'profiles',
        'reports', 'request_events', 'saved_artworks', 'styles', 'swipe_events'],
  'authenticated can read exactly the expected relations (never admins, impressions, analytics)'
);

-- Column-level exposure of the sensitive tables, for both client roles.
create temp table t_cols as
  select r.role, c.table_name::text as tbl, c.column_name::text as col
  from information_schema.columns c
  cross join (values ('anon'), ('authenticated')) r(role)
  where c.table_schema = 'public'
    and c.table_name in ('profiles', 'artworks', 'reports', 'artist_verifications')
    and has_column_privilege(r.role, format('public.%I', c.table_name), c.column_name, 'SELECT');

select is(
  (select array_agg(format('%s.%s', role, col) order by role, col) from t_cols where tbl = 'profiles'),
  array['anon.avatar_path', 'anon.created_at', 'anon.display_name', 'anon.id',
        'authenticated.avatar_path', 'authenticated.created_at', 'authenticated.display_name', 'authenticated.id'],
  'profiles: clients see only id, display_name, avatar_path, created_at'
);

select is(
  (select array_agg(col order by col) from t_cols where tbl = 'artworks'
     and col in ('original_path', 'reviewed_by', 'reviewed_at', 'rejection_reason', 'impressions_count', 'deleted_at')),
  null,
  'artworks: private columns are not readable by any client role'
);

select is(
  (select array_agg(format('%s.%s', role, col) order by 1) from t_cols
    where (tbl = 'reports' and col = 'resolved_by')
       or (tbl = 'artist_verifications' and col in ('provider_ref', 'reviewed_by'))),
  null,
  'reports.resolved_by and verification provider_ref / reviewed_by stay server-side'
);

select is(
  (select array_agg(n.nspname || '.' || p.proname order by 1)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (has_function_privilege('anon', p.oid, 'execute')
           or has_function_privilege('authenticated', p.oid, 'execute'))),
  null,
  'client-callable functions in public match the reviewed allow-list (empty until the first RPC feature)'
);

select is(
  (select array_agg(p.proname::text order by 1)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef),
  null,
  'SECURITY DEFINER functions in public match the reviewed allow-list (empty for now; helpers live in private)'
);

select is(
  (select array_agg(n.nspname || '.' || p.proname order by 1)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef
      and not coalesce(p.proconfig @> array['search_path=""'], false)),
  null,
  'every SECURITY DEFINER function pins an empty search_path'
);

select is(
  (select array_agg(p.proname::text order by 1)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'execute')),
  array['artist_is_publishable'],
  'anon can execute only the publishability helper (needed by public policies)'
);

select * from finish();
rollback;
