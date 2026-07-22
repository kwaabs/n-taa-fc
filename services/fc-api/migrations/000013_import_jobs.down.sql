DROP INDEX IF EXISTS idx_import_jobs_created_at;
DROP INDEX IF EXISTS idx_import_jobs_status;
DROP INDEX IF EXISTS idx_import_jobs_project_id;
DROP TABLE IF EXISTS import_jobs;

DROP INDEX IF EXISTS idx_project_connections_project_id;
DROP TABLE IF EXISTS project_connections;