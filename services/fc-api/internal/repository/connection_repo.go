package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type ConnectionRepo struct {
	db *bun.DB
}

func NewConnectionRepo(db *bun.DB) *ConnectionRepo {
	return &ConnectionRepo{db: db}
}

func (r *ConnectionRepo) Create(ctx context.Context, c *model.ProjectConnection) error {
	_, err := r.db.NewInsert().Model(c).Exec(ctx)
	return err
}

func (r *ConnectionRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.ProjectConnection, error) {
	c := new(model.ProjectConnection)
	err := r.db.NewSelect().Model(c).Where("pc.id = ?", id).Scan(ctx)
	return c, err
}

func (r *ConnectionRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.ProjectConnection, error) {
	var list []model.ProjectConnection
	err := r.db.NewSelect().
		Model(&list).
		Where("pc.project_id = ?", projectID).
		OrderExpr("pc.created_at DESC").
		Scan(ctx)
	return list, err
}

func (r *ConnectionRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.ProjectConnection)(nil)).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// Update persists changes to a connection profile. Re-encrypt the password
// before calling if you're changing it; this method writes whatever's on c.
func (r *ConnectionRepo) Update(ctx context.Context, c *model.ProjectConnection) error {
	c.UpdatedAt = time.Now()
	_, err := r.db.NewUpdate().
		Model(c).
		WherePK().
		OmitZero().
		Exec(ctx)
	return err
}
