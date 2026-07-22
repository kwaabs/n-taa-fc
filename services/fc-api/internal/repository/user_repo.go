package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type UserRepo struct {
	db *bun.DB
}

func NewUserRepo(db *bun.DB) *UserRepo {
	return &UserRepo{db: db}
}

// Upsert creates or updates a user profile based on GoTrue JWT claims.
func (r *UserRepo) Upsert(ctx context.Context, user *model.UserProfile) error {
	_, err := r.db.NewInsert().
		Model(user).
		On("CONFLICT (email) DO UPDATE").
		Set("id = EXCLUDED.id").
		Set("full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), u.full_name)").
		Set("updated_at = NOW()").
		Exec(ctx)
	return err
}

// FindByID retrieves a user profile by ID.
func (r *UserRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.UserProfile, error) {
	user := new(model.UserProfile)
	err := r.db.NewSelect().
		Model(user).
		Where("id = ?", id).
		Scan(ctx)
	return user, err
}

// FindByEmail retrieves a user profile by email.
func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*model.UserProfile, error) {
	user := new(model.UserProfile)
	err := r.db.NewSelect().
		Model(user).
		Where("email = ?", email).
		Scan(ctx)
	return user, err
}

// List returns all user profiles (for the admin Users page).
func (r *UserRepo) List(ctx context.Context) ([]model.UserProfile, error) {
	var users []model.UserProfile
	err := r.db.NewSelect().
		Model(&users).
		OrderExpr("u.email ASC").
		Scan(ctx)
	return users, err
}

// UpdateRole sets a user's fixed global role.
func (r *UserRepo) UpdateRole(ctx context.Context, userID uuid.UUID, role string) error {
	_, err := r.db.NewUpdate().
		Model((*model.UserProfile)(nil)).
		Set("role = ?", role).
		Set("updated_at = ?", time.Now()).
		Where("id = ?", userID).
		Exec(ctx)
	return err
}

// UserTeam represents a team the user belongs to, with their team role.
type UserTeam struct {
	TeamID   uuid.UUID `bun:"team_id" json:"team_id"`
	TeamName string    `bun:"team_name" json:"team_name"`
	TeamRole string    `bun:"team_role" json:"team_role"` // leader | member
}

// UserProject represents a project the user can access + how.
type UserProject struct {
	ProjectID uuid.UUID `bun:"project_id" json:"project_id"`
	Name      string    `bun:"name" json:"name"`
	Status    string    `bun:"status" json:"status"`
	Source    string    `bun:"source" json:"source"`     // "direct" | "team"
	TeamName  string    `bun:"team_name" json:"team_name"` // set when source=team
}

// TeamsForUser returns all teams the user is a member of.
func (r *UserRepo) TeamsForUser(ctx context.Context, userID uuid.UUID) ([]UserTeam, error) {
	var teams []UserTeam
	err := r.db.NewSelect().
		TableExpr("team_members AS tm").
		ColumnExpr("tm.team_id AS team_id").
		ColumnExpr("t.name AS team_name").
		ColumnExpr("tm.role AS team_role").
		Join("JOIN teams AS t ON t.id = tm.team_id").
		Where("tm.user_id = ?", userID).
		OrderExpr("t.name ASC").
		Scan(ctx, &teams)
	return teams, err
}

// ProjectsForUser returns all projects the user can access, direct + via teams.
func (r *UserRepo) ProjectsForUser(ctx context.Context, userID uuid.UUID) ([]UserProject, error) {
	var projects []UserProject
	query := `
		SELECT p.id AS project_id, p.name AS name, p.status AS status,
		       'direct' AS source, '' AS team_name
		FROM projects p
		JOIN project_members pm ON pm.project_id = p.id
		WHERE pm.user_id = ? AND p.status != 'archived'

		UNION

		SELECT p.id AS project_id, p.name AS name, p.status AS status,
		       'team' AS source, t.name AS team_name
		FROM projects p
		JOIN project_teams pt ON pt.project_id = p.id
		JOIN team_members tm ON tm.team_id = pt.team_id
		JOIN teams t ON t.id = pt.team_id
		WHERE tm.user_id = ? AND p.status != 'archived'

		ORDER BY name ASC
	`
	err := r.db.NewRaw(query, userID, userID).Scan(ctx, &projects)
	return projects, err
}