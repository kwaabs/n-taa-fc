package middleware

import (
    "context"
    "log/slog"
    "net/http"
    "strings"

    "github.com/golang-jwt/jwt/v5"
    "github.com/google/uuid"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

// NewAuthMiddleware returns a middleware that validates GoTrue JWTs
// and upserts the user profile on each authenticated request.
func NewAuthMiddleware(jwtSecret string, userRepo *repository.UserRepo) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            authHeader := r.Header.Get("Authorization")
            if authHeader == "" {
                http.Error(w, `{"error":"missing authorization header"}`, http.StatusUnauthorized)
                return
            }

            parts := strings.SplitN(authHeader, " ", 2)
            if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
                http.Error(w, `{"error":"invalid authorization format"}`, http.StatusUnauthorized)
                return
            }
            tokenStr := parts[1]

            token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
                if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
                    return nil, jwt.ErrSignatureInvalid
                }
                return []byte(jwtSecret), nil
            })
            if err != nil || !token.Valid {
                http.Error(w, `{"error":"invalid or expired token"}`, http.StatusUnauthorized)
                return
            }

            claims, ok := token.Claims.(jwt.MapClaims)
            if !ok {
                http.Error(w, `{"error":"invalid token claims"}`, http.StatusUnauthorized)
                return
            }

            sub, _ := claims.GetSubject()
            userID, err := uuid.Parse(sub)
            if err != nil {
                http.Error(w, `{"error":"invalid user id in token"}`, http.StatusUnauthorized)
                return
            }

            email, _ := claims["email"].(string)

            fullName := ""
            if meta, ok := claims["user_metadata"].(map[string]interface{}); ok {
                if name, ok := meta["full_name"].(string); ok {
                    fullName = name
                }
            }

            // Upsert user profile (must complete before request proceeds)
            user := &model.UserProfile{
                ID:       userID,
                Email:    email,
                FullName: fullName,
            }
            if err := userRepo.Upsert(r.Context(), user); err != nil {
                slog.Error("failed to upsert user profile", "error", err, "user_id", userID)
                http.Error(w, `{"error":"failed to provision user profile"}`, http.StatusInternalServerError)
                return
            }

            ctx := r.Context()
            ctx = context.WithValue(ctx, UserIDKey, userID)
            ctx = context.WithValue(ctx, UserEmailKey, email)
            ctx = context.WithValue(ctx, UserNameKey, fullName)

            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}