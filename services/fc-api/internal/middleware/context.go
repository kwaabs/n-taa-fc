package middleware

import (
	"context"

	"github.com/google/uuid"
)

type contextKey string

const (
	UserIDKey    contextKey = "user_id"
	UserEmailKey contextKey = "user_email"
	UserNameKey  contextKey = "user_name"
)

// GetUserID extracts the authenticated user's UUID from context.
func GetUserID(ctx context.Context) uuid.UUID {
	if v, ok := ctx.Value(UserIDKey).(uuid.UUID); ok {
		return v
	}
	return uuid.Nil
}

// GetUserEmail extracts the authenticated user's email from context.
func GetUserEmail(ctx context.Context) string {
	if v, ok := ctx.Value(UserEmailKey).(string); ok {
		return v
	}
	return ""
}
