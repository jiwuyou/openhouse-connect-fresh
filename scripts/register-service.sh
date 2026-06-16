#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "${script_dir}/.." && pwd)

log() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

svc_name="cc-connect"
svc_desc="OpenHouse Connect (cc-connect): bridge + management + webhook"

bridge_port=${CC_CONNECT_BRIDGE_PORT:-21010}
management_port=${CC_CONNECT_MANAGEMENT_PORT:-21020}
webhook_port=${CC_CONNECT_WEBHOOK_PORT:-21040}

agent_env=${OPENHOUSE_AGENT_ENV:-/root/.smallphoneai/agent-env}
cfg_path=${CC_CONNECT_CONFIG_PATH:-/root/.smallphoneai/cc-connect.toml}
work_dir=${CC_CONNECT_SMALLPHONE_WORK_DIR:-/root/workspace}
agent_type=${CC_CONNECT_SMALLPHONE_AGENT_TYPE:-claudecode}
agent_mode=${CC_CONNECT_SMALLPHONE_AGENT_MODE:-default}
launcher_path=${CC_CONNECT_LAUNCHER_PATH:-/root/.smallphoneai/bin/openhouse-cc-connect-launcher.sh}
service_path="/root/.npm-global/bin:/root/.local/node/bin:/root/.opencode/bin:/root/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/system/bin:/system/xbin:/data/data/com.termux/files/usr/bin"
service_home=${CC_CONNECT_SERVICE_HOME:-/root}
service_user=${CC_CONNECT_SERVICE_USER:-root}
service_shell=${CC_CONNECT_SERVICE_SHELL:-/bin/bash}
xdg_config_home=${XDG_CONFIG_HOME:-${service_home}/.config}
xdg_cache_home=${XDG_CACHE_HOME:-${service_home}/.cache}
xdg_data_home=${XDG_DATA_HOME:-${service_home}/.local/share}

detect_claude_cli() {
  if [ -n "${CC_CONNECT_SMALLPHONE_CLAUDE_CLI:-}" ]; then
    printf '%s\n' "${CC_CONNECT_SMALLPHONE_CLAUDE_CLI}"
    return
  fi

  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi

  for candidate in \
    /usr/local/bin/claude \
    /root/.local/bin/claude \
    /root/.npm-global/bin/claude \
    /root/.local/node/bin/claude; do
    if [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  printf '%s\n' /root/.npm-global/bin/claude
}

random_token() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
    return
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'
    printf '\n'
    return
  fi
  if [ -r /proc/sys/kernel/random/uuid ]; then
    tr -d '-' </proc/sys/kernel/random/uuid
    tr -d '-' </proc/sys/kernel/random/uuid
    printf '\n'
    return
  fi
  warn "error: cannot generate a secure runtime token; install python3 or openssl."
  exit 1
}

toml_section_value() {
  file=$1
  section=$2
  key=$3
  [ -r "${file}" ] || return 0
  awk -v section="${section}" -v key="${key}" '
    $0 ~ "^\\[" section "\\]$" { in_section=1; next }
    $0 ~ "^\\[" { in_section=0 }
    in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub("^[^=]*=", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "${file}"
}

token_value() {
  env_value=$1
  section=$2
  key=$3
  if [ -n "${env_value}" ]; then
    printf '%s\n' "${env_value}"
    return
  fi
  existing=$(toml_section_value "${cfg_path}" "${section}" "${key}" || true)
  if [ -n "${existing}" ]; then
    case "${existing}" in
      smallphoneai-bridge-token|smallphoneai-management-token|smallphoneai-webhook-token|\$\{*\})
        existing=""
        ;;
    esac
  fi
  if [ -n "${existing}" ]; then
    printf '%s\n' "${existing}"
    return
  fi
  random_token
}

ensure_agent_env() {
  if [ -s "${agent_env}" ] && ! grep -q '^# Optional runtime secrets for OpenHouse Connect\.$' "${agent_env}" 2>/dev/null; then
    chmod 600 "${agent_env}" 2>/dev/null || true
    return
  fi

  mkdir -p "$(dirname "${agent_env}")"
  tmp="${agent_env}.tmp"
  umask 077

  if [ -r "${service_home}/.bashrc" ] && grep -q '^# >>> OpenHouseAI Claude Code ' "${service_home}/.bashrc"; then
    {
      printf '%s\n' '# Generated from the device-local OpenHouseAI Claude Code block.'
      printf '%s\n' '# Keep this file on-device only; do not commit secrets.'
      sed -n '/^# >>> OpenHouseAI Claude Code /,/^# <<< OpenHouseAI Claude Code /p' "${service_home}/.bashrc" |
        sed '/^# >>> /d; /^# <<< /d'
    } >"${tmp}"
    if grep -q '^export ANTHROPIC_' "${tmp}"; then
      mv "${tmp}" "${agent_env}"
      chmod 600 "${agent_env}"
      log "ok: generated agent env from ${service_home}/.bashrc: ${agent_env}"
      return
    fi
    rm -f "${tmp}"
  fi

  if [ ! -e "${agent_env}" ]; then
    {
      printf '%s\n' '# Optional runtime secrets for OpenHouse Connect.'
      printf '%s\n' '# Fill this file on-device or run the OpenHouseAI agent setup.'
    } >"${tmp}"
    mv "${tmp}" "${agent_env}"
    chmod 600 "${agent_env}"
    warn "note: created empty ${agent_env}; Claude Code provider env was not found in ${service_home}/.bashrc."
  fi
}

bin_path=""
if [ -x "${repo_root}/cc-connect" ]; then
  bin_path="${repo_root}/cc-connect"
elif command -v cc-connect >/dev/null 2>&1; then
  bin_path=$(command -v cc-connect)
fi

log "cc-connect service registration"
log "ports: bridge=${bridge_port}, management=${management_port}, webhook=${webhook_port}"

if [ -z "${bin_path}" ]; then
  warn "note: no cc-connect binary found; run ${repo_root}/scripts/install.sh first."
  exit 0
fi

mkdir -p "$(dirname "${cfg_path}")" "$(dirname "${launcher_path}")" "${work_dir}" "${xdg_config_home}" "${xdg_cache_home}" "${xdg_data_home}"
ensure_agent_env
claude_cli=$(detect_claude_cli)

bridge_token=$(token_value "${OPENHOUSE_BRIDGE_TOKEN:-${CC_CONNECT_BRIDGE_TOKEN:-}}" bridge token)
management_token=$(token_value "${OPENHOUSE_MANAGEMENT_TOKEN:-${CC_CONNECT_MANAGEMENT_TOKEN:-}}" management token)
webhook_token=$(token_value "${OPENHOUSE_WEBHOOK_TOKEN:-${CC_CONNECT_WEBHOOK_TOKEN:-}}" webhook token)

cat >"${cfg_path}" <<EOF
language = "en"
data_dir = "/root/.smallphoneai/cc-connect-data"
attachment_send = "on"
shell = "bash"
shell_profile = "test -r ${agent_env} && set -a && . ${agent_env} && set +a"

[log]
level = "info"

[bridge]
enabled = true
port = ${bridge_port}
token = "${bridge_token}"
path = "/bridge/ws"
cors_origins = ["*"]

[management]
enabled = true
port = ${management_port}
token = "${management_token}"
cors_origins = ["http://127.0.0.1:${management_port}", "http://localhost:${management_port}", "smallphone://openhouse"]

[webhook]
enabled = true
port = ${webhook_port}
token = "${webhook_token}"
path = "/hook"

[[projects]]
name = "smallphone-default"
admin_from = "*"

[projects.agent]
type = "${agent_type}"

[projects.agent.options]
work_dir = "${work_dir}"
cli_path = "${claude_cli}"
mode = "${agent_mode}"
EOF
cat >"${launcher_path}" <<EOF
#!/bin/sh
set -eu

if [ -r "${agent_env}" ]; then
  set -a
  . "${agent_env}"
  set +a
fi

"${bin_path}" --config "${cfg_path}" "\$@" &
child=\$!

cleanup() {
  kill "\${child}" >/dev/null 2>&1 || true
  wait "\${child}" >/dev/null 2>&1 || true
}
trap cleanup INT TERM HUP

wait "\${child}"
EOF
chmod 700 "${launcher_path}"

log "config: ${cfg_path}"
log "launcher: ${launcher_path}"
log "exec: ${bin_path} --config ${cfg_path}"

sm_url="${SERVICE_MANAGER_URL:-http://127.0.0.1:20087}"
if ! command -v service-manager >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  warn "note: service-manager CLI or curl not found; config was written, registration skipped."
  exit 0
fi

if ! curl -fsS --max-time 2 "${sm_url}/api/v1/health" >/dev/null 2>&1; then
  warn "note: service-manager is not reachable at ${sm_url}; registration skipped."
  exit 0
fi

sm_token="${SERVICE_MANAGER_TOKEN:-}"
if [ -z "${sm_token}" ]; then
  sm_token=$(service-manager token show 2>/dev/null | tr -d '\r\n' || true)
fi
if [ -z "${sm_token}" ]; then
  warn "note: service-manager token unavailable; registration skipped."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  warn "note: python3 not found; config was written, service-manager registration skipped."
  exit 0
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/openhouse-connect-sm.XXXXXX")
cleanup() { rm -rf "${tmp_dir}" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT HUP TERM

curl_cfg="${tmp_dir}/curl.cfg"
spec_file="${tmp_dir}/service-spec.json"
printf 'header = "Authorization: Bearer %s"\n' "${sm_token}" >"${curl_cfg}"
printf 'header = "Content-Type: application/json"\n' >>"${curl_cfg}"

python3 - "${svc_name}" "${svc_desc}" "${launcher_path}" "${repo_root}" \
  "${bridge_port}" "${management_port}" "${webhook_port}" "${service_path}" \
  "${service_home}" "${service_user}" "${service_shell}" \
  "${xdg_config_home}" "${xdg_cache_home}" "${xdg_data_home}" >"${spec_file}" <<'PY'
import json
import sys

(
    name,
    desc,
    launcher_path,
    repo_root,
    bridge_port,
    management_port,
    webhook_port,
    service_path,
    service_home,
    service_user,
    service_shell,
    xdg_config_home,
    xdg_cache_home,
    xdg_data_home,
) = sys.argv[1:]

def tcp(port):
    return {"type": "tcp", "address": f"127.0.0.1:{port}", "interval": "30s", "timeout": "3s"}

env = {
    "PATH": service_path,
    "HOME": service_home,
    "USER": service_user,
    "LOGNAME": service_user,
    "SHELL": service_shell,
    "XDG_CONFIG_HOME": xdg_config_home,
    "XDG_CACHE_HOME": xdg_cache_home,
    "XDG_DATA_HOME": xdg_data_home,
}

json.dump({
    "name": name,
    "description": desc,
    "provider": "process",
    "command": ["/bin/sh", launcher_path],
    "working_dir": repo_root,
    "env": env,
    "runtime": {},
    "restart": {"mode": "always", "max_retries": 0},
    "health": [tcp(bridge_port), tcp(management_port)],
    "enabled": True,
    "tags": ["group:local-stack", "openhouse-component:cc-connect"],
}, sys.stdout, ensure_ascii=True)
PY

services_json=$(curl -q -fsS --max-time 3 -K "${curl_cfg}" "${sm_url}/api/v1/services" 2>/dev/null || true)
svc_id=$(SERVICES_JSON="${services_json}" python3 - "${svc_name}" <<'PY'
import json
import os
import sys

name = sys.argv[1]
try:
    services = json.loads(os.environ.get("SERVICES_JSON", ""))
except Exception:
    sys.exit(0)
for svc in services if isinstance(services, list) else services.get("services", []):
    spec = svc.get("spec") if isinstance(svc, dict) else None
    spec_name = spec.get("name") if isinstance(spec, dict) else None
    if svc.get("name") == name or spec_name == name:
        print(svc.get("id", ""))
        break
PY
)

if [ -n "${svc_id}" ]; then
  curl -q -fsS --max-time 5 -X PUT -K "${curl_cfg}" --data-binary "@${spec_file}" "${sm_url}/api/v1/services/${svc_id}" >/dev/null \
    && log "ok: updated service-manager service: ${svc_id}" \
    || warn "note: failed to update service-manager service: ${svc_id}"
else
  curl -q -fsS --max-time 5 -X POST -K "${curl_cfg}" --data-binary "@${spec_file}" "${sm_url}/api/v1/services" >/dev/null \
    && log "ok: registered service-manager service: ${svc_name}" \
    || warn "note: failed to register service-manager service: ${svc_name}"
fi
