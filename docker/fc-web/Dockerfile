# Field Collector admin UI — static Vite build behind nginx
FROM oven/bun:1-alpine AS builder

WORKDIR /build

COPY apps/fc-web/package.json apps/fc-web/bun.lock ./
RUN bun install --frozen-lockfile

COPY apps/fc-web/ ./

# Build-time public URLs (tiles + OAuth redirect host). Prefer same-origin
# GoTrue via nginx /gotrue when VITE_GOTRUE_EXTERNAL_URL is empty.
ARG VITE_MARTIN_URL=""
ARG VITE_GOTRUE_EXTERNAL_URL=""
ENV VITE_MARTIN_URL=$VITE_MARTIN_URL \
    VITE_GOTRUE_EXTERNAL_URL=$VITE_GOTRUE_EXTERNAL_URL

RUN bun run build

FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY docker/fc-web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
