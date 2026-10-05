package auth

import (
    "context"
    "database/sql"
    "strings"
    "time"

    "github.com/google/uuid"
)

// LoginEvent is one row from GoTrue's own auth.audit_log_entries table,
// joined against app.users for role/display-name context. geo_app only has
// SELECT on auth.audit_log_entries (see infra/postgres/migrations/004) —
// GoTrue owns writes to that table.
type LoginEvent struct {
    ID          uuid.UUID
    CreatedAt   time.Time
    IPAddress   string
    Email       string
    UserID      *uuid.UUID
    DisplayName string
    Role        string
}

type LoginEventFilter struct {
    Email string
}

// ListLoginEvents returns GoTrue "login" audit entries, newest first.
func (r *Repo) ListLoginEvents(ctx context.Context, f LoginEventFilter, offset, limit int) ([]LoginEvent, int64, error) {
    search := strings.TrimSpace(f.Email)

    var total int64
    if err := r.db.NewRaw(`
        SELECT count(*)
        FROM auth.audit_log_entries a
        WHERE a.payload->>'action' = 'login'
          AND (? = '' OR a.payload->>'actor_username' ILIKE '%' || ? || '%')
    `, search, search).Scan(ctx, &total); err != nil {
        return nil, 0, err
    }

    type row struct {
        ID            uuid.UUID      `bun:"id"`
        CreatedAt     time.Time      `bun:"created_at"`
        IPAddress     string         `bun:"ip_address"`
        ActorUsername string         `bun:"actor_username"`
        ActorID       sql.NullString `bun:"actor_id"`
        DisplayName   sql.NullString `bun:"display_name"`
        Role          sql.NullString `bun:"role"`
    }
    var rows []row

    err := r.db.NewRaw(`
        SELECT
          a.id,
          a.created_at,
          a.ip_address,
          COALESCE(a.payload->>'actor_username', '') AS actor_username,
          a.payload->>'actor_id'                      AS actor_id,
          u.display_name,
          u.role::text AS role
        FROM auth.audit_log_entries a
        LEFT JOIN app.users u ON u.id::text = a.payload->>'actor_id'
        WHERE a.payload->>'action' = 'login'
          AND (? = '' OR a.payload->>'actor_username' ILIKE '%' || ? || '%')
        ORDER BY a.created_at DESC
        LIMIT ? OFFSET ?
    `, search, search, limit, offset).Scan(ctx, &rows)
    if err != nil {
        return nil, 0, err
    }

    events := make([]LoginEvent, 0, len(rows))
    for _, rw := range rows {
        ev := LoginEvent{
            ID:          rw.ID,
            CreatedAt:   rw.CreatedAt,
            IPAddress:   rw.IPAddress,
            Email:       rw.ActorUsername,
            DisplayName: rw.DisplayName.String,
            Role:        rw.Role.String,
        }
        if rw.ActorID.Valid {
            if id, err := uuid.Parse(rw.ActorID.String); err == nil {
                ev.UserID = &id
            }
        }
        events = append(events, ev)
    }

    return events, total, nil
}
