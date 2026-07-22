package service

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type NotificationService struct {
	repo        *repository.NotificationRepo
	teamRepo    *repository.TeamRepo
	projectRepo *repository.ProjectRepo
	access      *AccessService
}

func NewNotificationService(
	repo *repository.NotificationRepo,
	teamRepo *repository.TeamRepo,
	projectRepo *repository.ProjectRepo,
	access *AccessService,
) *NotificationService {
	return &NotificationService{
		repo:        repo,
		teamRepo:    teamRepo,
		projectRepo: projectRepo,
		access:      access,
	}
}

func (s *NotificationService) List(
	ctx context.Context, userID uuid.UUID, unreadOnly bool, limit int,
) ([]model.Notification, error) {
	return s.repo.ListByUser(ctx, userID, unreadOnly, limit)
}

func (s *NotificationService) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.repo.CountUnread(ctx, userID)
}

func (s *NotificationService) MarkRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	return s.repo.MarkRead(ctx, userID, notificationID)
}

func (s *NotificationService) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	return s.repo.MarkAllRead(ctx, userID)
}

type SendMessageInput struct {
	ProjectID uuid.UUID
	Title     string
	Body      string
	TeamID    *uuid.UUID
	UserID    *uuid.UUID
}

type SendMessageResult struct {
	RecipientCount int `json:"recipient_count"`
}

// SendMessage posts a one-way supervisor message to a team or one user.
func (s *NotificationService) SendMessage(
	ctx context.Context, senderID uuid.UUID, in SendMessageInput,
) (*SendMessageResult, error) {
	ok, err := s.access.CanAccessWithRole(ctx, senderID, in.ProjectID, "supervisor")
	if err != nil {
		return nil, fmt.Errorf("access check failed: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	body := strings.TrimSpace(in.Body)
	if body == "" {
		return nil, fmt.Errorf("message body is required")
	}
	title := strings.TrimSpace(in.Title)
	if title == "" {
		title = "Message from supervisor"
	}

	if in.TeamID == nil && in.UserID == nil {
		return nil, fmt.Errorf("must send to a team or an individual")
	}
	if in.TeamID != nil && in.UserID != nil {
		return nil, fmt.Errorf("can only send to a team OR an individual, not both")
	}

	recipients, err := s.messageRecipients(ctx, in)
	if err != nil {
		return nil, err
	}
	if len(recipients) == 0 {
		return nil, fmt.Errorf("no recipients found")
	}

	projectName := "project"
	if p, err := s.projectRepo.FindByID(ctx, in.ProjectID); err == nil && p != nil {
		projectName = p.Name
	}

	// Body shown to field workers; append project for context.
	displayBody := fmt.Sprintf("%s · %s", body, projectName)

	rows := make([]model.Notification, 0, len(recipients))
	for _, uid := range recipients {
		rows = append(rows, model.Notification{
			UserID:    uid,
			ProjectID: in.ProjectID,
			Kind:      model.NotificationKindMessage,
			Title:     title,
			Body:      displayBody,
		})
	}
	if err := s.repo.CreateMany(ctx, rows); err != nil {
		return nil, fmt.Errorf("create notifications: %w", err)
	}
	return &SendMessageResult{RecipientCount: len(rows)}, nil
}

func (s *NotificationService) messageRecipients(
	ctx context.Context, in SendMessageInput,
) ([]uuid.UUID, error) {
	if in.UserID != nil {
		ok, err := s.access.CanAccess(ctx, *in.UserID, in.ProjectID)
		if err != nil || !ok {
			return nil, fmt.Errorf("recipient is not a member of this project")
		}
		return []uuid.UUID{*in.UserID}, nil
	}
	if in.TeamID != nil {
		// Team must be assigned to the project
		pts, err := s.teamRepo.ListProjectTeams(ctx, in.ProjectID)
		if err != nil {
			return nil, err
		}
		linked := false
		for _, pt := range pts {
			if pt.TeamID == *in.TeamID {
				linked = true
				break
			}
		}
		if !linked {
			return nil, fmt.Errorf("team is not assigned to this project")
		}
		members, err := s.teamRepo.ListMembers(ctx, *in.TeamID)
		if err != nil {
			return nil, err
		}
		ids := make([]uuid.UUID, 0, len(members))
		seen := map[uuid.UUID]struct{}{}
		for _, m := range members {
			if _, ok := seen[m.UserID]; ok {
				continue
			}
			seen[m.UserID] = struct{}{}
			ids = append(ids, m.UserID)
		}
		return ids, nil
	}
	return nil, nil
}

// NotifyAssignment fans out an in-app notification to the individual assignee
// or every member of the assigned team. Best-effort — never fails the caller.
func (s *NotificationService) NotifyAssignment(
	ctx context.Context,
	a *model.Assignment,
	kind string,
) {
	if a == nil {
		return
	}
	recipients, err := s.recipientsFor(ctx, a)
	if err != nil {
		slog.Warn("notification recipients", "error", err, "assignment_id", a.ID)
		return
	}
	if len(recipients) == 0 {
		return
	}

	projectName := "a project"
	if p, err := s.projectRepo.FindByID(ctx, a.ProjectID); err == nil && p != nil {
		projectName = p.Name
	}

	title := "New assignment"
	if kind == model.NotificationKindAssignmentReassigned {
		title = "Assignment reassigned to you"
	}
	body := a.Title
	if body == "" {
		body = "You have a new field assignment"
	}
	body = fmt.Sprintf("%s · %s", body, projectName)

	assignmentID := a.ID
	rows := make([]model.Notification, 0, len(recipients))
	for _, uid := range recipients {
		rows = append(rows, model.Notification{
			UserID:       uid,
			ProjectID:    a.ProjectID,
			AssignmentID: &assignmentID,
			Kind:         kind,
			Title:        title,
			Body:         body,
		})
	}
	if err := s.repo.CreateMany(ctx, rows); err != nil {
		slog.Warn("create notifications", "error", err, "assignment_id", a.ID, "count", len(rows))
	}
}

func (s *NotificationService) recipientsFor(ctx context.Context, a *model.Assignment) ([]uuid.UUID, error) {
	if a.AssignedTo != nil {
		return []uuid.UUID{*a.AssignedTo}, nil
	}
	if a.TeamID != nil {
		members, err := s.teamRepo.ListMembers(ctx, *a.TeamID)
		if err != nil {
			return nil, err
		}
		ids := make([]uuid.UUID, 0, len(members))
		for _, m := range members {
			ids = append(ids, m.UserID)
		}
		return ids, nil
	}
	return nil, nil
}
