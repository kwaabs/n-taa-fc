package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

// HomeDBConnection is the FC app's own Postgres, parsed from DATABASE_URL.
type HomeDBConnection struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Database string `json:"database"`
	Username string `json:"username"`
	Password string `json:"password"`
	SSLMode  string `json:"ssl_mode"`
}

type Config struct {
	Port             string
	Env              string
	DatabaseURL      string
	JWTSecret        string
	CORSOrigins      string
	S3Endpoint       string
	S3PublicEndpoint string // ← NEW
	S3Bucket         string
	S3AccessKey      string
	S3SecretKey      string
	S3UseSSL         bool
	ValkeyURL        string
	ValkeyPass       string
	ValkeyDB         int
	GoTrueURL        string
}

func Load() *Config {
	_ = godotenv.Load()

	return &Config{
		Port:             getEnv("PORT", "5355"),
		Env:              getEnv("ENV", "development"),
		DatabaseURL:      getEnv("DATABASE_URL", "postgres://supabase_admin:ntaafc@localhost:5350/ntaafc?sslmode=disable"),
		JWTSecret:        getEnv("JWT_SECRET", "super-secret-jwt-key-change-me-in-production"),
		CORSOrigins:      getEnv("CORS_ORIGINS", "http://localhost:5356,http://localhost:3000,http://localhost:53397"),
		S3Endpoint:       getEnv("S3_ENDPOINT", "http://localhost:5352"),
		S3PublicEndpoint: getEnv("S3_PUBLIC_ENDPOINT", "http://localhost:5352"),
		S3Bucket:         getEnv("S3_BUCKET", "field-collector"),
		S3AccessKey:      getEnv("S3_ACCESS_KEY", "rustfsadmin"),
		S3SecretKey:      getEnv("S3_SECRET_KEY", "rustfsadmin"),
		S3UseSSL:         getEnv("S3_USE_SSL", "false") == "true",
		ValkeyURL:        getEnv("VALKEY_URL", "redis://localhost:5351"),
		ValkeyPass:       getEnv("VALKEY_PASSWORD", ""),
		GoTrueURL:        getEnv("GOTRUE_URL", "http://localhost:5354"),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

// ParseDatabaseURL extracts connection fields from a postgres DSN.
func ParseDatabaseURL(dsn string) (*HomeDBConnection, error) {
	u, err := url.Parse(dsn)
	if err != nil {
		return nil, fmt.Errorf("invalid DATABASE_URL: %w", err)
	}
	if u.Host == "" {
		return nil, fmt.Errorf("DATABASE_URL missing host")
	}

	host := u.Hostname()
	port := 5432
	if p := u.Port(); p != "" {
		port, err = strconv.Atoi(p)
		if err != nil {
			return nil, fmt.Errorf("invalid DATABASE_URL port: %w", err)
		}
	} else if _, p, splitErr := net.SplitHostPort(u.Host); splitErr == nil {
		port, _ = strconv.Atoi(p)
	}

	database := strings.TrimPrefix(u.Path, "/")
	if database == "" {
		return nil, fmt.Errorf("DATABASE_URL missing database name")
	}

	username := ""
	password := ""
	if u.User != nil {
		username = u.User.Username()
		password, _ = u.User.Password()
	}

	sslMode := u.Query().Get("sslmode")
	if sslMode == "" {
		sslMode = "disable"
	}

	return &HomeDBConnection{
		Host:     host,
		Port:     port,
		Database: database,
		Username: username,
		Password: password,
		SSLMode:  sslMode,
	}, nil
}
