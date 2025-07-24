FROM node:22-alpine3.22 as build-step
RUN mkdir -p /app
RUN npm cache clear --force
WORKDIR /app
COPY package.json /app
RUN npm install
RUN echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.22/community" >> /etc/apk/repositories
RUN apk add --update gleam rebar3
COPY . /app
RUN gleam run -m lustre/dev build --minify

FROM nginx:1-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build-step /app/index-min.html /usr/share/nginx/html/index.html
COPY --from=build-step /app/priv /usr/share/nginx/html/priv
