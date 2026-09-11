#!/usr/bin/env python3
"""Scan every web asset without printing credentials or matched content."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_KEYS = {"GOOGLE_MAPS_WEB_API_KEY", "KAKAO_JAVASCRIPT_KEY"}
SECRETISH = ("KEY", "SECRET", "TOKEN", "PASSWORD", "CREDENTIAL")
GOOGLE_KEY = re.compile(rb"AIza[0-9A-Za-z_-]{30,}")
PRIVATE_KEY = re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")


def env_values(path):
    values = {}
    if path.is_file():
        for line in path.read_text().splitlines():
            if line.strip().startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip("\"'")
    return values


def scan(directories, values, approved):
    secrets = set()
    entries = values.items() if isinstance(values, dict) else values
    for name, value in entries:
        if name in PUBLIC_KEYS or not any(word in name for word in SECRETISH):
            continue
        if len(value) >= 12:
            for variant in (value, quote(value, safe="")):
                secrets.add(variant.encode())
                secrets.add(variant[:16].encode())
    failures, checked = set(), 0
    for directory in directories:
        if not directory.is_dir() or directory.is_symlink():
            failures.add("invalid_asset_directory")
            continue
        for path in directory.rglob("*"):
            if path.is_symlink():
                failures.add("symlink_in_assets")
                continue
            if not path.is_file():
                continue
            checked += 1
            if path.name.startswith(".env"):
                failures.add("dotenv_asset")
            if re.search(r" [0-9]+(?:\.|$)", path.name):
                failures.add("stale_duplicate_asset")
            # Stream large wasm/JS files with overlap for boundary matches.
            overlap = max([4096, *(len(value) for value in secrets)])
            previous = b""
            with path.open("rb") as source:
                block = source.read(1024 * 1024)
                while block:
                    following = source.read(1024 * 1024)
                    data = previous + block
                    if PRIVATE_KEY.search(data) or any(value in data for value in secrets):
                        failures.add("server_credential")
                    if any(match.group() not in approved
                           for match in GOOGLE_KEY.finditer(data)
                           if not following or match.end() < len(data)):
                        failures.add("unapproved_google_key")
                    previous = data[-overlap:]
                    block = following
    if not checked:
        failures.add("no_assets_checked")
    return checked, sorted(failures)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, action="append", required=True)
    parser.add_argument("--defines", type=Path)
    args = parser.parse_args()
    try:
        # Keep every source value: an override must not hide a leaked older key.
        values = [*env_values(ROOT / ".env").items(),
                  *env_values(ROOT.parent / "map-service-infra/.env").items(),
                  *os.environ.items()]
        defines = json.loads(args.defines.read_text()) if args.defines else {}
        if not isinstance(defines, dict):
            raise ValueError("invalid defines")
        approved = {value.encode() for name, value in defines.items()
                    if name in PUBLIC_KEYS and isinstance(value, str) and value}
        approved.update(value.encode() for name, value in values
                        if name in PUBLIC_KEYS and value)
        checked, failures = scan(args.directory, values, approved)
        print(json.dumps({"checked_files": checked, "failures": failures,
                          "status": "FAIL" if failures else "PASS"}))
        return bool(failures)
    except (OSError, ValueError):
        print('Web asset verification failed: unreadable or invalid input', file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
