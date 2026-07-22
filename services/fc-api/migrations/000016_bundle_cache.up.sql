CREATE TABLE bundle_cache (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id             UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id                UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    include_reference_data BOOLEAN NOT NULL,
    content_hash           TEXT NOT NULL,
    storage_key            TEXT NOT NULL,
    filename               TEXT NOT NULL,
    size_bytes             BIGINT NOT NULL DEFAULT 0,
    counts                 JSONB NOT NULL DEFAULT '{}'::jsonb,
    warnings               JSONB,
    generated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    accessed_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, user_id, include_reference_data, content_hash)
);

CREATE INDEX idx_bundle_cache_project_user
    ON bundle_cache(project_id, user_id, include_reference_data);

CREATE INDEX idx_bundle_cache_accessed
    ON bundle_cache(accessed_at);