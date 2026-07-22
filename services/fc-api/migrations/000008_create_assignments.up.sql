CREATE TABLE assignments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id   UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    assigned_to  UUID NOT NULL REFERENCES user_profiles(id),
    assigned_by  UUID NOT NULL REFERENCES user_profiles(id),
    area         GEOMETRY(Polygon, 4326),
    form_id      UUID REFERENCES forms(id),
    target_count INTEGER,
    instructions TEXT,
    due_date     DATE,
    status       VARCHAR(20) DEFAULT 'pending',
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_assignments_project_id  ON assignments(project_id);
CREATE INDEX idx_assignments_assigned_to ON assignments(assigned_to);
CREATE INDEX idx_assignments_status      ON assignments(status);
