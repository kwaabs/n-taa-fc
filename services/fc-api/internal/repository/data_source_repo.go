package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type DataSourceRepo struct {
	db *bun.DB
}

func NewDataSourceRepo(db *bun.DB) *DataSourceRepo {
	return &DataSourceRepo{db: db}
}

func (r *DataSourceRepo) Create(ctx context.Context, ds *model.LayerDataSource) error {
	_, err := r.db.NewInsert().Model(ds).Exec(ctx)
	return err
}

func (r *DataSourceRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.LayerDataSource, error) {
	ds := new(model.LayerDataSource)
	err := r.db.NewSelect().Model(ds).Where("lds.id = ?", id).Scan(ctx)
	return ds, err
}

func (r *DataSourceRepo) ListByLayer(ctx context.Context, layerID uuid.UUID) ([]model.LayerDataSource, error) {
	var sources []model.LayerDataSource
	err := r.db.NewSelect().
		Model(&sources).
		Where("lds.layer_id = ?", layerID).
		OrderExpr("lds.created_at DESC").
		Scan(ctx)
	return sources, err
}

func (r *DataSourceRepo) UpdateSyncStatus(ctx context.Context, id uuid.UUID, status, errMsg string, stats []byte) error {
	now := time.Now()
	_, err := r.db.NewUpdate().
		Model((*model.LayerDataSource)(nil)).
		Set("last_synced_at = ?", now).
		Set("last_sync_status = ?", status).
		Set("last_sync_error = ?", errMsg).
		Set("last_sync_stats = ?::jsonb", string(stats)).
		Set("updated_at = ?", now).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

func (r *DataSourceRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.LayerDataSource)(nil)).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// UpdateConfig replaces the entire config JSONB for a data source. Used by
// D3.0 to wire connection_id (and any other config edits an admin makes via
// the web UI).
func (r *DataSourceRepo) UpdateConfig(ctx context.Context, id uuid.UUID, config []byte) error {
    _, err := r.db.NewUpdate().
        Model((*model.LayerDataSource)(nil)).
        Set("config = ?::jsonb", string(config)).   // 👈 cast string → jsonb
        Set("updated_at = ?", time.Now()).
        Where("id = ?", id).
        Exec(ctx)
    return err
}
