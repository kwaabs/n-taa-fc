import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "@/lib/api";
import { Plus, Users2 } from "lucide-react";

export function TeamsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");

  const { data: teams, isLoading } = useQuery({ queryKey: ["teams"], queryFn: () => api.getTeams() });
  const teamList = Array.isArray(teams) ? teams : [];

  const createMutation = useMutation({
    mutationFn: () => api.createTeam({ name, description }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["teams"] }); setShowCreate(false); setName(""); setDescription(""); },
  });

  return (
    <div className="p-6 overflow-auto h-full">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Teams</h1>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Team
        </button>
      </div>

      {isLoading && <p className="text-gray-500">Loading...</p>}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {teamList.map((t: any) => (
          <div key={t.id} onClick={() => navigate(`/teams/${t.id}`)} className="cursor-pointer rounded-xl border border-gray-200 bg-white p-5 hover:shadow-md transition-shadow">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-green-50 p-2"><Users2 className="h-5 w-5 text-green-600" /></div>
              <h3 className="font-semibold text-gray-900">{t.name}</h3>
            </div>
            <p className="text-sm text-gray-500 line-clamp-2">{t.description || "No description"}</p>
          </div>
        ))}
        {!isLoading && teamList.length === 0 && (
          <p className="text-sm text-gray-400 italic col-span-full">No teams yet. Create your first team!</p>
        )}
      </div>

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">New Team</h2>
            <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="Northern Region Team" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowCreate(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={createMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">{createMutation.isPending ? "Creating..." : "Create"}</button>
              </div>
              {createMutation.isError && <p className="text-sm text-red-600">{(createMutation.error as Error).message}</p>}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}