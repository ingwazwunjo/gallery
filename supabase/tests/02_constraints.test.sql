-- Data integrity rules enforced by the database itself (they hold even for server-side code).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(29);

insert into auth.users (id, email) values
  ('f1000000-0000-4000-a000-000000000001', 'c1@t.test'),
  ('f1000000-0000-4000-a000-000000000002', 'c2@t.test'),
  ('f1000000-0000-4000-a000-000000000003', 'c3@t.test');
insert into profiles (id, display_name, birth_date, terms_accepted_version) values
  ('f1000000-0000-4000-a000-000000000001', 'c1', '1990-01-01', 't'),
  ('f1000000-0000-4000-a000-000000000002', 'c2', '1990-01-01', 't'),
  ('f1000000-0000-4000-a000-000000000003', 'c3', '1990-01-01', 't');
insert into artist_profiles (user_id) values
  ('f1000000-0000-4000-a000-000000000002'),
  ('f1000000-0000-4000-a000-000000000003');
insert into artworks (id, artist_id, title, category_slug, price_from_thb, original_path) values
  ('f1000000-0000-4000-b000-000000000002', 'f1000000-0000-4000-a000-000000000002', 'c2 work', 'oc', 500, 'o/c2'),
  ('f1000000-0000-4000-b000-000000000003', 'f1000000-0000-4000-a000-000000000003', 'c3 work', 'oc', 500, 'o/c3');

-- ---------- artworks, contacts, profiles ----------
select throws_ok($$insert into artworks (artist_id, title, category_slug, price_from_thb, status, original_path)
  values ('f1000000-0000-4000-a000-000000000002', 't', 'oc', 500, 'approved', 'o/x')$$,
  '23514', null, 'an approved artwork must have a display image and publish time');
select throws_ok($$insert into artworks (artist_id, title, category_slug, price_from_thb, original_path)
  values ('f1000000-0000-4000-a000-000000000002', 't', 'oc', 0, 'o/y')$$,
  '23514', null, 'price must be at least 1 THB');
select throws_ok($$insert into artist_contacts (user_id) values ('f1000000-0000-4000-a000-000000000002')$$,
  '23514', null, 'a contact row needs at least one handle');
select throws_ok($$update profiles set birth_date = null where id = 'f1000000-0000-4000-a000-000000000001'$$,
  '23514', null, 'an active profile must keep its birth date');
select throws_ok($$update profiles set deleted_at = now() where id = 'f1000000-0000-4000-a000-000000000001'$$,
  '23514', null, 'an erased profile must not keep birth date or avatar');

-- ---------- verification: never an ID number ----------
select throws_ok($$insert into artist_verifications (user_id, method, status)
  values ('f1000000-0000-4000-a000-000000000002', 'phone', 'verified')$$,
  '23514', null, 'a verified artist must have a verification time');
select throws_ok($$insert into artist_verifications (user_id, method, provider_ref)
  values ('f1000000-0000-4000-a000-000000000002', 'phone', 'id-1101700203451')$$,
  '23514', null, 'a 13-digit national ID number cannot be stored as a provider reference');
select throws_ok($$insert into artist_verifications (user_id, method, provider_ref)
  values ('f1000000-0000-4000-a000-000000000002', 'phone', '1-1017-00203-45-1')$$,
  '23514', null, 'nor with dashes');
select throws_ok($$insert into artist_verifications (user_id, method, provider_ref)
  values ('f1000000-0000-4000-a000-000000000002', 'phone', '1 1017 00203 45 1')$$,
  '23514', null, 'nor with spaces');
select throws_ok($$insert into artist_verifications (user_id, method)
  values ('f1000000-0000-4000-a000-000000000002', 'national_id')$$,
  '22P02', null, 'national ID is not a verification method in the MVP');

-- ---------- commission requests ----------
select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-a000-000000000002', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขอภาพตัวเองหนึ่งภาพสวย ๆ ครับ', 500)$$,
  '23514', null, 'an artist cannot commission themself');
select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description,
                                                     buyer_budget_thb, agreed_price_thb, status)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขอภาพตัวละคร OC ครึ่งตัวหนึ่งภาพ', 500, 1, 'completed')$$,
  '23514', null, 'a completed request must have both a quoted and an agreed price');
select throws_ok($$insert into commission_requests (buyer_id, artist_id, artwork_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000002',
          'f1000000-0000-4000-b000-000000000003', 'oc', 'ขอภาพแบบผลงานของศิลปินอีกคนหนึ่ง', 500)$$,
  '23503', null, 'the inspiring artwork must belong to the artist being asked');
select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb,
                                                     created_at, status_changed_at)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000003', 'oc',
          'ขอภาพตัวละคร OC ครึ่งตัวหนึ่งภาพ', 500, now(), now() - interval '1 day')$$,
  '23514', null, 'status cannot change before the request was created');
select lives_ok($$insert into commission_requests (id, buyer_id, artist_id, artwork_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-c000-000000000001', 'f1000000-0000-4000-a000-000000000001',
          'f1000000-0000-4000-a000-000000000002', 'f1000000-0000-4000-b000-000000000002', 'oc',
          'ขอภาพตัวละคร OC ครึ่งตัวหนึ่งภาพ', 500)$$,
  'a valid request referencing the artist''s own artwork is accepted');
select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขออีกหนึ่งภาพระหว่างที่ภาพแรกยังเปิดอยู่', 500)$$,
  '23505', null, 'only one open request per buyer and artist');

-- ---------- append-only history ----------
insert into request_events (request_id, actor_id, actor_role, to_status)
  values ('f1000000-0000-4000-c000-000000000001', 'f1000000-0000-4000-a000-000000000001', 'buyer', 'submitted');
insert into reports (id, reporter_id, target_type, target_id, reason)
  values ('f1000000-0000-4000-d000-000000000001', 'f1000000-0000-4000-a000-000000000001', 'artwork',
          'f1000000-0000-4000-b000-000000000003', 'stolen_art');

select throws_ok($$insert into request_events (request_id, actor_id, actor_role, to_status)
  values ('f1000000-0000-4000-c000-000000000001', 'f1000000-0000-4000-a000-000000000001', 'system', 'expired')$$,
  '23514', null, 'a system event has no actor, and a person''s event always has one');
insert into admin_audit_log (admin_id, action, target_type, target_id)
  values ('f1000000-0000-4000-a000-000000000001', 'test', 'artwork', 'f1000000-0000-4000-b000-000000000002');

select throws_ok($$update request_events set note = 'edited'$$, '42501', null,
  'request history cannot be edited, even by the table owner');
select throws_ok($$truncate request_events$$, '42501', null, 'request history cannot be truncated');
select throws_ok($$update admin_audit_log set reason = 'edited'$$, '42501', null, 'audit log cannot be edited');
select throws_ok($$truncate admin_audit_log$$, '42501', null, 'audit log cannot be truncated');
select lives_ok($$update reports set status = 'actioned' where id = 'f1000000-0000-4000-d000-000000000001'$$,
  'a report''s status can change');
select throws_ok($$delete from reports where id = 'f1000000-0000-4000-d000-000000000001'$$, '42501', null,
  'a report (evidence) cannot be deleted');
select throws_ok($$truncate reports$$, '42501', null, 'reports cannot be truncated');

-- ---------- deletion keeps history and evidence (ADR 0002) ----------
select throws_ok($$delete from commission_requests where id = 'f1000000-0000-4000-c000-000000000001'$$,
  '23503', null, 'a request with history cannot be deleted');
select throws_ok($$delete from auth.users where id = 'f1000000-0000-4000-a000-000000000001'$$,
  '23503', null, 'deleting a login does not silently delete its profile; erasure anonymises instead');
select throws_ok($$delete from artist_profiles where user_id = 'f1000000-0000-4000-a000-000000000003'$$,
  '23503', null, 'an artist with artworks cannot be hard-deleted (evidence for reports survives)');
select lives_ok($$delete from artworks where id = 'f1000000-0000-4000-b000-000000000002'$$,
  'an admin can still purge an illegal artwork');
select is((select artwork_id from commission_requests where id = 'f1000000-0000-4000-c000-000000000001'), null,
  'purging an artwork keeps the request and clears only artwork_id');

select * from finish();
rollback;
