package repository

import (
    "context"
    "encoding/json"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type ImportJobRepo struct {
    db *bun.DB
}

func NewImportJobRepo(db *bun.DB) *ImportJobRepo {
    return &ImportJobRepo{db: db}
}

func (r *ImportJobRepo) Create(ctx context.Context, j *model.ImportJob) error {
    _, err := r.db.NewInsert().Model(j).Exec(ctx)
    return err
}

func (r *ImportJobRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.ImportJob, error) {
    j := new(model.ImportJob)
    err := r.db.NewSelect().Model(j).Where("ij.id = ?", id).Scan(ctx)
    return j, err
}

func (r *ImportJobRepo) ListByProject(ctx context.Context, projectID uuid.UUID, limit int) ([]model.ImportJob, error) {
    var list []model.ImportJob
    q := r.db.NewSelect().
        Model(&list).
        Where("ij.project_id = ?", projectID).
        OrderExpr("ij.created_at DESC")
    if limit > 0 {
        q = q.Limit(limit)
    }
    err := q.Scan(ctx)
    return list, err
}

func (r *ImportJobRepo) MarkRunning(ctx context.Context, id uuid.UUID) error {
    now := time.Now()
    _, err := r.db.NewUpdate().
        Model((*model.ImportJob)(nil)).
        Set("status = 'running'").
        Set("started_at = ?", now).
        Set("updated_at = ?", now).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

func (r *ImportJobRepo) UpdateProgress(ctx context.Context, id uuid.UUID, progress json.RawMessage) error {
    _, err := r.db.NewUpdate().
        Model((*model.ImportJob)(nil)).
        Set("progress = ?::jsonb", string(progress)).
        Set("updated_at = ?", time.Now()).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

func (r *ImportJobRepo) MarkFinished(ctx context.Context, id uuid.UUID, status string, result json.RawMessage, errMsg string) error {
    now := time.Now()
    _, err := r.db.NewUpdate().
        Model((*model.ImportJob)(nil)).
        Set("status = ?", status).
        Set("result = ?::jsonb", string(result)).
        Set("error_message = ?", errMsg).
        Set("finished_at = ?", now).
        Set("updated_at = ?", now).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

// MarkOrphaned is called on server startup to fail jobs that were running when we restarted.
func (r *ImportJobRepo) MarkOrphaned(ctx context.Context) (int, error) {
    res, err := r.db.NewUpdate().
        Model((*model.ImportJob)(nil)).
        Set("status = 'failed'").
        Set("error_message = 'server restarted while job was running'").
        Set("finished_at = ?", time.Now()).
        Where("status = 'running'").
        Exec(ctx)
    if err != nil {
        return 0, err
    }
    n, _ := res.RowsAffected()
    return int(n), nil
}