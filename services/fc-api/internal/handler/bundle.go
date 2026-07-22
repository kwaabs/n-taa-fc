package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type BundleHandler struct {
	svc *service.BundleService
}

func NewBundleHandler(svc *service.BundleService) *BundleHandler {
	return &BundleHandler{svc: svc}
}

// GET /api/v1/projects/{projectID}/bundle?reference_data=true|false
// Returns either:
//   200 + { status: "ready", download_url, ... }
//   202 + { status: "queued"|"running", job_id }
func (h *BundleHandler) Request(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	includeRef := true
	if v := r.URL.Query().Get("reference_data"); v == "false" || v == "0" {
		includeRef = false
	}

	userID := middleware.GetUserID(r.Context())
	result, err := h.svc.RequestBundle(r.Context(), projectID, userID, includeRef)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "BUNDLE_REQUEST_FAILED", err.Error())
		return
	}

	status := http.StatusOK
	if result.Status != "ready" {
		status = http.StatusAccepted
	}
	RespondJSON(w, status, result)
}

// RequestCore is the efficient-sync slim core pack: project metadata, forms,
// layer catalog, choice lists, and assignments — without reference GeoJSON/mbtiles.
// Equivalent to GET .../bundle?reference_data=false.
//
// GET /api/v1/projects/{projectID}/core-pack
func (h *BundleHandler) RequestCore(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	result, err := h.svc.RequestBundle(r.Context(), projectID, userID, false)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "CORE_PACK_REQUEST_FAILED", err.Error())
		return
	}
	status := http.StatusOK
	if result.Status != "ready" {
		status = http.StatusAccepted
	}
	RespondJSON(w, status, result)
}

// RequestLayerReferencePack returns one layer's reference GeoJSON (+ mbtiles).
//
// GET /api/v1/projects/{projectID}/layers/{layerID}/reference-pack
func (h *BundleHandler) RequestLayerReferencePack(w http.ResponseWriter, r *http.Request) {
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
	result, err := h.svc.RequestLayerReferencePack(r.Context(), projectID, layerID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "LAYER_PACK_REQUEST_FAILED", err.Error())
		return
	}
	status := http.StatusOK
	if result.Status != "ready" {
		status = http.StatusAccepted
	}
	RespondJSON(w, status, result)
}

// GET /api/v1/projects/{projectID}/bundle/jobs/{jobID}
// Also used to poll core-pack and layer reference-pack jobs (same job store).
func (h *BundleHandler) GetJob(w http.ResponseWriter, r *http.Request) {
	jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	view, err := h.svc.GetJobStatus(r.Context(), jobID, userID)
	if err != nil {
		RespondError(w, http.StatusNotFound, "JOB_NOT_FOUND", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, view)
}

// WarmPacks pre-builds core + layer reference packs before peak load.
//
// POST /api/v1/projects/{projectID}/packs/warm
// Body (optional): { "layer_ids": ["uuid", ...] }
// Empty / omitted layer_ids → all published layers (else all catalog layers).
func (h *BundleHandler) WarmPacks(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}

	var body struct {
		LayerIDs []uuid.UUID `json:"layer_ids"`
	}
	if r.Body != nil && r.ContentLength != 0 {
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			RespondError(w, http.StatusBadRequest, "INVALID_BODY", "invalid JSON body")
			return
		}
	}

	userID := middleware.GetUserID(r.Context())
	result, err := h.svc.WarmProjectPacks(r.Context(), projectID, userID, body.LayerIDs)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "WARM_PACKS_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusAccepted, result)
}

// GetPacksManifest returns content hashes for incremental download.
//
// GET /api/v1/projects/{projectID}/packs/manifest
func (h *BundleHandler) GetPacksManifest(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	manifest, err := h.svc.GetPacksManifest(r.Context(), projectID, userID)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "MANIFEST_FAILED", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, manifest)
}
