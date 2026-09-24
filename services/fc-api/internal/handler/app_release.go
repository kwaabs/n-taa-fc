package handler

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
)

const androidReleaseManifestKey = "public/releases/android/manifest.json"

// AndroidReleaseManifest is stored at public/releases/android/manifest.json on RustFS.
type AndroidReleaseManifest struct {
	Platform    string `json:"platform"`
	VersionName string `json:"versionName"`
	VersionCode int    `json:"versionCode"`
	SHA256      string `json:"sha256"`
	SizeBytes   int64  `json:"sizeBytes"`
	ReleasedAt  string `json:"releasedAt"`
	DownloadURL string `json:"downloadUrl"`
}

type AppReleaseHandler struct {
	cfg    *config.Config
	s3     *minio.Client
	bucket string
}

func NewAppReleaseHandler(cfg *config.Config) (*AppReleaseHandler, error) {
	endpoint := strings.TrimPrefix(strings.TrimPrefix(cfg.S3Endpoint, "http://"), "https://")
	useSSL := strings.HasPrefix(cfg.S3Endpoint, "https://")
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.S3AccessKey, cfg.S3SecretKey, ""),
		Secure: useSSL,
		Region: "us-east-1",
	})
	if err != nil {
		return nil, err
	}
	return &AppReleaseHandler{cfg: cfg, s3: client, bucket: cfg.S3Bucket}, nil
}

// LatestAndroid serves GET /api/v1/app/android/latest (unauthenticated).
func (h *AppReleaseHandler) LatestAndroid(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	manifest, err := h.readManifest(ctx)
	if err != nil {
		if minio.ToErrorResponse(err).Code == "NoSuchKey" {
			RespondError(w, http.StatusNotFound, "NO_RELEASE", "no Android release published yet")
			return
		}
		RespondError(w, http.StatusInternalServerError, "S3_ERROR", err.Error())
		return
	}

	// Prefer live public endpoint in case manifest was uploaded with a stale host.
	if h.cfg.S3PublicEndpoint != "" {
		manifest.DownloadURL = strings.TrimRight(h.cfg.S3PublicEndpoint, "/") + "/" +
			h.bucket + "/public/releases/android/latest.apk"
	}

	RespondJSON(w, http.StatusOK, manifest)
}

func (h *AppReleaseHandler) readManifest(ctx context.Context) (*AndroidReleaseManifest, error) {
	obj, err := h.s3.GetObject(ctx, h.bucket, androidReleaseManifestKey, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	defer obj.Close()

	// Stat first so missing keys surface as NoSuchKey (GetObject is lazy).
	if _, err := obj.Stat(); err != nil {
		return nil, err
	}

	body, err := io.ReadAll(obj)
	if err != nil {
		return nil, err
	}

	var manifest AndroidReleaseManifest
	if err := json.Unmarshal(body, &manifest); err != nil {
		return nil, err
	}
	return &manifest, nil
}
