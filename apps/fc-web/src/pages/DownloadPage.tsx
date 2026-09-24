import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Download, MapPin, Smartphone } from "lucide-react";

type AndroidRelease = {
  platform: string;
  versionName: string;
  versionCode: number;
  sha256: string;
  sizeBytes: number;
  releasedAt: string;
  downloadUrl: string;
};

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

export function DownloadPage() {
  const [release, setRelease] = useState<AndroidRelease | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/v1/app/android/latest");
        const json = await res.json();
        if (!res.ok) {
          throw new Error(json?.error?.message || "No release available");
        }
        if (!cancelled) setRelease(json.data as AndroidRelease);
      } catch (e: unknown) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Failed to load release");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="w-full max-w-md bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <div className="flex items-center justify-center gap-2 mb-6">
          <MapPin className="h-8 w-8 text-blue-600" />
          <h1 className="text-2xl font-bold text-gray-900">Field Collector</h1>
        </div>

        <div className="flex items-start gap-3 mb-6">
          <div className="rounded-lg bg-blue-50 p-2 shrink-0">
            <Smartphone className="h-5 w-5 text-blue-600" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Android app</h2>
            <p className="text-sm text-gray-500 mt-0.5">
              Download the latest APK and install it on your device. Enable
              “Install unknown apps” for your browser if prompted.
            </p>
          </div>
        </div>

        {loading && (
          <p className="text-sm text-gray-500 text-center py-6">Loading…</p>
        )}

        {!loading && error && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            {error}
          </div>
        )}

        {!loading && release && (
          <div className="flex flex-col gap-4">
            <dl className="grid grid-cols-2 gap-3 text-sm">
              <div>
                <dt className="text-gray-500">Version</dt>
                <dd className="font-medium text-gray-900">
                  {release.versionName} ({release.versionCode})
                </dd>
              </div>
              <div>
                <dt className="text-gray-500">Size</dt>
                <dd className="font-medium text-gray-900">
                  {formatBytes(release.sizeBytes)}
                </dd>
              </div>
              <div className="col-span-2">
                <dt className="text-gray-500">Released</dt>
                <dd className="font-medium text-gray-900">
                  {new Date(release.releasedAt).toLocaleString()}
                </dd>
              </div>
              <div className="col-span-2">
                <dt className="text-gray-500">SHA-256</dt>
                <dd className="font-mono text-xs text-gray-600 break-all">
                  {release.sha256}
                </dd>
              </div>
            </dl>

            <a
              href={release.downloadUrl}
              className="inline-flex items-center justify-center gap-2 rounded-lg bg-blue-600 text-white px-4 py-2.5 text-sm font-medium hover:bg-blue-700"
            >
              <Download className="h-4 w-4" />
              Download APK
            </a>
          </div>
        )}

        <p className="text-center text-sm text-gray-500 mt-8">
          <Link to="/login" className="text-blue-600 hover:underline">
            Admin sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
