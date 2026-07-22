-- Add source tracking columns to features
ALTER TABLE features
    ADD COLUMN source         VARCHAR(20) DEFAULT 'collected' 
        CHECK (source IN ('collected', 'reference')),
    ADD COLUMN source_ref     TEXT,
    ADD COLUMN data_source_id UUID,
    ADD COLUMN change_type    VARCHAR(20) 
        CHECK (change_type IS NULL OR change_type IN ('inserted', 'updated', 'deleted')),
    ADD COLUMN change_at      TIMESTAMPTZ,
    ADD COLUMN change_by      UUID REFERENCES user_profiles(id),
    ADD COLUMN original_attributes JSONB,
    ADD COLUMN original_geometry GEOMETRY(Geometry, 4326),
    ADD COLUMN deleted_at     TIMESTAMPTZ;

CREATE INDEX idx_features_source        ON features(source);
CREATE INDEX idx_features_change_type   ON features(change_type);
CREATE INDEX idx_features_data_source   ON features(data_source_id);
CREATE INDEX idx_features_source_ref    ON features(layer_id, source_ref);
CREATE INDEX idx_features_deleted_at    ON features(deleted_at);

-- Layer data sources
CREATE TABLE layer_data_sources (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    layer_id             UUID NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
    name                 TEXT NOT NULL,
    source_type          VARCHAR(20) NOT NULL 
        CHECK (source_type IN ('file', 'url', 'database')),
    config               JSONB NOT NULL DEFAULT '{}'::jsonb,
    encrypted_credentials TEXT,
    auto_refresh_minutes INTEGER DEFAULT 0,
    last_synced_at       TIMESTAMPTZ,
    last_sync_status     VARCHAR(20),
    last_sync_error      TEXT,
    last_sync_stats      JSONB,
    created_by           UUID REFERENCES user_profiles(id),
    created_at           TIMESTAMPTZ DEFAULT now(),
    updated_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_layer_data_sources_layer_id ON layer_data_sources(layer_id);

-- Add FK from features to data_sources
ALTER TABLE features
    ADD CONSTRAINT fk_features_data_source 
    FOREIGN KEY (data_source_id) REFERENCES layer_data_sources(id) ON DELETE SET NULL;