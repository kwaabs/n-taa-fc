import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "@/lib/api";
import { FolderOpen, Users2, FileText, Plus } from "lucide-react";

export function DashboardPage() {
  const navigate = useNavigate();
  const { data: projects } = useQuery({ queryKey: ["projects"], queryFn: () => api.getProjects() });
  const { data: teams } = useQuery({ queryKey: ["teams"], queryFn: () => api.getTeams() });

  const projectList = Array.isArray(projects) ? projects : [];
  const teamList = Array.isArray(teams) ? teams : [];

  return (

  <div className="p-6 overflow-auto h-full">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-1">Welcome to Field Collector</p>
        </div>
        <button onClick={() => navigate("/projects")} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Project
        </button>
      </div>

      <div className="grid gap-4 sm:grid-cols-3 mb-8">
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="rounded-lg bg-blue-50 p-2"><FolderOpen className="h-5 w-5 text-blue-600" /></div>
            <span className="text-sm font-medium text-gray-600">Projects</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">{projectList.length}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="rounded-lg bg-green-50 p-2"><Users2 className="h-5 w-5 text-green-600" /></div>
            <span className="text-sm font-medium text-gray-600">Teams</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">{teamList.length}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="rounded-lg bg-purple-50 p-2"><FileText className="h-5 w-5 text-purple-600" /></div>
            <span className="text-sm font-medium text-gray-600">Active</span>
          </div>
          <p className="text-3xl font-bold text-gray-900">{projectList.filter((p: any) => p.status === "active" || p.status === "draft").length}</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="font-semibold text-gray-900 mb-4">Recent Projects</h2>
        {projectList.length === 0 ? (
          <p className="text-sm text-gray-400 italic">No projects yet. Create your first one!</p>
        ) : (
          <div className="flex flex-col gap-2">
            {projectList.slice(0, 5).map((p: any) => (
              <div key={p.id} onClick={() => navigate(`/projects/${p.id}`)} className="flex items-center justify-between rounded-lg border border-gray-100 px-4 py-3 hover:bg-gray-50 cursor-pointer">
                <div className="flex items-center gap-3">
                  <FolderOpen className="h-4 w-4 text-gray-400" />
                  <span className="font-medium text-gray-900">{p.name}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className={`rounded-full px-2 py-0.5 text-xs ${p.mode === "map_based" ? "bg-blue-50 text-blue-600" : "bg-green-50 text-green-600"}`}>
                    {p.mode === "map_based" ? "Map" : "Form"}
                  </span>
                  <span className="text-xs text-gray-400">v{p.version}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}