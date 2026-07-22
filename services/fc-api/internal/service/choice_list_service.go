package service

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type ChoiceListService struct {
    choiceListRepo *repository.ChoiceListRepo
    memberRepo     *repository.MemberRepo
}

func NewChoiceListService(choiceListRepo *repository.ChoiceListRepo, memberRepo *repository.MemberRepo) *ChoiceListService {
    return &ChoiceListService{choiceListRepo: choiceListRepo, memberRepo: memberRepo}
}

func (s *ChoiceListService) Create(ctx context.Context, userID, projectID uuid.UUID, name string, choices json.RawMessage) (*model.ChoiceList, error) {
    member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        return nil, fmt.Errorf("access denied: admin or supervisor role required")
    }
    if name == "" {
        return nil, fmt.Errorf("name is required")
    }
    if choices == nil {
        choices = json.RawMessage(`[]`)
    }
    cl := &model.ChoiceList{ProjectID: projectID, Name: name, Choices: choices}
    if err := s.choiceListRepo.Create(ctx, cl); err != nil {
        return nil, fmt.Errorf("failed to create choice list: %w", err)
    }
    return cl, nil
}

func (s *ChoiceListService) List(ctx context.Context, projectID, userID uuid.UUID) ([]model.ChoiceList, error) {
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    return s.choiceListRepo.ListByProject(ctx, projectID)
}

func (s *ChoiceListService) Get(ctx context.Context, id, userID uuid.UUID) (*model.ChoiceList, error) {
    cl, err := s.choiceListRepo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("choice list not found")
    }
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, cl.ProjectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    return cl, nil
}

func (s *ChoiceListService) Update(ctx context.Context, id, userID uuid.UUID, name *string, choices *json.RawMessage) (*model.ChoiceList, error) {
    cl, err := s.choiceListRepo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("choice list not found")
    }
    member, err := s.memberRepo.FindByProjectAndUser(ctx, cl.ProjectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        return nil, fmt.Errorf("access denied: admin or supervisor role required")
    }
    if name != nil { cl.Name = *name }
    if choices != nil { cl.Choices = *choices }
    if err := s.choiceListRepo.Update(ctx, cl); err != nil {
        return nil, fmt.Errorf("failed to update choice list: %w", err)
    }
    return cl, nil
}

func (s *ChoiceListService) Delete(ctx context.Context, id, userID uuid.UUID) error {
    cl, err := s.choiceListRepo.FindByID(ctx, id)
    if err != nil {
        return fmt.Errorf("choice list not found")
    }
    member, err := s.memberRepo.FindByProjectAndUser(ctx, cl.ProjectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        return fmt.Errorf("access denied: admin or supervisor role required")
    }
    return s.choiceListRepo.Delete(ctx, id)
}