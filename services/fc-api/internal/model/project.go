package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Project struct {
	bun.BaseModel `bun:"table:projects,alias:p"`

	ID             uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()"   json:"id"`
	Name           string          `bun:"name,notnull"                                 json:"name"`
	Description    string          `bun:"description"                                  json:"description,omitempty"`
	Mode           string          `bun:"mode,notnull"                                 json:"mode"`
	Config         json.RawMessage `bun:"config,type:jsonb,default:'{}'::jsonb"        json:"config"`
	Status         string          `bun:"status,default:'draft'"                       json:"status"`
	CreatedBy      uuid.UUID       `bun:"created_by,type:uuid"                         json:"created_by"`
	Version        int             `bun:"version,default:1"                            json:"version"`
	AreaOfInterest json.RawMessage `bun:"area_of_interest,type:geometry(Geometry,4326)" json:"area_of_interest,omitempty"`
	CreatedAt      time.Time       `bun:"created_at,nullzero,default:now()"            json:"created_at"`
	UpdatedAt      time.Time       `bun:"updated_at,nullzero,default:now()"            json:"updated_at"`

	// Relations
	Members []ProjectMember `bun:"rel:has-many,join:id=project_id" json:"members,omitempty"`
}

type ProjectMember struct {
	bun.BaseModel `bun:"table:project_members,alias:pm"`

	ProjectID uuid.UUID `bun:"project_id,pk,type:uuid"               json:"project_id"`
	UserID    uuid.UUID `bun:"user_id,pk,type:uuid"                  json:"user_id"`
	Role      string    `bun:"role,notnull"                           json:"role"`
	IsActive  bool      `bun:"is_active,default:true"                 json:"is_active"`
	JoinedAt  time.Time `bun:"joined_at,nullzero,default:now()"       json:"joined_at"`

	// Relations
	User    *UserProfile `bun:"rel:belongs-to,join:user_id=id" json:"user,omitempty"`
	Project *Project     `bun:"rel:belongs-to,join:project_id=id" json:"project,omitempty"`
}

// ProjectWithRole is a convenience struct for listing projects with the current user's role.
type ProjectWithRole struct {
	Project
	Role string `json:"role"`
}


// AOIBufferMeters returns the configured AOI buffer distance in meters.
// Reads projects.config.aoi_buffer_meters if set, otherwise 20m default.
func (p *Project) AOIBufferMeters() int {
    if len(p.Config) == 0 {
        return 20
    }
    var cfg struct {
        AOIBufferMeters *int `json:"aoi_buffer_meters,omitempty"`
    }
    if err := json.Unmarshal(p.Config, &cfg); err != nil {
        return 20
    }
    if cfg.AOIBufferMeters != nil && *cfg.AOIBufferMeters >= 0 {
        return *cfg.AOIBufferMeters
    }
    return 20
}

// AOILayerID returns the linked polygon layer used to build the project AOI, if any.
// Field edits on that layer must be rejected while it is the AOI source.
func (p *Project) AOILayerID() *uuid.UUID {
	if len(p.Config) == 0 {
		return nil
	}
	var cfg struct {
		AOILayerID *uuid.UUID `json:"aoi_layer_id,omitempty"`
	}
	if err := json.Unmarshal(p.Config, &cfg); err != nil {
		return nil
	}
	if cfg.AOILayerID == nil || *cfg.AOILayerID == uuid.Nil {
		return nil
	}
	return cfg.AOILayerID
}

// IsAOILayer reports whether layerID is the project's AOI source layer.
func (p *Project) IsAOILayer(layerID uuid.UUID) bool {
	id := p.AOILayerID()
	return id != nil && *id == layerID
}