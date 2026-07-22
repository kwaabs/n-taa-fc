import { useParams, NavLink, Routes, Route, Link, Navigate } from "react-router-dom";

import { ChoiceListsPage } from "@/pages/ChoiceListsPage";   // 👈 NEW import

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  ArrowLeft,
  Map as MapIcon,
  Layers as LayersIcon,
  FileText,
  BarChart2,
  Users2,
  ClipboardList,
  Settings as Cog,
  ListTree,
  Megaphone,
} from "lucide-react";

// Form-based tabs (existing behavior, unchanged)
import { ProjectOverviewPage } from "./ProjectOverviewPage";
import { ProjectFormsPage } from "./ProjectFormsPage";
import { ProjectDataPage } from "./ProjectDataPage";
import { ProjectAssignmentsPage } from "./ProjectAssignmentsPage";
import { ProjectAccessPage } from "./ProjectAccessPage";
import { ProjectLayersPage } from "./ProjectLayersPage";
import { ProjectMessagesPage } from "./ProjectMessagesPage";

// Map-based tabs (new)
import { MapTab } from "./MapTab";
import { ProjectSettingsTab } from "./ProjectSettingsTab";

const formBasedTabs = [
  { label: "Overview", path: "", icon: BarChart2 },
  { label: "Forms", path: "forms", icon: FileText },
  { label: "Data", path: "data", icon: MapIcon },
  { path: "choice-lists", label: "Choice Lists", icon: ListTree },
  { label: "Access", path: "access", icon: Users2 },
  { label: "Assignments", path: "assignments", icon: ClipboardList },
  { label: "Messages", path: "messages", icon: Megaphone },
  { label: "Settings", path: "settings", icon: Cog },   // ← add this
];

const mapBasedTabs = [
  { label: "Map", path: "", icon: MapIcon },
  { label: "Layers", path: "layers", icon: LayersIcon },
  { path: "choice-lists", label: "Choice Lists", icon: ListTree },
  { label: "Access", path: "access", icon: Users2 },
  { label: "Assignments", path: "assignments", icon: ClipboardList },
  { label: "Messages", path: "messages", icon: Megaphone },
  { label: "Settings", path: "settings", icon: Cog },
];

export function ProjectDetailPage() {
  const { projectId } = useParams();

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId!),
    enabled: !!projectId,
  });

  const isMapBased = project?.mode === "map_based";
  const tabs = isMapBased ? mapBasedTabs : formBasedTabs;

  return (
    <div className="p-6 h-full flex flex-col overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4 shrink-0">
        <Link to="/projects" className="text-gray-400 hover:text-gray-600">
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <h1 className="text-xl font-bold text-gray-900 truncate">
              {project?.name || "Loading..."}
            </h1>
            {project && (
              <span
                className={`rounded-full px-2 py-0.5 text-xs font-medium ${project.status === "active"
                    ? "bg-green-50 text-green-700"
                    : project.status === "archived"
                      ? "bg-gray-100 text-gray-500"
                      : "bg-yellow-50 text-yellow-700"
                  }`}
              >
                {project.status === "active"
                  ? "● Active"
                  : project.status === "archived"
                    ? "Archived"
                    : "Draft"}
              </span>
            )}
            {isMapBased && (
              <span className="rounded-full bg-blue-50 text-blue-700 px-2 py-0.5 text-xs">
                Map-based
              </span>
            )}
          </div>
          <p className="text-sm text-gray-500 truncate">{project?.description}</p>
        </div>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-gray-200 mb-6 shrink-0">
        {tabs.map((tab) => (
          <NavLink
            key={tab.path}
            to={
              tab.path === ""
                ? `/projects/${projectId}`
                : `/projects/${projectId}/${tab.path}`
            }
            end={tab.path === ""}
            className={({ isActive }) =>
              `flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${isActive
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              }`
            }
          >
            <tab.icon className="h-4 w-4" />
            {tab.label}
          </NavLink>
        ))}
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-hidden">
        {isMapBased ? (
          <Routes>
            <Route index element={<MapTab projectId={projectId!} />} />
            <Route path="layers" element={<ProjectLayersPage />} />
            <Route path="access" element={<ProjectAccessPage />} />
            <Route path="assignments" element={<ProjectAssignmentsPage />} />
            <Route path="messages" element={<ProjectMessagesPage />} />
            <Route path="settings" element={<ProjectSettingsTab />} />

            <Route path="choice-lists" element={<ChoiceListsPage />} />

            <Route path="*" element={<Navigate to="" replace />} />
          </Routes>
        ) : (
          <Routes>
            <Route index element={<ProjectOverviewPage />} />
            <Route path="forms" element={<ProjectFormsPage />} />
            <Route path="data" element={<ProjectDataPage />} />
            <Route path="access" element={<ProjectAccessPage />} />
            <Route path="assignments" element={<ProjectAssignmentsPage />} />
            <Route path="messages" element={<ProjectMessagesPage />} />
            <Route path="choice-lists" element={<ChoiceListsPage />} />
            <Route path="settings" element={<ProjectSettingsTab />} />   {/* ← add this */}
            <Route path="*" element={<Navigate to="" replace />} />
          </Routes>
        )}
      </div>
    </div>
  );
}