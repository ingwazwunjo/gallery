-- What each persona can and cannot read. Fixtures are created inside the transaction and rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(37);

-- ---------- Fixtures (as table owner) ----------
-- Personas
--   b1 buyer · b2 another buyer · aa verified artist · ab unverified artist
--   ac verified artist (second) · as suspended verified artist · ad admin
insert into auth.users (id, email) values
  ('f0000000-0000-4000-a000-0000000000b1', 'b1@t.test'),
  ('f0000000-0000-4000-a000-0000000000b2', 'b2@t.test'),
  ('f0000000-0000-4000-a000-0000000000aa', 'aa@t.test'),
  ('f0000000-0000-4000-a000-0000000000ab', 'ab@t.test'),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac@t.test'),
  ('f0000000-0000-4000-a000-0000000000a5', 'as@t.test'),
  ('f0000000-0000-4000-a000-0000000000ad', 'ad@t.test');

insert into profiles (id, display_name, birth_date, terms_accepted_version, is_suspended) values
  ('f0000000-0000-4000-a000-0000000000b1', 'b1', '1990-01-01', 't', false),
  ('f0000000-0000-4000-a000-0000000000b2', 'b2', '1990-01-01', 't', false),
  ('f0000000-0000-4000-a000-0000000000aa', 'aa', '1990-01-01', 't', false),
  ('f0000000-0000-4000-a000-0000000000ab', 'ab', '1990-01-01', 't', false),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac', '1990-01-01', 't', false),
  ('f0000000-0000-4000-a000-0000000000a5', 'as', '1990-01-01', 't', true),
  ('f0000000-0000-4000-a000-0000000000ad', 'ad', '1990-01-01', 't', false);

insert into admins (user_id) values ('f0000000-0000-4000-a000-0000000000ad');

insert into artist_profiles (user_id, queue_status, min_price_thb) values
  ('f0000000-0000-4000-a000-0000000000aa', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000ab', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000ac', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000a5', 'open', 500);

insert into artist_verifications (user_id, method, status, verified_at) values
  ('f0000000-0000-4000-a000-0000000000aa', 'phone', 'verified', now()),
  ('f0000000-0000-4000-a000-0000000000ab', 'phone', 'pending', null),
  ('f0000000-0000-4000-a000-0000000000ac', 'phone', 'verified', now()),
  ('f0000000-0000-4000-a000-0000000000a5', 'phone', 'verified', now());

insert into artist_contacts (user_id, line_id) values
  ('f0000000-0000-4000-a000-0000000000aa', 'aa-line'),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac-line');

-- Artworks: w1 public · w2 pending (owner aa) · w3 approved by unverified ab
--           w4 approved by suspended artist · w5 approved but deleted (owner aa)
insert into artworks (id, artist_id, title, category_slug, price_from_thb, status,
                      original_path, display_path, published_at, deleted_at) values
  ('f0000000-0000-4000-b000-000000000001', 'f0000000-0000-4000-a000-0000000000aa', 'w1', 'oc', 800, 'approved',
   'o/w1', 'd/w1', now(), null),
  ('f0000000-0000-4000-b000-000000000002', 'f0000000-0000-4000-a000-0000000000aa', 'w2', 'oc', 800, 'pending_review',
   'o/w2', null, null, null),
  ('f0000000-0000-4000-b000-000000000003', 'f0000000-0000-4000-a000-0000000000ab', 'w3', 'oc', 800, 'approved',
   'o/w3', 'd/w3', now(), null),
  ('f0000000-0000-4000-b000-000000000004', 'f0000000-0000-4000-a000-0000000000a5', 'w4', 'oc', 800, 'approved',
   'o/w4', 'd/w4', now(), null),
  ('f0000000-0000-4000-b000-000000000005', 'f0000000-0000-4000-a000-0000000000aa', 'w5', 'oc', 800, 'approved',
   'o/w5', 'd/w5', now(), now());

insert into artwork_styles (artwork_id, style_slug) values
  ('f0000000-0000-4000-b000-000000000001', 'anime'),
  ('f0000000-0000-4000-b000-000000000002', 'anime');

-- Requests: r1 b1→aa quoted (contact revealed) · r2 b1→ac submitted (contact hidden)
insert into commission_requests (id, buyer_id, artist_id, category_slug, description,
                                 buyer_budget_thb, quoted_price_thb, status) values
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000b1',
   'f0000000-0000-4000-a000-0000000000aa', 'oc', 'ขอภาพ OC ครึ่งตัว พื้นหลังเรียบ', 900, 1000, 'quoted'),
  ('f0000000-0000-4000-c000-000000000002', 'f0000000-0000-4000-a000-0000000000b1',
   'f0000000-0000-4000-a000-0000000000ac', 'oc', 'ขอภาพตัวละคร D&D เต็มตัวพร้อมอาวุธ', 1500, null, 'submitted');

insert into request_events (request_id, actor_id, from_status, to_status) values
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000b1', null, 'submitted'),
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000aa', 'submitted', 'quoted'),
  ('f0000000-0000-4000-c000-000000000002', 'f0000000-0000-4000-a000-0000000000b1', null, 'submitted');

insert into saved_artworks (user_id, artwork_id) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001'),
  ('f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-b000-000000000001');

insert into swipe_events (user_id, artwork_id, feed_session_id, action) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'like'),
  ('f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'pass');

insert into feed_impressions (user_id, artwork_id, feed_session_id, variant, position) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'swipe', 0);

insert into reports (reporter_id, target_type, target_id, reason) values
  ('f0000000-0000-4000-a000-0000000000b1', 'artwork', 'f0000000-0000-4000-b000-000000000003', 'stolen_art'),
  ('f0000000-0000-4000-a000-0000000000b2', 'artwork', 'f0000000-0000-4000-b000-000000000001', 'other');

insert into admin_audit_log (admin_id, action, target_type, target_id) values
  ('f0000000-0000-4000-a000-0000000000ad', 'artwork.approve', 'artwork', 'f0000000-0000-4000-b000-000000000001');

-- Counts are always restricted to fixture ids so the local seed cannot affect them.
create temp view t_artworks as
  select id from artworks where id::text like 'f0000000-0000-4000-b000-%';
grant select on t_artworks to anon, authenticated;
-- A view runs with its owner's rights unless security_invoker is set; set it so RLS applies.
alter view t_artworks set (security_invoker = true);

-- ---------- anon ----------
set local role anon;
select set_config('request.jwt.claims', '', true);

select results_eq('select id from t_artworks order by id',
  $$values ('f0000000-0000-4000-b000-000000000001'::uuid)$$,
  'anon sees only approved, live work by a verified, unsuspended artist');
select is((select count(*)::int from artwork_styles where artwork_id::text like 'f0000000-0000-4000-b000-%'), 1,
  'anon sees styles only of visible artworks');
select lives_ok('select id, display_name from profiles limit 1', 'anon can read public profile columns');
select throws_ok('select birth_date from profiles', '42501', null, 'anon cannot read birth_date');
select is((select count(*)::int from artist_contacts), 0, 'anon sees no contacts');
select is((select count(*)::int from commission_requests), 0, 'anon sees no requests');
select throws_ok($$insert into categories (slug, name_th) values ('zz', 'zz')$$, '42501', null,
  'anon cannot write reference data');
select throws_ok('select public.is_admin()', '42501', null, 'anon cannot call is_admin');

-- ---------- buyer b1 ----------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b1"}', true);

select results_eq('select id from t_artworks order by id',
  $$values ('f0000000-0000-4000-b000-000000000001'::uuid)$$,
  'buyer sees only publicly visible artworks');
select is((select count(*)::int from commission_requests), 2, 'buyer sees both own requests');
select is((select count(*)::int from request_events), 3, 'buyer sees history of own requests');
select results_eq('select line_id from artist_contacts', $$values ('aa-line')$$,
  'buyer sees contact only of the artist who quoted');
select is((select count(*)::int from saved_artworks), 1, 'buyer sees only own saved artworks');
select is((select count(*)::int from swipe_events), 1, 'buyer sees only own swipes');
select is((select count(*)::int from feed_impressions), 0, 'impressions are not readable by clients');
select is((select count(*)::int from reports), 1, 'buyer sees only own reports');
select is((select count(*)::int from admin_audit_log), 0, 'buyer cannot read the audit log');
select is((select count(*)::int from artist_verifications), 0, 'buyer cannot read verifications');
select is((select count(*)::int from admins), 0, 'buyer cannot list admins');
select is(public.is_admin(), false, 'buyer is not an admin');
select throws_ok($$update profiles set display_name = 'x' where id = 'f0000000-0000-4000-a000-0000000000b1'$$,
  '42501', null, 'buyer cannot update own profile directly');
select throws_ok($$update commission_requests set status = 'confirmed', agreed_price_thb = 1
  where id = 'f0000000-0000-4000-c000-000000000001'$$,
  '42501', null, 'buyer cannot change request status directly');
select throws_ok('select birth_date from profiles', '42501', null,
  'authenticated users cannot read birth_date either');

-- ---------- other buyer b2 ----------
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b2"}', true);
select is((select count(*)::int from commission_requests), 0, 'a stranger cannot see someone else''s requests');
select is((select count(*)::int from request_events), 0, 'a stranger cannot see request history');
select is((select count(*)::int from artist_contacts), 0, 'a stranger sees no contacts');

-- ---------- verified artist aa ----------
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000aa"}', true);
select results_eq('select id from t_artworks order by id',
  $$values ('f0000000-0000-4000-b000-000000000001'::uuid), ('f0000000-0000-4000-b000-000000000002'::uuid)$$,
  'artist sees public work plus own pending work, not own deleted work');
select results_eq('select id from commission_requests',
  $$values ('f0000000-0000-4000-c000-000000000001'::uuid)$$,
  'artist sees only requests addressed to them');
select results_eq('select line_id from artist_contacts', $$values ('aa-line')$$,
  'artist sees own contact only');
select is((select count(*)::int from artist_verifications), 1, 'artist sees own verification');

-- ---------- unverified artist ab ----------
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000ab"}', true);
select results_eq('select id from t_artworks order by id',
  $$values ('f0000000-0000-4000-b000-000000000001'::uuid), ('f0000000-0000-4000-b000-000000000003'::uuid)$$,
  'unverified artist sees own approved work, which the public cannot');

-- ---------- admin ad ----------
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000ad"}', true);
select is(public.is_admin(), true, 'admin is recognised');
select is((select count(*)::int from t_artworks), 5, 'admin sees every artwork including deleted');
select is((select count(*)::int from commission_requests), 2, 'admin can read all requests');
select is((select count(*)::int from admin_audit_log), 1, 'admin can read the audit log');
select is((select count(*)::int from reports), 2, 'admin sees all reports');
select throws_ok($$update artworks set status = 'removed' where id = 'f0000000-0000-4000-b000-000000000001'$$,
  '42501', null, 'admin cannot bypass the audited functions with a direct write');

select * from finish();
rollback;
