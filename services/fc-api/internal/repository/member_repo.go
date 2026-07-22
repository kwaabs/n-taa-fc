package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type MemberRepo struct {
	db *bun.DB
}

func NewMemberRepo(db *bun.DB) *MemberRepo {
	return &MemberRepo{db: db}
}

// Add inserts a new project member.
func (r *MemberRepo) Add(ctx context.Context, member *model.ProjectMember) error {
	_, err := r.db.NewInsert().Model(member).Exec(ctx)
	return err
}

// AddTx inserts a new project member within a transaction.
func (r *MemberRepo) AddTx(ctx context.Context, tx bun.Tx, member *model.ProjectMember) error {
	_, err := tx.NewInsert().Model(member).Exec(ctx)
	return err
}

// FindByProjectAndUser finds a member record for a specific project and user.
func (r *MemberRepo) FindByProjectAndUser(ctx context.Context, projectID, userID uuid.UUID) (*model.ProjectMember, error) {
	member := new(model.ProjectMember)
	err := r.db.NewSelect().
		Model(member).
		Where("project_id = ?", projectID).
		Where("user_id = ?", userID).
		Where("is_active = true").
		Scan(ctx)
	return member, err
}

// ListByProject returns all active members of a project with user details.
func (r *MemberRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.ProjectMember, error) {
	var members []model.ProjectMember
	err := r.db.NewSelect().
		Model(&members).
		Relation("User").
		Where("pm.project_id = ?", projectID).
		Where("pm.is_active = true").
		OrderExpr("pm.joined_at ASC").
		Scan(ctx)
	return members, err
}

// UpdateRole changes a member's role.
func (r *MemberRepo) UpdateRole(ctx context.Context, projectID, userID uuid.UUID, role string) error {
	_, err := r.db.NewUpdate().
		Model((*model.ProjectMember)(nil)).
		Set("role = ?", role).
		Where("project_id = ?", projectID).
		Where("user_id = ?", userID).
		Exec(ctx)
	return err
}

// Remove deactivates a project member (soft delete).
func (r *MemberRepo) Remove(ctx context.Context, projectID, userID uuid.UUID) error {
	_, err := r.db.NewUpdate().
		Model((*model.ProjectMember)(nil)).
		Set("is_active = false").
		Where("project_id = ?", projectID).
		Where("user_id = ?", userID).
		Exec(ctx)
	return err
}

// CountAdmins counts the number of active admin members in a project.
func (r *MemberRepo) CountAdmins(ctx context.Context, projectID uuid.UUID) (int, error) {
	count, err := r.db.NewSelect().
		Model((*model.ProjectMember)(nil)).
		Where("project_id = ?", projectID).
		Where("role = 'admin'").
		Where("is_active = true").
		Count(ctx)
	return count, err
}
