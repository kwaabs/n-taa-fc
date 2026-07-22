package service

import (
    "context"
    "fmt"

    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type TeamService struct {
    teamRepo *repository.TeamRepo
    userRepo *repository.UserRepo
}

func NewTeamService(teamRepo *repository.TeamRepo, userRepo *repository.UserRepo) *TeamService {
    return &TeamService{teamRepo: teamRepo, userRepo: userRepo}
}

// ── Teams ─────────────────────────────────────────

func (s *TeamService) Create(ctx context.Context, userID uuid.UUID, name, description string) (*model.Team, error) {
    if name == "" {
        return nil, fmt.Errorf("name is required")
    }
    team := &model.Team{
        Name:        name,
        Description: description,
        CreatedBy:   userID,
    }
    if err := s.teamRepo.Create(ctx, team); err != nil {
        return nil, fmt.Errorf("failed to create team: %w", err)
    }
    return team, nil
}

func (s *TeamService) List(ctx context.Context) ([]model.Team, error) {
    return s.teamRepo.List(ctx)
}

func (s *TeamService) Get(ctx context.Context, teamID uuid.UUID) (*model.Team, error) {
    team, err := s.teamRepo.FindByID(ctx, teamID)
    if err != nil {
        return nil, fmt.Errorf("team not found")
    }
    return team, nil
}

func (s *TeamService) Update(ctx context.Context, teamID uuid.UUID, name, description *string) (*model.Team, error) {
    team, err := s.teamRepo.FindByID(ctx, teamID)
    if err != nil {
        return nil, fmt.Errorf("team not found")
    }
    if name != nil {
        team.Name = *name
    }
    if description != nil {
        team.Description = *description
    }
    if err := s.teamRepo.Update(ctx, team); err != nil {
        return nil, fmt.Errorf("failed to update team: %w", err)
    }
    return team, nil
}

func (s *TeamService) Delete(ctx context.Context, teamID uuid.UUID) error {
    if _, err := s.teamRepo.FindByID(ctx, teamID); err != nil {
        return fmt.Errorf("team not found")
    }
    return s.teamRepo.Delete(ctx, teamID)
}

// ── Team Members ──────────────────────────────────

func (s *TeamService) ListMembers(ctx context.Context, teamID uuid.UUID) ([]model.TeamMember, error) {
    return s.teamRepo.ListMembers(ctx, teamID)
}

func (s *TeamService) AddMember(ctx context.Context, teamID uuid.UUID, email, role string) (*model.TeamMember, error) {
    user, err := s.userRepo.FindByEmail(ctx, email)
    if err != nil {
        return nil, fmt.Errorf("user with email '%s' not found — they must sign in at least once", email)
    }

    if role == "" {
        role = "member"
    }
    if role != "leader" && role != "member" {
        return nil, fmt.Errorf("role must be 'leader' or 'member'")
    }

    tm := &model.TeamMember{
        TeamID: teamID,
        UserID: user.ID,
        Role:   role,
    }
    if err := s.teamRepo.AddMember(ctx, tm); err != nil {
        return nil, fmt.Errorf("failed to add member: %w", err)
    }
    tm.User = user
    return tm, nil
}

func (s *TeamService) UpdateMemberRole(ctx context.Context, teamID, userID uuid.UUID, role string) error {
    if role != "leader" && role != "member" {
        return fmt.Errorf("role must be 'leader' or 'member'")
    }
    return s.teamRepo.UpdateMemberRole(ctx, teamID, userID, role)
}

func (s *TeamService) RemoveMember(ctx context.Context, teamID, userID uuid.UUID) error {
    return s.teamRepo.RemoveMember(ctx, teamID, userID)
}

// ── Project Teams ─────────────────────────────────

func (s *TeamService) AssignToProject(ctx context.Context, projectID, teamID uuid.UUID, role string) (*model.ProjectTeam, error) {
    if _, err := s.teamRepo.FindByID(ctx, teamID); err != nil {
        return nil, fmt.Errorf("team not found")
    }
    if role == "" {
        role = "field_worker"
    }
    if role != "supervisor" && role != "field_worker" {
        return nil, fmt.Errorf("role must be 'supervisor' or 'field_worker'")
    }

    pt := &model.ProjectTeam{
        ProjectID: projectID,
        TeamID:    teamID,
        Role:      role,
    }
    if err := s.teamRepo.AssignToProject(ctx, pt); err != nil {
        return nil, fmt.Errorf("failed to assign team: %w", err)
    }
    return pt, nil
}

func (s *TeamService) RemoveFromProject(ctx context.Context, projectID, teamID uuid.UUID) error {
    return s.teamRepo.RemoveFromProject(ctx, projectID, teamID)
}

func (s *TeamService) ListProjectTeams(ctx context.Context, projectID uuid.UUID) ([]model.ProjectTeam, error) {
    return s.teamRepo.ListProjectTeams(ctx, projectID)
}

func (s *TeamService) GetEffectiveMembers(ctx context.Context, projectID uuid.UUID) ([]model.TeamMember, error) {
    return s.teamRepo.GetEffectiveProjectMembers(ctx, projectID)
}