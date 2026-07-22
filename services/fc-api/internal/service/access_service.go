package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

// AccessService centralizes RBAC decisions:
//   - CanAccess: is the user allowed to see/use a project (membership)
//   - RoleOf:    the user's fixed global role
//   - HasMinRole: does the user's role meet a minimum threshold
//
// Model: role is FIXED per user (user_profiles.role). Membership is fluid
// (direct via project_members OR indirect via a team assigned to the project).
// is_system_admin is a platform-wide super-admin bypass.
type AccessService struct {
	db *bun.DB
}

func NewAccessService(db *bun.DB) *AccessService {
	return &AccessService{db: db}
}

func roleRank(role string) int {
	switch role {
	case "admin":
		return 3
	case "supervisor":
		return 2
	case "field_worker":
		return 1
	default:
		return 0
	}
}

// RoleOf returns the user's fixed global role. System admins resolve as "admin".
func (s *AccessService) RoleOf(ctx context.Context, userID uuid.UUID) (string, error) {
	var row struct {
		Role          string `bun:"role"`
		IsSystemAdmin bool   `bun:"is_system_admin"`
	}
	err := s.db.NewSelect().
		TableExpr("user_profiles").
		ColumnExpr("role, is_system_admin").
		Where("id = ?", userID).
		Scan(ctx, &row)
	if err != nil {
		return "", err
	}
	if row.IsSystemAdmin {
		return "admin", nil
	}
	if row.Role == "" {
		return "field_worker", nil
	}
	return row.Role, nil
}

// HasMinRole reports whether the user's role is at least minRole.
func (s *AccessService) HasMinRole(ctx context.Context, userID uuid.UUID, minRole string) (bool, error) {
	role, err := s.RoleOf(ctx, userID)
	if err != nil {
		return false, err
	}
	return roleRank(role) >= roleRank(minRole), nil
}

// IsSystemAdmin reports whether the user is a platform super-admin.
func (s *AccessService) IsSystemAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	var isSysAdmin bool
	err := s.db.NewSelect().
		TableExpr("user_profiles").
		ColumnExpr("is_system_admin").
		Where("id = ?", userID).
		Scan(ctx, &isSysAdmin)
	if err != nil {
		return false, err
	}
	return isSysAdmin, nil
}

// CanAccess reports whether the user may access the project.
// True if: system admin, OR direct member, OR member of a team assigned
// to the project.
func (s *AccessService) CanAccess(ctx context.Context, userID, projectID uuid.UUID) (bool, error) {
	// System admin bypass
	sysAdmin, err := s.IsSystemAdmin(ctx, userID)
	if err == nil && sysAdmin {
		return true, nil
	}

	// Direct membership
	directCount, err := s.db.NewSelect().
		TableExpr("project_members").
		Where("project_id = ?", projectID).
		Where("user_id = ?", userID).
		Count(ctx)
	if err == nil && directCount > 0 {
		return true, nil
	}

	// Team-based membership: user is on a team assigned to this project
	teamCount, err := s.db.NewSelect().
		TableExpr("team_members AS tm").
		Join("JOIN project_teams AS pt ON pt.team_id = tm.team_id").
		Where("tm.user_id = ?", userID).
		Where("pt.project_id = ?", projectID).
		Count(ctx)
	if err != nil {
		return false, err
	}
	return teamCount > 0, nil
}

// CanAccessWithRole is a convenience combining access + minimum role.
// Returns true only if the user can access the project AND meets minRole.
func (s *AccessService) CanAccessWithRole(
	ctx context.Context, userID, projectID uuid.UUID, minRole string,
) (bool, error) {
	access, err := s.CanAccess(ctx, userID, projectID)
	if err != nil || !access {
		return false, err
	}
	return s.HasMinRole(ctx, userID, minRole)
}

func NewAccessServiceProvider(db *bun.DB) *AccessService {
	return NewAccessService(db)
}