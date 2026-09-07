#!/usr/bin/env python3
"""Record built artifact hashes and privacy/SDK inventory without client keys."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--kind', choices=['android-signed', 'android-compile-only',
                                         'ios-signed', 'ios-compile-only', 'ios-simulator'], required=True)
    parser.add_argument('--artifact', action='append', default=[])
    parser.add_argument('--app-directory')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    source = json.loads(Path(args.config).read_text())
    fields = ['APP_ENV', 'NATIVE_APPLICATION_ID', 'INVITE_URL_SCHEME', 'KAKAO_CALLBACK_SCHEME',
              'INVITE_LINK_ORIGIN', 'APP_CONFIG_URL', 'API_ALLOWED_ORIGINS', 'PUBLIC_SITE_ORIGIN']
    result = {
        'schema_version': 1, 'recorded_utc': datetime.now(timezone.utc).isoformat(),
        'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'kind': args.kind, 'runner_architecture': platform.machine(),
        'environment': {field: source[field] for field in fields},
        'artifacts': [], 'privacy_manifests': [],
        'validation_scope': 'Build provenance and inventory only; no device, service, console or store acceptance claim',
    }
    for name in args.artifact:
        path = Path(name)
        if not path.is_file():
            raise SystemExit('Required artifact is missing')
        result['artifacts'].append({'path': name, 'sha256': digest(path), 'size_bytes': path.stat().st_size})
    if args.app_directory:
        app = Path(args.app_directory)
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != source['NATIVE_APPLICATION_ID']:
            raise SystemExit('Built iOS bundle identifier mismatch')
        schemes = [scheme for entry in info.get('CFBundleURLTypes', []) for scheme in entry.get('CFBundleURLSchemes', [])]
        if sorted(schemes) != sorted([source['INVITE_URL_SCHEME'], source['KAKAO_CALLBACK_SCHEME']]):
            raise SystemExit('Built iOS URL scheme mismatch')
        result['ios_bundle'] = {key: info.get(key) for key in ['CFBundleIdentifier', 'CFBundleDisplayName',
                                                             'CFBundleShortVersionString', 'CFBundleVersion',
                                                             'MinimumOSVersion', 'DTSDKName', 'DTXcode', 'DTXcodeBuild']}
        for path in sorted(app.rglob('*.xcprivacy')):
            result['privacy_manifests'].append({'path': str(path.relative_to(app)),
                                               'sha256': digest(path),
                                               'declarations': plistlib.loads(path.read_bytes())})
    for name in ['pubspec.lock', 'ios/Podfile.lock']:
        path = Path(name)
        if path.exists():
            result.setdefault('dependency_locks', []).append({'path': name, 'sha256': digest(path)})
    result['flutter'] = json.loads(subprocess.check_output(['flutter', '--version', '--machine'], text=True))
    if shutil.which('xcodebuild'):
        result['xcode'] = subprocess.check_output(['xcodebuild', '-version'], text=True).strip()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print('Artifact provenance and privacy inventory recorded; client keys omitted')


if __name__ == '__main__':
    main()
