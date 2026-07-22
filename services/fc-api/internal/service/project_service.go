package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type ProjectService struct {
	db          *bun.DB
	projectRepo *repository.ProjectRepo
	memberRepo  *repository.MemberRepo
	access      *AccessService
}

func NewProjectService(
	db *bun.DB,
	projectRepo *repository.ProjectRepo,
	memberRepo *repository.MemberRepo,
	access *AccessService,
) *ProjectService {
	return &ProjectService{
		db:          db,
		projectRepo: projectRepo,
		memberRepo:  memberRepo,
		access:      access,
	}
}

// Create creates a new project and adds the creator as an admin member, all in a single transaction.

func (s *ProjectService) Create(
	ctx context.Context, creatorID uuid.UUID,
	name, description, mode string, config json.RawMessage,

	areaOfInterest json.RawMessage,
) (*model.Project, error) {
	if config == nil {
		config = json.RawMessage(`{}`)
	}

	project := &model.Project{
		Name:           name,
		Description:    description,
		Mode:           mode,
		Config:         config,
		Status:         "draft",
		CreatedBy:      creatorID,
		Version:        1,
		AreaOfInterest: areaOfInterest,
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Insert project
	if err := s.projectRepo.Create(ctx, tx, project); err != nil {
		return nil, fmt.Errorf("failed to create project: %w", err)
	}

	// Add creator as admin member
	member := &model.ProjectMember{
		ProjectID: project.ID,
		UserID:    creatorID,
		Role:      "admin",
		IsActive:  true,
	}
	if err := s.memberRepo.AddTx(ctx, tx, member); err != nil {
		return nil, fmt.Errorf("failed to add creator as member: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return project, nil
}

// List returns all projects the user can access (direct or via team).
func (s *ProjectService) List(ctx context.Context, userID uuid.UUID) ([]model.ProjectWithRole, error) {
	return s.projectRepo.ListByUserID(ctx, userID)
}

// Get retrieves a project by ID when the user has direct or team access.
func (s *ProjectService) Get(ctx context.Context, projectID, userID uuid.UUID) (*model.Project, error) {
	ok, err := s.access.CanAccess(ctx, userID, projectID)
	if err != nil {
		return nil, fmt.Errorf("access check failed: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("access denied: you are not a member of this project")
	}

	return s.projectRepo.FindByID(ctx, projectID)
}

// Update updates a project. Only admins can update.

// Update updates a project. Only admins can update.
func (s *ProjectService) Update(ctx context.Context, projectID, userID uuid.UUID, name, description *string, config *json.RawMessage, areaOfInterest json.RawMessage) (*model.Project, error) {
	// Check admin role
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return nil, fmt.Errorf("access denied: admin role required")
	}

	// Fetch existing project
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}

	// AOI Phase 1: Published projects are locked. All edits go through
	// archive → recreate, or via a dedicated Publish flow (future).
	if project.Status == "active" {
		return nil, fmt.Errorf("cannot edit an active (dispatched) project; archive to make changes")
	}

	// Apply updates
	if name != nil {
		project.Name = *name
	}
	if description != nil {
		project.Description = *description
	}
	if config != nil {
		project.Config = *config
	}
	// JSON null and absent both mean "don't update AOI". Only actual GeoJSON persists.
	if len(areaOfInterest) > 0 && string(areaOfInterest) != "null" {
		project.AreaOfInterest = areaOfInterest
	}

	if err := s.projectRepo.Update(ctx, project); err != nil {
		return nil, fmt.Errorf("failed to update project: %w", err)
	}

	return project, nil
}

// Archive sets a project to archived status. Only admins can archive.
func (s *ProjectService) Archive(ctx context.Context, projectID, userID uuid.UUID) error {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return fmt.Errorf("access denied: admin role required")
	}

	return s.projectRepo.Archive(ctx, projectID)
}

// Dispatch transitions a project from draft to active. Only admins can dispatch.
func (s *ProjectService) Dispatch(ctx context.Context, projectID, userID uuid.UUID) (*model.Project, error) {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return nil, fmt.Errorf("access denied: admin role required to dispatch")
	}
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}
	if project.Status == "active" {
		return project, nil // idempotent
	}
	if project.Status == "archived" {
		return nil, fmt.Errorf("cannot dispatch an archived project")
	}
	project.Status = "active"
	project.Version = project.Version + 1
	if err := s.projectRepo.Update(ctx, project); err != nil {
		return nil, fmt.Errorf("failed to dispatch: %w", err)
	}
	return project, nil
}
