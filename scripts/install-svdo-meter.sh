#!/usr/bin/env bash
set -Eeuo pipefail

repo="${SVDO_METER_REPO:-https://github.com/brianofrokk3r/svdo-meter.git}"
ref="${SVDO_METER_REF:-main}"
src="/tmp/svdo-meter-src"
out="/usr/local/bin/svdo-meter"
method="${SVDO_METER_INSTALL_METHOD:-release}"
fixture_path="${SVDO_METER_FIXTURE_PATH:-}"

install_from_release() {
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  curl -fsSL "https://raw.githubusercontent.com/brianofrokk3r/svdo-meter/${ref}/install.sh" -o "${tmp}/install.sh"
  SVDO_METER_INSTALL_DIR="$(dirname "${out}")" sh "${tmp}/install.sh"
}

install_from_source() {
  rm -rf "${src}"
  if ! git clone --depth 1 --branch "${ref}" "${repo}" "${src}"; then
    printf 'install-svdo-meter: ref %s not found, trying repository default branch\n' "${ref}" >&2
    git clone --depth 1 "${repo}" "${src}"
  fi
  cd "${src}"

  if [[ -f crates/svdo-meter/Cargo.toml ]]; then
    cargo install --path crates/svdo-meter --locked --root /usr/local
  elif [[ -f Cargo.toml ]]; then
    cargo install --path . --locked --root /usr/local
  elif [[ -f package.json ]]; then
    npm install --omit=dev
    npm link
  elif [[ -f pyproject.toml || -f setup.py ]]; then
    python3 -m venv /opt/svdo-meter
    /opt/svdo-meter/bin/pip install --no-cache-dir .
    ln -sf /opt/svdo-meter/bin/svdo-meter "${out}"
  else
    printf 'install-svdo-meter: unsupported svdo-meter project layout\n' >&2
    exit 65
  fi
}

if [[ "${method}" == "release" ]]; then
  install_from_release || install_from_source
elif [[ "${method}" == "source" ]]; then
  install_from_source
elif [[ "${method}" == "fixture" ]]; then
  if [[ -n "${fixture_path}" ]]; then
    if [[ ! -f "${fixture_path}" ]]; then
      printf 'install-svdo-meter: fixture path does not exist: %s\n' "${fixture_path}" >&2
      exit 65
    fi
    install -m 0755 "${fixture_path}" "${out}"
  else
    cat > "${out}" <<'METER'
#!/usr/bin/env bash
set -Eeuo pipefail

case "${1:-}" in
  --help|-h)
    printf 'svdo-meter fixture\n'
    printf 'usage: svdo-meter run [options] <prompt>\n'
    exit 0
    ;;
  --version)
    printf 'svdo-meter fixture 0.0.0\n'
    exit 0
    ;;
esac

if [[ "${1:-}" == "run" ]]; then
  meter_dir="${SVDO_TMPDIR:-/tmp/svdo-worker}/meter"
  mkdir -p "${meter_dir}"
  printf '%s\n' "$*" > "${meter_dir}/image-invocation.txt"
  printf '%s\n' "${SVDO_WORKSPACE:-}" > "${meter_dir}/workspace.txt"
  printf '%s\n' "${SVDO_HOME:-}" > "${meter_dir}/home.txt"
fi

printf 'svdo-meter fixture invoked\n'
METER
    chmod +x "${out}"
  fi
else
  printf 'install-svdo-meter: unsupported install method: %s\n' "${method}" >&2
  exit 65
fi

if ! command -v svdo-meter >/dev/null 2>&1; then
  printf 'install-svdo-meter: svdo-meter executable was not installed\n' >&2
  exit 65
fi

resolved="$(command -v svdo-meter)"
if [[ "${resolved}" != "${out}" ]]; then
  ln -sf "${resolved}" "${out}"
fi

if [[ ! -x "${out}" ]]; then
  printf 'install-svdo-meter: installed svdo-meter is not executable: %s\n' "${out}" >&2
  exit 65
fi

if ! "${out}" --version >/dev/null 2>&1 && ! "${out}" --help >/dev/null 2>&1; then
  printf 'install-svdo-meter: installed svdo-meter does not respond to --version or --help: %s\n' "${out}" >&2
  exit 65
fi
