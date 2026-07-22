# Build fc-api for containerized replicas behind the OSS LB.
FROM golang:1.25-bookworm AS build
WORKDIR /src
COPY services/fc-api/go.mod services/fc-api/go.sum ./
RUN go mod download
COPY services/fc-api/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /fc-api ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /fc-api /fc-api
EXPOSE 5355
USER nonroot:nonroot
ENTRYPOINT ["/fc-api"]
