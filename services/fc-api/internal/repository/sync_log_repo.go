package repository

import (
    "context"
    "time"

    "github.com/google/uuid"
    "github.com/uptrace/bun"
)

type SyncLogRepo struct {
    db *bun.DB
}

func NewSyncLogRepo(db *bun.DB) *SyncLogRepo {
    return &SyncLogRepo{db: db}
}

// StartRun inserts a new sync_log row in 'started' state and returns its id.
func (r *SyncLogRepo) StartRun(
    ctx context.Context,
    userID, projectID uuid.UUID,
    direction, trigger string,
) (uuid.UUID, error) {
    id := uuid.New()
    _, err := r.db.NewRaw(`
        INSERT INTO sync_log
            (id, user_id, project_id, direction, trigger, status, started_at)
        VALUES (?, ?, ?, ?, ?, 'started', ?)
    `, id, userID, projectID, direction, trigger, time.Now()).Exec(ctx)
    return id, err
}

// CompleteRun updates a sync_log row with final stats.
func (r *SyncLogRepo) CompleteRun(
    ctx context.Context,
    id uuid.UUID,
    status string,
    featAttempted, featSucceeded, featFailed int,
    attAttempted, attSucceeded, attFailed int,
    errorMessage *string,
) error {
    _, err := r.db.NewRaw(`
        UPDATE sync_log
        SET status                = ?,
            features_attempted    = ?,
            features_succeeded    = ?,
            features_failed       = ?,
            attachments_attempted = ?,
            attachments_succeeded = ?,
            attachments_failed    = ?,
            ended_at              = ?,
            error_message         = ?
        WHERE id = ?
    `,
        status,
        featAttempted, featSucceeded, featFailed,
        attAttempted, attSucceeded, attFailed,
        time.Now(),
        errorMessage,
        id,
    ).Exec(ctx)
    return err
}

// LogError inserts a row into sync_errors.
func (r *SyncLogRepo) LogError(
    ctx context.Context,
    syncLogID uuid.UUID,
    featureClientID *uuid.UUID,
    attachmentClientID *uuid.UUID,
    errorCode, errorMessage string,
    httpStatus *int,
) error {
    _, err := r.db.NewRaw(`
        INSERT INTO sync_errors
            (id, sync_log_id, feature_id, attachment_id,
             error_code, error_message, http_status, occurred_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `,
        uuid.New(),
        syncLogID,
        featureClientID,
        attachmentClientID,
        errorCode,
        errorMessage,
        httpStatus,
        time.Now(),
    ).Exec(ctx)
    return err
}