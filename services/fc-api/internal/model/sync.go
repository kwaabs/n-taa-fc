package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type SyncManifest struct {
	ProjectConfigVersion int       `json:"project_config_version"`
	FormsChanged         bool      `json:"forms_changed"`
	FeaturesUpdated      int       `json:"features_updated"`
	AssignmentsNew       int       `json:"assignments_new"`
	ServerTime           time.Time `json:"server_time"`
}

type SyncPushPayload struct {
	Trigger string `json:"trigger,omitempty"` // 👈 NEW

	Features []SyncFeature `json:"features"`
}

type SyncFeature struct {
	ClientID     uuid.UUID        `json:"client_id"`
	AssignmentID *uuid.UUID       `json:"assignment_id,omitempty"`
	LayerID      *uuid.UUID       `json:"layer_id,omitempty"`
	FormID       uuid.UUID        `json:"form_id"`
	FormVersion  int              `json:"form_version"`
	Geometry     *json.RawMessage `json:"geometry,omitempty"`
	Attributes   json.RawMessage  `json:"attributes"`
	Status       string           `json:"status"`
	CollectedAt  time.Time        `json:"collected_at"`
	DeviceInfo   json.RawMessage  `json:"device_info,omitempty"`
	GPSMetadata  json.RawMessage  `json:"gps_metadata,omitempty"`

	AttachmentClientIDs []uuid.UUID `json:"attachment_client_ids,omitempty"`

	// ── D1.2: reference-edit linkage ──
	SourceRef          *string         `json:"source_ref,omitempty"`
	DataSourceID       *uuid.UUID      `json:"data_source_id,omitempty"`
	OriginalAttributes json.RawMessage  `json:"original_attributes,omitempty"`
	OriginalGeometry   *json.RawMessage `json:"original_geometry,omitempty"` // GeoJSON object (same as geometry)
	Deleted            bool             `json:"deleted,omitempty"`
	DeletedAt          *time.Time       `json:"deleted_at,omitempty"`
}
type SyncPushReceipt struct {
	SyncLogID uuid.UUID `json:"sync_log_id"` // 👈 NEW

	Accepted int                `json:"accepted"`
	Flagged  int                `json:"flagged"`
	Errors   []SyncFeatureError `json:"errors,omitempty"`
}

type SyncFeatureError struct {
	ClientID uuid.UUID        `json:"client_id"`
	Issues   []SyncFieldError `json:"issues"`
	Action   string           `json:"action"`
}

type SyncFieldError struct {
	FieldID string `json:"field_id"`
	Message string `json:"message"`
}

type SyncPullResponse struct {
	Config      json.RawMessage `json:"config"`
	Forms       []Form          `json:"forms"`
	Features    []Feature       `json:"features"`
	Assignments []Assignment    `json:"assignments"`
}
