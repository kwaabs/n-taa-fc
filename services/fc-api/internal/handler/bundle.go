package handler

import (
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

// GET /api/v1/projects/{projectID}/bundle/jobs/{jobID}
// Also used to poll core-pack jobs (same job store).
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