import { useState, useEffect,useMemo } from "react";
import { useSearchParams } from "react-router-dom";
import { useQuery,useQueries } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { LayersPanel } from "@/components/map/LayersPanel";
import { FocusedMapView } from "@/components/map/FocusedMapView";
import { FeatureInspector } from "@/components/map/FeatureInspector";

import { ExportMenu } from "@/components/data/ExportMenu";

import { Map as MapIcon } from "lucide-react";

interface Props {
  projectId: string;
}

export function MapTab({ projectId }: Props) {
  const [searchParams, setSearchParams] = useSearchParams();
  const focusedLayerId = searchParams.get("focus");

  const [visibleLayers, setVisibleLayers] = useState<Record<string, boolean>>({});
  const [selectedFeature, setSelectedFeature] = useState<any | null>(null);

  const { data: layers, isError: layersError, isLoading: layersLoading } = useQuery({
    queryKey: ["layers", projectId],
    queryFn: () => api.getProjectLayers(projectId),
  });

  const layerList = Array.isArray(layers) ? layers : [];

  // Default newly arrived layers to visible (keeps toggles for existing ones)
  useEffect(() => {
    if (layerList.length === 0) return;
    setVisibleLayers((prev) => {
      let changed = false;
      const next = { ...prev };
      for (const l of layerList) {
        if (next[l.id] === undefined) {
          next[l.id] = l.is_visible_by_default !== false;
          changed = true;
        }
      }
      return changed ? next : prev;
    });
  }, [layerList]);

  const toggleLayer = (layerId: string) => {
    setVisibleLayers((p) => ({ ...p, [layerId]: !p[layerId] }));
  };

  const focusLayer = (layerId: string | null) => {
    if (layerId === null || focusedLayerId === layerId) {
      searchParams.delete("focus");
    } else {
      searchParams.set("focus", layerId);
    }
    setSearchParams(searchParams, { replace: true });
  };

  if (layersLoading) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-400 p-12">
        <MapIcon className="h-16 w-16 mb-3 animate-pulse" />
        <p className="text-sm">Loading layers…</p>
      </div>
    );
  }

  if (layersError) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-400 p-12">
        <MapIcon className="h-16 w-16 mb-3" />
        <p className="text-lg font-medium text-gray-600">Couldn’t load layers</p>
        <p className="text-sm mt-1">Refresh the page or open the Layers tab and try again.</p>
      </div>
    );
  }

  if (layerList.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-400 p-12">
        <MapIcon className="h-16 w-16 mb-3" />
        <p className="text-lg font-medium">No layers in this project yet</p>
        <p className="text-sm mt-1">
          Add layers via the Layers tab to start visualising data on the map.
        </p>
      </div>
    );
  }

  return (
    <div className="flex h-full overflow-hidden">
      {/* Left sidebar */}
      
<aside className="w-72 shrink-0 flex flex-col border-r border-gray-200 bg-white overflow-hidden">
  <div className="overflow-y-auto flex-1">
    {/* Quick export of all visible-layer features */}
    <div className="p-3 border-b border-gray-100">
      <MapExportToolbar projectId={projectId} layerIds={Object.keys(visibleLayers).filter((id) => visibleLayers[id])} />
    </div>

          <LayersPanel
            projectId={projectId}
            layers={layerList}
            visibleLayers={visibleLayers}
            focusedLayerId={focusedLayerId}
            onToggle={toggleLayer}
            onFocus={focusLayer}
          />

          {selectedFeature && (
            <div className="border-t border-gray-200 p-3">
              <FeatureInspector
                projectId={projectId}
                feature={selectedFeature}
                onClose={() => setSelectedFeature(null)}
              />
            </div>
          )}
        </div>
      </aside>

      {/* Map */}
      <div className="flex-1 overflow-hidden bg-gray-100">
        <FocusedMapView
          projectId={projectId}
          layers={layerList}
          visibleLayers={visibleLayers}
          focusedLayerId={focusedLayerId}
          onSelectFeature={setSelectedFeature}
        />
      </div>
    </div>
  );
}


function MapExportToolbar({ projectId, layerIds }: { projectId: string; layerIds: string[] }) {
  // Aggregate features from all visible layers
  const queries = layerIds.map((id) => ({
    queryKey: ["layerFeaturesAll", id],
    queryFn: () => api.getLayerFeatures(projectId, id, { limit: 2000 }),
  }));
  // Note: useQueries already imported in this file
  const results = useQueries({ queries });

  const features = useMemo(() => {
    const all: any[] = [];
    for (const r of results) {
      const list = Array.isArray(r.data) ? r.data : r.data?.data || [];
      all.push(...list);
    }
    return all;
  }, [results.map((r) => r.dataUpdatedAt).join("|")]);

  return (
    <ExportMenu
      projectId={projectId}
      features={features}
      baseName="map"
      size="sm"
    />
  );
}