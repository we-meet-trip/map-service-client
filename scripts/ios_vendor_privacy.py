#!/usr/bin/env python3
"""Verify resolved Maps versions and genuine vendor privacy declarations; no builds."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess


EXPECTED_VERSIONS = {'GoogleMaps': '9.4.0', 'Google-Maps-iOS-Utils': '6.1.0'}
# Retrieved from Google's tagged source, not a locally authored replacement manifest.
VENDOR_SOURCE = ('https://raw.githubusercontent.com/googlemaps/ios-maps-sdk/9.4.0/'
                 'Maps/Resources/GoogleMapsResources/GoogleMaps.bundle/PrivacyInfo.xcprivacy')
VENDOR_SOURCE_SHA256 = '47734417f3f8617743fdfa6efdda9df04664f8a91519ff22208df9f022598501'
VENDOR_DECLARATIONS_SHA256 = '3ac68d0dcd83454f684b76aa5c9187479bc5dffb41368a4864086e278133cb44'


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path, root):
    path, root = Path(path), Path(root)
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Vendor evidence path must stay inside its artifact root')
    if not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise ValueError('Required vendor evidence file missing or oversized')
    return path.read_bytes()


def lock_versions(path):
    """Only top-level PODS entries; reject duplicates and unparseable versions."""
    text = Path(path).read_text()
    pods = text.split('PODS:\n', 1)
    if len(pods) != 2:
        raise ValueError('CocoaPods lock has no PODS section')
    section = re.split(r'\n[A-Z][A-Z _]+:\n', pods[1], maxsplit=1)[0]
    versions = {}
    for line in section.splitlines():
        if not line.startswith('  - '):
            continue
        match = re.fullmatch(r'  - ([\w/.-]+) \(([0-9][\w.+-]*)\):?', line)
        if not match or match[1] in versions:
            raise ValueError('Unexpected or duplicate CocoaPods lock entry')
        versions[match[1]] = match[2]
    return versions


def check_lock(path, baseline=None):
    versions = lock_versions(path)
    for name, expected in EXPECTED_VERSIONS.items():
        if versions.get(name) != expected:
            raise ValueError(f'Resolved {name} must be {expected}')
    if any(version != '9.4.0' for name, version in versions.items() if name.startswith('GoogleMaps/')):
        raise ValueError('GoogleMaps subspec version mismatch')
    if baseline:
        keep = lambda items: {name: version for name, version in items.items()
                              if name != 'Google-Maps-iOS-Utils' and name.split('/')[0] != 'GoogleMaps'}
        if keep(versions) != keep(lock_versions(baseline)):
            raise ValueError('Selective Maps resolution changed an unrelated pod version')
    return versions


def declaration_record(path, root):
    raw = read_file(path, root)
    value = plistlib.loads(raw)
    if not isinstance(value, dict):
        raise ValueError('Vendor privacy manifest must be a dictionary')
    canonical = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    if sha256(canonical) != VENDOR_DECLARATIONS_SHA256:
        raise ValueError('Vendor privacy declarations differ from the reviewed Google source')
    return {'path': str(Path(path).relative_to(root)), 'sha256': sha256(raw),
            'declarations_sha256': sha256(canonical), 'declarations': value}


def inspect_vendor_privacy(pod_lock, pods_directory, app_directory=None, baseline=None):
    pod_lock, pods = Path(pod_lock), Path(pods_directory)
    versions = check_lock(pod_lock, baseline)
    if read_file(pods / 'Manifest.lock', pods) != pod_lock.read_bytes():
        raise ValueError('CocoaPods installed manifest does not match the resolved lock')
    vendor_root = pods / 'GoogleMaps/Maps/Resources/GoogleMapsResources'
    sources = sorted(vendor_root.rglob('PrivacyInfo.xcprivacy'))
    if len(sources) != 1:
        raise ValueError('Exactly one original Google Maps vendor privacy manifest is required')
    source_record = declaration_record(sources[0], pods)
    if source_record['sha256'] != VENDOR_SOURCE_SHA256:
        raise ValueError('Installed vendor source bytes differ from the reviewed Google source')
    result = {
        'status': 'PASS', 'resolved_versions': {key: versions[key] for key in EXPECTED_VERSIONS},
        'pod_lock_sha256': sha256(pod_lock.read_bytes()),
        'reference': {'url': VENDOR_SOURCE, 'sha256': VENDOR_SOURCE_SHA256,
                      'declarations_sha256': VENDOR_DECLARATIONS_SHA256},
        'installed_vendor_manifest': source_record,
        'scope': 'Vendor declaration provenance; not a full App Privacy or store acceptance decision',
    }
    if app_directory:
        app = Path(app_directory)
        # The Flutter plugin's separate privacy bundle cannot satisfy this vendor gate.
        bundled = sorted((app / 'GoogleMapsResources.bundle').rglob('PrivacyInfo.xcprivacy'))
        if len(bundled) != 1:
            raise ValueError('Built app lacks its own Google Maps vendor privacy manifest')
        result['bundled_vendor_manifest'] = declaration_record(bundled[0], app)
        info = plistlib.loads(read_file(app / 'Info.plist', app))
        if info.get('MinimumOSVersion') != '15.0':
            raise ValueError('Built iOS minimum must match the reviewed iOS 15 contract')
        result['minimum_os_version'] = info['MinimumOSVersion']
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pod-lock', default='ios/Podfile.lock')
    parser.add_argument('--pods-directory', default='ios/Pods')
    parser.add_argument('--app-directory')
    parser.add_argument('--baseline-pod-lock')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    result = {'schema_version': 1, 'recorded_utc': datetime.now(timezone.utc).isoformat(),
              'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()}
    try:
        result.update(inspect_vendor_privacy(args.pod_lock, args.pods_directory,
                                             args.app_directory, args.baseline_pod_lock))
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        result.update(status='FAIL', reason=str(error))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    if result['status'] != 'PASS':
        raise SystemExit('iOS vendor privacy gate failed; inspect the evidence artifact')
    print('iOS vendor privacy provenance verified')


if __name__ == '__main__':
    main()
