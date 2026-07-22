package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

func containsAccessDenied(msg string) bool {
	return strings.Contains(msg, "access denied")
}

type LayerHandler struct {
	svc *service.LayerService
}

func NewLayerHandler(svc *service.LayerService) *LayerHandler {
	return &LayerHandler{svc: svc}
}

func (h *LayerHandler) Create(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	var req service.CreateLayerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	req.ProjectID = projectID
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.Create(r.Context(), userID, req)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "CREATE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusCreated, layer)
}

func (h *LayerHandler) List(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	layers, err := h.svc.List(r.Context(), projectID, userID)
	if err != nil {
		status := http.StatusInternalServerError
		code := "LIST_FAILED"
		if containsAccessDenied(err.Error()) {
			status = http.StatusForbidden
			code = "FORBIDDEN"
		}
		RespondError(w, status, code, err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layers)
}

func (h *LayerHandler) Get(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.Get(r.Context(), layerID, userID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}

func (h *LayerHandler) Update(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	var req service.UpdateLayerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.Update(r.Context(), layerID, userID, req)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "UPDATE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}

func (h *LayerHandler) Delete(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer id")
		return
	}

	userID := middleware.GetUserID(r.Context())

	if err := h.svc.DeleteCascade(r.Context(), layerID, userID); err != nil {
		slog.Error("DeleteCascade failed",
			"layer_id", layerID,
			"user_id", userID,
			"error", err.Error(),
		)
		RespondError(w, http.StatusInternalServerError, "DELETE_FAILED", err.Error())
		return
	}

	RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *LayerHandler) Publish(w http.ResponseWriter, r *http.Request) {
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
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.Publish(r.Context(), projectID, layerID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "PUBLISH_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}

func (h *LayerHandler) Unpublish(w http.ResponseWriter, r *http.Request) {
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
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.Unpublish(r.Context(), projectID, layerID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "UNPUBLISH_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}

// ListRows returns paginated live rows for a linked_table layer.
func (h *LayerHandler) ListRows(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	limit := 50
	offset := 0
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}
	searchQ := r.URL.Query().Get("q")
	var filters []service.LinkedRowFilter
	if raw := strings.TrimSpace(r.URL.Query().Get("filters")); raw != "" {
		if err := json.Unmarshal([]byte(raw), &filters); err != nil {
			RespondError(w, http.StatusBadRequest, "INVALID_FILTERS", "filters must be a JSON array of {field,op,value}")
			return
		}
	}
	userID := middleware.GetUserID(r.Context())
	rows, total, err := h.svc.ListLinkedRows(r.Context(), layerID, userID, limit, offset, searchQ, filters)
	if err != nil {
		status := http.StatusBadRequest
		if containsAccessDenied(err.Error()) {
			status = http.StatusForbidden
		}
		RespondError(w, status, "LIST_ROWS_FAILED", err.Error())
		return
	}
	RespondListWithMeta(w, http.StatusOK, rows, total, offset, limit)
}

// EnsureForm backfills a form schema from the linked source table columns.
func (h *LayerHandler) EnsureForm(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.EnsureLinkedForm(r.Context(), layerID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "ENSURE_FORM_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}

type ApplyFormTemplateRequest struct {
	SourceFormID uuid.UUID `json:"source_form_id"`
	Name         string    `json:"name,omitempty"`
}

// ApplyFormTemplate clones/links a form onto this layer.
func (h *LayerHandler) ApplyFormTemplate(w http.ResponseWriter, r *http.Request) {
	layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
		return
	}
	var req ApplyFormTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}
	if req.SourceFormID == uuid.Nil {
		RespondError(w, http.StatusBadRequest, "VALIDATION", "source_form_id is required")
		return
	}
	userID := middleware.GetUserID(r.Context())
	layer, err := h.svc.ApplyFormTemplate(r.Context(), layerID, userID, req.SourceFormID, req.Name)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "APPLY_TEMPLATE_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, layer)
}
