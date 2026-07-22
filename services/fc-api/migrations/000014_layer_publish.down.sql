DROP INDEX IF EXISTS idx_layers_status;

ALTER TABLE layers
    DROP COLUMN IF EXISTS published_by,
    DROP COLUMN IF EXISTS published_at,
    DROP COLUMN IF EXISTS status;