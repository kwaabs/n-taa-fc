CREATE TABLE features (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id     UUID NOT NULL UNIQUE,
    project_id    UUID NOT NULL REFERENCES projects(id),
    layer_id      UUID REFERENCES layers(id),
    form_id       UUID NOT NULL REFERENCES forms(id),
    form_version  INTEGER,
    geometry      GEOMETRY(Geometry, 4326),
    attributes    JSONB NOT NULL DEFAULT '{}'::jsonb,
    status        VARCHAR(20) DEFAULT 'draft',
    collected_by  UUID REFERENCES user_profiles(id),
    collected_at  TIMESTAMPTZ NOT NULL,
    device_info   JSONB,
    gps_metadata  JSONB,
    synced_at     TIMESTAMPTZ,
    reviewed_by   UUID REFERENCES user_profiles(id),
    reviewed_at   TIMESTAMPTZ,
    review_notes  TEXT,
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now()
);

-- Spatial index
CREATE INDEX idx_features_geo         ON features USING GIST(geometry);

-- JSONB index for attribute queries
CREATE INDEX idx_features_attrs       ON features USING GIN(attributes);

-- B-tree indexes for common lookups
CREATE INDEX idx_features_project_id  ON features(project_id);
CREATE INDEX idx_features_layer_id    ON features(layer_id);
CREATE INDEX idx_features_form_id     ON features(form_id);
CREATE INDEX idx_features_status      ON features(status);
CREATE INDEX idx_features_synced_at   ON features(synced_at);
CREATE INDEX idx_features_collected_by ON features(collected_by);
CREATE INDEX idx_features_client_id   ON features(client_id);
