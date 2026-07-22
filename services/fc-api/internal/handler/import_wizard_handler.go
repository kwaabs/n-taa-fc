package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

type ImportWizardHandler struct {
	discovery      *service.DiscoveryService
	jobRepo        *repository.ImportJobRepo
	connectionRepo *repository.ConnectionRepo
	memberRepo     *repository.MemberRepo
	pool           *service.WorkerPool
	databaseURL    string
}

func NewImportWizardHandler(
	discovery *service.DiscoveryService,
	jobRepo *repository.ImportJobRepo,
	connectionRepo *repository.ConnectionRepo,
	memberRepo *repository.MemberRepo,
	pool *service.WorkerPool,
	databaseURL string,
) *ImportWizardHandler {
	return &ImportWizardHandler{
		discovery: discovery, jobRepo: jobRepo, connectionRepo: connectionRepo,
		memberRepo: memberRepo, pool: pool, databaseURL: databaseURL,
	}
}

// HomeConnection returns this app's own Postgres credentials (from DATABASE_URL)
// so the import wizard can quickly target the shared local/home database.
func (h *ImportWizardHandler) HomeConnection(w http.ResponseWriter, r *http.Request) {
	projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
	if err != nil {
		RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
		return
	}
	userID := middleware.GetUserID(r.Context())
	member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
	if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
		RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
		return
	}

	home, err := config.ParseDatabaseURL(h.databaseURL)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "CONFIG_ERROR", err.Error())
		return
	}
	RespondJSON(w, http.StatusOK, home)
}

// ── Connection profiles ─────────────────────────────

type SaveConnectionRequest struct {
    Name     string `json:"name"`
    Driver   string `json:"driver"`
    Host     string `json:"host"`
    Port     int    `json:"port"`
    Database string `json:"database"`
    Username string `json:"username"`
    Password string `json:"password"`
    SSLMode  string `json:"ssl_mode"`
}

func (h *ImportWizardHandler) ListConnections(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if _, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID); err != nil {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "not a project member")
        return
    }
    list, err := h.connectionRepo.ListByProject(r.Context(), projectID)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, list)
}

func (h *ImportWizardHandler) SaveConnection(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }

    var req SaveConnectionRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }
    c := &model.ProjectConnection{
        ProjectID: projectID,
        Name:      req.Name,
        Driver:    "postgres",
        Host:      req.Host,
        Port:      req.Port,
        Database:  req.Database,
        Username:  req.Username,
        SSLMode:   req.SSLMode,
        CreatedBy: userID,
    }
    if err := h.discovery.SaveConnection(r.Context(), c, req.Password); err != nil {
        RespondError(w, http.StatusBadRequest, "SAVE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusCreated, c)
}

func (h *ImportWizardHandler) DeleteConnection(w http.ResponseWriter, r *http.Request) {
    connID, err := uuid.Parse(chi.URLParam(r, "connectionID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid connection ID")
        return
    }
    c, err := h.connectionRepo.FindByID(r.Context(), connID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", "connection not found")
        return
    }
    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), c.ProjectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }
    if err := h.connectionRepo.Delete(r.Context(), connID); err != nil {
        RespondError(w, http.StatusInternalServerError, "DELETE_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// ── Discovery ───────────────────────────────────────

type ConnectionTestRequest struct {
    ConnectionID *uuid.UUID                       `json:"connection_id,omitempty"`
    Inline       *model.BulkImportInlineConnection `json:"inline,omitempty"`
}

func (h *ImportWizardHandler) TestConnection(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }

    var req ConnectionTestRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }

    conn, err := h.discovery.ResolveConnection(r.Context(), model.BulkImportConnectionRef{
        ConnectionID: req.ConnectionID,
        Inline:       req.Inline,
    })
    if err != nil {
        RespondError(w, http.StatusBadRequest, "RESOLVE_FAILED", err.Error())
        return
    }

    version, err := h.discovery.TestConnection(r.Context(), *conn)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "CONNECTION_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]string{
        "status":  "success",
        "version": version,
    })
}

func (h *ImportWizardHandler) Discover(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }

    var req ConnectionTestRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }

    conn, err := h.discovery.ResolveConnection(r.Context(), model.BulkImportConnectionRef{
        ConnectionID: req.ConnectionID,
        Inline:       req.Inline,
    })
    if err != nil {
        RespondError(w, http.StatusBadRequest, "RESOLVE_FAILED", err.Error())
        return
    }

    tables, err := h.discovery.Discover(r.Context(), *conn)
    if err != nil {
        RespondError(w, http.StatusBadRequest, "DISCOVER_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, map[string]interface{}{
        "tables": tables,
        "count":  len(tables),
    })
}

// ── Jobs ────────────────────────────────────────────

type CreateImportJobRequest struct {
    model.BulkImportConfig
}

func (h *ImportWizardHandler) CreateJob(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }

    var req CreateImportJobRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }
    if len(req.Tables) == 0 {
        RespondError(w, http.StatusBadRequest, "VALIDATION", "no tables specified")
        return
    }

    configJSON, _ := json.Marshal(req.BulkImportConfig)
    job := &model.ImportJob{
        ProjectID:    projectID,
        ConnectionID: req.ConnectionRef.ConnectionID,
        JobType:      "bulk_database_import",
        Status:       "pending",
        Config:       configJSON,
        CreatedBy:    userID,
    }
    if err := h.jobRepo.Create(r.Context(), job); err != nil {
        RespondError(w, http.StatusInternalServerError, "CREATE_FAILED", err.Error())
        return
    }

    // Submit to worker pool
    h.pool.Submit(job)

    RespondJSON(w, http.StatusCreated, job)
}

func (h *ImportWizardHandler) GetJob(w http.ResponseWriter, r *http.Request) {
    jobID, err := uuid.Parse(chi.URLParam(r, "jobID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid job ID")
        return
    }
    job, err := h.jobRepo.FindByID(r.Context(), jobID)
    if err != nil {
        RespondError(w, http.StatusNotFound, "NOT_FOUND", "job not found")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if _, err := h.memberRepo.FindByProjectAndUser(r.Context(), job.ProjectID, userID); err != nil {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "not a project member")
        return
    }
    RespondJSON(w, http.StatusOK, job)
}

func (h *ImportWizardHandler) ListJobs(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }
    userID := middleware.GetUserID(r.Context())
    if _, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID); err != nil {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "not a project member")
        return
    }
    jobs, err := h.jobRepo.ListByProject(r.Context(), projectID, 50)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "LIST_FAILED", err.Error())
        return
    }
    RespondJSON(w, http.StatusOK, jobs)
}