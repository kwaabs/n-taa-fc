CREATE TABLE feature_attachments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_id  UUID REFERENCES features(id) ON DELETE CASCADE,
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    client_id   UUID NOT NULL UNIQUE,
    field_id    TEXT NOT NULL,
    kind        VARCHAR(20) NOT NULL CHECK (kind IN ('photo','audio','video','signature','barcode_image','file')),
    storage_key TEXT NOT NULL,
    thumb_key   TEXT,
    mime_type   TEXT,
    size_bytes  BIGINT,
    width       INTEGER,
    height      INTEGER,
    duration_ms INTEGER,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending_upload'
                CHECK (status IN ('pending_upload','uploaded','failed')),
    metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
    uploaded_by UUID REFERENCES user_profiles(id),
    uploaded_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_feature_attachments_feature_id ON feature_attachments(feature_id);
CREATE INDEX idx_feature_attachments_project_id ON feature_attachments(project_id);
CREATE INDEX idx_feature_attachments_field_id   ON feature_attachments(field_id);
CREATE INDEX idx_feature_attachments_status     ON feature_attachments(status);