#!/usr/bin/env bash
set -Eeuo pipefail

image="${SVDO_WORKER_IMAGE:-svdo-worker-node:latest}"
workspace="${1:-$PWD}"
shift || true
prompt="${*:-Inspect the workspace and implement the requested task.}"

podman run --rm -it \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --network=slirp4netns \
  --memory=4g \
  --cpus=4 \
  --env SVDO_AGENT="${SVDO_AGENT:-codex}" \
  --env SVDO_MODEL="${SVDO_MODEL:-}" \
  --env SVDO_TICKET_ID="${SVDO_TICKET_ID:-LOCAL}" \
  --volume "${workspace}:/workspace:Z" \
  "${image}" \
  "${prompt}"
