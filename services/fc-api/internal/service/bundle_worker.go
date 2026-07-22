package service

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/uptrace/bun"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/lib/cache"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

// BundleWorkerPool generates bundles from the queue.
type BundleWorkerPool struct {
	db              *bun.DB
	cache           cache.Cache
	bundleSvc       *BundleService
	bundleCacheRepo *repository.BundleCacheRepo
	importJobRepo   *repository.ImportJobRepo
	projectRepo     *repository.ProjectRepo
	formRepo        *repository.FormRepo
	layerRepo       *repository.LayerRepo
	choiceListRepo  *repository.ChoiceListRepo
	assignmentRepo  *repository.AssignmentRepo

	dataSourceRepo *repository.DataSourceRepo // 👈 NEW

	tippecanoeClient *TippecanoeClient // 👈 tile generation sidecar

	s3client *minio.Client
	s3bucket string

	queue       chan *model.ImportJob
	workerCount int
	wg          sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
}

func NewBundleWorkerPool(
	db *bun.DB,
	cacheClient cache.Cache,
	bundleSvc *BundleService,
	bundleCacheRepo *repository.BundleCacheRepo,
	importJobRepo *repository.ImportJobRepo,
	projectRepo *repository.ProjectRepo,
	formRepo *repository.FormRepo,
	layerRepo *repository.LayerRepo,
	choiceListRepo *repository.ChoiceListRepo,
	assignmentRepo *repository.AssignmentRepo,

	dataSourceRepo *repository.DataSourceRepo, // 👈 NEW

	tippecanoeClient *TippecanoeClient, // 👈 NEW: tile generation sidecar

	s3client *minio.Client,
	s3bucket string,
	workerCount int,
) *BundleWorkerPool {
	if workerCount <= 0 {
		workerCount = 4
	}
	ctx, cancel := context.WithCancel(context.Background())
	pool := &BundleWorkerPool{
		db:              db,
		cache:           cacheClient,
		bundleSvc:       bundleSvc,
		bundleCacheRepo: bundleCacheRepo,
		importJobRepo:   importJobRepo,
		projectRepo:     projectRepo,
		formRepo:        formRepo,
		layerRepo:       layerRepo,
		choiceListRepo:  choiceListRepo,
		assignmentRepo:  assignmentRepo,

		dataSourceRepo: dataSourceRepo, // 👈 NEW

		tippecanoeClient: tippecanoeClient, // 👈 NEW

		s3client:    s3client,
		s3bucket:    s3bucket,
		queue:       make(chan *model.ImportJob, 32),
		workerCount: workerCount,
		ctx:         ctx,
		cancel:      cancel,
	}
	for i := 0; i < workerCount; i++ {
		pool.wg.Add(1)
		go pool.worker(i)
	}
	return pool
}

func (p *BundleWorkerPool) Submit(job *model.ImportJob) {
	select {
	case p.queue <- job:
	default:
		slog.Error("bundle worker queue full", "job_id", job.ID)
		_ = p.importJobRepo.MarkFinished(context.Background(), job.ID, "failed", nil, "worker queue full")
	}
}

func (p *BundleWorkerPool) Shutdown() {
	p.cancel()
	close(p.queue)
	p.wg.Wait()
}

func (p *BundleWorkerPool) worker(id int) {
	defer p.wg.Done()
	slog.Info("bundle worker started", "id", id)
	for {
		select {
		case <-p.ctx.Done():
			return
		case job, ok := <-p.queue:
			if !ok {
				return
			}
			p.runJob(job)
		}
	}
}

// ── runJob — main generation flow ──────────────────────

type bundleJobConfigInner struct {
	IncludeReferenceData bool      `json:"include_reference_data"`
	ContentHash          string    `json:"content_hash"`
	PackKind             string    `json:"pack_kind,omitempty"`
	LayerID              uuid.UUID `json:"layer_id,omitempty"`
}

func (p *BundleWorkerPool) runJob(job *model.ImportJob) {
	ctx := p.ctx

	_ = p.importJobRepo.MarkRunning(ctx, job.ID)
	p.publishStatus(ctx, job.ID, "running", &model.BundleJobProgress{Step: "starting", Percent: 0})

	var cfg bundleJobConfigInner
	if err := json.Unmarshal(job.Config, &cfg); err != nil {
		p.finishFailed(ctx, job, "bad config: "+err.Error())
		return
	}

	if cfg.PackKind == "layer_ref" || job.JobType == "layer_reference_pack" {
		p.runLayerRefJob(job, cfg)
		return
	}

	project, err := p.projectRepo.FindByID(ctx, job.ProjectID)
	if err != nil {
		p.finishFailed(ctx, job, "project not found")
		return
	}

	manifest := model.BundleManifest{
		BundleVersion:        "1.0",
		ProjectID:            project.ID,
		ProjectName:          project.Name,
		GeneratedAt:          time.Now(),
		GeneratedBy:          job.CreatedBy,
		IncludeReferenceData: cfg.IncludeReferenceData,
		HasAOI:               len(project.AreaOfInterest) > 0,
		ContentHash:          cfg.ContentHash,
		Warnings:             []string{},
	}

	// Build zip in memory (acceptable for v1; max bundle size guarded by absent AOI)
	var buf bytes.Buffer
	hasher := sha256.New()
	mw := io.MultiWriter(&buf, hasher)
	zw := zip.NewWriter(mw)

	// project.json
	p.progress(ctx, job.ID, "project_meta", 5)
	if err := writeJSON(zw, "project.json", project); err != nil {
		p.finishFailed(ctx, job, "write project: "+err.Error())
		return
	}

	// Forms
	p.progress(ctx, job.ID, "forms", 15)
	publishedFormIDs, formsCount, err := p.writeForms(ctx, zw, job.ProjectID, &manifest)
	if err != nil {
		p.finishFailed(ctx, job, "write forms: "+err.Error())
		return
	}
	manifest.Counts.Forms = formsCount

	// Layers (graceful: form_id nulled if form not published)
	p.progress(ctx, job.ID, "layers", 25)
	publishedLayers, err := p.writeLayers(ctx, zw, job.ProjectID, publishedFormIDs, &manifest)
	if err != nil {
		p.finishFailed(ctx, job, "write layers: "+err.Error())
		return
	}
	manifest.Counts.Layers = len(publishedLayers)

	// Choice lists
	p.progress(ctx, job.ID, "choice_lists", 35)
	clCount, err := p.writeChoiceLists(ctx, zw, job.ProjectID)
	if err != nil {
		p.finishFailed(ctx, job, "write choice lists: "+err.Error())
		return
	}
	manifest.Counts.ChoiceLists = clCount

	// Assignments
	p.progress(ctx, job.ID, "assignments", 45)
	asgnCount, err := p.writeAssignments(ctx, zw, job.ProjectID, job.CreatedBy)
	if err != nil {
		p.finishFailed(ctx, job, "write assignments: "+err.Error())
		return
	}
	manifest.Counts.Assignments = asgnCount

	// Reference features (only if full bundle)
	if cfg.IncludeReferenceData {
		if !manifest.HasAOI {
			manifest.Warnings = append(manifest.Warnings,
				"Project has no AOI; reference features included without spatial filter")
		}
		refCount, err := p.writeReferenceFeatures(ctx, zw, publishedLayers, project.AreaOfInterest, manifest.HasAOI, project.AOIBufferMeters(), job.ID)
		if err != nil {
			p.finishFailed(ctx, job, "write reference features: "+err.Error())
			return
		}
		manifest.Counts.ReferenceFeatures = refCount
	}

	// manifest.json (last so bundle hash includes everything else)
	p.progress(ctx, job.ID, "manifest", 95)
	tmpHash := hex.EncodeToString(hasher.Sum(nil))[:16]
	manifest.BundleHash = tmpHash
	if err := writeJSON(zw, "manifest.json", manifest); err != nil {
		p.finishFailed(ctx, job, "write manifest: "+err.Error())
		return
	}

	if err := zw.Close(); err != nil {
		p.finishFailed(ctx, job, "close zip: "+err.Error())
		return
	}

	// Upload to RustFS
	p.progress(ctx, job.ID, "uploading", 97)
	storageKey := fmt.Sprintf("bundles/%s/%s/%s.zip", job.ProjectID, job.CreatedBy, cfg.ContentHash)
	filename := buildBundleFilename(project.Name, cfg.ContentHash)

	reader := bytes.NewReader(buf.Bytes())
	_, err = p.s3client.PutObject(ctx, p.s3bucket, storageKey, reader, int64(buf.Len()),
		minio.PutObjectOptions{ContentType: "application/zip"})
	if err != nil {
		p.finishFailed(ctx, job, "s3 upload: "+err.Error())
		return
	}

	// Write cache row
	countsJSON, _ := json.Marshal(manifest.Counts)
	warningsJSON, _ := json.Marshal(manifest.Warnings)
	cacheEntry := &model.BundleCache{
		ProjectID:            job.ProjectID,
		UserID:               job.CreatedBy,
		IncludeReferenceData: cfg.IncludeReferenceData,
		ContentHash:          cfg.ContentHash,
		StorageKey:           storageKey,
		Filename:             filename,
		SizeBytes:            int64(buf.Len()),
		Counts:               countsJSON,
		Warnings:             warningsJSON,
	}
	if err := p.bundleCacheRepo.Create(ctx, cacheEntry); err != nil {
		slog.Warn("failed to write bundle_cache row", "error", err, "job_id", job.ID)
		// Continue — the upload succeeded; next request will use cache miss path
	}

	// Finalize job
	result := model.BundleJobResult{
		CacheID:     cacheEntry.ID,
		ContentHash: cfg.ContentHash,
		StorageKey:  storageKey,
		Filename:    filename,
		SizeBytes:   int64(buf.Len()),
		Counts:      manifest.Counts,
		Warnings:    manifest.Warnings,
	}
	resultJSON, _ := json.Marshal(result)
	_ = p.importJobRepo.MarkFinished(ctx, job.ID, "success", resultJSON, "")
	p.publishStatus(ctx, job.ID, "success", &model.BundleJobProgress{Step: "complete", Percent: 100})
	p.bundleSvc.ReleaseJobDedupLock(ctx, job)

	// Warm hot cache for this user
	p.bundleSvc.warmHotCache(ctx, job.ProjectID, job.CreatedBy, cfg.IncludeReferenceData, cacheEntry)

	slog.Info("bundle generated",
		"job_id", job.ID,
		"size_bytes", buf.Len(),
		"forms", manifest.Counts.Forms,
		"layers", manifest.Counts.Layers,
		"ref_features", manifest.Counts.ReferenceFeatures,
	)
}

// runLayerRefJob builds a ZIP with one layer's reference GeoJSON (+ optional mbtiles).
func (p *BundleWorkerPool) runLayerRefJob(job *model.ImportJob, cfg bundleJobConfigInner) {
	ctx := p.ctx

	if cfg.LayerID == uuid.Nil {
		p.finishFailed(ctx, job, "layer_id required")
		return
	}

	project, err := p.projectRepo.FindByID(ctx, job.ProjectID)
	if err != nil {
		p.finishFailed(ctx, job, "project not found")
		return
	}

	layer, err := p.layerRepo.FindByID(ctx, cfg.LayerID)
	if err != nil || layer == nil {
		p.finishFailed(ctx, job, "layer not found")
		return
	}
	if layer.ProjectID != job.ProjectID {
		p.finishFailed(ctx, job, "layer does not belong to project")
		return
	}
	if layer.Status != "published" {
		p.finishFailed(ctx, job, "layer must be published")
		return
	}

	hasAOI := len(project.AreaOfInterest) > 0
	warnings := []string{}
	if !hasAOI {
		warnings = append(warnings,
			"Project has no AOI; reference features included without spatial filter")
	}

	manifest := map[string]interface{}{
		"pack_kind":              "layer_ref",
		"bundle_version":         "1.0",
		"project_id":             project.ID,
		"layer_id":               layer.ID,
		"layer_name":             layer.Name,
		"generated_at":           time.Now(),
		"generated_by":           job.CreatedBy,
		"include_reference_data": true,
		"has_aoi":                hasAOI,
		"content_hash":           cfg.ContentHash,
		"warnings":               warnings,
	}

	var buf bytes.Buffer
	hasher := sha256.New()
	mw := io.MultiWriter(&buf, hasher)
	zw := zip.NewWriter(mw)

	p.progress(ctx, job.ID, "reference_features", 20)
	refCount, err := p.writeOneLayerReference(
		ctx, zw, *layer, project.AreaOfInterest, hasAOI, project.AOIBufferMeters(),
	)
	if err != nil {
		p.finishFailed(ctx, job, "write reference: "+err.Error())
		return
	}

	counts := model.BundleCounts{
		Layers:            1,
		ReferenceFeatures: refCount,
	}
	manifest["counts"] = counts

	p.progress(ctx, job.ID, "manifest", 90)
	manifest["bundle_hash"] = hex.EncodeToString(hasher.Sum(nil))[:16]
	if err := writeJSON(zw, "manifest.json", manifest); err != nil {
		p.finishFailed(ctx, job, "write manifest: "+err.Error())
		return
	}
	if err := zw.Close(); err != nil {
		p.finishFailed(ctx, job, "close zip: "+err.Error())
		return
	}

	p.progress(ctx, job.ID, "uploading", 97)
	storageKey := fmt.Sprintf(
		"layer-packs/%s/%s/%s.zip", job.ProjectID, layer.ID, cfg.ContentHash,
	)
	filename := fmt.Sprintf("layer_%s_%s.zip", sanitizeFilename(layer.Name), cfg.ContentHash[:8])

	reader := bytes.NewReader(buf.Bytes())
	_, err = p.s3client.PutObject(ctx, p.s3bucket, storageKey, reader, int64(buf.Len()),
		minio.PutObjectOptions{ContentType: "application/zip"})
	if err != nil {
		p.finishFailed(ctx, job, "s3 upload: "+err.Error())
		return
	}

	countsJSON, _ := json.Marshal(counts)
	warningsJSON, _ := json.Marshal(warnings)
	cacheEntry := &model.BundleCache{
		ProjectID:            job.ProjectID,
		UserID:               job.CreatedBy,
		IncludeReferenceData: true,
		ContentHash:          cfg.ContentHash,
		StorageKey:           storageKey,
		Filename:             filename,
		SizeBytes:            int64(buf.Len()),
		Counts:               countsJSON,
		Warnings:             warningsJSON,
	}
	if err := p.bundleCacheRepo.Create(ctx, cacheEntry); err != nil {
		slog.Warn("failed to write layer pack cache row", "error", err, "job_id", job.ID)
	}

	result := model.BundleJobResult{
		CacheID:     cacheEntry.ID,
		ContentHash: cfg.ContentHash,
		StorageKey:  storageKey,
		Filename:    filename,
		SizeBytes:   int64(buf.Len()),
		Counts:      counts,
		Warnings:    warnings,
	}
	resultJSON, _ := json.Marshal(result)
	_ = p.importJobRepo.MarkFinished(ctx, job.ID, "success", resultJSON, "")
	p.publishStatus(ctx, job.ID, "success", &model.BundleJobProgress{Step: "complete", Percent: 100})
	p.bundleSvc.ReleaseJobDedupLock(ctx, job)
	p.bundleSvc.warmLayerHotCache(ctx, job.ProjectID, layer.ID, cacheEntry)

	slog.Info("layer reference pack generated",
		"job_id", job.ID,
		"layer_id", layer.ID,
		"size_bytes", buf.Len(),
		"ref_features", refCount,
	)
}

// ── Section writers ────────────────────────────────────

func (p *BundleWorkerPool) writeForms(
	ctx context.Context, zw *zip.Writer, projectID uuid.UUID, manifest *model.BundleManifest,
) (map[uuid.UUID]bool, int, error) {
	all, err := p.formRepo.ListByProject(ctx, projectID)
	if err != nil {
		return nil, 0, err
	}

	published := []model.Form{}
	ids := map[uuid.UUID]bool{}
	for _, f := range all {
		if !f.IsActive {
			continue
		}

		// AOI/Bundle fix: schema lives on form_versions, not on forms.schema
		// (forms.schema drifts to the latest DRAFT on every edit). Fetch the
		// latest PUBLISHED version and override before emitting.
		fv, err := p.formRepo.FindLatestPublishedVersion(ctx, f.ID)
		if err != nil {
			manifest.Warnings = append(manifest.Warnings,
				fmt.Sprintf("Form %q (%s) has no published version — skipped in bundle", f.Name, f.ID))
			continue
		}

		// Override with the published schema + version
		f.Schema = fv.Schema
		f.Version = fv.Version

		published = append(published, f)
		ids[f.ID] = true
	}

	if len(published) == 0 {
		manifest.Warnings = append(manifest.Warnings, "No published forms in this project")
	}

	index := make([]map[string]interface{}, 0, len(published))
	for _, f := range published {
		index = append(index, map[string]interface{}{
			"id": f.ID, "name": f.Name, "version": f.Version,
		})
		if err := writeJSON(zw, fmt.Sprintf("forms/%s.json", f.ID), f); err != nil {
			return nil, 0, err
		}
	}
	if err := writeJSON(zw, "forms/index.json", index); err != nil {
		return nil, 0, err
	}
	return ids, len(published), nil
}

func (p *BundleWorkerPool) writeLayers(
	ctx context.Context, zw *zip.Writer, projectID uuid.UUID,
	publishedFormIDs map[uuid.UUID]bool, manifest *model.BundleManifest,
) ([]model.Layer, error) {
	all, err := p.layerRepo.ListByProject(ctx, projectID)
	if err != nil {
		return nil, err
	}
	slog.Info("bundle: layers loaded",
		"project_id", projectID,
		"count", len(all),
	)
	for _, l := range all {
		slog.Info("bundle: layer",
			"id", l.ID,
			"name", l.Name,
			"status", l.Status,
			"form_id", l.FormID,
		)
	}

	published := []model.Layer{}
	for _, l := range all {
		if l.Status != "published" {
			continue
		}
		if l.FormID != nil && !publishedFormIDs[*l.FormID] {
			manifest.Warnings = append(manifest.Warnings,
				fmt.Sprintf("Layer %q references unpublished form; form_id set to null in bundle", l.Name))
			l.FormID = nil
		}
		published = append(published, l)
	}
	if len(published) == 0 {
		manifest.Warnings = append(manifest.Warnings, "No published layers in this project")
	}

	// ── D1.0: pre-fetch each layer's data source id (assumption: 1:1). ──
	dataSourceByLayer := make(map[uuid.UUID]*uuid.UUID, len(published))
	if p.dataSourceRepo != nil {
		for _, l := range published {
			sources, err := p.dataSourceRepo.ListByLayer(ctx, l.ID)
			if err != nil || len(sources) == 0 {
				continue
			}
			id := sources[0].ID
			dataSourceByLayer[l.ID] = &id
		}
	}

	index := make([]map[string]interface{}, 0, len(published))
	for _, l := range published {
		dsID := dataSourceByLayer[l.ID]
		index = append(index, map[string]interface{}{
			"id":             l.ID,
			"name":           l.Name,
			"geometry_type":  l.GeometryType,
			"form_id":        l.FormID,
			"source_type":    l.SourceType,
			"data_source_id": dsID,
		})

		// Inject data_source_id into the per-layer JSON without modifying
		// the bun-managed Layer struct.
		layerJSON, err := flattenWithExtras(l, map[string]interface{}{
			"data_source_id": dsID,
		})
		if err != nil {
			return nil, err
		}
		if err := writeJSON(zw, fmt.Sprintf("layers/%s.json", l.ID), layerJSON); err != nil {
			return nil, err
		}
	}
	if err := writeJSON(zw, "layers/index.json", index); err != nil {
		return nil, err
	}
	return published, nil
}

func (p *BundleWorkerPool) writeChoiceLists(
	ctx context.Context, zw *zip.Writer, projectID uuid.UUID,
) (int, error) {
	all, err := p.choiceListRepo.ListByProject(ctx, projectID)
	if err != nil {
		return 0, err
	}
	index := make([]map[string]interface{}, 0, len(all))
	for _, cl := range all {
		index = append(index, map[string]interface{}{"id": cl.ID, "name": cl.Name})
		if err := writeJSON(zw, fmt.Sprintf("choice_lists/%s.json", cl.ID), cl); err != nil {
			return 0, err
		}
	}
	if err := writeJSON(zw, "choice_lists/index.json", index); err != nil {
		return 0, err
	}
	return len(all), nil
}

func (p *BundleWorkerPool) writeAssignments(
	ctx context.Context, zw *zip.Writer, projectID, userID uuid.UUID,
) (int, error) {
	all, err := p.assignmentRepo.ListByUser(ctx, userID, projectID)
	if err != nil {
		return 0, err
	}
	index := make([]map[string]interface{}, 0, len(all))
	for _, a := range all {
		index = append(index, map[string]interface{}{
			"id": a.ID, "title": a.Title, "priority": a.Priority, "due_date": a.DueDate,
		})
		if err := writeJSON(zw, fmt.Sprintf("assignments/%s.json", a.ID), a); err != nil {
			return 0, err
		}
	}
	if err := writeJSON(zw, "assignments/index.json", index); err != nil {
		return 0, err
	}
	return len(all), nil
}

func (p *BundleWorkerPool) writeReferenceFeatures(
	ctx context.Context, zw *zip.Writer, layers []model.Layer,
	aoi json.RawMessage, hasAOI bool, bufferMeters int, jobID uuid.UUID,
) (int, error) {
	total := 0
	step := 45.0
	perLayer := 50.0 / float64(max(len(layers), 1))

	for _, l := range layers {
		n, err := p.writeOneLayerReference(ctx, zw, l, aoi, hasAOI, bufferMeters)
		if err != nil {
			return total, err
		}
		total += n
		step += perLayer
		p.progress(ctx, jobID, fmt.Sprintf("ref_features_%s", l.ID), int(step))
	}
	return total, nil
}

func (p *BundleWorkerPool) writeOneLayerReference(
	ctx context.Context, zw *zip.Writer, l model.Layer,
	aoi json.RawMessage, hasAOI bool, bufferMeters int,
) (int, error) {
	var (
		features []map[string]interface{}
		err      error
	)
	if l.SourceType == "linked_table" {
		features, err = p.queryLinkedReferenceFeatures(ctx, l, aoi, hasAOI, bufferMeters)
	} else {
		features, err = p.queryCopiedReferenceFeatures(ctx, l, aoi, hasAOI, bufferMeters)
	}
	if err != nil {
		return 0, fmt.Errorf("query layer %s (%s): %w", l.Name, l.ID, err)
	}

	geojson := map[string]interface{}{
		"type":     "FeatureCollection",
		"features": features,
	}
	if err := writeJSON(zw, fmt.Sprintf("reference_features/%s.geojson", l.ID), geojson); err != nil {
		return 0, err
	}

	if p.tippecanoeClient != nil && len(features) > 0 {
		geomType := mapGeometryTypeToTippecanoe(l.GeometryType)
		params := DefaultTileParams("reference_features", geomType)
		mbtiles, tileErr := p.tippecanoeClient.GenerateTiles(features, params)
		if tileErr != nil {
			slog.Warn("tile generation failed; pack will use GeoJSON only",
				"layer_id", l.ID, "error", tileErr)
		} else {
			if err := writeBytes(zw, fmt.Sprintf("reference_tiles/%s.mbtiles", l.ID), mbtiles); err != nil {
				return 0, err
			}
			slog.Info("emitted mbtiles",
				"layer_id", l.ID,
				"layer_name", l.Name,
				"source_type", l.SourceType,
				"features", len(features),
				"mbtiles_kb", len(mbtiles)/1024,
			)
		}
	}

	return len(features), nil
}

func (p *BundleWorkerPool) queryCopiedReferenceFeatures(
	ctx context.Context, l model.Layer,
	aoi json.RawMessage, hasAOI bool, bufferMeters int,
) ([]map[string]interface{}, error) {
	type row struct {
		ID           string          `bun:"id"`
		Geometry     string          `bun:"geometry"`
		Attributes   json.RawMessage `bun:"attributes"`
		SourceRef    string          `bun:"source_ref"`
		DataSourceID string          `bun:"data_source_id"`
	}

	q := p.db.NewSelect().
		TableExpr("features AS f").
		ColumnExpr("f.id::text AS id").
		ColumnExpr("ST_AsGeoJSON(f.geometry)::text AS geometry").
		ColumnExpr("f.attributes").
		ColumnExpr("COALESCE(f.source_ref, '') AS source_ref").
		ColumnExpr("COALESCE(f.data_source_id::text, '') AS data_source_id").
		Where("f.layer_id = ?", l.ID).
		Where("f.source = ?", "reference").
		Where("f.deleted_at IS NULL").
		Where("f.geometry IS NOT NULL")

	if hasAOI && len(aoi) > 0 {
		q = q.Where(
			"ST_Intersects(f.geometry, ST_Buffer(ST_GeomFromGeoJSON(?)::geography, ?)::geometry)",
			string(aoi),
			bufferMeters,
		)
	}

	var rows []row
	if err := q.Scan(ctx, &rows); err != nil {
		return nil, err
	}

	features := make([]map[string]interface{}, 0, len(rows))
	for _, r := range rows {
		var geom map[string]interface{}
		_ = json.Unmarshal([]byte(r.Geometry), &geom)
		var props map[string]interface{}
		_ = json.Unmarshal(r.Attributes, &props)
		if props == nil {
			props = map[string]interface{}{}
		}
		if r.SourceRef != "" {
			props["_source_ref"] = r.SourceRef
		}
		if r.DataSourceID != "" {
			props["_data_source_id"] = r.DataSourceID
		}
		features = append(features, map[string]interface{}{
			"type":       "Feature",
			"id":         r.ID,
			"geometry":   geom,
			"properties": props,
		})
	}
	return features, nil
}

// queryLinkedReferenceFeatures packs live dbo (or other) table rows into the
// same GeoJSON shape as copied reference features, so offline bundles treat
// linked and external reference data the same when the user opts in.
func (p *BundleWorkerPool) queryLinkedReferenceFeatures(
	ctx context.Context, l model.Layer,
	aoi json.RawMessage, hasAOI bool, bufferMeters int,
) ([]map[string]interface{}, error) {
	var cfg struct {
		Schema         string   `json:"schema"`
		Table          string   `json:"table"`
		IDColumn       string   `json:"id_column"`
		GeometryColumn string   `json:"geometry_column"`
		Included       []string `json:"included_columns"`
	}
	if err := json.Unmarshal(l.SourceConfig, &cfg); err != nil || cfg.Schema == "" || cfg.Table == "" {
		return nil, fmt.Errorf("linked layer missing schema/table in source_config")
	}
	if cfg.GeometryColumn == "" {
		return nil, fmt.Errorf("linked layer %s has no geometry_column", l.Name)
	}

	cols, err := listTableColumns(ctx, p.db, cfg.Schema, cfg.Table, cfg.GeometryColumn)
	if err != nil {
		return nil, fmt.Errorf("discover columns: %w", err)
	}

	included := map[string]bool{}
	for _, c := range cfg.Included {
		included[c] = true
	}

	selectParts := make([]string, 0, len(cols)+1)
	attrCols := make([]string, 0, len(cols))
	for _, c := range cols {
		if c.IsGeometry || c.Name == cfg.GeometryColumn {
			continue
		}
		if len(included) > 0 && !included[c.Name] && c.Name != cfg.IDColumn {
			continue
		}
		selectParts = append(selectParts, pgQuoteIdent(c.Name))
		attrCols = append(attrCols, c.Name)
	}
	selectParts = append(selectParts,
		fmt.Sprintf("ST_AsGeoJSON(ST_Transform(%s, 4326)) AS __geom__", pgQuoteIdent(cfg.GeometryColumn)))

	qualified := pgQuoteIdent(cfg.Schema) + "." + pgQuoteIdent(cfg.Table)
	whereSQL := fmt.Sprintf("%s IS NOT NULL", pgQuoteIdent(cfg.GeometryColumn))
	args := []interface{}{}
	if hasAOI && len(aoi) > 0 {
		// Use $n placeholders — raw database/sql does not rewrite bun-style "?".
		// A literal "?" is a jsonb operator in Postgres and yields
		// "syntax error at or near )" around ST_GeomFromGeoJSON(?).
		whereSQL += fmt.Sprintf(
			` AND ST_Intersects(
				ST_Transform(%s, 4326),
				ST_Buffer(ST_GeomFromGeoJSON($1)::geography, $2)::geometry
			)`,
			pgQuoteIdent(cfg.GeometryColumn),
		)
		args = append(args, string(aoi), bufferMeters)
	}

	orderSQL := ""
	if cfg.IDColumn != "" {
		orderSQL = " ORDER BY " + pgQuoteIdent(cfg.IDColumn)
	}

	q := fmt.Sprintf(
		`SELECT %s FROM %s WHERE %s%s`,
		strings.Join(selectParts, ", "),
		qualified,
		whereSQL,
		orderSQL,
	)

	rows, err := p.db.DB.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("query linked table: %w", err)
	}
	defer rows.Close()

	colNames, err := rows.Columns()
	if err != nil {
		return nil, err
	}

	var dsID string
	if p.dataSourceRepo != nil {
		if sources, dsErr := p.dataSourceRepo.ListByLayer(ctx, l.ID); dsErr == nil && len(sources) > 0 {
			dsID = sources[0].ID.String()
		}
	}

	features := make([]map[string]interface{}, 0, 256)
	for rows.Next() {
		raw := make([]interface{}, len(colNames))
		ptrs := make([]interface{}, len(colNames))
		for i := range raw {
			ptrs[i] = &raw[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}

		props := map[string]interface{}{}
		var geomJSON []byte
		var sourceRef string
		for i, name := range colNames {
			if name == "__geom__" {
				switch v := raw[i].(type) {
				case nil:
				case []byte:
					geomJSON = v
				case string:
					geomJSON = []byte(v)
				}
				continue
			}
			val := normalizeSQLValue(raw[i])
			props[name] = val
			if cfg.IDColumn != "" && name == cfg.IDColumn && val != nil {
				sourceRef = fmt.Sprint(val)
			}
		}
		if sourceRef == "" {
			for _, c := range attrCols {
				if v, ok := props[c]; ok && v != nil {
					sourceRef = fmt.Sprint(v)
					break
				}
			}
		}
		if sourceRef == "" {
			sourceRef = fmt.Sprintf("%s-%d", l.ID.String()[:8], len(features))
		}
		props["_source_ref"] = sourceRef
		if dsID != "" {
			props["_data_source_id"] = dsID
		}

		var geom map[string]interface{}
		if len(geomJSON) > 0 {
			_ = json.Unmarshal(geomJSON, &geom)
		}
		if geom == nil {
			continue
		}

		features = append(features, map[string]interface{}{
			"type":       "Feature",
			"id":         sourceRef,
			"geometry":   geom,
			"properties": props,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	slog.Info("bundle: linked reference features packed",
		"layer_id", l.ID,
		"layer_name", l.Name,
		"table", cfg.Schema+"."+cfg.Table,
		"features", len(features),
		"aoi_filtered", hasAOI && len(aoi) > 0,
	)
	return features, nil
}

// ── Helpers ────────────────────────────────────────────

func (p *BundleWorkerPool) progress(ctx context.Context, jobID uuid.UUID, step string, percent int) {
	pr := &model.BundleJobProgress{Step: step, Percent: percent}
	prJSON, _ := json.Marshal(pr)
	_ = p.importJobRepo.UpdateProgress(ctx, jobID, prJSON)
	p.publishStatus(ctx, jobID, "running", pr)
}

func (p *BundleWorkerPool) publishStatus(ctx context.Context, jobID uuid.UUID, status string, progress *model.BundleJobProgress) {
	view := &BundleJobView{
		JobID:    jobID,
		Status:   status,
		Progress: progress,
	}
	p.bundleSvc.WriteJobViewToCache(ctx, view)
}

func (p *BundleWorkerPool) finishFailed(ctx context.Context, job *model.ImportJob, errMsg string) {
	_ = p.importJobRepo.MarkFinished(ctx, job.ID, "failed", nil, errMsg)
	p.publishStatus(ctx, job.ID, "failed", nil)
	p.bundleSvc.ReleaseJobDedupLock(ctx, job)
	slog.Error("bundle job failed", "job_id", job.ID, "error", errMsg)
}

func writeJSON(zw *zip.Writer, name string, v interface{}) error {
	w, err := zw.Create(name)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(v)
}

func buildBundleFilename(projectName, contentHash string) string {
	safe := sanitizeFilename(projectName)
	if safe == "" {
		safe = "project"
	}
	if len(safe) > 40 {
		safe = safe[:40]
	}
	date := time.Now().Format("2006-01-02")
	short := contentHash
	if len(short) > 8 {
		short = short[:8]
	}
	return fmt.Sprintf("%s_bundle_%s_%s.zip", safe, date, short)
}

func sanitizeFilename(name string) string {
	return strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			return r
		case r == ' ', r == '-', r == '_':
			return '_'
		default:
			return -1
		}
	}, name)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// flattenWithExtras serializes any struct to a JSON object then merges extra
// fields into it. Lets us emit per-bundle metadata without modifying source
// structs (e.g., bun-managed models).
func flattenWithExtras(value any, extras map[string]interface{}) (map[string]interface{}, error) {
	b, err := json.Marshal(value)
	if err != nil {
		return nil, err
	}
	out := map[string]interface{}{}
	if err := json.Unmarshal(b, &out); err != nil {
		return nil, err
	}
	for k, v := range extras {
		out[k] = v
	}
	return out, nil
}

// writeBytes writes raw bytes as a file entry in the bundle zip.
func writeBytes(zw *zip.Writer, name string, data []byte) error {
	w, err := zw.Create(name)
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// mapGeometryTypeToTippecanoe converts our layer's geometry_type ("point",
// "line", "polygon") to what the tippecanoe sidecar expects. Case-insensitive.
func mapGeometryTypeToTippecanoe(geomType string) string {
	switch strings.ToLower(geomType) {
	case "point", "multipoint":
		return "point"
	case "line", "linestring", "multilinestring":
		return "line"
	case "polygon", "multipolygon":
		return "polygon"
	default:
		return "line" // safe fallback
	}
}
