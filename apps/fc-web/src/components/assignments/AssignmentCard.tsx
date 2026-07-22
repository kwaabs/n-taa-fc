import { Flag, Calendar, Users2, User, AlertTriangle } from "lucide-react";

const priorityStyles: Record<string, string> = {
  urgent: "bg-red-100 text-red-700 border-red-200",
  high: "bg-orange-100 text-orange-700 border-orange-200",
  medium: "bg-yellow-100 text-yellow-700 border-yellow-200",
  low: "bg-gray-100 text-gray-700 border-gray-200",
};

const statusStyles: Record<string, string> = {
  pending: "bg-gray-50 text-gray-600",
  in_progress: "bg-blue-50 text-blue-700",
  completed: "bg-green-50 text-green-700",
  overdue: "bg-red-50 text-red-700",
  cancelled: "bg-gray-100 text-gray-500",
};

interface Props {
  assignment: any;
  onClick: () => void;
}

function computeStatus(a: any): string {
  if (a.status === "completed") return "completed";
  if (a.due_date && new Date(a.due_date) < new Date()) return "overdue";
  return a.status;
}

export function AssignmentCard({ assignment, onClick }: Props) {
  const status = computeStatus(assignment);
  const isOverdue = status === "overdue";

  const assigneeName = assignment.team?.name
    ? assignment.team.name
    : assignment.assignee?.email || assignment.assignee?.full_name || "—";
  const isTeam = !!assignment.team_id;

  return (
    <div
      onClick={onClick}
      className={`bg-white rounded-xl border p-4 cursor-pointer hover:shadow-md transition-shadow ${
        isOverdue ? "border-red-300" : "border-gray-200"
      }`}
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex items-start gap-2 flex-1 min-w-0">
          <span className={`inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-medium ${priorityStyles[assignment.priority] || priorityStyles.medium}`}>
            <Flag className="h-3 w-3" /> {assignment.priority || "medium"}
          </span>
          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs ${statusStyles[status]}`}>
            {isOverdue && <AlertTriangle className="h-3 w-3 mr-1" />}
            {status.replace("_", " ")}
          </span>
        </div>
      </div>

      <h3 className="font-semibold text-gray-900 mb-1 truncate">
        {assignment.title || "Untitled Assignment"}
      </h3>

      {assignment.instructions && (
        <p className="text-sm text-gray-500 mb-3 line-clamp-2">{assignment.instructions}</p>
      )}

      <div className="flex flex-wrap items-center gap-3 text-xs text-gray-500">
        <span className="flex items-center gap-1">
          {isTeam ? <Users2 className="h-3.5 w-3.5" /> : <User className="h-3.5 w-3.5" />}
          {assigneeName}
        </span>

        {assignment.target_count > 0 && (
          <span className="flex items-center gap-1">
            🎯 Target: {assignment.target_count}
          </span>
        )}

        {assignment.due_date && (
          <span className={`flex items-center gap-1 ${isOverdue ? "text-red-600 font-medium" : ""}`}>
            <Calendar className="h-3.5 w-3.5" />
            Due {new Date(assignment.due_date).toLocaleDateString()}
          </span>
        )}

        {assignment.area && (
          <span className="flex items-center gap-1 text-blue-600">
            📍 Area defined
          </span>
        )}
      </div>
    </div>
  );
}