import { useState } from "react";
import { toast } from "sonner";
import {
  Package,
  Download,
  X,
  Loader2,
  CheckCircle2,
  AlertTriangle,
  Info,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { useBundleDownload, type BundleStage } from "@/hooks/useBundleDownload";

interface Props {
  projectId: string;
  projectName?: string;
  onClose: () => void;
}

export function BundleDialog({ projectId, projectName, onClose }: Props) {
  const [includeRef, setIncludeRef] = useState(true);
  const [showWarnings, setShowWarnings] = useState(false);
  const bundle = useBundleDownload(projectId);

  const handleStart = async () => {
    await bundle.start(includeRef);
  };

  const handleDownload = () => {
    bundle.download();
    if (bundle.ready) {
      toast.success(`Downloading ${bundle.ready.filename}`);
    }
  };

  const handleClose = () => {
    bundle.reset();
    onClose();
  };

  const isBusy =
    bundle.stage === "requesting" ||
    bundle.stage === "queued" ||
    bundle.stage === "running" ||
    bundle.stage === "downloading";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md mx-4 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200">
          <div className="flex items-center gap-2">
            <Package className="h-5 w-5 text-blue-600" />
            <h2 className="text-base font-semibold text-gray-900">
              Download Project Bundle
            </h2>
          </div>
          <button
            onClick={handleClose}
            disabled={isBusy}
            className="text-gray-400 hover:text-gray-600 disabled:opacity-30"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-5">
          {bundle.stage === "idle" && (
            <IdleContent
              projectName={projectName}
              includeRef={includeRef}
              onIncludeRefChange={setIncludeRef}
              onStart={handleStart}
            />
          )}

          {(bundle.stage === "requesting" ||
            bundle.stage === "queued" ||
            bundle.stage === "running") && (
            <BusyContent
              stage={bundle.stage}
              progress={bundle.progress}
            />
          )}

          {(bundle.stage === "ready" ||
            bundle.stage === "downloading" ||
            bundle.stage === "complete") && (
            <ReadyContent
              ready={bundle.ready!}
              stage={bundle.stage}
              showWarnings={showWarnings}
              onToggleWarnings={() => setShowWarnings((v) => !v)}
              onDownload={handleDownload}
              onClose={handleClose}
            />
          )}

          {bundle.stage === "error" && (
            <ErrorContent
              error={bundle.error || "Something went wrong"}
              onRetry={handleStart}
              onClose={handleClose}
            />
          )}
        </div>
      </div>
    </div>
  );
}

// ── Sub-views ────────────────────────────────────────────

function IdleContent({
  projectName,
  includeRef,
  onIncludeRefChange,
  onStart,
}: {
  projectName?: string;
  includeRef: boolean;
  onIncludeRefChange: (v: boolean) => void;
  onStart: () => void;
}) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Download an offline-ready bundle of{" "}
        <span className="font-medium text-gray-900">
          {projectName || "this project"}
        </span>{" "}
        for use on mobile devices or other clients.
      </p>

      <label className="flex items-start gap-3 rounded-lg border border-gray-200 px-3 py-3 cursor-pointer hover:bg-gray-50">
        <input
          type="checkbox"
          checked={includeRef}
          onChange={(e) => onIncludeRefChange(e.target.checked)}
          className="mt-0.5"
        />
        <div className="flex-1">
          <p className="text-sm font-medium text-gray-900">
            Include reference data
          </p>
          <p className="text-xs text-gray-500 mt-0.5">
            Adds all reference features (AOI-bounded if configured). Larger
            download but works fully offline.
          </p>
        </div>
      </label>

      <button
        onClick={onStart}
        className="rounded-lg bg-blue-600 text-white text-sm font-medium px-4 py-2 hover:bg-blue-700"
      >
        Prepare Bundle
      </button>
    </div>
  );
}

function BusyContent({
  stage,
  progress,
}: {
  stage: BundleStage;
  progress: { step?: string; percent?: number } | null;
}) {
  const label =
    stage === "requesting"
      ? "Sending request..."
      : stage === "queued"
      ? "Waiting in queue..."
      : "Generating bundle...";

  const percent = progress?.percent ?? 0;
  const step = humanizeStep(progress?.step);

  return (
    <div className="flex flex-col items-center gap-4 py-4">
      <Loader2 className="h-10 w-10 text-blue-600 animate-spin" />
      <div className="text-center">
        <p className="text-sm font-medium text-gray-900">{label}</p>
        {step && <p className="text-xs text-gray-500 mt-1">{step}</p>}
      </div>
      <div className="w-full">
        <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
          <div
            className="h-full bg-blue-500 transition-all"
            style={{ width: `${percent}%` }}
          />
        </div>
        <p className="text-xs text-gray-400 text-right mt-1">{percent}%</p>
      </div>
    </div>
  );
}

function ReadyContent({
  ready,
  stage,
  showWarnings,
  onToggleWarnings,
  onDownload,
  onClose,
}: {
  ready: any;
  stage: BundleStage;
  showWarnings: boolean;
  onToggleWarnings: () => void;
  onDownload: () => void;
  onClose: () => void;
}) {
  const warnings: string[] = ready.warnings || [];
  const counts = ready.counts || {};

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2 text-green-700">
        <CheckCircle2 className="h-5 w-5" />
        <span className="text-sm font-medium">Bundle ready</span>
      </div>

      <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5">
        <p className="text-xs text-gray-500 mb-1">Filename</p>
        <p className="text-sm font-mono text-gray-900 break-all">
          {ready.filename}
        </p>
        <p className="text-xs text-gray-500 mt-1">
          {formatBytes(ready.size_bytes)}
        </p>
      </div>

      <div className="grid grid-cols-3 gap-2 text-center">
        <Stat label="Forms" value={counts.forms} />
        <Stat label="Layers" value={counts.layers} />
        <Stat label="Features" value={counts.reference_features} />
        <Stat label="Choice Lists" value={counts.choice_lists} />
        <Stat label="Assignments" value={counts.assignments} />
        <Stat label="Total" value={ready.size_bytes ? "1 file" : "—"} />
      </div>

      {warnings.length > 0 && (
        <div className="rounded-lg border border-yellow-200 bg-yellow-50 px-3 py-2">
          <button
            onClick={onToggleWarnings}
            className="flex items-center justify-between w-full text-xs text-yellow-800"
          >
            <span className="flex items-center gap-1.5">
              <AlertTriangle className="h-3.5 w-3.5" />
              {warnings.length} warning{warnings.length === 1 ? "" : "s"}
            </span>
            {showWarnings ? (
              <ChevronUp className="h-3.5 w-3.5" />
            ) : (
              <ChevronDown className="h-3.5 w-3.5" />
            )}
          </button>
          {showWarnings && (
            <ul className="mt-2 space-y-1">
              {warnings.map((w, i) => (
                <li key={i} className="text-xs text-yellow-800">
                  · {w}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className="flex gap-2">
        {stage === "complete" ? (
          <button
            onClick={onClose}
            className="flex-1 rounded-lg bg-gray-100 text-gray-700 text-sm font-medium px-4 py-2 hover:bg-gray-200"
          >
            Close
          </button>
        ) : (
          <>
            <button
              onClick={onClose}
              className="rounded-lg border border-gray-300 text-gray-700 text-sm px-4 py-2 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={onDownload}
              disabled={stage === "downloading"}
              className="flex-1 flex items-center justify-center gap-2 rounded-lg bg-blue-600 text-white text-sm font-medium px-4 py-2 hover:bg-blue-700 disabled:opacity-50"
            >
              {stage === "downloading" ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Download className="h-4 w-4" />
              )}
              {stage === "downloading" ? "Downloading..." : "Download Now"}
            </button>
          </>
        )}
      </div>
    </div>
  );
}

function ErrorContent({
  error,
  onRetry,
  onClose,
}: {
  error: string;
  onRetry: () => void;
  onClose: () => void;
}) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start gap-2 text-red-700">
        <AlertTriangle className="h-5 w-5 mt-0.5" />
        <div>
          <p className="text-sm font-medium">Bundle generation failed</p>
          <p className="text-xs text-red-600 mt-1 font-mono">{error}</p>
        </div>
      </div>
      <div className="flex gap-2">
        <button
          onClick={onClose}
          className="rounded-lg border border-gray-300 text-gray-700 text-sm px-4 py-2 hover:bg-gray-50"
        >
          Close
        </button>
        <button
          onClick={onRetry}
          className="flex-1 rounded-lg bg-blue-600 text-white text-sm font-medium px-4 py-2 hover:bg-blue-700"
        >
          Try Again
        </button>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded-lg border border-gray-200 px-2 py-1.5">
      <p className="text-lg font-semibold text-gray-900">{value ?? 0}</p>
      <p className="text-xs text-gray-500">{label}</p>
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────

function formatBytes(n?: number): string {
  if (!n) return "0 B";
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(2)} MB`;
}

function humanizeStep(step?: string): string {
  if (!step) return "";
  const map: Record<string, string> = {
    starting: "Initializing",
    project_meta: "Reading project metadata",
    forms: "Packaging forms",
    layers: "Packaging layers",
    choice_lists: "Packaging choice lists",
    assignments: "Packaging assignments",
    manifest: "Finalizing manifest",
    uploading: "Uploading to storage",
    complete: "Complete",
  };
  if (map[step]) return map[step];
  if (step.startsWith("ref_features_")) return "Bundling reference features";
  return step;
}