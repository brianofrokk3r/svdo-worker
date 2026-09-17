#!/usr/bin/env bash
set -Eeuo pipefail

image="${SVDO_WORKER_IMAGE:-svdo-worker-base:latest}"
workspace="${1:-$PWD}"
shift || true
prompt="${*:-Inspect the workspace and summarize the current repository status.}"
state_dir="${SVDO_WORKER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/svdo-worker/home}"
tmp_dir="${SVDO_WORKER_TMP_DIR:-${TMPDIR:-/tmp}/svdo-worker}"
meter_config="${SVDO_METER_CONFIG_FILE:-}"

if [[ ! -d "${workspace}" ]]; then
  printf 'workspace does not exist: %s\n' "${workspace}" >&2
  exit 64
fi

mkdir -p "${state_dir}" "${tmp_dir}"

config_mount=()
if [[ -n "${meter_config}" ]]; then
  if [[ ! -f "${meter_config}" ]]; then
    printf 'meter config does not exist: %s\n' "${meter_config}" >&2
    exit 64
  fi
  config_mount=(--volume "${meter_config}:/etc/svdo-worker/meter.yaml:ro,Z")
fi

provider_env=()
for name in OPENAI_API_KEY CODEX_API_KEY OPENAI_ORG_ID OPENAI_PROJECT_ID; do
  if [[ -n "${!name:-}" ]]; then
    provider_env+=(--env "${name}")
  fi
done

podman run --rm -it \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --network=slirp4netns \
  --memory=2g \
  --cpus=2 \
  --env SVDO_TICKET_ID="${SVDO_TICKET_ID:-LOCAL}" \
  --env SVDO_AGENT="${SVDO_AGENT:-codex}" \
  --env SVDO_METER_EXTRA_ARGS="${SVDO_METER_EXTRA_ARGS:-}" \
  "${provider_env[@]}" \
  --env SVDO_HOME=/home/svdo \
  --env SVDO_TMPDIR=/tmp/svdo-worker \
  --volume "${workspace}:/workspace:Z" \
  --volume "${state_dir}:/home/svdo:Z" \
  --volume "${tmp_dir}:/tmp/svdo-worker:Z" \
  "${config_mount[@]}" \
  "${image}" \
  "${prompt}"
