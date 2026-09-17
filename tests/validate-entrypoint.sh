#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/bin" "${tmp}/workspace" "${tmp}/home" "${tmp}/tmp"

meter_bin="${tmp}/bin/svdo-meter"
cat > "${meter_bin}" <<'METER'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  --help|-h)
    printf 'test svdo-meter fixture\n'
    exit 0
    ;;
  --version)
    printf 'test svdo-meter fixture 0.0.0\n'
    exit 0
    ;;
esac
printf '%s\n' "$*" > "${SVDO_TMPDIR}/meter/invocation.txt"
[[ "$1" == "run" ]]
[[ "$2" == "--ticket" ]]
[[ "$4" == "--harness" ]]
[[ "$6" == "--workspace" ]]
[[ "${*: -1}" == "implement the ticket" ]]
printf ok
METER
chmod +x "${meter_bin}"

meter_config="${tmp}/meter.yaml"
cat > "${meter_config}" <<'YAML'
runtime:
  name: test
YAML

run_entrypoint() {
  PATH="${tmp}/bin:${PATH}" \
  SVDO_WORKSPACE="${tmp}/workspace" \
  SVDO_HOME="${tmp}/home" \
  SVDO_TMPDIR="${tmp}/tmp" \
  SVDO_METER_BIN="${1:-svdo-meter}" \
  SVDO_METER_CONFIG="${2:-${meter_config}}" \
  SVDO_TICKET_ID=ENG-142 \
  SVDO_AGENT=codex \
  SVDO_MODEL=gpt-5 \
  SVDO_METER_EXTRA_ARGS="${3:---emit ndjson}" \
    bash "${repo_root}/scripts/entrypoint.sh" implement the ticket
}

run_entrypoint
grep -q -- "run --ticket ENG-142 --harness codex --workspace ${tmp}/workspace --output-dir ${tmp}/tmp/meter --model gpt-5 --emit ndjson implement the ticket" "${tmp}/tmp/meter/invocation.txt"

run_entrypoint svdo-meter "${meter_config}" "--output-dir ${tmp}/custom-meter --emit ndjson"
grep -q -- "run --ticket ENG-142 --harness codex --workspace ${tmp}/workspace --model gpt-5 --output-dir ${tmp}/custom-meter --emit ndjson implement the ticket" "${tmp}/tmp/meter/invocation.txt"

if run_entrypoint svdo-meter "${tmp}/missing-meter.yaml" 2>"${tmp}/missing-config.err"; then
  printf 'expected missing config validation to fail\n' >&2
  exit 1
fi
grep -q -- "svdo-worker: meter config does not exist: ${tmp}/missing-meter.yaml" "${tmp}/missing-config.err"

if run_entrypoint "${tmp}/bin/missing-svdo-meter" "${meter_config}" 2>"${tmp}/missing-meter.err"; then
  printf 'expected missing meter validation to fail\n' >&2
  exit 1
fi
grep -q -- "svdo-worker: meter binary not found: ${tmp}/bin/missing-svdo-meter" "${tmp}/missing-meter.err"

broken_meter_bin="${tmp}/bin/broken-svdo-meter"
cat > "${broken_meter_bin}" <<'METER'
#!/usr/bin/env bash
exit 66
METER
chmod +x "${broken_meter_bin}"

if run_entrypoint "${broken_meter_bin}" "${meter_config}" 2>"${tmp}/broken-meter.err"; then
  printf 'expected broken meter validation to fail\n' >&2
  exit 1
fi
grep -q -- "svdo-worker: meter binary is not usable: ${broken_meter_bin} (expected --version or --help to succeed)" "${tmp}/broken-meter.err"

if env \
  PATH="${tmp}/bin:${PATH}" \
  SVDO_WORKSPACE="${tmp}/workspace" \
  SVDO_HOME="${tmp}/home" \
  SVDO_TMPDIR="${tmp}/tmp" \
  SVDO_METER_BIN=svdo-meter \
  SVDO_METER_CONFIG="${meter_config}" \
    bash "${repo_root}/scripts/entrypoint.sh" 2>"${tmp}/missing-command.err"; then
  printf 'expected missing command validation to fail\n' >&2
  exit 1
fi
grep -q -- "svdo-worker: no command supplied" "${tmp}/missing-command.err"

missing_home="${tmp}/missing-home"
if env \
  PATH="${tmp}/bin:${PATH}" \
  SVDO_WORKSPACE="${tmp}/workspace" \
  SVDO_HOME="${missing_home}" \
  SVDO_TMPDIR="${tmp}/tmp" \
  SVDO_METER_BIN=svdo-meter \
  SVDO_METER_CONFIG="${meter_config}" \
    bash "${repo_root}/scripts/entrypoint.sh" implement the ticket 2>"${tmp}/missing-home.err"; then
  printf 'expected missing home validation to fail\n' >&2
  exit 1
fi
grep -q -- "svdo-worker: home directory does not exist: ${missing_home}" "${tmp}/missing-home.err"

printf '\nentrypoint validation passed\n'
