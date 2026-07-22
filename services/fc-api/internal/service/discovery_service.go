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

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/crypto"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type DiscoveryService struct {
	connectionRepo *repository.ConnectionRepo
	encryptionKey  string
}

func NewDiscoveryService(connectionRepo *repository.ConnectionRepo, encryptionKey string) *DiscoveryService {
	return &DiscoveryService{
		connectionRepo: connectionRepo,
		encryptionKey:  encryptionKey,
	}
}

// TestConnection just opens a connection and runs SELECT version().
func (s *DiscoveryService) TestConnection(ctx context.Context, conn model.BulkImportInlineConnection) (string, error) {
	db, err := s.openConn(conn)
	if err != nil {
		return "", err
	}
	defer db.Close()

	var version string
	if err := db.QueryRowContext(ctx, "SELECT version()").Scan(&version); err != nil {
		return "", fmt.Errorf("failed to query version: %w", err)
	}
	return version, nil
}

// Discover lists all spatial and non-spatial tables, with column info and ENUM values.
func (s *DiscoveryService) Discover(ctx context.Context, conn model.BulkImportInlineConnection) ([]model.DiscoveredTable, error) {
	db, err := s.openConn(conn)
	if err != nil {
		return nil, err
	}
	defer db.Close()

	// 1. Find spatial tables via geometry_columns view
	spatial, err := s.discoverSpatialTables(ctx, db)
	if err != nil {
		return nil, fmt.Errorf("spatial discovery failed: %w", err)
	}

	// 2. Find plain tables (with at least 2 numeric columns — potential lat/lng)
	plain, err := s.discoverPlainTables(ctx, db, spatial)
	if err != nil {
		// Non-fatal — just log
		plain = nil
	}

	all := append(spatial, plain...)

	// 3. Enrich each with columns + ENUM values + row count
	for i := range all {
		cols, err := s.discoverColumns(ctx, db, all[i].Schema, all[i].Name, all[i].GeometryColumn)
		if err != nil {
			continue
		}
		all[i].Columns = cols

		count, _ := s.tableRowCount(ctx, db, all[i].Schema, all[i].Name)
		all[i].RowCount = count
	}

	return all, nil
}

// ResolveConnection takes a request that has either a connection_id or inline credentials
// and returns the inline form (decrypting the saved password if applicable).
func (s *DiscoveryService) ResolveConnection(ctx context.Context, ref model.BulkImportConnectionRef) (*model.BulkImportInlineConnection, error) {
	if ref.Inline != nil {
		return ref.Inline, nil
	}
	if ref.ConnectionID == nil {
		return nil, fmt.Errorf("no connection_id or inline credentials provided")
	}
	saved, err := s.connectionRepo.FindByID(ctx, *ref.ConnectionID)
	if err != nil {
		return nil, fmt.Errorf("saved connection not found")
	}
	password, err := crypto.Decrypt(saved.EncryptedPassword, s.encryptionKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt saved password: %w", err)
	}
	return &model.BulkImportInlineConnection{
		Host:     saved.Host,
		Port:     saved.Port,
		Database: saved.Database,
		Username: saved.Username,
		Password: password,
		SSLMode:  saved.SSLMode,
	}, nil
}

// SaveConnection creates a project-level reusable connection profile.
func (s *DiscoveryService) SaveConnection(ctx context.Context, c *model.ProjectConnection, plainPassword string) error {
	if plainPassword != "" {
		enc, err := crypto.Encrypt(plainPassword, s.encryptionKey)
		if err != nil {
			return fmt.Errorf("encryption failed: %w", err)
		}
		c.EncryptedPassword = enc
	}
	return s.connectionRepo.Create(ctx, c)
}

// ── internals ──────────────────────────────────────────

func (s *DiscoveryService) openConn(conn model.BulkImportInlineConnection) (*sql.DB, error) {
	port := conn.Port
	if port == 0 {
		port = 5432
	}
	ssl := normalizeSSLMode(conn.SSLMode)

	// Build URL-form DSN — handles special characters in password/db name properly
	u := &url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(conn.Username, conn.Password),
		Host:     fmt.Sprintf("%s:%d", conn.Host, port),
		Path:     "/" + conn.Database,
		RawQuery: fmt.Sprintf("sslmode=%s&connect_timeout=10", ssl),
	}

	slog.Info("opening database connection",
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

func (s *DiscoveryService) discoverSpatialTables(ctx context.Context, db *sql.DB) ([]model.DiscoveredTable, error) {
	// First check if PostGIS is installed
	var hasPostGIS bool
	_ = db.QueryRowContext(ctx,
		"SELECT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'geometry_columns')").Scan(&hasPostGIS)
	if !hasPostGIS {
		return nil, nil
	}

	rows, err := db.QueryContext(ctx, `
        SELECT
            f_table_schema, f_table_name, f_geometry_column, srid, type
        FROM geometry_columns
        WHERE f_table_schema NOT IN ('information_schema', 'pg_catalog', 'tiger', 'topology')
        ORDER BY f_table_schema, f_table_name
    `)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tables []model.DiscoveredTable
	for rows.Next() {
		var t model.DiscoveredTable
		if err := rows.Scan(&t.Schema, &t.Name, &t.GeometryColumn, &t.SRID, &t.GeometryType); err != nil {
			continue
		}
		t.IsSpatial = true
		t.QualifiedName = t.Schema + "." + t.Name
		tables = append(tables, t)
	}
	return tables, nil
}

func (s *DiscoveryService) discoverPlainTables(ctx context.Context, db *sql.DB, exclude []model.DiscoveredTable) ([]model.DiscoveredTable, error) {
	// Build a set of already-discovered spatial tables
	excludeSet := make(map[string]bool)
	for _, t := range exclude {
		excludeSet[t.Schema+"."+t.Name] = true
	}

	rows, err := db.QueryContext(ctx, `
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema NOT IN ('information_schema', 'pg_catalog', 'tiger', 'topology')
        ORDER BY table_schema, table_name
    `)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tables []model.DiscoveredTable
	for rows.Next() {
		var t model.DiscoveredTable
		if err := rows.Scan(&t.Schema, &t.Name); err != nil {
			continue
		}
		if excludeSet[t.Schema+"."+t.Name] {
			continue
		}
		t.QualifiedName = t.Schema + "." + t.Name
		tables = append(tables, t)
	}
	return tables, nil
}

func (s *DiscoveryService) discoverColumns(ctx context.Context, db *sql.DB, schema, table, geomColumn string) ([]model.DiscoveredColumn, error) {
	// Get primary key columns
	pkRows, err := db.QueryContext(ctx, `
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = ($1 || '.' || $2)::regclass
          AND i.indisprimary
    `, schema, table)
	pkSet := make(map[string]bool)
	if err == nil {
		for pkRows.Next() {
			var col string
			if pkRows.Scan(&col) == nil {
				pkSet[col] = true
			}
		}
		pkRows.Close()
	}

	// Get all columns
	rows, err := db.QueryContext(ctx, `
        SELECT
            column_name, data_type, udt_name, is_nullable
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position
    `, schema, table)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cols []model.DiscoveredColumn
	for rows.Next() {
		var c model.DiscoveredColumn
		var nullable string
		if err := rows.Scan(&c.Name, &c.DataType, &c.UDTName, &nullable); err != nil {
			continue
		}
		c.IsNullable = nullable == "YES"
		c.IsPrimaryKey = pkSet[c.Name]
		c.IsGeometry = c.Name == geomColumn
		// USER-DEFINED type usually indicates an ENUM in Postgres
		if c.DataType == "USER-DEFINED" {
			values, err := s.fetchEnumValues(ctx, db, c.UDTName)
			if err == nil && len(values) > 0 {
				c.IsEnum = true
				c.EnumValues = values
			}
		}
		cols = append(cols, c)
	}
	return cols, nil
}

// DiscoverTableColumns is a public wrapper around discoverColumns so other
// services can fetch column metadata for a known table.
func (s *DiscoveryService) DiscoverTableColumns(
    ctx context.Context,
    conn model.BulkImportInlineConnection,
    schema, table, geomColumn string,
) ([]model.DiscoveredColumn, error) {
    db, err := s.openConn(conn)
    if err != nil {
        return nil, fmt.Errorf("open connection: %w", err)
    }
    defer db.Close()

    return s.discoverColumns(ctx, db, schema, table, geomColumn)
}

func (s *DiscoveryService) fetchEnumValues(ctx context.Context, db *sql.DB, udtName string) ([]string, error) {
	rows, err := db.QueryContext(ctx, `
        SELECT e.enumlabel
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = $1
        ORDER BY e.enumsortorder
    `, udtName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var values []string
	for rows.Next() {
		var v string
		if rows.Scan(&v) == nil {
			values = append(values, v)
		}
	}
	return values, nil
}

func (s *DiscoveryService) tableRowCount(ctx context.Context, db *sql.DB, schema, table string) (int64, error) {
	q := fmt.Sprintf("SELECT count(*) FROM %s.%s", quoteIdent(schema), quoteIdent(table))
	var n int64
	if err := db.QueryRowContext(ctx, q).Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}

func quoteIdent(s string) string {
	return `"` + strings.ReplaceAll(s, `"`, `""`) + `"`
}

func normalizeSSLMode(input string) string {
	v := strings.ToLower(strings.TrimSpace(input))
	switch v {
	case "require", "verify-ca", "verify-full", "prefer", "allow":
		return v
	default:
		return "disable"
	}
}
