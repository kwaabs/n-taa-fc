package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type MemberService struct {
	memberRepo  *repository.MemberRepo
	userRepo    *repository.UserRepo
	projectRepo *repository.ProjectRepo
}

func NewMemberService(memberRepo *repository.MemberRepo, userRepo *repository.UserRepo, projectRepo *repository.ProjectRepo) *MemberService {
	return &MemberService{
		memberRepo:  memberRepo,
		userRepo:    userRepo,
		projectRepo: projectRepo,
	}
}

// List returns all members of a project. The requesting user must be a member.
func (s *MemberService) List(ctx context.Context, projectID, userID uuid.UUID) ([]model.ProjectMember, error) {
	// Check the requesting user is a member
	_, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("access denied: you are not a member of this project")
	}

	return s.memberRepo.ListByProject(ctx, projectID)
}

// Add adds a new member to a project by email. Only admins can add members.
func (s *MemberService) Add(ctx context.Context, projectID, requestingUserID uuid.UUID, email, role string) (*model.ProjectMember, error) {
	// Check admin role
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, requestingUserID)
	if err != nil || member.Role != "admin" {
		return nil, fmt.Errorf("access denied: admin role required to add members")
	}

	// Find user by email
	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return nil, fmt.Errorf("user with email '%s' not found. they must sign in at least once before being added", email)
	}

		// Check if already a member of THIS project.
	// FindByProjectAndUser returns an error (sql.ErrNoRows) when not found,
	// so we must check the error, not just the pointer.
	existing, findErr := s.memberRepo.FindByProjectAndUser(ctx, projectID, user.ID)
	if findErr == nil && existing != nil {
		return nil, fmt.Errorf("user is already a member of this project")
	}

	// Add member
	newMember := &model.ProjectMember{
		ProjectID: projectID,
		UserID:    user.ID,
		Role:      role,
		IsActive:  true,
	}
	if err := s.memberRepo.Add(ctx, newMember); err != nil {
		return nil, fmt.Errorf("failed to add member: %w", err)
	}

	// Load user details for response
	newMember.User = user
	return newMember, nil
}

// UpdateRole changes a member's role. Only admins can change roles.
// Prevents demoting the last admin.
func (s *MemberService) UpdateRole(ctx context.Context, projectID, requestingUserID, targetUserID uuid.UUID, newRole string) error {
	// Check admin role
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, requestingUserID)
	if err != nil || member.Role != "admin" {
		return fmt.Errorf("access denied: admin role required")
	}

	// If demoting an admin, ensure they're not the last one
	targetMember, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, targetUserID)
	if err != nil {
		return fmt.Errorf("target user is not a member of this project")
	}

	if targetMember.Role == "admin" && newRole != "admin" {
		adminCount, err := s.memberRepo.CountAdmins(ctx, projectID)
		if err != nil {
			return fmt.Errorf("failed to check admin count: %w", err)
		}
		if adminCount <= 1 {
			return fmt.Errorf("cannot demote the last admin of the project")
		}
	}

	return s.memberRepo.UpdateRole(ctx, projectID, targetUserID, newRole)
}

// Remove removes a member from a project. Only admins can remove members.
// Prevents removing the last admin.
func (s *MemberService) Remove(ctx context.Context, projectID, requestingUserID, targetUserID uuid.UUID) error {
	// Check admin role
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, requestingUserID)
	if err != nil || member.Role != "admin" {
		return fmt.Errorf("access denied: admin role required")
	}

	// Check if removing an admin
	targetMember, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, targetUserID)
	if err != nil {
		return fmt.Errorf("target user is not a member of this project")
	}

	if targetMember.Role == "admin" {
		adminCount, err := s.memberRepo.CountAdmins(ctx, projectID)
		if err != nil {
			return fmt.Errorf("failed to check admin count: %w", err)
		}
		if adminCount <= 1 {
			return fmt.Errorf("cannot remove the last admin of the project")
		}
	}

	return s.memberRepo.Remove(ctx, projectID, targetUserID)
}
