ALTER TABLE layers
    ADD COLUMN status        VARCHAR(20) NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft', 'published', 'archived')),
    ADD COLUMN published_at  TIMESTAMPTZ,
    ADD COLUMN published_by  UUID REFERENCES user_profiles(id);

CREATE INDEX idx_layers_status ON layers(status);

-- Existing layers default to published so they stay visible without manual action
UPDATE layers SET status = 'published', published_at = now();