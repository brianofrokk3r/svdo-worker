#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/bin" "${tmp}/workspace" "${tmp}/home" "${tmp}/tmp"
cat > "${tmp}/bin/svdo-meter" <<'METER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" > "${SVDO_TMPDIR}/meter/invocation.txt"
[[ "$1" == "run" ]]
[[ "$2" == "--ticket" ]]
[[ "$4" == "--harness" ]]
[[ "$6" == "--workspace" ]]
[[ "${*: -1}" == "implement the ticket" ]]
printf ok
METER
chmod +x "${tmp}/bin/svdo-meter"

cat > "${tmp}/meter.yaml" <<'YAML'
runtime:
  name: test
YAML

PATH="${tmp}/bin:${PATH}" \
SVDO_WORKSPACE="${tmp}/workspace" \
SVDO_HOME="${tmp}/home" \
SVDO_TMPDIR="${tmp}/tmp" \
SVDO_METER_BIN=svdo-meter \
SVDO_METER_CONFIG="${tmp}/meter.yaml" \
SVDO_TICKET_ID=ENG-142 \
SVDO_AGENT=codex \
SVDO_MODEL=gpt-5 \
  bash "${repo_root}/scripts/entrypoint.sh" implement the ticket

grep -q -- "run --ticket ENG-142 --harness codex --workspace ${tmp}/workspace --model gpt-5 implement the ticket" "${tmp}/tmp/meter/invocation.txt"
printf '\nentrypoint validation passed\n'
