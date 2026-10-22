-- Row Level Security, column grants and privileges.
-- Model (docs/adr/0001-database-access.md):
--   * Clients (anon, authenticated) start with NO privileges on anything in public.
--   * Each table they may read gets an explicit SELECT grant, on the columns they may see,
--     and an RLS policy choosing the rows. Writes go through SECURITY DEFINER functions.
--   * Helper functions used by policies live in schema `private`, which the API does not expose,
--     so they cannot be called as RPC endpoints.

-- ===== 1) Start from zero =====
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- Objects created later by migrations start with no client privileges either.
-- Postgres also grants EXECUTE on new functions to PUBLIC through a global default that a
-- schema-scoped revoke cannot remove, so every migration that creates a function must
-- `revoke execute ... from public` itself. supabase/tests/00_privileges.test.sql enforces this.
alter default privileges in schema public revoke all on tables from public, anon, authenticated;
alter default privileges in schema public revoke all on sequences from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ===== 2) Private helpers (not exposed through the API) =====
create schema private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins a where a.user_id = (select auth.uid()));
$$;
revoke execute on function private.is_admin() from public;
grant execute on function private.is_admin() to authenticated;

-- A user's work and profile are public only if they are verified (D3), not suspended, not erased.
create function private.artist_is_publishable(p_artist_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    join public.artist_verifications v on v.user_id = p.id
    where p.id = p_artist_id
      and not p.is_suspended
      and p.deleted_at is null
      and v.status = 'verified'
  );
$$;
revoke execute on function private.artist_is_publishable(uuid) from public;
grant execute on function private.artist_is_publishable(uuid) to anon, authenticated;

-- ===== 3) Reference data =====
grant select on public.categories, public.styles to anon, authenticated;
create policy categories_read on public.categories for select using (is_active);
create policy styles_read on public.styles for select using (is_active);

-- ===== 4) Profiles =====
-- Never exposed: birth_date, terms acceptance, is_suspended, deleted_at.
grant select (id, display_name, avatar_path, created_at) on public.profiles to anon, authenticated;

-- Everyone: profiles of publishable artists only (no list of buyers or admins, PDPA minimisation).
create policy profiles_public on public.profiles for select
  using (private.artist_is_publishable(id));
-- Signed in: yourself, the other party of your own requests, and everyone for admins.
create policy profiles_related on public.profiles for select to authenticated using (
  id = (select auth.uid())
  or exists (
    select 1 from public.commission_requests r      -- RLS limits this to the caller's requests
    where r.buyer_id = profiles.id or r.artist_id = profiles.id
  )
  or (select private.is_admin())
);

-- ===== 5) Artist profiles, contacts, verification =====
grant select on public.artist_profiles to anon, authenticated;
create policy artist_profiles_public on public.artist_profiles for select
  using (private.artist_is_publishable(user_id));
create policy artist_profiles_owner_or_admin on public.artist_profiles for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));

-- D2: owner, a buyer whose request the artist has quoted (still shown if the artist is later
-- suspended, so the buyer can follow up on paid work), and admins.
grant select on public.artist_contacts to authenticated;
create policy artist_contacts_read on public.artist_contacts for select to authenticated using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.commission_requests r
    where r.artist_id = artist_contacts.user_id
      and r.buyer_id = (select auth.uid())
      and r.status in ('quoted', 'confirmed', 'delivered', 'completed')
  )
  or (select private.is_admin())
);

-- provider_ref and reviewed_by stay server-side.
grant select (user_id, method, status, verified_at, created_at, updated_at)
  on public.artist_verifications to authenticated;
create policy artist_verifications_read on public.artist_verifications for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));

-- ===== 6) Artworks =====
-- Not exposed: original_path (private original), reviewed_by / reviewed_at (admin identity),
-- rejection_reason, impressions_count, deleted_at. Owners and admins get those through
-- server-side functions added with the features that need them.
grant select (id, artist_id, title, category_slug, price_from_thb, is_fan_art, status,
              display_path, width, height, published_at, created_at, updated_at)
  on public.artworks to anon, authenticated;

create policy artworks_public_read on public.artworks for select using (
  status = 'approved'
  and deleted_at is null
  and private.artist_is_publishable(artist_id)
);
create policy artworks_owner_read on public.artworks for select to authenticated
  using (artist_id = (select auth.uid()) and deleted_at is null);
create policy artworks_admin_read on public.artworks for select to authenticated
  using ((select private.is_admin()));

grant select on public.artwork_styles to anon, authenticated;
create policy artwork_styles_read on public.artwork_styles for select using (
  exists (select 1 from public.artworks a where a.id = artwork_id) -- inherits artworks RLS
);

-- ===== 7) Personal activity: owner only =====
grant select on public.saved_artworks, public.swipe_events, public.experiment_assignments
  to authenticated;
create policy saved_artworks_own on public.saved_artworks for select to authenticated
  using (user_id = (select auth.uid()));
create policy swipe_events_own on public.swipe_events for select to authenticated
  using (user_id = (select auth.uid()));
create policy experiment_assignments_own on public.experiment_assignments for select to authenticated
  using (user_id = (select auth.uid()));
-- feed_impressions, analytics_events, admins: no grant at all.

-- ===== 8) Commissions: the two parties, and admins (read-only) =====
grant select on public.commission_requests, public.request_events to authenticated;
create policy commission_requests_parties on public.commission_requests for select to authenticated
  using (
    buyer_id = (select auth.uid())
    or artist_id = (select auth.uid())
    or (select private.is_admin())
  );
create policy request_events_parties on public.request_events for select to authenticated
  using (exists (select 1 from public.commission_requests r where r.id = request_id));

-- ===== 9) Reports and audit log =====
-- resolved_by (admin identity) stays server-side.
grant select (id, reporter_id, target_type, target_id, reason, details, status, resolved_at, created_at)
  on public.reports to authenticated;
create policy reports_own_or_admin on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or (select private.is_admin()));

grant select on public.admin_audit_log to authenticated;
create policy admin_audit_log_admin on public.admin_audit_log for select to authenticated
  using ((select private.is_admin()));
