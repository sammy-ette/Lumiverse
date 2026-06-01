FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine AS frontend-build
WORKDIR /build
RUN apk add --no-cache curl git
COPY gleam.toml manifest.toml ./
RUN gleam deps download
COPY src ./src
RUN gleam run -m lustre/dev build

FROM golang:1.26-alpine AS backend-build
RUN apk add --no-cache gcc musl-dev vips-dev
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o /lumiverse .

FROM alpine:latest
RUN apk add --no-cache ca-certificates vips
WORKDIR /app
COPY --from=backend-build  /lumiverse ./lumiverse
COPY --from=frontend-build /build/dist ./dist

EXPOSE 8000
ENTRYPOINT ["/app/lumiverse"]