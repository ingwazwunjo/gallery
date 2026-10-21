-- Reference data needed in every environment (not just local seed).
-- Categories and price-band defaults follow recommendation D11; adjust before beta if needed.

insert into public.categories (slug, name_th, sort) values
  ('oc',               'OC (ตัวละครออริจินัล)', 10),
  ('fan-art',          'แฟนอาร์ต',             20),
  ('dnd-trpg',         'D&D / TRPG',           30),
  ('chibi',            'จิบิ',                  40),
  ('character-design', 'ออกแบบตัวละคร',        50),
  ('vtuber',           'VTuber Model Art',     60);

insert into public.styles (slug, name_th, sort) values
  ('anime',        'อนิเมะ / มังงะ',    10),
  ('semi-real',    'กึ่งเหมือนจริง',    20),
  ('realistic',    'เหมือนจริง',        30),
  ('cartoon',      'การ์ตูน',           40),
  ('painterly',    'ลายพู่กัน / เพนต์', 50),
  ('pixel',        'พิกเซล',           60),
  ('line-art',     'ลายเส้น',          70);
