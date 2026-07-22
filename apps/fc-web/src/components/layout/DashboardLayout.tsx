import { Outlet, Link } from "react-router-dom";
import { useState } from "react";
import { Sidebar } from "./Sidebar";
import { UserMenu } from "./UserMenu";
import { MapPin, Menu, X, PanelLeftClose, PanelLeftOpen } from "lucide-react";

export function DashboardLayout() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(() => {
    return localStorage.getItem("sidebar_collapsed") === "true";
  });

  const toggleCollapsed = () => {
    const next = !collapsed;
    setCollapsed(next);
    localStorage.setItem("sidebar_collapsed", String(next));
  };

  const sidebarWidth = collapsed ? "w-16" : "w-64";

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden">
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar — sticky / fixed */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 ${sidebarWidth} transform bg-white border-r border-gray-200 transition-all lg:relative lg:translate-x-0 flex flex-col ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {/* Logo header — sticky */}
        <div className="flex items-center justify-between h-14 px-3 border-b border-gray-200 shrink-0">
          <Link
            to="/"
            className="flex items-center gap-2 font-semibold text-gray-900 min-w-0"
          >
            <MapPin className="h-5 w-5 text-blue-600 shrink-0" />
            {!collapsed && <span className="truncate">Field Collector</span>}
          </Link>
          {!collapsed && (
            <button
              onClick={toggleCollapsed}
              className="hidden lg:block text-gray-400 hover:text-gray-700"
              title="Collapse sidebar"
            >
              <PanelLeftClose className="h-4 w-4" />
            </button>
          )}
          <button className="lg:hidden" onClick={() => setMobileOpen(false)}>
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Sidebar nav scroll area */}
        <div className="flex-1 overflow-y-auto">
          <Sidebar collapsed={collapsed} />
        </div>

        {/* Expand button when collapsed */}
        {collapsed && (
          <div className="border-t border-gray-200 p-2 shrink-0 hidden lg:block">
            <button
              onClick={toggleCollapsed}
              className="w-full flex items-center justify-center text-gray-400 hover:text-gray-700 py-1.5 rounded hover:bg-gray-50"
              title="Expand sidebar"
            >
              <PanelLeftOpen className="h-4 w-4" />
            </button>
          </div>
        )}
      </aside>

      {/* Main column */}
      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        {/* Header — sticky */}
        <header className="flex items-center justify-between h-14 px-4 bg-white border-b border-gray-200 shrink-0">
          <button className="lg:hidden" onClick={() => setMobileOpen(true)}>
            <Menu className="h-5 w-5" />
          </button>
          <div className="flex-1" />
          <UserMenu />
        </header>

        {/* Page content area */}
        <main className="flex-1 overflow-hidden">
          <Outlet />
        </main>
      </div>
    </div>
  );
}