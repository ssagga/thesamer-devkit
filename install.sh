#!/usr/bin/env bash
# install.sh — one-command bootstrap for thesamer.devkit.
#
# Run this from INSIDE the project you want to scaffold:
#
#   curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash
#
# Pass options through to the scaffolder after `-s --`:
#
#   curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash -s -- --integration-branch develop
#   curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash -s -- --dry-run
#
# It downloads the kit to a temp dir and runs bin/devkit-init.sh against your
# current directory. Nothing is installed globally; the temp dir is removed on exit.
#
# Overridable via env:
#   DEVKIT_REPO  (default: ssagga/thesamer-devkit)
#   DEVKIT_REF   (default: main)
#   DEVKIT_ARCHIVE_URL  (default: the GitHub tarball for REPO@REF)
set -euo pipefail

REPO="${DEVKIT_REPO:-ssagga/thesamer-devkit}"
REF="${DEVKIT_REF:-main}"
ARCHIVE_URL="${DEVKIT_ARCHIVE_URL:-https://github.com/${REPO}/archive/${REF}.tar.gz}"

need() {
  command -v "$1" >/dev/null 2>&1 || { printf '[ERROR] %s is required but not installed.\n' "$1" >&2; exit 1; }
}
need curl
need tar

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

printf '[INFO]  Fetching thesamer.devkit (%s@%s)...\n' "${REPO}" "${REF}"
if ! curl -fsSL "${ARCHIVE_URL}" | tar -xz -C "${TMP}" --strip-components=1; then
  printf '[ERROR] Could not download the kit from %s\n' "${ARCHIVE_URL}" >&2
  printf '[ERROR] If the repo is private, clone it with gh instead:\n' >&2
  printf '          gh repo clone %s /tmp/devkit && bash /tmp/devkit/bin/devkit-init.sh\n' "${REPO}" >&2
  exit 1
fi

if [[ ! -x "${TMP}/bin/devkit-init.sh" ]]; then
  printf '[ERROR] Downloaded archive is missing bin/devkit-init.sh\n' >&2
  exit 1
fi

printf '[INFO]  Scaffolding into: %s\n\n' "${PWD}"
bash "${TMP}/bin/devkit-init.sh" "$@"
