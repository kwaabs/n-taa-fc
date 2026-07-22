import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, CheckCircle2, AlertCircle, Save, Trash2, Home } from "lucide-react";
import type { ConnectionRef, InlineConnection } from "./types";

interface Props {
  projectId: string;
  connection: ConnectionRef | null;
  testedVersion: string;
  onConnectionResolved: (connection: ConnectionRef, version: string) => void;
}

const blankConn: InlineConnection = {
  host: "",
  port: 5432,
  database: "",
  username: "",
  password: "",
  ssl_mode: "disable",
};

export function StepConnect({ projectId, connection, testedVersion, onConnectionResolved }: Props) {
  const queryClient = useQueryClient();

  const [mode, setMode] = useState<"saved" | "new">("new");
  const [selectedId, setSelectedId] = useState<string>(connection?.connection_id || "");
  const [profileName, setProfileName] = useState("");
  const [showSavePrompt, setShowSavePrompt] = useState(false);
  const [homeApplied, setHomeApplied] = useState(false);

  const [inline, setInline] = useState<InlineConnection>(
    connection?.inline || blankConn
  );

  const { data: profiles } = useQuery({
    queryKey: ["connections", projectId],
    queryFn: () => api.getProjectConnections(projectId),
  });
  const profileList = Array.isArray(profiles) ? profiles : [];

  useEffect(() => {
    if (profileList.length > 0 && !connection && mode === "new") {
      setMode("saved");
      setSelectedId(profileList[0].id);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profileList.length]);

  const buildRef = (): ConnectionRef => {
    if (mode === "saved" && selectedId) {
      return { connection_id: selectedId };
    }
    return { inline };
  };

  const testMutation = useMutation({
    mutationFn: () => api.testConnection(projectId, buildRef()),
    onSuccess: (result: any) => {
      onConnectionResolved(buildRef(), result.version);
      if (mode === "new") setShowSavePrompt(true);
    },
  });

  const homeMutation = useMutation({
    mutationFn: () => api.getHomeConnection(projectId),
    onSuccess: (home) => {
      setMode("new");
      setInline({
        host: home.host,
        port: home.port,
        database: home.database,
        username: home.username,
        password: home.password,
        ssl_mode: home.ssl_mode || "disable",
      });
      setHomeApplied(true);
      setShowSavePrompt(false);
    },
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      api.saveProjectConnection(projectId, {
        name: profileName,
        host: inline.host,
        port: inline.port,
        database: inline.database,
        username: inline.username,
        password: inline.password,
        ssl_mode: inline.ssl_mode,
      }),
    onSuccess: (saved: any) => {
      queryClient.invalidateQueries({ queryKey: ["connections", projectId] });
      setMode("saved");
      setSelectedId(saved.id);
      setShowSavePrompt(false);
      setProfileName("");
      onConnectionResolved({ connection_id: saved.id }, testedVersion);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.deleteProjectConnection(projectId, id),
    onSuccess: (_data, id) => {
      queryClient.invalidateQueries({ queryKey: ["connections", projectId] });
      if (selectedId === id) setSelectedId("");
    },
  });

  const setField = (key: keyof InlineConnection, value: any) => {
    setHomeApplied(false);
    setInline((p) => ({ ...p, [key]: value }));
  };

  return (
    <div className="flex flex-col gap-5">
      <p className="text-sm text-gray-600">
        Choose a saved connection or enter new credentials. Passwords are stored encrypted.
      </p>

      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => homeMutation.mutate()}
          disabled={homeMutation.isPending}
          className={`flex items-center justify-center gap-1.5 rounded-lg border-2 px-3 py-2 text-sm transition-colors disabled:opacity-50 ${
            homeApplied
              ? "border-emerald-500 bg-emerald-50 text-emerald-800"
              : "border-gray-200 text-gray-800 hover:border-emerald-400 hover:bg-emerald-50/50"
          }`}
          title="This app's database (shared ntaafc)"
        >
          <Home className="h-3.5 w-3.5 shrink-0" />
          <span className="font-medium">
            {homeMutation.isPending ? "…" : "Home"}
          </span>
        </button>
        <button
          type="button"
          onClick={() => {
            setMode("saved");
            setHomeApplied(false);
          }}
          disabled={profileList.length === 0}
          className={`flex-1 rounded-lg border-2 px-3 py-2 text-sm transition-colors disabled:opacity-50 ${
            mode === "saved" && !homeApplied
              ? "border-blue-500 bg-blue-50 text-blue-700"
              : "border-gray-200 text-gray-700 hover:border-blue-300"
          }`}
        >
          Saved Profiles ({profileList.length})
        </button>
        <button
          type="button"
          onClick={() => {
            setMode("new");
            setHomeApplied(false);
          }}
          className={`shrink-0 rounded-lg border-2 px-2.5 py-2 text-sm transition-colors ${
            mode === "new" && !homeApplied
              ? "border-blue-500 bg-blue-50 text-blue-700"
              : "border-gray-200 text-gray-700 hover:border-blue-300"
          }`}
          title="New Connection"
        >
          <Plus className="h-4 w-4" />
        </button>
      </div>
      {homeMutation.isError && (
        <p className="text-xs text-red-600 -mt-3">
          {(homeMutation.error as Error).message}
        </p>
      )}

      {mode === "saved" && (
        <div className="flex flex-col gap-2">
          {profileList.map((p: any) => (
            <label
              key={p.id}
              className={`flex items-center gap-3 rounded-lg border px-3 py-2 cursor-pointer transition-colors ${
                selectedId === p.id
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-200 hover:bg-gray-50"
              }`}
            >
              <input
                type="radio"
                name="connection"
                checked={selectedId === p.id}
                onChange={() => setSelectedId(p.id)}
              />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900">{p.name}</p>
                <p className="text-xs text-gray-500 font-mono truncate">
                  {p.username}@{p.host}:{p.port}/{p.database}
                </p>
              </div>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  if (confirm(`Delete profile "${p.name}"?`)) deleteMutation.mutate(p.id);
                }}
                className="text-gray-400 hover:text-red-500"
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </label>
          ))}
        </div>
      )}

      {mode === "new" && (
        <div className="grid grid-cols-3 gap-3">
          <div className="col-span-2">
            <label className="block text-xs font-medium text-gray-600 mb-1">Host</label>
            <input
              value={inline.host}
              onChange={(e) => setField("host", e.target.value)}
              placeholder="db.example.com"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Port</label>
            <input
              type="number"
              value={inline.port}
              onChange={(e) => setField("port", Number(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Database</label>
            <input
              value={inline.database}
              onChange={(e) => setField("database", e.target.value)}
              placeholder="mydb"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Username</label>
            <input
              value={inline.username}
              onChange={(e) => setField("username", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Password</label>
            <input
              type="password"
              value={inline.password}
              onChange={(e) => setField("password", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          <div className="col-span-3">
            <label className="block text-xs font-medium text-gray-600 mb-1">SSL Mode</label>
            <select
              value={inline.ssl_mode}
              onChange={(e) => setField("ssl_mode", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
            >
              <option value="disable">disable</option>
              <option value="require">require</option>
              <option value="verify-ca">verify-ca</option>
              <option value="verify-full">verify-full</option>
            </select>
          </div>
        </div>
      )}

      <div className="border-t border-gray-100 pt-4 flex items-center gap-3">
        <button
          type="button"
          onClick={() => testMutation.mutate()}
          disabled={
            testMutation.isPending ||
            (mode === "saved" && !selectedId) ||
            (mode === "new" && (!inline.host || !inline.database || !inline.username))
          }
          className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {testMutation.isPending ? "Testing..." : "Test Connection"}
        </button>

        {testMutation.isError && (
          <div className="flex items-center gap-1.5 text-sm text-red-600">
            <AlertCircle className="h-4 w-4" />
            <span className="font-mono text-xs">
              {(testMutation.error as Error).message}
            </span>
          </div>
        )}

        {testedVersion && !testMutation.isError && (
          <div className="flex items-center gap-1.5 text-sm text-green-700">
            <CheckCircle2 className="h-4 w-4" />
            <span className="text-xs">Connected — {testedVersion.split(" on")[0]}</span>
          </div>
        )}
      </div>

      {showSavePrompt && mode === "new" && (
        <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
          <p className="text-sm font-medium text-blue-900 mb-2">
            Save this connection as a reusable profile?
          </p>
          <div className="flex gap-2">
            <input
              value={profileName}
              onChange={(e) => setProfileName(e.target.value)}
              placeholder="e.g., Main GIS DB"
              className="flex-1 rounded-lg border border-blue-300 px-3 py-2 text-sm"
            />
            <button
              type="button"
              onClick={() => saveMutation.mutate()}
              disabled={!profileName.trim() || saveMutation.isPending}
              className="rounded-lg bg-blue-600 px-3 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50 flex items-center gap-1"
            >
              <Save className="h-3.5 w-3.5" />
              {saveMutation.isPending ? "Saving..." : "Save"}
            </button>
            <button
              type="button"
              onClick={() => setShowSavePrompt(false)}
              className="rounded-lg border border-blue-300 px-3 py-2 text-sm text-blue-700"
            >
              Skip
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
