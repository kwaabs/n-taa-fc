package handler

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type ImportHandler struct {
	svc            *service.ImportService
	dataSourceRepo *repository.DataSourceRepo
	layerRepo      *repository.LayerRepo
	memberRepo     *repository.MemberRepo
	featureRepo    *repository.FeatureRepo
}

func NewImportHandler(
	svc *service.ImportService,
	dataSourceRepo *repository.DataSourceRepo,
	layerRepo *repository.LayerRepo,
	memberRepo *repository.MemberRepo,
	featureRepo *repository.FeatureRepo,
) *ImportHandler {
	return &ImportHandler{
		svc:            svc,
		dataSourceRepo: dataSourceRepo,
		layerRepo:      layerRepo,
		memberRepo:     memberRepo,
		featureRepo:    featureRepo,
	}
}

// ── List & Create Data Sources ────────────────────

type CreateDataSourceRequest struct {
	Name        string          `json:"name"`
	SourceType  string          `json:"source_type"`
	Config      json.RawMessage `json:"config"`
	Credentials string          `json:"credentials,omitempty"`
}

func (h *ImportHandler) ListDataSources(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	sources, err := h.svc.ListDataSources(r.Context(), layerID, userID)
	if err != nil {
		RespondError(w, http.StatusForbidden, "LIST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, sources)
}

func (h *ImportHandler) CreateDataSource(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	var req CreateDataSourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	if req.Name == "" {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "name is required")
		return
	}

	input := service.CreateDataSourceInput{
		LayerID:     layerID,
		Name:        req.Name,
		SourceType:  req.SourceType,
		Config:      req.Config,
		Credentials: req.Credentials,
	}
	userID := middleware.GetUserID(r.Context())
	ds, err := h.svc.CreateDataSource(r.Context(), userID, input)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusCreated, ds)
}

// ── Upload File (multipart) ───────────────────────

func (h *ImportHandler) UploadFile(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}

	// Permission check
	layer, err := h.layerRepo.FindByID(r.Context(), layerID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "layer not found")
		return
	}
	userID := middleware.GetUserID(r.Context())
	member, err := h.memberRepo.FindByProjectAndUser(r.Context(), layer.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
		return
	}

	// Parse multipart form (50 MB limit)
	if err := r.ParseMultipartForm(50 << 20); err != nil {
		RespondError(w, http.StatusBadRequest, "PARSE_FAILED", "could not parse upload")
		return
	}

	file, fileHeader, err := r.FormFile("file")
	if err != nil {
		RespondError(w, http.StatusBadRequest, "NO_FILE", "file upload missing")
		return
	}
	defer file.Close()

	name := r.FormValue("name")
	if name == "" {
		name = fileHeader.Filename
	}

	// Auto-detect format from extension
	format := r.FormValue("format")
	if format == "" {
		switch {
		case hasSuffix(fileHeader.Filename, ".geojson"), hasSuffix(fileHeader.Filename, ".json"):
			format = "geojson"
		case hasSuffix(fileHeader.Filename, ".csv"):
			format = "csv"
		default:
			RespondError(w, http.StatusBadRequest, "UNKNOWN_FORMAT", "could not detect format from filename; pass ?format=geojson|csv")
			return
		}
	}

	content, err := io.ReadAll(file)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "READ_FAILED", "failed to read uploaded file")
		return
	}

	// Create the data source record
	configBytes, _ := json.Marshal(model.FileConfig{
		Format:       format,
		OriginalName: fileHeader.Filename,
	})
	ds := &model.LayerDataSource{
		LayerID:    layerID,
		Name:       name,
		SourceType: "file",
		Config:     configBytes,
		CreatedBy:  userID,
	}
	if err := h.dataSourceRepo.Create(r.Context(), ds); err != nil {
		RespondError(w, http.StatusInternalServerError, "CREATE_FAILED", err.Error())
		return
	}

	// Run import immediately
	stats, err := h.svc.ImportFromUploadedContent(r.Context(), ds, layer, userID, content, format)
	if err != nil {
		errMsg := err.Error()
		_ = h.dataSourceRepo.UpdateSyncStatus(r.Context(), ds.ID, "failed", errMsg, nil)
		RespondError(w, http.StatusBadRequest, "IMPORT_FAILED", errMsg)
		return
	}
	statsJSON, _ := json.Marshal(stats)
	_ = h.dataSourceRepo.UpdateSyncStatus(r.Context(), ds.ID, "success", "", statsJSON)

	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"data_source": ds,
		"stats":       stats,
	})
}

func hasSuffix(s, suffix string) bool {
	if len(s) < len(suffix) {
		return false
	}
	return s[len(s)-len(suffix):] == suffix
}

// ── Trigger Sync (URL / DB) ───────────────────────

func (h *ImportHandler) RunSync(w http.ResponseWriter, r *http.Request) {
	dsID, err := uuid.Parse(chi.URLParam(r, "sourceID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid source ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	stats, err := h.svc.RunSync(r.Context(), dsID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "SYNC_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, stats)
}

// ── Delete Data Source ────────────────────────────

func (h *ImportHandler) DeleteDataSource(w http.ResponseWriter, r *http.Request) {
	dsID, err := uuid.Parse(chi.URLParam(r, "sourceID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid source ID")
		return
	}

	ds, err := h.dataSourceRepo.FindByID(r.Context(), dsID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "data source not found")
		return
	}
	layer, err := h.layerRepo.FindByID(r.Context(), ds.LayerID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "layer not found")
		return
	}
	userID := middleware.GetUserID(r.Context())
	member, err := h.memberRepo.FindByProjectAndUser(r.Context(), layer.ProjectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
		return
	}

	if err := h.dataSourceRepo.Delete(r.Context(), dsID); err != nil {
		RespondError(w, http.StatusInternalServerError, "DELETE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// ── Layer Change Summary ──────────────────────────

func (h *ImportHandler) GetLayerChangeSummary(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}

	layer, err := h.layerRepo.FindByID(r.Context(), layerID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", "layer not found")
		return
	}
	userID := middleware.GetUserID(r.Context())
	if _, err := h.memberRepo.FindByProjectAndUser(r.Context(), layer.ProjectID, userID); err != nil {
		RespondError(w, http.StatusForbidden, "FORBIDDEN", "not a project member")
		return
	}

	summary, err := h.featureRepo.GetLayerChangeSummary(r.Context(), layerID)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "SUMMARY_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, summary)
}

type LinkConnectionRequest struct {
	ConnectionID *uuid.UUID `json:"connection_id"` // nil = unlink
}

// PATCH /api/v1/projects/{projectID}/layers/{layerID}/data-sources/{sourceID}/connection
//
// Links (or unlinks) a project_connection to a data source. Unlocks reconciliation
// for inline-imported data sources.
func (h *ImportHandler) LinkConnection(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	sourceID, err := uuid.Parse(chi.URLParam(r, "sourceID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid data source ID")
		return
	}

	var req LinkConnectionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	userID := middleware.GetUserID(r.Context())
	ds, err := h.svc.LinkConnection(r.Context(), userID, projectID, layerID, sourceID, req.ConnectionID)
	if err != nil {
		if isAccessDeniedImport(err) {
			RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
			return
		}
		RespondError(w, http.StatusBadRequest, "LINK_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, ds)
}

func isAccessDeniedImport(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "access denied") || strings.Contains(msg, "not a member")
}
