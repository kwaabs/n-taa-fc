-- Reverse 000024: strip supervisor from layer permissions and revoke UPDATE.

UPDATE app.layers
SET permissions = jsonb_set(
  jsonb_set(
    permissions,
    '{view_roles}',
    (
      SELECT COALESCE(jsonb_agg(v), '[]'::jsonb)
      FROM jsonb_array_elements_text(COALESCE(permissions->'view_roles', '[]'::jsonb)) AS t(v)
      WHERE v <> 'supervisor'
    )
  ),
  '{export_roles}',
  (
    SELECT COALESCE(jsonb_agg(v), '[]'::jsonb)
    FROM jsonb_array_elements_text(COALESCE(permissions->'export_roles', '[]'::jsonb)) AS t(v)
    WHERE v <> 'supervisor'
  )
);

ALTER TABLE app.layers
  ALTER COLUMN permissions SET DEFAULT
    '{"view_roles": ["superuser", "editor", "viewer"], "export_roles": ["superuser", "editor", "viewer"]}'::jsonb;

REVOKE INSERT, UPDATE ON public.user_profiles FROM geo_app;
-- Keep SELECT from 000023; only drop the extra columns if needed — leave SELECT intact.
