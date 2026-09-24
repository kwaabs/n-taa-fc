package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/geostyle"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type StyleService struct {
	db         *bun.DB
	layerRepo  *repository.LayerRepo
	memberRepo *repository.MemberRepo
}

func NewStyleService(db *bun.DB, layerRepo *repository.LayerRepo, memberRepo *repository.MemberRepo) *StyleService {
	return &StyleService{db: db, layerRepo: layerRepo, memberRepo: memberRepo}
}

// UpdateStyle replaces the layer's style.
// Linked dbo layers write to app.layers (shared with geo); others write public.layers.style.
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
	if style == nil {
		return nil, fmt.Errorf("style body required")
	}
	if err := style.Validate(); err != nil {
		return nil, fmt.Errorf("style validation failed: %w", err)
	}

	if layer.SourceType == "linked_table" {
		resolved, err := geostyle.SaveLinkedStyle(ctx, s.db, layer, style)
		if err != nil {
			return nil, err
		}
		raw, err := resolved.MarshalToRaw()
		if err != nil {
			return nil, err
		}
		// Cache resolved FC style on public.layers and bump updated_at so
		// core-pack hashes invalidate and mobile offline downloads pick up
		// color/size/icon changes (app.layers alone was not hashed before).
		layer.Style = raw
		layer.UpdatedAt = time.Now()
		if err := s.layerRepo.Update(ctx, layer); err != nil {
			return nil, fmt.Errorf("failed to sync linked style to layer row: %w", err)
		}
		return layer, nil
	}

	raw, err := style.MarshalToRaw()
	if err != nil {
		return nil, err
	}
	layer.Style = raw
	if err := s.layerRepo.Update(ctx, layer); err != nil {
		return nil, fmt.Errorf("failed to update layer: %w", err)
	}
	return layer, nil
}

// GetStyle returns the parsed style of a layer.
// Linked dbo layers resolve live from app.layers.
func (s *StyleService) GetStyle(ctx context.Context, layerID uuid.UUID) (*model.LayerStyle, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}

	return geostyle.ResolveLayerStyle(ctx, s.db, layer)
}
