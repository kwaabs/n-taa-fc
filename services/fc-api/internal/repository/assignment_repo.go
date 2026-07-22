package repository

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
)

type AssignmentRepo struct {
    db *bun.DB
}

func NewAssignmentRepo(db *bun.DB) *AssignmentRepo {
    return &AssignmentRepo{db: db}
}

func (r *AssignmentRepo) Create(ctx context.Context, a *model.Assignment) error {
    // Handle geometry separately if present
    if a.Area != nil && *a.Area != "" {
        // We'll set area via raw SQL
        areaJSON := *a.Area
        a.Area = nil
        _, err := r.db.NewInsert().Model(a).
            Value("area", "ST_GeomFromGeoJSON(?)", areaJSON).
            Returning("*").
            Exec(ctx)
        return err
    }
    _, err := r.db.NewInsert().Model(a).Exec(ctx)
    return err
}

func (r *AssignmentRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.Assignment, error) {
    a := new(model.Assignment)
    err := r.db.NewSelect().
        Model(a).
        ColumnExpr("asg.id, asg.project_id, asg.assigned_to, asg.team_id, asg.assigned_by, asg.form_id, asg.layer_id").
        ColumnExpr("CASE WHEN asg.area IS NOT NULL THEN ST_AsGeoJSON(asg.area)::text ELSE NULL END AS area").
        ColumnExpr("asg.title, asg.target_count, asg.instructions, asg.priority, asg.due_date, asg.status, asg.created_at").
        Relation("Team").
        Relation("Assignee").
        Relation("Form").
        Relation("Layer").
        Where("asg.id = ?", id).
        Scan(ctx)
    return a, err
}

func (r *AssignmentRepo) ListByProject(ctx context.Context, projectID uuid.UUID) ([]model.Assignment, error) {
    var assignments []model.Assignment
    err := r.db.NewSelect().
        Model(&assignments).
        ColumnExpr("asg.id, asg.project_id, asg.assigned_to, asg.team_id, asg.assigned_by, asg.form_id, asg.layer_id").
        ColumnExpr("CASE WHEN asg.area IS NOT NULL THEN ST_AsGeoJSON(asg.area)::text ELSE NULL END AS area").
        ColumnExpr("asg.title, asg.target_count, asg.instructions, asg.priority, asg.due_date, asg.status, asg.created_at").
        Relation("Team").
        Relation("Assignee").
        Relation("Form").
        Relation("Layer").
        Where("asg.project_id = ?", projectID).
        OrderExpr(`
            CASE asg.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
            asg.due_date NULLS LAST,
            asg.created_at DESC
        `).
        Scan(ctx)
    return assignments, err
}

func (r *AssignmentRepo) ListByUser(ctx context.Context, userID, projectID uuid.UUID) ([]model.Assignment, error) {
    var assignments []model.Assignment
    err := r.db.NewSelect().
        Model(&assignments).
        ColumnExpr("asg.id, asg.project_id, asg.assigned_to, asg.team_id, asg.assigned_by, asg.form_id, asg.layer_id").
        ColumnExpr("CASE WHEN asg.area IS NOT NULL THEN ST_AsGeoJSON(asg.area)::text ELSE NULL END AS area").
        ColumnExpr("asg.title, asg.target_count, asg.instructions, asg.priority, asg.due_date, asg.status, asg.created_at").
        Where("asg.project_id = ?", projectID).
        Where(`
            asg.assigned_to = ? 
            OR asg.team_id IN (
                SELECT team_id FROM team_members WHERE user_id = ?
            )
        `, userID, userID).
        Scan(ctx)
    return assignments, err
}

func (r *AssignmentRepo) Update(ctx context.Context, a *model.Assignment) error {
    _, err := r.db.NewUpdate().
        Model(a).
        WherePK().
        OmitZero().
        ExcludeColumn("area").
        Exec(ctx)
    return err
}

func (r *AssignmentRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status string) error {
    _, err := r.db.NewUpdate().
        Model((*model.Assignment)(nil)).
        Set("status = ?", status).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

func (r *AssignmentRepo) UpdateDueDate(ctx context.Context, id uuid.UUID, dueDate *time.Time) error {
    q := r.db.NewUpdate().Model((*model.Assignment)(nil)).Where("id = ?", id)
    if dueDate != nil {
        q = q.Set("due_date = ?", *dueDate)
    } else {
        q = q.Set("due_date = NULL")
    }
    _, err := q.Exec(ctx)
    return err
}

func (r *AssignmentRepo) Reassign(ctx context.Context, id uuid.UUID, assignedTo, teamID *uuid.UUID) error {
    q := r.db.NewUpdate().
        Model((*model.Assignment)(nil)).
        Where("id = ?", id)
    if assignedTo != nil {
        q = q.Set("assigned_to = ?", *assignedTo).Set("team_id = NULL")
    } else if teamID != nil {
        q = q.Set("team_id = ?", *teamID).Set("assigned_to = NULL")
    }
    _, err := q.Exec(ctx)
    return err
}

func (r *AssignmentRepo) Delete(ctx context.Context, id uuid.UUID) error {
    _, err := r.db.NewDelete().
        Model((*model.Assignment)(nil)).
        Where("id = ?", id).
        Exec(ctx)
    return err
}

func (r *AssignmentRepo) CountNewSince(ctx context.Context, projectID, userID uuid.UUID, since time.Time) (int, error) {
    return r.db.NewSelect().
        Model((*model.Assignment)(nil)).
        Where("project_id = ?", projectID).
        Where(`(assigned_to = ? OR team_id IN (SELECT team_id FROM team_members WHERE user_id = ?))`, userID, userID).
        Where("created_at > ?", since).
        Count(ctx)
}

// GetProgress computes detailed progress stats for an assignment.
func (r *AssignmentRepo) GetProgress(ctx context.Context, assignmentID uuid.UUID) (*model.AssignmentProgress, error) {
    a, err := r.FindByID(ctx, assignmentID)
    if err != nil {
        return nil, err
    }

    type row struct {
        Status string
        Count  int
    }
    var rows []row
    err = r.db.NewSelect().
        TableExpr("features").
        ColumnExpr("status, COUNT(*) AS count").
        Where("assignment_id = ?", assignmentID).
        GroupExpr("status").
        Scan(ctx, &rows)
    if err != nil {
        return nil, err
    }

    progress := &model.AssignmentProgress{
        AssignmentID:   assignmentID,
        Target:         a.TargetCount,
        ComputedStatus: a.ComputedStatus(),
        IsOverdue:      a.ComputedStatus() == "overdue",
    }
    for _, r := range rows {
        switch r.Status {
        case "submitted":
            progress.Submitted += r.Count
        case "approved":
            progress.Approved += r.Count
        case "rejected":
            progress.Rejected += r.Count
        case "under_review":
            progress.UnderReview += r.Count
        }
    }
    totalCollected := progress.Submitted + progress.Approved + progress.Rejected + progress.UnderReview
    if progress.Target > 0 {
        progress.CompletionPct = float64(totalCollected) / float64(progress.Target) * 100
        if progress.CompletionPct > 100 {
            progress.CompletionPct = 100
        }
    }

    // By worker
    type workerRow struct {
        UserID    uuid.UUID `bun:"user_id"`
        Email     string    `bun:"email"`
        FullName  string    `bun:"full_name"`
        Status    string    `bun:"status"`
        Count     int       `bun:"count"`
    }
    var workerRows []workerRow
    err = r.db.NewSelect().
        TableExpr("features AS f").
        ColumnExpr("f.collected_by AS user_id, u.email, u.full_name, f.status, COUNT(*) AS count").
        Join("LEFT JOIN user_profiles AS u ON u.id = f.collected_by").
        Where("f.assignment_id = ?", assignmentID).
        GroupExpr("f.collected_by, u.email, u.full_name, f.status").
        Scan(ctx, &workerRows)
    if err != nil {
        return nil, err
    }

    byUser := map[uuid.UUID]*model.WorkerProgress{}
    for _, wr := range workerRows {
        wp, ok := byUser[wr.UserID]
        if !ok {
            wp = &model.WorkerProgress{
                UserID:   wr.UserID,
                Email:    wr.Email,
                FullName: wr.FullName,
            }
            byUser[wr.UserID] = wp
        }
        switch wr.Status {
        case "submitted":
            wp.Submitted += wr.Count
        case "approved":
            wp.Approved += wr.Count
        case "rejected":
            wp.Rejected += wr.Count
        }
    }
    for _, wp := range byUser {
        progress.ByWorker = append(progress.ByWorker, *wp)
    }

    // Last activity
    var lastAct *time.Time
    err = r.db.NewSelect().
        TableExpr("features").
        ColumnExpr("MAX(collected_at)").
        Where("assignment_id = ?", assignmentID).
        Scan(ctx, &lastAct)
    if err == nil && lastAct != nil {
        progress.LastActivityAt = lastAct
    }

    return progress, nil
}