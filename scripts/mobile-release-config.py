#!/usr/bin/env python3
"""Validate mobile release configuration and emit only approved Dart defines."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit

TEST_API_ORIGIN = "https://mapapptest.duckdns.org"
TEST_CONFIG_URL = "https://mapcenter-b59ca.web.app/app_config.json"
PLATFORM_KEYS = {
    "android": "GOOGLE_MAPS_ANDROID_API_KEY",
    "ios": "GOOGLE_MAPS_IOS_API_KEY",
    "web": "GOOGLE_MAPS_WEB_API_KEY",
}


class ConfigError(ValueError):
    pass


def https_url(value, field, *, origin_only=False):
    if not value or any(c.isspace() or ord(c) < 32 for c in value):
        raise ConfigError(f"{field}: a nonempty HTTPS value is required")
    try:
        uri = urlsplit(value)
        port = uri.port
    except ValueError:
        raise ConfigError(f"{field}: malformed URL") from None
    if (uri.scheme != "https" or not uri.hostname or uri.username is not None
            or uri.password is not None or uri.query or uri.fragment
            or "\\" in value):
        raise ConfigError(f"{field}: only HTTPS URLs without credentials/query/fragment are allowed")
    if origin_only and uri.path not in ("", "/"):
        raise ConfigError(f"{field}: API entries must be origins, without paths")
    if port is not None and not 1 <= port <= 65535:
        raise ConfigError(f"{field}: invalid port")
    host = uri.hostname.lower()
    if ":" in host:
        host = f"[{host}]"
    origin = f"https://{host}" + (f":{port}" if port not in (None, 443) else "")
    return origin if origin_only else origin + uri.path


def make_config(environment, platform, signed, environ):
    if environment not in ("test", "prod") or platform not in PLATFORM_KEYS:
        raise ConfigError("unsupported environment or platform")
    raw_origins = environ.get("API_ALLOWED_ORIGINS", "").strip()
    config_url = environ.get("APP_CONFIG_URL", "").strip()
    if environment == "test":
        raw_origins = raw_origins or TEST_API_ORIGIN
        config_url = config_url or TEST_CONFIG_URL
    elif not raw_origins or not config_url:
        raise ConfigError("prod requires explicit API_ALLOWED_ORIGINS and APP_CONFIG_URL")
    origins = list(dict.fromkeys(
        https_url(value.strip(), "API_ALLOWED_ORIGINS", origin_only=True)
        for value in raw_origins.split(",")
    ))
    config_url = https_url(config_url, "APP_CONFIG_URL")
    if environment == "prod" and (
        any(urlsplit(origin).hostname == urlsplit(TEST_API_ORIGIN).hostname for origin in origins)
        or config_url == TEST_CONFIG_URL
    ):
        raise ConfigError("prod configuration must not use the GCP test endpoints")
    key_name = PLATFORM_KEYS[platform]
    key = environ.get(key_name, "").strip()
    if key and (not re.fullmatch(r"[A-Za-z0-9_-]+", key)
                or key.lower().startswith(("replace-", "your_"))):
        raise ConfigError(f"{key_name}: invalid client key format")
    if signed and not key:
        raise ConfigError(f"{key_name}: required for a signed release")
    config = {
        "APP_ENV": environment,
        "API_ALLOWED_ORIGINS": ",".join(origins),
        "APP_CONFIG_URL": config_url,
    }
    if key:
        config[key_name] = key
    return config


def release_version(ref, pubspec, number):
    if ref.startswith("refs/tags/v"):
        name = ref.removeprefix("refs/tags/v")
    else:
        match = re.search(r"^version:\s*([^+\s]+)", pubspec, re.MULTILINE)
        if not match:
            raise ConfigError("pubspec version is missing")
        name = match.group(1)
    # Store metadata is a numeric version, never arbitrary tag text or shell code.
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", name):
        raise ConfigError("build name must be a numeric major.minor.patch version")
    if not re.fullmatch(r"[1-9][0-9]*", number) or int(number) > 2100000000:
        raise ConfigError("build number must be between 1 and 2100000000")
    return name, number


def write_private(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as output:
        os.fchmod(output.fileno(), 0o600)
        output.write(text)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment", choices=("test", "prod"), required=True)
    parser.add_argument("--platform", choices=tuple(PLATFORM_KEYS), required=True)
    parser.add_argument("--signed", action="store_true")
    parser.add_argument("--output", required=True)
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--build-number")
    args = parser.parse_args(argv)
    try:
        ref = os.environ.get("GITHUB_REF", "")
        if ref.startswith("refs/tags/v") and args.environment != "prod":
            raise ConfigError("v tags require APP_ENV=prod")
        signed = args.signed or ref.startswith("refs/tags/v")
        config = make_config(args.environment, args.platform, signed, os.environ)
        number = args.build_number or subprocess.check_output(
            ["git", "rev-list", "--count", "HEAD"], text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        name, number = release_version(ref, Path(args.pubspec).read_text(), number)
        write_private(args.output, json.dumps(config, ensure_ascii=False) + "\n")
        github_output = os.environ.get("GITHUB_OUTPUT")
        if github_output:
            with open(github_output, "a") as output:
                output.write(f"build_name={name}\nbuild_number={number}\n")
        print(f"Validated {args.environment}/{args.platform}; signed={signed}; "
              f"platform_key_present={PLATFORM_KEYS[args.platform] in config}; "
              f"version={name}+{number}")
        return 0
    except (ConfigError, OSError, subprocess.CalledProcessError) as error:
        # Config errors identify only field names; never print input values or credentials.
        print(f"mobile release configuration rejected: {error if isinstance(error, ConfigError) else type(error).__name__}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
