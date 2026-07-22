package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

// BundleHashService computes a content hash representing the current state
// of everything that could affect a project bundle's contents.
type BundleHashService struct {
	db *bun.DB
}

func NewBundleHashService(db *bun.DB) *BundleHashService {
	return &BundleHashService{db: db}
}

// Compute returns a SHA-256 hash of the current state.
// Two calls return the same hash IFF the underlying content has not changed.
//
// Signals included:
//   - project.updated_at (project metadata, AOI, basemap)
//   - MAX(forms.updated_at) for published forms in the project
//   - MAX(form_versions.published_at) for schema edits and publishes
//   - MAX(layers.updated_at) for published layers in the project
//   - MAX(choice_lists.updated_at) in the project
//   - MAX(features.updated_at) for reference features in this project (when includeRef)
//   - MAX(assignments.updated_at) for assignments targeting this user
//   - includeReferenceData flag
func (s *BundleHashService) Compute(
	ctx context.Context,
	projectID, userID uuid.UUID,
	includeReferenceData bool,
) (string, error) {
	type tsRow struct {
		Ts *time.Time `bun:"ts"`
	}

	var seedParts []string
	const BundleFormatVersion = "v6-linked-ref"

	// 0. Bundle format version (invalidates cache on writer changes)
	seedParts = append(seedParts, fmt.Sprintf("fmt:%s", BundleFormatVersion))

	// 1. Project itself
	var projectRow tsRow
	err := s.db.NewSelect().
		TableExpr("projects").
		ColumnExpr("updated_at AS ts").
		Where("id = ?", projectID).
		Scan(ctx, &projectRow)
	if err != nil {
		return "", fmt.Errorf("hash project: %w", err)
	}
	seedParts = append(seedParts, fmt.Sprintf("project:%s", tsStr(projectRow.Ts)))

	// 2. Published forms
	var formsRow tsRow
	_ = s.db.NewSelect().
		TableExpr("forms").
		ColumnExpr("MAX(updated_at) AS ts").
		Where("project_id = ?", projectID).
		Where("is_active = ?", true).
		Scan(ctx, &formsRow)
	seedParts = append(seedParts, fmt.Sprintf("forms:%s", tsStr(formsRow.Ts)))

	// 2b. Form versions — schema JSON lives on form_versions.schema, not on
	// forms.schema. Publishing a new version doesn't bump forms.updated_at,
	// so we hash MAX(published_at) across all published versions for this
	// project. Draft edits also touch this table.
	var fvRow tsRow
	_ = s.db.NewSelect().
		TableExpr("form_versions AS fv").
		ColumnExpr("MAX(fv.published_at) AS ts").
		Join("JOIN forms AS f ON f.id = fv.form_id").
		Where("f.project_id = ?", projectID).
		Where("f.is_active = ?", true).
		Scan(ctx, &fvRow)
	seedParts = append(seedParts, fmt.Sprintf("form_versions:%s", tsStr(fvRow.Ts)))

	// 3. Published layers
	var layersRow tsRow
	_ = s.db.NewSelect().
		TableExpr("layers").
		ColumnExpr("MAX(updated_at) AS ts").
		Where("project_id = ?", projectID).
		Where("status = ?", "published").
		Scan(ctx, &layersRow)
	seedParts = append(seedParts, fmt.Sprintf("layers:%s", tsStr(layersRow.Ts)))

	// 4. Choice lists
	var clRow tsRow
	_ = s.db.NewSelect().
		TableExpr("choice_lists").
		ColumnExpr("MAX(updated_at) AS ts").
		Where("project_id = ?", projectID).
		Scan(ctx, &clRow)
	seedParts = append(seedParts, fmt.Sprintf("choice_lists:%s", tsStr(clRow.Ts)))

	// 5. Reference features (only if includeRef)
	if includeReferenceData {
		var refRow tsRow
		_ = s.db.NewSelect().
			TableExpr("features AS f").
			ColumnExpr("MAX(f.updated_at) AS ts").
			Where("f.project_id = ?", projectID).
			Where("f.source = ?", "reference").
			Where("f.deleted_at IS NULL").
			Scan(ctx, &refRow)
		seedParts = append(seedParts, fmt.Sprintf("ref_features:%s", tsStr(refRow.Ts)))

		// Linked tables are not in public.features — fingerprint live row
		// counts so dbo changes invalidate the cache the same way.
		type linkedLayer struct {
			ID           uuid.UUID       `bun:"id"`
			SourceConfig json.RawMessage `bun:"source_config"`
		}
		var linked []linkedLayer
		_ = s.db.NewSelect().
			TableExpr("layers").
			ColumnExpr("id, source_config").
			Where("project_id = ?", projectID).
			Where("status = ?", "published").
			Where("source_type = ?", "linked_table").
			Scan(ctx, &linked)
		for _, ll := range linked {
			var cfg struct {
				Schema string `json:"schema"`
				Table  string `json:"table"`
			}
			_ = json.Unmarshal(ll.SourceConfig, &cfg)
			if cfg.Schema == "" || cfg.Table == "" {
				seedParts = append(seedParts, fmt.Sprintf("linked:%s:missing", ll.ID))
				continue
			}
			var count int
			q := fmt.Sprintf(
				`SELECT COUNT(*) FROM %s.%s`,
				pgQuoteIdent(cfg.Schema), pgQuoteIdent(cfg.Table),
			)
			if err := s.db.NewRaw(q).Scan(ctx, &count); err != nil {
				seedParts = append(seedParts, fmt.Sprintf("linked:%s:err", ll.ID))
				continue
			}
			seedParts = append(seedParts, fmt.Sprintf("linked:%s:%d", ll.ID, count))
		}
	} else {
		seedParts = append(seedParts, "ref_features:disabled")
	}

	// 6. User-scoped assignments
	var asgnRow tsRow
	_ = s.db.NewSelect().
		TableExpr("assignments AS a").
		ColumnExpr("MAX(a.updated_at) AS ts").
		Where("a.project_id = ?", projectID).
		Where("(a.assigned_to = ? OR a.team_id IN (?))",
			userID,
			s.db.NewSelect().TableExpr("team_members").Column("team_id").Where("user_id = ?", userID),
		).
		Scan(ctx, &asgnRow)
	seedParts = append(seedParts, fmt.Sprintf("assignments:%s", tsStr(asgnRow.Ts)))

	// 7. Reference data flag
	seedParts = append(seedParts, fmt.Sprintf("include_ref:%v", includeReferenceData))

	// Final hash
	seed := joinParts(seedParts)
	h := sha256.Sum256([]byte(seed))
	return hex.EncodeToString(h[:]), nil
}

func tsStr(t *time.Time) string {
	if t == nil {
		return "nil"
	}
	return t.UTC().Format(time.RFC3339Nano)
}

func joinParts(parts []string) string {
	out := ""
	for i, p := range parts {
		if i > 0 {
			out += "|"
		}
		out += p
	}
	return out
}
