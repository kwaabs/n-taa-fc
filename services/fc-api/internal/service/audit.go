package service

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

// Canonical audit column aliases we recognize on linked/external tables and forms.
var auditColumnAliases = map[string]string{
	"created_user":     "created_user",
	"created_by":       "created_user",
	"created_date":     "created_date",
	"created_at":       "created_date",
	"last_edited_user": "last_edited_user",
	"updated_by":       "last_edited_user",
	"last_edited_date": "last_edited_date",
	"last_edited_at":   "last_edited_date",
	"updated_at":       "last_edited_date",
	"device_id":        "device_id",
}

// AuditValues holds normalized provenance for inject / write-back.
type AuditValues struct {
	CreatedUser    string
	CreatedDate    string
	LastEditedUser string
	LastEditedDate string
	DeviceID       string
}

// AuditValuesFromFeature builds audit values from a feature + acting user.
// actorUserID is used for last_edited_* (write-back actor); falls back to collected_by.
func AuditValuesFromFeature(f *model.Feature, actorUserID uuid.UUID) AuditValues {
	createdUser := ""
	if f.CollectedBy != uuid.Nil {
		createdUser = f.CollectedBy.String()
	}
	editedUser := createdUser
	if actorUserID != uuid.Nil {
		editedUser = actorUserID.String()
	} else if f.ChangeBy != nil && *f.ChangeBy != uuid.Nil {
		editedUser = f.ChangeBy.String()
	}

	createdDate := ""
	if !f.CollectedAt.IsZero() {
		createdDate = f.CollectedAt.UTC().Format(time.RFC3339)
	} else if !f.CreatedAt.IsZero() {
		createdDate = f.CreatedAt.UTC().Format(time.RFC3339)
	} else {
		createdDate = time.Now().UTC().Format(time.RFC3339)
	}

	editedDate := time.Now().UTC().Format(time.RFC3339)
	if f.ChangeAt != nil && !f.ChangeAt.IsZero() {
		editedDate = f.ChangeAt.UTC().Format(time.RFC3339)
	} else if f.SyncedAt != nil && !f.SyncedAt.IsZero() {
		editedDate = f.SyncedAt.UTC().Format(time.RFC3339)
	}

	return AuditValues{
		CreatedUser:    createdUser,
		CreatedDate:    createdDate,
		LastEditedUser: editedUser,
		LastEditedDate: editedDate,
		DeviceID:       deviceIDFromJSON(f.DeviceInfo),
	}
}

func deviceIDFromJSON(raw json.RawMessage) string {
	if len(raw) == 0 {
		return ""
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return ""
	}
	for _, key := range []string{"device_id", "id", "deviceId"} {
		if v, ok := m[key]; ok && v != nil {
			s := strings.TrimSpace(fmt.Sprintf("%v", v))
			if s != "" && s != "<nil>" {
				return s
			}
		}
	}
	return ""
}

// ApplyAuditToAttrs sets audit keys on attrs for columns that exist in knownColumns.
// mode "insert" sets created_* + last_edited_*; "update" sets last_edited_* only.
// Only fills empty attribute values (does not overwrite non-empty field answers).
func ApplyAuditToAttrs(
	attrs map[string]any,
	knownColumns []string,
	values AuditValues,
	mode string,
) {
	if attrs == nil {
		return
	}
	known := make(map[string]string, len(knownColumns)) // lower -> actual name
	for _, c := range knownColumns {
		known[strings.ToLower(c)] = c
	}

	setIfKnown := func(alias, value string) {
		if value == "" {
			return
		}
		actual, ok := known[strings.ToLower(alias)]
		if !ok {
			return
		}
		if existing, exists := attrs[actual]; exists {
			if s := strings.TrimSpace(fmt.Sprintf("%v", existing)); s != "" && s != "<nil>" {
				return // keep existing non-empty value
			}
		}
		// Prefer exact case from knownColumns; also try alias if attrs used that key
		attrs[actual] = value
	}

	if mode == "insert" {
		setIfKnown("created_user", values.CreatedUser)
		setIfKnown("created_by", values.CreatedUser)
		setIfKnown("created_date", values.CreatedDate)
		setIfKnown("created_at", values.CreatedDate)
		setIfKnown("device_id", values.DeviceID)
	}
	setIfKnown("last_edited_user", values.LastEditedUser)
	setIfKnown("updated_by", values.LastEditedUser)
	setIfKnown("last_edited_date", values.LastEditedDate)
	setIfKnown("last_edited_at", values.LastEditedDate)
	setIfKnown("updated_at", values.LastEditedDate)
	if mode != "insert" {
		setIfKnown("device_id", values.DeviceID)
	}
}

// InjectAuditIntoExistingAttrs fills empty system audit keys already present in attrs.
func InjectAuditIntoExistingAttrs(attrs map[string]any, values AuditValues, mode string) {
	if len(attrs) == 0 {
		return
	}
	keys := make([]string, 0, len(attrs))
	for k := range attrs {
		lower := strings.ToLower(k)
		if _, ok := auditColumnAliases[lower]; ok {
			keys = append(keys, k)
		}
	}
	if len(keys) == 0 {
		return
	}
	ApplyAuditToAttrs(attrs, keys, values, mode)
}

// NormalizeAuditColumnName returns the canonical alias family for a column, or "".
func NormalizeAuditColumnName(name string) string {
	if v, ok := auditColumnAliases[strings.ToLower(name)]; ok {
		return v
	}
	return ""
}
