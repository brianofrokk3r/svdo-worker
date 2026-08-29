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
  --env SVDO_TICKET_ID="${SVDO_TICKET_ID:-local-ticket}" \
  --env SVDO_WORK_UNIT_ID="${SVDO_WORK_UNIT_ID:-local-work-unit}" \
  --env SVDO_REPOSITORY_ID="${SVDO_REPOSITORY_ID:-local-repo}" \
  --env SVDO_AGENT="${SVDO_AGENT:-codex}" \
  --env SVDO_MODEL="${SVDO_MODEL:-}" \
  --env SVDO_RUN_ID="${SVDO_RUN_ID:-local-run}" \
  --volume "${workspace}:/workspace:Z" \
  "${image}" \
  "Use the supplied SVDO metadata while working on this local task."
