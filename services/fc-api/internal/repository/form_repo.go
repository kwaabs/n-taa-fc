package repository

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type FormRepo struct {
    db *bun.DB
}

func NewFormRepo(db *bun.DB) *FormRepo {
    return &FormRepo{db: db}
}

func (r *FormRepo) Create(ctx context.Context, tx bun.Tx, form *model.Form) error {
    _, err := tx.NewInsert().Model(form).Exec(ctx)
    return err
}

func (r *FormRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Form, error) {
    form := new(model.Form)
    err := r.db.NewSelect().
        Model(form).
        Where("f.id = ?", id).
        Scan(ctx)
    return form, err
}

func (r *FormRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.Form, error) {
	var forms []model.Form
	err := r.db.NewSelect().
		Model(&forms).
		Where("f.project_id = ?", projectID).
		OrderExpr("f.created_at ASC").
		Scan(ctx)
	return forms, err
}

// FormTemplateRow is a form the user may reuse as a template, with project context.
type FormTemplateRow struct {
	ID          uuid.UUID `bun:"id" json:"id"`
	ProjectID   uuid.UUID `bun:"project_id" json:"project_id"`
	ProjectName string    `bun:"project_name" json:"project_name"`
	Name        string    `bun:"name" json:"name"`
	Description string    `bun:"description" json:"description"`
	Version     int       `bun:"version" json:"version"`
	UpdatedAt   time.Time `bun:"updated_at" json:"updated_at"`
}

// ListReusableTemplates returns active forms from projects the user can access.
// excludeProjectID is optional (uuid.Nil = include all).
func (r *FormRepo) ListReusableTemplates(
	ctx context.Context, userID, excludeProjectID uuid.UUID,
) ([]FormTemplateRow, error) {
	var rows []FormTemplateRow
	q := r.db.NewSelect().
		TableExpr("forms AS f").
		ColumnExpr("f.id, f.project_id, p.name AS project_name, f.name, f.description, f.version, f.updated_at").
		Join("JOIN projects AS p ON p.id = f.project_id").
		Where("f.is_active = TRUE").
		Where(`(
			EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = ? AND up.is_system_admin)
			OR EXISTS (
				SELECT 1 FROM project_members pm
				WHERE pm.project_id = f.project_id AND pm.user_id = ?
			)
			OR EXISTS (
				SELECT 1 FROM team_members tm
				JOIN project_teams pt ON pt.team_id = tm.team_id
				WHERE pt.project_id = f.project_id AND tm.user_id = ?
			)
		)`, userID, userID, userID).
		OrderExpr("p.name ASC, f.name ASC")
	if excludeProjectID != uuid.Nil {
		q = q.Where("f.project_id <> ?", excludeProjectID)
	}
	err := q.Scan(ctx, &rows)
	return rows, err
}

func (r *FormRepo) Update(ctx context.Context, form *model.Form) error {
    form.UpdatedAt = time.Now()
    _, err := r.db.NewUpdate().
        Model(form).
        WherePK().
        Column("name", "description", "schema", "version", "is_active", "updated_at").
        Exec(ctx)
    return err
}

func (r *FormRepo) CreateVersion(ctx context.Context, fv *model.FormVersion) error {
    _, err := r.db.NewInsert().Model(fv).Exec(ctx)
    return err
}

func (r *FormRepo) FindVersionByFormAndVersion(ctx context.Context, formID uuid.UUID, version int) (*model.FormVersion, error) {
    fv := new(model.FormVersion)
    err := r.db.NewSelect().
        Model(fv).
        Where("form_id = ?", formID).
        Where("version = ?", version).
        Scan(ctx)
    return fv, err
}

func (r *FormRepo) ListVersionsByForm(ctx context.Context, formID uuid.UUID) ([]model.FormVersion, error) {
    var versions []model.FormVersion
    err := r.db.NewSelect().
        Model(&versions).
        Where("form_id = ?", formID).
        OrderExpr("version DESC").
        Scan(ctx)
    return versions, err
}

func (r *FormRepo) FindLatestPublishedVersion(ctx context.Context, formID uuid.UUID) (*model.FormVersion, error) {
    fv := new(model.FormVersion)
    err := r.db.NewSelect().
        Model(fv).
        Where("form_id = ?", formID).
        Where("is_draft = false").
        OrderExpr("version DESC").
        Limit(1).
        Scan(ctx)
    return fv, err
}

// DeleteByID hard-deletes a form by ID.
func (r *FormRepo) DeleteByID(ctx context.Context, id uuid.UUID) error {
    _, err := r.db.NewDelete().
        Table("forms").
        Where("id = ?", id).
        Exec(ctx)
    return err
}