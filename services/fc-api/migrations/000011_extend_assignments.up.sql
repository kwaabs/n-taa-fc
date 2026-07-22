-- Extend assignments
ALTER TABLE assignments
    ADD COLUMN team_id   UUID REFERENCES teams(id) ON DELETE CASCADE,
    ADD COLUMN layer_id  UUID REFERENCES layers(id),
    ADD COLUMN priority  VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
    ADD COLUMN title     TEXT;

-- Make assigned_to nullable (one of team_id or assigned_to required)
ALTER TABLE assignments ALTER COLUMN assigned_to DROP NOT NULL;

ALTER TABLE assignments
    ADD CONSTRAINT assignment_has_assignee
    CHECK (assigned_to IS NOT NULL OR team_id IS NOT NULL);

CREATE INDEX idx_assignments_team_id   ON assignments(team_id);
CREATE INDEX idx_assignments_layer_id  ON assignments(layer_id);
CREATE INDEX idx_assignments_priority  ON assignments(priority);
CREATE INDEX idx_assignments_due_date  ON assignments(due_date);

-- Link features to assignments
ALTER TABLE features
    ADD COLUMN assignment_id UUID REFERENCES assignments(id) ON DELETE SET NULL;

CREATE INDEX idx_features_assignment_id ON features(assignment_id);