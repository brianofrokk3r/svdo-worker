#!/usr/bin/env bash
set -Eeuo pipefail

image="${SVDO_WORKER_IMAGE:-svdo-worker-base:latest}"
workspace="${1:-$PWD}"

podman run --rm -it \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --network=slirp4netns \
  --memory=2g \
  --cpus=2 \
  --env SVDO_TICKET_ID="${SVDO_TICKET_ID:-LOCAL}" \
  --env SVDO_AGENT="${SVDO_AGENT:-codex}" \
  --volume "${workspace}:/workspace:Z" \
  "${image}" \
  "Inspect the workspace and summarize the current repository status."
