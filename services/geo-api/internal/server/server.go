package server

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/auth"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/features"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/httpx"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/layers"
	"github.com/kwaabs/n-taa-fc/services/geo-api/internal/media"
)

type Deps struct {
	Config          *config.Config
	Logger          *slog.Logger
	DB              *bun.DB
	AuthHandler     *auth.Handler
	AuthMW          *auth.Middleware
	LayersHandler   *layers.Handler
	FeaturesHandler *features.Handler
	MediaHandler    *media.Handler
}

type Server struct {
	deps   *Deps
	router *chi.Mux
	http   *http.Server
}

func New(deps *Deps) *Server {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(httpx.RequestLogger(deps.Logger))
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   deps.Config.CORSAllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	s := &Server{deps: deps, router: r}
	s.mountRoutes()

	s.http = &http.Server{
		Addr:              deps.Config.Addr(),
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	return s
}

func (s *Server) Router() chi.Router { return s.router }

func (s *Server) Start(ctx context.Context) error {
	s.deps.Logger.Info("api listening",
		slog.String("addr", s.deps.Config.Addr()),
		slog.String("env", string(s.deps.Config.Env)),
	)

	errCh := make(chan error, 1)
	go func() {
		if err := s.http.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case <-ctx.Done():
		return s.shutdown()
	case err := <-errCh:
		return err
	}
}

func (s *Server) shutdown() error {
	s.deps.Logger.Info("api shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := s.http.Shutdown(shutdownCtx); err != nil {
		return err
	}
	s.deps.Logger.Info("api stopped")
	return nil
}
