package auth

import (
    "context"
    "database/sql"
    "errors"
    "time"
    "strings"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type Repo struct{ db *bun.DB }

func NewRepo(db *bun.DB) *Repo { return &Repo{db: db} }

// Users

func (r *Repo) GetUserByID(ctx context.Context, id uuid.UUID) (*User, error) {
    u := new(User)
    err := r.db.NewSelect().Model(u).Where("id = ?", id).Scan(ctx)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }
    return u, nil
}

func (r *Repo) GetUserByEmail(ctx context.Context, email string) (*User, error) {
    u := new(User)
    err := r.db.NewSelect().Model(u).Where("email = ?", email).Scan(ctx)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }
    return u, nil
}

// Identities

func (r *Repo) GetLocalIdentity(ctx context.Context, email string) (*Identity, error) {
    i := new(Identity)
    err := r.db.NewSelect().Model(i).
        Where("provider = ? AND subject = ?", ProviderLocal, email).
        Scan(ctx)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }
    return i, nil
}

// Refresh tokens

func (r *Repo) InsertRefreshToken(ctx context.Context, rt *RefreshToken) error {
    _, err := r.db.NewInsert().Model(rt).Returning("*").Exec(ctx)
    return err
}

func (r *Repo) GetRefreshByHash(ctx context.Context, hash string) (*RefreshToken, error) {
    rt := new(RefreshToken)
    err := r.db.NewSelect().Model(rt).Where("token_hash = ?", hash).Scan(ctx)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }
    return rt, nil
}

func (r *Repo) RevokeRefresh(ctx context.Context, id uuid.UUID) error {
    now := time.Now()
    _, err := r.db.NewUpdate().Model((*RefreshToken)(nil)).
        Set("revoked_at = ?", now).
        Where("id = ? AND revoked_at IS NULL", id).
        Exec(ctx)
    return err
}


func (r *Repo) ListUsers(ctx context.Context, f UserListFilter, offset, limit int) ([]*User, int64, error) {
    q := r.db.NewSelect().Model((*User)(nil))

    if f.Search != "" {
        like := "%" + strings.ToLower(f.Search) + "%"
        q = q.Where("lower(email) LIKE ? OR lower(display_name) LIKE ?", like, like)
    }
    if f.AuthSource != "" {
        q = q.Where("auth_source = ?", f.AuthSource)
    }
    if f.Status != "" {
        q = q.Where("status = ?", f.Status)
    }
    if f.Role != "" {
        q = q.Where("role = ?", f.Role)
    }

    total, err := q.Count(ctx)
    if err != nil {
        return nil, 0, err
    }

    users := []*User{}
    err = q.Order("created_at DESC").
        Offset(offset).
        Limit(limit).
        Scan(ctx, &users)
    if err != nil {
        return nil, 0, err
    }

    return users, int64(total), nil
}

func (r *Repo) UpdateUser(ctx context.Context, u *User) error {
    u.UpdatedAt = time.Now()
    _, err := r.db.NewUpdate().Model(u).WherePK().Exec(ctx)
    return err
}

// UpsertFromGoTrue links a GoTrue identity (sub UUID) to app.users for geo RBAC.
// - Match by id first, then by email (relink PK to GoTrue sub).
// - New users are pending viewers unless email matches SUPERUSER_EMAIL or they
//   are an FC platform super-admin (public.user_profiles.is_system_admin).
// - FC system admins are synced to geo superuser (not pending) on every login.
// - FC supervisors are synced to geo supervisor (not pending) when not already
//   elevated to superuser.
func (r *Repo) UpsertFromGoTrue(
    ctx context.Context,
    id uuid.UUID,
    email, displayName, authSource, superuserEmail string,
) (*User, error) {
    email = strings.TrimSpace(email)
    if email == "" {
        return nil, errors.New("email required from GoTrue token")
    }
    if displayName == "" {
        displayName = email
    }
    if authSource == "" {
        authSource = "local"
    }

    fcSuper, err := r.isFCSystemAdmin(ctx, id, email)
    if err != nil {
        return nil, err
    }
    fcRole, err := r.fcProfileRole(ctx, id, email)
    if err != nil {
        return nil, err
    }
    breakGlass := superuserEmail != "" && strings.EqualFold(email, superuserEmail)
    elevateSuper := fcSuper || breakGlass
    elevateSupervisor := !elevateSuper && (fcRole == "supervisor" || fcRole == "admin")

    existing, err := r.GetUserByID(ctx, id)
    if err != nil {
        return nil, err
    }
    if existing != nil {
        now := time.Now()
        existing.LastLoginAt = &now
        if displayName != "" && existing.DisplayName == "" {
            existing.DisplayName = displayName
        }
        if authSource != "" && existing.AuthSource == "" {
            existing.AuthSource = authSource
        }
        applyGeoElevation(existing, elevateSuper, elevateSupervisor)
        if err := r.UpdateUser(ctx, existing); err != nil {
            return nil, err
        }
        return existing, nil
    }

    byEmail, err := r.GetUserByEmail(ctx, email)
    if err != nil {
        return nil, err
    }
    if byEmail != nil {
        if byEmail.ID != id {
            if err := r.relinkUserID(ctx, byEmail.ID, id); err != nil {
                return nil, err
            }
        }
        u, err := r.GetUserByID(ctx, id)
        if err != nil || u == nil {
            return nil, err
        }
        now := time.Now()
        u.LastLoginAt = &now
        u.DisplayName = displayName
        u.AuthSource = authSource
        applyGeoElevation(u, elevateSuper, elevateSupervisor)
        if err := r.UpdateUser(ctx, u); err != nil {
            return nil, err
        }
        return u, nil
    }

    role := RoleViewer
    pending := true
    if elevateSuper {
        role = RoleSuperuser
        pending = false
    } else if elevateSupervisor {
        role = RoleSupervisor
        pending = false
    }

    now := time.Now()
    u := &User{
        ID:          id,
        Email:       email,
        DisplayName: displayName,
        Role:        role,
        Status:      StatusActive,
        AuthSource:  authSource,
        Pending:     pending,
        LastLoginAt: &now,
        CreatedAt:   now,
        UpdatedAt:   now,
    }
    if _, err := r.db.NewInsert().Model(u).Exec(ctx); err != nil {
        return nil, err
    }
    return u, nil
}

// isFCSystemAdmin reports whether the shared GoTrue user is a Field Collector
// platform super-admin (public.user_profiles.is_system_admin).
func (r *Repo) isFCSystemAdmin(ctx context.Context, id uuid.UUID, email string) (bool, error) {
    var ok bool
    err := r.db.NewRaw(`
        SELECT EXISTS (
            SELECT 1
            FROM public.user_profiles AS p
            WHERE (p.id = ? OR lower(p.email) = lower(?))
              AND p.is_system_admin = true
        )
    `, id, email).Scan(ctx, &ok)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return false, nil
        }
        return false, err
    }
    return ok, nil
}

// fcProfileRole returns public.user_profiles.role for the shared identity.
func (r *Repo) fcProfileRole(ctx context.Context, id uuid.UUID, email string) (string, error) {
    var role sql.NullString
    err := r.db.NewRaw(`
        SELECT p.role
        FROM public.user_profiles AS p
        WHERE p.id = ? OR lower(p.email) = lower(?)
        ORDER BY CASE WHEN p.id = ? THEN 0 ELSE 1 END
        LIMIT 1
    `, id, email, id).Scan(ctx, &role)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return "", nil
        }
        return "", err
    }
    if !role.Valid {
        return "", nil
    }
    return role.String, nil
}

// SyncFCRoleFromGeo mirrors geo role changes into FC user_profiles.
// - supervisor → upsert FC role=supervisor (never touches is_system_admin)
// - editor/viewer → demote FC supervisor → field_worker only (safe; skip admins)
// - superuser → no FC write (admin bridge is FC → geo)
func (r *Repo) SyncFCRoleFromGeo(ctx context.Context, u *User) error {
    if u == nil {
        return nil
    }
    switch u.Role {
    case RoleSupervisor:
        _, err := r.db.NewRaw(`
            INSERT INTO public.user_profiles (id, email, full_name, role, updated_at)
            VALUES (?, ?, ?, 'supervisor', now())
            ON CONFLICT (email) DO UPDATE
            SET
              id = EXCLUDED.id,
              full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.user_profiles.full_name),
              role = CASE
                WHEN public.user_profiles.is_system_admin THEN public.user_profiles.role
                ELSE 'supervisor'
              END,
              updated_at = now()
        `, u.ID, u.Email, u.DisplayName).Exec(ctx)
        return err
    case RoleEditor, RoleViewer:
        _, err := r.db.NewRaw(`
            UPDATE public.user_profiles AS p
            SET role = 'field_worker', updated_at = now()
            WHERE (p.id = ? OR lower(p.email) = lower(?))
              AND COALESCE(p.is_system_admin, false) = false
              AND p.role = 'supervisor'
        `, u.ID, u.Email).Exec(ctx)
        return err
    default:
        return nil
    }
}

func applyGeoElevation(u *User, elevateSuper, elevateSupervisor bool) {
    if elevateSuper {
        u.Role = RoleSuperuser
        u.Pending = false
        if u.Status != StatusDisabled {
            u.Status = StatusActive
        }
        return
    }
    if elevateSupervisor && u.Role != RoleSuperuser {
        u.Role = RoleSupervisor
        u.Pending = false
        if u.Status != StatusDisabled {
            u.Status = StatusActive
        }
    }
}

// relinkUserID moves an existing app.users row onto the GoTrue subject UUID.
func (r *Repo) relinkUserID(ctx context.Context, oldID, newID uuid.UUID) error {
    return r.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
        // Drop local auth artifacts that may FK to the old id.
        if _, err := tx.NewDelete().Model((*Identity)(nil)).Where("user_id = ?", oldID).Exec(ctx); err != nil {
            return err
        }
        if _, err := tx.NewDelete().Model((*RefreshToken)(nil)).Where("user_id = ?", oldID).Exec(ctx); err != nil {
            return err
        }
        _, err := tx.NewUpdate().Model((*User)(nil)).
            Set("id = ?", newID).
            Set("updated_at = ?", time.Now()).
            Where("id = ?", oldID).
            Exec(ctx)
        return err
    })
}
