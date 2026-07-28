package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"net/http/httputil"
	"net/url"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/driver/pgdriver"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/cache"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/geostyle"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/handler"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/service"
)

func main() {
	cfg := config.Load()

	cacheClient := cache.New(cfg.ValkeyURL)
	defer cacheClient.Close()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	// ── Database ──────────────────────────────────────
	sqldb := sql.OpenDB(pgdriver.NewConnector(pgdriver.WithDSN(cfg.DatabaseURL)))
	sqldb.SetMaxOpenConns(cfg.DBMaxOpenConns)
	sqldb.SetMaxIdleConns(cfg.DBMaxIdleConns)
	sqldb.SetConnMaxLifetime(cfg.DBConnMaxLifetime)
	db := bun.NewDB(sqldb, pgdialect.New())
	defer db.Close()

	if err := db.PingContext(context.Background()); err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to database",
		"max_open_conns", cfg.DBMaxOpenConns,
		"max_idle_conns", cfg.DBMaxIdleConns,
		"conn_max_lifetime", cfg.DBConnMaxLifetime.String(),
	)

	// ── Repositories ──────────────────────────────────
	userRepo := repository.NewUserRepo(db)
	projectRepo := repository.NewProjectRepo(db)
	memberRepo := repository.NewMemberRepo(db)
	formRepo := repository.NewFormRepo(db)
	layerRepo := repository.NewLayerRepo(db)
	choiceListRepo := repository.NewChoiceListRepo(db)
	featureRepo := repository.NewFeatureRepo(db)
	assignmentRepo := repository.NewAssignmentRepo(db)
	teamRepo := repository.NewTeamRepo(db)
	notificationRepo := repository.NewNotificationRepo(db)
	dataSourceRepo := repository.NewDataSourceRepo(db)
	connectionRepo := repository.NewConnectionRepo(db)
	importJobRepo := repository.NewImportJobRepo(db)
	attachmentRepo := repository.NewAttachmentRepo(db)
	bundleCacheRepo := repository.NewBundleCacheRepo(db)
	syncLogRepo := repository.NewSyncLogRepo(db) // 👈 NEW (use your real pool variable name)
	reconciliationRepo := repository.NewReconciliationRepo(db)

	// Mark any orphaned jobs (in 'running' state from previous boot) as failed
	if n, err := importJobRepo.MarkOrphaned(context.Background()); err == nil && n > 0 {
		slog.Warn("marked orphaned import jobs as failed", "count", n)
	}

	if n, err := reconciliationRepo.MarkOrphaned(context.Background()); err == nil && n > 0 {
		slog.Warn("marked orphaned reconciliation jobs as failed", "count", n)
	}

	// ── Services ──────────────────────────────────────
	validationService := service.NewValidationService(formRepo)
	accessService := service.NewAccessService(db)
	projectService := service.NewProjectService(db, projectRepo, memberRepo, layerRepo, accessService)
	memberService := service.NewMemberService(memberRepo, userRepo, projectRepo)
	formService := service.NewFormService(db, formRepo, memberRepo, validationService, accessService)
	layerService := service.NewLayerService(
		db,
		layerRepo,
		memberRepo,
		featureRepo,
		attachmentRepo,
		formRepo,
		formService,
	)
	choiceListService := service.NewChoiceListService(choiceListRepo, memberRepo)
	featureService := service.NewFeatureService(featureRepo, memberRepo)
	notificationService := service.NewNotificationService(notificationRepo, teamRepo, projectRepo, accessService)
	assignmentService := service.NewAssignmentService(assignmentRepo, memberRepo, accessService, notificationService)
	attachmentService, err := service.NewAttachmentService(cfg, attachmentRepo, featureRepo, accessService)
	if err != nil {
		slog.Error("failed to init attachment service", "error", err)
		os.Exit(1)
	}
	syncService := service.NewSyncService(
		projectRepo,
		formRepo,
		featureRepo,
		assignmentRepo,
		accessService,
		syncLogRepo, // 👈 NEW — inserted between memberRepo and validationService
		validationService,
		attachmentService,
	)
	teamService := service.NewTeamService(teamRepo, userRepo)
	importService := service.NewImportService(
		dataSourceRepo, featureRepo, layerRepo, memberRepo, connectionRepo, projectRepo,
		cfg.JWTSecret, cfg.S3Endpoint, cfg.S3Bucket, cfg.S3AccessKey, cfg.S3SecretKey,
	)
	styleService := service.NewStyleService(db, layerRepo, memberRepo)
	discoveryService := service.NewDiscoveryService(connectionRepo, cfg.JWTSecret)
	importOrchestrator := service.NewImportOrchestrator(
		db, importJobRepo, connectionRepo, layerRepo, formRepo, dataSourceRepo, featureRepo,
		discoveryService, cfg.JWTSecret,
	)
	workerPool := service.NewWorkerPool(importOrchestrator, importJobRepo, 2)
	defer workerPool.Shutdown()

	bundleHashSvc := service.NewBundleHashService(db)

	bundleSvc, err := service.NewBundleService(
		cfg,
		cacheClient,
		bundleCacheRepo,
		importJobRepo,
		layerRepo,
		accessService,
		bundleHashSvc,
	)
	if err != nil {
		slog.Error("init bundle service", "error", err)
		os.Exit(1)
	}

	homeDB, err := config.ParseDatabaseURL(cfg.DatabaseURL)
	if err != nil {
		slog.Warn("could not parse DATABASE_URL for source opener home fallback", "error", err)
	}
	sourceConnOpener := service.NewSourceConnectionOpener(connectionRepo, cfg.JWTSecret, homeDB)
	reconciliationService := service.NewReconciliationService(
		featureRepo, dataSourceRepo, layerRepo, memberRepo, projectRepo,
		reconciliationRepo, sourceConnOpener,
	)
	reconciliationPool := service.NewReconciliationWorkerPool(reconciliationService, reconciliationRepo, 1)
	defer reconciliationPool.Shutdown()
	reconciliationHandler := handler.NewReconciliationHandler(reconciliationService, reconciliationPool)

	// minio client already initialized inside bundleSvc — extract a pointer for the worker
	// We need a shared client. Easiest: re-init for the worker.
	endpoint := strings.TrimPrefix(strings.TrimPrefix(cfg.S3Endpoint, "http://"), "https://")
	useSSL := strings.HasPrefix(cfg.S3Endpoint, "https://")
	s3client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.S3AccessKey, cfg.S3SecretKey, ""),
		Secure: useSSL,
		Region: "us-east-1", // ← ADD THIS
	})

	// Tippecanoe sidecar for vector tile generation.
	// Non-fatal if unreachable — bundle emission will fall back to GeoJSON only.
	tippecanoeURL := os.Getenv("TIPPECANOE_URL")
	if tippecanoeURL == "" {
		tippecanoeURL = "http://localhost:5361"
	}
	tippecanoeClient := service.NewTippecanoeClient(tippecanoeURL)
	if err := tippecanoeClient.Health(); err != nil {
		slog.Warn("tippecanoe sidecar unreachable at startup — .mbtiles generation will be skipped",
			"url", tippecanoeURL, "error", err)
	} else {
		slog.Info("tippecanoe sidecar ready", "url", tippecanoeURL)
	}

	bundlePool := service.NewBundleWorkerPool(
		db, cacheClient, bundleSvc, bundleCacheRepo, importJobRepo,
		projectRepo, formRepo, layerRepo, choiceListRepo, assignmentRepo, dataSourceRepo,
		tippecanoeClient,
		s3client, cfg.S3Bucket, 4,
	)
	defer bundlePool.Shutdown()
	bundleSvc.SetPool(bundlePool)

	// ── Handlers ──────────────────────────────────────
	healthHandler := handler.NewHealthHandler(db)
	projectHandler := handler.NewProjectHandler(projectService)
	memberHandler := handler.NewMemberHandler(memberService)
	formHandler := handler.NewFormHandler(formService)
	layerHandler := handler.NewLayerHandler(layerService)
	choiceListHandler := handler.NewChoiceListHandler(choiceListService)
	featureHandler := handler.NewFeatureHandler(featureService)
	assignmentHandler := handler.NewAssignmentHandler(assignmentService)
	notificationHandler := handler.NewNotificationHandler(notificationService)
	syncHandler := handler.NewSyncHandler(syncService)
	teamHandler := handler.NewTeamHandler(teamService)
	userHandler := handler.NewUserHandler(userRepo)
	meHandler := handler.NewMeHandler(db)
	importHandler := handler.NewImportHandler(importService, dataSourceRepo, layerRepo, memberRepo, featureRepo)
	styleHandler := handler.NewStyleHandler(styleService)
	iconHandler := handler.NewIconHandler(cfg, memberRepo, layerRepo)
	importWizardHandler := handler.NewImportWizardHandler(
		discoveryService, importJobRepo, connectionRepo, memberRepo, workerPool, cfg.DatabaseURL,
	)
	attachmentHandler := handler.NewAttachmentHandler(attachmentService)
	bundleHandler := handler.NewBundleHandler(bundleSvc)
	appReleaseHandler, err := handler.NewAppReleaseHandler(cfg)
	if err != nil {
		slog.Error("failed to init app release handler", "error", err)
		os.Exit(1)
	}

	// ── Router ────────────────────────────────────────
	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(middleware.NewLoggerMiddleware())
	r.Use(chimw.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   strings.Split(cfg.CORSOrigins, ","),
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	r.Get("/health", healthHandler.Check)
	r.Get("/api/v1/app/android/latest", appReleaseHandler.LatestAndroid)
	r.Get("/api/v1/app/symbols", func(w http.ResponseWriter, r *http.Request) {
		names := geostyle.SymbolNames()
		type item struct {
			Name string `json:"name"`
			Ref  string `json:"ref"`
			SVG  string `json:"svg"`
		}
		out := make([]item, 0, len(names))
		for _, n := range names {
			svg, _ := geostyle.SymbolSVG(n)
			out = append(out, item{Name: n, Ref: "geo:" + n, SVG: svg})
		}
		handler.RespondJSON(w, http.StatusOK, out)
	})

	// Proxy /gotrue/* to GoTrue, stripping its CORS headers so our middleware controls them
	gotrueURL, err := url.Parse(cfg.GoTrueURL)
	if err != nil {
		slog.Error("invalid GOTRUE_URL", "url", cfg.GoTrueURL, "error", err)
		os.Exit(1)
	}

	gotrueProxy := httputil.NewSingleHostReverseProxy(gotrueURL)
	gotrueProxy.ModifyResponse = func(resp *http.Response) error {
		resp.Header.Del("Access-Control-Allow-Origin")
		resp.Header.Del("Access-Control-Allow-Methods")
		resp.Header.Del("Access-Control-Allow-Headers")
		resp.Header.Del("Access-Control-Allow-Credentials")
		resp.Header.Del("Access-Control-Expose-Headers")
		resp.Header.Del("Access-Control-Max-Age")
		return nil
	}

	r.Mount("/gotrue", http.StripPrefix("/gotrue", gotrueProxy))

	// ── Authenticated routes ───────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(middleware.NewAuthMiddleware(cfg.JWTSecret, userRepo, cacheClient, cfg.AuthProfileUpsertTTL))

		// Current user
		r.Get("/api/v1/me", meHandler.Get)

		// Reusable form templates (cross-project picker)
		r.Get("/api/v1/form-templates", formHandler.ListTemplates)

		// In-app notifications (assignment fan-out, etc.)
		r.Route("/api/v1/notifications", func(r chi.Router) {
			r.Get("/", notificationHandler.List)
			r.Get("/unread-count", notificationHandler.UnreadCount)
			r.Post("/read-all", notificationHandler.MarkAllRead)
			r.Patch("/{notificationID}/read", notificationHandler.MarkRead)
		})

		// Users management — system admin only
		r.Route("/api/v1/users", func(r chi.Router) {
			// List + detail: admins (needed for user pickers in team/member UI)
			r.With(middleware.RequireRole(accessService, "admin")).
				Get("/", userHandler.List)
			r.With(middleware.RequireRole(accessService, "admin")).
				Get("/{userID}", userHandler.GetDetail)
			// Role changes: system admin only
			r.With(middleware.RequireSystemAdmin(accessService)).
				Patch("/{userID}/role", userHandler.UpdateRole)
		})

		// Teams (organisation-level)
		r.Route("/api/v1/teams", func(r chi.Router) {
			r.Post("/", teamHandler.Create)
			r.Get("/", teamHandler.List)

			r.Route("/{teamID}", func(r chi.Router) {
				r.Get("/", teamHandler.Get)
				r.Put("/", teamHandler.Update)
				r.Delete("/", teamHandler.Delete)

				r.Route("/members", func(r chi.Router) {
					r.Get("/", teamHandler.ListMembers)
					r.Post("/", teamHandler.AddMember)
					r.Put("/{userID}", teamHandler.UpdateMemberRole)
					r.Delete("/{userID}", teamHandler.RemoveMember)
				})
			})
		})

		// Attachments
		r.Route("/api/v1/attachments", func(r chi.Router) {
			r.Route("/{attachmentID}", func(r chi.Router) {
				r.Get("/", attachmentHandler.Get)
				r.Post("/confirm", attachmentHandler.Confirm)
				r.Delete("/", attachmentHandler.Delete)
			})
		})

		// Projects
		r.Route("/api/v1/projects", func(r chi.Router) {
			r.Post("/", projectHandler.Create)
			r.Get("/", projectHandler.List)

			r.Route("/{projectID}", func(r chi.Router) {
				r.Get("/", projectHandler.Get)
				r.With(middleware.RequireRole(accessService, "admin")).
					Put("/", projectHandler.Update)
				r.With(middleware.RequireRole(accessService, "admin")).
					Patch("/archive", projectHandler.Archive)
				r.Post("/icons", iconHandler.UploadIcon)
				r.With(middleware.RequireRole(accessService, "admin")).
					Post("/dispatch", projectHandler.Dispatch)
				r.With(middleware.RequireRole(accessService, "admin")).
					Post("/aoi/from-layer", projectHandler.BuildAOIFromLayer)

				// Bundle (full pack) + efficient-sync slim core pack
				r.Route("/bundle", func(r chi.Router) {
					r.Get("/", bundleHandler.Request)
					r.Get("/jobs/{jobID}", bundleHandler.GetJob)
				})
				r.Route("/core-pack", func(r chi.Router) {
					r.Get("/", bundleHandler.RequestCore)
					r.Get("/jobs/{jobID}", bundleHandler.GetJob)
				})
				r.With(middleware.RequireRole(accessService, "admin")).
					Post("/packs/warm", bundleHandler.WarmPacks)
				r.Get("/packs/manifest", bundleHandler.GetPacksManifest)

				// Reconciliation
				// Reconciliation — supervisor+ only (writes to source DB)
				r.Route("/reconcile", func(r chi.Router) {
					r.Use(middleware.RequireRole(accessService, "supervisor"))
					r.Get("/jobs/{jobID}", reconciliationHandler.GetJob)
					r.Get("/jobs/{jobID}/log", reconciliationHandler.GetJobLog)
					r.Post("/jobs/{jobID}/cancel", reconciliationHandler.Cancel)
					r.Post("/jobs/{jobID}/force-finalize", reconciliationHandler.ForceFinalize)
					r.Post("/conflicts/{conflictID}/resolve", reconciliationHandler.ResolveConflict)
				})

				// Project attachments
				r.Post("/attachments", attachmentHandler.Create)

				r.Route("/features/{featureID}/attachments", func(r chi.Router) {
					r.Get("/", attachmentHandler.ListByFeature)
				})

				// Members
				// Members — list open to any member; mutations admin-only
				r.Route("/members", func(r chi.Router) {
					r.Get("/", memberHandler.List)
					r.With(middleware.RequireRole(accessService, "admin")).
						Post("/", memberHandler.Add)
					r.With(middleware.RequireRole(accessService, "admin")).
						Put("/{userID}", memberHandler.UpdateRole)
					r.With(middleware.RequireRole(accessService, "admin")).
						Delete("/{userID}", memberHandler.Remove)
				})

				// Teams assigned to project
				// Teams assigned to project — list open; assign/remove admin-only
				r.Route("/teams", func(r chi.Router) {
					r.Get("/", teamHandler.ListProjectTeams)
					r.With(middleware.RequireRole(accessService, "admin")).
						Post("/", teamHandler.AssignToProject)
					r.With(middleware.RequireRole(accessService, "admin")).
						Delete("/{teamID}", teamHandler.RemoveFromProject)
				})

				// Forms — GETs open; create/update/publish supervisor+
				r.Route("/forms", func(r chi.Router) {
					r.With(middleware.RequireRole(accessService, "supervisor")).
						Post("/", formHandler.Create)
					r.With(middleware.RequireRole(accessService, "supervisor")).
						Post("/clone", formHandler.Clone)
					r.Get("/", formHandler.List)

					r.Route("/{formID}", func(r chi.Router) {
						r.Get("/", formHandler.Get)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Put("/", formHandler.Update)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/publish", formHandler.Publish)
						r.Get("/versions", formHandler.GetVersions)
					})
				})

				// Layers — GETs open; mutations supervisor+ (field ops config)
				r.Route("/layers", func(r chi.Router) {
					r.With(middleware.RequireRole(accessService, "supervisor")).
						Post("/", layerHandler.Create)
					r.Get("/", layerHandler.List)

					r.Route("/{layerID}", func(r chi.Router) {
						r.Get("/", layerHandler.Get)
						r.Get("/rows", layerHandler.ListRows)
						r.Get("/reference-pack", bundleHandler.RequestLayerReferencePack)
						r.Get("/reference-pack/jobs/{jobID}", bundleHandler.GetJob)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Put("/", layerHandler.Update)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Delete("/", layerHandler.Delete)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/publish", layerHandler.Publish)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/unpublish", layerHandler.Unpublish)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/ensure-form", layerHandler.EnsureForm)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/apply-form-template", layerHandler.ApplyFormTemplate)

						// Per-feature write-back to source (update/delete)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Post("/features/{featureID}/write-back", reconciliationHandler.WriteBack)

						// Style — view open, edit supervisor+
						r.Get("/style", styleHandler.GetStyle)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Put("/style", styleHandler.UpdateStyle)

						// Import summary (view)
						r.Get("/summary", importHandler.GetLayerChangeSummary)

						// Reconciliation views — supervisor+
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Get("/reconcile/conflicts", reconciliationHandler.ListConflicts)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Get("/reconcile/summary", reconciliationHandler.Summary)

						// Data sources — supervisor+ (reference data management)
						r.Route("/data-sources", func(r chi.Router) {
							r.Use(middleware.RequireRole(accessService, "supervisor"))
							r.Get("/", importHandler.ListDataSources)
							r.Post("/", importHandler.CreateDataSource)
							r.Post("/upload", importHandler.UploadFile)

							r.Route("/{sourceID}", func(r chi.Router) {
								r.Delete("/", importHandler.DeleteDataSource)
								r.Post("/sync", importHandler.RunSync)
								r.Patch("/connection", importHandler.LinkConnection)

								// Reconcile preview/apply — supervisor+ (source DB writes)
								r.Route("/reconcile", func(r chi.Router) {
									r.Post("/preview", reconciliationHandler.Preview)
									r.Post("/apply", reconciliationHandler.Apply)
								})
							})
						})
					})
				})

				// Choice lists — GETs open; mutations supervisor+
				r.Route("/choice-lists", func(r chi.Router) {
					r.With(middleware.RequireRole(accessService, "supervisor")).
						Post("/", choiceListHandler.Create)
					r.Get("/", choiceListHandler.List)

					r.Route("/{choiceListID}", func(r chi.Router) {
						r.Get("/", choiceListHandler.Get)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Put("/", choiceListHandler.Update)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Delete("/", choiceListHandler.Delete)
					})
				})

				// Features
				// Features — view open; status change (review/approve) supervisor+
				r.Route("/features", func(r chi.Router) {
					r.Get("/", featureHandler.List)

					r.Route("/{featureID}", func(r chi.Router) {
						r.Get("/", featureHandler.Get)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Patch("/status", featureHandler.UpdateStatus)
					})
				})

				// Assignments — supervisors manage; field workers update own status
				r.Route("/assignments", func(r chi.Router) {
					r.With(middleware.RequireRole(accessService, "supervisor")).
						Post("/", assignmentHandler.Create)
					r.Get("/", assignmentHandler.List)

					r.Route("/{assignmentID}", func(r chi.Router) {
						r.Get("/", assignmentHandler.Get)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Patch("/", assignmentHandler.Update)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Delete("/", assignmentHandler.Delete)
						// Status update stays open — field workers mark their own progress
						r.Patch("/status", assignmentHandler.UpdateStatus)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Patch("/due-date", assignmentHandler.ExtendDueDate)
						r.With(middleware.RequireRole(accessService, "supervisor")).
							Patch("/reassign", assignmentHandler.Reassign)
						r.Get("/progress", assignmentHandler.GetProgress)
					})
				})

				// One-way supervisor messages → team or individual (in-app notifications)
				r.With(middleware.RequireRole(accessService, "supervisor")).
					Post("/messages", notificationHandler.SendMessage)

				// Mobile sync
				r.Route("/sync", func(r chi.Router) {
					r.Get("/manifest", syncHandler.GetManifest)
					r.Get("/pull/config", syncHandler.PullConfig)
					r.Get("/pull/features", syncHandler.PullFeatures)
					r.Post("/push", syncHandler.Push)
					r.Post("/verify", syncHandler.Verify)
				})

				// Connection profiles — admin only (external DB credentials)
				r.Route("/connections", func(r chi.Router) {
					r.Use(middleware.RequireRole(accessService, "admin"))
					r.Get("/", importWizardHandler.ListConnections)
					r.Post("/", importWizardHandler.SaveConnection)
					r.Delete("/{connectionID}", importWizardHandler.DeleteConnection)
				})

				// Import wizard — admin only
				r.Route("/import", func(r chi.Router) {
					r.Use(middleware.RequireRole(accessService, "admin"))
					r.Get("/home-connection", importWizardHandler.HomeConnection)
					r.Post("/test-connection", importWizardHandler.TestConnection)
					r.Post("/discover", importWizardHandler.Discover)
					r.Post("/jobs", importWizardHandler.CreateJob)
					r.Get("/jobs", importWizardHandler.ListJobs)
					r.Get("/jobs/{jobID}", importWizardHandler.GetJob)
				})
			})
		})
	})

	// ── Server ────────────────────────────────────────
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				cutoffCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
				deleted, _ := bundleSvc.CleanupStale(cutoffCtx, 7*24*time.Hour)
				if deleted > 0 {
					slog.Info("bundle cache cleanup", "deleted", deleted)
				}
				cancel()
			}
		}
	}()

	go func() {
		slog.Info("server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server forced to shutdown", "error", err)
	}

	slog.Info("server stopped")
}
