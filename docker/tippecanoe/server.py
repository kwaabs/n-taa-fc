#!/usr/bin/env python3
"""
Minimal HTTP wrapper around tippecanoe.

POST /tile with:
  - GeoJSON / NDJSON in request body (application/x-ndjson or application/json)
  - Query string flags: min_zoom, max_zoom, layer_name, geometry_type

Response: application/octet-stream containing .mbtiles bytes

Supports chunked transfer (no Content-Length) so the Go client can stream
features through an io.Pipe without buffering the full body.
"""
import os
import subprocess
import sys
import tempfile
import uuid
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
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

    def _read_body_to_file(self, path):
        """Read request body to disk. Supports Content-Length or chunked/EOF."""
        content_length = self.headers.get("Content-Length")
        with open(path, "wb") as f:
            if content_length is not None and content_length.isdigit():
                remaining = int(content_length)
                if remaining == 0:
                    raise ValueError("empty body")
                while remaining > 0:
                    chunk = self.rfile.read(min(65536, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)
            else:
                # Chunked / streamed body — read until EOF.
                total = 0
                while True:
                    chunk = self.rfile.read(65536)
                    if not chunk:
                        break
                    f.write(chunk)
                    total += len(chunk)
                if total == 0:
                    raise ValueError("empty body")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/tile":
            self.send_response(404)
            self.end_headers()
            return

        cl = self.headers.get("Content-Length", "chunked")
        self.log_message("POST /tile Content-Length=%s", cl)

        params = parse_qs(parsed.query)
        min_zoom = int(params.get("min_zoom", ["0"])[0])
        max_zoom = int(params.get("max_zoom", ["14"])[0])
        layer_name = params.get("layer_name", ["reference_features"])[0]
        geom_type = params.get("geometry_type", ["line"])[0]

        job_id = uuid.uuid4().hex
        work_dir = tempfile.mkdtemp(prefix=f"tp_{job_id}_")

        try:
            geojson_path = os.path.join(work_dir, "input.geojson")
            try:
                self._read_body_to_file(geojson_path)
            except ValueError as e:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(str(e).encode())
                return

            output_path = os.path.join(work_dir, "output.mbtiles")

            cmd = [
                "tippecanoe",
                "-o", output_path,
                f"--minimum-zoom={min_zoom}",
                f"--maximum-zoom={max_zoom}",
                f"--layer={layer_name}",
                "--force",
                "--quiet",
            ]

            if geom_type in ("point", "line"):
                # Keep every utility asset/line at every zoom. Default tippecanoe
                # drop-rate (2.5) still thins points even with no tile/feature limits.
                cmd.extend([
                    "--no-feature-limit",
                    "--no-tile-size-limit",
                    "--drop-rate=1",
                    "--base-zoom=0",
                ])
            else:
                cmd.extend([
                    "--drop-densest-as-needed",
                    "--extend-zooms-if-still-dropping",
                ])

            cmd.append(geojson_path)

            self.log_message("Running tippecanoe: %s", " ".join(cmd))

            # Large layers (100k–200k+) need longer than the old 5 min cap.
            result = subprocess.run(
                cmd,
                capture_output=True,
                timeout=1800,  # 30 min
            )

            if result.returncode != 0:
                stderr = result.stderr.decode("utf-8", errors="replace")
                self.log_message("Tippecanoe failed: %s", stderr)
                self.send_response(500)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(f"tippecanoe error: {stderr}".encode())
                return

            size = os.path.getsize(output_path)
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(size))
            self.end_headers()
            with open(output_path, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)

            self.log_message("Generated %d bytes of mbtiles", size)

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
            try:
                import shutil
                shutil.rmtree(work_dir, ignore_errors=True)
            except Exception:
                pass


def main():
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer.allow_reuse_address = True
    # Threading so /health stays responsive while a long /tile job runs
    # (single-threaded HTTPServer made downloads look "stuck" for 10–30 min).
    server = ThreadingHTTPServer(("0.0.0.0", port), TippecanoeHandler)
    print(f"Tippecanoe HTTP server listening on port {port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
