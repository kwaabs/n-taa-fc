import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { LayerDataSourcesTab } from "@/components/layer/LayerDataSourcesTab";
import { LayerChangeSummary } from "@/components/layer/LayerChangeSummary";
import { LayerFeaturesTab } from "@/components/layer/LayerFeaturesTab";
import { LayerPublishBanner } from "@/components/layer/LayerPublishBanner";
import { StyleEditor } from "@/components/style/StyleEditor";
import { LayerConflictsTab } from "@/components/layer/LayerConflictsTab";

import {
  ArrowLeft, Layers, Database, MapPin, Settings as Cog, Map as MapIcon,
  ListChecks, AlertCircle,
} from "lucide-react";
import { LayerFieldsTab } from "@/components/layer/LayerFieldsTab";

const tabs = [
  { id: "overview", label: "Overview",    icon: Layers },
  { id: "fields",   label: "Fields",      icon: ListChecks },
  { id: "sources",  label: "Data Sources", icon: Database },
  { id: "features", label: "Features",    icon: MapPin },
  
  { id: "conflicts", label: "Conflicts",   icon: AlertCircle },  // 👈 NEW

  { id: "settings", label: "Style",       icon: Cog },
];

export function LayerDetailPage() {
  const { projectId, layerId } = useParams();
  const [activeTab, setActiveTab] = useState("overview");

  const { data: layer } = useQuery({
    queryKey: ["layer", layerId],
    queryFn: () => api.getLayer(projectId!, layerId!),
    enabled: !!layerId,
  });

  return (
    <div className="p-6 h-full flex flex-col overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4 shrink-0">
        <Link
          to={`/projects/${projectId}/layers`}
          className="text-gray-400 hover:text-gray-600"
        >
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex items-center gap-3 flex-1 min-w-0">
          <div className="rounded-lg bg-blue-50 p-2">
            <Layers className="h-5 w-5 text-blue-600" />
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="text-xl font-bold text-gray-900 truncate">
              {layer?.name || "Loading..."}
            </h1>
            <p className="text-sm text-gray-500">
              <span className="font-mono bg-gray-100 px-1.5 py-0.5 rounded">
                {layer?.geometry_type || "—"}
              </span>{" "}
              · Source: {layer?.source_type || "collection"}
            </p>
          </div>
        </div>
        <Link
  to={`/projects/${projectId}?focus=${layerId}`}
  className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 shrink-0"
  title="View this layer on the project map"
>
  <MapIcon className="h-4 w-4" />
  View on Project Map
</Link>
      </div>

      {/* Publish banner */}
      {layer && (
        <div className="mb-4 shrink-0">
          <LayerPublishBanner projectId={projectId!} layer={layer} />
        </div>
      )}

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-gray-200 mb-6 shrink-0">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.id
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            }`}
          >
            <tab.icon className="h-4 w-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content — Fields fills height as 2 columns; other tabs scroll */}
      <div
        className={
          activeTab === "fields"
            ? "flex-1 min-h-0 overflow-hidden"
            : "flex-1 min-h-0 overflow-y-auto"
        }
      >
        {activeTab === "overview" && (
          <LayerChangeSummary
            projectId={projectId!}
            layerId={layerId!}
            layer={layer}
          />
        )}
{activeTab === "conflicts" && (
  <LayerConflictsTab projectId={projectId!} layerId={layerId!} />
)}
        
        {activeTab === "fields" && (
          <LayerFieldsTab
            projectId={projectId!}
            layerId={layerId!}
            formId={layer?.form_id}
          />
        )}


        {activeTab === "sources" && (
          <LayerDataSourcesTab
            projectId={projectId!}
            layerId={layerId!}
            layer={layer}
          />
        )}

        {activeTab === "features" && (
          <LayerFeaturesTab
            projectId={projectId!}
            layerId={layerId!}
            layer={layer}
          />
        )}

        {activeTab === "settings" && (
          <StyleEditor projectId={projectId!} layerId={layerId!} />
        )}
      </div>
    </div>
  );
}