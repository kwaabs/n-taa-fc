package handler

import (
    "bytes"
    "context"
    "fmt"
    "io"
    "net/http"
    "strings"

    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"
    "github.com/minio/minio-go/v7"
    "github.com/minio/minio-go/v7/pkg/credentials"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/middleware"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type IconHandler struct {
    cfg        *config.Config
    memberRepo *repository.MemberRepo
    layerRepo  *repository.LayerRepo
}

func NewIconHandler(cfg *config.Config, memberRepo *repository.MemberRepo, layerRepo *repository.LayerRepo) *IconHandler {
    return &IconHandler{cfg: cfg, memberRepo: memberRepo, layerRepo: layerRepo}
}

// UploadIcon accepts an SVG file and stores it in RustFS.
// Returns: { icon_id, url } — the icon_id is used as "custom:<id>" in style.
func (h *IconHandler) UploadIcon(w http.ResponseWriter, r *http.Request) {
    projectID, err := uuid.Parse(chi.URLParam(r, "projectID"))
    if err != nil {
        RespondError(w, http.StatusBadRequest, "INVALID_ID", "invalid project ID")
        return
    }

    userID := middleware.GetUserID(r.Context())
    member, err := h.memberRepo.FindByProjectAndUser(r.Context(), projectID, userID)
    if err != nil || (member.Role != "admin" && member.Role != "supervisor") {
        RespondError(w, http.StatusForbidden, "FORBIDDEN", "admin or supervisor role required")
        return
    }

    if err := r.ParseMultipartForm(2 << 20); err != nil { // 2 MB limit
        RespondError(w, http.StatusBadRequest, "PARSE_FAILED", "could not parse upload")
        return
    }

    file, header, err := r.FormFile("file")
    if err != nil {
        RespondError(w, http.StatusBadRequest, "NO_FILE", "file upload missing")
        return
    }
    defer file.Close()

    if !strings.HasSuffix(strings.ToLower(header.Filename), ".svg") {
        RespondError(w, http.StatusBadRequest, "INVALID_FORMAT", "only .svg files are accepted")
        return
    }

    content, err := io.ReadAll(file)
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "READ_FAILED", err.Error())
        return
    }

    if !bytes.Contains(content, []byte("<svg")) {
        RespondError(w, http.StatusBadRequest, "INVALID_SVG", "file content does not appear to be SVG")
        return
    }

    // Generate a unique ID and store
    iconID := uuid.New().String()
    objectKey := fmt.Sprintf("icons/%s/%s.svg", projectID, iconID)

    endpoint := strings.TrimPrefix(strings.TrimPrefix(h.cfg.S3Endpoint, "http://"), "https://")
    useSSL := strings.HasPrefix(h.cfg.S3Endpoint, "https://")

    client, err := minio.New(endpoint, &minio.Options{
        Creds:  credentials.NewStaticV4(h.cfg.S3AccessKey, h.cfg.S3SecretKey, ""),
        Secure: useSSL,
    })
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "S3_INIT", err.Error())
        return
    }

    ctx := context.Background()
    _, err = client.PutObject(ctx, h.cfg.S3Bucket, objectKey, bytes.NewReader(content), int64(len(content)),
        minio.PutObjectOptions{ContentType: "image/svg+xml"})
    if err != nil {
        RespondError(w, http.StatusInternalServerError, "UPLOAD_FAILED", err.Error())
        return
    }

    publicURL := fmt.Sprintf("%s/%s/%s", h.cfg.S3Endpoint, h.cfg.S3Bucket, objectKey)

    RespondJSON(w, http.StatusOK, map[string]string{
        "icon_id":   iconID,
        "icon_ref":  "custom:" + iconID,
        "url":       publicURL,
        "object_key": objectKey,
    })
}