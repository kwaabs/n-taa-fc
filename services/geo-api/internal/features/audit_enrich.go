package features

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
	"github.com/uptrace/bun"
)

var auditUserKeys = []string{
	"created_user",
	"created_by",
	"last_edited_user",
	"updated_by",
}

// EnrichAuditUserEmails replaces UUID-valued audit user fields with emails
// from public.user_profiles / app.users. Unknown IDs are left unchanged.
func (r *Repo) EnrichAuditUserEmails(ctx context.Context, props json.RawMessage) json.RawMessage {
	if len(props) == 0 || string(props) == "null" {
		return props
	}
	var m map[string]any
	if err := json.Unmarshal(props, &m); err != nil || len(m) == 0 {
		return props
	}

	ids := make([]uuid.UUID, 0, 2)
	seen := map[uuid.UUID]struct{}{}
	for _, key := range auditUserKeys {
		id, ok := uuidFromProp(m, key)
		if !ok {
			continue
		}
		if _, dup := seen[id]; dup {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}
	if len(ids) == 0 {
		return props
	}

	emails := r.lookupUserEmails(ctx, ids)
	if len(emails) == 0 {
		return props
	}

	changed := false
	for _, key := range auditUserKeys {
		id, ok := uuidFromProp(m, key)
		if !ok {
			continue
		}
		if email, hit := emails[id]; hit && email != "" {
			setProp(m, key, email)
			changed = true
		}
	}
	if !changed {
		return props
	}
	out, err := json.Marshal(m)
	if err != nil {
		return props
	}
	return out
}

func uuidFromProp(m map[string]any, key string) (uuid.UUID, bool) {
	v, ok := m[key]
	if !ok {
		for k, val := range m {
			if strings.EqualFold(k, key) {
				v, ok = val, true
				break
			}
		}
	}
	if !ok || v == nil {
		return uuid.Nil, false
	}
	s, ok := v.(string)
	if !ok {
		return uuid.Nil, false
	}
	s = strings.TrimSpace(s)
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func setProp(m map[string]any, key string, value string) {
	if _, ok := m[key]; ok {
		m[key] = value
		return
	}
	for k := range m {
		if strings.EqualFold(k, key) {
			m[k] = value
			return
		}
	}
}

func (r *Repo) lookupUserEmails(ctx context.Context, ids []uuid.UUID) map[uuid.UUID]string {
	out := make(map[uuid.UUID]string, len(ids))
	if len(ids) == 0 {
		return out
	}

	type row struct {
		ID    uuid.UUID `bun:"id"`
		Email string    `bun:"email"`
	}

	// Prefer FC profiles (write-back uses collected_by from there); fall back to geo app.users.
	var rows []row
	_ = r.db.NewRaw(`
		SELECT p.id, p.email
		FROM public.user_profiles AS p
		WHERE p.id IN (?)
		  AND COALESCE(p.email, '') <> ''
	`, bun.In(ids)).Scan(ctx, &rows)
	for _, row := range rows {
		out[row.ID] = row.Email
	}

	missing := make([]uuid.UUID, 0)
	for _, id := range ids {
		if _, ok := out[id]; !ok {
			missing = append(missing, id)
		}
	}
	if len(missing) == 0 {
		return out
	}

	rows = rows[:0]
	_ = r.db.NewRaw(`
		SELECT u.id, u.email
		FROM app.users AS u
		WHERE u.id IN (?)
		  AND COALESCE(u.email, '') <> ''
	`, bun.In(missing)).Scan(ctx, &rows)
	for _, row := range rows {
		out[row.ID] = row.Email
	}
	return out
}
