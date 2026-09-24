package service

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

// WritebackPrecaution is a registered risk for linked-table / DB reconcile.
// Blockers prevent Apply. Warnings with RequiresAck must be acknowledged.
type WritebackPrecaution struct {
	Code        string `json:"code"`
	Severity    string `json:"severity"` // blocker | warning | info
	Message     string `json:"message"`
	RequiresAck bool   `json:"requires_ack"`
	AckKey      string `json:"ack_key,omitempty"`
}

const (
	ackHardDelete    = "hard_delete"
	ackEvwTarget     = "evw_target"
	ackHomeDB        = "home_db_write"
	ackSkippedFields = "skipped_fields"
)

// assessWritebackPrecautions inspects data-source config + live relation metadata.
// Call with an open source DB. pendingDeletes / skippedAttrSamples / pendingGeomChanges
// drive conditional warnings.
func assessWritebackPrecautions(
	ctx context.Context,
	srcDB *sql.DB,
	ds *model.LayerDataSource,
	pendingDeletes int,
	skippedAttrSamples []string,
	pendingGeomChanges int,
) []WritebackPrecaution {
	var out []WritebackPrecaution

	schema := ds.SchemaName()
	table := ds.TableName()
	idCol := ds.IDColumn()
	geomCol := ds.GeometryColumn()

	if schema == "" || table == "" || idCol == "" {
		out = append(out, WritebackPrecaution{
			Code:     "missing_identity_config",
			Severity: "blocker",
			Message:  "Data source is missing schema, table, or id_column — cannot reconcile safely.",
		})
		return out
	}

	if geomCol == "" {
		out = append(out, WritebackPrecaution{
			Code:     "missing_geometry_column",
			Severity: "warning",
			Message:  "No geometry_column configured. Attribute writes may work; geometry changes will not be pushed.",
		})
	}

	// Relation kind — views / matviews / foreign tables must not be written blindly.
	kind, err := lookupRelationKind(ctx, srcDB, schema, table)
	if err != nil {
		out = append(out, WritebackPrecaution{
			Code:     "relation_unreadable",
			Severity: "blocker",
			Message:  fmt.Sprintf("Could not inspect %s.%s: %v", schema, table, err),
		})
	} else {
		switch kind {
		case "r", "p": // ordinary / partitioned table
			// ok
		case "v":
			out = append(out, WritebackPrecaution{
				Code:     "target_is_view",
				Severity: "blocker",
				Message: fmt.Sprintf(
					"%s.%s is a VIEW. Reconcile refuses to write views (often non-updatable or versioned). Point the data source at a base table.",
					schema, table,
				),
			})
		case "m":
			out = append(out, WritebackPrecaution{
				Code:     "target_is_matview",
				Severity: "blocker",
				Message:  fmt.Sprintf("%s.%s is a materialized view — not a valid reconcile target.", schema, table),
			})
		case "f":
			out = append(out, WritebackPrecaution{
				Code:     "target_is_foreign",
				Severity: "blocker",
				Message:  fmt.Sprintf("%s.%s is a foreign table — write-back is not supported.", schema, table),
			})
		default:
			out = append(out, WritebackPrecaution{
				Code:     "target_kind_unknown",
				Severity: "blocker",
				Message:  fmt.Sprintf("%s.%s has unsupported relation kind %q.", schema, table, kind),
			})
		}
	}

	// EVW naming — in this DB copies are base tables, but production ArcGIS EVWs are dangerous.
	lowerTable := strings.ToLower(table)
	if strings.Contains(lowerTable, "evw") || strings.HasSuffix(lowerTable, "_evw") {
		out = append(out, WritebackPrecaution{
			Code:        "evw_named_target",
			Severity:    "warning",
			RequiresAck: true,
			AckKey:      ackEvwTarget,
			Message: fmt.Sprintf(
				"Target %s.%s looks like an ArcGIS EVW name. Confirm it is a writable base table (not a versioned view) before applying.",
				schema, table,
			),
		})
	}

	strategy := ds.DeleteStrategy
	if strategy == "" {
		strategy = "hard"
	}
	switch strategy {
	case "hard":
		if pendingDeletes > 0 {
			out = append(out, WritebackPrecaution{
				Code:        "hard_delete",
				Severity:    "warning",
				RequiresAck: true,
				AckKey:      ackHardDelete,
				Message: fmt.Sprintf(
					"Delete strategy is hard: %d pending delete(s) will permanently DELETE rows from %s.%s.",
					pendingDeletes, schema, table,
				),
			})
		} else {
			out = append(out, WritebackPrecaution{
				Code:     "hard_delete_default",
				Severity: "info",
				Message:  "Delete strategy is hard. Future field deletes will permanently remove source rows unless you switch to soft delete.",
			})
		}
	case "soft":
		if ds.SoftDeleteColumn == "" {
			out = append(out, WritebackPrecaution{
				Code:     "soft_delete_misconfigured",
				Severity: "blocker",
				Message:  "delete_strategy=soft but soft_delete_column is empty.",
			})
		}
	default:
		out = append(out, WritebackPrecaution{
			Code:     "unknown_delete_strategy",
			Severity: "blocker",
			Message:  fmt.Sprintf("Unknown delete_strategy %q.", strategy),
		})
	}

	if ds.ConnectionID() == nil {
		out = append(out, WritebackPrecaution{
			Code:        "home_db_fallback",
			Severity:    "warning",
			RequiresAck: true,
			AckKey:      ackHomeDB,
			Message: "No connection_id on this data source — writes use the FC home database credentials. " +
				"Confirm that is intentional for production, or link a project connection profile.",
		})
	}

	if len(skippedAttrSamples) > 0 {
		shown := skippedAttrSamples
		if len(shown) > 12 {
			shown = shown[:12]
		}
		out = append(out, WritebackPrecaution{
			Code:        "skipped_fields",
			Severity:    "warning",
			RequiresAck: true,
			AckKey:      ackSkippedFields,
			Message: fmt.Sprintf(
				"Some collected attributes will not be written to the source table (form-only, attachments, or unknown columns): %s.",
				strings.Join(shown, ", "),
			),
		})
	}

	if pendingGeomChanges > 0 {
		if geomCol == "" {
			out = append(out, WritebackPrecaution{
				Code:     "geometry_writeback_no_column",
				Severity: "blocker",
				Message: fmt.Sprintf(
					"%d pending change(s) include geometry edits but geometry_column is not configured.",
					pendingGeomChanges,
				),
			})
		} else {
			out = append(out, WritebackPrecaution{
				Code:     "geometry_writeback",
				Severity: "info",
				Message: fmt.Sprintf(
					"%d pending change(s) will update %s.%s.%s via ST_GeomFromGeoJSON.",
					pendingGeomChanges, schema, table, geomCol,
				),
			})
		}
	}

	out = append(out, WritebackPrecaution{
		Code:     "dual_model",
		Severity: "info",
		Message: "Linked Features show the live source table; reconcile only applies pending collected rows in FC " +
			"(change_type inserted/updated/deleted). Live rows with no pending change are untouched.",
	})

	return out
}

func lookupRelationKind(ctx context.Context, db *sql.DB, schema, table string) (string, error) {
	var kind string
	err := db.QueryRowContext(ctx, `
		SELECT c.relkind::text
		FROM pg_class c
		JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE n.nspname = $1 AND c.relname = $2
	`, schema, table).Scan(&kind)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("relation not found")
	}
	return kind, err
}

func hasWritebackBlocker(ps []WritebackPrecaution) bool {
	for _, p := range ps {
		if p.Severity == "blocker" {
			return true
		}
	}
	return false
}

func requiredAckKeys(ps []WritebackPrecaution) []string {
	seen := map[string]bool{}
	var keys []string
	for _, p := range ps {
		if p.RequiresAck && p.AckKey != "" && !seen[p.AckKey] {
			seen[p.AckKey] = true
			keys = append(keys, p.AckKey)
		}
	}
	return keys
}

func missingAcknowledgments(required []string, provided []string) []string {
	have := map[string]bool{}
	for _, a := range provided {
		have[strings.TrimSpace(strings.ToLower(a))] = true
	}
	var missing []string
	for _, r := range required {
		if !have[strings.ToLower(r)] {
			missing = append(missing, r)
		}
	}
	return missing
}

// collectSkippedAttrSamples returns attribute keys from pending features that
// would not map onto the source table (attachments / unknown columns).
func collectSkippedAttrSamples(
	ctx context.Context,
	srcDB *sql.DB,
	ds *model.LayerDataSource,
	features []model.Feature,
) []string {
	schema := ds.SchemaName()
	table := ds.TableName()
	if schema == "" || table == "" || len(features) == 0 {
		return nil
	}
	cols, err := listSourceTableColumns(ctx, srcDB, schema, table)
	if err != nil || len(cols) == 0 {
		return nil
	}
	colSet := map[string]bool{}
	for _, c := range cols {
		colSet[strings.ToLower(c)] = true
	}
	idCol := strings.ToLower(ds.IDColumn())
	geomCol := strings.ToLower(ds.GeometryColumn())

	seen := map[string]bool{}
	var skipped []string
	for i := range features {
		attrs, err := decodeAttrs(features[i].Attributes)
		if err != nil {
			continue
		}
		for k, v := range attrs {
			lk := strings.ToLower(k)
			if lk == idCol || lk == geomCol {
				continue
			}
			if isAttachmentAttrValue(v) {
				if !seen[k] {
					seen[k] = true
					skipped = append(skipped, k+" (attachment)")
				}
				continue
			}
			if !colSet[lk] {
				if !seen[k] {
					seen[k] = true
					skipped = append(skipped, k)
				}
			}
		}
	}
	return skipped
}
