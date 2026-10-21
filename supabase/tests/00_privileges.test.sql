-- Structural guarantees that every future migration must keep.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  null,
  'every public table has RLS enabled'
);

select is(
  (select array_agg(format('%s:%s:%s', grantee, table_name, privilege_type) order by 1)
     from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')),
  null,
  'clients have no direct write privilege on any public table'
);

select is(
  (select array_agg(column_name::text order by column_name)
     from information_schema.column_privileges
    where table_schema = 'public' and table_name = 'profiles'
      and grantee = 'anon' and privilege_type = 'SELECT'),
  array['avatar_path', 'created_at', 'display_name', 'id'],
  'anon can read only the public columns of profiles'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  array['artist_is_publishable'],
  'anon can execute only artist_is_publishable'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and not coalesce(p.proconfig @> array['search_path=""'], false)),
  null,
  'every SECURITY DEFINER function pins an empty search_path'
);

select * from finish();
rollback;
