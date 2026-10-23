-- What each persona can and cannot read. Fixtures are created inside the transaction and rolled back.
-- Every assertion is scoped to fixture ids (prefix f0000000-) so supabase/seed.sql cannot affect it.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(60);

-- ---------- Fixtures (as table owner) ----------
-- b1, b2, b3, b4 buyers · aa, ac verified artists · ab pending artist · ar revoked artist
-- as suspended verified artist · ad admin · xx erased (anonymised) buyer
insert into auth.users (id, email) values
  ('f0000000-0000-4000-a000-0000000000b1', 'b1@t.test'),
  ('f0000000-0000-4000-a000-0000000000b2', 'b2@t.test'),
  ('f0000000-0000-4000-a000-0000000000b3', 'b3@t.test'),
  ('f0000000-0000-4000-a000-0000000000b4', 'b4@t.test'),
  ('f0000000-0000-4000-a000-0000000000aa', 'aa@t.test'),
  ('f0000000-0000-4000-a000-0000000000ab', 'ab@t.test'),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac@t.test'),
  ('f0000000-0000-4000-a000-0000000000a7', 'ar@t.test'),
  ('f0000000-0000-4000-a000-0000000000a5', 'as@t.test'),
  ('f0000000-0000-4000-a000-0000000000ad', 'ad@t.test'),
  ('f0000000-0000-4000-a000-0000000000ee', null);

insert into profiles (id, display_name, birth_date, terms_accepted_version, is_suspended, deleted_at) values
  ('f0000000-0000-4000-a000-0000000000b1', 'b1', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000b2', 'b2', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000b3', 'b3', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000b4', 'b4', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000aa', 'aa', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000ab', 'ab', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000a7', 'ar', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000a5', 'as', '1990-01-01', 't', true,  null),
  ('f0000000-0000-4000-a000-0000000000ad', 'ad', '1990-01-01', 't', false, null),
  ('f0000000-0000-4000-a000-0000000000ee', 'ผู้ใช้ที่ลบบัญชีแล้ว', null, 't', false, now());

insert into admins (user_id) values ('f0000000-0000-4000-a000-0000000000ad');

insert into artist_profiles (user_id, queue_status, min_price_thb) values
  ('f0000000-0000-4000-a000-0000000000aa', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000ab', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000ac', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000a7', 'open', 500),
  ('f0000000-0000-4000-a000-0000000000a5', 'open', 500);

insert into artist_verifications (user_id, method, status, verified_at, provider_ref, reviewed_by) values
  ('f0000000-0000-4000-a000-0000000000aa', 'phone', 'verified', now(), 'ref-aa', 'f0000000-0000-4000-a000-0000000000ad'),
  ('f0000000-0000-4000-a000-0000000000ab', 'phone', 'pending',  null,  null, null),
  ('f0000000-0000-4000-a000-0000000000ac', 'phone', 'verified', now(), null, null),
  ('f0000000-0000-4000-a000-0000000000a7', 'phone', 'revoked',  now(), null, null),
  ('f0000000-0000-4000-a000-0000000000a5', 'phone', 'verified', now(), null, null);

insert into artist_contacts (user_id, line_id) values
  ('f0000000-0000-4000-a000-0000000000aa', 'aa-line'),
  ('f0000000-0000-4000-a000-0000000000ac', 'ac-line'),
  ('f0000000-0000-4000-a000-0000000000a5', 'as-line');

-- w1 public · w2 pending (aa) · w3 approved by pending ab · w4 approved by suspended as
-- w5 approved but deleted (aa) · w6 approved by revoked ar · w7 rejected (aa)
insert into artworks (id, artist_id, title, category_slug, price_from_thb, status,
                      original_path, display_path, published_at, deleted_at,
                      reviewed_by, rejection_reason) values
  ('f0000000-0000-4000-b000-000000000001', 'f0000000-0000-4000-a000-0000000000aa', 'w1', 'oc', 800, 'approved',
   'o/w1', 'd/w1', now(), null, 'f0000000-0000-4000-a000-0000000000ad', null),
  ('f0000000-0000-4000-b000-000000000002', 'f0000000-0000-4000-a000-0000000000aa', 'w2', 'oc', 800, 'pending_review',
   'o/w2', null, null, null, null, null),
  ('f0000000-0000-4000-b000-000000000003', 'f0000000-0000-4000-a000-0000000000ab', 'w3', 'oc', 800, 'approved',
   'o/w3', 'd/w3', now(), null, null, null),
  ('f0000000-0000-4000-b000-000000000004', 'f0000000-0000-4000-a000-0000000000a5', 'w4', 'oc', 800, 'approved',
   'o/w4', 'd/w4', now(), null, null, null),
  ('f0000000-0000-4000-b000-000000000005', 'f0000000-0000-4000-a000-0000000000aa', 'w5', 'oc', 800, 'approved',
   'o/w5', 'd/w5', now(), now(), null, null),
  ('f0000000-0000-4000-b000-000000000006', 'f0000000-0000-4000-a000-0000000000a7', 'w6', 'oc', 800, 'approved',
   'o/w6', 'd/w6', now(), null, null, null),
  ('f0000000-0000-4000-b000-000000000007', 'f0000000-0000-4000-a000-0000000000aa', 'w7', 'oc', 800, 'rejected',
   'o/w7', null, null, null, 'f0000000-0000-4000-a000-0000000000ad', 'ภาพไม่ชัด');

insert into artwork_styles (artwork_id, style_slug) values
  ('f0000000-0000-4000-b000-000000000001', 'anime'),
  ('f0000000-0000-4000-b000-000000000002', 'anime'),
  ('f0000000-0000-4000-b000-000000000004', 'anime');

-- r1 b1→aa quoted · r2 b1→ac submitted · r3 b2→aa declined · r4 b2→ac confirmed
-- r5 b3→as delivered (artist suspended afterwards) · r6 ee(erased)→aa completed
-- r7 b3→ac expired after a quote · r8 b3→aa cancelled after a quote · r9 b4→ac completed
insert into commission_requests (id, buyer_id, artist_id, artwork_id, category_slug, description,
                                 buyer_budget_thb, quoted_price_thb, agreed_price_thb, status) values
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-a000-0000000000aa',
   'f0000000-0000-4000-b000-000000000001', 'oc', 'ขอภาพ OC ครึ่งตัว พื้นหลังเรียบ', 900, 1000, null, 'quoted'),
  ('f0000000-0000-4000-c000-000000000002', 'f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-a000-0000000000ac',
   null, 'oc', 'ขอภาพตัวละคร D&D เต็มตัวพร้อมอาวุธ', 1500, null, null, 'submitted'),
  ('f0000000-0000-4000-c000-000000000003', 'f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-a000-0000000000aa',
   null, 'oc', 'ขอภาพจิบิสองตัวละครกอดกันน่ารัก', 700, null, null, 'declined'),
  ('f0000000-0000-4000-c000-000000000004', 'f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-a000-0000000000ac',
   null, 'oc', 'ขอภาพตัวละครสาย fantasy ครึ่งตัว', 1200, 1200, 1200, 'confirmed'),
  ('f0000000-0000-4000-c000-000000000005', 'f0000000-0000-4000-a000-0000000000b3', 'f0000000-0000-4000-a000-0000000000a5',
   null, 'oc', 'ขอภาพ OC เต็มตัวพร้อมพื้นหลังป่า', 900, 900, 900, 'delivered'),
  ('f0000000-0000-4000-c000-000000000006', 'f0000000-0000-4000-a000-0000000000ee', 'f0000000-0000-4000-a000-0000000000aa',
   null, 'oc', 'งานเก่าของผู้ใช้ที่ลบบัญชีไปแล้ว', 500, 500, 500, 'completed'),
  ('f0000000-0000-4000-c000-000000000007', 'f0000000-0000-4000-a000-0000000000b3', 'f0000000-0000-4000-a000-0000000000ac',
   null, 'oc', 'ขอภาพแต่ไม่ได้ตอบกลับจนหมดเวลา', 800, 800, null, 'expired'),
  ('f0000000-0000-4000-c000-000000000008', 'f0000000-0000-4000-a000-0000000000b3', 'f0000000-0000-4000-a000-0000000000aa',
   null, 'oc', 'ขอภาพแล้วยกเลิกหลังได้รับราคา', 800, 800, null, 'cancelled'),
  ('f0000000-0000-4000-c000-000000000009', 'f0000000-0000-4000-a000-0000000000b4', 'f0000000-0000-4000-a000-0000000000ac',
   null, 'oc', 'งานที่ส่งมอบและยืนยันรับแล้ว', 1000, 1000, 1000, 'completed');

insert into request_events (request_id, actor_id, actor_role, from_status, to_status, note) values
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000b1', 'buyer', null, 'submitted', null),
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000aa', 'artist', 'submitted', 'quoted', null),
  ('f0000000-0000-4000-c000-000000000001', 'f0000000-0000-4000-a000-0000000000ad', 'admin', 'quoted', 'quoted', 'admin note'),
  ('f0000000-0000-4000-c000-000000000002', 'f0000000-0000-4000-a000-0000000000b1', 'buyer', null, 'submitted', null),
  ('f0000000-0000-4000-c000-000000000003', 'f0000000-0000-4000-a000-0000000000b2', 'buyer', null, 'submitted', null);

insert into saved_artworks (user_id, artwork_id) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001'),
  ('f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-b000-000000000001');

insert into swipe_events (user_id, artwork_id, feed_session_id, action) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'like'),
  ('f0000000-0000-4000-a000-0000000000b2', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'pass');

insert into feed_impressions (user_id, artwork_id, feed_session_id, variant, position) values
  ('f0000000-0000-4000-a000-0000000000b1', 'f0000000-0000-4000-b000-000000000001', gen_random_uuid(), 'swipe', 0);

insert into reports (reporter_id, target_type, target_id, reason, status, resolved_by, resolved_at) values
  ('f0000000-0000-4000-a000-0000000000b1', 'artwork', 'f0000000-0000-4000-b000-000000000003', 'stolen_art',
   'actioned', 'f0000000-0000-4000-a000-0000000000ad', now()),
  ('f0000000-0000-4000-a000-0000000000b2', 'artwork', 'f0000000-0000-4000-b000-000000000001', 'other',
   'open', null, null);

insert into admin_audit_log (admin_id, action, target_type, target_id) values
  ('f0000000-0000-4000-a000-0000000000ad', 'artwork.approve', 'artwork', 'f0000000-0000-4000-b000-000000000001');

-- Fixture-scoped views. security_invoker makes RLS and column grants apply to the caller.
create temp view t_artworks with (security_invoker = true) as
  select id from artworks where id::text like 'f0000000-%';
create temp view t_profiles with (security_invoker = true) as
  select id, display_name from profiles where id::text like 'f0000000-%';
create temp view t_artists with (security_invoker = true) as
  select user_id from artist_profiles where user_id::text like 'f0000000-%';
create temp view t_contacts with (security_invoker = true) as
  select line_id from artist_contacts where user_id::text like 'f0000000-%';
create temp view t_requests with (security_invoker = true) as
  select id from commission_requests where id::text like 'f0000000-%';
create temp view t_events with (security_invoker = true) as
  select id from request_events where request_id::text like 'f0000000-%';
create temp view t_reports with (security_invoker = true) as
  select id from reports where reporter_id::text like 'f0000000-%';
grant select on t_artworks, t_profiles, t_artists, t_contacts, t_requests, t_events, t_reports
  to anon, authenticated;

-- Short names for the fixture ids used in expectations.
create temp table ids (k text primary key, id uuid);
insert into ids values
  ('b1', 'f0000000-0000-4000-a000-0000000000b1'), ('b2', 'f0000000-0000-4000-a000-0000000000b2'),
  ('aa', 'f0000000-0000-4000-a000-0000000000aa'), ('ac', 'f0000000-0000-4000-a000-0000000000ac'),
  ('ee', 'f0000000-0000-4000-a000-0000000000ee'),
  ('w1', 'f0000000-0000-4000-b000-000000000001'), ('w2', 'f0000000-0000-4000-b000-000000000002'),
  ('w3', 'f0000000-0000-4000-b000-000000000003'), ('w7', 'f0000000-0000-4000-b000-000000000007'),
  ('b3', 'f0000000-0000-4000-a000-0000000000b3'),
  ('r1', 'f0000000-0000-4000-c000-000000000001'), ('r3', 'f0000000-0000-4000-c000-000000000003'),
  ('r6', 'f0000000-0000-4000-c000-000000000006'), ('r8', 'f0000000-0000-4000-c000-000000000008');
grant select on ids to anon, authenticated;

-- ======================= anon =======================
set local role anon;
select set_config('request.jwt.claims', '', true);

select results_eq('select id from t_artworks order by id', $$select id from ids where k = 'w1'$$,
  'anon: only approved, live work by a verified, unsuspended artist (not pending, revoked, suspended, deleted)');
select is((select count(*)::int from artwork_styles where artwork_id::text like 'f0000000-%'), 1,
  'anon: styles only of visible artworks');
select results_eq('select id from t_profiles order by id',
  $$select id from ids where k in ('aa', 'ac') order by id$$,
  'anon: profiles only of publishable artists (no buyers, admins, pending, suspended, erased)');
select results_eq('select user_id from t_artists order by user_id',
  $$select id from ids where k in ('aa', 'ac') order by id$$,
  'anon: artist profiles only of publishable artists');
select throws_ok('select birth_date from profiles', '42501', null, 'anon: birth_date is not readable');
select throws_ok('select original_path from artworks', '42501', null, 'anon: original_path is not readable');
select throws_ok('select reviewed_by from artworks', '42501', null, 'anon: reviewed_by (admin id) is not readable');
select throws_ok('select * from artworks', '42501', null, 'anon: select * on artworks is rejected');
select throws_ok('select 1 from artist_contacts', '42501', null, 'anon: contacts are not readable at all');
select throws_ok('select 1 from commission_requests', '42501', null, 'anon: requests are not readable at all');
select throws_ok('select 1 from admins', '42501', null, 'anon: admins are not readable at all');
select throws_ok('select private.is_admin()', '42501', null, 'anon: cannot call is_admin');
select throws_ok('select public.publishable_artist_ids()',
  '42883', null, 'anon: the publishability helper is not an API function in public');

-- ======================= buyer b1 =======================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b1"}', true);

select results_eq('select id from t_artworks order by id', $$select id from ids where k = 'w1'$$,
  'buyer: only publicly visible artworks');
select results_eq('select id from t_profiles order by id',
  $$select id from ids where k in ('b1', 'aa', 'ac') order by id$$,
  'buyer: self plus publishable artists (the other parties here are publishable too)');
select is((select count(*)::int from t_requests), 2, 'buyer: both own requests');
select is((select count(*)::int from t_events), 4, 'buyer: history of own requests only');
select throws_ok('select actor_id from request_events', '42501', null,
  'buyer: actor_id is not readable (it would reveal admin identities)');
select results_eq($$select actor_role from request_events where note = 'admin note'$$, $$values ('admin')$$,
  'buyer: an admin action on their request shows as role "admin", not as a person');
select results_eq('select line_id from t_contacts', $$values ('aa-line')$$,
  'buyer: contact of the artist who quoted (quoted), not of one still at submitted');
select is((select count(*)::int from saved_artworks where user_id::text like 'f0000000-%'), 1, 'buyer: own saved only');
select is((select count(*)::int from swipe_events where user_id::text like 'f0000000-%'), 1, 'buyer: own swipes only');
select throws_ok('select 1 from feed_impressions', '42501', null, 'buyer: impressions are not readable');
select throws_ok('select 1 from analytics_events', '42501', null, 'buyer: analytics are not readable');
select is((select count(*)::int from t_reports), 1, 'buyer: own reports only');
select throws_ok('select resolved_by from reports', '42501', null, 'buyer: resolved_by (admin id) is not readable');
select is((select count(*)::int from admin_audit_log where admin_id::text like 'f0000000-%'), 0,
  'buyer: audit log rows are hidden');
select is((select count(*)::int from artist_verifications where user_id::text like 'f0000000-%'), 0,
  'buyer: verifications are hidden');
select is(private.is_admin(), false, 'buyer is not an admin');
select throws_ok('select birth_date from profiles', '42501', null, 'buyer: birth_date is not readable');
select throws_ok($$update profiles set display_name = 'x' where id = 'f0000000-0000-4000-a000-0000000000b1'$$,
  '42501', null, 'buyer: cannot update own profile directly');
select throws_ok($$update commission_requests set status = 'completed'
  where id = 'f0000000-0000-4000-c000-000000000001'$$, '42501', null, 'buyer: cannot change status directly');

-- ======================= buyer b2 (declined + confirmed) =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b2"}', true);
select results_eq('select line_id from t_contacts', $$values ('ac-line')$$,
  'buyer: contact shown for confirmed, hidden for declined');
select is((select count(*)::int from t_requests), 2, 'buyer b2: own requests only, never b1''s');
select is((select count(*)::int from t_events), 1, 'buyer b2: history of own requests only');

-- ======================= buyer b3 (artist suspended after delivery) =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b3"}', true);
select results_eq('select line_id from t_contacts', $$values ('as-line')$$,
  'buyer: contact kept after the artist is suspended (decision L4), hidden after expired or cancelled');
select is((select count(*)::int from t_profiles where id = 'f0000000-0000-4000-a000-0000000000a5'), 1,
  'buyer: can see the suspended counterpart''s profile on their own request');
select is((select count(*)::int from t_artworks where id = 'f0000000-0000-4000-b000-000000000004'), 0,
  'buyer: still cannot see a suspended artist''s artwork');

-- ======================= buyer b4 (completed) =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000b4"}', true);
select results_eq('select line_id from t_contacts', $$values ('ac-line')$$, 'buyer: contact shown for completed');

-- ======================= verified artist aa =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000aa"}', true);
select results_eq('select id from t_artworks order by id',
  $$select id from ids where k in ('w1', 'w2', 'w7') order by id$$,
  'artist: public work plus own pending and rejected work, not own deleted work');
select throws_ok('select rejection_reason from artworks', '42501', null,
  'artist: rejection_reason comes through a server function, not the table');
select results_eq('select id from t_requests order by id',
  $$select id from ids where k in ('r1', 'r3', 'r6', 'r8') order by id$$,
  'artist: only requests addressed to them');
select is((select count(*)::int from t_events), 4, 'artist: history of their requests');
select results_eq('select line_id from t_contacts', $$values ('aa-line')$$, 'artist: own contact only');
select results_eq('select id from t_profiles order by id',
  $$select id from ids where k in ('b1', 'b2', 'b3', 'aa', 'ac', 'ee') order by id$$,
  'artist: buyers of own requests in any status (including an erased one) and publishable artists');
select results_eq($$select display_name from t_profiles where id = 'f0000000-0000-4000-a000-0000000000ee'$$,
  $$values ('ผู้ใช้ที่ลบบัญชีแล้ว')$$, 'artist: an erased buyer shows only the anonymised name');
select is((select count(*)::int from artist_verifications where user_id::text like 'f0000000-%'), 1,
  'artist: own verification only');
select throws_ok('select provider_ref from artist_verifications', '42501', null,
  'artist: provider_ref is not readable');

-- ======================= pending artist ab =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000ab"}', true);
select results_eq('select id from t_artworks order by id',
  $$select id from ids where k in ('w1', 'w3') order by id$$,
  'pending artist: sees own approved work, which the public cannot');
select is((select count(*)::int from t_artists where user_id = 'f0000000-0000-4000-a000-0000000000ab'), 1,
  'pending artist: sees own artist profile');
select is((select count(*)::int from artwork_styles where artwork_id = 'f0000000-0000-4000-b000-000000000004'), 0,
  'styles of a suspended artist''s work stay hidden');

-- ======================= admin ad =======================
select set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-a000-0000000000ad"}', true);
select is(private.is_admin(), true, 'admin is recognised');
select is((select count(*)::int from t_artworks), 7, 'admin: every artwork including deleted');
select is((select count(*)::int from t_profiles), 11, 'admin: every profile');
select is((select count(*)::int from t_requests), 9, 'admin: every request');
select is((select count(*)::int from admin_audit_log where admin_id::text like 'f0000000-%'), 1, 'admin: the audit log');
select is((select count(*)::int from artworks where id::text like 'f0000000-%' and deleted_at is not null), 1,
  'admin: can tell which artworks are soft-deleted');
select is((select count(*)::int from t_reports), 2, 'admin: every report');
select throws_ok('select 1 from admins', '42501', null, 'admin: even admins cannot list admins through the API');
select throws_ok($$update artworks set status = 'removed' where id = 'f0000000-0000-4000-b000-000000000001'$$,
  '42501', null, 'admin: cannot bypass the audited functions with a direct write');

select * from finish();
rollback;
