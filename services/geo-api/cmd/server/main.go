package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/auth"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/db"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/features"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/layers"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/media"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/server"
)

func main() {
	if err := run(); err != nil {
		slog.New(slog.NewTextHandler(os.Stderr, nil)).
			Error("fatal", slog.String("err", err.Error()))
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	logger := newLogger(cfg)

	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	database, err := db.Open(ctx, cfg, logger)
	if err != nil {
		return err
	}
	defer func() {
		if err := database.Close(); err != nil {
			logger.Warn("db close", slog.String("err", err.Error()))
		}
	}()

	if err := auth.SeedSuperuser(ctx, database, logger, auth.SeedConfig{
		Email:       cfg.SuperuserEmail,
		Password:    cfg.SuperuserPassword,
		DisplayName: cfg.SuperuserName,
	}); err != nil {
		return err
	}

	authRepo := auth.NewRepo(database)
	// Service kept for user admin APIs (list/update/approve). Token issuer unused for login.
	authSvc := auth.NewService(authRepo, nil, 0, cfg.SuperuserEmail)
	authHandler := auth.NewHandler(authSvc, logger, cfg.CookieDomain, cfg.CookieSecure)
	authMW := auth.NewGoTrueMiddleware(cfg.JWTSecret, authRepo, cfg.SuperuserEmail, logger)

	layersRepo := layers.NewRepo(database)
	layersProbe := db.NewProbe(database)
	layersSvc := layers.NewService(layersRepo, layersProbe)
	layersHandler := layers.NewHandler(layersSvc, logger, cfg.MartinBaseURL)

	featuresRepo := features.NewRepo(database)
	featuresSvc := features.NewService(layersSvc, featuresRepo)

	mediaSvc, err := media.NewService(database, layersSvc, featuresSvc, media.Config{
		Endpoint:       cfg.S3Endpoint,
		PublicEndpoint: cfg.S3PublicEndpoint,
		Bucket:         cfg.S3Bucket,
		AccessKey:      cfg.S3AccessKey,
		SecretKey:      cfg.S3SecretKey,
	})
	if err != nil {
		return err
	}
	mediaHandler := media.NewHandler(mediaSvc, logger)

	featuresHandler := features.NewHandler(featuresSvc, layersSvc, logger)

	srv := server.New(&server.Deps{
		Config:          cfg,
		Logger:          logger,
		DB:              database,
		AuthHandler:     authHandler,
		AuthMW:          authMW,
		LayersHandler:   layersHandler,
		FeaturesHandler: featuresHandler,
		MediaHandler:    mediaHandler,
	})
	return srv.Start(ctx)
}

func newLogger(cfg *config.Config) *slog.Logger {
	opts := &slog.HandlerOptions{Level: cfg.LogLevel}
	var h slog.Handler
	if cfg.IsDev() {
		h = slog.NewTextHandler(os.Stdout, opts)
	} else {
		h = slog.NewJSONHandler(os.Stdout, opts)
	}
	return slog.New(h)
}
