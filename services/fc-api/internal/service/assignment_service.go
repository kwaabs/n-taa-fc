package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type AssignmentService struct {
	assignmentRepo *repository.AssignmentRepo
	memberRepo     *repository.MemberRepo
	access         *AccessService
	notifications  *NotificationService
}

func NewAssignmentService(
	assignmentRepo *repository.AssignmentRepo,
	memberRepo *repository.MemberRepo,
	access *AccessService,
	notifications *NotificationService,
) *AssignmentService {
	return &AssignmentService{
		assignmentRepo: assignmentRepo,
		memberRepo:     memberRepo,
		access:         access,
		notifications:  notifications,
	}
}

// CreateRequest is the validated input for creating an assignment.
type CreateAssignmentInput struct {
	ProjectID    uuid.UUID
	AssignedTo   *uuid.UUID
	TeamID       *uuid.UUID
	FormID       *uuid.UUID
	LayerID      *uuid.UUID
	Area         *string // GeoJSON polygon string
	Title        string
	TargetCount  int
	Instructions string
	Priority     string
	DueDate      *time.Time
}

func (s *AssignmentService) requireSupervisor(ctx context.Context, userID, projectID uuid.UUID) error {
	ok, err := s.access.CanAccessWithRole(ctx, userID, projectID, "supervisor")
	if err != nil {
		return fmt.Errorf("access check failed: %w", err)
	}
	if !ok {
		return fmt.Errorf("access denied: admin or supervisor role required")
	}
	return nil
}

func (s *AssignmentService) requireAccess(ctx context.Context, userID, projectID uuid.UUID) error {
	ok, err := s.access.CanAccess(ctx, userID, projectID)
	if err != nil {
		return fmt.Errorf("access check failed: %w", err)
	}
	if !ok {
		return fmt.Errorf("access denied: not a member of this project")
	}
	return nil
}

func (s *AssignmentService) isFieldScoped(ctx context.Context, userID uuid.UUID) (bool, error) {
	ok, err := s.access.HasMinRole(ctx, userID, "supervisor")
	if err != nil {
		return false, err
	}
	return !ok, nil
}

func (s *AssignmentService) Create(ctx context.Context, userID uuid.UUID, input CreateAssignmentInput) (*model.Assignment, error) {
	if err := s.requireSupervisor(ctx, userID, input.ProjectID); err != nil {
		return nil, err
	}

	// Must have a team or an individual assignee
	if input.AssignedTo == nil && input.TeamID == nil {
		return nil, fmt.Errorf("must assign to a team or an individual")
	}
	if input.AssignedTo != nil && input.TeamID != nil {
		return nil, fmt.Errorf("can only assign to a team OR an individual, not both")
	}

	// Validate priority
	if input.Priority == "" {
		input.Priority = "medium"
	}
	if input.Priority != "low" && input.Priority != "medium" && input.Priority != "high" && input.Priority != "urgent" {
		return nil, fmt.Errorf("priority must be 'low', 'medium', 'high', or 'urgent'")
	}

	// If assigned to individual, verify they can access the project
	if input.AssignedTo != nil {
		ok, err := s.access.CanAccess(ctx, *input.AssignedTo, input.ProjectID)
		if err != nil || !ok {
			return nil, fmt.Errorf("assigned user is not a member of this project")
		}
	}

	a := &model.Assignment{
		ProjectID:    input.ProjectID,
		AssignedTo:   input.AssignedTo,
		TeamID:       input.TeamID,
		AssignedBy:   userID,
		FormID:       input.FormID,
		LayerID:      input.LayerID,
		Area:         input.Area,
		Title:        input.Title,
		TargetCount:  input.TargetCount,
		Instructions: input.Instructions,
		Priority:     input.Priority,
		DueDate:      input.DueDate,
		Status:       "pending",
	}

	if err := s.assignmentRepo.Create(ctx, a); err != nil {
		return nil, fmt.Errorf("failed to create assignment: %w", err)
	}
	if s.notifications != nil {
		s.notifications.NotifyAssignment(ctx, a, model.NotificationKindAssignmentCreated)
	}
	return a, nil
}

func (s *AssignmentService) List(ctx context.Context, projectID, userID uuid.UUID) ([]model.Assignment, error) {
	if err := s.requireAccess(ctx, userID, projectID); err != nil {
		return nil, err
	}
	fieldScoped, err := s.isFieldScoped(ctx, userID)
	if err != nil {
		return nil, err
	}
	if fieldScoped {
		return s.assignmentRepo.ListByUser(ctx, userID, projectID)
	}
	return s.assignmentRepo.ListByProject(ctx, projectID)
}

func (s *AssignmentService) Get(ctx context.Context, assignmentID, userID uuid.UUID) (*model.Assignment, error) {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("assignment not found")
	}
	if err := s.requireAccess(ctx, userID, a.ProjectID); err != nil {
		return nil, err
	}
	fieldScoped, err := s.isFieldScoped(ctx, userID)
	if err != nil {
		return nil, err
	}
	if fieldScoped {
		if (a.AssignedTo == nil || *a.AssignedTo != userID) && a.TeamID == nil {
			return nil, fmt.Errorf("access denied: this assignment is not yours")
		}
	}
	return a, nil
}

func (s *AssignmentService) Update(ctx context.Context, assignmentID, userID uuid.UUID, input CreateAssignmentInput) (*model.Assignment, error) {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("assignment not found")
	}
	if err := s.requireSupervisor(ctx, userID, a.ProjectID); err != nil {
		return nil, err
	}

	if input.Title != "" {
		a.Title = input.Title
	}
	if input.Instructions != "" {
		a.Instructions = input.Instructions
	}
	if input.TargetCount > 0 {
		a.TargetCount = input.TargetCount
	}
	if input.Priority != "" {
		a.Priority = input.Priority
	}
	if input.DueDate != nil {
		a.DueDate = input.DueDate
	}
	if input.FormID != nil {
		a.FormID = input.FormID
	}
	if input.LayerID != nil {
		a.LayerID = input.LayerID
	}

	if err := s.assignmentRepo.Update(ctx, a); err != nil {
		return nil, fmt.Errorf("failed to update assignment: %w", err)
	}
	return a, nil
}

func (s *AssignmentService) UpdateStatus(ctx context.Context, assignmentID, userID uuid.UUID, status string) error {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return fmt.Errorf("assignment not found")
	}
	if err := s.requireAccess(ctx, userID, a.ProjectID); err != nil {
		return err
	}

	validStatuses := map[string]bool{
		"pending": true, "in_progress": true, "completed": true, "cancelled": true,
	}
	if !validStatuses[status] {
		return fmt.Errorf("invalid status: %s", status)
	}
	return s.assignmentRepo.UpdateStatus(ctx, assignmentID, status)
}

func (s *AssignmentService) ExtendDueDate(ctx context.Context, assignmentID, userID uuid.UUID, newDueDate *time.Time) error {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return fmt.Errorf("assignment not found")
	}
	if err := s.requireSupervisor(ctx, userID, a.ProjectID); err != nil {
		return err
	}
	return s.assignmentRepo.UpdateDueDate(ctx, assignmentID, newDueDate)
}

func (s *AssignmentService) Reassign(ctx context.Context, assignmentID, userID uuid.UUID, assignedTo, teamID *uuid.UUID) error {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return fmt.Errorf("assignment not found")
	}
	if err := s.requireSupervisor(ctx, userID, a.ProjectID); err != nil {
		return err
	}
	if assignedTo == nil && teamID == nil {
		return fmt.Errorf("must reassign to a team or individual")
	}
	if assignedTo != nil && teamID != nil {
		return fmt.Errorf("can only assign to a team OR an individual, not both")
	}
	if assignedTo != nil {
		ok, err := s.access.CanAccess(ctx, *assignedTo, a.ProjectID)
		if err != nil || !ok {
			return fmt.Errorf("new assignee is not a member of this project")
		}
	}
	if err := s.assignmentRepo.Reassign(ctx, assignmentID, assignedTo, teamID); err != nil {
		return err
	}
	a.AssignedTo = assignedTo
	a.TeamID = teamID
	if s.notifications != nil {
		s.notifications.NotifyAssignment(ctx, a, model.NotificationKindAssignmentReassigned)
	}
	return nil
}

func (s *AssignmentService) Delete(ctx context.Context, assignmentID, userID uuid.UUID) error {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return fmt.Errorf("assignment not found")
	}
	if err := s.requireSupervisor(ctx, userID, a.ProjectID); err != nil {
		return err
	}
	return s.assignmentRepo.Delete(ctx, assignmentID)
}

func (s *AssignmentService) GetProgress(ctx context.Context, assignmentID, userID uuid.UUID) (*model.AssignmentProgress, error) {
	a, err := s.assignmentRepo.FindByID(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("assignment not found")
	}
	if err := s.requireAccess(ctx, userID, a.ProjectID); err != nil {
		return nil, err
	}
	return s.assignmentRepo.GetProgress(ctx, assignmentID)
}
