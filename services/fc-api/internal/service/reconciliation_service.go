package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

// ReconciliationService computes and orchestrates pushback of field changes
// to source data sources. For D2.3 it only does the read-only Preview pass.
type ReconciliationService struct {
	db                 *sql.DB // unused for now — kept for symmetry with other services
	featureRepo        *repository.FeatureRepo
	dataSourceRepo     *repository.DataSourceRepo
	layerRepo          *repository.LayerRepo
	memberRepo         *repository.MemberRepo
	projectRepo        *repository.ProjectRepo
	reconciliationRepo *repository.ReconciliationRepo
	connOpener         *SourceConnectionOpener
}

func NewReconciliationService(
	featureRepo *repository.FeatureRepo,
	dataSourceRepo *repository.DataSourceRepo,
	layerRepo *repository.LayerRepo,
	memberRepo *repository.MemberRepo,
	projectRepo *repository.ProjectRepo,
	reconciliationRepo *repository.ReconciliationRepo,
	connOpener *SourceConnectionOpener,
) *ReconciliationService {
	return &ReconciliationService{
		featureRepo:        featureRepo,
		dataSourceRepo:     dataSourceRepo,
		layerRepo:          layerRepo,
		memberRepo:         memberRepo,
		projectRepo:        projectRepo,
		reconciliationRepo: reconciliationRepo,
		connOpener:         connOpener,
	}
}

// ── Public API ─────────────────────────────────────────

// PreviewResult is what /preview returns to the admin.
type PreviewResult struct {
	JobID           uuid.UUID             `json:"job_id"`
	DataSource      DataSourceBrief       `json:"data_source"`
	Summary         PreviewSummary        `json:"summary"`
	ByChangeType    ByChangeType          `json:"by_change_type"`
	SampleSafe      []SampleRow           `json:"sample_safe,omitempty"`
	SampleConflicts []SampleRow           `json:"sample_conflicts,omitempty"`
	Precautions     []WritebackPrecaution `json:"precautions,omitempty"`
	ApplyBlocked    bool                  `json:"apply_blocked"`
	RequiredAcks    []string              `json:"required_acknowledgments,omitempty"`
}

type DataSourceBrief struct {
	ID     uuid.UUID `json:"id"`
	Name   string    `json:"name"`
	Schema string    `json:"schema"`
	Table  string    `json:"table"`
}

type PreviewSummary struct {
	TotalPending    int `json:"total_pending"`
	SafeToApply     int `json:"safe_to_apply"`
	Conflicts       int `json:"conflicts"`
	AlreadyApplied  int `json:"already_applied"`
	UnreachableRows int `json:"unreachable_rows"` // source row vanished/missing
}

type ByChangeType struct {
	Updated  TypeCounts `json:"updated"`
	Deleted  TypeCounts `json:"deleted"`
	Inserted TypeCounts `json:"inserted"`
}

type TypeCounts struct {
	Safe     int `json:"safe"`
	Conflict int `json:"conflict"`
}

type SampleRow struct {
	FeatureID         uuid.UUID `json:"feature_id"`
	SourceRef         string    `json:"source_ref"`
	ChangeType        string    `json:"change_type"`
	ChangingFields    []string  `json:"changing_fields,omitempty"`
	ConflictingFields []string  `json:"conflicting_fields,omitempty"`
}

// Preview runs a dry-run reconciliation pass for one data source.
// It opens the source DB, classifies every pending change, persists detected
// conflicts, and returns a summary admin can review before clicking Apply.
//
// IMPORTANT: This does NOT modify the source DB. Conflicts are written to FC's
// own DB (reconciliation_conflicts) so the Conflicts page can list them.
func (s *ReconciliationService) Preview(
	ctx context.Context,
	projectID, layerID, dataSourceID, userID uuid.UUID,
	batchSize int,
	featureIDs ...uuid.UUID,
) (*PreviewResult, error) {
	if batchSize <= 0 {
		batchSize = 500
	}

	// 1. Membership check
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}

	if err := s.rejectAOILayer(ctx, projectID, layerID); err != nil {
		return nil, err
	}

	// 2. Load data source + verify it's owned by the layer
	ds, err := s.dataSourceRepo.FindByID(ctx, dataSourceID)
	if err != nil {
		return nil, fmt.Errorf("data source not found: %w", err)
	}
	if ds.LayerID != layerID {
		return nil, fmt.Errorf("data source %s does not belong to layer %s", dataSourceID, layerID)
	}
	schema := ds.SchemaName()
	table := ds.TableName()
	idCol := ds.IDColumn()
	if schema == "" || table == "" || idCol == "" {
		return nil, fmt.Errorf("data source %s is missing schema/table/id_column config; cannot reconcile", ds.ID)
	}

	// 3. Open source DB connection (FAIL FAST if unreachable / inline import)
	srcDB, err := s.connOpener.OpenForDataSource(ctx, ds)
	if err != nil {
		return nil, fmt.Errorf("open source connection: %w", err)
	}
	defer srcDB.Close()

	// 4. Create the preview job upfront so conflicts can reference it
	job := &model.ReconciliationJob{
		ProjectID:    projectID,
		LayerID:      layerID,
		DataSourceID: dataSourceID,
		Mode:         "preview",
		Status:       "running",
		BatchSize:    batchSize,
		CreatedBy:    &userID,
	}
	now := time.Now()
	job.StartedAt = &now
	if err := s.reconciliationRepo.CreateJob(ctx, job); err != nil {
		return nil, fmt.Errorf("create preview job: %w", err)
	}

	// 5. Iterate pending changes in chunks. Classify each.
	result := &PreviewResult{
		JobID:      job.ID,
		DataSource: DataSourceBrief{ID: ds.ID, Name: ds.Name, Schema: schema, Table: table},
	}
	const sampleLimit = 10

	totalUpdatesAttempted := 0
	totalUpdatesSucceeded := 0
	totalDeletesAttempted := 0
	totalDeletesSucceeded := 0
	totalInsertsAttempted := 0
	totalInsertsSucceeded := 0
	totalConflicts := 0
	totalErrors := 0

	var allPendingForHonesty []model.Feature
	pendingGeomChanges := 0

	offset := 0
	for {
		batch, err := s.featureRepo.ListPendingChanges(ctx, dataSourceID, batchSize, offset, featureIDs...)
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("list pending changes: %w", err)
		}
		if len(batch) == 0 {
			break
		}
		if len(allPendingForHonesty) < 200 {
			remain := 200 - len(allPendingForHonesty)
			if remain > len(batch) {
				remain = len(batch)
			}
			allPendingForHonesty = append(allPendingForHonesty, batch[:remain]...)
		}

		// Group by sourceRef so we can bulk-query the source DB once per chunk
		srcRefs := make([]string, 0, len(batch))
		bySrcRef := make(map[string]*model.Feature, len(batch))
		for i := range batch {
			f := &batch[i]
			if f.SourceRef == "" {
				totalErrors++
				continue
			}
			srcRefs = append(srcRefs, f.SourceRef)
			bySrcRef[f.SourceRef] = f
		}

		// Bulk-fetch source rows
		sourceRows, err := fetchSourceRowsByIDs(ctx, srcDB, schema, table, idCol, srcRefs)
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("fetch source rows: %w", err)
		}

		// Classify each feature
		for _, f := range batch {
			if f.SourceRef == "" {
				continue
			}

			switch f.ChangeType {
			case "updated":
				result.Summary.TotalPending++
				totalUpdatesAttempted++
				if resolved, _ := s.findResolution(ctx, f.ID, "updated"); resolved != nil {
					if resolved.Resolution != nil && *resolved.Resolution == "source_wins" {
						// Admin chose to not apply. Hide entirely from preview output.

						// Decrement TotalPending so the counts stay consistent.

						result.Summary.TotalPending--
						totalUpdatesAttempted--

						continue
					}

					// field_wins or manual → will be applied at Apply time
					result.Summary.SafeToApply++
					result.ByChangeType.Updated.Safe++
					totalUpdatesSucceeded++

					addSample(&result.SampleSafe, sampleLimit, f, []string{"(resolved)"})
					continue
				}

				// Parse our snapshot + the new field values
				origAttrs, _ := decodeAttrs(f.OriginalAttributes)
				newAttrs, _ := decodeAttrs(f.Attributes)
				srcRow, foundOnSource := sourceRows[f.SourceRef]

				if !foundOnSource {
					// Source row vanished — admin must triage. Treat as conflict.
					result.Summary.UnreachableRows++
					totalConflicts++
					result.ByChangeType.Updated.Conflict++
					if err := s.persistConflict(ctx, job, &f, origAttrs, newAttrs, nil, []string{"_source_row_missing"}); err != nil {
						slog.Error("[reconcile] persistConflict (missing) failed",
							"feature_id", f.ID, "source_ref", f.SourceRef, "error", err)
					}
					addSample(&result.SampleConflicts, sampleLimit, f, []string{"_source_row_missing"})
					continue
				}

				fieldChanged := changedFields(origAttrs, newAttrs)
				if gChanged, _ := geomChanged(&f); gChanged {
					fieldChanged = append(fieldChanged, "__geometry__")
					pendingGeomChanges++
				}
				sourceChanged := changedFieldsInBoth(origAttrs, srcRow)
				conflicting := intersect(fieldChanged, sourceChanged)

				if len(conflicting) == 0 {
					result.Summary.SafeToApply++
					result.ByChangeType.Updated.Safe++
					totalUpdatesSucceeded++ // would-succeed in dry run
					addSample(&result.SampleSafe, sampleLimit, f, fieldChanged)
				} else {
					result.Summary.Conflicts++
					totalConflicts++
					result.ByChangeType.Updated.Conflict++
					if err := s.persistConflict(ctx, job, &f, origAttrs, newAttrs, srcRow, conflicting); err != nil {
						slog.Error("[reconcile] persistConflict (update) failed",
							"feature_id", f.ID, "source_ref", f.SourceRef, "error", err)
					}
					addSample(&result.SampleConflicts, sampleLimit, f, conflicting)
				}

			case "deleted":
				result.Summary.TotalPending++
				totalDeletesAttempted++

				if resolved, _ := s.findResolution(ctx, f.ID, "deleted"); resolved != nil {

					if resolved.Resolution != nil && *resolved.Resolution == "source_wins" {
						// Admin chose NOT to apply — hide entirely from preview output.
						result.Summary.TotalPending--
						totalDeletesAttempted--
						continue
					}

					// field_wins or manual → will be applied at Apply time
					result.Summary.SafeToApply++
					result.ByChangeType.Deleted.Safe++
					totalDeletesSucceeded++
					addSample(&result.SampleSafe, sampleLimit, f, nil)
					continue

				}

				origAttrs, _ := decodeAttrs(f.OriginalAttributes)
				srcRow, foundOnSource := sourceRows[f.SourceRef]

				if !foundOnSource {
					// Already deleted at source — count as safe (it's gone, which is what we want)
					result.Summary.SafeToApply++
					result.ByChangeType.Deleted.Safe++
					totalDeletesSucceeded++
					addSample(&result.SampleSafe, sampleLimit, f, nil)
					continue
				}

				// If source row differs from our snapshot → admin should know before deletion
				sourceChanged := changedFieldsInBoth(origAttrs, srcRow)
				if len(sourceChanged) > 0 {
					result.Summary.Conflicts++
					totalConflicts++
					result.ByChangeType.Deleted.Conflict++
					if err := s.persistConflict(ctx, job, &f, origAttrs, nil, srcRow, sourceChanged); err != nil {
						slog.Error("[reconcile] persistConflict (delete) failed",
							"feature_id", f.ID, "source_ref", f.SourceRef, "error", err)
					}
					addSample(&result.SampleConflicts, sampleLimit, f, sourceChanged)
				} else {
					result.Summary.SafeToApply++
					result.ByChangeType.Deleted.Safe++
					totalDeletesSucceeded++
					addSample(&result.SampleSafe, sampleLimit, f, nil)
				}

			case "inserted":
				result.Summary.TotalPending++
				totalInsertsAttempted++
				result.Summary.SafeToApply++
				result.ByChangeType.Inserted.Safe++
				totalInsertsSucceeded++
				addSample(&result.SampleSafe, sampleLimit, f, nil)

			default:
				totalErrors++
			}
		}

		offset += len(batch)
		if len(batch) < batchSize {
			break
		}
	}

	// 6. Finalize the job
	_ = s.reconciliationRepo.IncrementCounters(
		ctx,
		job.ID,
		totalInsertsAttempted, totalInsertsSucceeded,
		totalUpdatesAttempted, totalUpdatesSucceeded,
		totalDeletesAttempted, totalDeletesSucceeded,
		totalConflicts, totalErrors,
	)

	// Update changes_total separately
	if err := s.updateChangesTotal(ctx, job.ID, result.Summary.TotalPending); err != nil {
		slog.Warn("update changes_total failed (non-fatal)", "error", err)
	}

	summaryJSON, _ := json.Marshal(result.Summary)
	status := "success"
	if result.Summary.Conflicts > 0 {
		status = "partial"
	}
	_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, status, summaryJSON, "")

	skipped := collectSkippedAttrSamples(ctx, srcDB, ds, allPendingForHonesty)
	result.Precautions = assessWritebackPrecautions(
		ctx, srcDB, ds, result.ByChangeType.Deleted.Safe, skipped, pendingGeomChanges,
	)
	result.ApplyBlocked = hasWritebackBlocker(result.Precautions)
	result.RequiredAcks = requiredAckKeys(result.Precautions)

	return result, nil
}

// ── Helpers ────────────────────────────────────────────

// updateChangesTotal is a tiny convenience over the repo's update queries.
func (s *ReconciliationService) updateChangesTotal(ctx context.Context, jobID uuid.UUID, total int) error {
	progress, _ := json.Marshal(map[string]any{"changes_total": total})
	return s.reconciliationRepo.UpdateProgress(ctx, jobID, progress)
}

// persistConflict writes a row to reconciliation_conflicts.

func (s *ReconciliationService) persistConflict(
	ctx context.Context,
	job *model.ReconciliationJob,
	f *model.Feature,
	origAttrs, fieldAttrs, sourceAttrs map[string]any,
	conflictingFields []string,
) error {
	// ── D-phase polish: skip if a pending conflict already exists for this ──
	// (feature_id, change_type). Prevents Preview from creating duplicate rows.
	existing, err := s.reconciliationRepo.FindPendingConflict(ctx, f.ID, f.ChangeType)
	if err == nil && existing != nil {
		// Update conflicting_fields in case detection found more this run — but
		// skip creating a new row.
		return nil
	}

	originalJSON, _ := jsonEncodeOrNil(origAttrs)

	fieldJSON, _ := jsonEncodeOrNil(fieldAttrs)
	sourceJSON, _ := jsonEncodeOrNil(sourceAttrs)

	return s.reconciliationRepo.CreateConflict(ctx, &model.ReconciliationConflict{
		JobID:             job.ID,
		FeatureID:         f.ID,
		LayerID:           job.LayerID,
		DataSourceID:      job.DataSourceID,
		SourceRef:         f.SourceRef,
		ChangeType:        f.ChangeType,
		OriginalAttrs:     originalJSON,
		FieldAttrs:        fieldJSON,
		SourceAttrs:       sourceJSON,
		ConflictingFields: conflictingFields,
		Status:            "pending",
	})
}

// addSample appends to a sample list up to the limit. Stops when full.
func addSample(target *[]SampleRow, limit int, f model.Feature, changingFields []string) {
	if len(*target) >= limit {
		return
	}
	row := SampleRow{
		FeatureID:  f.ID,
		SourceRef:  f.SourceRef,
		ChangeType: f.ChangeType,
	}
	// We use 'changing_fields' on safe samples, 'conflicting_fields' on conflicts.
	// Caller knows which list it's appending to, so we just write to both fields
	// and let the JSON omit-empty filter out the noise.
	if changingFields != nil {
		row.ChangingFields = changingFields
	}
	*target = append(*target, row)
}

func decodeAttrs(raw json.RawMessage) (map[string]any, error) {
	if len(raw) == 0 {
		return map[string]any{}, nil
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}
	return m, nil
}

func jsonEncodeOrNil(v any) (json.RawMessage, error) {
	if v == nil {
		return nil, nil
	}
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(b), nil
}

// changedFields returns keys whose value differs between a and b.
// Uses tolerant comparison for strings (trim + case-insensitive).
func changedFields(a, b map[string]any) []string {
	if a == nil {
		a = map[string]any{}
	}
	if b == nil {
		b = map[string]any{}
	}
	seen := make(map[string]bool, len(a)+len(b))
	var changed []string
	for k := range a {
		seen[k] = true
		if !valuesEqual(a[k], b[k]) {
			changed = append(changed, k)
		}
	}
	for k := range b {
		if seen[k] {
			continue
		}
		if !valuesEqual(a[k], b[k]) {
			changed = append(changed, k)
		}
	}
	return changed
}

// valuesEqual compares two JSON-decoded values with tolerance:
//   - strings: trim + case-insensitive
//   - everything else: deep equal via JSON canonicalization
func valuesEqual(a, b any) bool {
	if a == nil && b == nil {
		return true
	}
	if a == nil || b == nil {
		return false
	}
	if sa, okA := a.(string); okA {
		if sb, okB := b.(string); okB {
			return strings.EqualFold(strings.TrimSpace(sa), strings.TrimSpace(sb))
		}
	}
	// Fallback: stringify both via JSON. Stable enough for primitives/numbers.
	bA, _ := json.Marshal(a)
	bB, _ := json.Marshal(b)
	return string(bA) == string(bB)
}

// intersect returns elements common to both lists. Preserves order from `a`.
func intersect(a, b []string) []string {
	if len(a) == 0 || len(b) == 0 {
		return nil
	}
	set := make(map[string]bool, len(b))
	for _, x := range b {
		set[x] = true
	}
	var out []string
	for _, x := range a {
		if set[x] {
			out = append(out, x)
		}
	}
	return out
}

func containsString(list []string, want string) bool {
	for _, s := range list {
		if strings.EqualFold(s, want) {
			return true
		}
	}
	return false
}

func cloneStringMap(in map[string]any) map[string]any {
	if in == nil {
		return map[string]any{}
	}
	out := make(map[string]any, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

// isAttachmentAttrValue is true for FC photo markers like "att:<uuid>".
// These must never be written into source table columns.
func isAttachmentAttrValue(v any) bool {
	s, ok := v.(string)
	if !ok {
		return false
	}
	return strings.HasPrefix(strings.TrimSpace(s), "att:")
}

// filterAttrsForSourceWrite keeps only attributes that map to real source
// columns and are not attachment markers / id / geometry.
func filterAttrsForSourceWrite(
	attrs map[string]any,
	tableCols []string,
	idCol, geomCol string,
) map[string]any {
	known := make(map[string]string, len(tableCols)) // lower -> actual
	for _, c := range tableCols {
		known[strings.ToLower(c)] = c
	}
	out := make(map[string]any)
	for k, v := range attrs {
		if isAttachmentAttrValue(v) {
			continue
		}
		if strings.EqualFold(k, idCol) {
			continue
		}
		if geomCol != "" && strings.EqualFold(k, geomCol) {
			continue
		}
		actual, ok := known[strings.ToLower(k)]
		if !ok {
			continue // form-only field (e.g. image) — not on dbo table
		}
		out[actual] = v
	}
	return out
}

// ── Apply ──────────────────────────────────────────────

// ApplyResult is what /apply returns to the admin.
type ApplyResult struct {
	JobID        uuid.UUID       `json:"job_id"`
	DataSource   DataSourceBrief `json:"data_source"`
	Summary      ApplySummary    `json:"summary"`
	ByChangeType ByChangeType    `json:"by_change_type"`
	Errors       []ApplyError    `json:"errors,omitempty"`
}

type ApplySummary struct {
	TotalAttempted int `json:"total_attempted"`
	Applied        int `json:"applied"`
	Skipped        int `json:"skipped"` // unresolved conflicts or already-applied
	Failed         int `json:"failed"`
	NewConflicts   int `json:"new_conflicts"` // detected during re-verify; couldn't apply
}

type ApplyError struct {
	FeatureID  uuid.UUID `json:"feature_id"`
	SourceRef  string    `json:"source_ref"`
	ChangeType string    `json:"change_type"`
	Reason     string    `json:"reason"`
}

// Apply executes reconciliation: pushes pending changes to the source DB.
// Same classification logic as Preview, but actually writes. Handles:
//   - re-detection of conflicts (source may have changed since preview)
//   - honoring resolved conflicts (uses resolved_attrs as the write payload)
//   - skipping already-applied changes (HasAppliedFor guard)
//   - per-chunk transactions
//   - per-row audit log entries
//
// Apply executes reconciliation: pushes pending changes to the source DB.
// ⚠️ DEPRECATED: use EnqueueApply + worker pool for production. Kept for
// tests/admin tooling where synchronous execution is desired.
func (s *ReconciliationService) Apply(
	ctx context.Context,
	projectID, layerID, dataSourceID, userID uuid.UUID,
	batchSize int,
	featureIDs ...uuid.UUID,
) (*ApplyResult, error) {
	job, err := s.EnqueueApply(ctx, projectID, layerID, dataSourceID, userID, batchSize, nil, false, featureIDs...)
	if err != nil {
		return nil, err
	}
	return s.ApplyJob(ctx, job)
}

// ── Per-change appliers ────────────────────────────────

// applyUpdate handles one updated feature. Returns:
//
//	outcome:  "applied" | "conflict" | "skipped" | "failed"
//	reason:   human-readable explanation if not applied
//	applied:  JSON of what was sent to source (for audit log)
//
// applyUpdate handles one updated feature. Returns:
//
//	outcome:  "applied" | "conflict" | "skipped" | "failed"
//	reason:   human-readable explanation if not applied
//	applied:  JSON of what was sent to source (for audit log)
//
// applyUpdate handles one updated feature. Returns:
//
//	outcome:  "applied" | "conflict" | "skipped" | "failed"
//	reason:   human-readable explanation if not applied
//	applied:  JSON of what was sent to source (for audit log)
func (s *ReconciliationService) applyUpdate(
	ctx context.Context,
	tx *sql.Tx,
	schema, table, idCol string,
	ds *model.LayerDataSource,
	f *model.Feature,
	sourceRows map[string]map[string]any,
	actorUserID uuid.UUID,
) (outcome, reason string, applied json.RawMessage) {

	origAttrs, _ := decodeAttrs(f.OriginalAttributes)
	newAttrs, _ := decodeAttrs(f.Attributes)

	srcRow, foundOnSource := sourceRows[f.SourceRef]
	if !foundOnSource {
		return "conflict", "source row missing", nil
	}

	fieldChanged := changedFields(origAttrs, newAttrs)
	sourceChanged := changedFieldsInBoth(origAttrs, srcRow)
	conflicting := intersect(fieldChanged, sourceChanged)

	if len(conflicting) > 0 {
		resolved, err := s.findResolution(ctx, f.ID, "updated")
		if err != nil {
			return "failed", fmt.Sprintf("lookup resolution: %v", err), nil
		}
		if resolved == nil {
			return "conflict", fmt.Sprintf("unresolved conflict on fields: %s", strings.Join(conflicting, ", ")), nil
		}
		if err := json.Unmarshal(resolved.ResolvedAttrs, &newAttrs); err != nil {
			return "failed", fmt.Sprintf("decode resolved_attrs: %v", err), nil
		}
		fieldChanged = changedFields(srcRow, newAttrs)
	}

	// Inject last_edited_* (and device_id) when those columns exist on the target.
	// Also drop attachment markers / form-only fields that are not on the source table.
	tableCols, colErr := listSourceTableColumns(ctx, tx, schema, table)
	if colErr == nil {
		before := cloneStringMap(newAttrs)
		ApplyAuditToAttrs(newAttrs, tableCols, AuditValuesFromFeature(f, actorUserID), "update")
		for k, v := range newAttrs {
			if !valuesEqual(before[k], v) {
				if !containsString(fieldChanged, k) {
					fieldChanged = append(fieldChanged, k)
				}
			}
		}
		writable := filterAttrsForSourceWrite(newAttrs, tableCols, idCol, ds.GeometryColumn())
		filtered := make([]string, 0, len(fieldChanged))
		for _, col := range fieldChanged {
			if _, ok := writable[col]; ok {
				filtered = append(filtered, col)
				continue
			}
			for actual := range writable {
				if strings.EqualFold(actual, col) {
					if !containsString(filtered, actual) {
						filtered = append(filtered, actual)
					}
					break
				}
			}
		}
		fieldChanged = filtered
		newAttrs = writable
	} else {
		filtered := make([]string, 0, len(fieldChanged))
		for _, col := range fieldChanged {
			if isAttachmentAttrValue(newAttrs[col]) {
				continue
			}
			filtered = append(filtered, col)
		}
		fieldChanged = filtered
	}

	// ── Geometry change detection (D6.0) ──
	geomCol := ds.GeometryColumn()
	geomSRID := ds.GeometrySRID()
	geomChanged, geomGeoJSON := geomChanged(f)

	if len(fieldChanged) == 0 && !geomChanged {
		return "skipped", "no fields to apply (already in sync)", nil
	}

	// Build UPDATE statement
	setClauses := make([]string, 0, len(fieldChanged)+1)
	args := make([]any, 0, len(fieldChanged)+2)
	pos := 1

	// Attribute SETs — skip geometry column (handled separately below)
	for _, col := range fieldChanged {
		if col == geomCol {
			continue
		}
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", quoteIdent(col), pos))
		args = append(args, newAttrs[col])
		pos++
	}

	// Geometry SET (single, canonical place). If text differs but PostGIS
	// considers them equal, skip the geom SET (formatting noise).
	if geomChanged && geomCol != "" {
		skipGeom := false
		if f.OriginalGeometry != nil && *f.OriginalGeometry != "" {
			var equals bool
			qErr := tx.QueryRowContext(ctx, `
				SELECT ST_Equals(
					ST_SetSRID(ST_GeomFromGeoJSON($1), $3),
					ST_SetSRID(ST_GeomFromGeoJSON($2), $3)
				)`, geomGeoJSON, *f.OriginalGeometry, geomSRID).Scan(&equals)
			if qErr == nil && equals {
				skipGeom = true
			}
		}
		if !skipGeom {
			setClauses = append(setClauses,
				fmt.Sprintf("%s = ST_SetSRID(ST_GeomFromGeoJSON($%d), %d)", quoteIdent(geomCol), pos, geomSRID))
			args = append(args, geomGeoJSON)
			pos++
		} else {
			geomChanged = false
		}
	}

	// Nothing left after filtering / ST_Equals skip — treat as already in sync.
	if len(setClauses) == 0 {
		return "skipped", "no fields to apply (already in sync)", nil
	}

	args = append(args, f.SourceRef)
	stmt := fmt.Sprintf(
		"UPDATE %s.%s SET %s WHERE %s = $%d",
		quoteIdent(schema), quoteIdent(table),
		strings.Join(setClauses, ", "),
		quoteIdent(idCol), pos,
	)

	if _, err := tx.ExecContext(ctx, stmt, args...); err != nil {
		return "failed", fmt.Sprintf("update: %v", err), nil
	}

	// Build audit payload
	appliedMap := make(map[string]any, len(fieldChanged)+1)
	for _, col := range fieldChanged {
		if col == geomCol {
			continue
		}
		appliedMap[col] = newAttrs[col]
	}
	if geomChanged {
		appliedMap["__geometry__"] = geomGeoJSON
	}
	appliedJSON, _ := json.Marshal(appliedMap)
	return "applied", "", appliedJSON
}

// geomChanged determines whether the feature's geometry differs from the
// captured pre-edit snapshot. Returns the new GeoJSON if it changed.
//
// Requires both Geometry and OriginalGeometry (synced from mobile as GeoJSON).
// Missing original snapshot → skip geometry write-back (attribute-only).
func geomChanged(f *model.Feature) (bool, string) {
	if f.Geometry == nil || *f.Geometry == "" {
		return false, ""
	}
	if f.OriginalGeometry == nil || *f.OriginalGeometry == "" {
		return false, ""
	}

	current := strings.TrimSpace(*f.Geometry)
	original := strings.TrimSpace(*f.OriginalGeometry)
	if current == original {
		return false, ""
	}
	return true, current
}

// applyDelete handles one deleted feature. Honors data source's delete_strategy.
func (s *ReconciliationService) applyDelete(
	ctx context.Context,
	tx *sql.Tx,
	schema, table, idCol string,
	ds *model.LayerDataSource,
	f *model.Feature,
	sourceRows map[string]map[string]any,
) (outcome, reason string) {

	origAttrs, _ := decodeAttrs(f.OriginalAttributes)
	srcRow, foundOnSource := sourceRows[f.SourceRef]

	if !foundOnSource {
		// Already deleted at source — count as applied (idempotent)
		return "applied", ""
	}

	sourceChanged := changedFieldsInBoth(origAttrs, srcRow)
	if len(sourceChanged) > 0 {
		// Source row modified since our snapshot → potential conflict
		resolved, err := s.findResolution(ctx, f.ID, "deleted")
		if err != nil {
			return "failed", fmt.Sprintf("lookup resolution: %v", err)
		}
		if resolved == nil {
			return "conflict", fmt.Sprintf("source row changed since snapshot; fields: %s", strings.Join(sourceChanged, ", "))
		}
		// Admin resolved — could be `source_wins` (don't delete) or `field_wins` (delete)
		if resolved.Resolution != nil && *resolved.Resolution == "source_wins" {
			return "skipped", "admin chose to keep source row"
		}
	}

	strategy := ds.DeleteStrategy
	if strategy == "" {
		strategy = "hard"
	}

	switch strategy {
	case "hard":
		stmt := fmt.Sprintf("DELETE FROM %s.%s WHERE %s = $1", quoteIdent(schema), quoteIdent(table), quoteIdent(idCol))
		if _, err := tx.ExecContext(ctx, stmt, f.SourceRef); err != nil {
			return "failed", fmt.Sprintf("delete: %v", err)
		}
		return "applied", ""

	case "soft":
		if ds.SoftDeleteColumn == "" {
			return "failed", "delete_strategy=soft but soft_delete_column not configured"
		}
		val := ds.SoftDeleteValue
		stmt := fmt.Sprintf(
			"UPDATE %s.%s SET %s = $1 WHERE %s = $2",
			quoteIdent(schema), quoteIdent(table),
			quoteIdent(ds.SoftDeleteColumn),
			quoteIdent(idCol),
		)
		if _, err := tx.ExecContext(ctx, stmt, val, f.SourceRef); err != nil {
			return "failed", fmt.Sprintf("soft delete: %v", err)
		}
		return "applied", ""

	default:
		return "failed", fmt.Sprintf("unknown delete_strategy: %s", strategy)
	}
}

// applyInsert inserts a new collected feature into the source table.
// Assigns the id column explicitly when the source has no serial/default
// (common for dbo.* tables where ogc_fid is a plain bigint UNIQUE).
func (s *ReconciliationService) applyInsert(
	ctx context.Context,
	tx *sql.Tx,
	schema, table, idCol string,
	ds *model.LayerDataSource,
	f *model.Feature,
	actorUserID uuid.UUID,
) (outcome, reason, newSourceRef string, applied json.RawMessage) {
	attrs, err := decodeAttrs(f.Attributes)
	if err != nil {
		return "failed", fmt.Sprintf("decode attributes: %v", err), "", nil
	}

	geomCol := ds.GeometryColumn()
	geomSRID := ds.GeometrySRID()

	tableCols, colErr := listSourceTableColumns(ctx, tx, schema, table)
	if colErr != nil {
		return "failed", fmt.Sprintf("list source columns: %v", colErr), "", nil
	}

	// Fill matching audit columns from feature provenance when present on target.
	ApplyAuditToAttrs(attrs, tableCols, AuditValuesFromFeature(f, actorUserID), "insert")

	newID, err := resolveInsertID(ctx, tx, schema, table, idCol, attrs)
	if err != nil {
		return "failed", err.Error(), "", nil
	}

	// Only write columns that exist on the source table; never write att: media markers.
	writeAttrs := filterAttrsForSourceWrite(attrs, tableCols, idCol, geomCol)

	keys := make([]string, 0, len(writeAttrs))
	for k := range writeAttrs {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	colNames := make([]string, 0, len(keys)+2)
	placeholders := make([]string, 0, len(keys)+2)
	args := make([]any, 0, len(keys)+2)
	pos := 1

	appliedMap := make(map[string]any, len(keys)+2)

	// Always include the id column — many linked dbo tables have no DEFAULT/serial.
	colNames = append(colNames, quoteIdent(idCol))
	placeholders = append(placeholders, fmt.Sprintf("$%d", pos))
	args = append(args, newID)
	appliedMap[idCol] = newID
	pos++

	for _, k := range keys {
		colNames = append(colNames, quoteIdent(k))
		placeholders = append(placeholders, fmt.Sprintf("$%d", pos))
		args = append(args, writeAttrs[k])
		appliedMap[k] = writeAttrs[k]
		pos++
	}

	if f.Geometry != nil && strings.TrimSpace(*f.Geometry) != "" && geomCol != "" {
		colNames = append(colNames, quoteIdent(geomCol))
		placeholders = append(placeholders,
			fmt.Sprintf("ST_SetSRID(ST_GeomFromGeoJSON($%d), %d)", pos, geomSRID))
		args = append(args, strings.TrimSpace(*f.Geometry))
		appliedMap["__geometry__"] = strings.TrimSpace(*f.Geometry)
		pos++
	}

	if len(colNames) == 0 {
		return "failed", "no columns to insert (empty attributes and no geometry)", "", nil
	}

	stmt := fmt.Sprintf(
		"INSERT INTO %s.%s (%s) VALUES (%s) RETURNING %s::text",
		quoteIdent(schema), quoteIdent(table),
		strings.Join(colNames, ", "),
		strings.Join(placeholders, ", "),
		quoteIdent(idCol),
	)

	var returned sql.NullString
	if err := tx.QueryRowContext(ctx, stmt, args...).Scan(&returned); err != nil {
		return "failed", fmt.Sprintf("insert: %v", err), "", nil
	}
	if returned.Valid && strings.TrimSpace(returned.String) != "" {
		newID = strings.TrimSpace(returned.String)
	}

	appliedJSON, _ := json.Marshal(appliedMap)
	return "applied", "", newID, appliedJSON
}

// resolveInsertID picks the source PK for a new row:
//  1. Use attributes[idCol] when present and not already taken
//  2. Otherwise allocate MAX(id)+1
func resolveInsertID(
	ctx context.Context,
	tx *sql.Tx,
	schema, table, idCol string,
	attrs map[string]any,
) (string, error) {
	var preferred string
	for k, v := range attrs {
		if !strings.EqualFold(k, idCol) || v == nil {
			continue
		}
		preferred = strings.TrimSpace(fmt.Sprintf("%v", v))
		if preferred == "" || preferred == "<nil>" {
			preferred = ""
		}
		break
	}

	if preferred != "" {
		var exists bool
		q := fmt.Sprintf(
			`SELECT EXISTS (SELECT 1 FROM %s.%s WHERE %s::text = $1)`,
			quoteIdent(schema), quoteIdent(table), quoteIdent(idCol),
		)
		if err := tx.QueryRowContext(ctx, q, preferred).Scan(&exists); err != nil {
			return "", fmt.Errorf("check existing id: %w", err)
		}
		if exists {
			return "", fmt.Errorf("source id %s=%s already exists; clear it on the feature or choose another id", idCol, preferred)
		}
		return preferred, nil
	}

	var next sql.NullString
	q := fmt.Sprintf(
		`SELECT (COALESCE(MAX(%s), 0) + 1)::text FROM %s.%s`,
		quoteIdent(idCol), quoteIdent(schema), quoteIdent(table),
	)
	if err := tx.QueryRowContext(ctx, q).Scan(&next); err != nil {
		return "", fmt.Errorf("allocate next %s: %w", idCol, err)
	}
	if !next.Valid || next.String == "" {
		return "1", nil
	}
	return next.String, nil
}

// findResolution returns the resolved conflict row for (feature, changeType),
// or nil if no resolution exists.
func (s *ReconciliationService) findResolution(ctx context.Context, featureID uuid.UUID, changeType string) (*model.ReconciliationConflict, error) {
	// Reuse the repo's ListPendingConflictsByLayer pattern but filter directly.
	// We need a focused query — add inline.
	type row struct {
		model.ReconciliationConflict `bun:",extend"`
	}
	var conflict model.ReconciliationConflict
	err := s.reconciliationRepo.QueryResolution(ctx, featureID, changeType, &conflict)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	if conflict.Status != "resolved" || conflict.ResolvedAttrs == nil {
		return nil, nil
	}
	return &conflict, nil
}

// logEntry writes a reconciliation_log row. Returns the error (caller logs/ignores).
func (s *ReconciliationService) logEntry(
	ctx context.Context,
	f *model.Feature,
	job *model.ReconciliationJob,
	outcome string,
	attempted json.RawMessage,
	failureReason string,
	appliedBy *uuid.UUID,
) error {
	entry := &model.ReconciliationLogEntry{
		JobID:            &job.ID,
		FeatureID:        &f.ID,
		LayerID:          &job.LayerID,
		DataSourceID:     &job.DataSourceID,
		SourceRef:        f.SourceRef,
		ChangeType:       f.ChangeType,
		Outcome:          outcome,
		AttemptedPayload: attempted,
		FailureReason:    failureReason,
		AppliedBy:        appliedBy,
	}
	return s.reconciliationRepo.WriteLogEntry(ctx, entry)
}

// EnqueueApply creates a pending apply job (no work done yet). The worker pool
// picks it up and runs ApplyJob asynchronously. Returns the job ID for polling.
// When featureIDs is non-empty, only those pending features are applied.
// acknowledgments must include every required_ack from a recent Preview when
// requireAcks is true (bulk reconcile UI). Single-feature write-back may set
// requireAcks=false but still refuses blockers (views, misconfig).
func (s *ReconciliationService) EnqueueApply(
	ctx context.Context,
	projectID, layerID, dataSourceID, userID uuid.UUID,
	batchSize int,
	acknowledgments []string,
	requireAcks bool,
	featureIDs ...uuid.UUID,
) (*model.ReconciliationJob, error) {
	if batchSize <= 0 {
		batchSize = 500
	}

	// Membership check up front — fast fail before queuing
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}

	if err := s.rejectAOILayer(ctx, projectID, layerID); err != nil {
		return nil, err
	}

	// Validate data source belongs to this layer + has reconciliation config
	ds, err := s.dataSourceRepo.FindByID(ctx, dataSourceID)
	if err != nil {
		return nil, fmt.Errorf("data source not found: %w", err)
	}
	if ds.LayerID != layerID {
		return nil, fmt.Errorf("data source %s does not belong to layer %s", dataSourceID, layerID)
	}
	if ds.SchemaName() == "" || ds.TableName() == "" || ds.IDColumn() == "" {
		return nil, fmt.Errorf("data source %s missing schema/table/id_column", ds.ID)
	}

	srcDB, err := s.connOpener.OpenForDataSource(ctx, ds)
	if err != nil {
		return nil, fmt.Errorf("open source connection: %w", err)
	}
	defer srcDB.Close()

	// Sample pending rows for honesty + delete counts (cheap first page).
	sample, _ := s.featureRepo.ListPendingChanges(ctx, dataSourceID, 200, 0, featureIDs...)
	pendingDeletes := 0
	for i := range sample {
		if sample[i].ChangeType == "deleted" {
			pendingDeletes++
		}
	}
	// If first page is full of non-deletes, still count deletes cheaply via CountPendingChanges.
	if _, deletes, err := s.featureRepo.CountPendingChanges(ctx, dataSourceID); err == nil {
		pendingDeletes = deletes
	}
	skipped := collectSkippedAttrSamples(ctx, srcDB, ds, sample)
	pendingGeom := 0
	for i := range sample {
		if gChanged, _ := geomChanged(&sample[i]); gChanged {
			pendingGeom++
		}
	}
	precautions := assessWritebackPrecautions(ctx, srcDB, ds, pendingDeletes, skipped, pendingGeom)
	if hasWritebackBlocker(precautions) {
		var msgs []string
		for _, p := range precautions {
			if p.Severity == "blocker" {
				msgs = append(msgs, p.Message)
			}
		}
		return nil, fmt.Errorf("apply blocked: %s", strings.Join(msgs, "; "))
	}
	if requireAcks {
		if missing := missingAcknowledgments(requiredAckKeys(precautions), acknowledgments); len(missing) > 0 {
			return nil, fmt.Errorf(
				"apply requires acknowledgments %v (from reconcile preview precautions)",
				missing,
			)
		}
	}

	job := &model.ReconciliationJob{
		ProjectID:    projectID,
		LayerID:      layerID,
		DataSourceID: dataSourceID,
		Mode:         "apply",
		Status:       "pending",
		BatchSize:    batchSize,
		CreatedBy:    &userID,
	}
	if len(featureIDs) > 0 {
		progress, _ := json.Marshal(map[string]any{"feature_ids": featureIDs})
		job.Progress = progress
	}
	if err := s.reconciliationRepo.CreateJob(ctx, job); err != nil {
		return nil, fmt.Errorf("create apply job: %w", err)
	}
	return job, nil
}

func (s *ReconciliationService) rejectAOILayer(ctx context.Context, projectID, layerID uuid.UUID) error {
	if s.projectRepo == nil {
		return nil
	}
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return fmt.Errorf("project not found")
	}
	if project.IsAOILayer(layerID) {
		return fmt.Errorf("layer is the project AOI source and cannot be reconciled")
	}
	return nil
}

// Cancel marks a running or pending job as cancelling. The worker checks
// status between chunks and bails out cleanly. Already-applied rows stay
// applied (we don't roll back — the reconciliation_log is the audit trail).
func (s *ReconciliationService) Cancel(ctx context.Context, jobID, userID uuid.UUID) error {
	job, err := s.reconciliationRepo.FindJob(ctx, jobID)
	if err != nil {
		return fmt.Errorf("job not found: %w", err)
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, job.ProjectID, userID); err != nil {
		return fmt.Errorf("access denied: not a member of this project")
	}
	switch job.Status {
	case "pending", "running":
		return s.reconciliationRepo.SetStatus(ctx, jobID, "cancelling")
	case "cancelling":
		return nil // already requested
	default:
		return fmt.Errorf("cannot cancel job in status %q", job.Status)
	}
}

// GetJob returns the current state of a reconciliation job. Used by HTTP
// polling endpoints to render progress in the admin UI.
func (s *ReconciliationService) GetJob(ctx context.Context, jobID, userID uuid.UUID) (*model.ReconciliationJob, error) {
	job, err := s.reconciliationRepo.FindJob(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("job not found: %w", err)
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, job.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	return job, nil
}

// ApplyJob runs reconciliation for an already-created job row. Called by the
// worker pool. Checks for cancellation between chunks.
func (s *ReconciliationService) ApplyJob(
	ctx context.Context,
	job *model.ReconciliationJob,
) (rapResult *ApplyResult, rapErr error) {

	// ── BULLETPROOF FINALIZER ──
	// Guarantee that the job exits `running` no matter what happens below
	// (panic, ctx cancel, missed return path, etc.). Uses a fresh context
	// so worker shutdown can't block us. Runs LAST.
	defer func() {
		if rec := recover(); rec != nil {
			slog.Error("[reconcile] ApplyJob PANICKED",
				"job_id", job.ID,
				"panic", fmt.Sprintf("%v", rec),
			)
			rapErr = fmt.Errorf("panic in ApplyJob: %v", rec)
		}

		// Check if MarkFinished already ran by the normal path (status != running)
		bgCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		current, err := s.reconciliationRepo.FindJob(bgCtx, job.ID)
		if err != nil {
			slog.Error("[reconcile] safety finalizer: could not load job",
				"job_id", job.ID, "error", err)
			return
		}

		if current.Status == "running" || current.Status == "pending" || current.Status == "cancelling" {
			// Decide the right terminal status based on counters
			status := "failed"
			errMsg := "job exited without explicit finalization"

			if rapErr == nil {
				// Normal completion that just missed the explicit MarkFinished
				switch {
				case current.Errors > 0:
					status = "partial"
					errMsg = ""
				case current.ConflictsDetected > 0:
					status = "partial"
					errMsg = ""
				case current.UpdatesSucceeded > 0 || current.DeletesSucceeded > 0 || current.InsertsSucceeded > 0:
					status = "success"
					errMsg = ""
				default:
					status = "failed"
					errMsg = "no changes applied"
				}
			} else {
				errMsg = rapErr.Error()
			}

			slog.Warn("[reconcile] safety finalizer kicking in",
				"job_id", job.ID,
				"intended_status", status,
				"current_status", current.Status,
			)

			summary := map[string]any{
				"updates_succeeded":  current.UpdatesSucceeded,
				"deletes_succeeded":  current.DeletesSucceeded,
				"conflicts_detected": current.ConflictsDetected,
				"errors":             current.Errors,
				"finalized_by":       "safety_defer",
			}
			summaryJSON, _ := json.Marshal(summary)

			if err := s.reconciliationRepo.MarkFinished(bgCtx, job.ID, status, summaryJSON, errMsg); err != nil {
				slog.Error("[reconcile] safety finalizer MarkFinished failed",
					"job_id", job.ID, "error", err)
			} else {
				slog.Info("[reconcile] safety finalizer wrote terminal status",
					"job_id", job.ID, "status", status)

			}
		}
	}()

	// Load data source
	ds, err := s.dataSourceRepo.FindByID(ctx, job.DataSourceID)
	if err != nil {
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, fmt.Errorf("data source not found: %w", err)
	}
	schema := ds.SchemaName()
	table := ds.TableName()
	idCol := ds.IDColumn()
	if schema == "" || table == "" || idCol == "" {
		err := fmt.Errorf("data source %s missing schema/table/id_column", ds.ID)
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, err
	}

	// Mark running
	if err := s.reconciliationRepo.MarkRunning(ctx, job.ID); err != nil {
		return nil, fmt.Errorf("mark running: %w", err)
	}

	featureIDs := featureIDsFromProgress(job.Progress)

	// Open source DB
	srcDB, err := s.connOpener.OpenForDataSource(ctx, ds)
	if err != nil {
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, fmt.Errorf("open source connection: %w", err)
	}
	defer srcDB.Close()

	userID := uuid.Nil
	if job.CreatedBy != nil {
		userID = *job.CreatedBy
	}

	result := &ApplyResult{
		JobID:      job.ID,
		DataSource: DataSourceBrief{ID: ds.ID, Name: ds.Name, Schema: schema, Table: table},
	}

	updAttempted, updSucceeded := 0, 0
	delAttempted, delSucceeded := 0, 0
	insAttempted, insSucceeded := 0, 0
	totalConflicts := 0
	totalErrors := 0

	batchSize := job.BatchSize
	if batchSize <= 0 {
		batchSize = 500
	}

	offset := 0
	chunkIdx := 0
	for {
		// ── Cancellation check (between chunks) ──
		if cancelled, _ := s.isCancelled(ctx, job.ID); cancelled {
			slog.Info("reconciliation job cancelled by user", "job_id", job.ID)
			summaryJSON, _ := json.Marshal(result.Summary)
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "cancelled", summaryJSON, "cancelled by user")
			return result, nil
		}

		batch, err := s.featureRepo.ListPendingChanges(ctx, job.DataSourceID, batchSize, offset, featureIDs...)
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("list pending changes: %w", err)
		}
		if len(batch) == 0 {
			break
		}

		// Bulk fetch source state (updates/deletes only; inserts have no source_ref yet)
		srcRefs := make([]string, 0, len(batch))
		for _, f := range batch {
			if f.SourceRef != "" {
				srcRefs = append(srcRefs, f.SourceRef)
			}
		}
		sourceRows, err := fetchSourceRowsByIDs(ctx, srcDB, schema, table, idCol, srcRefs)
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("fetch source rows: %w", err)
		}

		// Per-chunk transaction
		tx, err := srcDB.BeginTx(ctx, nil)
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("begin tx: %w", err)
		}

		chunkCommitted := true
		var pendingInsertRefs []struct {
			featureID uuid.UUID
			sourceRef string
		}

		for _, f := range batch {
			feature := f

			if feature.ChangeType != "inserted" && feature.SourceRef == "" {
				totalErrors++
				_ = s.logEntry(ctx, &feature, job, "failed", nil, "missing source_ref", &userID)
				continue
			}

			already, _ := s.reconciliationRepo.HasAppliedFor(ctx, feature.ID, feature.ChangeType)
			if already {
				result.Summary.Skipped++
				_ = s.logEntry(ctx, &feature, job, "skipped", nil, "already applied", &userID)
				continue
			}

			switch feature.ChangeType {
			case "updated":
				updAttempted++
				result.Summary.TotalAttempted++
				outcome, reason, applied := s.applyUpdate(ctx, tx, schema, table, idCol, ds, &feature, sourceRows, userID)
				switch outcome {
				case "applied":
					updSucceeded++
					result.Summary.Applied++
					result.ByChangeType.Updated.Safe++
					_ = s.logEntry(ctx, &feature, job, "applied", applied, "", &userID)
				case "conflict":
					totalConflicts++
					result.Summary.NewConflicts++
					result.ByChangeType.Updated.Conflict++
					_ = s.logEntry(ctx, &feature, job, "conflict", nil, reason, &userID)
				case "skipped":
					result.Summary.Skipped++
					_ = s.logEntry(ctx, &feature, job, "skipped", nil, reason, &userID)
				case "failed":
					totalErrors++
					result.Summary.Failed++
					result.Errors = append(result.Errors, ApplyError{
						FeatureID: feature.ID, SourceRef: feature.SourceRef,
						ChangeType: feature.ChangeType, Reason: reason,
					})
					_ = s.logEntry(ctx, &feature, job, "failed", nil, reason, &userID)
					chunkCommitted = false
				}
			case "deleted":
				delAttempted++
				result.Summary.TotalAttempted++
				outcome, reason := s.applyDelete(ctx, tx, schema, table, idCol, ds, &feature, sourceRows)
				switch outcome {
				case "applied":
					delSucceeded++
					result.Summary.Applied++
					result.ByChangeType.Deleted.Safe++
					_ = s.logEntry(ctx, &feature, job, "applied", nil, "", &userID)
				case "conflict":
					totalConflicts++
					result.Summary.NewConflicts++
					result.ByChangeType.Deleted.Conflict++
					_ = s.logEntry(ctx, &feature, job, "conflict", nil, reason, &userID)
				case "skipped":
					result.Summary.Skipped++
					_ = s.logEntry(ctx, &feature, job, "skipped", nil, reason, &userID)
				case "failed":
					totalErrors++
					result.Summary.Failed++
					result.Errors = append(result.Errors, ApplyError{
						FeatureID: feature.ID, SourceRef: feature.SourceRef,
						ChangeType: feature.ChangeType, Reason: reason,
					})
					_ = s.logEntry(ctx, &feature, job, "failed", nil, reason, &userID)
					chunkCommitted = false
				}
			case "inserted":
				insAttempted++
				result.Summary.TotalAttempted++
				outcome, reason, newRef, applied := s.applyInsert(ctx, tx, schema, table, idCol, ds, &feature, userID)
				switch outcome {
				case "applied":
					insSucceeded++
					result.Summary.Applied++
					result.ByChangeType.Inserted.Safe++
					feature.SourceRef = newRef
					pendingInsertRefs = append(pendingInsertRefs, struct {
						featureID uuid.UUID
						sourceRef string
					}{feature.ID, newRef})
					_ = s.logEntry(ctx, &feature, job, "applied", applied, "", &userID)
				case "failed":
					totalErrors++
					result.Summary.Failed++
					result.Errors = append(result.Errors, ApplyError{
						FeatureID: feature.ID, SourceRef: feature.SourceRef,
						ChangeType: feature.ChangeType, Reason: reason,
					})
					_ = s.logEntry(ctx, &feature, job, "failed", nil, reason, &userID)
					chunkCommitted = false
				default:
					result.Summary.Skipped++
					_ = s.logEntry(ctx, &feature, job, outcome, nil, reason, &userID)
				}
			default:
				totalErrors++
			}
		}

		if chunkCommitted {
			if err := tx.Commit(); err != nil {
				slog.Error("commit chunk failed", "error", err)
				_ = tx.Rollback()
				_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
				return nil, fmt.Errorf("commit chunk: %w", err)
			}
			for _, p := range pendingInsertRefs {
				if err := s.featureRepo.SetSourceRefAfterInsert(ctx, p.featureID, p.sourceRef, ds.ID); err != nil {
					slog.Error("set source_ref after insert failed",
						"feature_id", p.featureID, "source_ref", p.sourceRef, "error", err)
				}
			}
		} else {
			_ = tx.Rollback()
		}

		// Update counters + progress
		_ = s.reconciliationRepo.IncrementCounters(
			ctx, job.ID,
			insAttempted, insSucceeded,
			updAttempted, updSucceeded,
			delAttempted, delSucceeded,
			totalConflicts, totalErrors,
		)
		updAttempted, updSucceeded = 0, 0
		delAttempted, delSucceeded = 0, 0
		insAttempted, insSucceeded = 0, 0
		totalConflicts, totalErrors = 0, 0

		chunkIdx++
		progress, _ := json.Marshal(map[string]any{
			"current_chunk":      chunkIdx,
			"processed_features": offset + len(batch),
			"phase":              "applying",
		})
		_ = s.reconciliationRepo.UpdateProgress(ctx, job.ID, progress)

		offset += len(batch)
		if len(batch) < batchSize {
			break
		}
	}

	// Finalize
	summaryJSON, _ := json.Marshal(result.Summary)
	status := "success"
	if result.Summary.Failed > 0 || result.Summary.NewConflicts > 0 {
		status = "partial"
	}
	if result.Summary.Applied == 0 && result.Summary.TotalAttempted > 0 {
		status = "failed"
	}

	// Use a background context — worker pool shutdown (or any other ctx cancellation)
	// should NOT block recording the job's terminal status. We always want
	// finalization to land in the DB.
	finalCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := s.reconciliationRepo.MarkFinished(finalCtx, job.ID, status, summaryJSON, ""); err != nil {
		slog.Error("MarkFinished after apply loop failed",
			"job_id", job.ID,
			"intended_status", status,
			"applied", result.Summary.Applied,
			"error", err,
		)
	}

	return result, nil
}

// isCancelled checks if the job's status has been flipped to 'cancelling'.
// Worker calls this between chunks.
func (s *ReconciliationService) isCancelled(ctx context.Context, jobID uuid.UUID) (bool, error) {
	job, err := s.reconciliationRepo.FindJob(ctx, jobID)
	if err != nil {
		return false, err
	}
	return job.Status == "cancelling", nil
}

// WriteBackResult is the synchronous per-feature write-back response.
type WriteBackResult struct {
	JobID      uuid.UUID  `json:"job_id"`
	FeatureID  uuid.UUID  `json:"feature_id"`
	SourceRef  string     `json:"source_ref"`
	ChangeType string     `json:"change_type"`
	Outcome    string     `json:"outcome"` // applied | conflict | skipped | failed
	Reason     string     `json:"reason,omitempty"`
	ConflictID *uuid.UUID `json:"conflict_id,omitempty"`
}

// WriteBackFeature pushes one collected feature's insert/update/delete to the source table.
// Creates a one-feature reconcile job for audit.
func (s *ReconciliationService) WriteBackFeature(
	ctx context.Context,
	projectID, layerID, featureID, userID uuid.UUID,
) (*WriteBackResult, error) {
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}

	feature, err := s.featureRepo.FindByID(ctx, featureID)
	if err != nil {
		return nil, fmt.Errorf("feature not found: %w", err)
	}
	if feature.ProjectID != projectID {
		return nil, fmt.Errorf("feature does not belong to project %s", projectID)
	}
	if feature.LayerID == nil || *feature.LayerID != layerID {
		return nil, fmt.Errorf("feature does not belong to layer %s", layerID)
	}

	changeType := feature.ChangeType
	if changeType == "" {
		if feature.SourceRef != "" {
			changeType = "updated"
		} else {
			changeType = "inserted"
		}
		feature.ChangeType = changeType
	}

	switch changeType {
	case "updated", "deleted":
		if feature.SourceRef == "" {
			return nil, fmt.Errorf("feature has no source_ref; cannot write back %s", changeType)
		}
	case "inserted":
		// ok — source_ref assigned by DB on apply
	default:
		return nil, fmt.Errorf("write-back only supports inserted/updated/deleted features (got %q)", changeType)
	}

	ds, err := s.resolveWritableDataSource(ctx, layerID, feature)
	if err != nil {
		return nil, err
	}
	schema := ds.SchemaName()
	table := ds.TableName()
	idCol := ds.IDColumn()
	if schema == "" || table == "" || idCol == "" {
		return nil, fmt.Errorf("data source %s missing schema/table/id_column", ds.ID)
	}

	already, err := s.reconciliationRepo.HasAppliedFor(ctx, feature.ID, feature.ChangeType)
	if err != nil {
		return nil, fmt.Errorf("check applied: %w", err)
	}

	job, err := s.EnqueueApply(ctx, projectID, layerID, ds.ID, userID, 1, nil, false, feature.ID)
	if err != nil {
		return nil, err
	}
	if err := s.reconciliationRepo.MarkRunning(ctx, job.ID); err != nil {
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, fmt.Errorf("mark running: %w", err)
	}

	result := &WriteBackResult{
		JobID:      job.ID,
		FeatureID:  feature.ID,
		SourceRef:  feature.SourceRef,
		ChangeType: feature.ChangeType,
	}

	if already {
		result.Outcome = "skipped"
		result.Reason = "already applied"
		_ = s.logEntry(ctx, feature, job, "skipped", nil, "already applied", &userID)
		summaryJSON, _ := json.Marshal(map[string]any{"skipped": 1})
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "success", summaryJSON, "")
		return result, nil
	}

	srcDB, err := s.connOpener.OpenForDataSource(ctx, ds)
	if err != nil {
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, fmt.Errorf("open source connection: %w", err)
	}
	defer srcDB.Close()

	var sourceRows map[string]map[string]any
	if feature.ChangeType != "inserted" {
		sourceRows, err = fetchSourceRowsByIDs(ctx, srcDB, schema, table, idCol, []string{feature.SourceRef})
		if err != nil {
			_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
			return nil, fmt.Errorf("fetch source rows: %w", err)
		}
	}

	tx, err := srcDB.BeginTx(ctx, nil)
	if err != nil {
		_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, "failed", nil, err.Error())
		return nil, fmt.Errorf("begin tx: %w", err)
	}

	insAttempted, insSucceeded := 0, 0
	updAttempted, updSucceeded := 0, 0
	delAttempted, delSucceeded := 0, 0
	conflicts, errors := 0, 0
	var applied json.RawMessage
	var newSourceRef string

	switch feature.ChangeType {
	case "inserted":
		insAttempted = 1
		outcome, reason, newRef, payload := s.applyInsert(ctx, tx, schema, table, idCol, ds, feature, userID)
		result.Outcome = outcome
		result.Reason = reason
		applied = payload
		newSourceRef = newRef
		switch outcome {
		case "applied":
			insSucceeded = 1
			result.SourceRef = newRef
			feature.SourceRef = newRef
		case "failed":
			errors = 1
		}
	case "updated":
		updAttempted = 1
		outcome, reason, payload := s.applyUpdate(ctx, tx, schema, table, idCol, ds, feature, sourceRows, userID)
		result.Outcome = outcome
		result.Reason = reason
		applied = payload
		switch outcome {
		case "applied":
			updSucceeded = 1
		case "conflict":
			conflicts = 1
		case "failed":
			errors = 1
		}
	case "deleted":
		delAttempted = 1
		outcome, reason := s.applyDelete(ctx, tx, schema, table, idCol, ds, feature, sourceRows)
		result.Outcome = outcome
		result.Reason = reason
		switch outcome {
		case "applied":
			delSucceeded = 1
		case "conflict":
			conflicts = 1
		case "failed":
			errors = 1
		}
	}

	if result.Outcome == "failed" {
		_ = tx.Rollback()
	} else if err := tx.Commit(); err != nil {
		_ = tx.Rollback()
		result.Outcome = "failed"
		result.Reason = fmt.Sprintf("commit: %v", err)
		errors = 1
		insSucceeded, updSucceeded, delSucceeded, conflicts = 0, 0, 0, 0
	} else if feature.ChangeType == "inserted" && result.Outcome == "applied" && newSourceRef != "" {
		if err := s.featureRepo.SetSourceRefAfterInsert(ctx, feature.ID, newSourceRef, ds.ID); err != nil {
			slog.Error("set source_ref after insert write-back failed",
				"feature_id", feature.ID, "source_ref", newSourceRef, "error", err)
		}
	}

	if result.Outcome == "conflict" {
		origAttrs, _ := decodeAttrs(feature.OriginalAttributes)
		newAttrs, _ := decodeAttrs(feature.Attributes)
		srcRow, found := sourceRows[feature.SourceRef]
		var conflicting []string
		var fieldAttrs, sourceAttrs map[string]any
		if feature.ChangeType == "updated" {
			fieldAttrs = newAttrs
			if !found {
				conflicting = []string{"_source_row_missing"}
			} else {
				sourceAttrs = srcRow
				conflicting = intersect(changedFields(origAttrs, newAttrs), changedFieldsInBoth(origAttrs, srcRow))
			}
		} else if feature.ChangeType == "deleted" && found {
			sourceAttrs = srcRow
			conflicting = changedFieldsInBoth(origAttrs, srcRow)
		}
		if len(conflicting) == 0 {
			conflicting = []string{"_conflict"}
		}
		_ = s.persistConflict(ctx, job, feature, origAttrs, fieldAttrs, sourceAttrs, conflicting)
		if pending, err := s.reconciliationRepo.FindPendingConflict(ctx, feature.ID, feature.ChangeType); err == nil && pending != nil {
			result.ConflictID = &pending.ID
		}
	}

	_ = s.logEntry(ctx, feature, job, result.Outcome, applied, result.Reason, &userID)
	_ = s.reconciliationRepo.IncrementCounters(
		ctx, job.ID,
		insAttempted, insSucceeded,
		updAttempted, updSucceeded,
		delAttempted, delSucceeded,
		conflicts, errors,
	)

	status := "success"
	switch result.Outcome {
	case "applied", "skipped":
		status = "success"
	case "conflict":
		status = "partial"
	default:
		status = "failed"
	}
	summaryJSON, _ := json.Marshal(map[string]any{
		"outcome":     result.Outcome,
		"feature_id":  feature.ID,
		"source_ref":  result.SourceRef,
		"change_type": feature.ChangeType,
		"reason":      result.Reason,
	})
	_ = s.reconciliationRepo.MarkFinished(ctx, job.ID, status, summaryJSON, result.Reason)

	return result, nil
}

// resolveWritableDataSource finds the data source for write-back. Prefers the
// feature's data_source_id; otherwise picks the layer's linked database source.
func (s *ReconciliationService) resolveWritableDataSource(
	ctx context.Context,
	layerID uuid.UUID,
	feature *model.Feature,
) (*model.LayerDataSource, error) {
	if feature.DataSourceID != nil {
		ds, err := s.dataSourceRepo.FindByID(ctx, *feature.DataSourceID)
		if err != nil {
			return nil, fmt.Errorf("data source not found: %w", err)
		}
		if ds.LayerID != layerID {
			return nil, fmt.Errorf("data source %s does not belong to layer %s", ds.ID, layerID)
		}
		return ds, nil
	}

	sources, err := s.dataSourceRepo.ListByLayer(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("list data sources: %w", err)
	}
	for i := range sources {
		ds := &sources[i]
		if ds.SchemaName() == "" || ds.TableName() == "" || ds.IDColumn() == "" {
			continue
		}
		// connection_id optional when opener can use home DATABASE_URL (linked dbo)
		return ds, nil
	}
	return nil, fmt.Errorf("feature has no data_source_id and layer has no writable data source (need schema/table/id_column)")
}

// featureIDsFromProgress reads optional feature_ids filter from a job's progress JSON.
func featureIDsFromProgress(progress json.RawMessage) []uuid.UUID {
	if len(progress) == 0 {
		return nil
	}
	var parsed struct {
		FeatureIDs []uuid.UUID `json:"feature_ids"`
	}
	if err := json.Unmarshal(progress, &parsed); err != nil {
		return nil
	}
	return parsed.FeatureIDs
}

// ListPendingConflicts returns all pending conflicts for a layer. Used by the
// admin Conflicts page UI to populate the resolution list.
func (s *ReconciliationService) ListPendingConflicts(
	ctx context.Context,
	layerID uuid.UUID,
) ([]model.ReconciliationConflict, error) {
	return s.reconciliationRepo.ListPendingConflictsByLayer(ctx, layerID)
}

// ResolveConflict records an admin's resolution. The next reconciliation Apply
// job will pick up the resolved_attrs via QueryResolution.
func (s *ReconciliationService) ResolveConflict(
	ctx context.Context,
	conflictID uuid.UUID,
	resolution string,
	resolvedAttrs json.RawMessage,
	resolvedBy uuid.UUID,
	notes string,
) error {
	return s.reconciliationRepo.ResolveConflict(
		ctx,
		conflictID,
		resolution,
		resolvedAttrs,
		resolvedBy,
		notes,
	)
}

// ListJobLog returns the per-row audit entries for a job. Membership-checked.
func (s *ReconciliationService) ListJobLog(
	ctx context.Context,
	jobID, userID uuid.UUID,
	limit int,
) ([]model.ReconciliationLogEntry, error) {
	// Membership check via the job
	if _, err := s.GetJob(ctx, jobID, userID); err != nil {
		return nil, err
	}
	return s.reconciliationRepo.ListLogsByJob(ctx, jobID, limit)
}

// GetJobNoMembership loads a job without checking membership. Used by the
// worker watchdog where there's no user context to validate against.
func (s *ReconciliationService) GetJobNoMembership(ctx context.Context, jobID uuid.UUID) (*model.ReconciliationJob, error) {
	return s.reconciliationRepo.FindJob(ctx, jobID)
}

// ForceMarkFinished is the watchdog escape hatch. Sets terminal status
// without going through the normal MarkFinished path.
func (s *ReconciliationService) ForceMarkFinished(ctx context.Context, jobID uuid.UUID, status, errMsg string) error {
	summary := map[string]any{
		"finalized_by": "watchdog",
	}
	summaryJSON, _ := json.Marshal(summary)
	return s.reconciliationRepo.MarkFinished(ctx, jobID, status, summaryJSON, errMsg)
}

// LayerReconcileSummary returns counts of pending vs resolved conflicts for a layer.
// Membership-checked via project access (implicit through layer access).
func (s *ReconciliationService) LayerReconcileSummary(
	ctx context.Context,
	layerID uuid.UUID,
) (pending int, resolved int, err error) {
	return s.reconciliationRepo.LayerConflictCounts(ctx, layerID)
}

// ForceFinalize is the admin escape hatch — sets a job's terminal status
// based on current counters, regardless of worker state. Membership-checked.
func (s *ReconciliationService) ForceFinalize(
	ctx context.Context,
	jobID, userID uuid.UUID,
) (*model.ReconciliationJob, error) {
	job, err := s.reconciliationRepo.FindJob(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("job not found: %w", err)
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, job.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}

	// Only act on non-terminal jobs
	if job.Status != "running" && job.Status != "pending" && job.Status != "cancelling" {
		return job, nil // already terminal — no-op success
	}

	// Decide terminal status from counters (same logic as watchdog)
	status := "failed"
	errMsg := "force-finalized by admin"

	switch {
	case job.Errors > 0:
		status = "partial"
		errMsg = "force-finalized by admin (had errors)"
	case job.ConflictsDetected > 0 && (job.UpdatesSucceeded+job.DeletesSucceeded) > 0:
		status = "partial"
		errMsg = "force-finalized by admin (had conflicts)"
	case job.ConflictsDetected > 0:
		status = "partial"
		errMsg = "force-finalized by admin (only conflicts, none applied)"
	case job.UpdatesSucceeded > 0 || job.DeletesSucceeded > 0:
		status = "success"
		errMsg = "force-finalized by admin (work completed)"
	}

	if err := s.ForceMarkFinished(ctx, jobID, status, errMsg); err != nil {
		return nil, fmt.Errorf("force mark finished: %w", err)
	}

	// Return refreshed job
	return s.reconciliationRepo.FindJob(ctx, jobID)
}

// changedFieldsInBoth is like changedFields but only considers keys present
// in `a`. Fields existing only in `b` (e.g., source-only system columns like
// geometry or IDs that mobile never tracked in original_attributes) are NOT
// flagged as conflicts.
//
// Use this when checking "did the source diverge from what mobile snapshotted?"
// to avoid false-positive conflicts on columns mobile never knew about.
func changedFieldsInBoth(a, b map[string]any) []string {
	if a == nil {
		return nil
	}
	if b == nil {
		b = map[string]any{}
	}
	var changed []string
	for k := range a {
		if !valuesEqual(a[k], b[k]) {
			changed = append(changed, k)
		}
	}
	return changed
}
