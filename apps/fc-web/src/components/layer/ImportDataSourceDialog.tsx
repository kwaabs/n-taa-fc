import { useState, useRef } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  FileText, Link as LinkIcon, Database as DbIcon, Upload, X,
  AlertCircle, CheckCircle2,
} from "lucide-react";

interface Props {
  projectId: string;
  layerId: string;
  onClose: () => void;
}

type ImportType = "file" | "url" | "database";

export function ImportDataSourceDialog({ projectId, layerId, onClose }: Props) {
  const queryClient = useQueryClient();
  const [importType, setImportType] = useState<ImportType>("file");
  const [name, setName] = useState("");
  const [result, setResult] = useState<any | null>(null);

  // File state
  const [file, setFile] = useState<File | null>(null);
  const [fileFormat, setFileFormat] = useState<"geojson" | "csv">("geojson");
  const fileInputRef = useRef<HTMLInputElement>(null);

  // URL state
  const [url, setUrl] = useState("");
  const [urlFormat, setUrlFormat] = useState<"geojson" | "csv">("geojson");

  // Database state
  const [dbHost, setDbHost] = useState("");
  const [dbPort, setDbPort] = useState(5432);
  const [dbName, setDbName] = useState("");
  const [dbPassword, setDbPassword] = useState("");
  const [dbQuery, setDbQuery] = useState("SELECT id, name, latitude, longitude FROM points LIMIT 1000");
  const [dbLatCol, setDbLatCol] = useState("latitude");
  const [dbLngCol, setDbLngCol] = useState("longitude");
  const [dbIdCol, setDbIdCol] = useState("id");

  const fileMutation = useMutation({
    mutationFn: async () => {
      if (!file) throw new Error("Please select a file");
      return api.uploadDataSourceFile(projectId, layerId, file, name || file.name, fileFormat);
    },
    onSuccess: (data: any) => {
      setResult({ success: true, stats: data?.stats, name: data?.data_source?.name });
      queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layerSummary", layerId] });
    },
    onError: (err: Error) => {
      setResult({ success: false, error: err.message });
    },
  });

  const createAndSyncMutation = useMutation({
    mutationFn: async () => {
      let payload: any = { name, source_type: importType };
      if (importType === "url") {
        if (!url) throw new Error("URL is required");
        payload.config = { url, format: urlFormat };
      } else if (importType === "database") {
        if (!dbHost || !dbName || !dbQuery) throw new Error("Host, database, and query are required");
        payload.config = {
          driver: "postgres",
          host: dbHost,
          port: dbPort,
          database: dbName,
          query: dbQuery,
          lat_column: dbLatCol,
          lng_column: dbLngCol,
          id_column: dbIdCol,
        };
        payload.credentials = dbPassword;
      }
      const created = await api.createDataSource(projectId, layerId, payload);
      // Then trigger initial sync
      const stats = await api.syncDataSource(projectId, layerId, created.id);
      return { dataSource: created, stats };
    },
    onSuccess: (data: any) => {
      setResult({ success: true, stats: data.stats, name: data.dataSource.name });
      queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layerSummary", layerId] });
    },
    onError: (err: Error) => {
      setResult({ success: false, error: err.message });
    },
  });

  const handleSubmit = () => {
    setResult(null);
    if (importType === "file") {
      fileMutation.mutate();
    } else {
      createAndSyncMutation.mutate();
    }
  };

  const isPending = fileMutation.isPending || createAndSyncMutation.isPending;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setFile(f);
    if (!name) setName(f.name.replace(/\.[^.]+$/, ""));
    if (f.name.toLowerCase().endsWith(".csv")) setFileFormat("csv");
    else setFileFormat("geojson");
  };

  const tabBtn = (t: ImportType, label: string, Icon: any) => (
    <button
      key={t}
      onClick={() => { setImportType(t); setResult(null); }}
      className={`flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm transition-colors ${
        importType === t
          ? "bg-blue-50 text-blue-700 font-medium border border-blue-200"
          : "text-gray-600 hover:bg-gray-50 border border-transparent"
      }`}
    >
      <Icon className="h-4 w-4" />
      {label}
    </button>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <div className="flex items-center gap-3">
            <Upload className="h-5 w-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-gray-900">Add Data Source</h2>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-auto p-6 flex flex-col gap-5">
          {/* Type selector */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Source Type
            </label>
            <div className="grid grid-cols-3 gap-2">
              {tabBtn("file", "File Upload", FileText)}
              {tabBtn("url", "URL", LinkIcon)}
              {tabBtn("database", "Database", DbIcon)}
            </div>
          </div>

          {/* Name */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Name <span className="text-gray-400 text-xs">(label for this source)</span>
            </label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., 2026 Water Point Census"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          {/* File panel */}
          {importType === "file" && (
            <div className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  File <span className="text-gray-400 text-xs">(.geojson, .json, .csv)</span>
                </label>
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className="cursor-pointer rounded-lg border-2 border-dashed border-gray-300 px-4 py-6 text-center hover:border-blue-400 hover:bg-blue-50/30 transition-colors"
                >
                  <Upload className="h-6 w-6 mx-auto text-gray-400 mb-2" />
                  {file ? (
                    <>
                      <p className="text-sm font-medium text-gray-900">{file.name}</p>
                      <p className="text-xs text-gray-500">
                        {(file.size / 1024).toFixed(1)} KB · Click to change
                      </p>
                    </>
                  ) : (
                    <>
                      <p className="text-sm font-medium text-gray-700">
                        Click to choose file
                      </p>
                      <p className="text-xs text-gray-500">
                        or drag & drop here
                      </p>
                    </>
                  )}
                </div>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".geojson,.json,.csv"
                  className="hidden"
                  onChange={handleFileChange}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Format</label>
                <select
                  value={fileFormat}
                  onChange={(e) => setFileFormat(e.target.value as any)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="geojson">GeoJSON</option>
                  <option value="csv">CSV (must have lat/lng or latitude/longitude columns)</option>
                </select>
              </div>

              <div className="bg-blue-50 border border-blue-100 rounded-lg p-3 text-xs text-blue-700">
                <p className="font-medium mb-1">📋 Format requirements:</p>
                <ul className="space-y-0.5 ml-4 list-disc">
                  <li><strong>GeoJSON</strong>: Standard FeatureCollection with Features. Each feature needs <code>geometry</code> and <code>properties</code></li>
                  <li><strong>CSV</strong>: Must have <code>lat</code>/<code>latitude</code>/<code>y</code> and <code>lng</code>/<code>longitude</code>/<code>x</code> columns. <code>id</code> column used as source reference for dedup</li>
                </ul>
              </div>
            </div>
          )}

          {/* URL panel */}
          {importType === "url" && (
            <div className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  URL
                </label>
                <input
                  type="url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  placeholder="https://example.com/data.geojson"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Format</label>
                <select
                  value={urlFormat}
                  onChange={(e) => setUrlFormat(e.target.value as any)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="geojson">GeoJSON</option>
                  <option value="csv">CSV</option>
                </select>
              </div>
              <div className="bg-blue-50 border border-blue-100 rounded-lg p-3 text-xs text-blue-700">
                💡 The URL is fetched live when you click "Import & Sync". You can re-sync later
                to pick up updates from the source.
              </div>
            </div>
          )}

          {/* Database panel */}
          {importType === "database" && (
            <div className="flex flex-col gap-4">
              <div className="grid grid-cols-3 gap-3">
                <div className="col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Host</label>
                  <input
                    value={dbHost}
                    onChange={(e) => setDbHost(e.target.value)}
                    placeholder="db.example.com"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Port</label>
                  <input
                    type="number"
                    value={dbPort}
                    onChange={(e) => setDbPort(Number(e.target.value))}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Database</label>
                  <input
                    value={dbName}
                    onChange={(e) => setDbName(e.target.value)}
                    placeholder="myapp_db"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Password <span className="text-gray-400 text-xs">(encrypted)</span>
                  </label>
                  <input
                    type="password"
                    value={dbPassword}
                    onChange={(e) => setDbPassword(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Query <span className="text-gray-400 text-xs">(SELECT only — read-only enforced)</span>
                </label>
                <textarea
                  value={dbQuery}
                  onChange={(e) => setDbQuery(e.target.value)}
                  rows={4}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  placeholder="SELECT id, name, latitude, longitude, status FROM water_points WHERE region = 'north' LIMIT 5000"
                />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">ID Column</label>
                  <input
                    value={dbIdCol}
                    onChange={(e) => setDbIdCol(e.target.value)}
                    placeholder="id"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Lat Column</label>
                  <input
                    value={dbLatCol}
                    onChange={(e) => setDbLatCol(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Lng Column</label>
                  <input
                    value={dbLngCol}
                    onChange={(e) => setDbLngCol(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
                  />
                </div>
              </div>

              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 text-xs text-yellow-700 flex items-start gap-2">
                <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                <div>
                  <p className="font-medium">Security note</p>
                  <p className="mt-0.5">
                    Only SELECT queries are accepted. Password is encrypted at rest with the server's
                    JWT secret. Use a read-only database user for additional safety.
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Result */}
          {result && result.success && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <CheckCircle2 className="h-5 w-5 text-green-600" />
                <p className="text-sm font-medium text-green-900">
                  Imported successfully!
                </p>
              </div>
              {result.stats && (
                <div className="grid grid-cols-4 gap-2 text-xs text-green-700">
                  <Stat label="Total" value={result.stats.total} />
                  <Stat label="Inserted" value={result.stats.inserted} />
                  <Stat label="Unchanged" value={result.stats.unchanged} />
                  <Stat label="Errors" value={result.stats.errors} />
                </div>
              )}
            </div>
          )}

          {result && !result.success && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-700">
              <p className="font-medium mb-1">Import failed</p>
              <p className="font-mono text-xs">{result.error}</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200 shrink-0">
          <p className="text-xs text-gray-400">
            {importType === "file" && "File is processed and dropped — re-upload to re-sync"}
            {importType === "url" && "URL is saved — sync can be re-run anytime"}
            {importType === "database" && "Connection saved — sync can be re-run anytime"}
          </p>
          <div className="flex gap-3">
            <button onClick={onClose} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">
              {result?.success ? "Close" : "Cancel"}
            </button>
            {!result?.success && (
              <button
                onClick={handleSubmit}
                disabled={isPending}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50 flex items-center gap-1.5"
              >
                <Upload className="h-4 w-4" />
                {isPending ? "Importing..." : "Import & Sync"}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded bg-white border border-green-100 px-2 py-1">
      <p className="text-lg font-bold text-green-900">{value || 0}</p>
      <p className="text-[10px] uppercase tracking-wider">{label}</p>
    </div>
  );
}