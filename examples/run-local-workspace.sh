#!/usr/bin/env sh
set -eu

image="${SVDO_WORKER_IMAGE:-localhost/svdo-worker-node:latest}"
workspace="${1:-$PWD}"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
claude_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

if ! command -v podman >/dev/null 2>&1; then
  printf 'podman not found\n' >&2
  exit 1
fi

if ! podman info >/dev/null 2>&1; then
  printf 'podman is not usable in this environment\n' >&2
  exit 1
fi

case "${image}" in
  localhost/*)
    if ! podman image exists "${image}"; then
      printf 'local image %s not found. Build it first:\n  podman build -t localhost/svdo-worker-base:latest -f images/base/Containerfile .\n  podman build -t localhost/svdo-worker-node:latest -f images/node/Containerfile .\n' "${image}" >&2
      exit 1
    fi
    ;;
esac

if [ "${SVDO_AGENT:-codex}" = "codex" ] && [ -z "${OPENAI_API_KEY:-}" ] && [ ! -s "${codex_home}/auth.json" ]; then
  printf 'codex auth not found at %s/auth.json. Run codex login on the host, set CODEX_HOME, or export OPENAI_API_KEY.\n' "${codex_home}" >&2
  exit 1
fi

podman run --rm -it \
  --pull=never \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --network=slirp4netns \
  --memory=2g \
  --cpus=2 \
  --env SVDO_AGENT="${SVDO_AGENT:-codex}" \
  ${SVDO_TICKET_ID:+--env SVDO_TICKET_ID} \
  ${SVDO_WORK_UNIT_ID:+--env SVDO_WORK_UNIT_ID} \
  ${SVDO_RUN_ID:+--env SVDO_RUN_ID} \
  ${OPENAI_API_KEY:+--env OPENAI_API_KEY} \
  ${ANTHROPIC_API_KEY:+--env ANTHROPIC_API_KEY} \
  --volume "${workspace}:/workspace:Z" \
  --volume "${codex_home}:/home/svdo/.codex:Z" \
  --volume "${claude_config_dir}:/home/svdo/.claude:Z" \
  "${image}" \
  "Inspect the workspace and summarize the current repository status."
