package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type ImportOrchestrator struct {
	db             *bun.DB
	jobRepo        *repository.ImportJobRepo
	connectionRepo *repository.ConnectionRepo
	layerRepo      *repository.LayerRepo
	formRepo       *repository.FormRepo
	dataSourceRepo *repository.DataSourceRepo
	featureRepo    *repository.FeatureRepo
	discovery      *DiscoveryService
	encryptionKey  string
}

func NewImportOrchestrator(
	db *bun.DB,
	jobRepo *repository.ImportJobRepo,
	connectionRepo *repository.ConnectionRepo,
	layerRepo *repository.LayerRepo,
	formRepo *repository.FormRepo,
	dataSourceRepo *repository.DataSourceRepo,
	featureRepo *repository.FeatureRepo,
	discovery *DiscoveryService,
	encryptionKey string,
) *ImportOrchestrator {
	return &ImportOrchestrator{
		db:             db,
		jobRepo:        jobRepo,
		connectionRepo: connectionRepo,
		layerRepo:      layerRepo,
		formRepo:       formRepo,
		dataSourceRepo: dataSourceRepo,
		featureRepo:    featureRepo,
		discovery:      discovery,
		encryptionKey:  encryptionKey,
	}
}

// Run executes a bulk import job. Called by the worker.
func (o *ImportOrchestrator) Run(ctx context.Context, job *model.ImportJob) {
	_ = o.jobRepo.MarkRunning(ctx, job.ID)

	var cfg model.BulkImportConfig
	if err := json.Unmarshal(job.Config, &cfg); err != nil {
		o.finishWithError(ctx, job.ID, "invalid job config: "+err.Error())
		return
	}

	conn, err := o.discovery.ResolveConnection(ctx, cfg.ConnectionRef)
	if err != nil {
		o.finishWithError(ctx, job.ID, "resolve connection: "+err.Error())
		return
	}

	db, err := o.openConn(*conn)
	if err != nil {
		o.finishWithError(ctx, job.ID, "open connection: "+err.Error())
		return
	}
	defer db.Close()

	result := &model.ImportJobResult{
		TableResults: map[string]model.TableProgress{},
	}
	progress := &model.ImportJobProgress{
		Total:    len(cfg.Tables),
		Current:  0,
		PerTable: map[string]model.TableProgress{},
	}

	hasFailures := false
	hasSuccesses := false
	linkMode := strings.EqualFold(strings.TrimSpace(cfg.ImportMode), "link")

	for i, table := range cfg.Tables {
		qualifiedName := table.Schema + "." + table.Name
		progress.Current = i + 1
		if linkMode {
			progress.Message = "Linking " + qualifiedName
		} else {
			progress.Message = "Importing " + qualifiedName
		}

		// Mark this table running
		tp := model.TableProgress{Status: "running"}
		progress.PerTable[qualifiedName] = tp
		o.updateProgress(ctx, job.ID, progress)

		// 1. Create layer
		layer, err := o.createLayer(ctx, job.ProjectID, table, linkMode)
		if err != nil {
			tp.Status = "failed"
			tp.ErrorMessage = "create layer: " + err.Error()
			progress.PerTable[qualifiedName] = tp
			result.TableResults[qualifiedName] = tp
			result.Errors = append(result.Errors, qualifiedName+": "+tp.ErrorMessage)
			hasFailures = true
			o.updateProgress(ctx, job.ID, progress)
			continue
		}
		tp.LayerID = layer.ID.String()
		result.LayersCreated++

		// 2. Generate + create form (copy and link — link needs a schema for Fields tab)
		if table.GenerateForm {
			formID, err := o.createForm(ctx, job.ProjectID, layer.ID, table, *conn, job.CreatedBy)
			if err != nil {
				tp.ErrorMessage = "create form: " + err.Error()
				result.Errors = append(result.Errors, qualifiedName+": "+tp.ErrorMessage)
				// Non-fatal — keep importing / linking data
			} else {
				tp.FormID = formID.String()
				result.FormsCreated++

				// Link form to layer
				layer.FormID = &formID
				_ = o.layerRepo.Update(ctx, layer)
			}
		}

		// 3. Create the data source record
		ds, err := o.createDataSource(ctx, layer.ID, cfg.ConnectionRef, table, job.CreatedBy)
		if err != nil {
			tp.Status = "failed"
			tp.ErrorMessage = "create data source: " + err.Error()
			progress.PerTable[qualifiedName] = tp
			result.TableResults[qualifiedName] = tp
			result.Errors = append(result.Errors, qualifiedName+": "+tp.ErrorMessage)
			hasFailures = true
			o.updateProgress(ctx, job.ID, progress)
			continue
		}
		tp.DataSourceID = ds.ID.String()

		// 4. Materialize rows — skipped for link mode
		if linkMode {
			tp.Inserted = 0
			count := o.queryTableCount(ctx, db, table)
			tp.Total = count
			tp.Status = "success"
			hasSuccesses = true
			// Best-effort: store live bbox + row count on source_config
			bbox := o.queryTableBBox(ctx, db, table)
			_ = o.patchLayerSourceMeta(ctx, layer, bbox, count)
		} else {
			inserted, total, err := o.importTableData(ctx, db, ds, layer, table, job.CreatedBy, job.ID, progress)
			tp.Inserted = inserted
			tp.Total = total
			if err != nil {
				tp.Status = "failed"
				tp.ErrorMessage = "import data: " + err.Error()
				result.Errors = append(result.Errors, qualifiedName+": "+tp.ErrorMessage)
				hasFailures = true
			} else {
				tp.Status = "success"
				result.FeaturesImported += inserted
				hasSuccesses = true
			}
		}

		progress.PerTable[qualifiedName] = tp
		result.TableResults[qualifiedName] = tp
		o.updateProgress(ctx, job.ID, progress)

		// Update the data source's last sync status
		statsJSON, _ := json.Marshal(model.SyncStats{
			Total:     tp.Total,
			Inserted:  tp.Inserted,
			Unchanged: 0,
		})
		statusMsg := "success"
		if linkMode {
			statusMsg = "linked"
		}
		_ = o.dataSourceRepo.UpdateSyncStatus(ctx, ds.ID, statusMsg, "", statsJSON)
	}

	// Persist final per-table statuses before marking the job finished
	// (early continue paths used to leave the last table stuck on "running").
	o.updateProgress(ctx, job.ID, progress)

	// Determine final status
	status := "success"
	if hasFailures && hasSuccesses {
		status = "partial"
	} else if hasFailures {
		status = "failed"
	}

	resultJSON, _ := json.Marshal(result)
	_ = o.jobRepo.MarkFinished(ctx, job.ID, status, resultJSON, "")
}

// ── steps ──────────────────────────────────────────────

func (o *ImportOrchestrator) createLayer(ctx context.Context, projectID uuid.UUID, t model.BulkImportTableConfig, linkMode bool) (*model.Layer, error) {
	name := t.LayerName
	if name == "" {
		name = humanize(t.Name)
	}
	geomType := strings.ToLower(t.GeometryType)
	if geomType == "" {
		geomType = "point"
	}

	// Default style based on geometry type
	defaultStyle := model.DefaultStyle(geomType)
	styleJSON, _ := json.Marshal(defaultStyle)

	sourceType := "external"
	var sourceConfig json.RawMessage
	if linkMode {
		sourceType = "linked_table"
		cfgJSON, _ := json.Marshal(map[string]any{
			"schema":            t.Schema,
			"table":             t.Name,
			"id_column":         t.IDColumn,
			"geometry_column":   t.GeometryColumn,
			"martin_source_id":  t.Schema + "." + t.Name,
			"included_columns":  t.IncludedColumns,
		})
		sourceConfig = cfgJSON
	}

	layer := &model.Layer{
		ProjectID:          projectID,
		Name:               name,
		GeometryType:       geomType,
		Style:              styleJSON,
		IsEditable:         t.Editable && !linkMode, // linked layers edit via sparse change-sets later
		IsVisibleByDefault: true,
		SourceType:         sourceType,
		SourceConfig:       sourceConfig,
	}
	if err := o.layerRepo.Create(ctx, layer); err != nil {
		return nil, err
	}
	return layer, nil
}

func (o *ImportOrchestrator) createForm(
	ctx context.Context,
	projectID, _layerID uuid.UUID,
	t model.BulkImportTableConfig,
	conn model.BulkImportInlineConnection,
	_createdBy uuid.UUID,
) (uuid.UUID, error) {
	// Re-discover columns from the source to get real types + nullability.
	// We pass the geometry column so it's skipped automatically inside
	// discoverColumns (since it's already represented by the layer's geometry).
	cols, err := o.discovery.DiscoverTableColumns(
		ctx, conn, t.Schema, t.Name, t.GeometryColumn,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("discover columns for form: %w", err)
	}

	dt := model.DiscoveredTable{
		Schema:        t.Schema,
		Name:          t.Name,
		QualifiedName: t.Schema + "." + t.Name,
		Columns:       cols,
	}

	schema, err := GenerateForm(dt, t.IncludedColumns)
	if err != nil {
		return uuid.Nil, err
	}
	schemaRaw, _ := SchemaToRaw(schema)

	form := &model.Form{
		ProjectID:   projectID,
		Name:        t.LayerName + " Form",
		Description: "Auto-generated from " + dt.QualifiedName,
		Schema:      schemaRaw,
		Version:     1,
		IsActive:    true,
	}

	tx, err := o.db.BeginTx(ctx, nil)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback()

	if err := o.formRepo.Create(ctx, tx, form); err != nil {
		return uuid.Nil, err
	}

	now := time.Now()
	fv := &model.FormVersion{
		FormID:      form.ID,
		Version:     1,
		Schema:      schemaRaw,
		IsDraft:     false,
		PublishedAt: &now,
		Changelog:   "Auto-generated from " + dt.QualifiedName,
	}
	if _, err := tx.NewInsert().Model(fv).Exec(ctx); err != nil {
		return uuid.Nil, err
	}

	if err := tx.Commit(); err != nil {
		return uuid.Nil, err
	}
	return form.ID, nil
}

func (o *ImportOrchestrator) openTx(ctx context.Context) (interface {
	NewInsert() *bunInsert
	Rollback() error
	Commit() error
}, error) {
	// Stub — we'd need access to *bun.DB. We import the layer repo's db indirectly.
	// For simplicity in this delivery, we'll inline the form creation without a transaction.
	return nil, fmt.Errorf("transaction helper unavailable in this build")
}

type bunInsert struct{}

func (o *ImportOrchestrator) createDataSource(ctx context.Context, layerID uuid.UUID, connRef model.BulkImportConnectionRef, t model.BulkImportTableConfig, createdBy uuid.UUID) (*model.LayerDataSource, error) {
	// Build a SELECT query for ongoing re-sync
	cols := []string{}
	if t.IDColumn != "" {
		cols = append(cols, t.IDColumn)
	}
	cols = append(cols, t.IncludedColumns...)

	// Geometry projection
	geomSelect := ""
	if t.GeometryColumn != "" {
		geomSelect = fmt.Sprintf("ST_AsGeoJSON(ST_Transform(%s, 4326)) AS __geom__", quoteIdent(t.GeometryColumn))
	} else if t.LatColumn != "" && t.LngColumn != "" {
		geomSelect = fmt.Sprintf("%s AS latitude, %s AS longitude", quoteIdent(t.LatColumn), quoteIdent(t.LngColumn))
	}

	colsSQL := ""
	for _, c := range cols {
		colsSQL += ", " + quoteIdent(c)
	}
	if len(colsSQL) > 2 {
		colsSQL = colsSQL[2:]
	}

	query := fmt.Sprintf("SELECT %s, %s FROM %s.%s",
		colsSQL, geomSelect, quoteIdent(t.Schema), quoteIdent(t.Name))
	if t.FilterClause != "" {
		query += " " + t.FilterClause
	}

	// Build DatabaseConfig — note we don't store credentials here, the data source
	// will need the connection profile to be looked up at sync time. For simplicity
	// in 5A.5.1, we store an inline-credentials snapshot at the time of import.
	dbConfig := model.DatabaseConfig{
		Driver: "postgres",
		Query:  query,

		// ── D2.0: structured fields for reconciliation ──
		Schema: t.Schema,
		Table:  t.Name,

		
    // 👇 D2.4 geometry-ready
    GeometryColumn: t.GeometryColumn,
    GeometrySRID:   4326, // hardcoded for v1; future: detect from PostGIS

	}
	if connRef.Inline != nil {
		dbConfig.Host = connRef.Inline.Host
		dbConfig.Port = connRef.Inline.Port
		dbConfig.Database = connRef.Inline.Database
	}

	if connRef.ConnectionID != nil {
		// 👇 D2.0: link to project_connections so reconciliation can refresh credentials
		dbConfig.ConnectionID = connRef.ConnectionID
	}

	if t.GeometryColumn == "" && t.LatColumn != "" {
		dbConfig.LatColumn = "latitude"
		dbConfig.LngColumn = "longitude"
	}
	if t.IDColumn != "" {
		dbConfig.IDColumn = t.IDColumn
	}

	configJSON, _ := json.Marshal(dbConfig)
	ds := &model.LayerDataSource{
		LayerID:    layerID,
		Name:       t.Schema + "." + t.Name,
		SourceType: "database",
		Config:     configJSON,
		CreatedBy:  createdBy,
	}
	if t.ScheduleMinutes > 0 {
		ds.AutoRefreshMinutes = t.ScheduleMinutes
	}
	if err := o.dataSourceRepo.Create(ctx, ds); err != nil {
		return nil, err
	}
	return ds, nil
}

// importTableData streams rows from the source DB and inserts as reference features.
func (o *ImportOrchestrator) importTableData(ctx context.Context, db *sql.DB, ds *model.LayerDataSource, layer *model.Layer, t model.BulkImportTableConfig, userID, jobID uuid.UUID, progress *model.ImportJobProgress) (inserted, total int, err error) {
	// Build the SELECT
	cols := []string{}
	if t.IDColumn != "" {
		cols = append(cols, quoteIdent(t.IDColumn))
	}
	for _, c := range t.IncludedColumns {
		cols = append(cols, quoteIdent(c))
	}

	geomSelect := ""
	if t.GeometryColumn != "" {
		geomSelect = fmt.Sprintf("ST_AsGeoJSON(ST_Transform(%s, 4326)) AS __geom__", quoteIdent(t.GeometryColumn))
	} else if t.LatColumn != "" && t.LngColumn != "" {
		geomSelect = fmt.Sprintf("%s AS latitude, %s AS longitude", quoteIdent(t.LatColumn), quoteIdent(t.LngColumn))
	}

	colsSQL := strings.Join(cols, ", ")
	query := fmt.Sprintf("SELECT %s, %s FROM %s.%s",
		colsSQL, geomSelect, quoteIdent(t.Schema), quoteIdent(t.Name))
	if t.FilterClause != "" {
		query += " " + t.FilterClause
	}

	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return 0, 0, err
	}
	defer rows.Close()

	columnNames, _ := rows.Columns()
	now := time.Now()

	qualifiedName := t.Schema + "." + t.Name

	for rows.Next() {
		total++
		values := make([]interface{}, len(columnNames))
		ptrs := make([]interface{}, len(columnNames))
		for i := range values {
			ptrs[i] = &values[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			continue
		}

		row := make(map[string]interface{})
		for i, col := range columnNames {
			row[col] = values[i]
		}

		// Extract geometry
		var geomStr string
		if g, ok := row["__geom__"]; ok && g != nil {
			geomStr = asString(g)
			delete(row, "__geom__")
		} else if t.LatColumn != "" && t.LngColumn != "" {
			lat, ok1 := toFloat(row["latitude"])
			lng, ok2 := toFloat(row["longitude"])
			if ok1 && ok2 {
				geomStr = fmt.Sprintf(`{"type":"Point","coordinates":[%f,%f]}`, lng, lat)
			}
			delete(row, "latitude")
			delete(row, "longitude")
		}

		// Extract source_ref
		sourceRef := ""
		if t.IDColumn != "" {
			if v, ok := row[t.IDColumn]; ok && v != nil {
				sourceRef = fmt.Sprintf("%v", v)
				delete(row, t.IDColumn)
			}
		}

		attrsJSON, _ := json.Marshal(row)

		feature := &model.Feature{
			ClientID:     uuid.New(),
			ProjectID:    layer.ProjectID,
			LayerID:      &layer.ID,
			Geometry:     &geomStr,
			Attributes:   attrsJSON,
			Status:       "approved",
			CollectedBy:  userID,
			CollectedAt:  now,
			Source:       "reference",
			SourceRef:    sourceRef,
			DataSourceID: &ds.ID,
		}
		if layer.FormID != nil {
			feature.FormID = *layer.FormID
			feature.FormVersion = 1
		}

		if err := o.featureRepo.ImportReferenceFeature(ctx, feature); err != nil {
			continue
		}
		inserted++

		// Per-table progress update every 100 rows
		if total%100 == 0 {
			tp := progress.PerTable[qualifiedName]
			tp.Inserted = inserted
			tp.Total = total
			progress.PerTable[qualifiedName] = tp
			o.updateProgress(ctx, jobID, progress)
		}
	}

	return inserted, total, nil
}

// ── helpers ────────────────────────────────────────────

func (o *ImportOrchestrator) openConn(c model.BulkImportInlineConnection) (*sql.DB, error) {
	port := c.Port
	if port == 0 {
		port = 5432
	}
	ssl := normalizeSSLMode(c.SSLMode)

	u := &url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(c.Username, c.Password),
		Host:     fmt.Sprintf("%s:%d", c.Host, port),
		Path:     "/" + c.Database,
		RawQuery: fmt.Sprintf("sslmode=%s&connect_timeout=10", ssl),
	}

	db, err := sql.Open("postgres", u.String())
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// queryTableBBox returns [minLng, minLat, maxLng, maxLat] for a spatial table, or nil.
func (o *ImportOrchestrator) queryTableBBox(ctx context.Context, db *sql.DB, t model.BulkImportTableConfig) []float64 {
	geomCol := t.GeometryColumn
	if geomCol == "" {
		return nil
	}
	q := fmt.Sprintf(
		`SELECT ST_XMin(e), ST_YMin(e), ST_XMax(e), ST_YMax(e)
		 FROM (SELECT ST_Extent(%s)::box2d AS e FROM %s.%s) s`,
		pgQuoteIdent(geomCol), pgQuoteIdent(t.Schema), pgQuoteIdent(t.Name),
	)
	var xmin, ymin, xmax, ymax sql.NullFloat64
	if err := db.QueryRowContext(ctx, q).Scan(&xmin, &ymin, &xmax, &ymax); err != nil {
		return nil
	}
	if !xmin.Valid || !ymin.Valid || !xmax.Valid || !ymax.Valid {
		return nil
	}
	return []float64{xmin.Float64, ymin.Float64, xmax.Float64, ymax.Float64}
}

func (o *ImportOrchestrator) queryTableCount(ctx context.Context, db *sql.DB, t model.BulkImportTableConfig) int {
	q := fmt.Sprintf(
		`SELECT COUNT(*) FROM %s.%s`,
		pgQuoteIdent(t.Schema), pgQuoteIdent(t.Name),
	)
	var n int
	if err := db.QueryRowContext(ctx, q).Scan(&n); err != nil {
		return 0
	}
	return n
}

func (o *ImportOrchestrator) patchLayerSourceMeta(ctx context.Context, layer *model.Layer, bbox []float64, featureCount int) error {
	cfg := map[string]any{}
	if len(layer.SourceConfig) > 0 {
		_ = json.Unmarshal(layer.SourceConfig, &cfg)
	}
	if len(bbox) == 4 {
		cfg["bbox"] = bbox
	}
	if featureCount > 0 {
		cfg["feature_count"] = featureCount
	}
	raw, err := json.Marshal(cfg)
	if err != nil {
		return err
	}
	layer.SourceConfig = raw
	return o.layerRepo.Update(ctx, layer)
}

func (o *ImportOrchestrator) patchLayerSourceBBox(ctx context.Context, layer *model.Layer, bbox []float64) error {
	return o.patchLayerSourceMeta(ctx, layer, bbox, 0)
}

func pgQuoteIdent(ident string) string {
	return `"` + strings.ReplaceAll(ident, `"`, `""`) + `"`
}

func (o *ImportOrchestrator) updateProgress(ctx context.Context, jobID uuid.UUID, p *model.ImportJobProgress) {
	raw, err := json.Marshal(p)
	if err != nil {
		return
	}
	_ = o.jobRepo.UpdateProgress(ctx, jobID, raw)
}

func (o *ImportOrchestrator) finishWithError(ctx context.Context, jobID uuid.UUID, msg string) {
	_ = o.jobRepo.MarkFinished(ctx, jobID, "failed", nil, msg)
}

func asString(v interface{}) string {
	switch x := v.(type) {
	case string:
		return x
	case []byte:
		return string(x)
	}
	return fmt.Sprintf("%v", v)
}
