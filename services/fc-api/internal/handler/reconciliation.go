package handler

import (
    "encoding/json"
    "net/http"
    "strconv"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type ReconciliationHandler struct {
    svc  *service.ReconciliationService
    pool *service.ReconciliationWorkerPool
}

func NewReconciliationHandler(
    svc *service.ReconciliationService,
    pool *service.ReconciliationWorkerPool,
) *ReconciliationHandler {
    return &ReconciliationHandler{svc: svc, pool: pool}
}

// ── Request body types ────────────────────────────────

type ReconcileRequest struct {
	BatchSize        int         `json:"batch_size,omitempty"`
	FeatureIDs       []uuid.UUID `json:"feature_ids,omitempty"`
	Acknowledgments  []string    `json:"acknowledgments,omitempty"` // hard_delete, evw_target, home_db_write, skipped_fields
}

type ResolveConflictRequest struct {
    Resolution    string          `json:"resolution"`            // 'field_wins' | 'source_wins' | 'manual'
    ResolvedAttrs json.RawMessage `json:"resolved_attrs,omitempty"` // required if 'manual'
    Notes         string          `json:"notes,omitempty"`
}

// ── Preview ───────────────────────────────────────────

// POST /api/v1/projects/{projectID}/layers/{layerID}/data-sources/{sourceID}/reconcile/preview
func (h *ReconciliationHandler) Preview(w http.ResponseWriter, r *http.Request) {
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

    var req ReconcileRequest
    // Empty body is fine; defaults apply.
    if r.ContentLength > 0 {
        if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
            RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
            return
        }
    }

    userID := middleware.GetUserID(r.Context())
    result, err := h.svc.Preview(r.Context(), projectID, layerID, sourceID, userID, req.BatchSize, req.FeatureIDs...)
    if err != nil {
        // Membership errors carry the literal "access denied" string by convention
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "PREVIEW_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, result)
}

// ── Apply (async) ─────────────────────────────────────

// POST /api/v1/projects/{projectID}/layers/{layerID}/data-sources/{sourceID}/reconcile/apply
//
// Returns 202 Accepted with the job ID. Client polls GET /reconcile/jobs/{jobID}
// to track progress.
func (h *ReconciliationHandler) Apply(w http.ResponseWriter, r *http.Request) {
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

    var req ReconcileRequest
    if r.ContentLength > 0 {
        if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
            RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
            return
        }
    }

    userID := middleware.GetUserID(r.Context())

    job, err := h.svc.EnqueueApply(r.Context(), projectID, layerID, sourceID, userID, req.BatchSize, req.Acknowledgments, true, req.FeatureIDs...)
    if err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "APPLY_ENQUEUE_FAILED", err.Error())
        return
    }

    // Hand off to the worker pool. Non-blocking.
    h.pool.Submit(job)

    RespondJSON(w, http.StatusAccepted, map[string]any{
        "job_id":     job.ID,
        "status":     job.Status,
        "created_at": job.CreatedAt,
        "message":    "reconciliation job queued — poll GET /reconcile/jobs/" + job.ID.String(),
    })
}

// ── Job polling ───────────────────────────────────────

// GET /api/v1/projects/{projectID}/reconcile/jobs/{jobID}
func (h *ReconciliationHandler) GetJob(w http.ResponseWriter, r *http.Request) {
    jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
        return
    }
    userID := middleware.GetUserID(r.Context())

    job, err := h.svc.GetJob(r.Context(), jobID, userID)
    if err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, job)
}

// ── Cancel ────────────────────────────────────────────

// POST /api/v1/projects/{projectID}/reconcile/jobs/{jobID}/cancel
func (h *ReconciliationHandler) Cancel(w http.ResponseWriter, r *http.Request) {
    jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
        return
    }
    userID := middleware.GetUserID(r.Context())

    if err := h.svc.Cancel(r.Context(), jobID, userID); err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "CANCEL_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "job_id":  jobID,
        "status":  "cancelling",
        "message": "cancel requested — worker will exit between chunks",
    })
}

// ── Conflicts ─────────────────────────────────────────

// GET /api/v1/projects/{projectID}/layers/{layerID}/reconcile/conflicts
//
// Returns all PENDING conflicts for the layer. Resolved conflicts can be
// fetched via a future filter param (?status=...).
func (h *ReconciliationHandler) ListConflicts(w http.ResponseWriter, r *http.Request) {
    layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
        return
    }

    conflicts, err := h.svc.ListPendingConflicts(r.Context(), layerID)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "layer_id":  layerID,
        "count":     len(conflicts),
        "conflicts": conflicts,
    })
}

// POST /api/v1/projects/{projectID}/reconcile/conflicts/{conflictID}/resolve
func (h *ReconciliationHandler) ResolveConflict(w http.ResponseWriter, r *http.Request) {
    conflictID, err := uuid.Parse(chi.URLParam(r, "conflictID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid conflict ID")
        return
    }

    var req ResolveConflictRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", "could not parse request body")
        return
    }

    switch req.Resolution {
    case "field_wins", "source_wins", "manual":
        // ok
    default:
        RespondError(w, http.StatusBadRequest, "INVALID_RESOLUTION",
            "resolution must be one of: field_wins, source_wins, manual")
        return
    }
    if req.Resolution == "manual" && len(req.ResolvedAttrs) == 0 {
        RespondError(w, http.StatusBadRequest, "MISSING_ATTRS",
            "resolved_attrs is required when resolution = 'manual'")
        return
    }

    userID := middleware.GetUserID(r.Context())

    if err := h.svc.ResolveConflict(
        r.Context(),
        conflictID,
        req.Resolution,
        req.ResolvedAttrs,
        userID,
        req.Notes,
    ); err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "RESOLVE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "conflict_id": conflictID,
        "status":      "resolved",
        "resolution":  req.Resolution,
    })
}

// ── Log ───────────────────────────────────────────────

// GET /api/v1/projects/{projectID}/reconcile/jobs/{jobID}/log?limit=100
func (h *ReconciliationHandler) GetJobLog(w http.ResponseWriter, r *http.Request) {
    jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
        return
    }
    limit := 100
    if s := r.URL.Query().Get("limit"); s != "" {
        if n, err := strconv.Atoi(s); err == nil && n > 0 && n <= 1000 {
            limit = n
        }
    }
    userID := middleware.GetUserID(r.Context())

    entries, err := h.svc.ListJobLog(r.Context(), jobID, userID, limit)
    if err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "job_id":  jobID,
        "count":   len(entries),
        "entries": entries,
    })
}

// POST /api/v1/projects/{projectID}/reconcile/jobs/{jobID}/force-finalize
//
// Admin escape hatch: flips the job status to a terminal state regardless
// of the worker. Used when Cancel doesn't take and the job appears stuck.
// Status is computed from current counters.
func (h *ReconciliationHandler) ForceFinalize(w http.ResponseWriter, r *http.Request) {
    jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
        return
    }
    userID := middleware.GetUserID(r.Context())

    job, err := h.svc.ForceFinalize(r.Context(), jobID, userID)
    if err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "FORCE_FINALIZE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "job_id":  jobID,
        "status":  job.Status,
        "message": "job forcibly finalized",
    })
}

// GET /api/v1/projects/{projectID}/layers/{layerID}/reconcile/summary
//
// Returns counts of pending and resolved conflicts for the layer. Used by the
// Data Sources tab to surface "N resolutions ready to apply" badges.
func (h *ReconciliationHandler) Summary(w http.ResponseWriter, r *http.Request) {
    layerID, err := uuid.Parse(chi.URLParam(r, "layerID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid layer ID")
        return
    }

    pending, resolved, err := h.svc.LayerReconcileSummary(r.Context(), layerID)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "SUMMARY_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]any{
        "layer_id":           layerID,
        "pending_conflicts":  pending,
        "resolved_pending_apply": resolved,
    })
}

// POST /api/v1/projects/{projectID}/layers/{layerID}/features/{featureID}/write-back
//
// Synchronously pushes one collected feature (updated/deleted) to the source table.
func (h *ReconciliationHandler) WriteBack(w http.ResponseWriter, r *http.Request) {
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
    featureID, err := uuid.Parse(chi.URLParam(r, "featureID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid feature ID")
        return
    }

    userID := middleware.GetUserID(r.Context())
    result, err := h.svc.WriteBackFeature(r.Context(), projectID, layerID, featureID, userID)
    if err != nil {
        if isAccessDenied(err) {
            RespondError(w, http.StatusForbidden, "ACCESS_DENIED", err.Error())
            return
        }
        RespondError(w, http.StatusBadRequest, "WRITE_BACK_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, result)
}

// ── Helpers ───────────────────────────────────────────

// isAccessDenied detects our service-level membership error. We don't have a
// typed error in the codebase yet; checking the literal substring matches the
// convention used by other handlers (sync, import, etc.).
func isAccessDenied(err error) bool {
    if err == nil {
        return false
    }
    msg := err.Error()
    return contains(msg, "access denied") || contains(msg, "not a member")
}

func contains(s, sub string) bool {
    return len(s) >= len(sub) && indexOf(s, sub) >= 0
}

func indexOf(s, sub string) int {
    if sub == "" {
        return 0
    }
    for i := 0; i+len(sub) <= len(s); i++ {
        if s[i:i+len(sub)] == sub {
            return i
        }
    }
    return -1
}