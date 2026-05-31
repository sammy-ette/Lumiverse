FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang AS frontend
COPY --from=oven/bun:1-distroless /usr/local/bin/bun /bin/bun
COPY . /app/
WORKDIR /app
RUN bun i && gleam run -m lustre/dev build --minify

FROM golang:1.23-alpine AS backend
WORKDIR /app/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
COPY --from=frontend /app/dist /app/dist
ENV STATIC_PATH=/app/dist
RUN CGO_ENABLED=0 GOOS=linux go build -o lumiverse .

FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=backend /app/backend/lumiverse /app/lumiverse
COPY --from=backend /app/dist /app/dist
ENV STATIC_PATH=/app/dist
ENTRYPOINT ["/app/lumiverse"]
