#!/usr/bin/env python3
"""Prepare one environment's App Links, Universal Links and invite landing config.

No hosting publication is performed. Certificate fingerprints are public signing
metadata; use the certificate that signs the installed app (Play App Signing for
Play builds), not an upload certificate unless the artifact is directly installed.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys

spec = importlib.util.spec_from_file_location(
    'mobile_release_config', Path(__file__).with_name('mobile-release-config.py'))
config_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_module)


def make_associations(config, certificates, apple_app_id_prefix, *, allow_missing_apple=False):
    environment = config.get('APP_ENV')
    validated = config_module.make_config(environment, 'web', False, config)
    identity = config_module.native_identity(environment)
    for field, expected in identity.items():
        if config.get(field) != expected:
            raise ValueError(f'{field}: supplied config does not match APP_ENV')
    if not (allow_missing_apple and apple_app_id_prefix is None) and not re.fullmatch(r'[A-Z0-9]{10}', apple_app_id_prefix or ''):
        raise ValueError('Apple signed application-identifier prefix is required (10 uppercase characters)')
    normalized = []
    for fingerprint in certificates:
        value = fingerprint.replace(':', '').upper()
        if not re.fullmatch(r'[0-9A-F]{64}', value) or len(set(value)) == 1:
            raise ValueError('Android signing certificate SHA-256 must be a real 32-byte fingerprint')
        normalized.append(':'.join(value[i:i + 2] for i in range(0, 64, 2)))
    if not normalized:
        raise ValueError('At least one installed Android signing certificate SHA-256 is required')
    package = identity['NATIVE_APPLICATION_ID']
    artifacts = {
        '.well-known/assetlinks.json': [{
            'relation': ['delegate_permission/common.handle_all_urls'],
            'target': {'namespace': 'android_app', 'package_name': package,
                       'sha256_cert_fingerprints': list(dict.fromkeys(normalized))},
        }],
        'invite-environment.json': {
            'schema_version': 1, 'app_environment': environment,
            'android_package': package, 'invite_scheme': identity['INVITE_URL_SCHEME'],
            'invite_origin': validated['INVITE_LINK_ORIGIN'],
            'app_config_url': validated['APP_CONFIG_URL'],
            'api_allowed_origins': validated['API_ALLOWED_ORIGINS'].split(','),
            'public_site_origin': validated['PUBLIC_SITE_ORIGIN'],
        },
    }
    if apple_app_id_prefix is not None:
        artifacts['.well-known/apple-app-site-association'] = {
            'applinks': {'apps': [], 'details': [{
                'appID': f'{apple_app_id_prefix}.{package}', 'paths': ['/invite/*'],
            }]},
        }
    return artifacts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--android-cert-sha256', action='append', required=True)
    parser.add_argument('--apple-app-id-prefix', required=True)
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args(argv)
    try:
        config = json.loads(Path(args.config).read_text())
        artifacts = make_associations(config, args.android_cert_sha256, args.apple_app_id_prefix)
        output = Path(args.output_dir)
        # A pre-existing manifest from the other environment must never be overwritten.
        previous = output / 'invite-environment.json'
        if previous.exists() and json.loads(previous.read_text()).get('app_environment') != config['APP_ENV']:
            raise ValueError('Output directory belongs to a different app environment')
        for name, value in artifacts.items():
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
        print(f"Prepared {config['APP_ENV']} association files; no publication performed")
    except (OSError, ValueError, KeyError, TypeError) as error:
        # Do not echo config or certificate inputs on failures.
        print(f'association preparation rejected: {error if isinstance(error, ValueError) and not isinstance(error, json.JSONDecodeError) else type(error).__name__}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
