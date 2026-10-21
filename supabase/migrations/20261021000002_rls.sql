-- Row Level Security and privileges.
-- Clients (anon, authenticated) can only read, and only what the policies below allow.
-- Every write goes through SECURITY DEFINER functions added feature by feature.

-- 1) Enable RLS on every public table and remove direct write privileges from clients.
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke insert, update, delete, truncate on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- Tables created by later migrations start without client write privileges too.
alter default privileges in schema public
  revoke insert, update, delete, truncate on tables from anon, authenticated;

-- Functions are not callable by clients unless a migration grants it explicitly.
-- Postgres grants EXECUTE to PUBLIC on every new function by a global default that a
-- schema-scoped revoke cannot remove. Changing the global default would also strip extension
-- functions, so instead EVERY migration that creates a function in public must
-- `revoke execute ... from public` itself. supabase/tests/00_privileges.test.sql fails if one forgets.
revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from anon, authenticated;

-- 2) profiles: public columns only. birth_date, consent and suspension are never exposed to clients.
revoke select on public.profiles from anon, authenticated;
grant select (id, display_name, avatar_path, created_at) on public.profiles to anon, authenticated;

-- 3) Helpers. SECURITY DEFINER with an empty search_path to prevent search_path hijacking.
create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins a where a.user_id = (select auth.uid()));
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- An artist's work is publicly visible only if they are not suspended and are verified (D3).
-- Definer rights let the policy check this without exposing suspension or verification rows.
create function public.artist_is_publishable(p_artist_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    join public.artist_verifications v on v.user_id = p.id
    where p.id = p_artist_id
      and not p.is_suspended
      and v.status = 'verified'
  );
$$;
revoke execute on function public.artist_is_publishable(uuid) from public;
grant execute on function public.artist_is_publishable(uuid) to anon, authenticated;

-- 4) Public reads
create policy profiles_read on public.profiles for select using (true);
create policy artist_profiles_read on public.artist_profiles for select using (true);
create policy categories_read on public.categories for select using (is_active);
create policy styles_read on public.styles for select using (is_active);

create policy artworks_public_read on public.artworks for select using (
  status = 'approved'
  and deleted_at is null
  and public.artist_is_publishable(artist_id)
);
create policy artworks_owner_read on public.artworks for select to authenticated
  using (artist_id = (select auth.uid()) and deleted_at is null);
create policy artworks_admin_read on public.artworks for select to authenticated
  using ((select public.is_admin()));

-- Inherits visibility from artworks (RLS applies inside the subquery).
create policy artwork_styles_read on public.artwork_styles for select using (
  exists (select 1 from public.artworks a where a.id = artwork_id)
);

-- 5) Verification: the artist themself and admins.
create policy artist_verifications_read on public.artist_verifications for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- 6) Contacts (D2): owner, a buyer whose request the artist has quoted, admins.
create policy artist_contacts_read on public.artist_contacts for select to authenticated using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.commission_requests r
    where r.artist_id = artist_contacts.user_id
      and r.buyer_id = (select auth.uid())
      and r.status in ('quoted', 'confirmed', 'delivered', 'completed')
  )
  or (select public.is_admin())
);

-- 7) Personal activity: owner only.
create policy saved_artworks_own on public.saved_artworks for select to authenticated
  using (user_id = (select auth.uid()));
create policy swipe_events_own on public.swipe_events for select to authenticated
  using (user_id = (select auth.uid()));
create policy experiment_assignments_own on public.experiment_assignments for select to authenticated
  using (user_id = (select auth.uid()));
-- feed_impressions, analytics_events, admins: no select policy, so no client can read them.

-- 8) Commissions: the two parties and admins (read-only).
create policy commission_requests_parties on public.commission_requests for select to authenticated
  using (
    buyer_id = (select auth.uid())
    or artist_id = (select auth.uid())
    or (select public.is_admin())
  );
create policy request_events_parties on public.request_events for select to authenticated
  using (exists (select 1 from public.commission_requests r where r.id = request_id));

-- 9) Reports and audit log
create policy reports_own_or_admin on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or (select public.is_admin()));
create policy admin_audit_log_admin on public.admin_audit_log for select to authenticated
  using ((select public.is_admin()));
