import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { AreaDrawer } from "./AreaDrawer";
import { X, Pentagon, User, Users2, Calendar, Flag } from "lucide-react";

interface Props {
  projectId: string;
  projectMode: string; // "map_based" | "form_collection"
  onClose: () => void;
}

const priorities = [
  { value: "urgent", label: "Urgent", color: "text-red-600 bg-red-50 border-red-200" },
  { value: "high", label: "High", color: "text-orange-600 bg-orange-50 border-orange-200" },
  { value: "medium", label: "Medium", color: "text-yellow-700 bg-yellow-50 border-yellow-200" },
  { value: "low", label: "Low", color: "text-gray-600 bg-gray-50 border-gray-200" },
];

export function CreateAssignmentDialog({ projectId, projectMode, onClose }: Props) {
  const queryClient = useQueryClient();
  const isMapBased = projectMode === "map_based";

  const [assigneeType, setAssigneeType] = useState<"team" | "user">("user");
  const [teamId, setTeamId] = useState("");
  const [userId, setUserId] = useState("");
  const [formId, setFormId] = useState("");
  const [layerId, setLayerId] = useState("");
  const [title, setTitle] = useState("");
  const [instructions, setInstructions] = useState("");
  const [targetCount, setTargetCount] = useState(0);
  const [priority, setPriority] = useState("medium");
  const [dueDate, setDueDate] = useState("");
  const [area, setArea] = useState<any | null>(null);
  const [showAreaDrawer, setShowAreaDrawer] = useState(false);

  // Data fetches
  const { data: teams } = useQuery({ queryKey: ["projectTeams", projectId], queryFn: () => api.getProjectTeams(projectId) });
  const { data: members } = useQuery({ queryKey: ["members", projectId], queryFn: () => api.getProjectMembers(projectId) });
  const { data: forms } = useQuery({ queryKey: ["forms", projectId], queryFn: () => api.getProjectForms(projectId) });
  const { data: layers } = useQuery({
    queryKey: ["layers", projectId],
    queryFn: () => api.getProjectLayers(projectId),
    enabled: isMapBased,
  });

  const teamList = Array.isArray(teams) ? teams : [];
  const memberList = Array.isArray(members) ? members : [];
  const formList = Array.isArray(forms) ? forms : [];
  const layerList = Array.isArray(layers) ? layers : [];

  const createMutation = useMutation({
    mutationFn: () => {
      const body: any = {
        title: title || undefined,
        instructions: instructions || undefined,
        target_count: targetCount || undefined,
        priority,
        form_id: formId || undefined,
        due_date: dueDate ? new Date(dueDate).toISOString() : undefined,
      };

      if (assigneeType === "team") {
        body.team_id = teamId;
      } else {
        body.assigned_to = userId;
      }

      if (isMapBased) {
        if (layerId) body.layer_id = layerId;
        if (area) body.area = JSON.stringify(area);
      }

      return api.createAssignment(projectId, body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["assignments", projectId] });
      onClose();
    },
  });

  const canSubmit = (assigneeType === "team" ? !!teamId : !!userId);

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
        <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
            <h2 className="text-lg font-semibold text-gray-900">New Assignment</h2>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
              <X className="h-5 w-5" />
            </button>
          </div>

          {/* Body */}
          <div className="flex-1 overflow-auto p-6 flex flex-col gap-5">
            {/* Title */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Title <span className="text-gray-400 text-xs">(short name)</span>
              </label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Survey Northern Region"
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>

            {/* Assignee */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Assign To</label>
              <div className="flex gap-2 mb-2">
                <button
                  onClick={() => setAssigneeType("team")}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-sm ${
                    assigneeType === "team" ? "border-blue-500 bg-blue-50 text-blue-700" : "border-gray-200 text-gray-600"
                  }`}
                >
                  <Users2 className="h-4 w-4" /> Team
                </button>
                <button
                  onClick={() => setAssigneeType("user")}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-sm ${
                    assigneeType === "user" ? "border-blue-500 bg-blue-50 text-blue-700" : "border-gray-200 text-gray-600"
                  }`}
                >
                  <User className="h-4 w-4" /> Individual
                </button>
              </div>
              {assigneeType === "team" ? (
                <select
                  value={teamId}
                  onChange={(e) => setTeamId(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="">Select a team...</option>
                  {teamList.map((pt: any) => (
                    <option key={pt.team_id} value={pt.team_id}>
                      {pt.team?.name || pt.team_id}
                    </option>
                  ))}
                </select>
              ) : (
                <select
                  value={userId}
                  onChange={(e) => setUserId(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="">Select a member...</option>
                  {memberList.map((m: any) => (
                    <option key={m.user_id} value={m.user_id}>
                      {m.user?.email || m.user_id} ({m.role})
                    </option>
                  ))}
                </select>
              )}
            </div>

            {/* Form */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Focus Form <span className="text-gray-400 text-xs">(optional — leave blank for all)</span>
              </label>
              <select
                value={formId}
                onChange={(e) => setFormId(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">All forms in project</option>
                {formList.map((f: any) => (
                  <option key={f.id} value={f.id}>{f.name}</option>
                ))}
              </select>
            </div>

            {/* Map-based only */}
            {isMapBased && (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Focus Layer <span className="text-gray-400 text-xs">(optional)</span>
                  </label>
                  <select
                    value={layerId}
                    onChange={(e) => setLayerId(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  >
                    <option value="">All layers</option>
                    {layerList.map((l: any) => (
                      <option key={l.id} value={l.id}>{l.name}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Area Boundary <span className="text-gray-400 text-xs">(optional — restricts collection within this area)</span>
                  </label>
                  <button
                    onClick={() => setShowAreaDrawer(true)}
                    className={`w-full flex items-center justify-center gap-2 rounded-lg border-2 border-dashed px-4 py-3 text-sm transition-colors ${
                      area ? "border-green-300 bg-green-50 text-green-700" : "border-gray-300 text-gray-600 hover:border-blue-300 hover:bg-blue-50"
                    }`}
                  >
                    <Pentagon className="h-4 w-4" />
                    {area ? "Area defined — click to edit" : "Draw Area on Map"}
                  </button>
                  {area && (
                    <button
                      onClick={() => setArea(null)}
                      className="text-xs text-red-500 hover:underline mt-1"
                    >
                      Remove area
                    </button>
                  )}
                </div>
              </>
            )}

            {/* Target + Priority + Due Date row */}
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Target Count</label>
                <input
                  type="number"
                  value={targetCount}
                  onChange={(e) => setTargetCount(Number(e.target.value))}
                  min={0}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  placeholder="0"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
                  <Flag className="h-3 w-3" /> Priority
                </label>
                <select
                  value={priority}
                  onChange={(e) => setPriority(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  {priorities.map((p) => (
                    <option key={p.value} value={p.value}>{p.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
                  <Calendar className="h-3 w-3" /> Due Date
                </label>
                <input
                  type="date"
                  value={dueDate}
                  onChange={(e) => setDueDate(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
            </div>

            {/* Instructions */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Instructions <span className="text-gray-400 text-xs">(detailed brief for the worker)</span>
              </label>
              <textarea
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                rows={3}
                placeholder="Go to these villages and survey household members..."
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>

            {createMutation.isError && (
              <p className="text-sm text-red-600">{(createMutation.error as Error).message}</p>
            )}
          </div>

          {/* Footer */}
          <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200 shrink-0">
            <button onClick={onClose} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
            <button
              onClick={() => createMutation.mutate()}
              disabled={!canSubmit || createMutation.isPending}
              className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
            >
              {createMutation.isPending ? "Creating..." : "Create Assignment"}
            </button>
          </div>
        </div>
      </div>

      {showAreaDrawer && (
        <AreaDrawer
          initialPolygon={area}
          onSave={(geom) => {
            setArea(geom);
            setShowAreaDrawer(false);
          }}
          onClose={() => setShowAreaDrawer(false)}
        />
      )}
    </>
  );
}