import { useState } from "react";
import { useAuth } from "@/lib/auth";
import { Settings as SettingsIcon, User, Bell, Database, Shield, Info } from "lucide-react";

const sections = [
  { id: "account", label: "Account", icon: User },
  { id: "notifications", label: "Notifications", icon: Bell },
  { id: "data", label: "Data & Storage", icon: Database },
  { id: "security", label: "Security", icon: Shield },
  { id: "about", label: "About", icon: Info },
];

export function SettingsPage() {
  const { user } = useAuth();
  const [activeSection, setActiveSection] = useState("account");

  return (
    <div className="flex flex-col h-full">
      <div className="p-6 pb-4 shrink-0 border-b border-gray-200 bg-white">
        <div className="flex items-center gap-3">
          <div className="rounded-lg bg-gray-100 p-2">
            <SettingsIcon className="h-5 w-5 text-gray-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
            <p className="text-sm text-gray-500 mt-0.5">
              Manage your account and application preferences
            </p>
          </div>
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden">
        {/* Section nav */}
        <aside className="w-56 border-r border-gray-200 bg-white p-3 shrink-0 overflow-y-auto">
          <nav className="flex flex-col gap-1">
            {sections.map((s) => (
              <button
                key={s.id}
                onClick={() => setActiveSection(s.id)}
                className={`flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-colors text-left ${
                  activeSection === s.id
                    ? "bg-blue-50 text-blue-700 font-medium"
                    : "text-gray-600 hover:bg-gray-50"
                }`}
              >
                <s.icon className="h-4 w-4" />
                {s.label}
              </button>
            ))}
          </nav>
        </aside>

        {/* Section content */}
        <div className="flex-1 overflow-y-auto p-6">
          {activeSection === "account" && (
            <SectionCard title="Account" description="Your account information">
              <FieldRow label="Email">
                <p className="text-sm text-gray-900">{user?.email}</p>
              </FieldRow>
              <FieldRow label="User ID">
                <p className="text-xs text-gray-500 font-mono">{user?.id}</p>
              </FieldRow>
              <FieldRow label="Email verified">
                <p className="text-sm">
                  {user?.email_confirmed_at ? (
                    <span className="text-green-600">✓ Verified</span>
                  ) : (
                    <span className="text-yellow-600">Pending</span>
                  )}
                </p>
              </FieldRow>
              <FieldRow label="Member since">
                <p className="text-sm text-gray-700">
                  {user?.created_at ? new Date(user.created_at).toLocaleDateString() : "—"}
                </p>
              </FieldRow>
            </SectionCard>
          )}

          {activeSection === "notifications" && (
            <SectionCard title="Notifications" description="Choose what you want to be notified about">
              <ToggleRow label="New assignments" description="When you're assigned to a new task" />
              <ToggleRow label="Submission reviews" description="When your submissions are approved or rejected" />
              <ToggleRow label="Due date reminders" description="One day before assignment due dates" />
              <ToggleRow label="Sync errors" description="When mobile sync fails" />
              <p className="text-xs text-gray-400 italic mt-4">
                Notification delivery coming soon — currently in-app only.
              </p>
            </SectionCard>
          )}

          {activeSection === "data" && (
            <SectionCard title="Data & Storage" description="Manage how data is collected and stored">
              <FieldRow label="Default basemap">
                <select className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm">
                  <option>OpenStreetMap</option>
                  <option>Satellite</option>
                  <option>Terrain</option>
                </select>
              </FieldRow>
              <FieldRow label="Photo quality">
                <select className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm">
                  <option>Standard (recommended)</option>
                  <option>High</option>
                  <option>Original</option>
                </select>
              </FieldRow>
              <FieldRow label="Offline storage">
                <p className="text-sm text-gray-700">~ 0 MB used</p>
              </FieldRow>
              <button className="rounded-lg border border-red-200 bg-red-50 text-red-700 px-3 py-1.5 text-sm hover:bg-red-100">
                Clear local cache
              </button>
            </SectionCard>
          )}

          {activeSection === "security" && (
            <SectionCard title="Security" description="Manage your password and session">
              <FieldRow label="Password">
                <button className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50">
                  Change password
                </button>
              </FieldRow>
              <FieldRow label="Two-factor authentication">
                <span className="text-sm text-gray-500">Not enabled</span>
              </FieldRow>
              <FieldRow label="Active sessions">
                <p className="text-sm text-gray-700">1 active session (this device)</p>
              </FieldRow>
              <p className="text-xs text-gray-400 italic mt-4">
                More security options coming soon.
              </p>
            </SectionCard>
          )}

          {activeSection === "about" && (
            <SectionCard title="About" description="Field Collector application information">
              <FieldRow label="Application">
                <p className="text-sm text-gray-900">Field Collector</p>
              </FieldRow>
              <FieldRow label="Version">
                <p className="text-sm text-gray-700">0.1.0 (MVP)</p>
              </FieldRow>
              <FieldRow label="License">
                <p className="text-sm text-gray-700">MIT — Open Source</p>
              </FieldRow>
              <FieldRow label="API endpoint">
                <p className="text-xs text-gray-500 font-mono">http://localhost:5355</p>
              </FieldRow>
              <FieldRow label="Inspired by">
                <p className="text-sm text-gray-700">ODK, KoboToolbox, Esri Field Maps</p>
              </FieldRow>
            </SectionCard>
          )}
        </div>
      </div>
    </div>
  );
}

function SectionCard({ title, description, children }: any) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 max-w-2xl">
      <h2 className="text-lg font-semibold text-gray-900 mb-1">{title}</h2>
      <p className="text-sm text-gray-500 mb-5">{description}</p>
      <div className="flex flex-col gap-4">{children}</div>
    </div>
  );
}

function FieldRow({ label, children }: any) {
  return (
    <div className="flex items-center justify-between gap-4 py-2 border-b border-gray-100 last:border-0">
      <p className="text-sm font-medium text-gray-700">{label}</p>
      <div>{children}</div>
    </div>
  );
}

function ToggleRow({ label, description }: { label: string; description: string }) {
  const [enabled, setEnabled] = useState(true);
  return (
    <div className="flex items-center justify-between gap-4 py-2 border-b border-gray-100 last:border-0">
      <div>
        <p className="text-sm font-medium text-gray-700">{label}</p>
        <p className="text-xs text-gray-500">{description}</p>
      </div>
      <button
        onClick={() => setEnabled(!enabled)}
        className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
          enabled ? "bg-blue-600" : "bg-gray-300"
        }`}
      >
        <span
          className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
            enabled ? "translate-x-5" : "translate-x-1"
          }`}
        />
      </button>
    </div>
  );
}