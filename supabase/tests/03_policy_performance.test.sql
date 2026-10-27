-- Policies must not do per-row work that grows with other tables. A correlated subquery in a policy
-- once made one unfiltered read of profiles take minutes. Each read here must finish well within a
-- hard statement timeout on a realistically large dataset; a regression fails instead of hanging.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

-- ---------- Bulk fixtures: 50k users, 1k artists (half verified), 20k artworks, 20k requests ----------
insert into auth.users (id, email)
  select ('f2000000-0000-4000-a000-' || lpad(to_hex(i), 12, '0'))::uuid, null
  from generate_series(1, 50000) i;
insert into profiles (id, display_name, birth_date, terms_accepted_version)
  select ('f2000000-0000-4000-a000-' || lpad(to_hex(i), 12, '0'))::uuid, 'u' || i, '1990-01-01', 't'
  from generate_series(1, 50000) i;
insert into artist_profiles (user_id, queue_status)
  select ('f2000000-0000-4000-a000-' || lpad(to_hex(i), 12, '0'))::uuid, 'open'
  from generate_series(1, 1000) i;
insert into artist_verifications (user_id, method, status, verified_at)
  select ('f2000000-0000-4000-a000-' || lpad(to_hex(i), 12, '0'))::uuid, 'phone',
         case when i % 2 = 0 then 'verified' else 'pending' end::verification_status,
         case when i % 2 = 0 then now() end
  from generate_series(1, 1000) i;
insert into artist_contacts (user_id, line_id)
  select ('f2000000-0000-4000-a000-' || lpad(to_hex(i), 12, '0'))::uuid, 'line' || i
  from generate_series(1, 1000) i;
insert into artworks (id, artist_id, title, category_slug, price_from_thb, status, original_path, display_path, published_at)
  select ('f2000000-0000-4000-b000-' || lpad(to_hex(i), 12, '0'))::uuid,
         ('f2000000-0000-4000-a000-' || lpad(to_hex(1 + i % 1000), 12, '0'))::uuid,
         'w' || i, 'oc', 500, 'approved', 'o/p' || i, 'd/p' || i, now()
  from generate_series(1, 20000) i;
insert into artwork_styles (artwork_id, style_slug)
  select ('f2000000-0000-4000-b000-' || lpad(to_hex(i), 12, '0'))::uuid, 'anime'
  from generate_series(1, 20000) i;
insert into commission_requests (id, buyer_id, artist_id, category_slug, description, buyer_budget_thb,
                                 quoted_price_thb, agreed_price_thb, status)
  select ('f2000000-0000-4000-c000-' || lpad(to_hex(i), 12, '0'))::uuid,
         ('f2000000-0000-4000-a000-' || lpad(to_hex(1001 + i % 49000), 12, '0'))::uuid,
         ('f2000000-0000-4000-a000-' || lpad(to_hex(1 + i % 1000), 12, '0'))::uuid,
         'oc', 'งานทดสอบประสิทธิภาพของ policy', 500, 500, 500, 'completed'
  from generate_series(1, 20000) i;
insert into request_events (request_id, actor_id, actor_role, to_status)
  select ('f2000000-0000-4000-c000-' || lpad(to_hex(i), 12, '0'))::uuid,
         ('f2000000-0000-4000-a000-' || lpad(to_hex(1001 + i % 49000), 12, '0'))::uuid, 'buyer', 'submitted'
  from generate_series(1, 20000) i;
-- Deliberately NO `analyze`: this is the worst case (e.g. right after a bulk load, before autovacuum).
-- Measured on this dataset: the old correlated profiles policy took 85 s without statistics and
-- 0.3 s with them; the set-based policies take about 0.02 s either way. Each read must finish in 5 s.
set local statement_timeout = '5s';

set local role anon;
select set_config('request.jwt.claims', '', true);
select lives_ok('select count(*) from profiles', 'anon: count all profiles quickly');
select lives_ok('select count(*) from artworks', 'anon: count all artworks quickly');
select lives_ok('select count(*) from artwork_styles', 'anon: count all artwork styles quickly');

reset role;
set local role authenticated;
-- A buyer with a request, and an artist with about 20 requests.
select set_config('request.jwt.claims', '{"sub":"f2000000-0000-4000-a000-0000000003ea"}', true);
select lives_ok('select count(*) from profiles', 'buyer: count all visible profiles quickly');
select lives_ok('select count(*) from artist_contacts', 'buyer: count visible contacts quickly');
select lives_ok('select count(*) from request_events', 'buyer: count visible request history quickly');

select set_config('request.jwt.claims', '{"sub":"f2000000-0000-4000-a000-000000000002"}', true);
select lives_ok('select count(*) from profiles', 'artist: count all visible profiles quickly');
select lives_ok('select count(*) from artwork_styles', 'artist: count all visible artwork styles quickly');

select * from finish();
rollback;
