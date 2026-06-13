#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "${script_dir}/.." && pwd)
repo_bin="${repo_root}/cc-connect"

can_run() {
  "$1" --version >/dev/null 2>&1 || "$1" --help >/dev/null 2>&1
}

printf '%s\n' "openhouse-connect check"
printf '%s\n' "repo: ${repo_root}"

ok=0
if [ -x "${repo_bin}" ]; then
  if can_run "${repo_bin}"; then
    printf '%s\n' "ok: bundled cc-connect runnable: ${repo_bin}"
    ok=1
  else
    printf '%s\n' "note: bundled cc-connect exists but is not runnable on this host: ${repo_bin}" >&2
  fi
else
  printf '%s\n' "error: missing bundled cc-connect: ${repo_bin}" >&2
fi

if [ -f "${repo_root}/scripts/register-service.sh" ]; then
  printf '%s\n' "ok: register-service.sh present"
else
  printf '%s\n' "error: missing scripts/register-service.sh" >&2
fi

if [ -f "${repo_root}/config/openhouse-smallphone.example.toml" ]; then
  printf '%s\n' "ok: SmallPhone config example present"
else
  printf '%s\n' "error: missing config/openhouse-smallphone.example.toml" >&2
fi

if [ "${ok}" -eq 1 ]; then
  exit 0
fi

printf '%s\n' "error: no runnable cc-connect executable found for this environment." >&2
exit 1
