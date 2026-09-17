#!/usr/bin/env bash
set -Eeuo pipefail

image="${SVDO_WORKER_IMAGE:-svdo-worker-node:latest}"
if [[ "$#" -gt 0 ]]; then
  workspace="$1"
  shift
else
  workspace="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
prompt="${*:-Create a sample markdown file.}"
state_dir="${SVDO_WORKER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/svdo-worker/codex-home}"
tmp_dir="${SVDO_WORKER_TMP_DIR:-${TMPDIR:-/tmp}/svdo-worker-codex}"
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

if [[ "${SVDO_WORKER_AUTH_DEBUG:-}" == "1" ]]; then
  podman run --rm -it \
    --userns=keep-id \
    --security-opt=no-new-privileges \
    --cap-drop=all \
    --network=slirp4netns \
    --memory=4g \
    --cpus=4 \
    "${provider_env[@]}" \
    --env SVDO_HOME=/home/svdo \
    --env SVDO_TMPDIR=/tmp/svdo-worker \
    --volume "${workspace}:/workspace:Z" \
    --volume "${state_dir}:/home/svdo:Z" \
    --volume "${tmp_dir}:/tmp/svdo-worker:Z" \
    --entrypoint bash \
    "${image}" \
    -lc 'for name in OPENAI_API_KEY CODEX_API_KEY OPENAI_ORG_ID OPENAI_PROJECT_ID; do value="${!name:-}"; if [[ -n "${value}" ]]; then printf "%s=set length=%s\n" "${name}" "${#value}"; else printf "%s=unset\n" "${name}"; fi; done; command -v codex >/dev/null 2>&1 && codex --version || true'
  exit 0
fi

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
