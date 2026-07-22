package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type LayerRepo struct {
	db *bun.DB
}

func NewLayerRepo(db *bun.DB) *LayerRepo {
	return &LayerRepo{db: db}
}

func (r *LayerRepo) Create(ctx context.Context, layer *model.Layer) error {
	_, err := r.db.NewInsert().Model(layer).Exec(ctx)
	return err
}

func (r *LayerRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Layer, error) {
	layer := new(model.Layer)
	err := r.db.NewSelect().
		Model(layer).
		Where("l.id = ?", id).
		Scan(ctx)
	return layer, err
}

func (r *LayerRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.Layer, error) {
    var layers []model.Layer
    // COALESCE to empty array: NULL bbox (e.g. linked_table with no copied
    // features) cannot scan into []float64 and used to 403 the whole list.
    err := r.db.NewSelect().
        Model(&layers).
        ColumnExpr("l.*").
        ColumnExpr(`COALESCE((
            SELECT ARRAY[ST_XMin(e.g), ST_YMin(e.g), ST_XMax(e.g), ST_YMax(e.g)]
            FROM (
                SELECT ST_Extent(f.geometry) AS g
                FROM features f
                WHERE f.layer_id = l.id
                  AND f.deleted_at IS NULL
                  AND f.geometry IS NOT NULL
            ) e
            WHERE e.g IS NOT NULL
        ), ARRAY[]::float8[]) AS bbox`).
        Where("l.project_id = ?", projectID).
        OrderExpr("l.sort_order ASC, l.name ASC").
        Scan(ctx)
    return layers, err
}

func (r *LayerRepo) Update(ctx context.Context, layer *model.Layer) error {
	_, err := r.db.NewUpdate().
		Model(layer).
		WherePK().
		OmitZero().
		Exec(ctx)
	return err
}

func (r *LayerRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.Layer)(nil)).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// Publish marks a layer as published.
func (r *LayerRepo) Publish(ctx context.Context, layerID, publishedBy uuid.UUID) error {
	now := time.Now()
	_, err := r.db.NewUpdate().
		Model((*model.Layer)(nil)).
		Set("status = ?", "published").
		Set("published_at = ?", now).
		Set("published_by = ?", publishedBy).
		Where("id = ?", layerID).
		Exec(ctx)
	return err
}

// Unpublish reverts a layer to draft.
func (r *LayerRepo) Unpublish(ctx context.Context, layerID uuid.UUID) error {
	_, err := r.db.NewUpdate().
		Model((*model.Layer)(nil)).
		Set("status = ?", "draft").
		Set("published_at = NULL").
		Set("published_by = NULL").
		Where("id = ?", layerID).
		Exec(ctx)
	return err
}

// Returns the form_id assigned to a layer (nullable).
func (r *LayerRepo) GetFormID(ctx context.Context, layerID uuid.UUID) (*uuid.UUID, error) {
    var row struct {
        FormID *uuid.UUID `bun:"form_id"`
    }
    err := r.db.NewSelect().
        Table("layers").
        Column("form_id").
        Where("id = ?", layerID).
        Scan(ctx, &row)
    if err != nil {
        return nil, err
    }
    return row.FormID, nil
}

// CountLayersUsingForm returns how many layers reference the given form_id.
func (r *LayerRepo) CountLayersUsingForm(ctx context.Context, formID uuid.UUID) (int, error) {
    count, err := r.db.NewSelect().
        Table("layers").
        Where("form_id = ?", formID).
        Count(ctx)
    if err != nil {
        return 0, err
    }
    return count, nil
}