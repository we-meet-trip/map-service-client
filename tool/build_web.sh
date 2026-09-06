#!/usr/bin/env bash
# Build with the same explicit environment contract as native releases.
# The local dotenv is never packaged or rewritten. Hosting publication is separate.
set -euo pipefail

CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CLIENT_DIR"
: "${APP_ENV:?Set APP_ENV=test or prod explicitly}"
HOSTING_DIR="${HOSTING_DIR:-$CLIENT_DIR/hosting}"
if [[ "$APP_ENV" == prod ]]; then
  [[ -d "$HOSTING_DIR" ]] || { echo 'Prepare a separate production hosting directory first' >&2; exit 1; }
  [[ "$(cd "$HOSTING_DIR" && pwd -P)" != "$(cd "$CLIENT_DIR/hosting" && pwd -P)" ]] || {
    echo 'Production output must not overwrite the test hosting directory' >&2; exit 1;
  }
fi

umask 077
work="$(mktemp -d "${TMPDIR:-/tmp}/map-web-build.XXXXXXXX")"
defines="$work/defines.json"
python3 scripts/mobile-release-config.py --environment "$APP_ENV" --platform web \
  --signed --output "$defines"
python3 scripts/web-secrets.py --directory lib --directory web --defines "$defines"

# A fresh output directory cannot carry stale bundles from an earlier build.
flutter build web --release --output "$work/web" --dart-define-from-file "$defines"
python3 scripts/web-secrets.py --directory "$work/web" --defines "$defines"
[[ -f "$work/web/index.html" ]]
mkdir -p "$HOSTING_DIR"
# Keep environment configuration, policy pages, invitations and downloads.
rsync -a --delete --exclude 'app_config*.json' --exclude '.well-known/' \
  --exclude 'legal/' --exclude 'dl/' --exclude 'invite/' \
  "$work/web/" "$HOSTING_DIR/"
python3 scripts/web-secrets.py --directory "$HOSTING_DIR" --defines "$defines"
echo "Web build verified for $APP_ENV; hosting files prepared. No publication performed."
