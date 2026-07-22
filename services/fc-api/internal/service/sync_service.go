package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type SyncService struct {
	projectRepo       *repository.ProjectRepo
	formRepo          *repository.FormRepo
	featureRepo       *repository.FeatureRepo
	assignmentRepo    *repository.AssignmentRepo
	accessSvc         *AccessService
	syncLogRepo       *repository.SyncLogRepo // ← NEW (B2)
	validationService *ValidationService
	attachmentService *AttachmentService
}

func NewSyncService(
	projectRepo *repository.ProjectRepo,
	formRepo *repository.FormRepo,
	featureRepo *repository.FeatureRepo,
	assignmentRepo *repository.AssignmentRepo,
	accessSvc *AccessService,
	syncLogRepo *repository.SyncLogRepo, // ← NEW (B2)
	validationService *ValidationService,
	attachmentService *AttachmentService,
) *SyncService {
	return &SyncService{
		projectRepo:       projectRepo,
		formRepo:          formRepo,
		featureRepo:       featureRepo,
		assignmentRepo:    assignmentRepo,
		accessSvc:         accessSvc,
		syncLogRepo:       syncLogRepo, // ← NEW (B2)
		validationService: validationService,
		attachmentService: attachmentService,
	}
}

func (s *SyncService) requireAccess(ctx context.Context, projectID, userID uuid.UUID) error {
	ok, err := s.accessSvc.CanAccess(ctx, userID, projectID)
	if err != nil || !ok {
		return fmt.Errorf("access denied: not a member of this project")
	}
	return nil
}

func (s *SyncService) GetManifest(ctx context.Context, projectID, userID uuid.UUID, lastSync time.Time) (*model.SyncManifest, error) {
	if err := s.requireAccess(ctx, projectID, userID); err != nil {
		return nil, err
	}

	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}

	featuresUpdated, err := s.featureRepo.CountModifiedSince(ctx, projectID, lastSync)
	if err != nil {
		featuresUpdated = 0
	}

	assignmentsNew, err := s.assignmentRepo.CountNewSince(ctx, projectID, userID, lastSync)
	if err != nil {
		assignmentsNew = 0
	}

	forms, _ := s.formRepo.ListByProject(ctx, projectID)
	formsChanged := false
	for _, f := range forms {
		if f.UpdatedAt.After(lastSync) {
			formsChanged = true
			break
		}
	}

	return &model.SyncManifest{
		ProjectConfigVersion: project.Version,
		FormsChanged:         formsChanged,
		FeaturesUpdated:      featuresUpdated,
		AssignmentsNew:       assignmentsNew,
		ServerTime:           time.Now().UTC(),
	}, nil
}

func (s *SyncService) PullConfig(ctx context.Context, projectID, userID uuid.UUID) (*model.SyncPullResponse, error) {
	if err := s.requireAccess(ctx, projectID, userID); err != nil {
		return nil, err
	}

	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}

	forms, err := s.formRepo.ListByProject(ctx, projectID)
	if err != nil {
		forms = []model.Form{}
	}

	assignments, err := s.assignmentRepo.ListByUser(ctx, userID, projectID)
	if err != nil {
		assignments = []model.Assignment{}
	}

	return &model.SyncPullResponse{
		Config:      project.Config,
		Forms:       forms,
		Features:    []model.Feature{},
		Assignments: assignments,
	}, nil
}

func (s *SyncService) PullFeatures(ctx context.Context, projectID, userID uuid.UUID, since time.Time) ([]model.Feature, error) {
	if err := s.requireAccess(ctx, projectID, userID); err != nil {
		return nil, err
	}
	return s.featureRepo.ListModifiedSince(ctx, projectID, since)
}

func (s *SyncService) Push(ctx context.Context, projectID, userID uuid.UUID, payload model.SyncPushPayload) (*model.SyncPushReceipt, error) {
	if err := s.requireAccess(ctx, projectID, userID); err != nil {
		return nil, err
	}
	role, err := s.accessSvc.RoleOf(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("access denied: not a member of this project")
	}
	if role != "admin" && role != "supervisor" && role != "field_worker" {
		return nil, fmt.Errorf("access denied: must be a project member")
	}

	// Determine trigger (default 'manual') for sync_log
	trigger := payload.Trigger
	if trigger == "" {
		trigger = "manual"
	}

	// Start sync_log run (best-effort; do not block sync on logging failures)
	var syncLogID uuid.UUID
	if s.syncLogRepo != nil {
		if id, logErr := s.syncLogRepo.StartRun(ctx, userID, projectID, "push", trigger); logErr == nil {
			syncLogID = id
		} else {
			slog.Warn("failed to start sync_log run", "error", logErr)
		}
	}

	receipt := &model.SyncPushReceipt{SyncLogID: syncLogID}
	now := time.Now()

	// AOI Phase 3: fetch project once so we can enforce spatial rules
	// across the whole batch. If no AOI → skip all AOI checks.
	project, err := s.projectRepo.FindByID(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("project not found")
	}
	aoiEnforced := len(project.AreaOfInterest) > 0
	var aoiBufferMeters int
	if aoiEnforced {
		aoiBufferMeters = project.AOIBufferMeters()
	}

	for _, sf := range payload.Features {
		slog.Info("[D1.2 SERVER DEBUG] incoming feature",
			"client_id", sf.ClientID,
			"source_ref_ptr_nil", sf.SourceRef == nil,
			"source_ref_val", sf.SourceRef,
			"data_source_id_ptr_nil", sf.DataSourceID == nil,
			"data_source_id_val", sf.DataSourceID,
			"deleted", sf.Deleted,
			"orig_attrs_len", len(sf.OriginalAttributes),
		)

		// Dedup by client_id
		existing, findErr := s.featureRepo.FindByClientID(ctx, sf.ClientID)
		if findErr == nil && existing != nil && existing.ID != uuid.Nil {
			slog.Info("dedup: feature already exists", "client_id", sf.ClientID)
			receipt.Accepted++
			continue
		}

		// Extract geometry — handle both object and JSON-encoded string forms
		var geomStr *string
		if sf.Geometry != nil && len(*sf.Geometry) > 0 {
			raw := string(*sf.Geometry)
			if len(raw) > 1 && raw[0] == '"' && raw[len(raw)-1] == '"' {
				var unquoted string
				if err := json.Unmarshal(*sf.Geometry, &unquoted); err == nil {
					raw = unquoted
				}
			}
			geomStr = &raw
		}

		// AOI Phase 3: reject features outside buffered AOI.
		// Deletes always allowed. Grandfathering: only apply to inserts/updates.
		if aoiEnforced && !sf.Deleted && geomStr != nil {
			inside, aoiErr := s.projectRepo.AOIContainsGeometry(ctx, projectID, *geomStr, aoiBufferMeters)
			if aoiErr != nil {
				slog.Warn("aoi check failed; permitting feature", "error", aoiErr, "client_id", sf.ClientID)
			} else if !inside {
				slog.Info("feature rejected: outside AOI",
					"client_id", sf.ClientID,
					"buffer_m", aoiBufferMeters,
				)
				receipt.Errors = append(receipt.Errors, model.SyncFeatureError{
					ClientID: sf.ClientID,
					Issues: []model.SyncFieldError{{
						FieldID: "_aoi",
						Message: fmt.Sprintf("Feature is outside the project boundary (AOI + %dm buffer)", aoiBufferMeters),
					}},
					Action: "rejected",
				})
				if s.syncLogRepo != nil && syncLogID != uuid.Nil {
					cid := sf.ClientID
					_ = s.syncLogRepo.LogError(ctx, syncLogID, &cid, nil,
						"outside_aoi", fmt.Sprintf("outside AOI + %dm buffer", aoiBufferMeters), nil)
				}
				continue
			}
		}

		feature := &model.Feature{
			ClientID:     sf.ClientID,
			AssignmentID: sf.AssignmentID,
			ProjectID:    projectID,
			LayerID:      sf.LayerID,
			FormID:       sf.FormID,
			FormVersion:  sf.FormVersion,
			Geometry:     geomStr,
			Attributes:   sf.Attributes,
			Status:       sf.Status,
			CollectedBy:  userID,
			CollectedAt:  sf.CollectedAt,
			DeviceInfo:   sf.DeviceInfo,
			GPSMetadata:  sf.GPSMetadata,
			SyncedAt:     &now,

			// ── D1.2: reference-edit linkage ──
			DataSourceID:       sf.DataSourceID,
			OriginalAttributes: sf.OriginalAttributes,

			OriginalGeometry: sf.OriginalGeometry,
		}

		// SourceRef — model has string, payload has *string. Copy when set.
		if sf.SourceRef != nil {
			feature.SourceRef = *sf.SourceRef
		}

		// ── D1.2/D1.3: derive change_type from incoming payload signals ──
		//   - Deleted=true   → 'deleted'  (mobile sent a tombstone)
		//   - SourceRef set  → 'updated'  (edit of a reference feature)
		//   - Otherwise      → 'inserted' (brand-new collected capture)
		switch {
		case sf.Deleted:
			feature.ChangeType = "deleted"
		case sf.SourceRef != nil && *sf.SourceRef != "":
			feature.ChangeType = "updated"
		default:
			feature.ChangeType = "inserted"
		}
		feature.ChangeAt = &now
		feature.ChangeBy = &userID

		// Inject audit into existing form system fields (created_user, etc.)
		if attrs, err := decodeAttrs(feature.Attributes); err == nil && len(attrs) > 0 {
			mode := "insert"
			if feature.ChangeType == "updated" || feature.ChangeType == "deleted" {
				mode = "update"
			}
			InjectAuditIntoExistingAttrs(attrs, AuditValuesFromFeature(feature, userID), mode)
			if remarshaled, err := json.Marshal(attrs); err == nil {
				feature.Attributes = remarshaled
			}
		}

		// Tombstone: surveyor marked this reference as deleted on mobile.
		// Backend records deleted_at; reconciliation (later D-phase) actually
		// pushes the delete out to the source data store.
		if sf.Deleted {
			if sf.DeletedAt != nil {
				feature.DeletedAt = sf.DeletedAt
			} else {
				feature.DeletedAt = &now
			}
			feature.Status = "deleted"
		}

		if feature.Status == "" {
			feature.Status = "submitted"
		}

		// Validate attributes
		validationErrors := s.validationService.ValidateAttributes(ctx, sf.FormID, sf.FormVersion, sf.Attributes)
		if len(validationErrors) > 0 {
			featureErr := model.SyncFeatureError{
				ClientID: sf.ClientID,
				Action:   "accepted_with_warnings",
			}
			for _, ve := range validationErrors {
				featureErr.Issues = append(featureErr.Issues, model.SyncFieldError{
					FieldID: ve.FieldID,
					Message: ve.Message,
				})
				// Log each validation error to sync_errors (best-effort)
				if s.syncLogRepo != nil && syncLogID != uuid.Nil {
					cid := sf.ClientID
					_ = s.syncLogRepo.LogError(ctx, syncLogID, &cid, nil,
						"validation_failed", ve.Message, nil)
				}
			}
			receipt.Errors = append(receipt.Errors, featureErr)
			receipt.Flagged++
		}

		slog.Info("[D1.2 SERVER DEBUG] feature to insert",
			"client_id", feature.ClientID,
			"source_ref", feature.SourceRef,
			"data_source_id", feature.DataSourceID,
			"change_type", feature.ChangeType,
			"deleted_at_nil", feature.DeletedAt == nil,
		)

		// Save feature
		if err := s.featureRepo.Create(ctx, feature); err != nil {
			slog.Error("failed to save feature", "error", err, "client_id", sf.ClientID)
			receipt.Errors = append(receipt.Errors, model.SyncFeatureError{
				ClientID: sf.ClientID,
				Issues:   []model.SyncFieldError{{FieldID: "_db", Message: err.Error()}},
				Action:   "rejected",
			})
			// Log to sync_errors (best-effort)
			if s.syncLogRepo != nil && syncLogID != uuid.Nil {
				cid := sf.ClientID
				_ = s.syncLogRepo.LogError(ctx, syncLogID, &cid, nil,
					"db_insert_failed", err.Error(), nil)
			}
			continue
		}

		// Link any attachments that mobile already uploaded
		if s.attachmentService != nil && len(sf.AttachmentClientIDs) > 0 {
			if err := s.attachmentService.LinkToFeature(ctx, sf.AttachmentClientIDs, feature.ID); err != nil {
				slog.Warn("failed to link attachments", "error", err, "feature_id", feature.ID)
			}
		}

		slog.Info("feature saved", "client_id", sf.ClientID, "has_geometry", geomStr != nil)

		if len(validationErrors) == 0 {
			receipt.Accepted++
		}
	}

	// Finalise sync_log run
	if s.syncLogRepo != nil && syncLogID != uuid.Nil {
		attempted := len(payload.Features)
		succeeded := receipt.Accepted + receipt.Flagged
		failed := attempted - succeeded

		var status string
		switch {
		case failed == 0:
			status = "success"
		case succeeded > 0:
			status = "partial"
		default:
			status = "failed"
		}

		if cErr := s.syncLogRepo.CompleteRun(ctx, syncLogID, status,
			attempted, succeeded, failed,
			0, 0, 0, // attachments counted in B3
			nil,
		); cErr != nil {
			slog.Warn("failed to complete sync_log run", "error", cErr)
		}
	}

	return receipt, nil
}

// VerifyResult is the per-feature response shape.
type VerifyFoundEntry struct {
	ClientID  string `json:"client_id"`
	ServerID  string `json:"server_id"`
	Status    string `json:"status"`
	UpdatedAt string `json:"updated_at"`
}

type VerifyResponse struct {
	Found   []VerifyFoundEntry `json:"found"`
	Missing []string           `json:"missing"`
}

// Verify checks which of the provided client_ids exist on the server.
// Used by mobile for crash-recovery during sync.
func (s *SyncService) Verify(
	ctx context.Context,
	projectID, userID uuid.UUID,
	clientIDs []string,
) (*VerifyResponse, error) {
	if err := s.requireAccess(ctx, projectID, userID); err != nil {
		return nil, err
	}

	results, err := s.featureRepo.FindByClientIDs(ctx, projectID, clientIDs)
	if err != nil {
		return nil, fmt.Errorf("verify lookup: %w", err)
	}

	foundSet := make(map[string]bool, len(results))
	found := make([]VerifyFoundEntry, 0, len(results))
	for _, r := range results {
		foundSet[r.ClientID] = true
		found = append(found, VerifyFoundEntry{
			ClientID:  r.ClientID,
			ServerID:  r.ServerID,
			Status:    r.Status,
			UpdatedAt: r.UpdatedAt.Format(time.RFC3339Nano),
		})
	}

	missing := make([]string, 0)
	for _, cid := range clientIDs {
		if !foundSet[cid] {
			missing = append(missing, cid)
		}
	}

	return &VerifyResponse{
		Found:   found,
		Missing: missing,
	}, nil
}
