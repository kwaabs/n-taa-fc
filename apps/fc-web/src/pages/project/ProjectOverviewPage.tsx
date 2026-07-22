import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { FileText, MapPin, Users2, ClipboardList } from "lucide-react";

export function ProjectOverviewPage() {
  const { projectId } = useParams();
  const { data: forms } = useQuery({ queryKey: ["forms", projectId], queryFn: () => api.getProjectForms(projectId!), enabled: !!projectId });
  const { data: features } = useQuery({ queryKey: ["features", projectId], queryFn: () => api.getProjectFeatures(projectId!, { limit: 1 }), enabled: !!projectId });
  const { data: members } = useQuery({ queryKey: ["members", projectId], queryFn: () => api.getProjectMembers(projectId!), enabled: !!projectId });
  const { data: teams } = useQuery({ queryKey: ["projectTeams", projectId], queryFn: () => api.getProjectTeams(projectId!), enabled: !!projectId });

  const formList = Array.isArray(forms) ? forms : [];
  const memberList = Array.isArray(members) ? members : [];
  const teamList = Array.isArray(teams) ? teams : [];
  const featureCount = features?.meta?.total || (Array.isArray(features) ? features.length : 0);

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="rounded-lg bg-purple-50 p-2"><FileText className="h-5 w-5 text-purple-600" /></div>
          <span className="text-sm font-medium text-gray-600">Forms</span>
        </div>
        <p className="text-3xl font-bold text-gray-900">{formList.length}</p>
      </div>
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="rounded-lg bg-blue-50 p-2"><MapPin className="h-5 w-5 text-blue-600" /></div>
          <span className="text-sm font-medium text-gray-600">Features</span>
        </div>
        <p className="text-3xl font-bold text-gray-900">{featureCount}</p>
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
          <div className="rounded-lg bg-orange-50 p-2"><ClipboardList className="h-5 w-5 text-orange-600" /></div>
          <span className="text-sm font-medium text-gray-600">Members</span>
        </div>
        <p className="text-3xl font-bold text-gray-900">{memberList.length}</p>
      </div>
    </div>
  );
}