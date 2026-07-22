# Multi-stage: pull tippecanoe binaries from actively-maintained upstream image
FROM ghcr.io/openwatersio/tippecanoe:latest AS tippecanoe

# --- Runtime image ---
FROM debian:12-slim

# Runtime deps for our HTTP wrapper
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    zlib1g \
    ca-certificates \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled tippecanoe binaries
COPY --from=tippecanoe /usr/local/bin/tippecanoe /usr/local/bin/
COPY --from=tippecanoe /usr/local/bin/tile-join /usr/local/bin/
COPY --from=tippecanoe /usr/local/bin/tippecanoe-decode /usr/local/bin/

WORKDIR /work
COPY server.py /server.py
RUN chmod +x /server.py

EXPOSE 8080

CMD ["python3", "/server.py"]