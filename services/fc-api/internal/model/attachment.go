package model

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type FeatureAttachment struct {
    bun.BaseModel `bun:"table:feature_attachments,alias:fa"`

    ID         uuid.UUID  `bun:"id,pk,type:uuid,default:gen_random_uuid()" json:"id"`
    FeatureID  *uuid.UUID `bun:"feature_id,type:uuid"                       json:"feature_id,omitempty"`
    ProjectID  uuid.UUID  `bun:"project_id,type:uuid,notnull"               json:"project_id"`
    ClientID   uuid.UUID  `bun:"client_id,type:uuid,notnull"                json:"client_id"`
    FieldID    string     `bun:"field_id,notnull"                            json:"field_id"`
    Kind       string     `bun:"kind,notnull"                                json:"kind"`

    // Storage
    StorageKey string `bun:"storage_key,notnull" json:"storage_key"`
    ThumbKey   string `bun:"thumb_key"            json:"thumb_key,omitempty"`

    // File metadata
    MimeType   string `bun:"mime_type"   json:"mime_type,omitempty"`
    SizeBytes  int64  `bun:"size_bytes"  json:"size_bytes,omitempty"`
    Width      int    `bun:"width"        json:"width,omitempty"`
    Height     int    `bun:"height"       json:"height,omitempty"`
    DurationMs int    `bun:"duration_ms"  json:"duration_ms,omitempty"`

    // Workflow
    Status     string          `bun:"status,default:'pending_upload'" json:"status"`
    Metadata   json.RawMessage `bun:"metadata,type:jsonb,default:'{}'::jsonb" json:"metadata,omitempty"`

    UploadedBy *uuid.UUID `bun:"uploaded_by,type:uuid" json:"uploaded_by,omitempty"`
    UploadedAt *time.Time `bun:"uploaded_at"            json:"uploaded_at,omitempty"`
    CreatedAt  time.Time  `bun:"created_at,nullzero,default:now()" json:"created_at"`
    UpdatedAt  time.Time  `bun:"updated_at,nullzero,default:now()" json:"updated_at"`
}

// Valid attachment kinds
var ValidAttachmentKinds = map[string]bool{
    "photo":         true,
    "audio":         true,
    "video":         true,
    "signature":     true,
    "barcode_image": true,
    "file":          true,
}

// Default max size by kind (in bytes)
var MaxSizeByKind = map[string]int64{
    "photo":         10 * 1024 * 1024,  // 10 MB
    "audio":         25 * 1024 * 1024,  // 25 MB
    "video":         100 * 1024 * 1024, // 100 MB
    "signature":     2 * 1024 * 1024,   // 2 MB
    "barcode_image": 5 * 1024 * 1024,   // 5 MB
    "file":          25 * 1024 * 1024,  // 25 MB
}