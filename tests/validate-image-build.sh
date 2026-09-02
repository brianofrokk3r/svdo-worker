#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v podman >/dev/null 2>&1; then
  printf 'podman not found; skipping image build validation\n' >&2
  exit 0
fi

if ! podman info >/dev/null 2>&1; then
  printf 'podman is not usable in this environment; skipping image build validation\n' >&2
  exit 0
fi

podman build -t localhost/svdo-worker-base:latest -f "${repo_root}/images/base/Containerfile" "${repo_root}"
podman run --rm \
  --pull=never \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --volume "${repo_root}:/workspace:Z" \
  --entrypoint /usr/local/bin/svdo-meter \
  localhost/svdo-worker-base:latest \
  --help

podman build -t localhost/svdo-worker-node:latest -f "${repo_root}/images/node/Containerfile" "${repo_root}"
podman run --rm \
  --pull=never \
  --entrypoint codex \
  localhost/svdo-worker-node:latest \
  --version
podman run --rm \
  --pull=never \
  --entrypoint claude \
  localhost/svdo-worker-node:latest \
  --version
podman build -t localhost/svdo-worker-python:latest -f "${repo_root}/images/python/Containerfile" "${repo_root}"
podman build -t localhost/svdo-worker-rust:latest -f "${repo_root}/images/rust/Containerfile" "${repo_root}"
