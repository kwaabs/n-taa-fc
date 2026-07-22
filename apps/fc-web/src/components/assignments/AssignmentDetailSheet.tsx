import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  X, Flag, Calendar, Users2, User, AlertTriangle, Target,
  CheckCircle2, XCircle, Clock, Trash2, UserCog
} from "lucide-react";

interface Props {
  projectId: string;
  assignmentId: string;
  onClose: () => void;
}

const priorityStyles: Record<string, string> = {
  urgent: "bg-red-100 text-red-700 border-red-200",
  high: "bg-orange-100 text-orange-700 border-orange-200",
  medium: "bg-yellow-100 text-yellow-700 border-yellow-200",
  low: "bg-gray-100 text-gray-700 border-gray-200",
};

export function AssignmentDetailSheet({ projectId, assignmentId, onClose }: Props) {
  const queryClient = useQueryClient();
  const [showReassign, setShowReassign] = useState(false);
  const [showExtendDate, setShowExtendDate] = useState(false);
  const [newAssignee, setNewAssignee] = useState({ type: "user" as "user" | "team", id: "" });
  const [newDueDate, setNewDueDate] = useState("");

  const { data: assignment, isLoading } = useQuery({
    queryKey: ["assignment", assignmentId],
    queryFn: () => api.getAssignment(projectId, assignmentId),
    enabled: !!assignmentId,
  });

  const { data: progress } = useQuery({
    queryKey: ["assignmentProgress", assignmentId],
    queryFn: () => api.getAssignmentProgress(projectId, assignmentId),
    enabled: !!assignmentId,
    refetchInterval: 10000, // refresh every 10s
  });

  const { data: members } = useQuery({
    queryKey: ["members", projectId],
    queryFn: () => api.getProjectMembers(projectId),
  });

  const { data: teams } = useQuery({
    queryKey: ["projectTeams", projectId],
    queryFn: () => api.getProjectTeams(projectId),
  });

  const memberList = Array.isArray(members) ? members : [];
  const teamList = Array.isArray(teams) ? teams : [];

  const statusMutation = useMutation({
    mutationFn: (status: string) => api.updateAssignmentStatus(projectId, assignmentId, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["assignment", assignmentId] });
      queryClient.invalidateQueries({ queryKey: ["assignments", projectId] });
    },
  });

  const reassignMutation = useMutation({
    mutationFn: () =>
      api.reassignAssignment(
        projectId,
        assignmentId,
        newAssignee.type === "user" ? newAssignee.id : null,
        newAssignee.type === "team" ? newAssignee.id : null
      ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["assignment", assignmentId] });
      queryClient.invalidateQueries({ queryKey: ["assignments", projectId] });
      setShowReassign(false);
    },
  });

  const extendMutation = useMutation({
    mutationFn: () =>
      api.extendAssignmentDueDate(
        projectId,
        assignmentId,
        newDueDate ? new Date(newDueDate).toISOString() : null
      ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["assignment", assignmentId] });
      queryClient.invalidateQueries({ queryKey: ["assignments", projectId] });
      setShowExtendDate(false);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: () => api.deleteAssignment(projectId, assignmentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["assignments", projectId] });
      onClose();
    },
  });

  const isOverdue = progress?.is_overdue;
  const computedStatus = progress?.computed_status || assignment?.status || "pending";
  const completionPct = progress?.completion_pct || 0;

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40 bg-black/30" />

      {/* Sheet */}
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-2xl bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between gap-3 px-6 py-4 border-b border-gray-200 shrink-0">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-2">
              <span className={`inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-medium ${priorityStyles[assignment?.priority] || priorityStyles.medium}`}>
                <Flag className="h-3 w-3" /> {assignment?.priority || "medium"}
              </span>
              <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs ${
                isOverdue
                  ? "bg-red-50 text-red-700"
                  : computedStatus === "completed"
                  ? "bg-green-50 text-green-700"
                  : computedStatus === "in_progress"
                  ? "bg-blue-50 text-blue-700"
                  : "bg-gray-50 text-gray-600"
              }`}>
                {isOverdue && <AlertTriangle className="h-3 w-3 mr-1" />}
                {computedStatus.replace("_", " ")}
              </span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 truncate">
              {assignment?.title || "Untitled Assignment"}
            </h2>
            {assignment?.instructions && (
              <p className="text-sm text-gray-500 mt-1">{assignment.instructions}</p>
            )}
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 shrink-0">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
          {isLoading && <p className="text-gray-500">Loading...</p>}

          {assignment && (
            <>
              {/* Quick info */}
              <div className="grid grid-cols-2 gap-3">
                <InfoTile icon={<Target className="h-4 w-4" />} label="Target">
                  {assignment.target_count || "—"}
                </InfoTile>
                <InfoTile icon={<Calendar className="h-4 w-4" />} label="Due Date">
                  {assignment.due_date ? new Date(assignment.due_date).toLocaleDateString() : "No deadline"}
                </InfoTile>
                <InfoTile
                  icon={assignment.team_id ? <Users2 className="h-4 w-4" /> : <User className="h-4 w-4" />}
                  label="Assigned to"
                >
                  {assignment.team?.name || assignment.assignee?.email || "—"}
                </InfoTile>
                <InfoTile icon={<Clock className="h-4 w-4" />} label="Last activity">
                  {progress?.last_activity_at
                    ? new Date(progress.last_activity_at).toLocaleString()
                    : "None yet"}
                </InfoTile>
              </div>

              {/* Progress */}
              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-semibold text-gray-900">Progress</h3>
                  <span className="text-sm text-gray-500">
                    {(progress?.submitted || 0) + (progress?.approved || 0) + (progress?.rejected || 0) + (progress?.under_review || 0)}
                    {assignment.target_count > 0 && " / " + assignment.target_count}
                    {" "}collected
                  </span>
                </div>
                <div className="w-full h-3 bg-gray-100 rounded-full overflow-hidden mb-3">
                  <div
                    className={`h-full transition-all ${
                      completionPct >= 100 ? "bg-green-500" : completionPct >= 75 ? "bg-blue-500" : "bg-yellow-500"
                    }`}
                    style={{ width: `${Math.min(completionPct, 100)}%` }}
                  />
                </div>
                <div className="grid grid-cols-4 gap-2 text-center text-xs">
                  <Stat color="blue" label="Submitted" value={progress?.submitted || 0} />
                  <Stat color="green" label="Approved" value={progress?.approved || 0} />
                  <Stat color="red" label="Rejected" value={progress?.rejected || 0} />
                  <Stat color="purple" label="Review" value={progress?.under_review || 0} />
                </div>
              </div>

              {/* By Worker */}
              {progress?.by_worker && progress.by_worker.length > 0 && (
                <div className="bg-white rounded-xl border border-gray-200 p-5">
                  <h3 className="font-semibold text-gray-900 mb-3">By Worker</h3>
                  <div className="flex flex-col gap-2">
                    {progress.by_worker.map((wp: any) => {
                      const total = (wp.submitted || 0) + (wp.approved || 0) + (wp.rejected || 0);
                      const pct = assignment.target_count > 0 ? (total / assignment.target_count) * 100 : 0;
                      return (
                        <div key={wp.user_id} className="border border-gray-100 rounded-lg p-3">
                          <div className="flex items-center justify-between mb-2">
                            <span className="text-sm font-medium text-gray-900">
                              {wp.email || wp.full_name || wp.user_id?.slice(0, 8)}
                            </span>
                            <span className="text-xs text-gray-500">{total} collected</span>
                          </div>
                          <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden">
                            <div className="h-full bg-blue-500" style={{ width: `${Math.min(pct, 100)}%` }} />
                          </div>
                          <div className="flex gap-3 mt-2 text-xs text-gray-500">
                            <span>📥 {wp.submitted || 0}</span>
                            <span className="text-green-600">✓ {wp.approved || 0}</span>
                            <span className="text-red-600">✗ {wp.rejected || 0}</span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Actions */}
              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <h3 className="font-semibold text-gray-900 mb-3">Actions</h3>
                <div className="flex flex-wrap gap-2">
                  {computedStatus !== "completed" && (
                    <>
                      {computedStatus === "pending" && (
                        <button
                          onClick={() => statusMutation.mutate("in_progress")}
                          className="rounded-lg bg-blue-50 px-3 py-1.5 text-sm text-blue-700 hover:bg-blue-100"
                        >
                          ▶ Mark In Progress
                        </button>
                      )}
                      <button
                        onClick={() => statusMutation.mutate("completed")}
                        className="rounded-lg bg-green-50 px-3 py-1.5 text-sm text-green-700 hover:bg-green-100"
                      >
                        <CheckCircle2 className="h-3.5 w-3.5 inline mr-1" />
                        Mark Complete
                      </button>
                      <button
                        onClick={() => setShowReassign(!showReassign)}
                        className="rounded-lg bg-purple-50 px-3 py-1.5 text-sm text-purple-700 hover:bg-purple-100"
                      >
                        <UserCog className="h-3.5 w-3.5 inline mr-1" />
                        Reassign
                      </button>
                      <button
                        onClick={() => setShowExtendDate(!showExtendDate)}
                        className="rounded-lg bg-yellow-50 px-3 py-1.5 text-sm text-yellow-700 hover:bg-yellow-100"
                      >
                        <Calendar className="h-3.5 w-3.5 inline mr-1" />
                        Extend Due Date
                      </button>
                    </>
                  )}
                  <button
                    onClick={() => {
                      if (confirm("Delete this assignment?")) deleteMutation.mutate();
                    }}
                    className="rounded-lg bg-red-50 px-3 py-1.5 text-sm text-red-700 hover:bg-red-100 ml-auto"
                  >
                    <Trash2 className="h-3.5 w-3.5 inline mr-1" />
                    Delete
                  </button>
                </div>

                {/* Reassign panel */}
                {showReassign && (
                  <div className="mt-4 border-t border-gray-100 pt-4">
                    <p className="text-sm font-medium text-gray-700 mb-2">Reassign to:</p>
                    <div className="flex gap-2 mb-2">
                      <button
                        onClick={() => setNewAssignee({ type: "user", id: "" })}
                        className={`px-3 py-1.5 text-xs rounded-lg border ${
                          newAssignee.type === "user"
                            ? "border-blue-500 bg-blue-50 text-blue-700"
                            : "border-gray-200 text-gray-600"
                        }`}
                      >
                        Individual
                      </button>
                      <button
                        onClick={() => setNewAssignee({ type: "team", id: "" })}
                        className={`px-3 py-1.5 text-xs rounded-lg border ${
                          newAssignee.type === "team"
                            ? "border-blue-500 bg-blue-50 text-blue-700"
                            : "border-gray-200 text-gray-600"
                        }`}
                      >
                        Team
                      </button>
                    </div>
                    <select
                      value={newAssignee.id}
                      onChange={(e) => setNewAssignee({ ...newAssignee, id: e.target.value })}
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm mb-2"
                    >
                      <option value="">Select...</option>
                      {newAssignee.type === "user"
                        ? memberList.map((m: any) => (
                            <option key={m.user_id} value={m.user_id}>
                              {m.user?.email || m.user_id}
                            </option>
                          ))
                        : teamList.map((pt: any) => (
                            <option key={pt.team_id} value={pt.team_id}>
                              {pt.team?.name || pt.team_id}
                            </option>
                          ))}
                    </select>
                    <button
                      onClick={() => reassignMutation.mutate()}
                      disabled={!newAssignee.id || reassignMutation.isPending}
                      className="w-full rounded-lg bg-blue-600 px-3 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
                    >
                      {reassignMutation.isPending ? "Reassigning..." : "Confirm Reassign"}
                    </button>
                  </div>
                )}

                {/* Extend Due Date panel */}
                {showExtendDate && (
                  <div className="mt-4 border-t border-gray-100 pt-4">
                    <p className="text-sm font-medium text-gray-700 mb-2">New due date:</p>
                    <input
                      type="date"
                      value={newDueDate}
                      onChange={(e) => setNewDueDate(e.target.value)}
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm mb-2"
                    />
                    <button
                      onClick={() => extendMutation.mutate()}
                      disabled={extendMutation.isPending}
                      className="w-full rounded-lg bg-blue-600 px-3 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
                    >
                      {extendMutation.isPending ? "Updating..." : "Update Due Date"}
                    </button>
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}

function InfoTile({ icon, label, children }: any) {
  return (
    <div className="rounded-lg border border-gray-200 px-3 py-2">
      <div className="flex items-center gap-1.5 text-xs text-gray-500 mb-0.5">
        {icon} {label}
      </div>
      <p className="text-sm font-medium text-gray-900 truncate">{children}</p>
    </div>
  );
}

function Stat({ color, label, value }: { color: string; label: string; value: number }) {
  const colors: Record<string, string> = {
    blue: "bg-blue-50 text-blue-700",
    green: "bg-green-50 text-green-700",
    red: "bg-red-50 text-red-700",
    purple: "bg-purple-50 text-purple-700",
  };
  return (
    <div className={`rounded-lg px-2 py-1.5 ${colors[color]}`}>
      <p className="text-lg font-bold">{value}</p>
      <p className="text-xs">{label}</p>
    </div>
  );
}