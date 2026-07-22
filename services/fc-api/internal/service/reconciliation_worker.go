package service

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
	"github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
	"github.com/google/uuid"
)

// ReconciliationWorkerPool runs reconciliation jobs in the background so the
// HTTP layer doesn't block on long source-DB writes. Mirrors WorkerPool /
// BundleWorkerPool in shape and lifecycle.
type ReconciliationWorkerPool struct {
	service *ReconciliationService
	jobRepo *repository.ReconciliationRepo

	queue       chan *model.ReconciliationJob
	workerCount int
	wg          sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
}

// NewReconciliationWorkerPool creates and starts a pool of background workers.
//
// Default workerCount is 1 — reconciliation is bounded by external DB
// throughput and we don't want competing writes to the same source.
func NewReconciliationWorkerPool(
	service *ReconciliationService,
	jobRepo *repository.ReconciliationRepo,
	workerCount int,
) *ReconciliationWorkerPool {
	if workerCount <= 0 {
		workerCount = 1
	}
	ctx, cancel := context.WithCancel(context.Background())

	pool := &ReconciliationWorkerPool{
		service:     service,
		jobRepo:     jobRepo,
		queue:       make(chan *model.ReconciliationJob, 16),
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

func (p *ReconciliationWorkerPool) worker(id int) {
	defer p.wg.Done()
	slog.Info("reconciliation worker started", "id", id)
	for {
		select {
		case <-p.ctx.Done():
			slog.Info("reconciliation worker stopping", "id", id)
			return
		case job, ok := <-p.queue:
			if !ok {
				return
			}
			p.runJob(id, job)
		}
	}
}

// Submit enqueues a job for processing. Non-blocking; if the queue is full,
// the job is marked failed immediately.
func (p *ReconciliationWorkerPool) Submit(job *model.ReconciliationJob) {
	select {
	case p.queue <- job:
	default:
		slog.Error("reconciliation queue full, rejecting", "job_id", job.ID)
		_ = p.jobRepo.MarkFinished(
			context.Background(), job.ID, "failed", nil, "worker queue full",
		)
	}
}

// Shutdown gracefully stops all workers, waiting for in-flight jobs to finish.
func (p *ReconciliationWorkerPool) Shutdown() {
	p.cancel()
	close(p.queue)
	p.wg.Wait()
}

func (p *ReconciliationWorkerPool) runJob(workerID int, job *model.ReconciliationJob) {
	slog.Info("running reconciliation job",
		"worker_id", workerID,
		"job_id", job.ID,
		"mode", job.Mode,
		"layer_id", job.LayerID,
	)

	// ── BULLETPROOF WATCHDOG ──
	// Independent goroutine that force-finalizes the job after a grace period
	// if ApplyJob didn't. Solves the "status stays running" bug regardless of
	// whether the defer-based finalizer fires.
	done := make(chan struct{})
	go p.watchdog(job.ID, done)

	switch job.Mode {
	case "apply":
		_, err := p.service.ApplyJob(p.ctx, job)
		if err != nil {
			slog.Error("apply job failed",
				"worker_id", workerID, "job_id", job.ID, "error", err)
			_ = p.jobRepo.MarkFinished(context.Background(), job.ID, "failed", nil, err.Error())
		}
	default:
		slog.Warn("reconciliation worker received non-apply job — ignoring",
			"job_id", job.ID, "mode", job.Mode)
	}

	close(done) // signal watchdog to exit quietly

	slog.Info("finished reconciliation job",
		"worker_id", workerID, "job_id", job.ID)
}

// watchdog runs in a goroutine spawned alongside each apply. After a short
// grace period, it checks if the job is still 'running' and force-finalizes
// based on counters if so. Independent of the ApplyJob call's defer / panic /
// context cancellation — guaranteed to fire.
func (p *ReconciliationWorkerPool) watchdog(jobID uuid.UUID, done <-chan struct{}) {
	timer := time.NewTimer(30 * time.Second)
	defer timer.Stop()

	select {
	case <-done:
		// ApplyJob's normal path finished. Give it a tiny moment, then verify
		// terminal status. If it's already terminal, we exit. If not, we fix.
		time.Sleep(500 * time.Millisecond)
	case <-timer.C:
		// ApplyJob didn't signal done within 30s — definitely needs finalizing.
	}

	bgCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	current, err := p.service.GetJobNoMembership(bgCtx, jobID)
	if err != nil {
		slog.Error("[reconcile] watchdog: failed to load job",
			"job_id", jobID, "error", err)
		return
	}
	if current.Status != "running" && current.Status != "pending" && current.Status != "cancelling" {
		// Normal path already finalized; nothing to do
		return
	}

	// Decide a terminal status from actual counters
	status := "failed"
	errMsg := "watchdog: job did not finalize within grace period"

	switch {
	case current.Errors > 0:
		status = "partial"
		errMsg = ""
	case current.ConflictsDetected > 0 && (current.UpdatesSucceeded+current.DeletesSucceeded) > 0:
		status = "partial"
		errMsg = ""
	case current.ConflictsDetected > 0:
		status = "partial"
		errMsg = ""
	case current.UpdatesSucceeded > 0 || current.DeletesSucceeded > 0:
		status = "success"
		errMsg = ""
	default:
		status = "failed"
		errMsg = "no changes applied"
	}

	slog.Warn("[reconcile] watchdog finalizing stale job",
		"job_id", jobID,
		"intended_status", status,
		"applied", current.UpdatesSucceeded+current.DeletesSucceeded,
		"conflicts", current.ConflictsDetected,
		"errors", current.Errors,
	)

	if err := p.service.ForceMarkFinished(bgCtx, jobID, status, errMsg); err != nil {
		slog.Error("[reconcile] watchdog ForceMarkFinished failed",
			"job_id", jobID, "error", err)
	} else {
		slog.Info("[reconcile] watchdog wrote terminal status",
			"job_id", jobID, "status", status)
	}
}
