import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "@/lib/api";
import { AreaDrawer } from "@/components/assignments/AreaDrawer";
import { BasemapPicker } from "./BasemapPicker";
import {
  X, ArrowRight, ArrowLeft, Check, Pentagon, FileText, Layers as LayersIcon,
  Globe, Users2, ListChecks, Sparkles, Table2,
} from "lucide-react";

interface Props {
  onClose: () => void;
}

interface WizardState {
  name: string;
  description: string;
  areaGeoJson: any | null;
  basemapId: string;
  basemapCustomUrl: string;
  firstLayerName: string;
  firstLayerGeomType: "point" | "line" | "polygon";
  firstLayerEditable: boolean;
  skipFirstLayer: boolean;
  buildFormLater: boolean;
}

const initialState: WizardState = {
  name: "",
  description: "",
  areaGeoJson: null,
  basemapId: "osm",
  basemapCustomUrl: "",
  firstLayerName: "",
  firstLayerGeomType: "point",
  firstLayerEditable: true,
  skipFirstLayer: false,
  buildFormLater: true,
};

// Area comes after First Layer / Form so AOI-from-table (districts) can use a
// linked polygon layer after create. In-wizard table pick needs a project id,
// so Settings → Select from table is the path for that.
const steps = [
  { id: 1, title: "Basics", icon: Sparkles },
  { id: 2, title: "Basemap", icon: Globe },
  { id: 3, title: "First Layer", icon: LayersIcon },
  { id: 4, title: "Form", icon: FileText },
  { id: 5, title: "Area", icon: Pentagon },
  { id: 6, title: "Teams", icon: Users2 },
  { id: 7, title: "Review", icon: ListChecks },
];

export function MapProjectWizard({ onClose }: Props) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [step, setStep] = useState(1);
  const [state, setState] = useState<WizardState>(initialState);
  const [showAreaDrawer, setShowAreaDrawer] = useState(false);

  const { data: teams } = useQuery({ queryKey: ["teams"], queryFn: () => api.getTeams() });
  const teamList = Array.isArray(teams) ? teams : [];

  const createMutation = useMutation({
    mutationFn: async () => {
      const config: any = {
        basemap_id: state.basemapId,
      };
      if (state.basemapId === "custom") {
        config.basemap_custom_url = state.basemapCustomUrl;
      }
      const project = await api.createProject({
        name: state.name,
        description: state.description,
        mode: "map_based",
        config,
        area_of_interest: state.areaGeoJson || undefined,
      });

      if (!state.skipFirstLayer && state.firstLayerName) {
        await api.createLayer(project.id, {
          name: state.firstLayerName,
          geometry_type: state.firstLayerGeomType,
          is_editable: state.firstLayerEditable,
          is_visible_by_default: true,
          style: {},
        });
      }

      return project;
    },
    onSuccess: (project: any) => {
      queryClient.invalidateQueries({ queryKey: ["projects"] });
      onClose();
      navigate(`/projects/${project.id}`);
    },
  });

  const canProceed = () => {
    switch (step) {
      case 1:
        return state.name.trim().length > 0;
      case 2:
        if (state.basemapId === "custom") return state.basemapCustomUrl.includes("{z}");
        return !!state.basemapId;
      case 3:
        return state.skipFirstLayer || state.firstLayerName.trim().length > 0;
      case 4:
        return true;
      case 5:
        return true; // area optional
      case 6:
        return true;
      case 7:
        return true;
      default:
        return false;
    }
  };

  const update = (patch: Partial<WizardState>) => setState((p) => ({ ...p, ...patch }));

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
        <div className="bg-white rounded-xl shadow-xl w-full max-w-3xl max-h-[90vh] flex flex-col">
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">New Map-Based Project</h2>
              <p className="text-xs text-gray-500 mt-0.5">
                Step {step} of {steps.length} — {steps[step - 1].title}
              </p>
            </div>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
              <X className="h-5 w-5" />
            </button>
          </div>

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
                      className={`mx-2 w-6 h-0.5 ${isDone ? "bg-green-500" : "bg-gray-200"}`}
                    />
                  )}
                </div>
              );
            })}
          </div>

          <div className="flex-1 overflow-y-auto p-6">
            {step === 1 && <StepBasics state={state} update={update} />}
            {step === 2 && <StepBasemap state={state} update={update} />}
            {step === 3 && <StepFirstLayer state={state} update={update} />}
            {step === 4 && <StepForm state={state} update={update} />}
            {step === 5 && (
              <StepArea
                state={state}
                update={update}
                openDrawer={() => setShowAreaDrawer(true)}
              />
            )}
            {step === 6 && <StepTeams state={state} update={update} teams={teamList} />}
            {step === 7 && <StepReview state={state} />}
          </div>

          <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200 shrink-0">
            <button
              onClick={() => step > 1 && setStep(step - 1)}
              disabled={step === 1}
              className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:opacity-30"
            >
              <ArrowLeft className="h-4 w-4" /> Back
            </button>

            <div className="flex items-center gap-3">
              {step < steps.length && (
                <button
                  onClick={() => setStep(step + 1)}
                  disabled={!canProceed()}
                  className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  Next <ArrowRight className="h-4 w-4" />
                </button>
              )}
              {step === steps.length && (
                <button
                  onClick={() => createMutation.mutate()}
                  disabled={createMutation.isPending}
                  className="flex items-center gap-1.5 rounded-lg bg-green-600 px-4 py-2 text-sm text-white hover:bg-green-700 disabled:opacity-50"
                >
                  <Check className="h-4 w-4" />
                  {createMutation.isPending ? "Creating..." : "Create Project"}
                </button>
              )}
            </div>
          </div>

          {createMutation.isError && (
            <p className="text-sm text-red-600 px-6 pb-3">
              {(createMutation.error as Error).message}
            </p>
          )}
        </div>
      </div>

      {showAreaDrawer && (
        <AreaDrawer
          initialPolygon={state.areaGeoJson}
          onSave={(geom) => {
            update({ areaGeoJson: geom });
            setShowAreaDrawer(false);
          }}
          onClose={() => setShowAreaDrawer(false)}
        />
      )}
    </>
  );
}

function StepBasics({ state, update }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Let's start with the basics. You can refine everything later.
      </p>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Project Name</label>
        <input
          value={state.name}
          onChange={(e) => update({ name: e.target.value })}
          placeholder="Water Point Inventory"
          autoFocus
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Description <span className="text-gray-400 text-xs">(optional)</span>
        </label>
        <textarea
          value={state.description}
          onChange={(e) => update({ description: e.target.value })}
          placeholder="Mapping all water points in the northern region..."
          rows={3}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
        />
      </div>
    </div>
  );
}

function StepArea({ state, update, openDrawer }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Define the project's geographic area (default map extent and assignment
        boundary).{" "}
        <span className="text-gray-400">Optional — you can skip and set it later.</span>
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <button
          type="button"
          onClick={openDrawer}
          className={`flex items-center justify-center gap-2 rounded-lg border-2 border-dashed px-4 py-8 text-sm transition-colors ${
            state.areaGeoJson
              ? "border-green-300 bg-green-50 text-green-700"
              : "border-gray-300 text-gray-600 hover:border-blue-300 hover:bg-blue-50"
          }`}
        >
          <Pentagon className="h-5 w-5" />
          {state.areaGeoJson ? "Area defined — edit drawing" : "Draw on map"}
        </button>

        <div className="flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-200 bg-gray-50 px-4 py-6 text-center">
          <Table2 className="h-5 w-5 text-gray-400" />
          <p className="text-sm font-medium text-gray-700">Select from table</p>
          <p className="text-xs text-gray-500 max-w-xs">
            After you create the project and link a polygon layer (e.g. districts),
            use <strong>Settings → Project Area → Select from table</strong>.
          </p>
        </div>
      </div>

      {state.areaGeoJson && (
        <button
          type="button"
          onClick={() => update({ areaGeoJson: null })}
          className="text-xs text-red-500 hover:underline self-start"
        >
          Clear area
        </button>
      )}
    </div>
  );
}

function StepBasemap({ state, update }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Choose the basemap shown to admins and field workers.
      </p>
      <BasemapPicker
        selectedId={state.basemapId}
        customUrl={state.basemapCustomUrl}
        onChange={(id, custom) => {
          if (id === "custom" && custom !== undefined) {
            update({ basemapId: "custom", basemapCustomUrl: custom });
          } else {
            update({ basemapId: id });
          }
        }}
      />
    </div>
  );
}

function StepFirstLayer({ state, update }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Add the first layer to your project.{" "}
        <span className="text-gray-400">You can add more layers later.</span>
      </p>

      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={state.skipFirstLayer}
          onChange={(e) => update({ skipFirstLayer: e.target.checked })}
          className="rounded border-gray-300"
        />
        Skip — I'll add layers later
      </label>

      {!state.skipFirstLayer && (
        <>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Layer Name</label>
            <input
              value={state.firstLayerName}
              onChange={(e) => update({ firstLayerName: e.target.value })}
              placeholder="Water Points"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Geometry Type</label>
            <div className="grid grid-cols-3 gap-2">
              {["point", "line", "polygon"].map((g) => (
                <button
                  key={g}
                  type="button"
                  onClick={() => update({ firstLayerGeomType: g })}
                  className={`rounded-lg border px-3 py-2 text-sm capitalize ${
                    state.firstLayerGeomType === g
                      ? "border-blue-500 bg-blue-50 text-blue-700"
                      : "border-gray-200 text-gray-600 hover:bg-gray-50"
                  }`}
                >
                  {g}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Editable Mode</label>
            <div className="flex flex-col gap-2">
              <label className="flex items-center gap-2 text-sm rounded-lg border border-gray-200 px-3 py-2 cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  checked={state.firstLayerEditable}
                  onChange={() => update({ firstLayerEditable: true })}
                />
                Workers can collect new features
              </label>
              <label className="flex items-center gap-2 text-sm rounded-lg border border-gray-200 px-3 py-2 cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  checked={!state.firstLayerEditable}
                  onChange={() => update({ firstLayerEditable: false })}
                />
                Inspect-only (read-only reference layer)
              </label>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function StepForm({ state, update }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Each layer can have a form attached for collecting attributes. You can build it now or later.
      </p>
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
        <label className="flex items-start gap-2">
          <input
            type="checkbox"
            checked={state.buildFormLater}
            onChange={(e) => update({ buildFormLater: e.target.checked })}
            className="mt-0.5 rounded border-gray-300"
          />
          <div>
            <p className="text-sm font-medium text-gray-900">Build the form later</p>
            <p className="text-xs text-gray-500 mt-1">
              After the project is created, go to the layer's settings to attach a form.
              You can also import a CSV/JSON form template.
            </p>
          </div>
        </label>
      </div>
    </div>
  );
}

function StepTeams({ teams }: any) {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-gray-600">
        Teams can be assigned to the project after creation. You currently have{" "}
        <strong>{teams.length}</strong> teams in your organization.
      </p>
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-3 text-xs text-blue-700">
        After creating the project, go to the <strong>Access</strong> tab to assign teams
        with the right roles.
      </div>
    </div>
  );
}

function StepReview({ state }: any) {
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-gray-600">Ready to create your project?</p>
      <div className="rounded-xl border border-gray-200 p-4 flex flex-col gap-2">
        <Row label="Name" value={state.name} />
        {state.description && <Row label="Description" value={state.description} />}
        <Row label="Mode" value="Map-based" />
        <Row label="Basemap" value={state.basemapId === "custom" ? "Custom URL" : state.basemapId} />
        {!state.skipFirstLayer && state.firstLayerName ? (
          <Row label="First layer" value={`${state.firstLayerName} (${state.firstLayerGeomType})`} />
        ) : (
          <Row label="First layer" value="None yet" />
        )}
        <Row label="Project area" value={state.areaGeoJson ? "Defined (drawn)" : "Not set"} />
      </div>
      <p className="text-xs text-gray-500 italic">
        To set AOI from districts: after create, link a polygon layer, then Settings →
        Project Area → Select from table.
      </p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-3 text-sm">
      <span className="text-gray-500">{label}</span>
      <span className="text-gray-900 font-medium text-right">{value}</span>
    </div>
  );
}
