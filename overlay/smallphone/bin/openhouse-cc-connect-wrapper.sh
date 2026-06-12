#!/usr/bin/env bash
set -euo pipefail

agent_env="${OPENHOUSE_AGENT_ENV:-/root/.smallphoneai/agent-env}"
config_path="${CC_CONNECT_CONFIG:-/root/.smallphoneai/cc-connect.toml}"
cc_connect_bin="${CC_CONNECT_BIN:-cc-connect}"

if [[ -r "$agent_env" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$agent_env"
  set +a
fi

if [[ ! -r "$config_path" ]]; then
  fallback_config="/opt/openhouse/config/openhouse-smallphone.example.toml"
  if [[ -r "$fallback_config" ]]; then
    config_path="$fallback_config"
  fi
fi

command_args=("$cc_connect_bin" "-config" "$config_path")
if [[ "$#" -gt 0 ]]; then
  command_args+=("$@")
fi

printf -v command_line "%q " "${command_args[@]}"

if [[ -n "${OPENHOUSE_PROOT_CMD:-}" ]]; then
  # OPENHOUSE_PROOT_CMD is a device-local service-manager setting, for example:
  #   proot-distro login ubuntu --
  # It is intentionally evaluated as words here so service-manager can provide
  # the proot launcher and arguments.
  # shellcheck disable=SC2086
  exec $OPENHOUSE_PROOT_CMD /bin/bash -lc "$command_line"
fi

exec /bin/bash -lc "$command_line"
