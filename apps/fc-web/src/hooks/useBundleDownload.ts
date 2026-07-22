import { useState, useRef, useCallback } from "react";
import { api } from "@/lib/api";

export type BundleStage =
  | "idle"
  | "requesting"
  | "queued"
  | "running"
  | "ready"
  | "downloading"
  | "complete"
  | "error";

export interface BundleProgress {
  step?: string;
  percent?: number;
  message?: string;
}

export interface BundleReadyInfo {
  filename: string;
  download_url: string;
  size_bytes: number;
  content_hash: string;
  counts: {
    forms: number;
    layers: number;
    choice_lists: number;
    assignments: number;
    reference_features: number;
  };
  warnings?: string[];
  expires_at?: string;
}

interface State {
  stage: BundleStage;
  progress: BundleProgress | null;
  ready: BundleReadyInfo | null;
  error: string | null;
}

export function useBundleDownload(projectId: string) {
  const [state, setState] = useState<State>({
    stage: "idle",
    progress: null,
    ready: null,
    error: null,
  });

  const pollTimerRef = useRef<number | null>(null);
  const cancelledRef = useRef(false);

  const clearPolling = () => {
    if (pollTimerRef.current !== null) {
      clearTimeout(pollTimerRef.current);
      pollTimerRef.current = null;
    }
  };

  const reset = useCallback(() => {
    cancelledRef.current = true;
    clearPolling();
    setState({ stage: "idle", progress: null, ready: null, error: null });
  }, []);

  const downloadFile = (url: string, filename: string) => {
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.target = "_blank";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  const start = useCallback(
    async (includeReferenceData: boolean) => {
      cancelledRef.current = false;
      clearPolling();
      setState({
        stage: "requesting",
        progress: null,
        ready: null,
        error: null,
      });

      try {
        const resp = await api.requestBundle(projectId, includeReferenceData);

        if (cancelledRef.current) return;

        if (resp?.status === "ready" && resp?.download_url) {
          setState({
            stage: "ready",
            progress: null,
            ready: resp as BundleReadyInfo,
            error: null,
          });
          return;
        }

        if (resp?.job_id) {
          if (resp.status === "failed") {
            setState({
              stage: "error",
              progress: null,
              ready: null,
              error: "Bundle generation failed — retry to start a new job",
            });
            return;
          }
          setState((s) => ({
            ...s,
            stage: resp.status === "running" ? "running" : "queued",
            error: null,
          }));
          pollJob(resp.job_id);
          return;
        }

        setState({
          stage: "error",
          progress: null,
          ready: null,
          error: "Unexpected response from server",
        });
      } catch (err: any) {
        setState({
          stage: "error",
          progress: null,
          ready: null,
          error: err.message || "Request failed",
        });
      }
    },
    [projectId]
  );

  const pollJob = useCallback(
    (jobId: string) => {
      const poll = async () => {
        if (cancelledRef.current) return;
        try {
          const view = await api.getBundleJob(projectId, jobId);
          if (cancelledRef.current) return;

          if (view.status === "success" && view.result) {
            setState({
              stage: "ready",
              progress: null,
              ready: view.result as BundleReadyInfo,
              error: null,
            });
            return;
          }

          if (view.status === "failed") {
            setState({
              stage: "error",
              progress: null,
              ready: null,
              error: view.error || "Bundle generation failed",
            });
            return;
          }

          // queued or running — keep polling
          setState((s) => ({
            ...s,
            stage: view.status === "running" ? "running" : "queued",
            progress: view.progress || null,
            error: null,
          }));

          pollTimerRef.current = window.setTimeout(poll, 1500);
        } catch (err: any) {
          if (cancelledRef.current) return;
          setState({
            stage: "error",
            progress: null,
            ready: null,
            error: err.message || "Polling failed",
          });
        }
      };

      pollTimerRef.current = window.setTimeout(poll, 500);
    },
    [projectId]
  );

  const download = useCallback(() => {
    if (state.stage !== "ready" || !state.ready) return;
    setState((s) => ({ ...s, stage: "downloading" }));
    downloadFile(state.ready.download_url, state.ready.filename);
    setTimeout(() => {
      setState((s) => ({ ...s, stage: "complete" }));
    }, 800);
  }, [state.ready, state.stage]);

  return {
    stage: state.stage,
    progress: state.progress,
    ready: state.ready,
    error: state.error,
    start,
    download,
    reset,
  };
}