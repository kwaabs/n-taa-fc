package config

import (
    "fmt"
    "log/slog"
    "os"
    "strconv"
    "strings"
    "time"

    "github.com/joho/godotenv"
)

type Env string

const (
    EnvDevelopment Env = "development"
    EnvProduction  Env = "production"
)

type Config struct {
    Env      Env
    Host     string
    Port     int
    LogLevel slog.Level

    DatabaseURL       string
    DBMaxOpenConns    int
    DBMaxIdleConns    int
    DBConnMaxLifetime time.Duration

    CORSAllowedOrigins []string

    MartinBaseURL string

    // Shared with GoTrue / Field Collector (GOTRUE_JWT_SECRET)
    JWTSecret string

    SuperuserEmail    string
    SuperuserPassword string // unused under GoTrue; kept for env compat
    SuperuserName     string

    CookieDomain string
    CookieSecure bool

    // Shared RustFS (same bucket as FC) — optional; media list empty if unset
    S3Endpoint       string
    S3PublicEndpoint string
    S3Bucket         string
    S3AccessKey      string
    S3SecretKey      string
}

func Load() (*Config, error) {
    _ = godotenv.Load()

    // Prefer JWT_SECRET (shared with FC/GoTrue); fall back to legacy JWT_SIGNING_KEY
    jwtSecret := getEnv("JWT_SECRET", "")
    if jwtSecret == "" {
        jwtSecret = getEnv("JWT_SIGNING_KEY", "")
    }

    cfg := &Config{
        Env:               Env(getEnv("API_ENV", "development")),
        Host:              getEnv("API_HOST", "0.0.0.0"),
        Port:              getEnvInt("API_PORT", 5442),
        LogLevel:          parseLogLevel(getEnv("API_LOG_LEVEL", "info")),
        DatabaseURL:       getEnv("DATABASE_URL", ""),
        DBMaxOpenConns:    getEnvInt("DB_MAX_OPEN_CONNS", 20),
        DBMaxIdleConns:    getEnvInt("DB_MAX_IDLE_CONNS", 5),
        DBConnMaxLifetime: getEnvDuration("DB_CONN_MAX_LIFETIME", 30*time.Minute),

        CORSAllowedOrigins: splitCSV(getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:5357")),

        MartinBaseURL: getEnv("MARTIN_BASE_URL", "http://localhost:5360"),

        JWTSecret: jwtSecret,

        SuperuserEmail:    getEnv("SUPERUSER_EMAIL", ""),
        SuperuserPassword: getEnv("SUPERUSER_PASSWORD", ""),
        SuperuserName:     getEnv("SUPERUSER_NAME", ""),

        CookieDomain: getEnv("COOKIE_DOMAIN", ""),
        CookieSecure: getEnvBool("COOKIE_SECURE", false),

        S3Endpoint:       getEnv("S3_ENDPOINT", "http://localhost:5352"),
        S3PublicEndpoint: getEnv("S3_PUBLIC_ENDPOINT", "http://localhost:5352"),
        S3Bucket:         getEnv("S3_BUCKET", "field-collector"),
        S3AccessKey:      getEnv("S3_ACCESS_KEY", "rustfsadmin"),
        S3SecretKey:      getEnv("S3_SECRET_KEY", "rustfsadmin"),
    }

    if err := cfg.validate(); err != nil {
        return nil, err
    }
    return cfg, nil
}

func (c *Config) validate() error {
    if c.DatabaseURL == "" {
        return fmt.Errorf("DATABASE_URL is required")
    }
    if c.Port <= 0 || c.Port > 65535 {
        return fmt.Errorf("API_PORT must be 1..65535, got %d", c.Port)
    }
    if c.Env != EnvDevelopment && c.Env != EnvProduction {
        return fmt.Errorf("API_ENV must be development or production, got %q", c.Env)
    }
    if len(c.JWTSecret) < 32 {
        return fmt.Errorf("JWT_SECRET (shared GoTrue secret) must be at least 32 chars")
    }
    return nil
}

func (c *Config) Addr() string { return fmt.Sprintf("%s:%d", c.Host, c.Port) }
func (c *Config) IsDev() bool  { return c.Env == EnvDevelopment }

// helpers unchanged, plus one addition:
func getEnv(key, fallback string) string {
    if v, ok := os.LookupEnv(key); ok && v != "" {
        return v
    }
    return fallback
}

func getEnvInt(key string, fallback int) int {
    if v, ok := os.LookupEnv(key); ok && v != "" {
        if n, err := strconv.Atoi(v); err == nil {
            return n
        }
    }
    return fallback
}

func getEnvBool(key string, fallback bool) bool {
    if v, ok := os.LookupEnv(key); ok && v != "" {
        switch strings.ToLower(v) {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        }
    }
    return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
    if v, ok := os.LookupEnv(key); ok && v != "" {
        if d, err := time.ParseDuration(v); err == nil {
            return d
        }
    }
    return fallback
}

func splitCSV(s string) []string {
    if s == "" {
        return nil
    }
    parts := strings.Split(s, ",")
    out := make([]string, 0, len(parts))
    for _, p := range parts {
        if t := strings.TrimSpace(p); t != "" {
            out = append(out, t)
        }
    }
    return out
}

func parseLogLevel(s string) slog.Level {
    switch strings.ToLower(s) {
    case "debug":
        return slog.LevelDebug
    case "warn":
        return slog.LevelWarn
    case "error":
        return slog.LevelError
    default:
        return slog.LevelInfo
    }
}
