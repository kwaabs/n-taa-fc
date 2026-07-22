-- D2.1: reconciliation engine schema.

-- Soft delete configuration per data source (admin can override later via UI).
ALTER TABLE layer_data_sources
    ADD COLUMN IF NOT EXISTS delete_strategy VARCHAR(20) NOT NULL DEFAULT 'hard'
        CHECK (delete_strategy IN ('hard', 'soft')),
    ADD COLUMN IF NOT EXISTS soft_delete_column TEXT,
    ADD COLUMN IF NOT EXISTS soft_delete_value  TEXT;

-- One row per "reconcile this layer" run.
CREATE TABLE IF NOT EXISTS reconciliation_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    layer_id        UUID NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
    data_source_id  UUID NOT NULL REFERENCES layer_data_sources(id) ON DELETE CASCADE,

    -- Execution mode: 'preview' (dry-run) or 'apply' (real writes).
    mode            VARCHAR(20) NOT NULL DEFAULT 'preview'
        CHECK (mode IN ('preview', 'apply')),

    -- Lifecycle.
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'success', 'partial', 'failed', 'cancelled')),

    -- Tunables admin can override per run.
    batch_size      INTEGER NOT NULL DEFAULT 500,

    -- Counts populated as the job runs.
    changes_total       INTEGER NOT NULL DEFAULT 0,
    inserts_attempted   INTEGER NOT NULL DEFAULT 0,
    inserts_succeeded   INTEGER NOT NULL DEFAULT 0,
    updates_attempted   INTEGER NOT NULL DEFAULT 0,
    updates_succeeded   INTEGER NOT NULL DEFAULT 0,
    deletes_attempted   INTEGER NOT NULL DEFAULT 0,
    deletes_succeeded   INTEGER NOT NULL DEFAULT 0,
    conflicts_detected  INTEGER NOT NULL DEFAULT 0,
    errors              INTEGER NOT NULL DEFAULT 0,

    -- Free-form progress info (current_chunk, last_processed_feature_id, etc.).
    progress        JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Final summary (admin-facing). Includes per-change-type counts.
    result          JSONB,
    error_message   TEXT,

    -- Audit.
    created_by      UUID REFERENCES user_profiles(id),
    started_at      TIMESTAMPTZ,
    finished_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_project_id     ON reconciliation_jobs(project_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_layer_id       ON reconciliation_jobs(layer_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_data_source_id ON reconciliation_jobs(data_source_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_status         ON reconciliation_jobs(status);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_created_at     ON reconciliation_jobs(created_at);


-- Conflict storage: source-side row differs from our snapshot.
-- Admin resolves these on a dedicated page; resolutions feed the next job.
CREATE TABLE IF NOT EXISTS reconciliation_conflicts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id          UUID NOT NULL REFERENCES reconciliation_jobs(id) ON DELETE CASCADE,
    feature_id      UUID NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    layer_id        UUID NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
    data_source_id  UUID NOT NULL REFERENCES layer_data_sources(id) ON DELETE CASCADE,

    source_ref      TEXT NOT NULL,
    change_type     VARCHAR(20) NOT NULL CHECK (change_type IN ('inserted','updated','deleted')),

    -- Snapshots that drive the side-by-side view.
    original_attrs  JSONB,    -- our captured pre-edit snapshot
    field_attrs     JSONB,    -- what surveyor proposed (the edit)
    source_attrs    JSONB,    -- what source DB currently has (the "other" change)

    -- Field-level diff hints (computed at detection time).
    conflicting_fields TEXT[] NOT NULL DEFAULT '{}',

    -- Lifecycle.
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','resolved','dismissed')),
    resolution      VARCHAR(20)
        CHECK (resolution IS NULL OR resolution IN ('field_wins','source_wins','manual')),
    resolved_attrs  JSONB,
    resolved_by     UUID REFERENCES user_profiles(id),
    resolved_at     TIMESTAMPTZ,
    notes           TEXT,

    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reconciliation_conflicts_job_id         ON reconciliation_conflicts(job_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_conflicts_feature_id     ON reconciliation_conflicts(feature_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_conflicts_data_source_id ON reconciliation_conflicts(data_source_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_conflicts_status         ON reconciliation_conflicts(status);


-- Audit trail of every applied change. Survives even if the job/feature is later deleted.
-- We retain this forever (no auto-trim) for accountability.
CREATE TABLE IF NOT EXISTS reconciliation_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id          UUID REFERENCES reconciliation_jobs(id) ON DELETE SET NULL,
    feature_id      UUID,        -- intentionally NOT a hard FK so we keep history if feature is deleted
    layer_id        UUID,
    data_source_id  UUID,
    source_ref      TEXT,

    change_type     VARCHAR(20) NOT NULL CHECK (change_type IN ('inserted','updated','deleted')),
    outcome         VARCHAR(20) NOT NULL CHECK (outcome IN ('applied','conflict','failed','skipped')),

    -- Snapshot of what was attempted (admin-readable JSON).
    attempted_payload JSONB,
    failure_reason  TEXT,

    applied_by      UUID REFERENCES user_profiles(id),
    applied_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reconciliation_log_job_id        ON reconciliation_log(job_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_log_feature_id    ON reconciliation_log(feature_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_log_outcome       ON reconciliation_log(outcome);
CREATE INDEX IF NOT EXISTS idx_reconciliation_log_applied_at    ON reconciliation_log(applied_at);