-- Local development seed only (`supabase db reset`). Never run against production.
-- Six personas used by manual testing. Log in locally with email OTP via the Inbucket/Mailpit UI.

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'buyer@artmatch.test',        now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-4000-a000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'artist@artmatch.test',       now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-4000-a000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'artist2@artmatch.test',      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-4000-a000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'unverified@artmatch.test',   now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-4000-a000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'admin@artmatch.test',        now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-4000-a000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'suspended@artmatch.test',    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (id, display_name, birth_date, terms_accepted_version, is_suspended) values
  ('00000000-0000-4000-a000-000000000001', 'ผู้ซื้อทดสอบ',          '1998-05-01', 'dev', false),
  ('00000000-0000-4000-a000-000000000002', 'ศิลปินทดสอบ',          '1996-01-15', 'dev', false),
  ('00000000-0000-4000-a000-000000000003', 'ศิลปินคนที่สอง',        '2000-09-09', 'dev', false),
  ('00000000-0000-4000-a000-000000000004', 'ศิลปินยังไม่ยืนยัน',     '2001-03-03', 'dev', false),
  ('00000000-0000-4000-a000-000000000005', 'แอดมิน',               '1990-12-12', 'dev', false),
  ('00000000-0000-4000-a000-000000000006', 'บัญชีถูกระงับ',          '1995-07-07', 'dev', true);

insert into public.admins (user_id) values ('00000000-0000-4000-a000-000000000005');

insert into public.artist_profiles (user_id, bio, queue_status, min_price_thb) values
  ('00000000-0000-4000-a000-000000000002', 'รับวาด OC และจิบิ', 'open',   500),
  ('00000000-0000-4000-a000-000000000003', 'สาย D&D แฟนตาซี',   'open',   1200),
  ('00000000-0000-4000-a000-000000000004', 'ยังไม่ได้ยืนยันเบอร์', 'open',   300),
  ('00000000-0000-4000-a000-000000000006', 'บัญชีถูกระงับ',       'closed', 800);

insert into public.artist_contacts (user_id, line_id, x_handle) values
  ('00000000-0000-4000-a000-000000000002', 'artist-line', '@artist'),
  ('00000000-0000-4000-a000-000000000003', null, '@artist2');

insert into public.artist_verifications (user_id, method, status, verified_at) values
  ('00000000-0000-4000-a000-000000000002', 'phone', 'verified', now()),
  ('00000000-0000-4000-a000-000000000003', 'phone', 'verified', now()),
  ('00000000-0000-4000-a000-000000000004', 'phone', 'pending',  null),
  ('00000000-0000-4000-a000-000000000006', 'phone', 'verified', now());
