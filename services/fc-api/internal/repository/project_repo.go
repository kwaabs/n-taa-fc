package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type ProjectRepo struct {
	db *bun.DB
}

func NewProjectRepo(db *bun.DB) *ProjectRepo {
	return &ProjectRepo{db: db}
}

func (r *ProjectRepo) Create(ctx context.Context, tx bun.Tx, project *model.Project) error {
	aoi := project.AreaOfInterest
	project.AreaOfInterest = nil

	if _, err := tx.NewInsert().Model(project).Exec(ctx); err != nil {
		return err
	}

	if len(aoi) > 0 {
		_, err := tx.NewUpdate().
			Model(project).
			Set("area_of_interest = ST_GeomFromGeoJSON(?)", string(aoi)).
			WherePK().
			Exec(ctx)
		if err != nil {
			return err
		}
	}

	project.AreaOfInterest = aoi
	return nil
}

// FindByID retrieves a project by its ID.
func (r *ProjectRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Project, error) {
	project := new(model.Project)
	err := r.db.NewSelect().
		Model(project).
		ExcludeColumn("area_of_interest").
		ColumnExpr("ST_AsGeoJSON(p.area_of_interest)::jsonb AS area_of_interest").
		Where("p.id = ?", id).
		Scan(ctx)
	return project, err
}

// ListByUserID returns projects the user can access — direct project_members
// or via team_members ∩ project_teams — matching AccessService.CanAccess.
// Direct membership role wins over team role when both apply.
func (r *ProjectRepo) ListByUserID(ctx context.Context, userID uuid.UUID) ([]model.ProjectWithRole, error) {
	var results []model.ProjectWithRole

	err := r.db.NewRaw(`
		WITH access AS (
			SELECT p.id AS project_id, pm.role AS role, 1 AS priority
			FROM projects AS p
			JOIN project_members AS pm ON pm.project_id = p.id
			WHERE pm.user_id = ?
			  AND pm.is_active = true
			  AND p.status != 'archived'

			UNION ALL

			SELECT p.id AS project_id, pt.role AS role, 2 AS priority
			FROM projects AS p
			JOIN project_teams AS pt ON pt.project_id = p.id
			JOIN team_members AS tm ON tm.team_id = pt.team_id
			WHERE tm.user_id = ?
			  AND p.status != 'archived'
		)
		SELECT
			p.id, p.name, p.description, p.mode, p.config, p.status,
			p.created_by, p.version, p.created_at, p.updated_at,
			ST_AsGeoJSON(p.area_of_interest)::jsonb AS area_of_interest,
			a.role AS role
		FROM projects AS p
		JOIN (
			SELECT DISTINCT ON (project_id) project_id, role
			FROM access
			ORDER BY project_id, priority ASC
		) AS a ON a.project_id = p.id
		ORDER BY p.updated_at DESC
	`, userID, userID).Scan(ctx, &results)

	return results, err
}

// Update updates project fields and increments version.
//
// Important: use Value() (not Set()) for overrides. Bun's Set() replaces the
// entire SET clause and ignores model columns — which silently dropped status
// (and name/description/config) on dispatch and project edits.
func (r *ProjectRepo) Update(ctx context.Context, project *model.Project) error {
	project.UpdatedAt = time.Now()

	// Extract AOI so Bun doesn't try to bind geometry column directly
	aoi := project.AreaOfInterest
	project.AreaOfInterest = nil

	q := r.db.NewUpdate().
		Model(project).
		WherePK().
		OmitZero().
		Value("version", "version + 1").
		Value("updated_at", "?", project.UpdatedAt)

	if len(aoi) > 0 && string(aoi) != "null" {
		q = q.Value("area_of_interest", "ST_GeomFromGeoJSON(?)", string(aoi))
	}

	_, err := q.Exec(ctx)

	// Restore for caller
	project.AreaOfInterest = aoi
	return err
}

// Archive sets a project's status to archived.
func (r *ProjectRepo) Archive(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.NewUpdate().
		Model((*model.Project)(nil)).
		Set("status = 'archived'").
		Set("updated_at = ?", time.Now()).
		Where("id = ?", id).
		Exec(ctx)
	return err
}

// AOIContainsGeometry returns true if the given GeoJSON geometry intersects
// the project's AOI (with buffer, in meters). Uses geography cast so buffer
// is in real-world meters, not degrees.
//
// Returns error only if the SQL fails. Caller decides whether to permit or
// reject on error (typically permit + log warning).
func (r *ProjectRepo) AOIContainsGeometry(
	ctx context.Context,
	projectID uuid.UUID,
	geomJSON string,
	bufferMeters int,
) (bool, error) {
	var inside bool
	err := r.db.NewSelect().
		TableExpr("projects").
		ColumnExpr(
			"ST_Intersects("+
				"ST_GeomFromGeoJSON(?), "+
				"ST_Buffer(area_of_interest::geography, ?)::geometry"+
				") AS inside",
			geomJSON,
			bufferMeters,
		).
		Where("id = ?", projectID).
		Limit(1).
		Scan(ctx, &inside)
	return inside, err
}
