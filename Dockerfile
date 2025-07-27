FROM erlang:alpine as build-step
RUN mkdir -p /app
RUN apk add npm
COPY --from=ghcr.io/gleam-lang/gleam:v1.11.0-erlang-alpine /bin/gleam /bin/gleam
WORKDIR /app
COPY package.json /app
RUN npm install
COPY . /app
RUN gleam run -m lustre/dev build --minify

FROM nginx:1-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build-step /app/index-min.html /usr/share/nginx/html/index.html
COPY --from=build-step /app/priv /usr/share/nginx/html/priv
