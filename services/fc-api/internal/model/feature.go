package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

type Feature struct {
	bun.BaseModel `bun:"table:features,alias:ft"`

	// ── Identity ──────────────────────────────────────────────
	ID       uuid.UUID `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
	ClientID uuid.UUID `bun:"client_id,type:uuid,notnull,unique"        json:"client_id"`

	// ── Relations ─────────────────────────────────────────────
	ProjectID    uuid.UUID  `bun:"project_id,type:uuid,notnull"  json:"project_id"`
	LayerID      *uuid.UUID `bun:"layer_id,type:uuid"            json:"layer_id,omitempty"`
	FormID       uuid.UUID  `bun:"form_id,type:uuid,notnull"     json:"form_id"`
	FormVersion  int        `bun:"form_version"                  json:"form_version"`
	AssignmentID *uuid.UUID `bun:"assignment_id,type:uuid"       json:"assignment_id,omitempty"`

	// ── Content ───────────────────────────────────────────────
	Geometry   *string         `bun:"geometry,type:geometry(Geometry,4326)" json:"geometry,omitempty"`
	Attributes json.RawMessage `bun:"attributes,type:jsonb,default:'{}'::jsonb" json:"attributes"`
	Status     string          `bun:"status,default:'draft'"                json:"status"`

	// ── Collection metadata ───────────────────────────────────
	CollectedBy uuid.UUID       `bun:"collected_by,type:uuid"   json:"collected_by"`
	CollectedAt time.Time       `bun:"collected_at,notnull"      json:"collected_at"`
	DeviceInfo  json.RawMessage `bun:"device_info,type:jsonb"    json:"device_info,omitempty"`
	GPSMetadata json.RawMessage `bun:"gps_metadata,type:jsonb"   json:"gps_metadata,omitempty"`
	SyncedAt    *time.Time      `bun:"synced_at"                 json:"synced_at,omitempty"`

	// ── Review workflow ───────────────────────────────────────
	ReviewedBy  *uuid.UUID `bun:"reviewed_by,type:uuid" json:"reviewed_by,omitempty"`
	ReviewedAt  *time.Time `bun:"reviewed_at"           json:"reviewed_at,omitempty"`
	ReviewNotes string     `bun:"review_notes"          json:"review_notes,omitempty"`

	// ── Reference data tracking ───────────────────────────────
	Source             string          `bun:"source,default:'collected'"      json:"source"`
	SourceRef          string          `bun:"source_ref"                       json:"source_ref,omitempty"`
	DataSourceID       *uuid.UUID      `bun:"data_source_id,type:uuid"         json:"data_source_id,omitempty"`
	ChangeType         string          `bun:"change_type"                       json:"change_type,omitempty"`
	ChangeAt           *time.Time      `bun:"change_at"                         json:"change_at,omitempty"`
	ChangeBy           *uuid.UUID      `bun:"change_by,type:uuid"               json:"change_by,omitempty"`
	OriginalAttributes json.RawMessage `bun:"original_attributes,type:jsonb"    json:"original_attributes,omitempty"`
	OriginalGeometry   *string         `bun:"original_geometry,type:geometry(Geometry,4326)" json:"original_geometry,omitempty"`
	DeletedAt          *time.Time      `bun:"deleted_at"                        json:"deleted_at,omitempty"`

	// ── Audit ─────────────────────────────────────────────────
	CreatedAt time.Time `bun:"created_at,nullzero,default:now()" json:"created_at"`
	UpdatedAt time.Time `bun:"updated_at,nullzero,default:now()" json:"updated_at"`

	// Computed: true when reconciliation_log has an 'applied' row for this
	// feature_id + change_type. Not a DB column.
	WriteBackApplied bool `bun:"write_back_applied,scanonly" json:"write_back_applied"`
}
