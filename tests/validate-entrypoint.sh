#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/bin" "${tmp}/workspace" "${tmp}/home" "${tmp}/tmp"
cat > "${tmp}/bin/svdo-meter" <<'METER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${SVDO_TMPDIR}/meter/invocation.txt"
[[ "$1" == "run" ]]
[[ "$2" == "--ticket" ]]
[[ "$4" == "--harness" ]]
[[ "$6" == "--workspace" ]]
printf ok
METER
chmod +x "${tmp}/bin/svdo-meter"

cat > "${tmp}/meter.yaml" <<'YAML'
runtime:
  name: test
YAML

set +e
missing_auth_output="$(
  PATH="${tmp}/bin:${PATH}" \
  SVDO_WORKSPACE="${tmp}/workspace" \
  SVDO_HOME="${tmp}/home" \
  SVDO_TMPDIR="${tmp}/tmp" \
  SVDO_METER_BIN=svdo-meter \
  SVDO_METER_CONFIG="${tmp}/meter.yaml" \
  SVDO_AGENT=codex \
    bash "${repo_root}/scripts/entrypoint.sh" needs auth 2>&1
)"
missing_auth_status="$?"
set -e

[[ "${missing_auth_status}" -eq 64 ]]
grep -q -- "codex auth not found" <<<"${missing_auth_output}"

PATH="${tmp}/bin:${PATH}" \
SVDO_WORKSPACE="${tmp}/workspace" \
SVDO_HOME="${tmp}/home" \
SVDO_TMPDIR="${tmp}/tmp" \
SVDO_METER_BIN=svdo-meter \
SVDO_METER_CONFIG="${tmp}/meter.yaml" \
SVDO_TICKET_ID=ENG-142 \
SVDO_AGENT=codex \
SVDO_MODEL=gpt-5 \
OPENAI_API_KEY=test-key \
  bash "${repo_root}/scripts/entrypoint.sh" implement the ticket

grep -q -- "run --ticket ENG-142 --harness codex --workspace ${tmp}/workspace --model gpt-5 implement the ticket" "${tmp}/tmp/meter/invocation.txt"

PATH="${tmp}/bin:${PATH}" \
SVDO_WORKSPACE="${tmp}/workspace" \
SVDO_HOME="${tmp}/home" \
SVDO_TMPDIR="${tmp}/tmp" \
SVDO_METER_BIN=svdo-meter \
SVDO_METER_CONFIG="${tmp}/meter.yaml" \
SVDO_AGENT=codex \
OPENAI_API_KEY=test-key \
  bash "${repo_root}/scripts/entrypoint.sh" local prompt

grep -Eq -- "run --ticket local-[0-9]{8}T[0-9]{6}Z-[0-9]+ --harness codex --workspace ${tmp}/workspace local prompt" "${tmp}/tmp/meter/invocation.txt"
! grep -q -- "run --ticket local --harness" "${tmp}/tmp/meter/invocation.txt"
printf '\nentrypoint validation passed\n'
