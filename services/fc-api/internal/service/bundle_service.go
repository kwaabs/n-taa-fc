package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/config"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/cache"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type BundleService struct {
	cfg             *config.Config
	cache           cache.Cache
	bundleCacheRepo *repository.BundleCacheRepo
	importJobRepo   *repository.ImportJobRepo
	accessSvc       *AccessService
	hashSvc         *BundleHashService
	pool            *BundleWorkerPool
	s3client        *minio.Client
}

func NewBundleService(
	cfg *config.Config,
	cacheClient cache.Cache,
	bundleCacheRepo *repository.BundleCacheRepo,
	importJobRepo *repository.ImportJobRepo,
	accessSvc *AccessService,
	hashSvc *BundleHashService,
) (*BundleService, error) {
	endpoint := strings.TrimPrefix(strings.TrimPrefix(cfg.S3PublicEndpoint, "http://"), "https://")
	useSSL := strings.HasPrefix(cfg.S3PublicEndpoint, "https://")
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.S3AccessKey, cfg.S3SecretKey, ""),
		Secure: useSSL,
		Region: "us-east-1", // ← ADD THIS
	})
	if err != nil {
		return nil, fmt.Errorf("init minio: %w", err)
	}

	return &BundleService{
		cfg:             cfg,
		cache:           cacheClient,
		bundleCacheRepo: bundleCacheRepo,
		importJobRepo:   importJobRepo,
		accessSvc:       accessSvc,
		hashSvc:         hashSvc,
		s3client:        client,
	}, nil
}

// SetPool is called after BundleWorkerPool is initialized to break the circular dep.
func (s *BundleService) SetPool(pool *BundleWorkerPool) {
	s.pool = pool
}

// ── Request types ──────────────────────────────────────

type BundleRequestResult struct {
	// Status one of: "ready", "queued", "running"
	Status      string `json:"status"`
	ContentHash string `json:"content_hash"`

	// When status=ready
	DownloadURL string              `json:"download_url,omitempty"`
	Filename    string              `json:"filename,omitempty"`
	SizeBytes   int64               `json:"size_bytes,omitempty"`
	Counts      *model.BundleCounts `json:"counts,omitempty"`
	Warnings    []string            `json:"warnings,omitempty"`
	ExpiresAt   *time.Time          `json:"expires_at,omitempty"`

	// When status=queued/running
	JobID *uuid.UUID `json:"job_id,omitempty"`
}

// ── Main entry point ───────────────────────────────────

// RequestBundle is the main flow:
//  1. Check Valkey for a cached entry — instant return
//  2. Compute content hash from DB signals
//  3. Look up bundle_cache table by (project, user, ref_flag, content_hash)
//     - Hit: presign URL, warm Valkey, return ready
//     - Miss: continue
//  4. Check for an active job for this user+project+ref_flag — dedup
//  5. Enqueue a new job
func (s *BundleService) RequestBundle(
	ctx context.Context,
	projectID, userID uuid.UUID,
	includeReferenceData bool,
) (*BundleRequestResult, error) {

	// Permission check — direct membership OR team assigned to project
	ok, err := s.accessSvc.CanAccess(ctx, userID, projectID)
	if err != nil || !ok {
		return nil, fmt.Errorf("access denied: not a project member")
	}

	// AOI Phase 1: Bundles are only downloadable for published projects.
	// Draft projects are admin sandboxes — field workers can't consume them.
	var projectStatus string
	if err := s.bundleCacheRepo.GetProjectStatus(ctx, projectID, &projectStatus); err != nil {
		return nil, fmt.Errorf("project not found")
	}

	if projectStatus != "active" {
		return nil, fmt.Errorf("project must be dispatched before bundles can be downloaded (current status: %s)", projectStatus)
	}

	// 1. Hot cache check (Valkey)
	hot := s.checkHotCache(ctx, projectID, userID, includeReferenceData)
	if hot != nil {
		return hot, nil
	}

	// 2. Compute current content hash
	contentHash, err := s.hashSvc.Compute(ctx, projectID, userID, includeReferenceData)
	if err != nil {
		return nil, fmt.Errorf("compute content hash: %w", err)
	}

	// 3. Look up bundle_cache table
	entry, err := s.bundleCacheRepo.FindMatch(ctx, projectID, userID, includeReferenceData, contentHash)
	if err == nil && entry != nil && entry.ID != uuid.Nil {
		// Cache hit. Presign URL, warm hot cache, return ready.
		return s.serveFromCache(ctx, entry)
	}

	// 4. Dedup: is there already an active job for this exact request?
	existingJobID := s.findOrLockActiveJob(ctx, projectID, userID, includeReferenceData, contentHash)
	if existingJobID != nil {
		status := s.readJobStatus(ctx, *existingJobID)
		// Only reuse in-flight jobs. Failed/success locks must not block retries
		// (a failed SQL job previously stuck here for the full lock TTL).
		if status == "pending" || status == "queued" || status == "running" {
			return &BundleRequestResult{
				Status:      status,
				ContentHash: contentHash,
				JobID:       existingJobID,
			}, nil
		}
		s.releaseDedupLock(ctx, projectID, userID, includeReferenceData, contentHash)
		// Re-acquire so we own the lock for enqueue.
		if again := s.findOrLockActiveJob(ctx, projectID, userID, includeReferenceData, contentHash); again != nil {
			status = s.readJobStatus(ctx, *again)
			if status == "pending" || status == "queued" || status == "running" {
				return &BundleRequestResult{
					Status:      status,
					ContentHash: contentHash,
					JobID:       again,
				}, nil
			}
			s.releaseDedupLock(ctx, projectID, userID, includeReferenceData, contentHash)
			_ = s.findOrLockActiveJob(ctx, projectID, userID, includeReferenceData, contentHash)
		}
	}

	// 5. Enqueue new job
	jobID, err := s.enqueueJob(ctx, projectID, userID, includeReferenceData, contentHash)
	if err != nil {
		// Lock is held but we couldn't enqueue — release the lock
		s.releaseDedupLock(ctx, projectID, userID, includeReferenceData, contentHash)
		return nil, fmt.Errorf("enqueue job: %w", err)
	}

	// Store job_id under the dedup lock so subsequent requests find it
	s.storeJobUnderLock(ctx, projectID, userID, includeReferenceData, contentHash, jobID)

	return &BundleRequestResult{
		Status:      "queued",
		ContentHash: contentHash,
		JobID:       &jobID,
	}, nil
}

// RequestLayerReferencePack builds or returns a cached ZIP with one layer's
// reference GeoJSON (+ optional mbtiles). Used by efficient-sync hybrid.
func (s *BundleService) RequestLayerReferencePack(
	ctx context.Context,
	projectID, layerID, userID uuid.UUID,
) (*BundleRequestResult, error) {
	ok, err := s.accessSvc.CanAccess(ctx, userID, projectID)
	if err != nil || !ok {
		return nil, fmt.Errorf("access denied: not a project member")
	}

	var projectStatus string
	if err := s.bundleCacheRepo.GetProjectStatus(ctx, projectID, &projectStatus); err != nil {
		return nil, fmt.Errorf("project not found")
	}
	if projectStatus != "active" {
		return nil, fmt.Errorf("project must be dispatched before packs can be downloaded (current status: %s)", projectStatus)
	}

	if hot := s.checkLayerHotCache(ctx, projectID, layerID); hot != nil {
		return hot, nil
	}

	contentHash, err := s.hashSvc.ComputeLayerRef(ctx, projectID, layerID)
	if err != nil {
		return nil, fmt.Errorf("compute layer hash: %w", err)
	}

	// Layer packs are project-scoped content; still keyed by requesting user in
	// bundle_cache (FK). Hash uniqueness prevents collision with full bundles.
	entry, err := s.bundleCacheRepo.FindMatch(ctx, projectID, userID, true, contentHash)
	if err == nil && entry != nil && entry.ID != uuid.Nil {
		return s.serveLayerFromCache(ctx, projectID, layerID, entry)
	}

	existingJobID := s.findOrLockActiveJob(ctx, projectID, userID, true, contentHash)
	if existingJobID != nil {
		status := s.readJobStatus(ctx, *existingJobID)
		if status == "pending" || status == "queued" || status == "running" {
			return &BundleRequestResult{
				Status:      status,
				ContentHash: contentHash,
				JobID:       existingJobID,
			}, nil
		}
		s.releaseDedupLock(ctx, projectID, userID, true, contentHash)
		if again := s.findOrLockActiveJob(ctx, projectID, userID, true, contentHash); again != nil {
			status = s.readJobStatus(ctx, *again)
			if status == "pending" || status == "queued" || status == "running" {
				return &BundleRequestResult{
					Status:      status,
					ContentHash: contentHash,
					JobID:       again,
				}, nil
			}
			s.releaseDedupLock(ctx, projectID, userID, true, contentHash)
			_ = s.findOrLockActiveJob(ctx, projectID, userID, true, contentHash)
		}
	}

	jobID, err := s.enqueueLayerRefJob(ctx, projectID, userID, layerID, contentHash)
	if err != nil {
		s.releaseDedupLock(ctx, projectID, userID, true, contentHash)
		return nil, fmt.Errorf("enqueue layer pack: %w", err)
	}
	s.storeJobUnderLock(ctx, projectID, userID, true, contentHash, jobID)

	return &BundleRequestResult{
		Status:      "queued",
		ContentHash: contentHash,
		JobID:       &jobID,
	}, nil
}

// ── Job status polling ────────────────────────────────

type BundleJobView struct {
	JobID    uuid.UUID                `json:"job_id"`
	Status   string                   `json:"status"`
	Progress *model.BundleJobProgress `json:"progress,omitempty"`
	Result   *BundleRequestResult     `json:"result,omitempty"`
	Error    string                   `json:"error,omitempty"`
}

func (s *BundleService) GetJobStatus(ctx context.Context, jobID, userID uuid.UUID) (*BundleJobView, error) {
	// Try Valkey first (hot path during active polling)

	view := s.readJobViewFromCache(ctx, jobID)
	if view != nil && view.Status != "" {
		if !s.canViewJob(ctx, jobID, userID) {
			return nil, fmt.Errorf("access denied")
		}
		if view.Status == "success" && view.Result == nil {
			view.Result = s.buildResultFromJob(ctx, jobID)
		}
		return view, nil
	}

	// Fall back to DB
	job, err := s.importJobRepo.FindByID(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("job not found")
	}
	ok, err := s.accessSvc.CanAccess(ctx, userID, job.ProjectID)
	if err != nil || !ok {
		return nil, fmt.Errorf("access denied")
	}

	v := &BundleJobView{
		JobID:  job.ID,
		Status: job.Status,
		Error:  job.ErrorMessage,
	}

	if len(job.Progress) > 0 {
		var p model.BundleJobProgress
		if json.Unmarshal(job.Progress, &p) == nil {
			v.Progress = &p
		}
	}

	if job.Status == "success" {
		v.Result = s.buildResultFromJob(ctx, jobID)
	}

	return v, nil
}

// buildResultFromJob loads job result + corresponding cache entry, returns a presigned URL.
func (s *BundleService) buildResultFromJob(ctx context.Context, jobID uuid.UUID) *BundleRequestResult {
	job, err := s.importJobRepo.FindByID(ctx, jobID)
	if err != nil || len(job.Result) == 0 {
		return nil
	}

	var r model.BundleJobResult
	if err := json.Unmarshal(job.Result, &r); err != nil {
		return nil
	}

	// Parse job config to get include_reference_data flag
	var cfg bundleJobConfig
	_ = json.Unmarshal(job.Config, &cfg)

	// Try to find the cache entry (and refresh accessed time)
	entry, err := s.bundleCacheRepo.FindMatch(ctx, job.ProjectID, job.CreatedBy, cfg.IncludeReferenceData, r.ContentHash)
	if err == nil && entry != nil && entry.ID != uuid.Nil {
		if cfg.PackKind == "layer_ref" && cfg.LayerID != uuid.Nil {
			ready, err := s.serveLayerFromCache(ctx, job.ProjectID, cfg.LayerID, entry)
			if err == nil {
				return ready
			}
		} else {
			ready, err := s.serveFromCache(ctx, entry)
			if err == nil {
				return ready
			}
		}
	}

	// Fallback: presign directly from the result's storage_key
	url, expiry, err := s.presignGet(ctx, r.StorageKey)
	if err != nil {
		return nil
	}
	return &BundleRequestResult{
		Status:      "ready",
		ContentHash: r.ContentHash,
		DownloadURL: url,
		Filename:    r.Filename,
		SizeBytes:   r.SizeBytes,
		Counts:      &r.Counts,
		Warnings:    r.Warnings,
		ExpiresAt:   &expiry,
	}
}

// ── Helpers — Hot cache (Valkey) ──────────────────────

func (s *BundleService) hotCacheKey(projectID, userID uuid.UUID, includeRef bool) string {
	return fmt.Sprintf("bundle:cache:%s:%s:%v", projectID, userID, includeRef)
}

type hotCacheEntry struct {
	ContentHash string             `json:"content_hash"`
	StorageKey  string             `json:"storage_key"`
	Filename    string             `json:"filename"`
	SizeBytes   int64              `json:"size_bytes"`
	Counts      model.BundleCounts `json:"counts"`
	Warnings    []string           `json:"warnings"`
	CacheID     uuid.UUID          `json:"cache_id"`
}

func (s *BundleService) checkHotCache(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool,
) *BundleRequestResult {
	key := s.hotCacheKey(projectID, userID, includeRef)
	var hot hotCacheEntry
	if err := s.cache.GetJSON(ctx, key, &hot); err != nil {
		return nil
	}
	// Validate by recomputing hash — if hash differs, invalidate
	currentHash, err := s.hashSvc.Compute(ctx, projectID, userID, includeRef)
	if err != nil || currentHash != hot.ContentHash {
		_ = s.cache.Del(ctx, key)
		return nil
	}
	url, expiry, err := s.presignGet(ctx, hot.StorageKey)
	if err != nil {
		_ = s.cache.Del(ctx, key)
		return nil
	}
	// Touch accessed time async
	go s.bundleCacheRepo.TouchAccessed(context.Background(), hot.CacheID)
	return &BundleRequestResult{
		Status:      "ready",
		ContentHash: hot.ContentHash,
		DownloadURL: url,
		Filename:    hot.Filename,
		SizeBytes:   hot.SizeBytes,
		Counts:      &hot.Counts,
		Warnings:    hot.Warnings,
		ExpiresAt:   &expiry,
	}
}

func (s *BundleService) warmHotCache(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool, entry *model.BundleCache,
) {
	var counts model.BundleCounts
	_ = json.Unmarshal(entry.Counts, &counts)
	var warnings []string
	if len(entry.Warnings) > 0 {
		_ = json.Unmarshal(entry.Warnings, &warnings)
	}
	hot := hotCacheEntry{
		ContentHash: entry.ContentHash,
		StorageKey:  entry.StorageKey,
		Filename:    entry.Filename,
		SizeBytes:   entry.SizeBytes,
		Counts:      counts,
		Warnings:    warnings,
		CacheID:     entry.ID,
	}
	_ = s.cache.SetJSON(ctx, s.hotCacheKey(projectID, userID, includeRef), hot, 1*time.Hour)
}

func (s *BundleService) layerHotCacheKey(projectID, layerID uuid.UUID) string {
	return fmt.Sprintf("bundle:cache:layer:%s:%s", projectID, layerID)
}

func (s *BundleService) checkLayerHotCache(
	ctx context.Context, projectID, layerID uuid.UUID,
) *BundleRequestResult {
	key := s.layerHotCacheKey(projectID, layerID)
	var hot hotCacheEntry
	if err := s.cache.GetJSON(ctx, key, &hot); err != nil {
		return nil
	}
	currentHash, err := s.hashSvc.ComputeLayerRef(ctx, projectID, layerID)
	if err != nil || currentHash != hot.ContentHash {
		_ = s.cache.Del(ctx, key)
		return nil
	}
	url, expiry, err := s.presignGet(ctx, hot.StorageKey)
	if err != nil {
		_ = s.cache.Del(ctx, key)
		return nil
	}
	go s.bundleCacheRepo.TouchAccessed(context.Background(), hot.CacheID)
	return &BundleRequestResult{
		Status:      "ready",
		ContentHash: hot.ContentHash,
		DownloadURL: url,
		Filename:    hot.Filename,
		SizeBytes:   hot.SizeBytes,
		Counts:      &hot.Counts,
		Warnings:    hot.Warnings,
		ExpiresAt:   &expiry,
	}
}

func (s *BundleService) warmLayerHotCache(
	ctx context.Context, projectID, layerID uuid.UUID, entry *model.BundleCache,
) {
	var counts model.BundleCounts
	_ = json.Unmarshal(entry.Counts, &counts)
	var warnings []string
	if len(entry.Warnings) > 0 {
		_ = json.Unmarshal(entry.Warnings, &warnings)
	}
	hot := hotCacheEntry{
		ContentHash: entry.ContentHash,
		StorageKey:  entry.StorageKey,
		Filename:    entry.Filename,
		SizeBytes:   entry.SizeBytes,
		Counts:      counts,
		Warnings:    warnings,
		CacheID:     entry.ID,
	}
	_ = s.cache.SetJSON(ctx, s.layerHotCacheKey(projectID, layerID), hot, 1*time.Hour)
}

func (s *BundleService) serveLayerFromCache(
	ctx context.Context, projectID, layerID uuid.UUID, entry *model.BundleCache,
) (*BundleRequestResult, error) {
	url, expiry, err := s.presignGet(ctx, entry.StorageKey)
	if err != nil {
		return nil, fmt.Errorf("presign download: %w", err)
	}
	var counts model.BundleCounts
	_ = json.Unmarshal(entry.Counts, &counts)
	var warnings []string
	if len(entry.Warnings) > 0 {
		_ = json.Unmarshal(entry.Warnings, &warnings)
	}
	s.warmLayerHotCache(ctx, projectID, layerID, entry)
	go s.bundleCacheRepo.TouchAccessed(context.Background(), entry.ID)
	return &BundleRequestResult{
		Status:      "ready",
		ContentHash: entry.ContentHash,
		DownloadURL: url,
		Filename:    entry.Filename,
		SizeBytes:   entry.SizeBytes,
		Counts:      &counts,
		Warnings:    warnings,
		ExpiresAt:   &expiry,
	}, nil
}

func (s *BundleService) serveFromCache(ctx context.Context, entry *model.BundleCache) (*BundleRequestResult, error) {
	url, expiry, err := s.presignGet(ctx, entry.StorageKey)
	if err != nil {
		return nil, fmt.Errorf("presign download: %w", err)
	}

	var counts model.BundleCounts
	_ = json.Unmarshal(entry.Counts, &counts)
	var warnings []string
	if len(entry.Warnings) > 0 {
		_ = json.Unmarshal(entry.Warnings, &warnings)
	}

	s.warmHotCache(ctx, entry.ProjectID, entry.UserID, entry.IncludeReferenceData, entry)
	go s.bundleCacheRepo.TouchAccessed(context.Background(), entry.ID)

	return &BundleRequestResult{
		Status:      "ready",
		ContentHash: entry.ContentHash,
		DownloadURL: url,
		Filename:    entry.Filename,
		SizeBytes:   entry.SizeBytes,
		Counts:      &counts,
		Warnings:    warnings,
		ExpiresAt:   &expiry,
	}, nil
}

// ── Helpers — Dedup lock (Valkey SETNX) ───────────────

func (s *BundleService) dedupLockKey(projectID, userID uuid.UUID, includeRef bool, contentHash string) string {
	return fmt.Sprintf("bundle:lock:%s:%s:%v:%s", projectID, userID, includeRef, contentHash)
}

// findOrLockActiveJob:
//   - Tries to SETNX the lock with placeholder "pending"
//   - If lock already exists, reads its value (could be "pending" or a job_id)
//   - Returns job_id if found, else nil (meaning we acquired the lock)
func (s *BundleService) findOrLockActiveJob(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool, contentHash string,
) *uuid.UUID {
	key := s.dedupLockKey(projectID, userID, includeRef, contentHash)
	acquired, err := s.cache.SetNX(ctx, key, "pending", 5*time.Minute)
	if err != nil || acquired {
		// We hold the lock (or cache error — assume we own it)
		return nil
	}
	// Lock already exists. Read value.
	val, err := s.cache.Get(ctx, key)
	if err != nil || val == "" || val == "pending" {
		return nil // still pending; treat as "we own it" and re-enqueue (rare race)
	}
	jobID, err := uuid.Parse(val)
	if err != nil {
		return nil
	}
	return &jobID
}

func (s *BundleService) storeJobUnderLock(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool, contentHash string, jobID uuid.UUID,
) {
	key := s.dedupLockKey(projectID, userID, includeRef, contentHash)
	_ = s.cache.Set(ctx, key, jobID.String(), 5*time.Minute)
}

func (s *BundleService) releaseDedupLock(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool, contentHash string,
) {
	_ = s.cache.Del(ctx, s.dedupLockKey(projectID, userID, includeRef, contentHash))
}

// ReleaseJobDedupLock clears the generation lock for a finished job so retries
// are not stuck on a terminal (failed/success) job id.
func (s *BundleService) ReleaseJobDedupLock(ctx context.Context, job *model.ImportJob) {
	if job == nil {
		return
	}
	var cfg bundleJobConfig
	_ = json.Unmarshal(job.Config, &cfg)
	if cfg.ContentHash == "" {
		return
	}
	s.releaseDedupLock(ctx, job.ProjectID, job.CreatedBy, cfg.IncludeReferenceData, cfg.ContentHash)
}

// ── Helpers — Job enqueue ─────────────────────────────

type bundleJobConfig struct {
	IncludeReferenceData bool      `json:"include_reference_data"`
	ContentHash          string    `json:"content_hash"`
	PackKind             string    `json:"pack_kind,omitempty"` // ""|"project"|"layer_ref"
	LayerID              uuid.UUID `json:"layer_id,omitempty"`
}

func (s *BundleService) enqueueJob(
	ctx context.Context, projectID, userID uuid.UUID, includeRef bool, contentHash string,
) (uuid.UUID, error) {
	cfgJSON, _ := json.Marshal(bundleJobConfig{
		IncludeReferenceData: includeRef,
		ContentHash:          contentHash,
		PackKind:             "project",
	})
	job := &model.ImportJob{
		ProjectID: projectID,
		JobType:   "bundle_generation",
		Status:    "pending",
		Config:    cfgJSON,
		CreatedBy: userID,
	}
	if err := s.importJobRepo.Create(ctx, job); err != nil {
		return uuid.Nil, err
	}
	if s.pool != nil {
		s.pool.Submit(job)
	}
	return job.ID, nil
}

func (s *BundleService) enqueueLayerRefJob(
	ctx context.Context, projectID, userID, layerID uuid.UUID, contentHash string,
) (uuid.UUID, error) {
	cfgJSON, _ := json.Marshal(bundleJobConfig{
		IncludeReferenceData: true,
		ContentHash:          contentHash,
		PackKind:             "layer_ref",
		LayerID:              layerID,
	})
	job := &model.ImportJob{
		ProjectID: projectID,
		JobType:   "layer_reference_pack",
		Status:    "pending",
		Config:    cfgJSON,
		CreatedBy: userID,
	}
	if err := s.importJobRepo.Create(ctx, job); err != nil {
		return uuid.Nil, err
	}
	if s.pool != nil {
		s.pool.Submit(job)
	}
	return job.ID, nil
}

// ── Helpers — Job status read ─────────────────────────

func (s *BundleService) jobStatusKey(jobID uuid.UUID) string {
	return fmt.Sprintf("bundle:job:%s", jobID)
}

func (s *BundleService) readJobStatus(ctx context.Context, jobID uuid.UUID) string {
	view := s.readJobViewFromCache(ctx, jobID)
	if view != nil {
		return view.Status
	}
	job, err := s.importJobRepo.FindByID(ctx, jobID)
	if err != nil {
		return "unknown"
	}
	return job.Status
}

func (s *BundleService) readJobViewFromCache(ctx context.Context, jobID uuid.UUID) *BundleJobView {
	var v BundleJobView
	if err := s.cache.GetJSON(ctx, s.jobStatusKey(jobID), &v); err != nil {
		return nil
	}
	return &v
}

func (s *BundleService) WriteJobViewToCache(ctx context.Context, view *BundleJobView) {
	_ = s.cache.SetJSON(ctx, s.jobStatusKey(view.JobID), view, 10*time.Minute)
}

func (s *BundleService) canViewJob(ctx context.Context, jobID, userID uuid.UUID) bool {
	job, err := s.importJobRepo.FindByID(ctx, jobID)
	if err != nil {
		return false
	}
	ok, err := s.accessSvc.CanAccess(ctx, userID, job.ProjectID)
	return err == nil && ok
}

// ── Helpers — Presigned URLs ──────────────────────────

func (s *BundleService) presignGet(ctx context.Context, key string) (string, time.Time, error) {
	expiry := 1 * time.Hour
	u, err := s.s3client.PresignedGetObject(ctx, s.cfg.S3Bucket, key, expiry, nil)
	if err != nil {
		return "", time.Time{}, err
	}
	return u.String(), time.Now().Add(expiry), nil
}

// ── Cleanup ───────────────────────────────────────────

// CleanupStale deletes cache entries older than ttl from RustFS and Postgres.
func (s *BundleService) CleanupStale(ctx context.Context, ttl time.Duration) (int, error) {
	cutoff := time.Now().Add(-ttl)
	stale, err := s.bundleCacheRepo.ListStale(ctx, cutoff, 100)
	if err != nil {
		return 0, err
	}
	deleted := 0
	for _, entry := range stale {
		// Best-effort RustFS delete
		_ = s.s3client.RemoveObject(ctx, s.cfg.S3Bucket, entry.StorageKey, minio.RemoveObjectOptions{})
		if err := s.bundleCacheRepo.Delete(ctx, entry.ID); err == nil {
			deleted++
			_ = s.cache.Del(ctx, s.hotCacheKey(entry.ProjectID, entry.UserID, entry.IncludeReferenceData))
		}
	}
	return deleted, errors.New("") // intentionally returning empty error; caller uses count
}

// InvalidateProjectCache wipes hot+cold cache for a project. Called on content change.
func (s *BundleService) InvalidateProjectCache(ctx context.Context, projectID uuid.UUID) {
	_ = s.cache.DelPattern(ctx, fmt.Sprintf("bundle:cache:%s:*", projectID))
	_ = s.cache.DelPattern(ctx, fmt.Sprintf("bundle:lock:%s:*", projectID))
	_ = s.bundleCacheRepo.InvalidateProject(ctx, projectID)
}
