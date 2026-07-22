package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type SyncHandler struct {
	svc *service.SyncService
}

func NewSyncHandler(svc *service.SyncService) *SyncHandler {
	return &SyncHandler{svc: svc}
}

func (h *SyncHandler) GetManifest(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	lastSyncStr := r.URL.Query().Get("last_sync")
	var lastSync time.Time
	if lastSyncStr != "" {
		lastSync, err = time.Parse(time.RFC3339, lastSyncStr)
		if err != nil {
			RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "last_sync must be RFC3339 format")
			return
		}
	}

	userID := middleware.GetUserID(r.Context())
	manifest, err := h.svc.GetManifest(r.Context(), projectID, userID, lastSync)
	if err != nil {
		RespondError(w, http.StatusForbidden, "MANIFEST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, manifest)
}

func (h *SyncHandler) PullConfig(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	resp, err := h.svc.PullConfig(r.Context(), projectID, userID)
	if err != nil {
		RespondError(w, http.StatusForbidden, "PULL_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) PullFeatures(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	sinceStr := r.URL.Query().Get("since")
	var since time.Time
	if sinceStr != "" {
		since, err = time.Parse(time.RFC3339, sinceStr)
		if err != nil {
			RespondError(w, http.StatusBadRequest, "INVALID_PARAM", "since must be RFC3339 format")
			return
		}
	}

	userID := middleware.GetUserID(r.Context())
	features, err := h.svc.PullFeatures(r.Context(), projectID, userID, since)
	if err != nil {
		RespondError(w, http.StatusForbidden, "PULL_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, features)
}

func (h *SyncHandler) Push(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	var payload model.SyncPushPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
		return
	}

	userID := middleware.GetUserID(r.Context())
	receipt, err := h.svc.Push(r.Context(), projectID, userID, payload)
	if err != nil {
		RespondError(w, http.StatusForbidden, "PUSH_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, receipt)
}

type VerifyRequest struct {
	ClientIDs []string `json:"client_ids"`
}

// POST /api/v1/projects/{projectID}/sync/verify
func (h *SyncHandler) Verify(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	var req VerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if len(req.ClientIDs) == 0 {
		RespondJSON(w, http.StatusOK, service.VerifyResponse{
			Found:   []service.VerifyFoundEntry{},
			Missing: []string{},
		})
		return
	}
	if len(req.ClientIDs) > 500 {
		RespondError(w, http.StatusBadRequest, "TOO_MANY",
			"max 500 client_ids per request")
		return
	}

	userID := middleware.GetUserID(r.Context())
	result, err := h.svc.Verify(r.Context(), projectID, userID, req.ClientIDs)
	if err != nil {
		RespondError(w, http.StatusForbidden, "VERIFY_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, result)
}
