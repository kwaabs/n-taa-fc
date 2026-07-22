CREATE TABLE layers (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id            UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name                  TEXT NOT NULL,
    geometry_type         VARCHAR(20) NOT NULL,
    form_id               UUID REFERENCES forms(id),
    style                 JSONB DEFAULT '{}'::jsonb,
    is_editable           BOOLEAN DEFAULT false,
    is_visible_by_default BOOLEAN DEFAULT true,
    sort_order            INTEGER DEFAULT 0,
    source_type           VARCHAR(20) DEFAULT 'collection',
    source_config         JSONB,
    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_layers_project_id ON layers(project_id);
CREATE INDEX idx_layers_form_id    ON layers(form_id);
