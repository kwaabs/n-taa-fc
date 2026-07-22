package service

import (
    "context"
    "fmt"
    "strconv"

    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type FeatureService struct {
    featureRepo *repository.FeatureRepo
    memberRepo  *repository.MemberRepo
}

func NewFeatureService(featureRepo *repository.FeatureRepo, memberRepo *repository.MemberRepo) *FeatureService {
    return &FeatureService{featureRepo: featureRepo, memberRepo: memberRepo}
}

func (s *FeatureService) List(ctx context.Context, projectID, userID uuid.UUID, limit, offset int) ([]model.Feature, int, error) {
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
        return nil, 0, fmt.Errorf("access denied: not a member of this project")
    }
    if limit <= 0 {
        limit = 50
    }
    if limit > 500 {
        limit = 500
    }
    return s.featureRepo.ListByProject(ctx, projectID, limit, offset)
}

func (s *FeatureService) Get(ctx context.Context, featureID, userID uuid.UUID) (*model.Feature, error) {
    feature, err := s.featureRepo.FindByID(ctx, featureID)
    if err != nil {
        return nil, fmt.Errorf("feature not found")
    }
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, feature.ProjectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    return feature, nil
}

func (s *FeatureService) ListByBBox(ctx context.Context, projectID, userID uuid.UUID, bbox string) ([]model.Feature, error) {
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    // Parse bbox: "minLng,minLat,maxLng,maxLat"
    coords, err := parseBBox(bbox)
    if err != nil {
        return nil, err
    }
    return s.featureRepo.ListByBBox(ctx, projectID, coords[0], coords[1], coords[2], coords[3])
}

func (s *FeatureService) UpdateStatus(ctx context.Context, featureID, userID uuid.UUID, status, reviewNotes string) error {
    feature, err := s.featureRepo.FindByID(ctx, featureID)
    if err != nil {
        return fmt.Errorf("feature not found")
    }
    member, err := s.memberRepo.FindByProjectAndUser(ctx, feature.ProjectID, userID)
    if err != nil {
        return fmt.Errorf("access denied: not a member of this project")
    }

    validStatuses := map[string]bool{"draft": true, "submitted": true, "under_review": true, "approved": true, "rejected": true}
    if !validStatuses[status] {
        return fmt.Errorf("invalid status: %s", status)
    }

    // Only supervisors and admins can review
    if status == "approved" || status == "rejected" || status == "under_review" {
        if member.Role != "admin" && member.Role != "supervisor" {
            return fmt.Errorf("access denied: admin or supervisor role required for review actions")
        }
    }

    return s.featureRepo.UpdateStatus(ctx, featureID, status, &userID, reviewNotes)
}

func parseBBox(bbox string) ([4]float64, error) {
    var result [4]float64
    parts := splitComma(bbox)
    if len(parts) != 4 {
        return result, fmt.Errorf("bbox must have 4 comma-separated values: minLng,minLat,maxLng,maxLat")
    }
    for i, p := range parts {
        v, err := strconv.ParseFloat(p, 64)
        if err != nil {
            return result, fmt.Errorf("invalid bbox coordinate at position %d: %s", i, p)
        }
        result[i] = v
    }
    return result, nil
}

func splitComma(s string) []string {
    var parts []string
    current := ""
    for _, c := range s {
        if c == ',' {
            parts = append(parts, current)
            current = ""
        } else {
            current += string(c)
        }
    }
    parts = append(parts, current)
    return parts
}

func (s *FeatureService) ListByProjectAndLayer(ctx context.Context, projectID uuid.UUID, layerID *uuid.UUID, userID uuid.UUID, limit, offset int) ([]model.Feature, int, error) {
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
        return nil, 0, fmt.Errorf("access denied: not a project member")
    }
    return s.featureRepo.ListByProjectAndLayer(ctx, projectID, layerID, limit, offset)
}