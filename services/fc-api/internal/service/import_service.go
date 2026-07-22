package service

import (
	"context"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/crypto"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"

	_ "github.com/lib/pq"
)

type ImportService struct {
	dataSourceRepo *repository.DataSourceRepo
	featureRepo    *repository.FeatureRepo
	layerRepo      *repository.LayerRepo
	memberRepo     *repository.MemberRepo
	connectionRepo *repository.ConnectionRepo // 👈 NEW
	projectRepo    *repository.ProjectRepo    // 👈 for AOI clip at import
	encryptionKey  string
	s3Endpoint     string
	s3Bucket       string
	s3AccessKey    string
	s3SecretKey    string
}

func NewImportService(
	dataSourceRepo *repository.DataSourceRepo,
	featureRepo *repository.FeatureRepo,
	layerRepo *repository.LayerRepo,
	memberRepo *repository.MemberRepo,
	connectionRepo *repository.ConnectionRepo, // 👈 NEW
	projectRepo *repository.ProjectRepo, // 👈 for AOI clip at import
	encryptionKey, s3Endpoint, s3Bucket, s3AccessKey, s3SecretKey string,
) *ImportService {
	return &ImportService{
		dataSourceRepo: dataSourceRepo,
		featureRepo:    featureRepo,
		layerRepo:      layerRepo,
		memberRepo:     memberRepo,
		connectionRepo: connectionRepo, // 👈 NEW
		projectRepo:    projectRepo,
		encryptionKey:  encryptionKey,
		s3Endpoint:     s3Endpoint,
		s3Bucket:       s3Bucket,
		s3AccessKey:    s3AccessKey,
		s3SecretKey:    s3SecretKey,
	}
}

// ── Data Source CRUD ──────────────────────────────

type CreateDataSourceInput struct {
	LayerID     uuid.UUID
	Name        string
	SourceType  string // file, url, database
	Config      json.RawMessage
	Credentials string // raw, will be encrypted (db only)
}

func (s *ImportService) CreateDataSource(ctx context.Context, userID uuid.UUID, input CreateDataSourceInput) (*model.LayerDataSource, error) {
	// Permission: must be project admin/supervisor
	layer, err := s.layerRepo.FindByID(ctx, input.LayerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	// Validate source type
	switch input.SourceType {
	case "file", "url", "database":
	default:
		return nil, fmt.Errorf("invalid source_type: must be file, url, or database")
	}

	ds := &model.LayerDataSource{
		LayerID:    input.LayerID,
		Name:       input.Name,
		SourceType: input.SourceType,
		Config:     input.Config,
		CreatedBy:  userID,
	}

	// Encrypt credentials for database sources
	if input.SourceType == "database" && input.Credentials != "" {
		enc, err := crypto.Encrypt(input.Credentials, s.encryptionKey)
		if err != nil {
			return nil, fmt.Errorf("failed to encrypt credentials: %w", err)
		}
		ds.EncryptedCredentials = enc
	}

	if err := s.dataSourceRepo.Create(ctx, ds); err != nil {
		return nil, fmt.Errorf("failed to create data source: %w", err)
	}
	return ds, nil
}

func (s *ImportService) ListDataSources(ctx context.Context, layerID, userID uuid.UUID) ([]model.LayerDataSource, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied")
	}
	return s.dataSourceRepo.ListByLayer(ctx, layerID)
}

// ── Run Import / Sync ─────────────────────────────

func (s *ImportService) RunSync(ctx context.Context, dataSourceID, userID uuid.UUID) (*model.SyncStats, error) {
	ds, err := s.dataSourceRepo.FindByID(ctx, dataSourceID)
	if err != nil {
		return nil, fmt.Errorf("data source not found")
	}

	layer, err := s.layerRepo.FindByID(ctx, ds.LayerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	if layer.SourceType == "linked_table" {
		return nil, fmt.Errorf("linked tables are live against the source — no materialize sync")
	}

	member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied")
	}

	// Mark as running
	_ = s.dataSourceRepo.UpdateSyncStatus(ctx, ds.ID, "running", "", nil)

	var stats *model.SyncStats
	var syncErr error

	switch ds.SourceType {
	case "file":
		stats, syncErr = s.syncFromFile(ctx, ds, layer, userID)
	case "url":
		stats, syncErr = s.syncFromURL(ctx, ds, layer, userID)
	case "database":
		stats, syncErr = s.syncFromDatabase(ctx, ds, layer, userID)
	default:
		syncErr = fmt.Errorf("unknown source type")
	}

	// Save result
	status := "success"
	errMsg := ""
	if syncErr != nil {
		status = "failed"
		errMsg = syncErr.Error()
	}
	var statsJSON []byte
	if stats != nil {
		statsJSON, _ = json.Marshal(stats)
	}
	_ = s.dataSourceRepo.UpdateSyncStatus(ctx, ds.ID, status, errMsg, statsJSON)

	return stats, syncErr
}

// ── File-based Import (uploaded GeoJSON or CSV) ────

func (s *ImportService) ImportFromUploadedContent(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID, content []byte, format string) (*model.SyncStats, error) {
	switch format {
	case "geojson":
		return s.importGeoJSON(ctx, ds, layer, userID, content)
	case "csv":
		return s.importCSV(ctx, ds, layer, userID, content)
	default:
		return nil, fmt.Errorf("unsupported format: %s (use geojson or csv)", format)
	}
}

func (s *ImportService) syncFromFile(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID) (*model.SyncStats, error) {
	// For MVP: re-sync from file means the file is already uploaded and config has storage_path
	// In a real flow, we'd fetch the file from RustFS using ds.Config.storage_path
	// For now, file sources are one-shot at upload time
	return nil, fmt.Errorf("re-sync for file sources requires re-uploading; use POST /sources/:id/upload")
}

// ── URL-based Import ──────────────────────────────

func (s *ImportService) syncFromURL(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID) (*model.SyncStats, error) {
	var cfg model.URLConfig
	if err := json.Unmarshal(ds.Config, &cfg); err != nil {
		return nil, fmt.Errorf("invalid url config: %w", err)
	}
	if cfg.URL == "" {
		return nil, fmt.Errorf("url is empty")
	}

	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequestWithContext(ctx, "GET", cfg.URL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d from source", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	format := cfg.Format
	if format == "" {
		format = "geojson"
	}

	switch format {
	case "geojson":
		return s.importGeoJSON(ctx, ds, layer, userID, body)
	case "csv":
		return s.importCSV(ctx, ds, layer, userID, body)
	}
	return nil, fmt.Errorf("unsupported format: %s", format)
}

// ── Database-based Import ─────────────────────────

func (s *ImportService) syncFromDatabase(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID) (*model.SyncStats, error) {
	var cfg model.DatabaseConfig
	if err := json.Unmarshal(ds.Config, &cfg); err != nil {
		return nil, fmt.Errorf("invalid database config: %w", err)
	}

	// Decrypt credentials
	creds, err := crypto.Decrypt(ds.EncryptedCredentials, s.encryptionKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt credentials: %w", err)
	}

	// Validate query is read-only
	queryUpper := strings.ToUpper(strings.TrimSpace(cfg.Query))
	if !strings.HasPrefix(queryUpper, "SELECT") {
		return nil, fmt.Errorf("only SELECT queries are allowed")
	}
	forbidden := []string{"INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE", "TRUNCATE", "GRANT", "REVOKE"}
	for _, kw := range forbidden {
		if strings.Contains(queryUpper, " "+kw+" ") || strings.HasPrefix(queryUpper, kw+" ") {
			return nil, fmt.Errorf("query contains forbidden keyword: %s", kw)
		}
	}

	// Build connection DSN
	port := cfg.Port
	if port == 0 {
		port = 5432
	}
	dsn := fmt.Sprintf("host=%s port=%d dbname=%s user=postgres password=%s sslmode=disable connect_timeout=10",
		cfg.Host, port, cfg.Database, creds)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("connection failed: %w", err)
	}
	defer db.Close()

	// Force read-only
	queryCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	if _, err := db.ExecContext(queryCtx, "SET TRANSACTION READ ONLY"); err != nil {
		// Not all drivers support this outside a tx; ignore
	}

	// AOI clip at import time. If the project has an AOI, push the spatial
	// filter DOWN to the source database via ST_Intersects. This can cut
	// millions of source rows to thousands before they even hit our system.
	queryToRun, err := s.applyAOIToImportQuery(ctx, layer.ProjectID, &cfg)
	if err != nil {
		return nil, fmt.Errorf("build AOI-clipped query: %w", err)
	}

	rows, err := db.QueryContext(queryCtx, queryToRun)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}

	stats := &model.SyncStats{}
	now := time.Now()

	for rows.Next() {
		values := make([]interface{}, len(cols))
		valuePtrs := make([]interface{}, len(cols))
		for i := range values {
			valuePtrs[i] = &values[i]
		}
		if err := rows.Scan(valuePtrs...); err != nil {
			stats.Errors++
			continue
		}

		row := make(map[string]interface{})
		for i, col := range cols {
			row[col] = values[i]
		}

		// Extract lat/lng
		var lat, lng float64
		var ok1, ok2 bool
		lat, ok1 = toFloat(row[cfg.LatColumn])
		lng, ok2 = toFloat(row[cfg.LngColumn])
		if !ok1 || !ok2 {
			stats.Errors++
			continue
		}

		// Extract source_ref
		sourceRef := ""
		if cfg.IDColumn != "" {
			if v := row[cfg.IDColumn]; v != nil {
				sourceRef = fmt.Sprintf("%v", v)
			}
		}

		// Remove geometry columns from attributes
		delete(row, cfg.LatColumn)
		delete(row, cfg.LngColumn)
		attrsJSON, _ := json.Marshal(row)

		geomStr := fmt.Sprintf(`{"type":"Point","coordinates":[%f,%f]}`, lng, lat)

		if err := s.importOne(ctx, ds, layer, userID, sourceRef, geomStr, attrsJSON, now, stats); err != nil {
			stats.Errors++
			continue
		}
	}

	return stats, nil
}

func toFloat(v interface{}) (float64, bool) {
	switch x := v.(type) {
	case float64:
		return x, true
	case float32:
		return float64(x), true
	case int64:
		return float64(x), true
	case int:
		return float64(x), true
	case string:
		f, err := strconv.ParseFloat(x, 64)
		return f, err == nil
	case []byte:
		f, err := strconv.ParseFloat(string(x), 64)
		return f, err == nil
	}
	return 0, false
}

// ── GeoJSON Import ────────────────────────────────

type geoJSONFeatureCollection struct {
	Type     string           `json:"type"`
	Features []geoJSONFeature `json:"features"`
}

type geoJSONFeature struct {
	Type       string                 `json:"type"`
	ID         interface{}            `json:"id,omitempty"`
	Geometry   json.RawMessage        `json:"geometry"`
	Properties map[string]interface{} `json:"properties"`
}

func (s *ImportService) importGeoJSON(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID, body []byte) (*model.SyncStats, error) {
	var fc geoJSONFeatureCollection
	if err := json.Unmarshal(body, &fc); err != nil {
		return nil, fmt.Errorf("invalid GeoJSON: %w", err)
	}
	if fc.Type != "FeatureCollection" {
		return nil, fmt.Errorf("expected FeatureCollection, got %s", fc.Type)
	}

	stats := &model.SyncStats{}
	now := time.Now()

	for _, f := range fc.Features {
		sourceRef := ""
		if f.ID != nil {
			sourceRef = fmt.Sprintf("%v", f.ID)
		} else if id, ok := f.Properties["id"]; ok {
			sourceRef = fmt.Sprintf("%v", id)
		}

		attrsJSON, _ := json.Marshal(f.Properties)
		geomStr := string(f.Geometry)

		if err := s.importOne(ctx, ds, layer, userID, sourceRef, geomStr, attrsJSON, now, stats); err != nil {
			stats.Errors++
			continue
		}
	}

	return stats, nil
}

// ── CSV Import ────────────────────────────────────

func (s *ImportService) importCSV(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID, body []byte) (*model.SyncStats, error) {
	reader := csv.NewReader(strings.NewReader(string(body)))
	reader.TrimLeadingSpace = true

	headers, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV headers: %w", err)
	}

	for i, h := range headers {
		headers[i] = strings.TrimSpace(strings.ToLower(h))
	}

	// Find lat/lng/id columns
	latIdx, lngIdx, idIdx := -1, -1, -1
	for i, h := range headers {
		switch h {
		case "lat", "latitude", "y":
			latIdx = i
		case "lng", "lon", "long", "longitude", "x":
			lngIdx = i
		case "id":
			idIdx = i
		}
	}
	if latIdx == -1 || lngIdx == -1 {
		return nil, fmt.Errorf("CSV must have lat (or latitude/y) and lng (or longitude/x) columns")
	}

	stats := &model.SyncStats{}
	now := time.Now()

	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			stats.Errors++
			continue
		}

		lat, e1 := strconv.ParseFloat(strings.TrimSpace(row[latIdx]), 64)
		lng, e2 := strconv.ParseFloat(strings.TrimSpace(row[lngIdx]), 64)
		if e1 != nil || e2 != nil {
			stats.Errors++
			continue
		}

		attrs := make(map[string]interface{})
		for i, h := range headers {
			if i == latIdx || i == lngIdx || i >= len(row) {
				continue
			}
			attrs[h] = row[i]
		}

		sourceRef := ""
		if idIdx >= 0 && idIdx < len(row) {
			sourceRef = strings.TrimSpace(row[idIdx])
		}

		attrsJSON, _ := json.Marshal(attrs)
		geomStr := fmt.Sprintf(`{"type":"Point","coordinates":[%f,%f]}`, lng, lat)

		if err := s.importOne(ctx, ds, layer, userID, sourceRef, geomStr, attrsJSON, now, stats); err != nil {
			stats.Errors++
			continue
		}
	}

	return stats, nil
}

// ── importOne: dedup by source_ref, insert or skip ─

func (s *ImportService) importOne(ctx context.Context, ds *model.LayerDataSource, layer *model.Layer, userID uuid.UUID, sourceRef, geomStr string, attrsJSON json.RawMessage, now time.Time, stats *model.SyncStats) error {
	stats.Total++

	// Check for existing reference feature by source_ref
	if sourceRef != "" {
		existing, err := s.featureRepo.FindBySourceRef(ctx, ds.LayerID, sourceRef)
		if err == nil && existing != nil && existing.ID != uuid.Nil {
			stats.Unchanged++
			return nil
		}
	}

	feature := &model.Feature{
		ClientID:     uuid.New(),
		ProjectID:    layer.ProjectID,
		LayerID:      &ds.LayerID,
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

	if err := s.featureRepo.ImportReferenceFeature(ctx, feature); err != nil {
		return err
	}
	stats.Inserted++
	return nil
}

// LinkConnection associates an existing project_connection with a data source.
// Passing nil for connectionID unlinks the data source (admin removed the link).
//
// When linking (not unlinking), this method validates that:
//   - The connection exists and belongs to the same project
//   - The credentials decrypt successfully
//   - The source DB is reachable and the source table can be queried
//
// Returns the updated data source on success.
func (s *ImportService) LinkConnection(
	ctx context.Context,
	userID, projectID, layerID, dataSourceID uuid.UUID,
	connectionID *uuid.UUID,
) (*model.LayerDataSource, error) {
	// 1. Membership
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}

	// 2. Load data source + verify ownership
	ds, err := s.dataSourceRepo.FindByID(ctx, dataSourceID)
	if err != nil {
		return nil, fmt.Errorf("data source not found: %w", err)
	}
	if ds.LayerID != layerID {
		return nil, fmt.Errorf("data source %s does not belong to layer %s", dataSourceID, layerID)
	}
	if ds.SourceType != "database" {
		return nil, fmt.Errorf("data source %s is not a database type; cannot link a connection", dataSourceID)
	}

	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return nil, fmt.Errorf("data source %s has malformed config", dataSourceID)
	}

	// 3. Validate the connection (if linking, not unlinking)
	if connectionID != nil {
		conn, err := s.connectionRepo.FindByID(ctx, *connectionID)
		if err != nil {
			return nil, fmt.Errorf("connection not found: %w", err)
		}
		if conn.ProjectID != projectID {
			return nil, fmt.Errorf("connection %s does not belong to this project", *connectionID)
		}

		// Test the connection can actually reach the source table
		password, err := crypto.Decrypt(conn.EncryptedPassword, s.encryptionKey)
		if err != nil {
			return nil, fmt.Errorf("decrypt connection password: %w", err)
		}

		if err := validateSourceAccess(ctx, conn, password, cfg.Schema, cfg.Table); err != nil {
			return nil, fmt.Errorf("connection cannot reach %s.%s: %w", cfg.Schema, cfg.Table, err)
		}
	}

	// 4. Persist updated config
	cfg.ConnectionID = connectionID
	updatedConfig, err := json.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("marshal config: %w", err)
	}
	if err := s.dataSourceRepo.UpdateConfig(ctx, dataSourceID, updatedConfig); err != nil {
		return nil, fmt.Errorf("update data source: %w", err)
	}

	// 5. Return fresh copy
	updated, err := s.dataSourceRepo.FindByID(ctx, dataSourceID)
	if err != nil {
		return nil, fmt.Errorf("reload data source: %w", err)
	}
	return updated, nil
}

// validateSourceAccess opens a connection using the given credentials and
// verifies that the source table exists and is queryable. Closes the connection
// on return.
func validateSourceAccess(
	ctx context.Context,
	conn *model.ProjectConnection,
	password, schema, table string,
) error {
	if schema == "" || table == "" {
		return fmt.Errorf("data source missing schema/table config; re-import required")
	}

	inline := model.BulkImportInlineConnection{
		Host:     conn.Host,
		Port:     conn.Port,
		Database: conn.Database,
		Username: conn.Username,
		Password: password,
		SSLMode:  conn.SSLMode,
	}
	db, err := OpenInlineSourceConnection(inline)
	if err != nil {
		return err
	}
	defer db.Close()

	q := fmt.Sprintf("SELECT 1 FROM %s.%s LIMIT 1", quoteIdent(schema), quoteIdent(table))
	row := db.QueryRowContext(ctx, q)
	var ignored int
	if err := row.Scan(&ignored); err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("validation query failed: %w", err)
	}
	return nil
}

// applyAOIToImportQuery wraps the admin's SELECT with a spatial filter tied to
// the project's AOI (plus buffer). If the project has no AOI or the config
// lacks geometry columns, returns the query unchanged.
//
// This runs the spatial predicate on the source database's PostGIS, so millions
// of source rows can be filtered down to the AOI-relevant subset before any
// data crosses to Field Collector.
func (s *ImportService) applyAOIToImportQuery(
	ctx context.Context, projectID uuid.UUID, cfg *model.DatabaseConfig,
) (string, error) {
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return "", fmt.Errorf("fetch project: %w", err)
	}

	// No AOI defined → no clipping, return query as-is
	if len(project.AreaOfInterest) == 0 {
		return cfg.Query, nil
	}

	bufferMeters := project.AOIBufferMeters()

	// Determine which geometry expression to use based on config
	var geomExpr string
	switch {
	case cfg.GeometryColumn != "":
		// Native PostGIS geometry column
		geomExpr = fmt.Sprintf("src.%s", cfg.GeometryColumn)
	case cfg.LatColumn != "" && cfg.LngColumn != "":
		// Lat/lng column pattern — build a point on the fly
		geomExpr = fmt.Sprintf(
			"ST_SetSRID(ST_MakePoint((src.%s)::float, (src.%s)::float), 4326)",
			cfg.LngColumn, cfg.LatColumn,
		)
	default:
		slog.Warn("AOI defined but source has no geometry columns; import not filtered",
			"project_id", projectID)
		return cfg.Query, nil
	}

	// Escape single quotes in AOI JSON to be safe.
	aoiJSON := strings.ReplaceAll(string(project.AreaOfInterest), "'", "''")

	wrapped := fmt.Sprintf(
		"SELECT * FROM (%s) AS src WHERE ST_Intersects(%s, ST_Buffer(ST_GeomFromGeoJSON('%s')::geography, %d)::geometry)",
		cfg.Query, geomExpr, aoiJSON, bufferMeters,
	)

	slog.Info("AOI clip applied to import query",
		"project_id", projectID,
		"buffer_m", bufferMeters,
		"has_geom_col", cfg.GeometryColumn != "",
	)

	return wrapped, nil
}
