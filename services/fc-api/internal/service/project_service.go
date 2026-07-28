package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type ProjectService struct {
	db          *bun.DB
	projectRepo *repository.ProjectRepo
	memberRepo  *repository.MemberRepo
	layerRepo   *repository.LayerRepo
	access      *AccessService
}

func NewProjectService(
	db *bun.DB,
	projectRepo *repository.ProjectRepo,
	memberRepo *repository.MemberRepo,
	layerRepo *repository.LayerRepo,
	access *AccessService,
) *ProjectService {
	return &ProjectService{
		db:          db,
		projectRepo: projectRepo,
		memberRepo:  memberRepo,
		layerRepo:   layerRepo,
		access:      access,
	}
}

// AOIFromLayerResult is GeoJSON built by unioning selected polygon rows.
type AOIFromLayerResult struct {
	Geometry   json.RawMessage `json:"geometry"`
	LayerID    uuid.UUID       `json:"layer_id"`
	SourceRefs []string        `json:"source_refs"`
	RowCount   int             `json:"row_count"`
}

// Create creates a new project and adds the creator as an admin member, all in a single transaction.

func (s *ProjectService) Create(
	ctx context.Context, creatorID uuid.UUID,
	name, description, mode string, config json.RawMessage,

	areaOfInterest json.RawMessage,
) (*model.Project, error) {
	if config == nil {
		config = json.RawMessage(`{}`)
	}

	project := &model.Project{
		Name:           name,
		Description:    description,
		Mode:           mode,
		Config:         config,
		Status:         "draft",
		CreatedBy:      creatorID,
		Version:        1,
		AreaOfInterest: areaOfInterest,
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Insert project
	if err := s.projectRepo.Create(ctx, tx, project); err != nil {
		return nil, fmt.Errorf("failed to create project: %w", err)
	}

	// Add creator as admin member
	member := &model.ProjectMember{
		ProjectID: project.ID,
		UserID:    creatorID,
		Role:      "admin",
		IsActive:  true,
	}
	if err := s.memberRepo.AddTx(ctx, tx, member); err != nil {
		return nil, fmt.Errorf("failed to add creator as member: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return project, nil
}

// List returns all projects the user can access (direct or via team).
func (s *ProjectService) List(ctx context.Context, userID uuid.UUID) ([]model.ProjectWithRole, error) {
	return s.projectRepo.ListByUserID(ctx, userID)
}

// Get retrieves a project by ID when the user has direct or team access.
func (s *ProjectService) Get(ctx context.Context, projectID, userID uuid.UUID) (*model.Project, error) {
	ok, err := s.access.CanAccess(ctx, userID, projectID)
	if err != nil {
		return nil, fmt.Errorf("access check failed: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("access denied: you are not a member of this project")
	}

	return s.projectRepo.FindByID(ctx, projectID)
}

// Update updates a project. Only admins can update.

// Update updates a project. Only admins can update.
func (s *ProjectService) Update(ctx context.Context, projectID, userID uuid.UUID, name, description *string, config *json.RawMessage, areaOfInterest json.RawMessage) (*model.Project, error) {
	// Check admin role
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return nil, fmt.Errorf("access denied: admin role required")
	}

	// Fetch existing project
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}

	// AOI Phase 1: Published projects are locked. All edits go through
	// archive → recreate, or via a dedicated Publish flow (future).
	if project.Status == "active" {
		return nil, fmt.Errorf("cannot edit an active (dispatched) project; archive to make changes")
	}

	// Apply updates
	if name != nil {
		project.Name = *name
	}
	if description != nil {
		project.Description = *description
	}
	if config != nil {
		project.Config = *config
	}
	// JSON null and absent both mean "don't update AOI". Only actual GeoJSON persists.
	if len(areaOfInterest) > 0 && string(areaOfInterest) != "null" {
		project.AreaOfInterest = areaOfInterest
	}

	if err := s.validateAndLockAOILayer(ctx, project); err != nil {
		return nil, err
	}

	if err := s.projectRepo.Update(ctx, project); err != nil {
		return nil, fmt.Errorf("failed to update project: %w", err)
	}

	if err := s.lockAOILayer(ctx, project); err != nil {
		return nil, err
	}

	return project, nil
}

// Archive sets a project to archived status. Only admins can archive.
func (s *ProjectService) Archive(ctx context.Context, projectID, userID uuid.UUID) error {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return fmt.Errorf("access denied: admin role required")
	}

	return s.projectRepo.Archive(ctx, projectID)
}

// Dispatch transitions a project from draft to active. Only admins can dispatch.
func (s *ProjectService) Dispatch(ctx context.Context, projectID, userID uuid.UUID) (*model.Project, error) {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || member.Role != "admin" {
		return nil, fmt.Errorf("access denied: admin role required to dispatch")
	}
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}
	if project.Status == "active" {
		return project, nil // idempotent
	}
	if project.Status == "archived" {
		return nil, fmt.Errorf("cannot dispatch an archived project")
	}
	project.Status = "active"
	project.Version = project.Version + 1
	if err := s.projectRepo.Update(ctx, project); err != nil {
		return nil, fmt.Errorf("failed to dispatch: %w", err)
	}
	return project, nil
}

// BuildAOIFromLayer unions polygon geometries for the given source_refs on a
// linked_table polygon layer, persists the AOI + aoi_layer_id, and locks the
// layer against field insert/update/delete (is_editable=false).
func (s *ProjectService) BuildAOIFromLayer(
	ctx context.Context,
	projectID, userID, layerID uuid.UUID,
	sourceRefs []string,
) (*AOIFromLayerResult, error) {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}
	if project.Status == "active" {
		return nil, fmt.Errorf("cannot change AOI on an active project; archive first")
	}

	layer, err := s.layerRepo.FindByID(ctx, layerID)
	if err != nil {
		return nil, fmt.Errorf("layer not found")
	}
	if err := validateAOISourceLayer(layer, projectID); err != nil {
		return nil, err
	}

	refs := normalizeSourceRefs(sourceRefs)
	if len(refs) == 0 {
		return nil, fmt.Errorf("select at least one row")
	}
	if len(refs) > 500 {
		return nil, fmt.Errorf("too many rows selected (max 500)")
	}

	var cfg struct {
		Schema         string `json:"schema"`
		Table          string `json:"table"`
		IDColumn       string `json:"id_column"`
		GeometryColumn string `json:"geometry_column"`
	}
	if err := json.Unmarshal(layer.SourceConfig, &cfg); err != nil || cfg.Schema == "" || cfg.Table == "" {
		return nil, fmt.Errorf("linked layer missing schema/table in source_config")
	}
	if cfg.IDColumn == "" {
		cfg.IDColumn = "ogc_fid"
	}
	if cfg.GeometryColumn == "" {
		return nil, fmt.Errorf("linked layer missing geometry_column")
	}

	qualified := pgQuoteIdent(cfg.Schema) + "." + pgQuoteIdent(cfg.Table)
	idCol := pgQuoteIdent(cfg.IDColumn)
	geomCol := pgQuoteIdent(cfg.GeometryColumn)

	placeholders := make([]string, len(refs))
	args := make([]any, len(refs))
	for i, ref := range refs {
		placeholders[i] = fmt.Sprintf("$%d", i+1)
		args[i] = ref
	}

	// Union selected polygonal geometries into one AOI (MultiPolygon-safe).
	query := fmt.Sprintf(`
		SELECT ST_AsGeoJSON(
			ST_Multi(
				ST_UnaryUnion(
					ST_Collect(
						ST_MakeValid(ST_Transform(ST_Force2D(%s), 4326))
					)
				)
			)
		)::jsonb AS geometry,
		COUNT(*)::int AS row_count
		FROM %s
		WHERE %s::text IN (%s)
		  AND %s IS NOT NULL
		  AND ST_GeometryType(%s) IN ('ST_Polygon', 'ST_MultiPolygon')
	`, geomCol, qualified, idCol, strings.Join(placeholders, ", "), geomCol, geomCol)

	var geom json.RawMessage
	var rowCount int
	err = s.db.DB.QueryRowContext(ctx, query, args...).Scan(&geom, &rowCount)
	if err == sql.ErrNoRows || (err == nil && rowCount == 0) {
		return nil, fmt.Errorf("no polygonal geometries found for the selected rows")
	}
	if err != nil {
		return nil, fmt.Errorf("union geometries: %w", err)
	}
	if len(geom) == 0 || string(geom) == "null" {
		return nil, fmt.Errorf("union produced empty geometry")
	}

	merged, err := mergeProjectConfig(project.Config, map[string]any{
		"aoi_layer_id":    layerID.String(),
		"aoi_source_refs": refs,
	})
	if err != nil {
		return nil, fmt.Errorf("update project config: %w", err)
	}
	project.Config = merged
	project.AreaOfInterest = geom

	if err := s.projectRepo.Update(ctx, project); err != nil {
		return nil, fmt.Errorf("failed to save AOI: %w", err)
	}
	if err := s.layerRepo.SetEditable(ctx, layerID, false); err != nil {
		return nil, fmt.Errorf("failed to lock AOI layer: %w", err)
	}

	return &AOIFromLayerResult{
		Geometry:   geom,
		LayerID:    layerID,
		SourceRefs: refs,
		RowCount:   rowCount,
	}, nil
}

func validateAOISourceLayer(layer *model.Layer, projectID uuid.UUID) error {
	if layer.ProjectID != projectID {
		return fmt.Errorf("layer does not belong to this project")
	}
	if layer.SourceType != "linked_table" {
		return fmt.Errorf("AOI from table requires a linked_table layer")
	}
	if !strings.EqualFold(layer.GeometryType, "polygon") {
		return fmt.Errorf("layer geometry_type must be polygon (got %q)", layer.GeometryType)
	}
	return nil
}

// validateAndLockAOILayer ensures config.aoi_layer_id (if set) points at a valid
// polygon linked_table in this project. The actual is_editable write happens in
// lockAOILayer after the project row is saved.
func (s *ProjectService) validateAndLockAOILayer(ctx context.Context, project *model.Project) error {
	aoiLayerID := project.AOILayerID()
	if aoiLayerID == nil {
		return nil
	}
	layer, err := s.layerRepo.FindByID(ctx, *aoiLayerID)
	if err != nil {
		return fmt.Errorf("aoi_layer_id: layer not found")
	}
	return validateAOISourceLayer(layer, project.ID)
}

func (s *ProjectService) lockAOILayer(ctx context.Context, project *model.Project) error {
	aoiLayerID := project.AOILayerID()
	if aoiLayerID == nil {
		return nil
	}
	if err := s.layerRepo.SetEditable(ctx, *aoiLayerID, false); err != nil {
		return fmt.Errorf("failed to lock AOI layer: %w", err)
	}
	return nil
}

func mergeProjectConfig(existing json.RawMessage, patch map[string]any) (json.RawMessage, error) {
	m := map[string]any{}
	if len(existing) > 0 && string(existing) != "null" {
		if err := json.Unmarshal(existing, &m); err != nil {
			return nil, err
		}
	}
	for k, v := range patch {
		if v == nil {
			delete(m, k)
			continue
		}
		m[k] = v
	}
	return json.Marshal(m)
}

func normalizeSourceRefs(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, r := range in {
		r = strings.TrimSpace(r)
		if r == "" || seen[r] {
			continue
		}
		seen[r] = true
		out = append(out, r)
	}
	return out
}
