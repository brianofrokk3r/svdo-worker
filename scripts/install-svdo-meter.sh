#!/usr/bin/env bash
set -Eeuo pipefail

repo="${SVDO_METER_REPO:-https://github.com/brianofrokk3r/svdo-meter.git}"
ref="${SVDO_METER_REF:-main}"
src="/tmp/svdo-meter-src"
out="${SVDO_METER_BIN:-/usr/local/bin/svdo-meter}"
install_root="$(dirname "$(dirname "${out}")")"
method="${SVDO_METER_INSTALL_METHOD:-release}"

install_from_release() {
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  curl -fsSL "https://raw.githubusercontent.com/brianofrokk3r/svdo-meter/${ref}/install.sh" -o "${tmp}/install.sh"
  SVDO_METER_INSTALL_DIR="$(dirname "${out}")" bash "${tmp}/install.sh"
}

install_from_source() {
  rm -rf "${src}"
  rm -f "${out}"

  if ! git clone --depth 1 --branch "${ref}" "${repo}" "${src}"; then
    printf 'install-svdo-meter: ref %s not found, trying repository default branch\n' "${ref}" >&2
    git clone --depth 1 "${repo}" "${src}"
  fi
  cd "${src}"

  if [[ -f crates/svdo-meter/Cargo.toml ]]; then
    cargo install --force --path crates/svdo-meter --locked --root "${install_root}"
  elif [[ -f Cargo.toml ]]; then
    cargo install --force --path . --locked --root "${install_root}"
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

"${out}" --version >/dev/null 2>&1 || true
