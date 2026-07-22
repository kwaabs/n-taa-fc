package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type StyleService struct {
	layerRepo  *repository.LayerRepo
	memberRepo *repository.MemberRepo
}

func NewStyleService(layerRepo *repository.LayerRepo, memberRepo *repository.MemberRepo) *StyleService {
	return &StyleService{layerRepo: layerRepo, memberRepo: memberRepo}
}

// UpdateStyle replaces the layer's style. Validates first.
func (s *StyleService) UpdateStyle(ctx context.Context, layerID, userID uuid.UUID, rawStyle json.RawMessage) (*model.Layer, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}

	member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	style, err := model.UnmarshalStyle(rawStyle)
	if err != nil {
		return nil, fmt.Errorf("invalid style JSON: %w", err)
	}

	if style != nil {
		if err := style.Validate(); err != nil {
			return nil, fmt.Errorf("style validation failed: %w", err)
		}
		raw, err := style.MarshalToRaw()
		if err != nil {
			return nil, err
		}
		layer.Style = raw
	} else {
		layer.Style = json.RawMessage("{}")
	}

	if err := s.layerRepo.Update(ctx, layer); err != nil {
		return nil, fmt.Errorf("failed to update layer: %w", err)
	}

	return layer, nil
}

// GetStyle returns the parsed style of a layer (with default fallback).
func (s *StyleService) GetStyle(ctx context.Context, layerID uuid.UUID) (*model.LayerStyle, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}

	style, err := model.UnmarshalStyle(layer.Style)
	if err != nil {
		return nil, err
	}

	if style == nil {
		style = model.DefaultStyle(layer.GeometryType)
	}

	return style, nil
}
