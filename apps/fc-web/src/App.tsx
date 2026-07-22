import { Routes, Route, Navigate } from "react-router-dom";
import { useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { toast } from "sonner";
import { ProtectedRoute } from "./lib/auth";
import { useTokenRefresh } from "./hooks/useTokenRefresh";
import { DashboardLayout } from "./components/layout/DashboardLayout";
import { LoginPage } from "./pages/LoginPage";
import { AuthCallback } from "./pages/AuthCallback";
import { DashboardPage } from "./pages/DashboardPage";
import { ProjectsPage } from "./pages/ProjectsPage";
import { ProjectDetailPage } from "./pages/project/ProjectDetailPage";
import { FormDetailPage } from "./pages/FormDetailPage";
import { FormBuilderPage } from "./pages/FormBuilderPage";
import { LayerDetailPage } from "./pages/LayerDetailPage";
import { TeamsPage } from "./pages/TeamsPage";
import { UsersPage } from "./pages/UsersPage";
import { UserDetailPage } from "./pages/UserDetailPage";
import { TeamDetailPage } from "./pages/TeamDetailPage";
import { SettingsPage } from "./pages/SettingsPage";

export default function App() {
  // Pre-emptive token refresh in the background
  useTokenRefresh();

  // Global mutation error toasts
  const queryClient = useQueryClient();
  useEffect(() => {
    const cache = queryClient.getMutationCache();
    const unsub = cache.subscribe((event) => {
      if (event.type === "updated" && event.action?.type === "error") {
        const err = event.action.error as Error;
        if (err?.message && !err.message.includes("Session expired")) {
          toast.error(err.message);
        }
      }
    });
    return () => unsub();
  }, [queryClient]);

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/auth/callback" element={<AuthCallback />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="projects" element={<ProjectsPage />} />
        <Route path="projects/:projectId/*" element={<ProjectDetailPage />} />
        <Route
          path="projects/:projectId/forms/:formId"
          element={<FormDetailPage />}
        />
        <Route
          path="projects/:projectId/forms/:formId/edit"
          element={<FormBuilderPage />}
        />
        <Route
          path="projects/:projectId/layers/:layerId"
          element={<LayerDetailPage />}
        />
        <Route path="teams" element={<TeamsPage />} />
        <Route path="teams/:teamId" element={<TeamDetailPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:userId" element={<UserDetailPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}