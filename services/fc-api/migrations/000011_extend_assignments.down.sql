DROP INDEX IF EXISTS idx_features_assignment_id;
ALTER TABLE features DROP COLUMN IF EXISTS assignment_id;

DROP INDEX IF EXISTS idx_assignments_due_date;
DROP INDEX IF EXISTS idx_assignments_priority;
DROP INDEX IF EXISTS idx_assignments_layer_id;
DROP INDEX IF EXISTS idx_assignments_team_id;

ALTER TABLE assignments DROP CONSTRAINT IF EXISTS assignment_has_assignee;
ALTER TABLE assignments ALTER COLUMN assigned_to SET NOT NULL;

ALTER TABLE assignments
    DROP COLUMN IF EXISTS title,
    DROP COLUMN IF EXISTS priority,
    DROP COLUMN IF EXISTS layer_id,
    DROP COLUMN IF EXISTS team_id;