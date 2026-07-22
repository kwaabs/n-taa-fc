package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type FormService struct {
	db                *bun.DB
	formRepo          *repository.FormRepo
	memberRepo        *repository.MemberRepo
	validationService *ValidationService
	access            *AccessService
}

func NewFormService(
	db *bun.DB,
	formRepo *repository.FormRepo,
	memberRepo *repository.MemberRepo,
	validationService *ValidationService,
	access *AccessService,
) *FormService {
	return &FormService{
		db:                db,
		formRepo:          formRepo,
		memberRepo:        memberRepo,
		validationService: validationService,
		access:            access,
	}
}

func (s *FormService) Create(ctx context.Context, userID, projectID uuid.UUID, name, description string, schema json.RawMessage) (*model.Form, error) {
	member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	var formSchema model.FormSchema
	if err := json.Unmarshal(schema, &formSchema); err != nil {
		return nil, fmt.Errorf("invalid form schema JSON: %w", err)
	}
	if validationErrors := s.validationService.ValidateFormSchema(&formSchema); len(validationErrors) > 0 {
		errMsg := "schema validation failed:"
		for _, ve := range validationErrors {
			errMsg += fmt.Sprintf(" [%s: %s]", ve.FieldID, ve.Message)
		}
		return nil, fmt.Errorf(errMsg)
	}

	form := &model.Form{
		ProjectID: projectID, Name: name, Description: description,
		Schema: schema, Version: 1, IsActive: true,
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.formRepo.Create(ctx, tx, form); err != nil {
		return nil, fmt.Errorf("failed to create form: %w", err)
	}

	now := time.Now()
	fv := &model.FormVersion{
		FormID: form.ID, Version: 1, Schema: schema,
		IsDraft: false, PublishedAt: &now, Changelog: "Initial version",
	}
	if _, err := tx.NewInsert().Model(fv).Exec(ctx); err != nil {
		return nil, fmt.Errorf("failed to create form version: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit: %w", err)
	}
	return form, nil
}

func (s *FormService) List(ctx context.Context, projectID, userID uuid.UUID) ([]model.Form, error) {
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	return s.formRepo.ListByProject(ctx, projectID)
}

func (s *FormService) Get(ctx context.Context, formID, userID uuid.UUID) (*model.Form, error) {
	form, err := s.formRepo.FindByID(ctx, formID)
	if err != nil {
		return nil, fmt.Errorf("form not found")
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, form.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	return form, nil
}

func (s *FormService) Update(ctx context.Context, formID, userID uuid.UUID, name, description *string, schema *json.RawMessage) (*model.Form, error) {
	form, err := s.formRepo.FindByID(ctx, formID)
	if err != nil {
		return nil, fmt.Errorf("form not found")
	}
	member, err := s.memberRepo.FindByProjectAndUser(ctx, form.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}

	if name != nil {
		form.Name = *name
	}
	if description != nil {
		form.Description = *description
	}
	if schema != nil {
		var formSchema model.FormSchema
		if err := json.Unmarshal(*schema, &formSchema); err != nil {
			return nil, fmt.Errorf("invalid form schema JSON: %w", err)
		}
		if validationErrors := s.validationService.ValidateFormSchema(&formSchema); len(validationErrors) > 0 {
			errMsg := "schema validation failed:"
			for _, ve := range validationErrors {
				errMsg += fmt.Sprintf(" [%s: %s]", ve.FieldID, ve.Message)
			}
			return nil, fmt.Errorf(errMsg)
		}
		form.Schema = *schema
		form.Version++
		fv := &model.FormVersion{FormID: form.ID, Version: form.Version, Schema: *schema, IsDraft: true}
		if err := s.formRepo.CreateVersion(ctx, fv); err != nil {
			return nil, fmt.Errorf("failed to create form version: %w", err)
		}
	}

	if err := s.formRepo.Update(ctx, form); err != nil {
		return nil, fmt.Errorf("failed to update form: %w", err)
	}
	return form, nil
}

func (s *FormService) Publish(ctx context.Context, formID, userID uuid.UUID, version int) (*model.FormVersion, error) {
	form, err := s.formRepo.FindByID(ctx, formID)
	if err != nil {
		return nil, fmt.Errorf("form not found")
	}
	member, err := s.memberRepo.FindByProjectAndUser(ctx, form.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		return nil, fmt.Errorf("access denied: admin or supervisor role required")
	}
	fv, err := s.formRepo.FindVersionByFormAndVersion(ctx, formID, version)
	if err != nil {
		return nil, fmt.Errorf("version %d not found", version)
	}
	if !fv.IsDraft {
		return nil, fmt.Errorf("version %d is already published", version)
	}

	now := time.Now()
	fv.IsDraft = false
	fv.PublishedAt = &now

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin publish tx: %w", err)
	}
	defer tx.Rollback()

	// 1. Mark version as published
	if _, err := tx.NewUpdate().Model(fv).Column("is_draft", "published_at").WherePK().Exec(ctx); err != nil {
		return nil, fmt.Errorf("failed to publish version: %w", err)
	}

	// 2. Bump the parent form's updated_at so bundle hash invalidates.
	if _, err := tx.NewUpdate().Model((*model.Form)(nil)).
		Set("updated_at = ?", now).
		Where("id = ?", formID).
		Exec(ctx); err != nil {
		return nil, fmt.Errorf("failed to touch form: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit publish: %w", err)
	}

	return fv, nil
}

func (s *FormService) GetVersions(ctx context.Context, formID, userID uuid.UUID) ([]model.FormVersion, error) {
	form, err := s.formRepo.FindByID(ctx, formID)
	if err != nil {
		return nil, fmt.Errorf("form not found")
	}
	if _, err := s.memberRepo.FindByProjectAndUser(ctx, form.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	return s.formRepo.ListVersionsByForm(ctx, formID)
}

// CanManageProject reports whether the user may create/attach forms on a project.
func (s *FormService) CanManageProject(ctx context.Context, userID, projectID uuid.UUID) (bool, error) {
	if s.access == nil {
		member, err := s.memberRepo.FindByProjectAndUser(ctx, projectID, userID)
		if err != nil {
			return false, err
		}
		return member.Role == "admin" || member.Role == "supervisor", nil
	}
	return s.access.CanAccessWithRole(ctx, userID, projectID, "supervisor")
}

// ListTemplates returns forms the user can reuse (optionally excluding one project).
func (s *FormService) ListTemplates(
	ctx context.Context, userID, excludeProjectID uuid.UUID,
) ([]repository.FormTemplateRow, error) {
	return s.formRepo.ListReusableTemplates(ctx, userID, excludeProjectID)
}

// CloneIntoProject copies a form's schema into targetProject as a new published form.
func (s *FormService) CloneIntoProject(
	ctx context.Context,
	userID, targetProjectID, sourceFormID uuid.UUID,
	nameOverride string,
) (*model.Form, error) {
	ok, err := s.access.CanAccessWithRole(ctx, userID, targetProjectID, "supervisor")
	if err != nil || !ok {
		return nil, fmt.Errorf("access denied: admin or supervisor role required on target project")
	}

	source, err := s.formRepo.FindByID(ctx, sourceFormID)
	if err != nil {
		return nil, fmt.Errorf("source form not found")
	}
	srcOK, err := s.access.CanAccess(ctx, userID, source.ProjectID)
	if err != nil || !srcOK {
		return nil, fmt.Errorf("access denied: cannot read source form")
	}

	schema := source.Schema
	if pub, err := s.formRepo.FindLatestPublishedVersion(ctx, sourceFormID); err == nil && pub != nil && len(pub.Schema) > 0 {
		schema = pub.Schema
	}

	var formSchema model.FormSchema
	if err := json.Unmarshal(schema, &formSchema); err != nil {
		return nil, fmt.Errorf("invalid source form schema: %w", err)
	}
	if validationErrors := s.validationService.ValidateFormSchema(&formSchema); len(validationErrors) > 0 {
		errMsg := "schema validation failed:"
		for _, ve := range validationErrors {
			errMsg += fmt.Sprintf(" [%s: %s]", ve.FieldID, ve.Message)
		}
		return nil, fmt.Errorf(errMsg)
	}

	name := nameOverride
	if name == "" {
		name = source.Name
	}
	desc := source.Description
	if desc == "" {
		desc = "Cloned from another project"
	} else {
		desc = desc + " (cloned template)"
	}

	form := &model.Form{
		ProjectID:   targetProjectID,
		Name:        name,
		Description: desc,
		Schema:      schema,
		Version:     1,
		IsActive:    true,
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.formRepo.Create(ctx, tx, form); err != nil {
		return nil, fmt.Errorf("failed to create form: %w", err)
	}

	now := time.Now()
	fv := &model.FormVersion{
		FormID: form.ID, Version: 1, Schema: schema,
		IsDraft: false, PublishedAt: &now,
		Changelog: fmt.Sprintf("Cloned from form %s", sourceFormID),
	}
	if _, err := tx.NewInsert().Model(fv).Exec(ctx); err != nil {
		return nil, fmt.Errorf("failed to create form version: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit: %w", err)
	}
	return form, nil
}
