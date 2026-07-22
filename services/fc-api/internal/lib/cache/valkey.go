package cache

import (
    "context"
    "encoding/json"
    "errors"
    "log/slog"
    "sync"
    "time"

    "github.com/redis/go-redis/v9"
)

// Cache is the abstraction we use throughout the app.
// Backed by Valkey/Redis when available; falls back to in-memory when not.
type Cache interface {
    Get(ctx context.Context, key string) (string, error)
    Set(ctx context.Context, key, value string, ttl time.Duration) error
    SetNX(ctx context.Context, key, value string, ttl time.Duration) (bool, error)
    Del(ctx context.Context, keys ...string) error
    DelPattern(ctx context.Context, pattern string) error
    GetJSON(ctx context.Context, key string, dest interface{}) error
    SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error
    Ping(ctx context.Context) error
    Close() error
}

// ErrCacheMiss is returned when a key is not found.
var ErrCacheMiss = errors.New("cache miss")

// ── Valkey-backed implementation ────────────────────────

type valkeyCache struct {
    client *redis.Client
}

// New attempts to connect to Valkey/Redis. If URL is empty or unreachable,
// returns an in-memory fallback so the app keeps working.
func New(url string) Cache {
    if url == "" {
        slog.Info("cache: no URL configured, using in-memory cache")
        return newMemoryCache()
    }

    opt, err := redis.ParseURL(url)
    if err != nil {
        slog.Warn("cache: invalid URL, falling back to in-memory", "error", err)
        return newMemoryCache()
    }

    client := redis.NewClient(opt)
    ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
    defer cancel()

    if err := client.Ping(ctx).Err(); err != nil {
        slog.Warn("cache: cannot reach Valkey, falling back to in-memory", "error", err, "url", url)
        _ = client.Close()
        return newMemoryCache()
    }

    slog.Info("cache: connected to Valkey", "url", url)
    return &valkeyCache{client: client}
}

func (c *valkeyCache) Get(ctx context.Context, key string) (string, error) {
    v, err := c.client.Get(ctx, key).Result()
    if errors.Is(err, redis.Nil) {
        return "", ErrCacheMiss
    }
    return v, err
}

func (c *valkeyCache) Set(ctx context.Context, key, value string, ttl time.Duration) error {
    return c.client.Set(ctx, key, value, ttl).Err()
}

func (c *valkeyCache) SetNX(ctx context.Context, key, value string, ttl time.Duration) (bool, error) {
    return c.client.SetNX(ctx, key, value, ttl).Result()
}

func (c *valkeyCache) Del(ctx context.Context, keys ...string) error {
    if len(keys) == 0 {
        return nil
    }
    return c.client.Del(ctx, keys...).Err()
}

func (c *valkeyCache) DelPattern(ctx context.Context, pattern string) error {
    iter := c.client.Scan(ctx, 0, pattern, 100).Iterator()
    var toDelete []string
    for iter.Next(ctx) {
        toDelete = append(toDelete, iter.Val())
        if len(toDelete) >= 100 {
            if err := c.client.Del(ctx, toDelete...).Err(); err != nil {
                return err
            }
            toDelete = toDelete[:0]
        }
    }
    if err := iter.Err(); err != nil {
        return err
    }
    if len(toDelete) > 0 {
        return c.client.Del(ctx, toDelete...).Err()
    }
    return nil
}

func (c *valkeyCache) GetJSON(ctx context.Context, key string, dest interface{}) error {
    v, err := c.Get(ctx, key)
    if err != nil {
        return err
    }
    return json.Unmarshal([]byte(v), dest)
}

func (c *valkeyCache) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
    b, err := json.Marshal(value)
    if err != nil {
        return err
    }
    return c.Set(ctx, key, string(b), ttl)
}

func (c *valkeyCache) Ping(ctx context.Context) error {
    return c.client.Ping(ctx).Err()
}

func (c *valkeyCache) Close() error {
    return c.client.Close()
}

// ── In-memory fallback ──────────────────────────────────

type memoryEntry struct {
    value     string
    expiresAt time.Time
}

type memoryCache struct {
    mu      sync.RWMutex
    entries map[string]memoryEntry
}

func newMemoryCache() *memoryCache {
    m := &memoryCache{
        entries: make(map[string]memoryEntry),
    }
    // Background cleanup
    go func() {
        t := time.NewTicker(30 * time.Second)
        defer t.Stop()
        for range t.C {
            m.gc()
        }
    }()
    return m
}

func (m *memoryCache) gc() {
    m.mu.Lock()
    defer m.mu.Unlock()
    now := time.Now()
    for k, e := range m.entries {
        if !e.expiresAt.IsZero() && now.After(e.expiresAt) {
            delete(m.entries, k)
        }
    }
}

func (m *memoryCache) Get(_ context.Context, key string) (string, error) {
    m.mu.RLock()
    defer m.mu.RUnlock()
    e, ok := m.entries[key]
    if !ok {
        return "", ErrCacheMiss
    }
    if !e.expiresAt.IsZero() && time.Now().After(e.expiresAt) {
        return "", ErrCacheMiss
    }
    return e.value, nil
}

func (m *memoryCache) Set(_ context.Context, key, value string, ttl time.Duration) error {
    m.mu.Lock()
    defer m.mu.Unlock()
    exp := time.Time{}
    if ttl > 0 {
        exp = time.Now().Add(ttl)
    }
    m.entries[key] = memoryEntry{value: value, expiresAt: exp}
    return nil
}

func (m *memoryCache) SetNX(_ context.Context, key, value string, ttl time.Duration) (bool, error) {
    m.mu.Lock()
    defer m.mu.Unlock()
    if e, ok := m.entries[key]; ok {
        if e.expiresAt.IsZero() || time.Now().Before(e.expiresAt) {
            return false, nil
        }
    }
    exp := time.Time{}
    if ttl > 0 {
        exp = time.Now().Add(ttl)
    }
    m.entries[key] = memoryEntry{value: value, expiresAt: exp}
    return true, nil
}

func (m *memoryCache) Del(_ context.Context, keys ...string) error {
    m.mu.Lock()
    defer m.mu.Unlock()
    for _, k := range keys {
        delete(m.entries, k)
    }
    return nil
}

func (m *memoryCache) DelPattern(_ context.Context, pattern string) error {
    m.mu.Lock()
    defer m.mu.Unlock()
    for k := range m.entries {
        if matchGlob(pattern, k) {
            delete(m.entries, k)
        }
    }
    return nil
}

func matchGlob(pattern, key string) bool {
    // Very basic glob matcher (supports trailing *).
    if pattern == key {
        return true
    }
    if n := len(pattern); n > 0 && pattern[n-1] == '*' {
        prefix := pattern[:n-1]
        return len(key) >= len(prefix) && key[:len(prefix)] == prefix
    }
    return false
}

func (m *memoryCache) GetJSON(ctx context.Context, key string, dest interface{}) error {
    v, err := m.Get(ctx, key)
    if err != nil {
        return err
    }
    return json.Unmarshal([]byte(v), dest)
}

func (m *memoryCache) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
    b, err := json.Marshal(value)
    if err != nil {
        return err
    }
    return m.Set(ctx, key, string(b), ttl)
}

func (m *memoryCache) Ping(_ context.Context) error { return nil }
func (m *memoryCache) Close() error                  { return nil }