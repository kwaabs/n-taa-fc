-- 000017_sync_extend.down.sql

DROP TABLE IF EXISTS sync_errors;

ALTER TABLE sync_log
    DROP COLUMN IF EXISTS trigger,
    DROP COLUMN IF EXISTS features_succeeded,
    DROP COLUMN IF EXISTS features_failed,
    DROP COLUMN IF EXISTS attachments_attempted,
    DROP COLUMN IF EXISTS attachments_succeeded,
    DROP COLUMN IF EXISTS attachments_failed,
    DROP COLUMN IF EXISTS ended_at;

-- Rename back if the new column exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sync_log' AND column_name = 'features_attempted'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sync_log' AND column_name = 'features_count'
    ) THEN
        ALTER TABLE sync_log RENAME COLUMN features_attempted TO features_count;
    END IF;
END $$;