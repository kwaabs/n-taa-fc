# Build from repo root:
#   docker build -f apps/geo-web/Dockerfile .
FROM oven/bun:1-alpine AS builder

WORKDIR /build

# Shared map symbols (imported via @map-symbols)
COPY shared/map-symbols ./shared/map-symbols

WORKDIR /build/apps/geo-web

COPY apps/geo-web/package.json apps/geo-web/bun.lock ./
RUN bun install --frozen-lockfile

COPY apps/geo-web/ ./

ARG VITE_API_URL=""
ARG VITE_MARTIN_URL=""
ARG VITE_GOTRUE_EXTERNAL_URL=""
ENV VITE_API_URL=$VITE_API_URL \
    VITE_MARTIN_URL=$VITE_MARTIN_URL \
    VITE_GOTRUE_EXTERNAL_URL=$VITE_GOTRUE_EXTERNAL_URL

RUN bun run build

FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY apps/geo-web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/apps/geo-web/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
