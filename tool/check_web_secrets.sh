#!/usr/bin/env bash
# Firebase predeploy and local builds share the same artifact scanner.
set -euo pipefail
CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
args=(--directory "${RESOURCE_DIR:-$CLIENT_DIR/hosting}")
if [[ -n "${WEB_BUILD_DEFINES:-}" ]]; then
  args+=(--defines "$WEB_BUILD_DEFINES")
fi
python3 "$CLIENT_DIR/scripts/web-secrets.py" "${args[@]}"
