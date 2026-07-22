import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { X, User, Users2, Megaphone } from "lucide-react";

interface Props {
  projectId: string;
  onClose: () => void;
}

export function SendMessageDialog({ projectId, onClose }: Props) {
  const [audience, setAudience] = useState<"team" | "user">("team");
  const [teamId, setTeamId] = useState("");
  const [userId, setUserId] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [sentCount, setSentCount] = useState<number | null>(null);

  const { data: teams } = useQuery({
    queryKey: ["projectTeams", projectId],
    queryFn: () => api.getProjectTeams(projectId),
  });
  const { data: members } = useQuery({
    queryKey: ["members", projectId],
    queryFn: () => api.getProjectMembers(projectId),
  });

  const teamList = Array.isArray(teams) ? teams : [];
  const memberList = Array.isArray(members) ? members : [];

  const sendMutation = useMutation({
    mutationFn: () => {
      const payload: {
        title?: string;
        body: string;
        team_id?: string;
        user_id?: string;
      } = {
        body: body.trim(),
        title: title.trim() || undefined,
      };
      if (audience === "team") payload.team_id = teamId;
      else payload.user_id = userId;
      return api.sendProjectMessage(projectId, payload);
    },
    onSuccess: (res) => {
      setSentCount(res?.recipient_count ?? 0);
    },
  });

  const canSubmit =
    body.trim().length > 0 &&
    (audience === "team" ? !!teamId : !!userId) &&
    !sendMutation.isPending;

  if (sentCount !== null) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
        <div className="bg-white rounded-xl shadow-xl w-full max-w-md p-6">
          <div className="flex items-start gap-3 mb-4">
            <div className="rounded-full bg-green-50 p-2">
              <Megaphone className="h-5 w-5 text-green-700" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Message sent</h2>
              <p className="text-sm text-gray-600 mt-1">
                Delivered to {sentCount} recipient{sentCount === 1 ? "" : "s"}.
                They’ll see it in the app the next time they open it online.
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-full rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Done
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <h2 className="text-lg font-semibold text-gray-900">Send message</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 overflow-auto p-6 flex flex-col gap-5">
          <p className="text-sm text-gray-500">
            One-way notice to the field. No replies — shows in the mobile notification bell.
          </p>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Send to</label>
            <div className="flex gap-2 mb-2">
              <button
                type="button"
                onClick={() => setAudience("team")}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-sm ${
                  audience === "team"
                    ? "border-blue-500 bg-blue-50 text-blue-700"
                    : "border-gray-200 text-gray-600"
                }`}
              >
                <Users2 className="h-4 w-4" /> Team
              </button>
              <button
                type="button"
                onClick={() => setAudience("user")}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-sm ${
                  audience === "user"
                    ? "border-blue-500 bg-blue-50 text-blue-700"
                    : "border-gray-200 text-gray-600"
                }`}
              >
                <User className="h-4 w-4" /> Individual
              </button>
            </div>
            {audience === "team" ? (
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

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Subject <span className="text-gray-400 text-xs">(optional)</span>
            </label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Message from supervisor"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Message</label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={5}
              placeholder="Weather delay — start at 10am tomorrow."
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm resize-y"
            />
          </div>

          {sendMutation.isError && (
            <p className="text-sm text-red-600">
              {(sendMutation.error as Error).message}
            </p>
          )}
        </div>

        <div className="flex justify-end gap-2 px-6 py-4 border-t border-gray-200 shrink-0">
          <button
            onClick={onClose}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            disabled={!canSubmit}
            onClick={() => sendMutation.mutate()}
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            {sendMutation.isPending ? "Sending…" : "Send"}
          </button>
        </div>
      </div>
    </div>
  );
}
