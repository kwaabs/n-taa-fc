-- Let geo-api (geo_app) read FC platform admins so GoTrue login can
-- elevate them to app.users superuser without pending approval.
GRANT USAGE ON SCHEMA public TO geo_app;
GRANT SELECT (id, email, is_system_admin, role) ON public.user_profiles TO geo_app;

-- Backfill: any existing geo user who is already an FC system admin.
UPDATE app.users AS u
SET
  role = 'superuser',
  pending = false,
  status = CASE WHEN u.status = 'disabled' THEN u.status ELSE 'active' END,
  updated_at = now()
FROM public.user_profiles AS p
WHERE (u.id = p.id OR lower(u.email) = lower(p.email))
  AND p.is_system_admin = true;
