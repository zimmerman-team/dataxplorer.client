# The dx.client image: the built app served by nginx. CI builds it on every
# push and tags it with the commit SHA; infra.dx runs it. Build it locally with
# `make build`. Its settings (VITE_*) are read when the container starts, not
# at build time, so the same image runs in staging and production.

# ---- rawgraphs-charts --------------------------------------------------------
FROM node:22.21-alpine3.21 AS charts
RUN apk add --no-cache git
# The rawgraphs-charts commit the app is built with (on feat/DX-137; the
# server's Dockerfile pins the same one). Change both to update the charts.
ARG RAWGRAPHS_REPO=https://github.com/zimmerman-team/rawgraphs-charts.git
ARG RAWGRAPHS_REF=17c017a71ee3c95944d2911f072b3e3c818f6e32
WORKDIR /charts
RUN git init -q \
 && git remote add origin "$RAWGRAPHS_REPO" \
 && git fetch -q --depth 1 origin "$RAWGRAPHS_REF" \
 && git checkout -q FETCH_HEAD
# rollup only: rawgraphs' own `yarn build` also copies itself into sibling folders.
RUN yarn install --frozen-lockfile --network-timeout 600000 && npx rollup -c

# ---- build the app -----------------------------------------------------------
FROM node:22.21-alpine3.21 AS build
# No git hooks in an image build.
ENV HUSKY=0
COPY --from=charts /charts /charts
RUN cd /charts && yarn link
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn link "@rawgraphs/rawgraphs-charts" \
 && yarn install --frozen-lockfile --network-timeout 600000
COPY . .
RUN RUNTIME_ENV=1 yarn build

# ---- serve it ----------------------------------------------------------------
FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
# nginx's entrypoint runs this before starting: it writes env.js.
COPY --chmod=755 docker/40-env-js.sh /docker-entrypoint.d/40-env-js.sh
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
