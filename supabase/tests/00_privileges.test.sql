-- Structural guarantees every future migration must keep. has_*_privilege is used throughout, so a
-- grant made to PUBLIC (which anon and authenticated inherit) is caught as well as a direct grant.
-- Changing an allow-list below is how a migration deliberately exposes something new.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

-- Every relation clients could reach in public: tables, partitioned tables, views, matviews, foreign tables.
create temp table t_rel as
  select c.oid, c.relname::text as name, c.relkind, c.relrowsecurity, c.reloptions
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f');

-- Write-type privileges that exist on this server (MAINTAIN only from Postgres 17).
create temp table t_privs as
  select p from (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) v(p)
  union all
  select 'MAINTAIN' where current_setting('server_version_num')::int >= 170000;

select is(
  (select array_agg(name order by name) from t_rel where relkind in ('r', 'p') and not relrowsecurity),
  null,
  'every public table has RLS enabled'
);

select is(
  (select array_agg(name order by name) from t_rel
    where relkind = 'v'
      and not exists (select 1 from unnest(coalesce(reloptions, '{}')) o
                      where split_part(o, '=', 1) = 'security_invoker'
                        and lower(split_part(o, '=', 2)) in ('true', 'on', '1', 'yes'))),
  null,
  'every public view runs with the caller''s rights (security_invoker), so RLS applies'
);

select is(
  (select array_agg(format('%s:%s:%s', r.role, t.name, p.p) order by format('%s:%s:%s', r.role, t.name, p.p))
     from t_rel t
     cross join (values ('anon'), ('authenticated')) r(role)
     cross join t_privs p
    where has_table_privilege(r.role, t.oid, p.p)
       or (p.p in ('INSERT', 'UPDATE', 'REFERENCES') and has_any_column_privilege(r.role, t.oid, p.p))),
  null,
  'clients have no write, truncate, references, trigger or maintain privilege on anything in public'
);

select is(
  (select array_agg(c.relname::text order by c.relname::text)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'S'
      and (has_sequence_privilege('anon', c.oid, 'usage') or has_sequence_privilege('authenticated', c.oid, 'usage'))),
  null,
  'clients cannot use any sequence in public'
);

-- Full snapshot of every column each client role can read. A new column on a client-readable table
-- fails this test until someone decides it is safe to expose.
create temp table t_cols as
  select r.role, c.table_name::text || '.' || c.column_name::text as col
  from information_schema.columns c
  cross join (values ('anon'), ('authenticated')) r(role)
  where c.table_schema = 'public'
    and has_column_privilege(r.role, format('public.%I', c.table_name), c.column_name, 'SELECT');

select is(
  (select array_agg(col order by col) from t_cols where role = 'anon'),
  array[
    'artist_profiles.bio', 'artist_profiles.created_at', 'artist_profiles.min_price_thb',
    'artist_profiles.queue_status', 'artist_profiles.updated_at', 'artist_profiles.user_id',
    'artwork_styles.artwork_id', 'artwork_styles.style_slug',
    'artworks.artist_id', 'artworks.category_slug', 'artworks.created_at', 'artworks.display_path',
    'artworks.height', 'artworks.id', 'artworks.is_fan_art', 'artworks.price_from_thb',
    'artworks.published_at', 'artworks.status', 'artworks.title', 'artworks.updated_at', 'artworks.width',
    'categories.is_active', 'categories.name_th', 'categories.slug', 'categories.sort',
    'profiles.avatar_path', 'profiles.created_at', 'profiles.display_name', 'profiles.id',
    'styles.is_active', 'styles.name_th', 'styles.slug', 'styles.sort'
  ],
  'anon: readable columns match the reviewed snapshot'
);

select is(
  (select array_agg(col order by col) from t_cols where role = 'authenticated'),
  array[
    'admin_audit_log.action', 'admin_audit_log.admin_id', 'admin_audit_log.after', 'admin_audit_log.before',
    'admin_audit_log.created_at', 'admin_audit_log.id', 'admin_audit_log.reason',
    'admin_audit_log.target_id', 'admin_audit_log.target_type',
    'artist_contacts.discord', 'artist_contacts.line_id', 'artist_contacts.updated_at',
    'artist_contacts.user_id', 'artist_contacts.x_handle',
    'artist_profiles.bio', 'artist_profiles.created_at', 'artist_profiles.min_price_thb',
    'artist_profiles.queue_status', 'artist_profiles.updated_at', 'artist_profiles.user_id',
    'artist_verifications.created_at', 'artist_verifications.method', 'artist_verifications.status',
    'artist_verifications.updated_at', 'artist_verifications.user_id', 'artist_verifications.verified_at',
    'artwork_styles.artwork_id', 'artwork_styles.style_slug',
    'artworks.artist_id', 'artworks.category_slug', 'artworks.created_at', 'artworks.deleted_at',
    'artworks.display_path', 'artworks.height', 'artworks.id', 'artworks.is_fan_art',
    'artworks.price_from_thb', 'artworks.published_at', 'artworks.status', 'artworks.title',
    'artworks.updated_at', 'artworks.width',
    'categories.is_active', 'categories.name_th', 'categories.slug', 'categories.sort',
    'commission_requests.agreed_price_thb', 'commission_requests.artist_id', 'commission_requests.artwork_id',
    'commission_requests.buyer_budget_thb', 'commission_requests.buyer_id', 'commission_requests.category_slug',
    'commission_requests.commercial_use', 'commission_requests.created_at', 'commission_requests.description',
    'commission_requests.id', 'commission_requests.price_from_snapshot_thb', 'commission_requests.quoted_price_thb',
    'commission_requests.status', 'commission_requests.status_changed_at', 'commission_requests.updated_at',
    'commission_requests.version',
    'experiment_assignments.assigned_at', 'experiment_assignments.experiment', 'experiment_assignments.user_id',
    'experiment_assignments.variant',
    'profiles.avatar_path', 'profiles.created_at', 'profiles.display_name', 'profiles.id',
    'reports.created_at', 'reports.details', 'reports.id', 'reports.reason', 'reports.reporter_id',
    'reports.resolved_at', 'reports.status', 'reports.target_id', 'reports.target_type',
    'request_events.actor_role', 'request_events.created_at', 'request_events.from_status',
    'request_events.id', 'request_events.note', 'request_events.request_id', 'request_events.to_status',
    'saved_artworks.artwork_id', 'saved_artworks.created_at', 'saved_artworks.user_id',
    'styles.is_active', 'styles.name_th', 'styles.slug', 'styles.sort',
    'swipe_events.action', 'swipe_events.artwork_id', 'swipe_events.created_at',
    'swipe_events.feed_session_id', 'swipe_events.id', 'swipe_events.user_id'
  ],
  'authenticated: readable columns match the reviewed snapshot (never admins, impressions, analytics, '
  'birth_date, original_path, reviewed_by, resolved_by, provider_ref, actor_id)'
);

select is(
  (select array_agg(n.nspname || '.' || p.proname order by n.nspname || '.' || p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (has_function_privilege('anon', p.oid, 'execute')
           or has_function_privilege('authenticated', p.oid, 'execute'))),
  null,
  'client-callable functions in public match the reviewed allow-list (empty until the first RPC feature)'
);

select is(
  (select array_agg(p.proname::text order by p.proname::text)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef),
  null,
  'SECURITY DEFINER functions in public match the reviewed allow-list (empty for now; helpers live in private)'
);

select is(
  (select array_agg(n.nspname || '.' || p.proname order by n.nspname || '.' || p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef
      and not coalesce(p.proconfig @> array['search_path=""'], false)),
  null,
  'every SECURITY DEFINER function pins an empty search_path'
);

select is(
  (select array_agg(p.proname::text order by p.proname::text)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'execute')),
  array['publishable_artist_ids'],
  'anon can execute only the publishable-artists helper (needed by public policies)'
);

select is(
  (select array_agg(p.proname::text order by p.proname::text)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'execute')),
  array['is_admin', 'my_counterpart_ids', 'my_quoting_artist_ids', 'publishable_artist_ids'],
  'authenticated can execute exactly the policy helpers in private'
);

-- Default privileges: the migration role's defaults in public grant clients nothing.
select is(
  (select array_agg(format('%s:%s', d.defaclobjtype, a.grantee::regrole) order by format('%s:%s', d.defaclobjtype, a.grantee::regrole))
     from pg_default_acl d
     join pg_namespace n on n.oid = d.defaclnamespace
     cross join lateral aclexplode(d.defaclacl) a
    where n.nspname = 'public'
      and d.defaclrole = current_user::regrole
      and a.grantee in ('anon'::regrole, 'authenticated'::regrole)),
  null,
  'default privileges of the migration role in public grant nothing to anon or authenticated'
);

-- Prove it: objects created now (as the migration role) start with no client privileges.
create table public.t_probe_table (id int);
create view public.t_probe_view with (security_invoker = true) as select 1 as one;
create function public.t_probe_fn() returns int language sql as 'select 1';

select is(
  (select array_agg(format('%s:%s', r.role, o.name) order by format('%s:%s', r.role, o.name))
     from (values ('anon'), ('authenticated')) r(role)
     cross join (values ('public.t_probe_table'), ('public.t_probe_view')) o(name)
    where has_any_column_privilege(r.role, o.name, 'SELECT')
       or has_table_privilege(r.role, o.name, 'INSERT')),
  null,
  'a newly created table or view is not readable or writable by clients'
);

-- Postgres grants EXECUTE on new functions to PUBLIC globally; migrations must revoke it themselves.
-- This proves the allow-list check above would catch a migration that forgets.
select ok(
  has_function_privilege('anon', 'public.t_probe_fn()', 'execute'),
  'a function created without `revoke execute ... from public` is visible to the allow-list check'
);

-- On real Supabase, the GraphQL API must not reflect any helper from schema private.
-- Dynamic SQL so this file still parses where pg_graphql is absent (the local stub).
create function pg_temp.graphql_query_fields() returns text language plpgsql as $$
declare v text;
begin
  execute $q$select graphql_public.graphql(query := '{ __schema { queryType { fields { name } } } }')::text$q$
    into v;
  return v;
end $$;
grant execute on function pg_temp.graphql_query_fields() to anon;

set local role anon;
select case
  when to_regprocedure('graphql_public.graphql(text,text,jsonb,jsonb)') is null
    then skip('pg_graphql is not installed here (local stub); CI on real Supabase runs this check', 1)
  else ok(
    pg_temp.graphql_query_fields() !~* '(publishable|isadmin|is_admin|counterpart|quoting)',
    'anon''s GraphQL schema exposes no private policy helper')
end;
reset role;

select * from finish();
rollback;
