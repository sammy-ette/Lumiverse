# Install JS dependencies (phosphor-icons-tailwindcss plugin used by src/lumiverse.css)
FROM oven/bun:1-alpine AS frontend-deps
WORKDIR /build
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine AS frontend-build
WORKDIR /build
RUN apk add --no-cache curl git
COPY gleam.toml manifest.toml ./
RUN gleam deps download
# node_modules is required so Tailwind can resolve the @plugin in src/lumiverse.css
COPY --from=frontend-deps /build/node_modules ./node_modules
COPY package.json bun.lock ./
# assets/ holds the custom index.html (asset-version placeholders + service
# worker registration) and the favicon; lustre copies it into dist/ on build.
COPY src ./src
COPY assets ./assets
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
COPY sw.js ./sw.js

VOLUME ["/app/data"]
ENV DB_PATH=/app/data/lumiverse.db

EXPOSE 8000
ENTRYPOINT ["/app/lumiverse"]
