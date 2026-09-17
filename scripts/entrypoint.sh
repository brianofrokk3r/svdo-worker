#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'svdo-worker: %s\n' "$*" >&2
  exit 64
}

SVDO_WORKSPACE="${SVDO_WORKSPACE:-/workspace}"
SVDO_HOME="${SVDO_HOME:-/home/svdo}"
SVDO_TMPDIR="${SVDO_TMPDIR:-/tmp/svdo-worker}"
SVDO_METER_BIN="${SVDO_METER_BIN:-/usr/local/bin/svdo-meter}"
SVDO_METER_CONFIG="${SVDO_METER_CONFIG:-/etc/svdo-worker/meter.yaml}"
SVDO_WORKER_MODE="${SVDO_WORKER_MODE:-harness}"
SVDO_METER_EXTRA_ARGS="${SVDO_METER_EXTRA_ARGS:-}"

export SVDO_WORKSPACE SVDO_HOME SVDO_TMPDIR SVDO_METER_CONFIG
export HOME="${SVDO_HOME}"
export TMPDIR="${SVDO_TMPDIR}"

[[ "$#" -gt 0 ]] || die "no command supplied"
[[ -d "${SVDO_WORKSPACE}" ]] || die "workspace does not exist: ${SVDO_WORKSPACE}"
[[ -r "${SVDO_WORKSPACE}" ]] || die "workspace is not readable: ${SVDO_WORKSPACE}"
[[ -d "${SVDO_HOME}" ]] || die "home directory does not exist: ${SVDO_HOME}"
[[ -w "${SVDO_HOME}" ]] || die "home directory is not writable: ${SVDO_HOME}"
[[ -f "${SVDO_METER_CONFIG}" ]] || die "meter config does not exist: ${SVDO_METER_CONFIG}"
[[ -r "${SVDO_METER_CONFIG}" ]] || die "meter config is not readable: ${SVDO_METER_CONFIG}"
command -v "${SVDO_METER_BIN}" >/dev/null 2>&1 || die "meter binary not found: ${SVDO_METER_BIN}"
resolved_meter_bin="$(command -v "${SVDO_METER_BIN}")"
[[ -x "${resolved_meter_bin}" ]] || die "meter binary is not executable: ${SVDO_METER_BIN}"

mkdir -p "${SVDO_TMPDIR}" "${SVDO_TMPDIR}/meter"
[[ -w "${SVDO_TMPDIR}" ]] || die "temp directory is not writable: ${SVDO_TMPDIR}"
[[ -w "${SVDO_TMPDIR}/meter" ]] || die "meter output directory is not writable: ${SVDO_TMPDIR}/meter"

if ! "${resolved_meter_bin}" --version >/dev/null 2>&1 && ! "${resolved_meter_bin}" --help >/dev/null 2>&1; then
  die "meter binary is not usable: ${SVDO_METER_BIN} (expected --version or --help to succeed)"
fi

cd "${SVDO_WORKSPACE}"

case "${SVDO_WORKER_MODE}" in
  harness)
    ticket="${SVDO_TICKET_ID:-${SVDO_WORK_UNIT_ID:-local}}"
    harness="${SVDO_HARNESS:-${SVDO_AGENT:-codex}}"

    # Extra args are shell-split so callers can pass harness-specific flags,
    # for example: SVDO_METER_EXTRA_ARGS="--emit ndjson --codex-sandbox workspace-write".
    # shellcheck disable=SC2206
    extra_args=( ${SVDO_METER_EXTRA_ARGS} )

    meter_args=(run --ticket "${ticket}" --harness "${harness}" --workspace "${SVDO_WORKSPACE}")
    has_output_dir=0
    for arg in "${extra_args[@]}"; do
      if [[ "${arg}" == "--output-dir" || "${arg}" == --output-dir=* ]]; then
        has_output_dir=1
        break
      fi
    done
    if [[ "${has_output_dir}" == "0" ]]; then
      meter_args+=(--output-dir "${SVDO_TMPDIR}/meter")
    fi
    [[ -z "${SVDO_WORK_UNIT_ID:-}" ]] || meter_args+=(--label "${SVDO_WORK_UNIT_ID}")
    [[ -z "${SVDO_MODEL:-}" ]] || meter_args+=(--model "${SVDO_MODEL}")
    [[ -z "${SVDO_PROVIDER_SESSION_ID:-}" ]] || meter_args+=(--session "${SVDO_PROVIDER_SESSION_ID}")

    exec "${resolved_meter_bin}" "${meter_args[@]}" "${extra_args[@]}" "$*"
    ;;
  raw)
    SVDO_METER_ARGS="${SVDO_METER_ARGS:-run --config ${SVDO_METER_CONFIG}}"
    # Raw mode is reserved for a future generic subprocess wrapper contract.
    # shellcheck disable=SC2206
    meter_args=( ${SVDO_METER_ARGS} )
    exec "${resolved_meter_bin}" "${meter_args[@]}" -- "$@"
    ;;
  *)
    die "unsupported SVDO_WORKER_MODE: ${SVDO_WORKER_MODE}"
    ;;
esac
