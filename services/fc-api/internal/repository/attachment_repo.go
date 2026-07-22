package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type AttachmentRepo struct {
	db *bun.DB
}

func NewAttachmentRepo(db *bun.DB) *AttachmentRepo {
	return &AttachmentRepo{db: db}
}

func (r *AttachmentRepo) Create(ctx context.Context, a *model.FeatureAttachment) error {
	_, err := r.db.NewInsert().Model(a).Exec(ctx)
	return err
}

func (r *AttachmentRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.FeatureAttachment, error) {
	a := new(model.FeatureAttachment)
	err := r.db.NewSelect().Model(a).Where("fa.id = ?", id).Scan(ctx)
	return a, err
}

func (r *AttachmentRepo) FindByClientID(ctx context.Context, clientID uuid.UUID) (*model.FeatureAttachment, error) {
	a := new(model.FeatureAttachment)
	err := r.db.NewSelect().Model(a).Where("fa.client_id = ?", clientID).Scan(ctx)
	return a, err
}

func (r *AttachmentRepo) ListByFeature(ctx context.Context, featureID uuid.UUID) ([]model.FeatureAttachment, error) {
	var list []model.FeatureAttachment
	err := r.db.NewSelect().
		Model(&list).
		Where("fa.feature_id = ?", featureID).
		OrderExpr("fa.field_id ASC, fa.created_at ASC").
		Scan(ctx)
	return list, err
}

func (r *AttachmentRepo) ListByProject(ctx context.Context, projectID uuid.UUID, limit, offset int) ([]model.FeatureAttachment, int, error) {
	var list []model.FeatureAttachment
	count, err := r.db.NewSelect().
		Model(&list).
		Where("fa.project_id = ?", projectID).
		OrderExpr("fa.created_at DESC").
		Limit(limit).
		Offset(offset).
		ScanAndCount(ctx)
	return list, count, err
}

// LinkToFeature ties pending uploads to a feature (called when feature is pushed).
func (r *AttachmentRepo) LinkToFeature(ctx context.Context, clientIDs []uuid.UUID, featureID uuid.UUID) error {
	if len(clientIDs) == 0 {
		return nil
	}
	_, err := r.db.NewUpdate().
		Model((*model.FeatureAttachment)(nil)).
		Set("feature_id = ?", featureID).
		Set("updated_at = ?", time.Now()).
		Where("client_id IN (?)", bun.In(clientIDs)).
		Exec(ctx)
	return err
}

func (r *AttachmentRepo) MarkUploaded(ctx context.Context, id uuid.UUID, uploadedBy uuid.UUID, sizeBytes int64) error {
	now := time.Now()
	_, err := r.db.NewUpdate().
		Model((*model.FeatureAttachment)(nil)).
		Set("status = ?", "uploaded").
		Set("uploaded_by = ?", uploadedBy).
		Set("uploaded_at = ?", now).
		Set("size_bytes = ?", sizeBytes).
		Set("updated_at = ?", now).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

func (r *AttachmentRepo) MarkFailed(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewUpdate().
		Model((*model.FeatureAttachment)(nil)).
		Set("status = ?", "failed").
		Set("updated_at = ?", time.Now()).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

func (r *AttachmentRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewDelete().
		Model((*model.FeatureAttachment)(nil)).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

func (r *AttachmentRepo) CountByFeature(ctx context.Context, featureID uuid.UUID) (int, error) {
	return r.db.NewSelect().
		Model((*model.FeatureAttachment)(nil)).
		Where("feature_id = ?", featureID).
		Where("status = ?", "uploaded").
		Count(ctx)
}

// DeleteByFeatureIDs removes all attachments tied to a set of features.
func (r *AttachmentRepo) DeleteByFeatureIDs(ctx context.Context, featureIDs []uuid.UUID) (int64, error) {
	if len(featureIDs) == 0 {
		return 0, nil
	}
	res, err := r.db.NewDelete().
		Table("feature_attachments").
		Where("feature_id IN (?)", bun.In(featureIDs)).
		Exec(ctx)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}
