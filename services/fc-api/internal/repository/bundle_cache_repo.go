package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type BundleCacheRepo struct {
	db *bun.DB
}

func NewBundleCacheRepo(db *bun.DB) *BundleCacheRepo {
	return &BundleCacheRepo{db: db}
}

func (r *BundleCacheRepo) FindMatch(
	ctx context.Context,
	projectID, userID uuid.UUID,
	includeReferenceData bool,
	contentHash string,
) (*model.BundleCache, error) {
	c := new(model.BundleCache)
	err := r.db.NewSelect().
		Model(c).
		Where("bc.project_id = ?", projectID).
		Where("bc.user_id = ?", userID).
		Where("bc.include_reference_data = ?", includeReferenceData).
		Where("bc.content_hash = ?", contentHash).
		Limit(1).
		Scan(ctx)
	return c, err
}

func (r *BundleCacheRepo) Create(ctx context.Context, c *model.BundleCache) error {
	_, err := r.db.NewInsert().Model(c).Exec(ctx)
	return err
}

func (r *BundleCacheRepo) TouchAccessed(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewUpdate().
		Model((*model.BundleCache)(nil)).
		Set("accessed_at = ?", time.Now()).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// ListStale finds cache entries older than the given cutoff for TTL eviction.
func (r *BundleCacheRepo) ListStale(ctx context.Context, olderThan time.Time, limit int) ([]model.BundleCache, error) {
	var list []model.BundleCache
	q := r.db.NewSelect().
		Model(&list).
		Where("bc.accessed_at < ?", olderThan).
		OrderExpr("bc.accessed_at ASC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	err := q.Scan(ctx)
	return list, err
}

func (r *BundleCacheRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.BundleCache)(nil)).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// InvalidateProject deletes ALL cache entries for a project (called when project content changes).
func (r *BundleCacheRepo) InvalidateProject(ctx context.Context, projectID uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.BundleCache)(nil)).
		Where("project_id = ?", projectID).
		Exec(ctx)
	return err
}

// GetProjectStatus fetches just the status column for a project.
// Used by bundle download gating (AOI Phase 1).
func (r *BundleCacheRepo) GetProjectStatus(ctx context.Context, projectID uuid.UUID, out *string) error {
	return r.db.NewSelect().
		TableExpr("projects").
		ColumnExpr("status").
		Where("id = ?", projectID).
		Limit(1).
		Scan(ctx, out)
}
