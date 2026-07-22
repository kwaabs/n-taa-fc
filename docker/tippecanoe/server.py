#!/usr/bin/env python3
"""
Minimal HTTP wrapper around tippecanoe.

POST /tile with:
  - GeoJSON in request body (application/x-ndjson or application/json)
  - Query string flags: min_zoom, max_zoom, layer_name, geometry_type

Response: application/octet-stream containing .mbtiles bytes

For production, use a real WSGI framework. This is intentionally minimal for
the sidecar use case.
"""
import json
import os
import subprocess
import sys
import tempfile
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs


class TippecanoeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Print to stdout so docker compose logs picks it up
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/tile":
            self.send_response(404)
            self.end_headers()
            return

        params = parse_qs(parsed.query)
        min_zoom = int(params.get("min_zoom", ["0"])[0])
        max_zoom = int(params.get("max_zoom", ["14"])[0])
        layer_name = params.get("layer_name", ["reference_features"])[0]
        geom_type = params.get("geometry_type", ["line"])[0]

        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"empty body")
            return

        job_id = uuid.uuid4().hex
        work_dir = tempfile.mkdtemp(prefix=f"tp_{job_id}_")

        try:
            # Read GeoJSON from POST body into a file
            geojson_path = os.path.join(work_dir, "input.geojson")
            with open(geojson_path, "wb") as f:
                remaining = content_length
                while remaining > 0:
                    chunk = self.rfile.read(min(65536, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)

            output_path = os.path.join(work_dir, "output.mbtiles")

            # Build tippecanoe command
            cmd = [
                "tippecanoe",
                "-o", output_path,
                f"--minimum-zoom={min_zoom}",
                f"--maximum-zoom={max_zoom}",
                "--drop-densest-as-needed",
                "--extend-zooms-if-still-dropping",
                f"--layer={layer_name}",
                "--force",
                "--quiet",
                geojson_path,
            ]

            # Point-specific tuning
            if geom_type == "point":
                cmd.insert(-1, "--cluster-distance=50")

            self.log_message("Running tippecanoe: %s", " ".join(cmd))

            result = subprocess.run(
                cmd,
                capture_output=True,
                timeout=300,  # 5 min max
            )

            if result.returncode != 0:
                stderr = result.stderr.decode("utf-8", errors="replace")
                self.log_message("Tippecanoe failed: %s", stderr)
                self.send_response(500)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(f"tippecanoe error: {stderr}".encode())
                return

            # Read and return the .mbtiles file
            with open(output_path, "rb") as f:
                mbtiles_bytes = f.read()

            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(mbtiles_bytes)))
            self.end_headers()
            self.wfile.write(mbtiles_bytes)

            self.log_message("Generated %d bytes of mbtiles", len(mbtiles_bytes))

        except subprocess.TimeoutExpired:
            self.send_response(504)
            self.end_headers()
            self.wfile.write(b"tippecanoe timed out")
        except Exception as e:
            self.log_message("Error: %s", str(e))
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"error: {e}".encode())
        finally:
            # Cleanup temp dir
            try:
                import shutil
                shutil.rmtree(work_dir, ignore_errors=True)
            except Exception:
                pass


def main():
    port = int(os.environ.get("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), TippecanoeHandler)
    print(f"Tippecanoe HTTP server listening on port {port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()