-- 000017_sync_extend.up.sql
-- Extend sync_log with richer per-run stats and add sync_errors detail table.

-- 1. Extend sync_log with the columns we need for the new run model.
ALTER TABLE sync_log
    ADD COLUMN IF NOT EXISTS trigger                VARCHAR(20)
        DEFAULT 'manual'
        CHECK (trigger IN ('manual','auto_wifi','retry')),
    ADD COLUMN IF NOT EXISTS features_succeeded     INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS features_failed        INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attachments_attempted  INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attachments_succeeded  INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attachments_failed     INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ended_at               TIMESTAMPTZ;

-- Rename features_count to features_attempted for clarity. Use a fallback
-- so re-running this migration is safe.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sync_log' AND column_name = 'features_count'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sync_log' AND column_name = 'features_attempted'
    ) THEN
        ALTER TABLE sync_log RENAME COLUMN features_count TO features_attempted;
    END IF;
END $$;

-- 2. New detail table for individual error rows (only written on failure).
CREATE TABLE IF NOT EXISTS sync_errors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_log_id     UUID REFERENCES sync_log(id) ON DELETE CASCADE,
    feature_id      UUID NULL,         -- client_id of the feature (no FK; client_id may not exist yet)
    attachment_id   UUID NULL,         -- client_id of the attachment
    error_code      VARCHAR(50) NOT NULL,
    error_message   TEXT,
    http_status     INTEGER,
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sync_errors_sync_log_id ON sync_errors(sync_log_id);
CREATE INDEX IF NOT EXISTS idx_sync_errors_feature_id  ON sync_errors(feature_id);
CREATE INDEX IF NOT EXISTS idx_sync_errors_occurred_at ON sync_errors(occurred_at);