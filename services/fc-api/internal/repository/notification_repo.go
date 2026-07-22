package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type NotificationRepo struct {
	db *bun.DB
}

func NewNotificationRepo(db *bun.DB) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) CreateMany(ctx context.Context, rows []model.Notification) error {
	if len(rows) == 0 {
		return nil
	}
	_, err := r.db.NewInsert().Model(&rows).Exec(ctx)
	return err
}

func (r *NotificationRepo) ListByUser(
	ctx context.Context,
	userID uuid.UUID,
	unreadOnly bool,
	limit int,
) ([]model.Notification, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	var rows []model.Notification
	q := r.db.NewSelect().
		Model(&rows).
		Where("user_id = ?", userID).
		OrderExpr("created_at DESC").
		Limit(limit)
	if unreadOnly {
		q = q.Where("read_at IS NULL")
	}
	err := q.Scan(ctx)
	return rows, err
}

func (r *NotificationRepo) CountUnread(ctx context.Context, userID uuid.UUID) (int, error) {
	return r.db.NewSelect().
		Model((*model.Notification)(nil)).
		Where("user_id = ?", userID).
		Where("read_at IS NULL").
		Count(ctx)
}

func (r *NotificationRepo) MarkRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	now := time.Now().UTC()
	_, err := r.db.NewUpdate().
		Model((*model.Notification)(nil)).
		Set("read_at = ?", now).
		Where("id = ?", notificationID).
		Where("user_id = ?", userID).
		Where("read_at IS NULL").
		Exec(ctx)
	return err
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	now := time.Now().UTC()
	_, err := r.db.NewUpdate().
		Model((*model.Notification)(nil)).
		Set("read_at = ?", now).
		Where("user_id = ?", userID).
		Where("read_at IS NULL").
		Exec(ctx)
	return err
}
