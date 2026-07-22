CREATE TABLE sync_conflicts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_id      UUID REFERENCES features(id) ON DELETE SET NULL,
    client_version  JSONB,
    server_version  JSONB,
    resolved_by     VARCHAR(20),
    resolved_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_sync_conflicts_feature_id ON sync_conflicts(feature_id);

CREATE TABLE sync_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES user_profiles(id),
    project_id      UUID REFERENCES projects(id),
    direction       VARCHAR(10) NOT NULL CHECK (direction IN ('push', 'pull')),
    features_count  INTEGER DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'started',
    started_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    error_message   TEXT
);

CREATE INDEX idx_sync_log_user_id    ON sync_log(user_id);
CREATE INDEX idx_sync_log_project_id ON sync_log(project_id);
