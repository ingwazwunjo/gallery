-- Data integrity rules enforced by the database itself (they hold even for server-side code).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

insert into auth.users (id, email) values
  ('f1000000-0000-4000-a000-000000000001', 'c1@t.test'),
  ('f1000000-0000-4000-a000-000000000002', 'c2@t.test');
insert into profiles (id, display_name, birth_date, terms_accepted_version) values
  ('f1000000-0000-4000-a000-000000000001', 'c1', '1990-01-01', 't'),
  ('f1000000-0000-4000-a000-000000000002', 'c2', '1990-01-01', 't');
insert into artist_profiles (user_id) values ('f1000000-0000-4000-a000-000000000002');

select throws_ok($$insert into artworks (artist_id, title, category_slug, price_from_thb, status, original_path)
  values ('f1000000-0000-4000-a000-000000000002', 't', 'oc', 500, 'approved', 'o/x')$$,
  '23514', null, 'an approved artwork must have a display image and publish time');

select throws_ok($$insert into artworks (artist_id, title, category_slug, price_from_thb, original_path)
  values ('f1000000-0000-4000-a000-000000000002', 't', 'oc', 0, 'o/y')$$,
  '23514', null, 'price must be at least 1 THB');

select throws_ok($$insert into artist_contacts (user_id) values ('f1000000-0000-4000-a000-000000000002')$$,
  '23514', null, 'a contact row needs at least one handle');

select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-a000-000000000002', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขอภาพตัวเองหนึ่งภาพสวย ๆ ครับ', 500)$$,
  '23514', null, 'an artist cannot commission themself');

select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb, status)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขอภาพตัวละคร OC ครึ่งตัวหนึ่งภาพ', 500, 'confirmed')$$,
  '23514', null, 'a confirmed request must record the agreed price');

select lives_ok($$insert into commission_requests (id, buyer_id, artist_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-c000-000000000001', 'f1000000-0000-4000-a000-000000000001',
          'f1000000-0000-4000-a000-000000000002', 'oc', 'ขอภาพตัวละคร OC ครึ่งตัวหนึ่งภาพ', 500)$$,
  'a valid request is accepted');

select throws_ok($$insert into commission_requests (buyer_id, artist_id, category_slug, description, buyer_budget_thb)
  values ('f1000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000002', 'oc',
          'ขออีกหนึ่งภาพระหว่างที่ภาพแรกยังเปิดอยู่', 500)$$,
  '23505', null, 'only one open request per buyer and artist');

insert into request_events (request_id, actor_id, to_status)
  values ('f1000000-0000-4000-c000-000000000001', 'f1000000-0000-4000-a000-000000000001', 'submitted');

select throws_ok($$update request_events set note = 'edited' where request_id = 'f1000000-0000-4000-c000-000000000001'$$,
  '42501', null, 'request history cannot be edited, even by the table owner');

select throws_ok($$delete from request_events where request_id = 'f1000000-0000-4000-c000-000000000001'$$,
  '42501', null, 'request history cannot be deleted');

select throws_ok($$insert into artist_verifications (user_id, method, status)
  values ('f1000000-0000-4000-a000-000000000002', 'phone', 'verified')$$,
  '23514', null, 'a verified artist must have a verification time');

select * from finish();
rollback;
