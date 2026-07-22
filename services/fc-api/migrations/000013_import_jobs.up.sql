-- Project-level reusable connection profiles
CREATE TABLE project_connections (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    driver      VARCHAR(20) NOT NULL DEFAULT 'postgres' CHECK (driver IN ('postgres')),
    host        TEXT NOT NULL,
    port        INTEGER NOT NULL DEFAULT 5432,
    database    TEXT NOT NULL,
    username    TEXT NOT NULL,
    encrypted_password TEXT,
    ssl_mode    VARCHAR(20) DEFAULT 'disable',
    created_by  UUID REFERENCES user_profiles(id),
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE (project_id, name)
);

CREATE INDEX idx_project_connections_project_id ON project_connections(project_id);

-- Background import jobs
CREATE TABLE import_jobs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    connection_id UUID REFERENCES project_connections(id) ON DELETE SET NULL,
    job_type      VARCHAR(30) NOT NULL,             -- 'bulk_database_import', 'geopackage_import', etc.
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'running', 'success', 'partial', 'failed')),
    config        JSONB NOT NULL DEFAULT '{}'::jsonb,
    progress      JSONB DEFAULT '{}'::jsonb,        -- {current, total, message, per_table: {...}}
    result        JSONB,                              -- {layers_created, forms_created, features_imported, errors}
    error_message TEXT,
    created_by    UUID REFERENCES user_profiles(id),
    started_at    TIMESTAMPTZ,
    finished_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_import_jobs_project_id ON import_jobs(project_id);
CREATE INDEX idx_import_jobs_status     ON import_jobs(status);
CREATE INDEX idx_import_jobs_created_at ON import_jobs(created_at DESC);