-- Allow geo-api to sync supervisor role into FC user_profiles.
GRANT SELECT (id, email, full_name, role, is_system_admin) ON public.user_profiles TO geo_app;
GRANT INSERT, UPDATE (id, email, full_name, role, updated_at) ON public.user_profiles TO geo_app;

-- Include supervisor in layer permission defaults for new/existing layers.
ALTER TABLE app.layers
  ALTER COLUMN permissions SET DEFAULT
    '{"view_roles": ["superuser", "supervisor", "editor", "viewer"], "export_roles": ["superuser", "supervisor", "editor", "viewer"]}'::jsonb;

UPDATE app.layers
SET permissions = jsonb_set(
  jsonb_set(
    permissions,
    '{view_roles}',
    (
      SELECT COALESCE(jsonb_agg(DISTINCT v), '[]'::jsonb)
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(permissions->'view_roles', '[]'::jsonb)) AS v
        UNION ALL
        SELECT 'supervisor'
      ) s
    )
  ),
  '{export_roles}',
  (
    SELECT COALESCE(jsonb_agg(DISTINCT v), '[]'::jsonb)
    FROM (
      SELECT jsonb_array_elements_text(COALESCE(permissions->'export_roles', '[]'::jsonb)) AS v
      UNION ALL
      SELECT 'supervisor'
    ) s
  )
)
WHERE NOT (COALESCE(permissions->'view_roles', '[]'::jsonb) ? 'supervisor')
   OR NOT (COALESCE(permissions->'export_roles', '[]'::jsonb) ? 'supervisor');

-- Backfill: FC supervisors become active geo supervisors (not pending).
UPDATE app.users AS u
SET
  role = 'supervisor',
  pending = false,
  status = CASE WHEN u.status = 'disabled' THEN u.status ELSE 'active' END,
  updated_at = now()
FROM public.user_profiles AS p
WHERE (u.id = p.id OR lower(u.email) = lower(p.email))
  AND p.role = 'supervisor'
  AND COALESCE(p.is_system_admin, false) = false
  AND u.role NOT IN ('superuser');
