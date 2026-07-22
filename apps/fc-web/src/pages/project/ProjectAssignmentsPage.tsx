import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { AssignmentCard } from "@/components/assignments/AssignmentCard";
import { CreateAssignmentDialog } from "@/components/assignments/CreateAssignmentDialog";
import { AssignmentDetailSheet } from "@/components/assignments/AssignmentDetailSheet";
import { Plus, ClipboardList } from "lucide-react";

export function ProjectAssignmentsPage() {
  const { projectId } = useParams();
  const [showCreate, setShowCreate] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [filterPriority, setFilterPriority] = useState("");
  const [filterStatus, setFilterStatus] = useState("");

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId!),
    enabled: !!projectId,
  });

  const { data: assignments, isLoading } = useQuery({
    queryKey: ["assignments", projectId],
    queryFn: () => api.getProjectAssignments(projectId!),
    enabled: !!projectId,
  });

  const list = Array.isArray(assignments) ? assignments : [];
  const filtered = list.filter((a: any) => {
    if (filterPriority && a.priority !== filterPriority) return false;
    if (filterStatus) {
      const isOverdue = a.due_date && new Date(a.due_date) < new Date() && a.status !== "completed";
      const computed = isOverdue ? "overdue" : a.status;
      if (computed !== filterStatus) return false;
    }
    return true;
  });

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between mb-4 shrink-0">
        <div className="flex items-center gap-2">
          <h2 className="text-lg font-semibold text-gray-900">Assignments</h2>
          <span className="text-sm text-gray-500">({filtered.length})</span>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={filterPriority}
            onChange={(e) => setFilterPriority(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="">All priorities</option>
            <option value="urgent">Urgent</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>

          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="">All statuses</option>
            <option value="pending">Pending</option>
            <option value="in_progress">In Progress</option>
            <option value="overdue">Overdue</option>
            <option value="completed">Completed</option>
          </select>

          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" /> New Assignment
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        {isLoading ? (
          <p className="text-gray-500">Loading...</p>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-400">
            <ClipboardList className="h-12 w-12 mb-3" />
            <p className="text-lg font-medium">No assignments yet</p>
            <p className="text-sm">
              {filterPriority || filterStatus
                ? "Try clearing filters"
                : "Click 'New Assignment' to create one"}
            </p>
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2">
            {filtered.map((a: any) => (
              <AssignmentCard
                key={a.id}
                assignment={a}
                onClick={() => setSelectedId(a.id)}
              />
            ))}
          </div>
        )}
      </div>

      {showCreate && project && (
        <CreateAssignmentDialog
          projectId={projectId!}
          projectMode={project.mode}
          onClose={() => setShowCreate(false)}
        />
      )}

      {selectedId && (
        <AssignmentDetailSheet
          projectId={projectId!}
          assignmentId={selectedId}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  );
}