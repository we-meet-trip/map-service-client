#!/usr/bin/env python3
"""Reject a hosting directory whose invite and app-link files disagree.

The invite landing page fetches invite-environment.json and refuses to open the
app without it, so a publish that drops the file turns every web invite into a
dead end while the deploy still reports success. Android App Links fail the same
way when assetlinks.json names a package the manifest never declares.

Only files already present in the directory are read; nothing is generated and
no network call is made. Values that identify an environment are compared, never
printed alongside their source path, so a failure names the field, not the file
contents.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

FINGERPRINT = re.compile(r'[0-9A-F]{2}(:[0-9A-F]{2}){31}')
SCHEME = re.compile(r'[a-z][a-z0-9+.-]*')
ORIGIN = re.compile(r'https://[a-z0-9.-]+\.[a-z]{2,}')
PACKAGE = re.compile(r'[a-z][a-z0-9_]*(\.[a-z0-9_]+)+')
APPLE_ID = re.compile(r'[A-Z0-9]{10}\..+')
REQUIRED = ('schema_version', 'app_environment', 'android_package', 'invite_scheme',
            'invite_origin', 'app_config_url', 'api_allowed_origins', 'public_site_origin')


class CheckError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise CheckError(message)


def load(path, expected_type):
    require(path.is_file() and not path.is_symlink(), f'{path.name} 가 없다')
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, UnicodeError, ValueError):
        raise CheckError(f'{path.name} 를 JSON 으로 읽지 못했다') from None
    require(isinstance(value, expected_type), f'{path.name} 의 최상위 형식이 다르다')
    return value


def read_environment(directory):
    manifest = load(directory / 'invite-environment.json', dict)
    missing = [key for key in REQUIRED if key not in manifest]
    require(not missing, 'invite-environment.json 에 ' + ', '.join(missing) + ' 가 없다')
    require(manifest['schema_version'] == 1, 'invite-environment.json 의 schema_version 이 1 이 아니다')
    require(manifest['app_environment'] in ('test', 'prod'),
            'invite-environment.json 의 app_environment 는 test 또는 prod 여야 한다')
    package = manifest['android_package']
    require(isinstance(package, str) and PACKAGE.fullmatch(package),
            'invite-environment.json 의 android_package 형식이 아니다')
    require(isinstance(manifest['invite_scheme'], str) and SCHEME.fullmatch(manifest['invite_scheme']),
            'invite-environment.json 의 invite_scheme 형식이 아니다')
    origins = manifest['api_allowed_origins']
    require(isinstance(origins, list) and origins
            and all(isinstance(o, str) and ORIGIN.fullmatch(o) for o in origins),
            'invite-environment.json 의 api_allowed_origins 가 HTTPS 출처 목록이 아니다')
    for field in ('invite_origin', 'public_site_origin'):
        require(isinstance(manifest[field], str) and ORIGIN.fullmatch(manifest[field]),
                f'invite-environment.json 의 {field} 가 HTTPS 출처가 아니다')
    require(isinstance(manifest['app_config_url'], str)
            and manifest['app_config_url'].startswith(manifest['public_site_origin'] + '/'),
            'invite-environment.json 의 app_config_url 이 public_site_origin 아래에 있지 않다')
    return manifest


def check_android(directory, package):
    statements = load(directory / '.well-known/assetlinks.json', list)
    require(statements, 'assetlinks.json 이 비어 있다')
    matched = 0
    for statement in statements:
        require(isinstance(statement, dict), 'assetlinks.json 항목이 객체가 아니다')
        target = statement.get('target')
        require(isinstance(target, dict), 'assetlinks.json 항목에 target 이 없다')
        if target.get('namespace') != 'android_app' or target.get('package_name') != package:
            continue
        require('delegate_permission/common.handle_all_urls' in (statement.get('relation') or []),
                'assetlinks.json 의 대상 항목에 링크 위임 관계가 없다')
        prints = target.get('sha256_cert_fingerprints')
        require(isinstance(prints, list) and prints
                and all(isinstance(p, str) and FINGERPRINT.fullmatch(p) for p in prints),
                'assetlinks.json 의 서명 지문이 SHA-256 형식이 아니다')
        matched += 1
    require(matched, 'assetlinks.json 에 이번 환경의 앱 패키지 항목이 없다')


def check_apple(directory, package):
    """iOS 는 서명 자격이 있어야 앱 식별자가 정해진다. 파일이 없으면 그
    사실을 알리고, 있으면 안드로이드와 같은 패키지를 가리키는지 본다."""
    path = directory / '.well-known/apple-app-site-association'
    if not path.exists() and not path.is_symlink():
        return False
    association = load(path, dict)
    details = ((association.get('applinks') or {}) if isinstance(association.get('applinks'), dict) else {}).get('details')
    require(isinstance(details, list) and details,
            'apple-app-site-association 에 applinks.details 가 비어 있다')
    for detail in details:
        require(isinstance(detail, dict), 'apple-app-site-association 의 details 항목이 객체가 아니다')
        app_id = detail.get('appID')
        require(isinstance(app_id, str) and APPLE_ID.fullmatch(app_id),
                'apple-app-site-association 의 appID 가 팀 접두사와 번들로 이뤄지지 않았다')
        require(app_id.endswith('.' + package),
                'apple-app-site-association 의 appID 가 이번 환경의 앱을 가리키지 않는다')
        require('/invite/*' in (detail.get('paths') or []),
                'apple-app-site-association 의 paths 에 초대 경로가 없다')
    return True


def check_app_config(directory, manifest):
    """주소 파일 자체의 존재는 기존 검사가 본다. 여기서는 그 주소가 이번
    환경이 허용한 출처인지만 겹쳐 본다 — 둘이 어긋나면 앱이 켜지자마자
    설정을 거부하고, 그 사실은 배포 결과에 드러나지 않는다."""
    path = directory / 'app_config.json'
    if not path.exists():
        return False
    config = load(path, dict)
    base = config.get('api_base_url')
    require(isinstance(base, str) and base in manifest['api_allowed_origins'],
            'app_config.json 의 api_base_url 이 이번 환경의 허용 출처에 없다')
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        directory = args.directory
        require(directory.is_dir(), '배포할 디렉터리가 없다')
        manifest = read_environment(directory)
        package = manifest['android_package']
        check_android(directory, package)
        apple = check_apple(directory, package)
        config = check_app_config(directory, manifest)
    except CheckError as error:
        print(f'✗ {error}', file=sys.stderr)
        print('  scripts/mobile-link-associations.py 로 이번 환경의 파일을 만든 뒤 함께 올린다.',
              file=sys.stderr)
        return 1
    print(f"✓ {manifest['app_environment']} 초대·앱링크 파일이 서로 맞는다")
    if not apple:
        print('  iOS 범용 링크 파일은 없다 — 애플 서명 자격이 정해진 뒤 만들어 함께 올린다.')
    if not config:
        print('  app_config.json 은 이 검사 대상에 없었다 — 주소 파일 검사가 따로 본다.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
