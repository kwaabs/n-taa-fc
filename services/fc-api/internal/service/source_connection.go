package service

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"net/url"
	"strings"
	"time"

	_ "github.com/lib/pq"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/crypto"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

// SourceConnectionOpener opens *sql.DB connections to the source databases
// backing layer data sources. Centralised so reconciliation, import, and
// discovery all use one definition.
type SourceConnectionOpener struct {
	connectionRepo *repository.ConnectionRepo
	encryptionKey  string
	home           *config.HomeDBConnection // optional: same Postgres as FC (linked dbo)
}

func NewSourceConnectionOpener(
	connectionRepo *repository.ConnectionRepo,
	encryptionKey string,
	home *config.HomeDBConnection,
) *SourceConnectionOpener {
	return &SourceConnectionOpener{
		connectionRepo: connectionRepo,
		encryptionKey:  encryptionKey,
		home:           home,
	}
}

// OpenForDataSource returns a connected *sql.DB to the source DB for a data
// source. Resolves credentials in this order:
//
//  1. If config.ConnectionID is set → load project_connection, decrypt password.
//  2. Else if home DATABASE_URL is configured and the data source has
//     schema/table (typical linked_table on the shared ntaafc DB) → use home.
//  3. Otherwise fail — admin must link a project_connection.
//
// Caller MUST close the returned DB.
func (o *SourceConnectionOpener) OpenForDataSource(ctx context.Context, ds *model.LayerDataSource) (*sql.DB, error) {
	cfg := ds.DatabaseConfigParsed()
	if cfg == nil {
		return nil, fmt.Errorf("data source %s is not a database type", ds.ID)
	}

	if cfg.ConnectionID == nil {
		if o.home != nil && ds.SchemaName() != "" && ds.TableName() != "" {
			slog.Info("opening source via home DATABASE_URL (no connection_id)",
				"data_source_id", ds.ID,
				"schema", ds.SchemaName(),
				"table", ds.TableName(),
			)
			return OpenInlineSourceConnection(model.BulkImportInlineConnection{
				Host:     o.home.Host,
				Port:     o.home.Port,
				Database: o.home.Database,
				Username: o.home.Username,
				Password: o.home.Password,
				SSLMode:  o.home.SSLMode,
			})
		}
		return nil, fmt.Errorf(
			"data source %q (%s) was imported inline and has no linked connection profile; "+
				"link it to a project_connection before reconciling",
			ds.Name, ds.ID,
		)
	}

	conn, err := o.connectionRepo.FindByID(ctx, *cfg.ConnectionID)
	if err != nil {
		return nil, fmt.Errorf("load connection %s: %w", *cfg.ConnectionID, err)
	}

	password, err := crypto.Decrypt(conn.EncryptedPassword, o.encryptionKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt connection password: %w", err)
	}

	inline := model.BulkImportInlineConnection{
		Host:     conn.Host,
		Port:     conn.Port,
		Database: conn.Database,
		Username: conn.Username,
		Password: password,
		SSLMode:  conn.SSLMode,
	}
	return OpenInlineSourceConnection(inline)
}

// OpenInlineSourceConnection is the shared DSN-building + sql.Open pattern.
// Extracted from discovery_service so reconciliation, import, and discovery
// all use one definition (DRY).
func OpenInlineSourceConnection(conn model.BulkImportInlineConnection) (*sql.DB, error) {
    port := conn.Port
    if port == 0 {
        port = 5432
    }
    ssl := normalizeSSLModeShared(conn.SSLMode)

    u := &url.URL{
        Scheme:   "postgres",
        User:     url.UserPassword(conn.Username, conn.Password),
        Host:     fmt.Sprintf("%s:%d", conn.Host, port),
        Path:     "/" + conn.Database,
        RawQuery: fmt.Sprintf("sslmode=%s&connect_timeout=10", ssl),
    }

    slog.Info("opening source database connection",
        "host", conn.Host,
        "port", port,
        "database", conn.Database,
        "username", conn.Username,
        "ssl_mode_resolved", ssl,
    )

    db, err := sql.Open("postgres", u.String())
    if err != nil {
        return nil, err
    }
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetMaxOpenConns(5)

    if err := db.Ping(); err != nil {
        db.Close()
        return nil, fmt.Errorf("connection failed: %w", err)
    }
    return db, nil
}

func normalizeSSLModeShared(mode string) string {
    switch strings.ToLower(strings.TrimSpace(mode)) {
    case "", "disable":
        return "disable"
    case "require":
        return "require"
    case "verify-ca":
        return "verify-ca"
    case "verify-full":
        return "verify-full"
    case "prefer":
        return "prefer"
    case "allow":
        return "allow"
    default:
        return "disable"
    }
}