#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

output="${1:-/tmp/openhouse-smallphone-payload.tar.gz}"
output_dir="$(dirname "$output")"

required_paths=(
  "cc-connect"
  "overlay/smallphone"
  "config/openhouse-smallphone.example.toml"
  "scripts/install.sh"
  "scripts/check.sh"
  "scripts/register-service.sh"
  "scripts/openhouse-sync-cc-connect.sh"
  "scripts/openhouse-build-smallphone-payload.sh"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing required payload path: $path" >&2
    exit 1
  fi
done

mkdir -p "$output_dir"

tar -czf "$output" \
  "cc-connect" \
  "overlay/smallphone" \
  "config/openhouse-smallphone.example.toml" \
  "scripts/install.sh" \
  "scripts/check.sh" \
  "scripts/register-service.sh" \
  "scripts/openhouse-sync-cc-connect.sh" \
  "scripts/openhouse-build-smallphone-payload.sh"

echo "Wrote SmallPhone payload: $output"
echo "Payload includes offline cc-connect binary, overlay/smallphone, config, and runtime scripts."
