package repository

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type FeatureRepo struct {
	db *bun.DB
}

func NewFeatureRepo(db *bun.DB) *FeatureRepo {
	return &FeatureRepo{db: db}
}

// All selects use this column list to convert geometry to GeoJSON text
const featureColumns = `
    ft.id, ft.client_id, ft.project_id, ft.layer_id, ft.form_id, ft.form_version,
    CASE WHEN ft.geometry IS NOT NULL THEN ST_AsGeoJSON(ft.geometry)::text ELSE NULL END AS geometry,
    CASE WHEN ft.original_geometry IS NOT NULL THEN ST_AsGeoJSON(ft.original_geometry)::text ELSE NULL END AS original_geometry,
    ft.attributes, ft.status, ft.collected_by, ft.collected_at,
    ft.device_info, ft.gps_metadata, ft.synced_at,
    ft.reviewed_by, ft.reviewed_at, ft.review_notes, ft.created_at, ft.updated_at,
    ft.source, ft.source_ref, ft.data_source_id,
    ft.change_type, ft.change_at, ft.change_by,
    ft.original_attributes, ft.deleted_at,
    EXISTS (
        SELECT 1 FROM reconciliation_log rl
        WHERE rl.feature_id = ft.id
          AND rl.change_type = ft.change_type
          AND rl.outcome = 'applied'
    ) AS write_back_applied
`

const featureListColumns = `
		ft.id, ft.client_id, ft.project_id, ft.layer_id, ft.form_id, ft.form_version, ft.assignment_id,
		CASE WHEN ft.geometry IS NOT NULL THEN ST_AsGeoJSON(ft.geometry)::text ELSE NULL END AS geometry,
		CASE WHEN ft.original_geometry IS NOT NULL THEN ST_AsGeoJSON(ft.original_geometry)::text ELSE NULL END AS original_geometry,
		ft.attributes, ft.status, ft.collected_by, ft.collected_at,
		ft.device_info, ft.gps_metadata, ft.synced_at,
		ft.reviewed_by, ft.reviewed_at, ft.review_notes,
		ft.source, ft.source_ref, ft.data_source_id, ft.change_type, ft.change_at, ft.change_by,
		ft.original_attributes, ft.deleted_at, ft.created_at, ft.updated_at,
		EXISTS (
			SELECT 1 FROM reconciliation_log rl
			WHERE rl.feature_id = ft.id
			  AND rl.change_type = ft.change_type
			  AND rl.outcome = 'applied'
		) AS write_back_applied
`

func (r *FeatureRepo) Create(ctx context.Context, feature *model.Feature) error {
	if feature.ID == uuid.Nil {
		feature.ID = uuid.New()
	}
	if feature.CreatedAt.IsZero() {
		feature.CreatedAt = time.Now()
	}
	feature.UpdatedAt = time.Now()

	// Geometry: cast GeoJSON to PostGIS if provided.
	var geomExpr string
	var geomArgs []interface{}
	if feature.Geometry != nil && *feature.Geometry != "" {
		geomExpr = "ST_GeomFromGeoJSON(?)"
		geomArgs = append(geomArgs, *feature.Geometry)
	} else {
		geomExpr = "NULL"
	}

	// ── D6.0: original_geometry — same dance as geometry ──
	var origGeomExpr string
	var origGeomArgs []interface{}
	if feature.OriginalGeometry != nil && *feature.OriginalGeometry != "" {
		origGeomExpr = "ST_GeomFromGeoJSON(?)"
		origGeomArgs = append(origGeomArgs, *feature.OriginalGeometry)
	} else {
		origGeomExpr = "NULL"
	}

	// ── D1.2: source linkage + audit + tombstone columns ──
	sourceVal := feature.Source
	if sourceVal == "" {
		sourceVal = "collected"
	}

	query := `
        INSERT INTO features (
            id, client_id, assignment_id, project_id, layer_id, form_id, form_version,
            geometry, attributes, status, collected_by, collected_at,
            device_info, gps_metadata, synced_at, created_at, updated_at,
            source, source_ref, data_source_id, change_type, change_at, change_by,
            original_attributes, original_geometry, deleted_at
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?,
            ` + geomExpr + `, ?, ?, ?, ?,
            ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?,
            ?, ` + origGeomExpr + `, ?
        )
    `

	allArgs := []interface{}{
		feature.ID,
		feature.ClientID,
		feature.AssignmentID,
		feature.ProjectID,
		feature.LayerID,
		feature.FormID,
		feature.FormVersion,
	}
	allArgs = append(allArgs, geomArgs...) // geometry placeholder
	allArgs = append(allArgs,
		feature.Attributes,
		feature.Status,
		feature.CollectedBy,
		feature.CollectedAt,
		feature.DeviceInfo,
		feature.GPSMetadata,
		feature.SyncedAt,
		feature.CreatedAt,
		feature.UpdatedAt,

		// ── D1.2 ──
		sourceVal,
		feature.SourceRef,
		feature.DataSourceID,
		feature.ChangeType,
		feature.ChangeAt,
		feature.ChangeBy,
		feature.OriginalAttributes,
	)
	allArgs = append(allArgs, origGeomArgs...) // 👈 D6.0: original_geometry placeholder
	allArgs = append(allArgs,
		feature.DeletedAt,
	)

	_, err := r.db.ExecContext(ctx, query, allArgs...)
	return err
}

func (r *FeatureRepo) CreateBatch(ctx context.Context, features []model.Feature) error {
	if len(features) == 0 {
		return nil
	}
	for i := range features {
		if err := r.Create(ctx, &features[i]); err != nil {
			return err
		}
	}
	return nil
}

func (r *FeatureRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Feature, error) {
	feature := new(model.Feature)
	err := r.db.NewSelect().
		Model(feature).
		ColumnExpr(featureColumns).
		Where("ft.id = ?", id).
		Scan(ctx)
	return feature, err
}

func (r *FeatureRepo) FindByClientID(ctx context.Context, clientID uuid.UUID) (*model.Feature, error) {
	feature := new(model.Feature)
	err := r.db.NewSelect().
		Model(feature).
		ColumnExpr(featureColumns).
		Where("ft.client_id = ?", clientID).
		Scan(ctx)
	return feature, err
}

func (r *FeatureRepo) ListByProject(ctx context.Context, projectID uuid.UUID, limit, offset int) ([]model.Feature, int, error) {
	var features []model.Feature

	// Count first
	count, err := r.db.NewSelect().
		Model((*model.Feature)(nil)).
		Where("project_id = ?", projectID).
		Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	// Then select with geometry cast
	err = r.db.NewSelect().
		TableExpr("features AS ft").
		ColumnExpr("ft.id, ft.client_id, ft.project_id, ft.layer_id, ft.form_id, ft.form_version").
		ColumnExpr("CASE WHEN ft.geometry IS NOT NULL THEN ST_AsGeoJSON(ft.geometry)::text ELSE NULL END AS geometry").
		ColumnExpr("ft.attributes, ft.status, ft.collected_by, ft.collected_at").
		ColumnExpr("ft.device_info, ft.gps_metadata, ft.synced_at").
		ColumnExpr("ft.reviewed_by, ft.reviewed_at, ft.review_notes, ft.created_at, ft.updated_at").
		Where("ft.project_id = ?", projectID).
		OrderExpr("ft.collected_at DESC").
		Limit(limit).
		Offset(offset).
		Scan(ctx, &features)

	return features, count, err
}

// ListByProjectAndLayer fetches features filtered by project and optionally by layer.
func (r *FeatureRepo) ListByProjectAndLayer(ctx context.Context, projectID uuid.UUID, layerID *uuid.UUID, limit, offset int) ([]model.Feature, int, error) {
	var features []model.Feature

	countQ := r.db.NewSelect().
		Model((*model.Feature)(nil)).
		Where("project_id = ?", projectID).
		Where("deleted_at IS NULL")
	if layerID != nil {
		countQ = countQ.Where("layer_id = ?", *layerID)
	}
	count, err := countQ.Count(ctx)
	if err != nil {
		return nil, 0, err
	}

	q := r.db.NewSelect().
		TableExpr("features AS ft").
		ColumnExpr(featureListColumns).
		Where("ft.project_id = ?", projectID).
		Where("ft.deleted_at IS NULL").
		OrderExpr("ft.collected_at DESC").
		Limit(limit).
		Offset(offset)
	if layerID != nil {
		q = q.Where("ft.layer_id = ?", *layerID)
	}
	err = q.Scan(ctx, &features)
	return features, count, err
}

func (r *FeatureRepo) ListByLayer(ctx context.Context, layerID uuid.UUID, limit, offset int) ([]model.Feature, int, error) {
	var features []model.Feature
	count, err := r.db.NewSelect().
		Model(&features).
		ColumnExpr(featureColumns).
		Where("ft.layer_id = ?", layerID).
		OrderExpr("ft.collected_at DESC").
		Limit(limit).
		Offset(offset).
		ScanAndCount(ctx)
	return features, count, err
}

func (r *FeatureRepo) ListByBBox(ctx context.Context, projectID uuid.UUID, minLng, minLat, maxLng, maxLat float64) ([]model.Feature, error) {
	var features []model.Feature
	err := r.db.NewSelect().
		Model(&features).
		ColumnExpr(featureColumns).
		Where("ft.project_id = ?", projectID).
		Where("ft.geometry IS NOT NULL").
		Where("ST_Intersects(ft.geometry, ST_MakeEnvelope(?, ?, ?, ?, 4326))", minLng, minLat, maxLng, maxLat).
		Scan(ctx)
	return features, err
}

func (r *FeatureRepo) ListModifiedSince(ctx context.Context, projectID uuid.UUID, since time.Time) ([]model.Feature, error) {
	var features []model.Feature
	err := r.db.NewSelect().
		Model(&features).
		ColumnExpr(featureColumns).
		Where("ft.project_id = ?", projectID).
		Where("ft.updated_at > ?", since).
		OrderExpr("ft.updated_at ASC").
		Scan(ctx)
	return features, err
}

func (r *FeatureRepo) Update(ctx context.Context, feature *model.Feature) error {
	feature.UpdatedAt = time.Now()
	_, err := r.db.NewUpdate().
		Model(feature).
		WherePK().
		OmitZero().
		ExcludeColumn("geometry").
		Exec(ctx)
	return err
}

func (r *FeatureRepo) UpdateStatus(ctx context.Context, featureID uuid.UUID, status string, reviewedBy *uuid.UUID, reviewNotes string) error {
	now := time.Now()
	q := r.db.NewUpdate().
		Model((*model.Feature)(nil)).
		Set("status = ?", status).
		Set("updated_at = ?", now).
		Where("id = ?", featureID)

	if reviewedBy != nil {
		q = q.Set("reviewed_by = ?", *reviewedBy).
			Set("reviewed_at = ?", now).
			Set("review_notes = ?", reviewNotes)
	}

	_, err := q.Exec(ctx)
	return err
}

func (r *FeatureRepo) CountByProject(ctx context.Context, projectID uuid.UUID) (int, error) {
	return r.db.NewSelect().
		Model((*model.Feature)(nil)).
		Where("project_id = ?", projectID).
		Count(ctx)
}

func (r *FeatureRepo) CountModifiedSince(ctx context.Context, projectID uuid.UUID, since time.Time) (int, error) {
	return r.db.NewSelect().
		Model((*model.Feature)(nil)).
		Where("project_id = ?", projectID).
		Where("updated_at > ?", since).
		Count(ctx)
}

// SoftDelete marks a feature as deleted instead of removing it.
func (r *FeatureRepo) SoftDelete(ctx context.Context, id uuid.UUID, deletedBy uuid.UUID) error {
	now := time.Now()
	_, err := r.db.NewUpdate().
		Model((*model.Feature)(nil)).
		Set("deleted_at = ?", now).
		Set("change_type = ?", "deleted").
		Set("change_at = ?", now).
		Set("change_by = ?", deletedBy).
		Set("updated_at = ?", now).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// FindBySourceRef finds an existing reference feature by layer + source_ref (for updates).
func (r *FeatureRepo) FindBySourceRef(ctx context.Context, layerID uuid.UUID, sourceRef string) (*model.Feature, error) {
	feature := new(model.Feature)
	err := r.db.NewSelect().
		Model(feature).
		ColumnExpr(`
            ft.id, ft.client_id, ft.project_id, ft.layer_id, ft.form_id, ft.form_version, ft.assignment_id,
            CASE WHEN ft.geometry IS NOT NULL THEN ST_AsGeoJSON(ft.geometry)::text ELSE NULL END AS geometry,
            ft.attributes, ft.status, ft.collected_by, ft.collected_at, ft.device_info, ft.gps_metadata,
            ft.synced_at, ft.reviewed_by, ft.reviewed_at, ft.review_notes, ft.created_at, ft.updated_at,
            ft.source, ft.source_ref, ft.data_source_id, ft.change_type, ft.change_at, ft.change_by,
            ft.original_attributes, ft.deleted_at
        `).
		Where("ft.layer_id = ?", layerID).
		Where("ft.source_ref = ?", sourceRef).
		Where("ft.deleted_at IS NULL").
		Scan(ctx)
	return feature, err
}

// ImportReferenceFeature inserts a reference feature (or skips if duplicate source_ref).
func (r *FeatureRepo) ImportReferenceFeature(ctx context.Context, feature *model.Feature) error {
	if feature.ID == uuid.Nil {
		feature.ID = uuid.New()
	}
	if feature.CreatedAt.IsZero() {
		feature.CreatedAt = time.Now()
	}
	feature.UpdatedAt = time.Now()
	feature.Source = "reference"
	feature.OriginalAttributes = feature.Attributes // snapshot

	var geomExpr string
	var geomArgs []interface{}
	if feature.Geometry != nil && *feature.Geometry != "" {
		geomExpr = "ST_GeomFromGeoJSON(?)"
		geomArgs = append(geomArgs, *feature.Geometry)
	} else {
		geomExpr = "NULL"
	}

	query := `
        INSERT INTO features (
            id, client_id, project_id, layer_id, form_id, form_version,
            geometry, attributes, status, collected_by, collected_at,
            created_at, updated_at,
            source, source_ref, data_source_id, original_attributes
        ) VALUES (
            ?, ?, ?, ?, ?, ?,
            ` + geomExpr + `, ?, ?, ?, ?,
            ?, ?,
            ?, ?, ?, ?
        )
        ON CONFLICT (client_id) DO NOTHING
    `

	args := []interface{}{
		feature.ID, feature.ClientID, feature.ProjectID, feature.LayerID,
		feature.FormID, feature.FormVersion,
	}
	args = append(args, geomArgs...)
	args = append(args,
		feature.Attributes, feature.Status, feature.CollectedBy, feature.CollectedAt,
		feature.CreatedAt, feature.UpdatedAt,
		feature.Source, feature.SourceRef, feature.DataSourceID, feature.OriginalAttributes,
	)

	_, err := r.db.ExecContext(ctx, query, args...)
	return err
}

// GetLayerChangeSummary returns aggregated change stats for a layer.
func (r *FeatureRepo) GetLayerChangeSummary(ctx context.Context, layerID uuid.UUID) (*model.LayerChangeSummary, error) {
	type row struct {
		Source     string
		ChangeType string `bun:"change_type"`
		Count      int
	}
	var rows []row
	err := r.db.NewSelect().
		TableExpr("features").
		ColumnExpr("source, change_type, COUNT(*) AS count").
		Where("layer_id = ?", layerID).
		GroupExpr("source, change_type").
		Scan(ctx, &rows)
	if err != nil {
		return nil, err
	}

	summary := &model.LayerChangeSummary{LayerID: layerID}
	for _, r := range rows {
		summary.TotalFeatures += r.Count
		if r.Source == "reference" {
			summary.ReferenceCount += r.Count
		} else {
			summary.CollectedCount += r.Count
		}
		switch r.ChangeType {
		case "updated":
			summary.UpdatedCount += r.Count
		case "deleted":
			summary.DeletedCount += r.Count
		case "inserted":
			summary.NewCount += r.Count
		case "":
			summary.UnchangedCount += r.Count
		}
	}
	return summary, nil
}

// Update with change tracking: when reference data is updated, capture original
func (r *FeatureRepo) UpdateWithChangeTracking(ctx context.Context, id uuid.UUID, newAttrs json.RawMessage, newGeometry *string, changedBy uuid.UUID) error {
	now := time.Now()

	// First, fetch the existing feature to snapshot if it's a reference
	existing, err := r.FindByID(ctx, id)
	if err != nil {
		return err
	}

	q := r.db.NewUpdate().
		Model((*model.Feature)(nil)).
		Set("attributes = ?::jsonb", string(newAttrs)).
		Set("change_at = ?", now).
		Set("change_by = ?", changedBy).
		Set("updated_at = ?", now).
		Where("id = ?", id)

	// Mark as updated if it's a reference feature
	if existing.Source == "reference" && existing.ChangeType != "inserted" {
		q = q.Set("change_type = ?", "updated")
		// Snapshot original if not already done
		if existing.OriginalAttributes == nil {
			q = q.Set("original_attributes = ?::jsonb", string(existing.Attributes))
		}
	}

	if newGeometry != nil && *newGeometry != "" {
		q = q.Set("geometry = ST_GeomFromGeoJSON(?)", *newGeometry)
	}

	_, err = q.Exec(ctx)
	return err
}

type VerifyResult struct {
	ClientID  string    `bun:"client_id" json:"client_id"`
	ServerID  string    `bun:"id"        json:"server_id"`
	Status    string    `bun:"status"    json:"status"`
	UpdatedAt time.Time `bun:"updated_at" json:"updated_at"`
}

// FindByClientIDs returns features in the project whose client_id matches.
// Used by the verify endpoint for sync recovery.
func (r *FeatureRepo) FindByClientIDs(
	ctx context.Context,
	projectID uuid.UUID,
	clientIDs []string,
) ([]VerifyResult, error) {
	if len(clientIDs) == 0 {
		return []VerifyResult{}, nil
	}

	// Filter out empty / non-UUID strings to avoid query errors
	cleaned := make([]uuid.UUID, 0, len(clientIDs))
	for _, s := range clientIDs {
		u, err := uuid.Parse(s)
		if err == nil {
			cleaned = append(cleaned, u)
		}
	}
	if len(cleaned) == 0 {
		return []VerifyResult{}, nil
	}

	var results []VerifyResult
	err := r.db.NewSelect().
		TableExpr("features AS f").
		ColumnExpr("f.client_id::text AS client_id").
		ColumnExpr("f.id::text AS id").
		ColumnExpr("f.status").
		ColumnExpr("f.updated_at").
		Where("f.project_id = ?", projectID).
		Where("f.client_id IN (?)", bun.In(cleaned)).
		Where("f.deleted_at IS NULL").
		Scan(ctx, &results)
	return results, err
}

// DeleteByLayer hard-deletes all features in a layer.
// (We do hard delete to truly free FK references for layer deletion.)
func (r *FeatureRepo) DeleteByLayer(ctx context.Context, layerID uuid.UUID) (int64, error) {
	res, err := r.db.NewDelete().
		Table("features").
		Where("layer_id = ?", layerID).
		Exec(ctx)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// IDsByLayer returns feature IDs for a given layer.
// We need this so we can delete attachments tied to those features
// before deleting features themselves.
func (r *FeatureRepo) IDsByLayer(ctx context.Context, layerID uuid.UUID) ([]uuid.UUID, error) {
	var ids []uuid.UUID
	err := r.db.NewSelect().
		Table("features").
		Column("id").
		Where("layer_id = ?", layerID).
		Scan(ctx, &ids)
	if err != nil {
		return nil, err
	}
	return ids, nil
}

// ListPendingChanges returns features in a data source that have unresolved
// reconciliation changes (change_type = 'updated', 'deleted', or 'inserted')
// AND have not yet been pushed to source (no matching 'applied' row in
// reconciliation_log).
//
// When featureIDs is non-empty, only those feature rows are considered (per-feature
// / multi-select write-back). Caller controls ordering+chunking via limit/offset.
func (r *FeatureRepo) ListPendingChanges(
	ctx context.Context,
	dataSourceID uuid.UUID,
	limit, offset int,
	featureIDs ...uuid.UUID,
) ([]model.Feature, error) {
	var features []model.Feature

	q := r.db.NewSelect().
		TableExpr("features AS ft").
		ColumnExpr(`
		ft.id, ft.client_id, ft.project_id, ft.layer_id, ft.form_id, ft.form_version, ft.assignment_id,
		CASE WHEN ft.geometry IS NOT NULL THEN ST_AsGeoJSON(ft.geometry)::text ELSE NULL END AS geometry,
		CASE WHEN ft.original_geometry IS NOT NULL THEN ST_AsGeoJSON(ft.original_geometry)::text ELSE NULL END AS original_geometry,
		ft.attributes, ft.status, ft.collected_by, ft.collected_at,
		ft.device_info, ft.gps_metadata, ft.synced_at,
		ft.reviewed_by, ft.reviewed_at, ft.review_notes,
		ft.source, ft.source_ref, ft.data_source_id, ft.change_type, ft.change_at, ft.change_by,
		ft.original_attributes, ft.deleted_at, ft.created_at, ft.updated_at
	`).
		Where("ft.data_source_id = ?", dataSourceID).
		Where("ft.change_type IN (?, ?, ?)", "updated", "deleted", "inserted").
		Where(`NOT EXISTS (
            SELECT 1 FROM reconciliation_log rl
            WHERE rl.feature_id = ft.id
              AND rl.change_type = ft.change_type
              AND rl.outcome = 'applied'
        )`).
		OrderExpr("ft.change_at ASC NULLS LAST, ft.id ASC")

	if len(featureIDs) > 0 {
		q = q.Where("ft.id IN (?)", bun.In(featureIDs))
	}

	if limit > 0 {
		q = q.Limit(limit)
	}
	if offset > 0 {
		q = q.Offset(offset)
	}

	err := q.Scan(ctx, &features)
	return features, err
}

// CountPendingChanges returns the count of features that ListPendingChanges
// would return. Used by the preview engine for the dry-run summary.
func (r *FeatureRepo) CountPendingChanges(ctx context.Context, dataSourceID uuid.UUID) (updates, deletes int, err error) {
	type row struct {
		ChangeType string `bun:"change_type"`
		Count      int    `bun:"count"`
	}
	var rows []row
	err = r.db.NewSelect().
		TableExpr("features AS ft").
		ColumnExpr("ft.change_type, COUNT(*) AS count").
		Where("ft.data_source_id = ?", dataSourceID).
		Where("ft.change_type IN (?, ?, ?)", "updated", "deleted", "inserted").
		Where(`NOT EXISTS (
            SELECT 1 FROM reconciliation_log rl
            WHERE rl.feature_id = ft.id
              AND rl.change_type = ft.change_type
              AND rl.outcome = 'applied'
        )`).
		GroupExpr("ft.change_type").
		Scan(ctx, &rows)
	if err != nil {
		return 0, 0, err
	}
	for _, r := range rows {
		switch r.ChangeType {
		case "updated":
			updates = r.Count
		case "deleted":
			deletes = r.Count
		}
	}
	return updates, deletes, nil
}

// SetSourceRefAfterInsert records the source PK assigned by an insert write-back
// and ensures the feature is linked to its data source.
func (r *FeatureRepo) SetSourceRefAfterInsert(
	ctx context.Context,
	id uuid.UUID,
	sourceRef string,
	dataSourceID uuid.UUID,
) error {
	_, err := r.db.NewUpdate().
		Model((*model.Feature)(nil)).
		Set("source_ref = ?", sourceRef).
		Set("data_source_id = ?", dataSourceID).
		Set("updated_at = ?", time.Now()).
		Where("id = ?", id).
		Exec(ctx)
	return err
}
