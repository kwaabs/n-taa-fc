CREATE TABLE attachments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_id      UUID NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    client_id       UUID NOT NULL UNIQUE,
    field_name      TEXT,
    file_type       VARCHAR(20),
    file_name       TEXT,
    mime_type       TEXT,
    file_size_bytes BIGINT,
    storage_path    TEXT,
    thumbnail_path  TEXT,
    exif_data       JSONB,
    uploaded_at     TIMESTAMPTZ
);

CREATE INDEX idx_attachments_feature_id ON attachments(feature_id);
