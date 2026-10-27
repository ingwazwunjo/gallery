-- ArtMatch core schema.
-- Rules this schema relies on (see docs/adr/0001-database-access.md and 0002-account-erasure.md):
--   * Clients may only SELECT (filtered by RLS and column grants). Every write goes through a
--     Route Handler that calls a SECURITY DEFINER function, so business rules live in one place.
--   * Accounts are erased by anonymisation, never by deleting rows that history depends on.
--   * Money is integer THB, columns end in _thb.
--   * No national ID numbers or ID card images are ever stored (decision D3).

-- ===== Enums =====
create type public.queue_status as enum ('open', 'closed');
create type public.artwork_status as enum ('pending_review', 'approved', 'rejected', 'removed');
create type public.request_status as enum (
  'submitted', 'quoted', 'declined', 'confirmed', 'delivered', 'completed', 'cancelled', 'expired'
);
create type public.swipe_action as enum ('pass', 'like');
create type public.report_target as enum ('artwork', 'user', 'request');
create type public.report_status as enum ('open', 'actioned', 'dismissed');
-- Only phone (SMS OTP) for the MVP. Add a value when an eKYC provider is chosen.
create type public.verification_method as enum ('phone');
create type public.verification_status as enum ('pending', 'verified', 'rejected', 'revoked');

-- ===== Shared trigger functions =====
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create function public.forbid_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception '% is append-only', tg_table_name using errcode = '42501';
end $$;

-- ===== Identity =====
-- No ON DELETE CASCADE from auth.users: deleting a login must go through the erasure flow
-- (ADR 0002), which anonymises this row instead of removing it.
create table public.profiles (
  id                     uuid primary key references auth.users (id),
  display_name           text not null check (char_length(btrim(display_name)) between 1 and 50),
  avatar_path            text,
  -- D1: 18+ only. Age is checked in the onboarding function, not with a CHECK on current_date.
  birth_date             date,
  terms_accepted_version text not null,
  terms_accepted_at      timestamptz not null default now(),
  is_suspended           boolean not null default false,
  deleted_at             timestamptz, -- set when the account is anonymised
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  check (deleted_at is not null or birth_date is not null),
  check (deleted_at is null or (birth_date is null and avatar_path is null))
);

-- Admins are granted only through a reviewed migration or SQL by the project owner.
create table public.admins (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.artist_profiles (
  user_id       uuid primary key references public.profiles (id),
  bio           text check (char_length(bio) <= 1000),
  queue_status  public.queue_status not null default 'closed',
  min_price_thb integer check (min_price_thb between 1 and 1000000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- D2: shown to a buyer only after the artist has quoted their request.
create table public.artist_contacts (
  user_id    uuid primary key references public.artist_profiles (user_id) on delete cascade,
  line_id    text check (char_length(line_id) <= 50),
  x_handle   text check (char_length(x_handle) <= 50),
  discord    text check (char_length(discord) <= 50),
  updated_at timestamptz not null default now(),
  check (coalesce(line_id, x_handle, discord) is not null)
);

-- D3: an artist must be verified before their work can be published.
-- MVP verifies by SMS OTP; the phone number itself lives in auth.users.phone (unique there).
create table public.artist_verifications (
  user_id      uuid primary key references public.artist_profiles (user_id) on delete cascade,
  method       public.verification_method not null,
  status       public.verification_status not null default 'pending',
  -- Opaque reference from a verification provider. Must never hold a national ID number, in any
  -- common spelling: 13 digits, optionally separated by spaces, dots or dashes.
  provider_ref text check (char_length(provider_ref) <= 200 and provider_ref !~ '[0-9]([ .-]?[0-9]){12}'),
  verified_at  timestamptz,
  reviewed_by  uuid references public.profiles (id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (status <> 'verified' or verified_at is not null)
);

-- ===== Taxonomy (reference data, managed by admins) =====
create table public.categories (
  slug      text primary key check (slug ~ '^[a-z0-9-]{2,40}$'),
  name_th   text not null,
  sort      integer not null default 0,
  is_active boolean not null default true
);

create table public.styles (
  slug      text primary key check (slug ~ '^[a-z0-9-]{2,40}$'),
  name_th   text not null,
  sort      integer not null default 0,
  is_active boolean not null default true
);

-- ===== Artworks =====
-- Normally soft-deleted (deleted_at). A hard delete is reserved for illegal content an admin must
-- purge; it is blocked while the artist still exists only through artist_id (no cascade from artists).
create table public.artworks (
  id                uuid primary key default gen_random_uuid(),
  artist_id         uuid not null references public.artist_profiles (user_id),
  title             text not null check (char_length(btrim(title)) between 1 and 100),
  category_slug     text not null references public.categories (slug),
  price_from_thb    integer not null check (price_from_thb between 1 and 1000000),
  is_fan_art        boolean not null default false,
  status            public.artwork_status not null default 'pending_review',
  original_path     text not null unique, -- private bucket 'originals'
  display_path      text unique,          -- public bucket 'display', re-encoded, no EXIF
  width             integer check (width > 0),
  height            integer check (height > 0),
  rejection_reason  text check (char_length(rejection_reason) <= 500),
  reviewed_by       uuid references public.profiles (id),
  reviewed_at       timestamptz,
  published_at      timestamptz,
  impressions_count integer not null default 0 check (impressions_count >= 0),
  deleted_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint approved_needs_display
    check (status <> 'approved' or (display_path is not null and published_at is not null)),
  -- Lets commission_requests prove its artwork belongs to its artist.
  constraint artworks_id_artist_key unique (id, artist_id)
);
create index artworks_feed_idx on public.artworks (category_slug, price_from_thb)
  where status = 'approved' and deleted_at is null;
create index artworks_artist_idx on public.artworks (artist_id);
create index artworks_review_idx on public.artworks (created_at) where status = 'pending_review';

create table public.artwork_styles (
  artwork_id uuid not null references public.artworks (id) on delete cascade,
  style_slug text not null references public.styles (slug),
  primary key (artwork_id, style_slug)
);

-- ===== Discovery & analytics =====
create table public.experiment_assignments (
  user_id     uuid not null references public.profiles (id),
  experiment  text not null,
  variant     text not null check (variant in ('swipe', 'gallery')),
  assigned_at timestamptz not null default now(),
  primary key (user_id, experiment)
);

create table public.feed_impressions (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references public.profiles (id),
  artwork_id      uuid not null references public.artworks (id) on delete cascade,
  feed_session_id uuid not null,
  variant         text not null check (variant in ('swipe', 'gallery')),
  position        integer not null check (position >= 0),
  created_at      timestamptz not null default now(),
  unique (user_id, artwork_id, feed_session_id)
);
create index feed_impressions_artwork_idx on public.feed_impressions (artwork_id, created_at);

create table public.swipe_events (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references public.profiles (id),
  artwork_id      uuid not null references public.artworks (id) on delete cascade,
  feed_session_id uuid not null,
  action          public.swipe_action not null,
  created_at      timestamptz not null default now(),
  unique (user_id, artwork_id, feed_session_id)
);
create index swipe_events_user_idx on public.swipe_events (user_id, created_at desc);

create table public.saved_artworks (
  user_id    uuid not null references public.profiles (id),
  artwork_id uuid not null references public.artworks (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artwork_id)
);

create table public.analytics_events (
  id         bigint generated always as identity primary key,
  user_id    uuid references public.profiles (id),
  name       text not null check (name in (
               'artist_profile_view', 'artwork_detail_view', 'request_form_open', 'filter_change')),
  props      jsonb not null default '{}' check (pg_column_size(props) < 2048),
  created_at timestamptz not null default now()
);
create index analytics_events_name_idx on public.analytics_events (name, created_at);

-- ===== Commissions =====
create table public.commission_requests (
  id                      uuid primary key default gen_random_uuid(),
  buyer_id                uuid not null references public.profiles (id),
  artist_id               uuid not null references public.artist_profiles (user_id),
  artwork_id              uuid,
  category_slug           text not null references public.categories (slug),
  description             text not null check (char_length(btrim(description)) between 20 and 4000),
  buyer_budget_thb        integer not null check (buyer_budget_thb between 1 and 1000000),
  price_from_snapshot_thb integer check (price_from_snapshot_thb between 1 and 1000000),
  quoted_price_thb        integer check (quoted_price_thb between 1 and 1000000),
  agreed_price_thb        integer check (agreed_price_thb between 1 and 1000000),
  commercial_use          boolean not null default false,
  status                  public.request_status not null default 'submitted',
  version                 integer not null default 1 check (version >= 1),
  status_changed_at       timestamptz not null default now(),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  -- The artwork that inspired the request must belong to the artist being asked.
  -- If an admin purges that artwork, only artwork_id is cleared (PG 15+ column list).
  constraint commission_requests_artwork_fk foreign key (artwork_id, artist_id)
    references public.artworks (id, artist_id) on delete set null (artwork_id),
  check (buyer_id <> artist_id),
  check (status <> 'quoted' or quoted_price_thb is not null),
  check (status not in ('confirmed', 'delivered', 'completed')
         or (quoted_price_thb is not null and agreed_price_thb is not null)),
  check (status_changed_at >= created_at)
);
-- Anti-spam: one open request per buyer-artist pair.
create unique index one_open_request_per_pair on public.commission_requests (buyer_id, artist_id)
  where status in ('submitted', 'quoted');
create index requests_artist_idx on public.commission_requests (artist_id, status, created_at desc);
create index requests_buyer_idx on public.commission_requests (buyer_id, status, created_at desc);

-- Append-only history of every status change. Requests with history can never be deleted.
create table public.request_events (
  id          bigint generated always as identity primary key,
  request_id  uuid not null references public.commission_requests (id),
  actor_id    uuid references public.profiles (id), -- null = system; never shown to clients
  -- What the parties see instead of actor_id, so an admin's identity is never revealed.
  actor_role  text not null check (actor_role in ('buyer', 'artist', 'admin', 'system')),
  from_status public.request_status,
  to_status   public.request_status not null,
  note        text check (char_length(note) <= 1000),
  created_at  timestamptz not null default now(),
  check ((actor_role = 'system') = (actor_id is null))
);
create index request_events_req_idx on public.request_events (request_id, created_at);

-- ===== Trust & safety =====
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id),
  target_type public.report_target not null,
  target_id   uuid not null, -- polymorphic: existence is checked by the submit function
  reason      text not null check (reason in (
                'copyright', 'stolen_art', 'ai_undisclosed', 'nsfw', 'harassment', 'scam', 'other')),
  details     text check (char_length(details) <= 2000),
  status      public.report_status not null default 'open',
  resolved_by uuid references public.profiles (id),
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);
create unique index one_open_report_per_target on public.reports (reporter_id, target_type, target_id)
  where status = 'open';
create index reports_open_idx on public.reports (created_at) where status = 'open';

-- Append-only log of every admin action.
create table public.admin_audit_log (
  id          bigint generated always as identity primary key,
  admin_id    uuid not null references public.profiles (id),
  action      text not null,
  target_type text not null,
  target_id   uuid not null,
  reason      text,
  before      jsonb,
  after       jsonb,
  created_at  timestamptz not null default now()
);

-- ===== updated_at triggers =====
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger artist_profiles_updated_at before update on public.artist_profiles
  for each row execute function public.set_updated_at();
create trigger artist_contacts_updated_at before update on public.artist_contacts
  for each row execute function public.set_updated_at();
create trigger artist_verifications_updated_at before update on public.artist_verifications
  for each row execute function public.set_updated_at();
create trigger artworks_updated_at before update on public.artworks
  for each row execute function public.set_updated_at();
create trigger commission_requests_updated_at before update on public.commission_requests
  for each row execute function public.set_updated_at();

-- ===== Append-only enforcement =====
-- Row triggers stop UPDATE/DELETE; statement triggers stop TRUNCATE (row triggers do not fire on it).
-- They apply to every role, including the service role and the table owner.
create trigger request_events_append_only before update or delete on public.request_events
  for each row execute function public.forbid_mutation();
create trigger request_events_no_truncate before truncate on public.request_events
  for each statement execute function public.forbid_mutation();
create trigger admin_audit_log_append_only before update or delete on public.admin_audit_log
  for each row execute function public.forbid_mutation();
create trigger admin_audit_log_no_truncate before truncate on public.admin_audit_log
  for each statement execute function public.forbid_mutation();

-- Reports are evidence (ADR 0002): their status can change, but they can never be removed.
create function public.forbid_delete() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'rows in % cannot be deleted', tg_table_name using errcode = '42501';
end $$;

create trigger reports_no_delete before delete on public.reports
  for each row execute function public.forbid_delete();
create trigger reports_no_truncate before truncate on public.reports
  for each statement execute function public.forbid_delete();
