package service

import (
    "context"
    "log/slog"
    "sync"

    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/model"
    "github.com/kwaabs/n-taa-fc/services/fc-api/internal/repository"
)

type WorkerPool struct {
    orchestrator *ImportOrchestrator
    jobRepo      *repository.ImportJobRepo

    queue      chan *model.ImportJob
    workerCount int
    wg          sync.WaitGroup
    ctx         context.Context
    cancel      context.CancelFunc
}

// NewWorkerPool creates and starts a pool of background workers.
func NewWorkerPool(orchestrator *ImportOrchestrator, jobRepo *repository.ImportJobRepo, workerCount int) *WorkerPool {
    if workerCount <= 0 {
        workerCount = 2
    }
    ctx, cancel := context.WithCancel(context.Background())

    pool := &WorkerPool{
        orchestrator: orchestrator,
        jobRepo:      jobRepo,
        queue:        make(chan *model.ImportJob, 16),
        workerCount:  workerCount,
        ctx:          ctx,
        cancel:       cancel,
    }
    for i := 0; i < workerCount; i++ {
        pool.wg.Add(1)
        go pool.worker(i)
    }
    return pool
}

func (p *WorkerPool) worker(id int) {
    defer p.wg.Done()
    slog.Info("import worker started", "id", id)
    for {
        select {
        case <-p.ctx.Done():
            slog.Info("import worker stopping", "id", id)
            return
        case job, ok := <-p.queue:
            if !ok {
                return
            }
            slog.Info("running import job", "worker_id", id, "job_id", job.ID)
            p.orchestrator.Run(p.ctx, job)
            slog.Info("finished import job", "worker_id", id, "job_id", job.ID)
        }
    }
}

// Submit enqueues a job for processing. Non-blocking unless the queue is full.
func (p *WorkerPool) Submit(job *model.ImportJob) {
    select {
    case p.queue <- job:
    default:
        // Queue full — log and fail the job
        slog.Error("import job queue full, rejecting", "job_id", job.ID)
        _ = p.jobRepo.MarkFinished(context.Background(), job.ID, "failed", nil, "worker queue full")
    }
}

func (p *WorkerPool) Shutdown() {
    p.cancel()
    close(p.queue)
    p.wg.Wait()
}