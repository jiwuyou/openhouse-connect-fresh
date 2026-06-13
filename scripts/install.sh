#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/install.sh

Behavior:
  CC_CONNECT_INSTALL_MODE=auto (default):
    1) Prefer bundled ./cc-connect.
    2) Else, prefer runnable cc-connect on PATH.
    3) Else, build from source when Go is available.

  CC_CONNECT_INSTALL_MODE=local:
    Only accept bundled ./cc-connect or a runnable PATH binary.

  CC_CONNECT_INSTALL_MODE=source:
    Build from source with the no_web tag.

The APK path is intentionally offline-first. It should bundle ./cc-connect and
run with CC_CONNECT_INSTALL_MODE=local.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "${script_dir}/.." && pwd)
repo_bin="${repo_root}/cc-connect"
mode="${CC_CONNECT_INSTALL_MODE:-auto}"

log() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

can_run() {
  "$1" --version >/dev/null 2>&1 || "$1" --help >/dev/null 2>&1
}

try_existing_binary() {
  if [ -x "${repo_bin}" ]; then
    if can_run "${repo_bin}"; then
      log "ok: using bundled cc-connect: ${repo_bin}"
      return 0
    fi
    warn "note: bundled cc-connect exists but is not runnable in this environment: ${repo_bin}"
  fi

  if command -v cc-connect >/dev/null 2>&1; then
    path_bin=$(command -v cc-connect)
    if can_run "${path_bin}"; then
      log "ok: using PATH cc-connect: ${path_bin}"
      return 0
    fi
    warn "note: PATH cc-connect exists but is not runnable: ${path_bin}"
  fi

  return 1
}

build_from_source() {
  command -v go >/dev/null 2>&1 || {
    warn "error: Go is required for CC_CONNECT_INSTALL_MODE=source."
    return 1
  }

  log "install: building cc-connect from source with no_web tag"
  (
    cd "${repo_root}"
    go build -tags 'no_web' -o cc-connect ./cmd/cc-connect
  )
  can_run "${repo_bin}" || {
    warn "error: built binary is not runnable: ${repo_bin}"
    return 1
  }
  log "ok: built cc-connect: ${repo_bin}"
}

case "${mode}" in
  auto)
    try_existing_binary || build_from_source
    ;;
  local)
    try_existing_binary || {
      warn "error: offline payload is missing a runnable cc-connect binary."
      warn "expected: ${repo_bin}"
      exit 1
    }
    ;;
  source)
    build_from_source
    ;;
  *)
    warn "error: unknown CC_CONNECT_INSTALL_MODE: ${mode}"
    warn "expected: auto, local, or source"
    exit 1
    ;;
esac
