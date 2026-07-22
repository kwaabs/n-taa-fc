package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type ReconciliationRepo struct {
	db *bun.DB
}

func NewReconciliationRepo(db *bun.DB) *ReconciliationRepo {
	return &ReconciliationRepo{db: db}
}

// ── Jobs ───────────────────────────────────────────────

func (r *ReconciliationRepo) CreateJob(ctx context.Context, job *model.ReconciliationJob) error {
	_, err := r.db.NewInsert().Model(job).Exec(ctx)
	return err
}

func (r *ReconciliationRepo) FindJob(ctx context.Context, id uuid.UUID) (*model.ReconciliationJob, error) {
	job := new(model.ReconciliationJob)
	err := r.db.NewSelect().Model(job).Where("rj.id = ?", id).Scan(ctx)
	return job, err
}

func (r *ReconciliationRepo) ListJobsByLayer(ctx context.Context, layerID uuid.UUID, limit int) ([]model.ReconciliationJob, error) {
	var jobs []model.ReconciliationJob
	q := r.db.NewSelect().
		Model(&jobs).
		Where("rj.layer_id = ?", layerID).
		OrderExpr("rj.created_at DESC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	err := q.Scan(ctx)
	return jobs, err
}

// MarkRunning transitions a job to 'running' and stamps started_at.
func (r *ReconciliationRepo) MarkRunning(ctx context.Context, jobID uuid.UUID) error {
	now := time.Now()
	_, err := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("status = ?", "running").
		Set("started_at = ?", now).
		Set("updated_at = ?", now).
		Where("id = ?", jobID).
		Exec(ctx)
	return err
}

// UpdateProgress writes a free-form progress JSON for live monitoring.
func (r *ReconciliationRepo) UpdateProgress(ctx context.Context, jobID uuid.UUID, progress []byte) error {
	_, err := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("progress = ?::jsonb", string(progress)).
		Set("updated_at = ?", time.Now()).
		Where("id = ?", jobID).
		Exec(ctx)
	return err
}

// IncrementCounters atomically bumps the per-job counters (called per chunk).
func (r *ReconciliationRepo) IncrementCounters(
	ctx context.Context,
	jobID uuid.UUID,
	insertsAttempted, insertsSucceeded int,
	updatesAttempted, updatesSucceeded int,
	deletesAttempted, deletesSucceeded int,
	conflicts, errors int,
) error {
	_, err := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("inserts_attempted  = inserts_attempted  + ?", insertsAttempted).
		Set("inserts_succeeded  = inserts_succeeded  + ?", insertsSucceeded).
		Set("updates_attempted  = updates_attempted  + ?", updatesAttempted).
		Set("updates_succeeded  = updates_succeeded  + ?", updatesSucceeded).
		Set("deletes_attempted  = deletes_attempted  + ?", deletesAttempted).
		Set("deletes_succeeded  = deletes_succeeded  + ?", deletesSucceeded).
		Set("conflicts_detected = conflicts_detected + ?", conflicts).
		Set("errors             = errors             + ?", errors).
		Set("updated_at = ?", time.Now()).
		Where("id = ?", jobID).
		Exec(ctx)
	return err
}

// MarkFinished closes out a job with final status + summary result.
func (r *ReconciliationRepo) MarkFinished(ctx context.Context, jobID uuid.UUID, status string, result []byte, errMsg string) error {
	now := time.Now()
	q := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("status = ?", status).
		Set("finished_at = ?", now).
		Set("updated_at = ?", now).
		Where("id = ?", jobID)
	if result != nil {
		q = q.Set("result = ?::jsonb", string(result))
	}
	if errMsg != "" {
		q = q.Set("error_message = ?", errMsg)
	}
	_, err := q.Exec(ctx)
	return err
}

// MarkOrphaned flips any 'running' jobs back to 'failed' on server boot.
// Mirrors the import_jobs pattern.
func (r *ReconciliationRepo) MarkOrphaned(ctx context.Context) (int, error) {
	res, err := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("status = ?", "failed").
		Set("error_message = ?", "orphaned by server restart").
		Set("finished_at = ?", time.Now()).
		Where("status = ?", "running").
		Exec(ctx)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return int(n), nil
}

// ── Conflicts ──────────────────────────────────────────

func (r *ReconciliationRepo) CreateConflict(ctx context.Context, c *model.ReconciliationConflict) error {
	_, err := r.db.NewInsert().Model(c).Exec(ctx)
	return err
}

func (r *ReconciliationRepo) ListConflictsByJob(ctx context.Context, jobID uuid.UUID) ([]model.ReconciliationConflict, error) {
	var conflicts []model.ReconciliationConflict
	err := r.db.NewSelect().
		Model(&conflicts).
		Where("rc.job_id = ?", jobID).
		OrderExpr("rc.created_at ASC").
		Scan(ctx)
	return conflicts, err
}

func (r *ReconciliationRepo) ListPendingConflictsByLayer(ctx context.Context, layerID uuid.UUID) ([]model.ReconciliationConflict, error) {
	var conflicts []model.ReconciliationConflict
	err := r.db.NewSelect().
		Model(&conflicts).
		Where("rc.layer_id = ?", layerID).
		Where("rc.status = ?", "pending").
		OrderExpr("rc.created_at ASC").
		Scan(ctx)
	return conflicts, err
}

func (r *ReconciliationRepo) ResolveConflict(
	ctx context.Context,
	conflictID uuid.UUID,
	resolution string,
	resolvedAttrs []byte,
	resolvedBy uuid.UUID,
	notes string,
) error {
	_, err := r.db.NewUpdate().
		Model((*model.ReconciliationConflict)(nil)).
		Set("status = ?", "resolved").
		Set("resolution = ?", sql.NullString{String: resolution, Valid: resolution != ""}).
		Set("resolved_attrs = ?::jsonb", string(resolvedAttrs)).
		Set("resolved_by = ?", resolvedBy).
		Set("resolved_at = ?", time.Now()).
		Set("notes = ?", notes).
		Where("id = ?", conflictID).
		Exec(ctx)
	return err
}

// ── Audit log ──────────────────────────────────────────

func (r *ReconciliationRepo) WriteLogEntry(ctx context.Context, entry *model.ReconciliationLogEntry) error {
	_, err := r.db.NewInsert().Model(entry).Exec(ctx)
	return err
}

func (r *ReconciliationRepo) ListLogsByJob(ctx context.Context, jobID uuid.UUID, limit int) ([]model.ReconciliationLogEntry, error) {
	var entries []model.ReconciliationLogEntry
	q := r.db.NewSelect().
		Model(&entries).
		Where("rl.job_id = ?", jobID).
		OrderExpr("rl.applied_at DESC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	err := q.Scan(ctx)
	return entries, err
}

// HasAppliedFor checks whether a given feature_id + change_type pair has already
// been successfully applied. Prevents double-pushing during retries.
func (r *ReconciliationRepo) HasAppliedFor(ctx context.Context, featureID uuid.UUID, changeType string) (bool, error) {
	count, err := r.db.NewSelect().
		Model((*model.ReconciliationLogEntry)(nil)).
		Where("rl.feature_id = ?", featureID).
		Where("rl.change_type = ?", changeType).
		Where("rl.outcome = ?", "applied").
		Count(ctx)
	return count > 0, err
}

// QueryResolution loads the most recent resolved conflict for a (feature, changeType)
// pair into the provided container. Returns sql.ErrNoRows if none.
func (r *ReconciliationRepo) QueryResolution(
	ctx context.Context,
	featureID uuid.UUID,
	changeType string,
	out *model.ReconciliationConflict,
) error {
	err := r.db.NewSelect().
		Model(out).
		Where("rc.feature_id = ?", featureID).
		Where("rc.change_type = ?", changeType).
		Where("rc.status = ?", "resolved").
		OrderExpr("rc.resolved_at DESC NULLS LAST").
		Limit(1).
		Scan(ctx)
	return err
}

// SetStatus updates a job's status without touching counters or timestamps.
// Used by Cancel() to flip a running job to 'cancelling'.
func (r *ReconciliationRepo) SetStatus(ctx context.Context, jobID uuid.UUID, status string) error {
	_, err := r.db.NewUpdate().
		Model((*model.ReconciliationJob)(nil)).
		Set("status = ?", status).
		Set("updated_at = ?", time.Now()).
		Where("id = ?", jobID).
		Exec(ctx)
	return err
}

// FindPendingConflict returns the most recent PENDING conflict for a
// (feature_id, change_type) pair, or nil if none exists.
// Used by Preview to avoid creating duplicate rows on repeated runs.
func (r *ReconciliationRepo) FindPendingConflict(
	ctx context.Context,
	featureID uuid.UUID,
	changeType string,
) (*model.ReconciliationConflict, error) {
	conflict := new(model.ReconciliationConflict)
	err := r.db.NewSelect().
		Model(conflict).
		Where("rc.feature_id = ?", featureID).
		Where("rc.change_type = ?", changeType).
		Where("rc.status = ?", "pending").
		OrderExpr("rc.created_at DESC").
		Limit(1).
		Scan(ctx)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return conflict, nil
}


// LayerConflictCounts returns pending vs resolved conflict counts for a layer.
// Used by the admin UI to surface "N resolutions ready to apply" badges.
func (r *ReconciliationRepo) LayerConflictCounts(
    ctx context.Context,
    layerID uuid.UUID,
) (pending int, resolved int, err error) {
    type row struct {
        Status string `bun:"status"`
        Count  int    `bun:"count"`
    }
    var rows []row
    err = r.db.NewSelect().
        TableExpr("reconciliation_conflicts AS rc").
        ColumnExpr("rc.status, COUNT(*) AS count").
        Where("rc.layer_id = ?", layerID).
        GroupExpr("rc.status").
        Scan(ctx, &rows)
    if err != nil {
        return 0, 0, err
    }
    for _, r := range rows {
        switch r.Status {
        case "pending":
            pending = r.Count
        case "resolved":
            resolved = r.Count
        }
    }
    return pending, resolved, nil
}