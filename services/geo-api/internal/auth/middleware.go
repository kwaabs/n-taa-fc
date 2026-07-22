package auth

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/httpx"
)

type ctxKey int

const userCtxKey ctxKey = 1

func WithUser(ctx context.Context, u *User) context.Context {
	return context.WithValue(ctx, userCtxKey, u)
}

func UserFromContext(ctx context.Context) (*User, bool) {
	u, ok := ctx.Value(userCtxKey).(*User)
	return u, ok
}

func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	u, ok := UserFromContext(ctx)
	if !ok || u == nil {
		return uuid.UUID{}, false
	}
	return u.ID, true
}

func RoleFromContext(ctx context.Context) (Role, bool) {
	u, ok := UserFromContext(ctx)
	if !ok || u == nil {
		return "", false
	}
	return u.Role, true
}

// Middleware validates shared GoTrue JWTs and loads geo RBAC from app.users.
type Middleware struct {
	jwtSecret      []byte
	repo           *Repo
	superuserEmail string
	logger         *slog.Logger
}

func NewGoTrueMiddleware(jwtSecret string, repo *Repo, superuserEmail string, logger *slog.Logger) *Middleware {
	return &Middleware{
		jwtSecret:      []byte(jwtSecret),
		repo:           repo,
		superuserEmail: superuserEmail,
		logger:         logger,
	}
}

func (m *Middleware) RequireUser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := extractBearer(r)
		if raw == "" {
			httpx.Unauthorized(w, "missing bearer token")
			return
		}

		token, err := jwt.Parse(raw, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return m.jwtSecret, nil
		})
		if err != nil || !token.Valid {
			httpx.Unauthorized(w, "invalid or expired token")
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			httpx.Unauthorized(w, "invalid token claims")
			return
		}

		sub, _ := claims.GetSubject()
		userID, err := uuid.Parse(sub)
		if err != nil {
			httpx.Unauthorized(w, "invalid user id in token")
			return
		}

		email, _ := claims["email"].(string)
		displayName := displayNameFromClaims(claims)
		authSource := authSourceFromClaims(claims)

		u, err := m.repo.UpsertFromGoTrue(r.Context(), userID, email, displayName, authSource, m.superuserEmail)
		if err != nil {
			if m.logger != nil {
				m.logger.Error("upsert app.users from GoTrue", slog.String("err", err.Error()))
			}
			httpx.Unauthorized(w, "user provisioning failed")
			return
		}
		if u == nil {
			httpx.Unauthorized(w, "user not found")
			return
		}
		if u.Status != StatusActive {
			httpx.Forbidden(w, "user is disabled")
			return
		}
		if u.Pending {
			httpx.Forbidden(w, "account pending approval")
			return
		}

		next.ServeHTTP(w, r.WithContext(WithUser(r.Context(), u)))
	})
}

func (m *Middleware) RequireRole(roles ...Role) func(http.Handler) http.Handler {
	allowed := map[Role]struct{}{}
	for _, r := range roles {
		allowed[r] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			u, ok := UserFromContext(r.Context())
			if !ok {
				httpx.Unauthorized(w, "not authenticated")
				return
			}
			if _, ok := allowed[u.Role]; !ok {
				httpx.Forbidden(w, "insufficient role")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func extractBearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if !strings.HasPrefix(h, "Bearer ") {
		return ""
	}
	return strings.TrimPrefix(h, "Bearer ")
}

func displayNameFromClaims(claims jwt.MapClaims) string {
	if meta, ok := claims["user_metadata"].(map[string]interface{}); ok {
		for _, key := range []string{"full_name", "name", "display_name"} {
			if v, ok := meta[key].(string); ok && v != "" {
				return v
			}
		}
	}
	if v, ok := claims["name"].(string); ok && v != "" {
		return v
	}
	email, _ := claims["email"].(string)
	return email
}

func authSourceFromClaims(claims jwt.MapClaims) string {
	if amr, ok := claims["amr"].([]interface{}); ok {
		for _, a := range amr {
			if s, ok := a.(string); ok && strings.Contains(strings.ToLower(s), "oauth") {
				return "azure"
			}
		}
	}
	if appMeta, ok := claims["app_metadata"].(map[string]interface{}); ok {
		if provider, ok := appMeta["provider"].(string); ok {
			switch strings.ToLower(provider) {
			case "azure", "azure_ad":
				return "azure"
			case "google":
				return "google"
			}
		}
		if providers, ok := appMeta["providers"].([]interface{}); ok {
			for _, p := range providers {
				if s, ok := p.(string); ok {
					switch strings.ToLower(s) {
					case "azure", "azure_ad":
						return "azure"
					case "google":
						return "google"
					}
				}
			}
		}
	}
	return "local"
}
