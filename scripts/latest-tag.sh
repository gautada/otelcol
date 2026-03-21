#!/bin/sh
set -eu

REPO="open-telemetry/opentelemetry-collector-contrib"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

LATEST_TAG="$(
  curl -fsSL \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL" \
  | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -n1
)"

if [ -z "${LATEST_TAG}" ]; then
  echo "Failed to determine latest tag for ${REPO}" >&2
  exit 1
fi

printf '%s' "${LATEST_TAG#v}"
