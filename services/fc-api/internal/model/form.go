package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Form struct {
	bun.BaseModel `bun:"table:forms,alias:f"`

	ID          uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	ProjectID   uuid.UUID       `bun:"project_id,type:uuid,notnull"              json:"project_id"`
	Name        string          `bun:"name,notnull"                               json:"name"`
	Description string          `bun:"description"                                json:"description,omitempty"`
	Schema      json.RawMessage `bun:"schema,type:jsonb,notnull"                  json:"schema"`
	Version     int             `bun:"version,default:1"                          json:"version"`
	IsActive    bool            `bun:"is_active,default:true"                     json:"is_active"`
	CreatedAt   time.Time       `bun:"created_at,nullzero,default:now()"          json:"created_at"`
	UpdatedAt   time.Time       `bun:"updated_at,nullzero,default:now()"          json:"updated_at"`

	// Relations
	Versions []FormVersion `bun:"rel:has-many,join:id=form_id" json:"versions,omitempty"`
}

type FormVersion struct {
	bun.BaseModel `bun:"table:form_versions,alias:fv"`

	ID          uuid.UUID       `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	FormID      uuid.UUID       `bun:"form_id,type:uuid,notnull"                 json:"form_id"`
	Version     int             `bun:"version,notnull"                            json:"version"`
	Schema      json.RawMessage `bun:"schema,type:jsonb,notnull"                  json:"schema"`
	PublishedAt *time.Time      `bun:"published_at"                               json:"published_at,omitempty"`
	IsDraft     bool            `bun:"is_draft,default:true"                      json:"is_draft"`
	Changelog   string          `bun:"changelog"                                  json:"changelog,omitempty"`
}
