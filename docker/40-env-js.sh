#!/bin/sh
# Runs when the container starts (nginx's entrypoint runs /docker-entrypoint.d/).
# Writes the VITE_* variables the container was started with to env.js, which
# index.html loads before the app. Everything in it is public: only VITE_*
# variables go in.
set -eu

target=/usr/share/nginx/html/env.js
{
  printf 'window.__DX_ENV__ = {\n'
  env | grep '^VITE_' | sort | while IFS='=' read -r key value; do
    value="$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
    printf '  "%s": "%s",\n' "$key" "$value"
  done
  printf '};\n'
} > "$target"

echo "40-env-js.sh: wrote $(grep -c '": "' "$target") VITE_* settings to $target"
