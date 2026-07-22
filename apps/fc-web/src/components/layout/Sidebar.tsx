import { NavLink, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  LayoutDashboard, FolderOpen, Users2, Settings, Plus, ChevronDown, ChevronRight, ShieldCheck
} from "lucide-react";
import { useState } from "react";

interface Props {
  collapsed: boolean;
}

export function Sidebar({ collapsed }: Props) {
  const navigate = useNavigate();
  const [projectsOpen, setProjectsOpen] = useState(true);

  const { data: projects } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api.getProjects(),
  });
  const projectList = Array.isArray(projects) ? projects : [];

  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
      isActive
        ? "bg-blue-50 text-blue-700 font-medium"
        : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
    } ${collapsed ? "justify-center" : ""}`;

  if (collapsed) {
    return (
      <div className="flex flex-col h-full">
        <nav className="flex flex-col gap-1 p-2">
          <NavLink to="/" end className={linkClass} title="Dashboard">
            <LayoutDashboard className="h-4 w-4 shrink-0" />
          </NavLink>
          <NavLink to="/projects" className={linkClass} title="Projects">
            <FolderOpen className="h-4 w-4 shrink-0" />
          </NavLink>
          <NavLink to="/teams" className={linkClass} title="Teams">
            <Users2 className="h-4 w-4 shrink-0" />
          </NavLink>
        </nav>
        <div className="mt-auto p-2">
          <NavLink to="/settings" className={linkClass} title="Settings">
            <Settings className="h-4 w-4 shrink-0" />
          </NavLink>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <nav className="flex flex-col gap-1 p-3">
        <NavLink to="/" end className={linkClass}>
          <LayoutDashboard className="h-4 w-4 shrink-0" />
          Dashboard
        </NavLink>
      </nav>

      {/* Projects */}
      <div className="px-3 mt-2">
        <button
          onClick={() => setProjectsOpen(!projectsOpen)}
          className="flex items-center justify-between w-full text-xs font-semibold text-gray-400 uppercase tracking-wider px-3 py-1.5 hover:text-gray-600"
        >
          <span>Projects</span>
          <div className="flex items-center gap-1">
            <Plus
              className="h-3.5 w-3.5 cursor-pointer hover:text-blue-600"
              onClick={(e) => {
                e.stopPropagation();
                navigate("/projects");
              }}
            />
            {projectsOpen ? (
              <ChevronDown className="h-3.5 w-3.5" />
            ) : (
              <ChevronRight className="h-3.5 w-3.5" />
            )}
          </div>
        </button>

        {projectsOpen && (
          <div className="flex flex-col gap-0.5 mt-1">
            {projectList.slice(0, 10).map((p: any) => (
              <NavLink
                key={p.id}
                to={`/projects/${p.id}`}
                className={({ isActive }) =>
                  `flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm truncate transition-colors ${
                    isActive
                      ? "bg-blue-50 text-blue-700 font-medium"
                      : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                  }`
                }
              >
                <FolderOpen className="h-3.5 w-3.5 shrink-0" />
                <span className="truncate">{p.name}</span>
              </NavLink>
            ))}
            {projectList.length === 0 && (
              <p className="px-3 py-2 text-xs text-gray-400 italic">No projects yet</p>
            )}
            {projectList.length > 10 && (
              <NavLink
                to="/projects"
                className="px-3 py-1.5 text-xs text-blue-600 hover:underline"
              >
                View all ({projectList.length})
              </NavLink>
            )}
          </div>
        )}
      </div>

      {/* Manage */}
      <div className="px-3 mt-4">
        <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider px-3 py-1.5">
          Manage
        </p>
        <nav className="flex flex-col gap-0.5 mt-1">
          <NavLink to="/teams" className={linkClass}>
            <Users2 className="h-4 w-4 shrink-0" />
            Teams
          </NavLink>
          <NavLink to="/users" className={linkClass}>
            <ShieldCheck className="h-4 w-4 shrink-0" />
            Users
          </NavLink>
        </nav>
      </div>

      {/* Settings — pinned bottom */}
      <div className="mt-auto p-3 border-t border-gray-100">
        <NavLink to="/settings" className={linkClass}>
          <Settings className="h-4 w-4 shrink-0" />
          Settings
        </NavLink>
      </div>
    </div>
  );
}