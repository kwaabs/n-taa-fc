package auth

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/uptrace/bun"
)

type SeedConfig struct {
	Email       string
	Password    string // unused under GoTrue — kept for env compat
	DisplayName string
}

// SeedSuperuser promotes an existing app.users row (by email) to active superuser.
// Identity/password seeding is skipped — users authenticate via shared GoTrue.
// First-time superuser is created on GoTrue login when email matches SUPERUSER_EMAIL.
func SeedSuperuser(ctx context.Context, db *bun.DB, logger *slog.Logger, cfg SeedConfig) error {
	if cfg.Email == "" {
		logger.Warn("superuser seed skipped: SUPERUSER_EMAIL not set")
		return nil
	}
	repo := NewRepo(db)

	existing, err := repo.GetUserByEmail(ctx, cfg.Email)
	if err != nil {
		return fmt.Errorf("check superuser: %w", err)
	}
	if existing == nil {
		logger.Info("superuser will be provisioned on first GoTrue login",
			slog.String("email", cfg.Email))
		return nil
	}

	if existing.Role != RoleSuperuser || existing.Status != StatusActive || existing.Pending {
		_, err := db.NewUpdate().Model((*User)(nil)).
			Set("role = ?", RoleSuperuser).
			Set("status = ?", StatusActive).
			Set("pending = ?", false).
			Where("id = ?", existing.ID).
			Exec(ctx)
		if err != nil {
			return fmt.Errorf("promote superuser: %w", err)
		}
		logger.Info("superuser promoted", slog.String("email", cfg.Email))
		return nil
	}

	logger.Info("superuser already present", slog.String("email", cfg.Email))
	return nil
}
