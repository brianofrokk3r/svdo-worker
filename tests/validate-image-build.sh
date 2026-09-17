#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
require_podman="${SVDO_REQUIRE_PODMAN:-0}"

skip_or_fail() {
  if [[ "${require_podman}" == "1" || "${require_podman}" == "true" ]]; then
    printf '%s\n' "$1" >&2
    exit 1
  fi

  printf '%s; skipping image build validation\n' "$1" >&2
  exit 0
}

if ! command -v podman >/dev/null 2>&1; then
  skip_or_fail "podman not found"
fi

if ! podman info >/dev/null 2>&1; then
  skip_or_fail "podman is installed but unavailable"
fi

mkdir -p "${tmp}/workspace" "${tmp}/home" "${tmp}/tmp"
chmod -R 0777 "${tmp}"

meter_install_method="${SVDO_IMAGE_TEST_METER_INSTALL_METHOD:-fixture}"
base_image="svdo-worker-base-test:latest"
node_image="svdo-worker-node-test:latest"
python_image="svdo-worker-python-test:latest"
rust_image="svdo-worker-rust-test:latest"

podman build \
  --build-arg "SVDO_METER_INSTALL_METHOD=${meter_install_method}" \
  -t "${base_image}" \
  -f "${repo_root}/images/base/Containerfile" \
  "${repo_root}"

podman run --rm \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --volume "${repo_root}:/workspace:Z" \
  --entrypoint /usr/local/bin/svdo-meter \
  "${base_image}" \
  --help

if [[ "${meter_install_method}" == "fixture" ]]; then
  podman run --rm \
    --userns=keep-id \
    --security-opt=no-new-privileges \
    --cap-drop=all \
    --volume "${tmp}/workspace:/workspace:Z" \
    --volume "${tmp}/home:/home/svdo:Z" \
    --volume "${tmp}/tmp:/tmp/svdo-worker:Z" \
    --env SVDO_TICKET_ID=IMAGE-1 \
    --env SVDO_AGENT=codex \
    --env SVDO_MODEL=gpt-5 \
    --env 'SVDO_METER_EXTRA_ARGS=--emit ndjson' \
    "${base_image}" \
    "image smoke command"

  grep -q -- "run --ticket IMAGE-1 --harness codex --workspace /workspace --output-dir /tmp/svdo-worker/meter --model gpt-5 --emit ndjson image smoke command" \
    "${tmp}/tmp/meter/image-invocation.txt"
  grep -q -- "/workspace" "${tmp}/tmp/meter/workspace.txt"
  grep -q -- "/home/svdo" "${tmp}/tmp/meter/home.txt"
else
  printf 'skipping metered-run assertion for non-fixture meter install method: %s\n' "${meter_install_method}" >&2
fi

podman build --build-arg "SVDO_WORKER_BASE=localhost/${base_image}" --build-arg SVDO_CODEX_INSTALL=0 -t "${node_image}" -f "${repo_root}/images/node/Containerfile" "${repo_root}"
podman build --build-arg "SVDO_WORKER_BASE=localhost/${base_image}" -t "${python_image}" -f "${repo_root}/images/python/Containerfile" "${repo_root}"
podman build --build-arg "SVDO_WORKER_BASE=localhost/${base_image}" -t "${rust_image}" -f "${repo_root}/images/rust/Containerfile" "${repo_root}"

printf '\nimage build validation passed\n'
