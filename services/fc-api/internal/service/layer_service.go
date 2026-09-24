package service

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "strconv"
    "strings"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/geostyle"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type LayerService struct {
	db             *bun.DB
	layerRepo      *repository.LayerRepo
	memberRepo     *repository.MemberRepo
	featureRepo    *repository.FeatureRepo
	attachmentRepo *repository.AttachmentRepo
	formRepo       *repository.FormRepo
	formSvc        *FormService
}

func NewLayerService(
	db *bun.DB,
	layerRepo *repository.LayerRepo,
	memberRepo *repository.MemberRepo,
	featureRepo *repository.FeatureRepo,
	attachmentRepo *repository.AttachmentRepo,
	formRepo *repository.FormRepo,
	formSvc *FormService,
) *LayerService {
	return &LayerService{
		db:             db,
		layerRepo:      layerRepo,
		memberRepo:     memberRepo,
		featureRepo:    featureRepo,
		attachmentRepo: attachmentRepo,
		formRepo:       formRepo,
		formSvc:        formSvc,
	}
}

// ─────────────────────────────────────────────────────────
// Request DTOs
// ─────────────────────────────────────────────────────────

type CreateLayerRequest struct {
    ProjectID          uuid.UUID       `json:"project_id"`
    Name               string          `json:"name"`
    GeometryType       string          `json:"geometry_type"`
    FormID             *uuid.UUID      `json:"form_id,omitempty"`
    Style              json.RawMessage `json:"style,omitempty"`
    IsEditable         bool            `json:"is_editable"`
    IsVisibleByDefault bool            `json:"is_visible_by_default"`
    SortOrder          int             `json:"sort_order"`
    SourceType         string          `json:"source_type"`
    SourceConfig       json.RawMessage `json:"source_config,omitempty"`
}

type UpdateLayerRequest struct {
    Name               *string          `json:"name,omitempty"`
    FormID             *uuid.UUID       `json:"form_id,omitempty"`
    Style              *json.RawMessage `json:"style,omitempty"`
    IsEditable         *bool            `json:"is_editable,omitempty"`
    IsVisibleByDefault *bool            `json:"is_visible_by_default,omitempty"`
    SortOrder          *int             `json:"sort_order,omitempty"`
}

// ─────────────────────────────────────────────────────────
// Standard layer operations
// ─────────────────────────────────────────────────────────

func (s *LayerService) Create(ctx context.Context, userID uuid.UUID, req CreateLayerRequest) (*model.Layer, error) {
    member, err := s.memberRepo.FindByProjectAndUser(ctx, req.ProjectID, userID)
    if err != nil || member.Role != "admin" {
        return nil, fmt.Errorf("access denied: admin role required")
    }
    if req.Name == "" {
        return nil, fmt.Errorf("name is required")
    }
    if req.GeometryType != "point" && req.GeometryType != "line" && req.GeometryType != "polygon" {
        return nil, fmt.Errorf("geometry_type must be 'point', 'line', or 'polygon'")
    }

    layer := &model.Layer{
        ProjectID:          req.ProjectID,
        Name:               req.Name,
        GeometryType:       req.GeometryType,
        FormID:             req.FormID,
        Style:              req.Style,
        IsEditable:         req.IsEditable,
        IsVisibleByDefault: req.IsVisibleByDefault,
        SortOrder:          req.SortOrder,
        SourceType:         req.SourceType,
        SourceConfig:       req.SourceConfig,
    }
    if layer.SourceType == "" {
        layer.SourceType = "collection"
    }
    if err := s.layerRepo.Create(ctx, layer); err != nil {
        return nil, fmt.Errorf("failed to create layer: %w", err)
    }
    return layer, nil
}

func (s *LayerService) List(ctx context.Context, projectID, userID uuid.UUID) ([]model.Layer, error) {
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    layers, err := s.layerRepo.ListByProject(ctx, projectID)
    if err != nil {
        return nil, err
    }
    for i := range layers {
        hydrateLinkedMeta(ctx, s, &layers[i])
        _ = geostyle.ApplyResolvedStyleJSON(ctx, s.db, &layers[i])
    }
    return layers, nil
}

// hydrateLinkedMeta fills bbox + feature_count for linked_table layers from
// source_config (and, when count is missing, a live COUNT(*) on the dbo table).
func hydrateLinkedMeta(ctx context.Context, s *LayerService, layer *model.Layer) {
    if layer == nil || layer.SourceType != "linked_table" || len(layer.SourceConfig) == 0 {
        return
    }
    var cfg map[string]any
    if err := json.Unmarshal(layer.SourceConfig, &cfg); err != nil {
        return
    }

    if len(layer.Bbox) != 4 {
        if bbox, ok := cfg["bbox"].([]any); ok && len(bbox) == 4 {
            out := make([]float64, 4)
            good := true
            for i, v := range bbox {
                n, ok := v.(float64)
                if !ok {
                    good = false
                    break
                }
                out[i] = n
            }
            if good {
                layer.Bbox = out
            }
        }
    }

    if n, ok := asInt(cfg["feature_count"]); ok {
        layer.FeatureCount = &n
        return
    }

    schema, _ := cfg["schema"].(string)
    table, _ := cfg["table"].(string)
    if schema == "" || table == "" || s == nil || s.db == nil {
        return
    }
    var count int
    q := fmt.Sprintf(
        `SELECT COUNT(*) FROM %s.%s`,
        pgQuoteIdent(schema), pgQuoteIdent(table),
    )
    if err := s.db.NewRaw(q).Scan(ctx, &count); err != nil {
        return
    }
    layer.FeatureCount = &count
    cfg["feature_count"] = count
    if raw, err := json.Marshal(cfg); err == nil {
        layer.SourceConfig = raw
        _ = s.layerRepo.Update(ctx, layer)
    }
}

func asInt(v any) (int, bool) {
    switch n := v.(type) {
    case float64:
        return int(n), true
    case int:
        return n, true
    case int64:
        return int(n), true
    case json.Number:
        i, err := n.Int64()
        return int(i), err == nil
    default:
        return 0, false
    }
}

func (s *LayerService) Get(ctx context.Context, layerID, userID uuid.UUID) (*model.Layer, error) {
    layer, err := s.layerRepo.FindByID(ctx, layerID)
    if err != nil {
        return nil, fmt.Errorf("layer not found")
    }
    if _, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID); err != nil {
        return nil, fmt.Errorf("access denied: not a member of this project")
    }
    hydrateLinkedMeta(ctx, s, layer)
    _ = geostyle.ApplyResolvedStyleJSON(ctx, s.db, layer)
    return layer, nil
}

func (s *LayerService) Update(ctx context.Context, layerID, userID uuid.UUID, req UpdateLayerRequest) (*model.Layer, error) {
    layer, err := s.layerRepo.FindByID(ctx, layerID)
    if err != nil {
        return nil, fmt.Errorf("layer not found")
    }
    member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
    if err != nil || member.Role != "admin" {
        return nil, fmt.Errorf("access denied: admin role required")
    }
    if req.Name != nil {
        layer.Name = *req.Name
    }
    if req.FormID != nil {
        layer.FormID = req.FormID
    }
    if req.Style != nil {
        if layer.SourceType == "linked_table" {
            // Shared symbology lives in app.layers — use PUT …/style instead.
            return nil, fmt.Errorf("use the Style tab (PUT /style) to edit linked layer symbology")
        }
        layer.Style = *req.Style
    }
    if req.IsEditable != nil {
        if *req.IsEditable {
            locked, err := s.isProjectAOILayer(ctx, layer.ProjectID, layer.ID)
            if err != nil {
                return nil, err
            }
            if locked {
                return nil, fmt.Errorf("cannot enable editing: this layer is the project AOI source")
            }
        }
        // Set explicitly — bun OmitZero would skip is_editable=false.
        if err := s.layerRepo.SetEditable(ctx, layer.ID, *req.IsEditable); err != nil {
            return nil, fmt.Errorf("failed to update layer: %w", err)
        }
        layer.IsEditable = *req.IsEditable
    }
    if req.IsVisibleByDefault != nil {
        layer.IsVisibleByDefault = *req.IsVisibleByDefault
    }
    if req.SortOrder != nil {
        layer.SortOrder = *req.SortOrder
    }

    if err := s.layerRepo.Update(ctx, layer); err != nil {
        return nil, fmt.Errorf("failed to update layer: %w", err)
    }
    _ = geostyle.ApplyResolvedStyleJSON(ctx, s.db, layer)
    return layer, nil
}

func (s *LayerService) isProjectAOILayer(ctx context.Context, projectID, layerID uuid.UUID) (bool, error) {
    project := new(model.Project)
    if err := s.db.NewSelect().Model(project).Column("config").Where("id = ?", projectID).Scan(ctx); err != nil {
        return false, fmt.Errorf("project not found")
    }
    return project.IsAOILayer(layerID), nil
}

// Delete performs a permission-checked **shallow** delete.
// Use this only if you know the layer has no features/attachments/orphan-form risk.
// In most cases, prefer DeleteCascade.
func (s *LayerService) Delete(ctx context.Context, layerID, userID uuid.UUID) error {
    layer, err := s.layerRepo.FindByID(ctx, layerID)
    if err != nil {
        return fmt.Errorf("layer not found")
    }
    member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
    if err != nil || member.Role != "admin" {
        return fmt.Errorf("access denied: admin role required")
    }
    return s.layerRepo.Delete(ctx, layerID)
}

func (s *LayerService) Publish(ctx context.Context, projectID, layerID, userID uuid.UUID) (*model.Layer, error) {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	if layer.ProjectID != projectID {
		return nil, fmt.Errorf("layer does not belong to this project")
	}

	if layer.SourceType == "linked_table" {
		layer, err = s.EnsureLinkedForm(ctx, layerID, userID)
		if err != nil {
			return nil, fmt.Errorf("ensure linked form: %w", err)
		}
	}

	if layer.FormID != nil && s.formSvc != nil {
		if err := s.formSvc.PublishLatestDraft(ctx, *layer.FormID, userID); err != nil {
			return nil, fmt.Errorf("publish layer form: %w", err)
		}
	}

	if err := s.layerRepo.Publish(ctx, layerID, userID); err != nil {
		return nil, fmt.Errorf("failed to publish layer: %w", err)
	}
	return s.layerRepo.FindByID(ctx, layerID)
}

func (s *LayerService) Unpublish(ctx context.Context, projectID, layerID, userID uuid.UUID) (*model.Layer, error) {
    member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        return nil, fmt.Errorf("access denied: admin or supervisor role required")
    }
    layer, err := s.layerRepo.FindByID(ctx, layerID)
    if err != nil {
        return nil, fmt.Errorf("layer not found")
    }
    if layer.ProjectID != projectID {
        return nil, fmt.Errorf("layer does not belong to this project")
    }
    if err := s.layerRepo.Unpublish(ctx, layerID); err != nil {
        return nil, fmt.Errorf("failed to unpublish layer: %w", err)
    }
    return s.layerRepo.FindByID(ctx, layerID)
}

// LinkedRow is a paginated view of a live linked_table source row.
type LinkedRow struct {
    ID         string                 `json:"id"`
    SourceRef  string                 `json:"source_ref"`
    Source     string                 `json:"source"`
    Attributes map[string]interface{} `json:"attributes"`
    Geometry   json.RawMessage        `json:"geometry,omitempty"`
    Linked     bool                   `json:"_linked"`
}

// LinkedRowFilter is one AND-ed condition for ListLinkedRows.
type LinkedRowFilter struct {
	Field string `json:"field"`
	Op    string `json:"op"` // eq|neq|gt|gte|lt|lte|contains|starts_with|is_null|is_not_null
	Value string `json:"value"`
}

// ListLinkedRows pages through the live source table for a linked_table layer.
// filters are AND-ed column conditions; searchQ is a legacy free-text OR across columns.
func (s *LayerService) ListLinkedRows(
	ctx context.Context, layerID, userID uuid.UUID, limit, offset int, searchQ string, filters []LinkedRowFilter,
) ([]LinkedRow, int, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, 0, fmt.Errorf("layer not found")
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID); err != nil {
		return nil, 0, fmt.Errorf("access denied: not a member of this project")
	}
	if layer.SourceType != "linked_table" {
		return nil, 0, fmt.Errorf("layer is not a linked_table")
	}

	var cfg struct {
		Schema         string   `json:"schema"`
		Table          string   `json:"table"`
		IDColumn       string   `json:"id_column"`
		GeometryColumn string   `json:"geometry_column"`
		Included       []string `json:"included_columns"`
	}
	if err := json.Unmarshal(layer.SourceConfig, &cfg); err != nil || cfg.Schema == "" || cfg.Table == "" {
		return nil, 0, fmt.Errorf("linked layer is missing schema/table in source_config")
	}

	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	qualified := pgQuoteIdent(cfg.Schema) + "." + pgQuoteIdent(cfg.Table)

	cols, err := listTableColumns(ctx, s.db, cfg.Schema, cfg.Table, cfg.GeometryColumn)
	if err != nil {
		return nil, 0, fmt.Errorf("discover columns: %w", err)
	}

	included := map[string]bool{}
	for _, c := range cfg.Included {
		included[c] = true
	}

	selectParts := make([]string, 0, len(cols)+1)
	attrCols := make([]string, 0, len(cols))
	attrSet := map[string]bool{}
	geomCol := cfg.GeometryColumn
	for _, c := range cols {
		if c.IsGeometry || (geomCol != "" && c.Name == geomCol) {
			if geomCol == "" {
				geomCol = c.Name
			}
			continue
		}
		if len(included) > 0 && !included[c.Name] && c.Name != cfg.IDColumn {
			continue
		}
		selectParts = append(selectParts, pgQuoteIdent(c.Name))
		attrCols = append(attrCols, c.Name)
		attrSet[c.Name] = true
	}
	if geomCol != "" {
		selectParts = append(selectParts,
			fmt.Sprintf("ST_AsGeoJSON(ST_Transform(%s, 4326)) AS __geom__", pgQuoteIdent(geomCol)))
	}
	if len(selectParts) == 0 {
		return []LinkedRow{}, 0, nil
	}

	whereParts := []string{}
	var args []interface{}
	argN := 0
	nextArg := func(v interface{}) string {
		argN++
		args = append(args, v)
		return fmt.Sprintf("$%d", argN)
	}

	if len(filters) > 0 {
		built, err := buildLinkedFilterSQL(filters, attrSet, nextArg)
		if err != nil {
			return nil, 0, err
		}
		whereParts = append(whereParts, built...)
	}

	searchQ = strings.TrimSpace(searchQ)
	if searchQ != "" && len(attrCols) > 0 {
		ph := nextArg("%" + escapeILIKE(searchQ) + "%")
		ors := make([]string, 0, len(attrCols))
		for _, name := range attrCols {
			ors = append(ors, fmt.Sprintf(
				`%s::text ILIKE %s ESCAPE '\'`,
				pgQuoteIdent(name), ph,
			))
		}
		whereParts = append(whereParts, "("+strings.Join(ors, " OR ")+")")
	}

	whereSQL := ""
	if len(whereParts) > 0 {
		whereSQL = " WHERE " + strings.Join(whereParts, " AND ")
	}

	countQ := `SELECT COUNT(*) FROM ` + qualified + whereSQL
	var total int
	if err := s.db.DB.QueryRowContext(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count rows: %w", err)
	}

	orderCol := cfg.IDColumn
	if orderCol == "" {
		for _, c := range cols {
			if c.IsPrimaryKey {
				orderCol = c.Name
				break
			}
		}
	}
	orderSQL := ""
	if orderCol != "" {
		orderSQL = " ORDER BY " + pgQuoteIdent(orderCol)
	}

	q := fmt.Sprintf(
		`SELECT %s FROM %s%s%s LIMIT %d OFFSET %d`,
		strings.Join(selectParts, ", "),
		qualified,
		whereSQL,
		orderSQL,
		limit,
		offset,
	)

	rows, err := s.db.DB.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query rows: %w", err)
	}
	defer rows.Close()

	colNames, err := rows.Columns()
	if err != nil {
		return nil, 0, err
	}

	out := make([]LinkedRow, 0, limit)
	for rows.Next() {
		raw := make([]interface{}, len(colNames))
		ptrs := make([]interface{}, len(colNames))
		for i := range raw {
			ptrs[i] = &raw[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, 0, err
		}

		attrs := map[string]interface{}{}
		var geomJSON []byte
		var sourceRef string
		for i, name := range colNames {
			if name == "__geom__" {
				switch v := raw[i].(type) {
				case nil:
				case []byte:
					geomJSON = v
				case string:
					geomJSON = []byte(v)
				}
				continue
			}
			val := normalizeSQLValue(raw[i])
			attrs[name] = val
			if cfg.IDColumn != "" && name == cfg.IDColumn && val != nil {
				sourceRef = fmt.Sprint(val)
			}
		}
		if sourceRef == "" {
			for _, c := range attrCols {
				if v, ok := attrs[c]; ok && v != nil {
					sourceRef = fmt.Sprint(v)
					break
				}
			}
		}
		if sourceRef == "" {
			sourceRef = fmt.Sprintf("row-%d", offset+len(out))
		}

		row := LinkedRow{
			ID:         sourceRef,
			SourceRef:  sourceRef,
			Source:     "linked",
			Attributes: attrs,
			Linked:     true,
		}
		if len(geomJSON) > 0 {
			row.Geometry = json.RawMessage(geomJSON)
		}
		out = append(out, row)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return out, total, nil
}

func buildLinkedFilterSQL(
	filters []LinkedRowFilter,
	allowed map[string]bool,
	nextArg func(interface{}) string,
) ([]string, error) {
	parts := make([]string, 0, len(filters))
	for i, f := range filters {
		field := strings.TrimSpace(f.Field)
		op := strings.ToLower(strings.TrimSpace(f.Op))
		if field == "" || op == "" {
			continue
		}
		if !allowed[field] {
			return nil, fmt.Errorf("filter[%d]: column %q is not searchable on this layer", i, field)
		}
		col := pgQuoteIdent(field)
		switch op {
		case "eq":
			parts = append(parts, fmt.Sprintf("%s::text = %s", col, nextArg(f.Value)))
		case "neq":
			parts = append(parts, fmt.Sprintf("%s::text <> %s", col, nextArg(f.Value)))
		case "gt", "gte", "lt", "lte":
			sqlOp := map[string]string{"gt": ">", "gte": ">=", "lt": "<", "lte": "<="}[op]
			// Prefer numeric compare when the value looks numeric.
			if _, err := strconv.ParseFloat(strings.TrimSpace(f.Value), 64); err == nil {
				parts = append(parts, fmt.Sprintf(
					`NULLIF(regexp_replace(%s::text, '[^0-9.\-]+', '', 'g'), '')::numeric %s %s::numeric`,
					col, sqlOp, nextArg(strings.TrimSpace(f.Value)),
				))
			} else {
				parts = append(parts, fmt.Sprintf("%s::text %s %s", col, sqlOp, nextArg(f.Value)))
			}
		case "contains":
			parts = append(parts, fmt.Sprintf(
				`%s::text ILIKE %s ESCAPE '\'`,
				col, nextArg("%"+escapeILIKE(f.Value)+"%"),
			))
		case "starts_with":
			parts = append(parts, fmt.Sprintf(
				`%s::text ILIKE %s ESCAPE '\'`,
				col, nextArg(escapeILIKE(f.Value)+"%"),
			))
		case "is_null":
			parts = append(parts, fmt.Sprintf("%s IS NULL", col))
		case "is_not_null":
			parts = append(parts, fmt.Sprintf("%s IS NOT NULL", col))
		default:
			return nil, fmt.Errorf("filter[%d]: unsupported operator %q", i, f.Op)
		}
	}
	return parts, nil
}

func escapeILIKE(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `%`, `\%`)
	s = strings.ReplaceAll(s, `_`, `\_`)
	return s
}

func normalizeSQLValue(v interface{}) interface{} {
    switch x := v.(type) {
    case nil:
        return nil
    case []byte:
        return string(x)
    case time.Time:
        return x.UTC().Format(time.RFC3339)
    default:
        return x
    }
}

// EnsureLinkedForm creates a form from the live source table columns when a
// linked_table layer has no form yet (e.g. older link imports that skipped forms).
// When a form already exists, it appends the standard optional Photos field if
// missing and publishes a new version so mobile picks it up on the next sync.
func (s *LayerService) EnsureLinkedForm(ctx context.Context, layerID, userID uuid.UUID) (*model.Layer, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	if layer.SourceType != "linked_table" {
		return nil, fmt.Errorf("form backfill is only supported for linked_table layers")
	}

	if layer.FormID != nil {
		if err := s.ensureLinkedFormHasPhotoField(ctx, *layer.FormID); err != nil {
			return nil, err
		}
		return layer, nil
	}

	var cfg struct {
		Schema          string   `json:"schema"`
		Table           string   `json:"table"`
		GeometryColumn  string   `json:"geometry_column"`
		IncludedColumns []string `json:"included_columns"`
	}
	if err := json.Unmarshal(layer.SourceConfig, &cfg); err != nil || cfg.Schema == "" || cfg.Table == "" {
		return nil, fmt.Errorf("linked layer is missing schema/table in source_config")
	}

	cols, err := listTableColumns(ctx, s.db, cfg.Schema, cfg.Table, cfg.GeometryColumn)
	if err != nil {
		return nil, fmt.Errorf("discover columns: %w", err)
	}
	dt := model.DiscoveredTable{
		Schema:        cfg.Schema,
		Name:          cfg.Table,
		QualifiedName: cfg.Schema + "." + cfg.Table,
		Columns:       cols,
	}
	schema, err := GenerateForm(dt, cfg.IncludedColumns)
	if err != nil {
		return nil, err
	}
	schemaRaw, err := SchemaToRaw(schema)
	if err != nil {
		return nil, err
	}

	form := &model.Form{
		ProjectID:   layer.ProjectID,
		Name:        layer.Name + " Form",
		Description: "Auto-generated from " + dt.QualifiedName,
		Schema:      schemaRaw,
		Version:     1,
		IsActive:    true,
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if err := s.formRepo.Create(ctx, tx, form); err != nil {
		return nil, fmt.Errorf("create form: %w", err)
	}
	now := time.Now()
	fv := &model.FormVersion{
		FormID:      form.ID,
		Version:     1,
		Schema:      schemaRaw,
		IsDraft:     false,
		PublishedAt: &now,
		Changelog:   "Auto-generated from linked table " + dt.QualifiedName,
	}
	if _, err := tx.NewInsert().Model(fv).Exec(ctx); err != nil {
		return nil, fmt.Errorf("create form version: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	layer.FormID = &form.ID
	if err := s.layerRepo.Update(ctx, layer); err != nil {
		return nil, fmt.Errorf("link form to layer: %w", err)
	}
	return layer, nil
}

func (s *LayerService) ensureLinkedFormHasPhotoField(ctx context.Context, formID uuid.UUID) error {
	form, err := s.formRepo.FindByID(ctx, formID)
	if err != nil {
		return fmt.Errorf("form not found")
	}
	var schema model.FormSchema
	if err := json.Unmarshal(form.Schema, &schema); err != nil {
		return fmt.Errorf("invalid form schema: %w", err)
	}
	SanitizeLinkedFormSchema(&schema)
	schemaRaw, err := SchemaToRaw(&schema)
	if err != nil {
		return err
	}

	// Mobile bundles use the latest *published* schema. Do not exit early when
	// forms.schema already has Photos but the published version does not (e.g.
	// draft saved in the form builder without publish).
	if pub, pubErr := s.formRepo.FindLatestPublishedVersion(ctx, formID); pubErr == nil && pub != nil {
		if FormSchemaJSONEqual(schemaRaw, pub.Schema) {
			form.Schema = schemaRaw
			form.Version = pub.Version
			return s.formRepo.Update(ctx, form)
		}
	}

	versions, err := s.formRepo.ListVersionsByForm(ctx, formID)
	if err != nil {
		return fmt.Errorf("list form versions: %w", err)
	}

	maxVer := form.Version
	for _, v := range versions {
		if v.Version > maxVer {
			maxVer = v.Version
		}
	}

	now := time.Now()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	changelog := "Sanitize linked form: drop system ID fields, ensure optional Photos"

	if len(versions) > 0 && versions[0].IsDraft {
		latest := versions[0]
		latest.Schema = schemaRaw
		latest.IsDraft = false
		latest.PublishedAt = &now
		latest.Changelog = changelog
		if _, err := tx.NewUpdate().
			Model(&latest).
			Column("schema", "is_draft", "published_at", "changelog").
			WherePK().
			Exec(ctx); err != nil {
			return fmt.Errorf("publish form version: %w", err)
		}
		form.Schema = schemaRaw
		form.Version = latest.Version
		form.UpdatedAt = now
		if _, err := tx.NewUpdate().
			Model(form).
			WherePK().
			Column("schema", "version", "updated_at").
			Exec(ctx); err != nil {
			return fmt.Errorf("update form: %w", err)
		}
		return tx.Commit()
	}

	nextVer := maxVer + 1
	fv := &model.FormVersion{
		FormID:      form.ID,
		Version:     nextVer,
		Schema:      schemaRaw,
		IsDraft:     false,
		PublishedAt: &now,
		Changelog:   changelog,
	}

	form.Schema = schemaRaw
	form.Version = nextVer
	form.UpdatedAt = now

	if _, err := tx.NewInsert().Model(fv).Exec(ctx); err != nil {
		return fmt.Errorf("create form version: %w", err)
	}
	if _, err := tx.NewUpdate().
		Model(form).
		WherePK().
		Column("schema", "version", "updated_at").
		Exec(ctx); err != nil {
		return fmt.Errorf("update form: %w", err)
	}
	return tx.Commit()
}

// ApplyFormTemplate attaches a form to a layer. Same-project forms are linked
// directly; cross-project forms are cloned into this project first.
func (s *LayerService) ApplyFormTemplate(
	ctx context.Context,
	layerID, userID, sourceFormID uuid.UUID,
	nameOverride string,
) (*model.Layer, error) {
	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	ok, err := s.formSvc.CanManageProject(ctx, userID, layer.ProjectID)
	if err != nil || !ok {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	source, err := s.formRepo.FindByID(ctx, sourceFormID)
	if err != nil {
		return nil, fmt.Errorf("source form not found")
	}

	var formID uuid.UUID
	if source.ProjectID == layer.ProjectID {
		formID = source.ID
	} else {
		if s.formSvc == nil {
			return nil, fmt.Errorf("form clone service unavailable")
		}
		cloned, err := s.formSvc.CloneIntoProject(ctx, userID, layer.ProjectID, sourceFormID, nameOverride)
		if err != nil {
			return nil, err
		}
		formID = cloned.ID
	}

	layer.FormID = &formID
	if err := s.layerRepo.Update(ctx, layer); err != nil {
		return nil, fmt.Errorf("link form to layer: %w", err)
	}
	if layer.SourceType == "linked_table" {
		if err := s.ensureLinkedFormHasPhotoField(ctx, formID); err != nil {
			return nil, err
		}
	}
	return layer, nil
}

func listTableColumns(ctx context.Context, db *bun.DB, schema, table, geomColumn string) ([]model.DiscoveredColumn, error) {
    type colRow struct {
        ColumnName string `bun:"column_name"`
        DataType   string `bun:"data_type"`
        UDTName    string `bun:"udt_name"`
        IsNullable string `bun:"is_nullable"`
    }
    var rows []colRow
    err := db.NewRaw(`
        SELECT column_name, data_type, udt_name, is_nullable
        FROM information_schema.columns
        WHERE table_schema = ? AND table_name = ?
        ORDER BY ordinal_position
    `, schema, table).Scan(ctx, &rows)
    if err != nil {
        return nil, err
    }
    if len(rows) == 0 {
        return nil, fmt.Errorf("no columns found for %s.%s", schema, table)
    }

    pkSet := map[string]bool{}
    var pkRows *sql.Rows
    pkRows, err = db.DB.QueryContext(ctx, `
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = ($1 || '.' || $2)::regclass
          AND i.indisprimary
    `, schema, table)
    if err == nil {
        defer pkRows.Close()
        for pkRows.Next() {
            var name string
            if pkRows.Scan(&name) == nil {
                pkSet[name] = true
            }
        }
    }

    out := make([]model.DiscoveredColumn, 0, len(rows))
    for _, r := range rows {
        c := model.DiscoveredColumn{
            Name:         r.ColumnName,
            DataType:     r.DataType,
            UDTName:      r.UDTName,
            IsPrimaryKey: pkSet[r.ColumnName],
            IsNullable:   r.IsNullable == "YES",
            IsGeometry:   r.UDTName == "geometry" || r.UDTName == "geography" ||
                (geomColumn != "" && r.ColumnName == geomColumn),
        }
        out = append(out, c)
    }
    return out, nil
}

// ─────────────────────────────────────────────────────────
// Cascade delete
// ─────────────────────────────────────────────────────────

// DeleteCascade deletes a layer and all data that depends on it.
//
// Order:
//  1. Look up the linked form_id.
//  2. Find all feature IDs in this layer.
//  3. Delete all feature_attachments tied to those features.
//  4. Delete the features.
//  5. If the linked form is not used by any other layer, delete the form.
//  6. Delete the layer.
//
// All inside a single DB transaction so partial deletes can't happen.
func (s *LayerService) DeleteCascade(ctx context.Context, layerID, userID uuid.UUID) error {
    layer, err := s.layerRepo.FindByID(ctx, layerID)
    if err != nil {
        return fmt.Errorf("layer not found")
    }

    member, err := s.memberRepo.FindByProjectAndUser(ctx, layer.ProjectID, userID)
    if err != nil || member.Role != "admin" {
        return fmt.Errorf("access denied: admin role required")
    }

    // 1. Linked form id (before we delete anything)
    formID, err := s.layerRepo.GetFormID(ctx, layerID)
    if err != nil {
        return fmt.Errorf("lookup form_id: %w", err)
    }

    // 2. Feature ids belonging to this layer
    featureIDs, err := s.featureRepo.IDsByLayer(ctx, layerID)
    if err != nil {
        return fmt.Errorf("list feature ids: %w", err)
    }

    // 3. Delete attachments tied to those features
    if len(featureIDs) > 0 {
        if _, err := s.attachmentRepo.DeleteByFeatureIDs(ctx, featureIDs); err != nil {
            return fmt.Errorf("delete attachments: %w", err)
        }
    }

    // 4. Delete features in this layer
    if _, err := s.featureRepo.DeleteByLayer(ctx, layerID); err != nil {
        return fmt.Errorf("delete features: %w", err)
    }

    // 5. Delete the layer itself (before form so we don't violate FK)
    if err := s.layerRepo.Delete(ctx, layerID); err != nil {
        return fmt.Errorf("delete layer: %w", err)
    }

    // 6. After the layer is gone, decide whether to delete the form
    if formID != nil {
        count, err := s.layerRepo.CountLayersUsingForm(ctx, *formID)
        if err != nil {
            return fmt.Errorf("count layers using form: %w", err)
        }

        // At this point the deleted layer no longer counts.
        // If still > 0, another layer references the form → keep it.
        // If 0, no remaining layer references the form → safe to delete.
        if count == 0 {
            if err := s.formRepo.DeleteByID(ctx, *formID); err != nil {
                return fmt.Errorf("delete linked form: %w", err)
            }
        }
    }

    return nil
}