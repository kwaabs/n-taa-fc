import { useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import {
  X, ArrowLeft, ArrowRight, Check,
  Plug, Database, Settings as Cog, FileText, Play,
} from "lucide-react";
import type {
  ConnectionRef, DiscoveredTable, TableConfig, ImportJob,
} from "./types";
import { StepConnect } from "./StepConnect";
import { StepDiscover } from "./StepDiscover";
import { StepConfigure } from "./StepConfigure";
import { StepReview } from "./StepReview";
import { StepRun } from "./StepRun";

interface Props {
  projectId: string;
  onClose: () => void;
}

interface WizardState {
  connection: ConnectionRef | null;
  testedVersion: string;
  discovered: DiscoveredTable[];
  selectedTables: string[];        // qualified_names
  configs: Record<string, TableConfig>;  // keyed by qualified_name
  /** "link" = register only; "copy" = materialize into public.features (default) */
  importMode: "link" | "copy";
  job: ImportJob | null;
}

const steps = [
  { id: 1, title: "Connect", icon: Plug },
  { id: 2, title: "Discover", icon: Database },
  { id: 3, title: "Configure", icon: Cog },
  { id: 4, title: "Review", icon: FileText },
  { id: 5, title: "Run", icon: Play },
];

export function ImportWizard({ projectId, onClose }: Props) {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);

  const [state, setState] = useState<WizardState>({
    connection: null,
    testedVersion: "",
    discovered: [],
    selectedTables: [],
    configs: {},
    importMode: "link",
    job: null,
  });

  const update = (patch: Partial<WizardState>) =>
    setState((p) => ({ ...p, ...patch }));

  const onJobUpdated = useCallback((job: ImportJob) => {
    setState((p) => {
      if (
        p.job?.id === job.id &&
        p.job?.status === job.status &&
        p.job?.updated_at === job.updated_at &&
        p.job?.progress?.current === job.progress?.current
      ) {
        return p;
      }
      return { ...p, job };
    });
  }, []);

  const canProceed = () => {
    switch (step) {
      case 1:
        return !!state.connection && !!state.testedVersion;
      case 2:
        return state.selectedTables.length > 0;
      case 3:
        // Every selected table must have a layer_name + id_column
        return state.selectedTables.every((qn) => {
          const c = state.configs[qn];
          return c && c.layer_name.trim().length > 0 && c.id_column.trim().length > 0;
        });
      case 4:
        return true;
      case 5:
        // Show "Done" instead of Next when job is finished
        return state.job?.status === "success" ||
               state.job?.status === "partial" ||
               state.job?.status === "failed";
      default:
        return false;
    }
  };

  const goNext = () => {
    if (step < steps.length) setStep(step + 1);
  };

  const handleDone = () => {
    onClose();
    // If job succeeded, refresh the layers list
    navigate(`/projects/${projectId}/layers`);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              Import from Database
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">
              Step {step} of {steps.length} — {steps[step - 1].title}
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Progress stepper */}
        <div className="flex items-center px-6 py-3 border-b border-gray-100 shrink-0 overflow-x-auto">
          {steps.map((s, idx) => {
            const isActive = step === s.id;
            const isDone = step > s.id;
            return (
              <div key={s.id} className="flex items-center shrink-0">
                <div
                  className={`flex items-center justify-center w-7 h-7 rounded-full text-xs font-medium ${
                    isActive
                      ? "bg-blue-600 text-white"
                      : isDone
                      ? "bg-green-500 text-white"
                      : "bg-gray-200 text-gray-500"
                  }`}
                >
                  {isDone ? <Check className="h-3.5 w-3.5" /> : s.id}
                </div>
                <span
                  className={`ml-1.5 text-xs ${
                    isActive ? "font-medium text-gray-900" : "text-gray-500"
                  }`}
                >
                  {s.title}
                </span>
                {idx < steps.length - 1 && (
                  <div
                    className={`mx-2 w-6 h-0.5 ${
                      isDone ? "bg-green-500" : "bg-gray-200"
                    }`}
                  />
                )}
              </div>
            );
          })}
        </div>

        {/* Body — only the active step is mounted */}
        <div className="flex-1 overflow-y-auto p-6">
          {step === 1 && (
            <StepConnect
              projectId={projectId}
              connection={state.connection}
              testedVersion={state.testedVersion}
              onConnectionResolved={(connection, version) =>
                update({ connection, testedVersion: version })
              }
            />
          )}
          {step === 2 && state.connection && (
            <StepDiscover
              projectId={projectId}
              connection={state.connection}
              discovered={state.discovered}
              selected={state.selectedTables}
              onDiscovered={(tables) => update({ discovered: tables })}
              onSelectionChange={(qns) => update({ selectedTables: qns })}
            />
          )}
          {step === 3 && (
            <StepConfigure
              tables={state.discovered.filter((t) =>
                state.selectedTables.includes(t.qualified_name)
              )}
              configs={state.configs}
              importMode={state.importMode}
              onImportModeChange={(importMode) => update({ importMode })}
              onConfigsChange={(configs) => update({ configs })}
            />
          )}
          {step === 4 && (
            <StepReview
              tables={state.discovered.filter((t) =>
                state.selectedTables.includes(t.qualified_name)
              )}
              configs={state.configs}
              importMode={state.importMode}
            />
          )}
          {step === 5 && state.connection && (
            <StepRun
              projectId={projectId}
              connection={state.connection}
              tables={state.discovered.filter((t) =>
                state.selectedTables.includes(t.qualified_name)
              )}
              configs={state.configs}
              importMode={state.importMode}
              onJobUpdated={onJobUpdated}
            />
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200 shrink-0">
          <button
            onClick={() => step > 1 && setStep(step - 1)}
            disabled={step === 1 || step === 5}
            className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:opacity-30"
          >
            <ArrowLeft className="h-4 w-4" /> Back
          </button>

          <div className="flex items-center gap-3">
            {step < 5 && (
              <button
                onClick={goNext}
                disabled={!canProceed()}
                className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
              >
                Next <ArrowRight className="h-4 w-4" />
              </button>
            )}
            {step === 5 && (
              <button
                onClick={handleDone}
                disabled={!canProceed()}
                className="flex items-center gap-1.5 rounded-lg bg-green-600 px-4 py-2 text-sm text-white hover:bg-green-700 disabled:opacity-50"
              >
                <Check className="h-4 w-4" />
                Done
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}