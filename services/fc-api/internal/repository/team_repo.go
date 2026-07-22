package repository

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type TeamRepo struct {
    db *bun.DB
}

func NewTeamRepo(db *bun.DB) *TeamRepo {
    return &TeamRepo{db: db}
}

// ── Teams ─────────────────────────────────────────

func (r *TeamRepo) Create(ctx context.Context, team *model.Team) error {
    _, err := r.db.NewInsert().Model(team).Exec(ctx)
    return err
}

func (r *TeamRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Team, error) {
    team := new(model.Team)
    err := r.db.NewSelect().
        Model(team).
        Where("t.id = ?", id).
        Scan(ctx)
    return team, err
}

func (r *TeamRepo) List(ctx context.Context) ([]model.Team, error) {
    var teams []model.Team
    err := r.db.NewSelect().
        Model(&teams).
        OrderExpr("t.name ASC").
        Scan(ctx)
    return teams, err
}

func (r *TeamRepo) Update(ctx context.Context, team *model.Team) error {
    team.UpdatedAt = time.Now()
    _, err := r.db.NewUpdate().
        Model(team).
        WherePK().
        Column("name", "description", "updated_at").
        Exec(ctx)
    return err
}

func (r *TeamRepo) Delete(ctx context.Context, id uuid.UUID) error {
    _, err := r.db.NewDelete().
        Model((*model.Team)(nil)).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

// ── Team Members ──────────────────────────────────

func (r *TeamRepo) AddMember(ctx context.Context, tm *model.TeamMember) error {
    _, err := r.db.NewInsert().Model(tm).Exec(ctx)
    return err
}

func (r *TeamRepo) RemoveMember(ctx context.Context, teamID, userID uuid.UUID) error {
    _, err := r.db.NewDelete().
        Model((*model.TeamMember)(nil)).
        Where("team_id = ?", teamID).
        Where("user_id = ?", userID).
        Exec(ctx)
    return err
}

func (r *TeamRepo) ListMembers(ctx context.Context, teamID uuid.UUID) ([]model.TeamMember, error) {
    var members []model.TeamMember
    err := r.db.NewSelect().
        Model(&members).
        Relation("User").
        Where("tm.team_id = ?", teamID).
        OrderExpr("tm.joined_at ASC").
        Scan(ctx)
    return members, err
}

func (r *TeamRepo) UpdateMemberRole(ctx context.Context, teamID, userID uuid.UUID, role string) error {
    _, err := r.db.NewUpdate().
        Model((*model.TeamMember)(nil)).
        Set("role = ?", role).
        Where("team_id = ?", teamID).
        Where("user_id = ?", userID).
        Exec(ctx)
    return err
}

// ── Project Teams ─────────────────────────────────

func (r *TeamRepo) AssignToProject(ctx context.Context, pt *model.ProjectTeam) error {
    _, err := r.db.NewInsert().
        Model(pt).
        On("CONFLICT (project_id, team_id) DO UPDATE").
        Set("role = EXCLUDED.role").
        Exec(ctx)
    return err
}

func (r *TeamRepo) RemoveFromProject(ctx context.Context, projectID, teamID uuid.UUID) error {
    _, err := r.db.NewDelete().
        Model((*model.ProjectTeam)(nil)).
        Where("project_id = ?", projectID).
        Where("team_id = ?", teamID).
        Exec(ctx)
    return err
}

func (r *TeamRepo) ListProjectTeams(ctx context.Context, projectID uuid.UUID) ([]model.ProjectTeam, error) {
    var pts []model.ProjectTeam
    err := r.db.NewSelect().
        Model(&pts).
        Relation("Team").
        Where("pt.project_id = ?", projectID).
        OrderExpr("pt.assigned_at ASC").
        Scan(ctx)
    return pts, err
}

func (r *TeamRepo) ListTeamProjects(ctx context.Context, teamID uuid.UUID) ([]model.ProjectTeam, error) {
    var pts []model.ProjectTeam
    err := r.db.NewSelect().
        Model(&pts).
        Relation("Project").
        Where("pt.team_id = ?", teamID).
        Scan(ctx)
    return pts, err
}

// GetEffectiveProjectMembers returns all users who have access to a project
// through team assignments. Used for resolving who can sync.
func (r *TeamRepo) GetEffectiveProjectMembers(ctx context.Context, projectID uuid.UUID) ([]model.TeamMember, error) {
    var members []model.TeamMember
    err := r.db.NewSelect().
        Model(&members).
        Relation("User").
        Where("tm.team_id IN (?)",
            r.db.NewSelect().
                TableExpr("project_teams").
                Column("team_id").
                Where("project_id = ?", projectID),
        ).
        Scan(ctx)
    return members, err
}