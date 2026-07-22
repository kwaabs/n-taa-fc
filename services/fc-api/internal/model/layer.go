package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Layer struct {
	bun.BaseModel `bun:"table:layers,alias:l"`

	ID                 uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	ProjectID          uuid.UUID       `bun:"project_id,type:uuid,notnull"              json:"project_id"`
	Name               string          `bun:"name,notnull"                               json:"name"`
	GeometryType       string          `bun:"geometry_type,notnull"                      json:"geometry_type"`
	FormID             *uuid.UUID      `bun:"form_id,type:uuid"                          json:"form_id,omitempty"`
	Style              json.RawMessage `bun:"style,type:jsonb,default:'{}'::jsonb"       json:"style"`
	IsEditable         bool            `bun:"is_editable,default:false"                  json:"is_editable"`
	IsVisibleByDefault bool            `bun:"is_visible_by_default,default:true"         json:"is_visible_by_default"`
	SortOrder          int             `bun:"sort_order,default:0"                       json:"sort_order"`
	SourceType         string          `bun:"source_type,default:'collection'"           json:"source_type"`
	SourceConfig       json.RawMessage `bun:"source_config,type:jsonb"                   json:"source_config,omitempty"`
	CreatedAt          time.Time       `bun:"created_at,nullzero,default:now()"          json:"created_at"`
	UpdatedAt          time.Time       `bun:"updated_at,nullzero,default:now()"        json:"updated_at"`
	Status             string          `bun:"status,default:'draft'"  json:"status"`
	PublishedAt        *time.Time      `bun:"published_at"             json:"published_at,omitempty"`
	PublishedBy        *uuid.UUID      `bun:"published_by,type:uuid"   json:"published_by,omitempty"`

	// Bbox is the layer's spatial extent as [minLng, minLat, maxLng, maxLat].
	// Computed at query time from feature geometries; not stored.
	// Used by clients to auto-fit the map viewport to layer data.
	Bbox []float64 `bun:"bbox,scanonly,array" json:"bbox,omitempty"`

	// FeatureCount is set for linked_table layers (row count of the live
	// source table). Copied/external layers leave this nil — clients use
	// the features list meta.total instead.
	FeatureCount *int `bun:"-" json:"feature_count,omitempty"`
}
