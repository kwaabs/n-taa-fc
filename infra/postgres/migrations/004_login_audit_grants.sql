-- Let geo_app read GoTrue's own login audit trail (read-only; geo_app
-- never writes to the auth schema — that's GoTrue's).
--
-- GoTrue manages the auth schema itself and only creates its tables on its
-- own first boot, which can happen AFTER this migration runs on a brand
-- new deploy (geo-migrate has no dependency on gotrue). Guard the table
-- grant so a fresh install doesn't fail here — a later deploy, once GoTrue
-- has started at least once, will pick the grant up.
GRANT USAGE ON SCHEMA auth TO geo_app;

DO $$
BEGIN
  IF to_regclass('auth.audit_log_entries') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON auth.audit_log_entries TO geo_app';
  END IF;
END
$$;
