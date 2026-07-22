package middleware

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

// RequireRole gates a route by minimum role, scoped to the {projectID} URL
// param when present (checks project access + role), otherwise global role.
//
// minRole: "field_worker" | "supervisor" | "admin"
func RequireRole(access *service.AccessService, minRole string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := GetUserID(r.Context())
			if userID == uuid.Nil {
				respondRBAC(w, http.StatusUnauthorized, "authentication required")
				return
			}

			projectIDStr := chi.URLParam(r, "projectID")
			if projectIDStr != "" {
				projectID, err := uuid.Parse(projectIDStr)
				if err != nil {
					respondRBAC(w, http.StatusBadRequest, "invalid project ID")
					return
				}
				ok, err := access.CanAccessWithRole(r.Context(), userID, projectID, minRole)
				if err != nil {
					respondRBAC(w, http.StatusInternalServerError, "authz check failed")
					return
				}
				if !ok {
					respondRBAC(w, http.StatusForbidden, "requires "+minRole+" role on this project")
					return
				}
			} else {
				ok, err := access.HasMinRole(r.Context(), userID, minRole)
				if err != nil {
					respondRBAC(w, http.StatusInternalServerError, "authz check failed")
					return
				}
				if !ok {
					respondRBAC(w, http.StatusForbidden, "requires "+minRole+" role")
					return
				}
			}

			next.ServeHTTP(w, r)
		})
	}
}

func respondRBAC(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(`{"error":{"code":"FORBIDDEN","message":"` + msg + `"}}`))
}

// RequireSystemAdmin gates to platform super-admins only.
func RequireSystemAdmin(access *service.AccessService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := GetUserID(r.Context())
			if userID == uuid.Nil {
				respondRBAC(w, http.StatusUnauthorized, "authentication required")
				return
			}
			ok, err := access.IsSystemAdmin(r.Context(), userID)
			if err != nil || !ok {
				respondRBAC(w, http.StatusForbidden, "requires system administrator")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
