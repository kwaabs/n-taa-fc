CREATE TABLE forms (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    description TEXT,
    schema      JSONB NOT NULL,
    version     INTEGER DEFAULT 1,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_forms_project_id ON forms(project_id);

CREATE TABLE form_versions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    form_id      UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
    version      INTEGER NOT NULL,
    schema       JSONB NOT NULL,
    published_at TIMESTAMPTZ,
    is_draft     BOOLEAN DEFAULT true,
    changelog    TEXT,
    UNIQUE(form_id, version)
);

CREATE INDEX idx_form_versions_form_id ON form_versions(form_id);

CREATE TABLE choice_lists (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    choices    JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_choice_lists_project_id ON choice_lists(project_id);
