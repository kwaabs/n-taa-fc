package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type AttachmentService struct {
    cfg         *config.Config
    repo        *repository.AttachmentRepo
    featureRepo *repository.FeatureRepo
    accessSvc   *AccessService

    // backend -> RustFS direct operations
    s3Internal *minio.Client

    // presigned URLs returned to mobile/web
    s3PublicSigner *minio.Client
}

func NewAttachmentService(
    cfg *config.Config,
    repo *repository.AttachmentRepo,
    featureRepo *repository.FeatureRepo,
    accessSvc *AccessService,
) (*AttachmentService, error) {
    internalClient, err := newS3Client(
        cfg.S3Endpoint,
        cfg.S3AccessKey,
        cfg.S3SecretKey,
    )
    if err != nil {
        return nil, fmt.Errorf("init internal s3 client: %w", err)
    }

    publicSigner, err := newS3Client(
        cfg.S3PublicEndpoint,
        cfg.S3AccessKey,
        cfg.S3SecretKey,
    )
    if err != nil {
        return nil, fmt.Errorf("init public signer s3 client: %w", err)
    }

    return &AttachmentService{
        cfg:            cfg,
        repo:           repo,
        featureRepo:    featureRepo,
        accessSvc:      accessSvc,
        s3Internal:     internalClient,
        s3PublicSigner: publicSigner,
    }, nil
}

// ── Inputs ──────────────────────────────────────────────

type CreateAttachmentInput struct {
	ProjectID uuid.UUID
	FeatureID *uuid.UUID // nullable: file may exist before the feature
	ClientID  uuid.UUID  // mobile-generated, idempotent
	FieldID   string
	Kind      string
	MimeType  string
	SizeBytes int64
}

type CreateAttachmentResult struct {
	Attachment *model.FeatureAttachment `json:"attachment"`
	UploadURL  string                   `json:"upload_url"`
	ExpiresAt  time.Time                `json:"expires_at"`
}

func (s *AttachmentService) requireAccess(ctx context.Context, projectID, userID uuid.UUID) error {
	ok, err := s.accessSvc.CanAccess(ctx, userID, projectID)
	if err != nil || !ok {
		return fmt.Errorf("access denied: not a project member")
	}
	return nil
}

// ── Create + pre-signed PUT URL ─────────────────────────

func (s *AttachmentService) Create(ctx context.Context, userID uuid.UUID, in CreateAttachmentInput) (*CreateAttachmentResult, error) {
	// Permission — direct membership OR team assigned to project
	if err := s.requireAccess(ctx, in.ProjectID, userID); err != nil {
		return nil, err
	}

	// Validate
	if !model.ValidAttachmentKinds[in.Kind] {
		return nil, fmt.Errorf("invalid attachment kind: %s", in.Kind)
	}
	if in.FieldID == "" {
		return nil, fmt.Errorf("field_id is required")
	}
	if in.SizeBytes <= 0 {
		return nil, fmt.Errorf("size_bytes must be > 0")
	}
	maxSize := model.MaxSizeByKind[in.Kind]
	if maxSize > 0 && in.SizeBytes > maxSize {
		return nil, fmt.Errorf("file too large for kind %s (max %d bytes)", in.Kind, maxSize)
	}

	// Idempotency: if a row exists for this client_id, return it (regen URL if still pending)
	if existing, err := s.repo.FindByClientID(ctx, in.ClientID); err == nil && existing != nil && existing.ID != uuid.Nil {
		if existing.Status == "uploaded" {
			return &CreateAttachmentResult{Attachment: existing}, nil
		}
		// still pending — regen presigned URL
		url, expiry, err := s.presignPut(ctx, existing.StorageKey, in.MimeType)
		if err != nil {
			return nil, err
		}
		return &CreateAttachmentResult{
			Attachment: existing,
			UploadURL:  url,
			ExpiresAt:  expiry,
		}, nil
	}

	// Choose extension from mime_type (best-effort)
	ext := extFromMime(in.MimeType, in.Kind)

	// Storage key layout:
	//   attachments/{project_id}/{feature_id-or-pending}/{attachment_id}.{ext}
	attID := uuid.New()
	featurePart := "pending"
	if in.FeatureID != nil {
		featurePart = in.FeatureID.String()
	}
	storageKey := fmt.Sprintf("attachments/%s/%s/%s.%s",
		in.ProjectID.String(), featurePart, attID.String(), ext)

	att := &model.FeatureAttachment{
		ID:         attID,
		ProjectID:  in.ProjectID,
		FeatureID:  in.FeatureID,
		ClientID:   in.ClientID,
		FieldID:    in.FieldID,
		Kind:       in.Kind,
		StorageKey: storageKey,
		MimeType:   in.MimeType,
		SizeBytes:  in.SizeBytes,
		Status:     "pending_upload",
	}
	if err := s.repo.Create(ctx, att); err != nil {
		return nil, fmt.Errorf("create attachment record: %w", err)
	}

	// Generate pre-signed PUT URL (1 hour validity)
	url, expiry, err := s.presignPut(ctx, storageKey, in.MimeType)
	if err != nil {
		return nil, fmt.Errorf("presign upload url: %w", err)
	}

	return &CreateAttachmentResult{
		Attachment: att,
		UploadURL:  url,
		ExpiresAt:  expiry,
	}, nil
}

// ── Confirm upload ──────────────────────────────────────

func (s *AttachmentService) Confirm(ctx context.Context, attachmentID, userID uuid.UUID) (*model.FeatureAttachment, error) {
    att, err := s.repo.FindByID(ctx, attachmentID)
    if err != nil {
        return nil, fmt.Errorf("attachment not found")
    }
    if err := s.requireAccess(ctx, att.ProjectID, userID); err != nil {
        return nil, fmt.Errorf("access denied")
    }

    statCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()

    stat, err := s.s3Internal.StatObject(
        statCtx,
        s.cfg.S3Bucket,
        att.StorageKey,
        minio.StatObjectOptions{},
    )
    if err != nil {
        _ = s.repo.MarkFailed(ctx, attachmentID)
        return nil, fmt.Errorf("object not found in storage: %w", err)
    }

    if err := s.repo.MarkUploaded(ctx, attachmentID, userID, stat.Size); err != nil {
        return nil, fmt.Errorf("mark uploaded: %w", err)
    }

    return s.repo.FindByID(ctx, attachmentID)
}

// ── Get (with pre-signed download URL) ──────────────────

type AttachmentView struct {
	Attachment  *model.FeatureAttachment `json:"attachment"`
	DownloadURL string                   `json:"download_url"`
	ExpiresAt   time.Time                `json:"expires_at"`
}

func (s *AttachmentService) Get(ctx context.Context, attachmentID, userID uuid.UUID) (*AttachmentView, error) {
	att, err := s.repo.FindByID(ctx, attachmentID)
	if err != nil {
		return nil, fmt.Errorf("attachment not found")
	}
	if err := s.requireAccess(ctx, att.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied")
	}
	if att.Status != "uploaded" {
		return &AttachmentView{Attachment: att}, nil
	}
	url, expiry, err := s.presignGet(ctx, att.StorageKey)
	if err != nil {
		return nil, err
	}
	return &AttachmentView{
		Attachment:  att,
		DownloadURL: url,
		ExpiresAt:   expiry,
	}, nil
}

// ── List per feature ────────────────────────────────────

func (s *AttachmentService) ListByFeature(ctx context.Context, featureID, userID uuid.UUID) ([]AttachmentView, error) {
	feature, err := s.featureRepo.FindByID(ctx, featureID)
	if err != nil {
		return nil, fmt.Errorf("feature not found")
	}
	if err := s.requireAccess(ctx, feature.ProjectID, userID); err != nil {
		return nil, fmt.Errorf("access denied")
	}
	attachments, err := s.repo.ListByFeature(ctx, featureID)
	if err != nil {
		return nil, err
	}
	views := make([]AttachmentView, 0, len(attachments))
	for i := range attachments {
		att := attachments[i]
		view := AttachmentView{Attachment: &att}
		if att.Status == "uploaded" {
			if url, expiry, err := s.presignGet(ctx, att.StorageKey); err == nil {
				view.DownloadURL = url
				view.ExpiresAt = expiry
			}
		}
		views = append(views, view)
	}
	return views, nil
}

// ── Delete ──────────────────────────────────────────────

func (s *AttachmentService) Delete(ctx context.Context, attachmentID, userID uuid.UUID) error {
	att, err := s.repo.FindByID(ctx, attachmentID)
	if err != nil {
		return fmt.Errorf("attachment not found")
	}
	if err := s.requireAccess(ctx, att.ProjectID, userID); err != nil {
		return fmt.Errorf("access denied: admin or supervisor required")
	}
	ok, err := s.accessSvc.HasMinRole(ctx, userID, "supervisor")
	if err != nil || !ok {
		return fmt.Errorf("access denied: admin or supervisor required")
	}

	// Remove from S3 (best-effort)
	_ = s.s3Internal.RemoveObject(ctx, s.cfg.S3Bucket, att.StorageKey, minio.RemoveObjectOptions{})
	if att.ThumbKey != "" {
		_ = s.s3Internal.RemoveObject(ctx, s.cfg.S3Bucket, att.ThumbKey, minio.RemoveObjectOptions{})
	}

	return s.repo.Delete(ctx, attachmentID)
}

// ── Link to feature (called by sync push) ───────────────

func (s *AttachmentService) LinkToFeature(ctx context.Context, clientIDs []uuid.UUID, featureID uuid.UUID) error {
	return s.repo.LinkToFeature(ctx, clientIDs, featureID)
}

// ── Helpers ─────────────────────────────────────────────

func (s *AttachmentService) presignPut(ctx context.Context, key, contentType string) (string, time.Time, error) {
    expiry := 1 * time.Hour
    url, err := s.s3PublicSigner.PresignedPutObject(ctx, s.cfg.S3Bucket, key, expiry)
    if err != nil {
        return "", time.Time{}, err
    }
    _ = contentType
    return url.String(), time.Now().Add(expiry), nil
}

func (s *AttachmentService) presignGet(ctx context.Context, key string) (string, time.Time, error) {
    expiry := 1 * time.Hour
    url, err := s.s3PublicSigner.PresignedGetObject(ctx, s.cfg.S3Bucket, key, expiry, nil)
    if err != nil {
        return "", time.Time{}, err
    }
    return url.String(), time.Now().Add(expiry), nil
}

func extFromMime(mime, kind string) string {
	switch mime {
	case "image/jpeg":
		return "jpg"
	case "image/png":
		return "png"
	case "image/webp":
		return "webp"
	case "image/gif":
		return "gif"
	case "audio/mpeg":
		return "mp3"
	case "audio/mp4", "audio/m4a", "audio/x-m4a":
		return "m4a"
	case "audio/wav", "audio/x-wav":
		return "wav"
	case "audio/ogg":
		return "ogg"
	case "video/mp4":
		return "mp4"
	case "video/webm":
		return "webm"
	case "application/pdf":
		return "pdf"
	}
	// Fallback by kind
	switch kind {
	case "photo":
		return "jpg"
	case "audio":
		return "m4a"
	case "video":
		return "mp4"
	case "signature":
		return "png"
	case "barcode_image":
		return "png"
	}
	return "bin"
}


func newS3Client(endpointURL, accessKey, secretKey string) (*minio.Client, error) {
    endpoint := strings.TrimPrefix(strings.TrimPrefix(endpointURL, "http://"), "https://")
    useSSL := strings.HasPrefix(endpointURL, "https://")

    return minio.New(endpoint, &minio.Options{
        Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
        Secure: useSSL,
        Region: "us-east-1", // avoid bucket-region lookup timeout
    })
}