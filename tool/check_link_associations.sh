#!/usr/bin/env bash
# Firebase predeploy and local builds share the same association checker.
set -euo pipefail
CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$CLIENT_DIR/scripts/link-associations-check.py" \
  --directory "${RESOURCE_DIR:-$CLIENT_DIR/hosting}"
