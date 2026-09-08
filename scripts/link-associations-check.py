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
import importlib.util
import json
from pathlib import Path
import re
import sys

FINGERPRINT = re.compile(r'[0-9A-F]{2}(:[0-9A-F]{2}){31}')
APPLE_PREFIX = re.compile(r'[A-Z0-9]{10}')
REQUIRED = ('schema_version', 'app_environment', 'android_package', 'invite_scheme',
            'invite_origin', 'app_config_url', 'api_allowed_origins', 'public_site_origin')

spec = importlib.util.spec_from_file_location(
    'mobile_release_config', Path(__file__).with_name('mobile-release-config.py'))
config_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_module)


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
    require(type(manifest['schema_version']) is int and manifest['schema_version'] == 1,
            'invite-environment.json 의 schema_version 이 1 이 아니다')
    require(manifest['app_environment'] in ('test', 'prod'),
            'invite-environment.json 의 app_environment 는 test 또는 prod 여야 한다')
    identity = config_module.native_identity(manifest['app_environment'])
    require(manifest['android_package'] == identity['NATIVE_APPLICATION_ID'],
            'invite-environment.json 의 android_package 가 이번 환경의 앱이 아니다')
    require(manifest['invite_scheme'] == identity['INVITE_URL_SCHEME'],
            'invite-environment.json 의 invite_scheme 이 이번 환경의 앱과 다르다')
    origins = manifest['api_allowed_origins']
    require(isinstance(origins, list) and origins
            and all(isinstance(o, str) and o and ',' not in o for o in origins),
            'invite-environment.json 의 api_allowed_origins 가 HTTPS 출처 목록이 아니다')
    fields = {'invite_origin': 'INVITE_LINK_ORIGIN', 'public_site_origin': 'PUBLIC_SITE_ORIGIN',
              'app_config_url': 'APP_CONFIG_URL'}
    require(all(isinstance(manifest[field], str) and manifest[field] for field in fields),
            'invite-environment.json 의 URL 필드가 비어 있거나 문자열이 아니다')
    inputs = {key: manifest[field] for field, key in fields.items()}
    inputs['API_ALLOWED_ORIGINS'] = ','.join(origins)
    try:
        validated = config_module.make_config(manifest['app_environment'], 'web', False, inputs)
    except config_module.ConfigError as error:
        raise CheckError(f'invite-environment.json: {error}') from None
    require(all(manifest[field] == validated[key] for field, key in fields.items())
            and origins == validated['API_ALLOWED_ORIGINS'].split(','),
            'invite-environment.json 의 URL 은 정규화된 모바일 환경 계약과 같아야 한다')
    require(manifest['app_config_url'].startswith(manifest['public_site_origin'] + '/'),
            'invite-environment.json 의 app_config_url 이 public_site_origin 아래에 있지 않다')
    return manifest


def normalize_fingerprint(value):
    require(isinstance(value, str), '서명 지문이 문자열이 아니다')
    compact = value.replace(':', '').upper()
    require(re.fullmatch(r'[0-9A-F]{64}', compact)
            and len(set(compact[i:i + 2] for i in range(0, 64, 2))) > 1,
            '서명 지문은 반복 가짜 값이 아닌 SHA-256 형식이어야 한다')
    return ':'.join(compact[i:i + 2] for i in range(0, 64, 2))


def check_android(directory, package, expected_certificates=None):
    statements = load(directory / '.well-known/assetlinks.json', list)
    require(statements, 'assetlinks.json 이 비어 있다')
    matched = 0
    actual_certificates = set()
    for statement in statements:
        require(isinstance(statement, dict), 'assetlinks.json 항목이 객체가 아니다')
        target = statement.get('target')
        require(isinstance(target, dict), 'assetlinks.json 항목에 target 이 없다')
        require(target.get('namespace') == 'android_app' and target.get('package_name') == package,
                'assetlinks.json 에 이번 환경과 다른 앱 패키지 항목이 있다')
        relations = statement.get('relation')
        require(isinstance(relations, list) and all(isinstance(r, str) for r in relations)
                and 'delegate_permission/common.handle_all_urls' in relations,
                'assetlinks.json 의 대상 항목에 링크 위임 관계가 없다')
        prints = target.get('sha256_cert_fingerprints')
        require(isinstance(prints, list) and prints
                and all(isinstance(p, str) and FINGERPRINT.fullmatch(p) for p in prints),
                'assetlinks.json 의 서명 지문이 SHA-256 형식이 아니다')
        actual_certificates.update(normalize_fingerprint(p) for p in prints)
        matched += 1
    require(matched, 'assetlinks.json 에 이번 환경의 앱 패키지 항목이 없다')
    if expected_certificates is not None:
        expected = {normalize_fingerprint(p) for p in expected_certificates}
        require(expected and actual_certificates == expected,
                'assetlinks.json 의 지문이 외부에서 제공한 실제 설치 서명 인증서와 다르다')


def check_apple(directory, package, expected_prefix=None):
    """파일 정합과 외부에서 제공한 서명 prefix 대조를 구별한다."""
    if expected_prefix is not None:
        require(APPLE_PREFIX.fullmatch(expected_prefix), '기대 Apple 앱 접두사 형식이 아니다')
    path = directory / '.well-known/apple-app-site-association'
    if not path.exists() and not path.is_symlink():
        require(expected_prefix is None, '기대 Apple 앱 접두사가 있지만 apple-app-site-association 이 없다')
        return False
    association = load(path, dict)
    details = ((association.get('applinks') or {}) if isinstance(association.get('applinks'), dict) else {}).get('details')
    require(isinstance(details, list) and details,
            'apple-app-site-association 에 applinks.details 가 비어 있다')
    for detail in details:
        require(isinstance(detail, dict), 'apple-app-site-association 의 details 항목이 객체가 아니다')
        app_id = detail.get('appID')
        require(isinstance(app_id, str) and '.' in app_id,
                'apple-app-site-association 의 appID 가 앱 접두사와 번들로 이뤄지지 않았다')
        prefix, bundle = app_id.split('.', 1)
        require(APPLE_PREFIX.fullmatch(prefix) and bundle == package,
                'apple-app-site-association 의 appID 가 이번 환경의 앱을 가리키지 않는다')
        if expected_prefix is not None:
            require(prefix == expected_prefix,
                    'apple-app-site-association 의 appID 가 외부에서 제공한 실제 앱 접두사와 다르다')
        paths = detail.get('paths')
        require(isinstance(paths, list) and all(isinstance(p, str) for p in paths)
                and '/invite/*' in paths,
                'apple-app-site-association 의 paths 에 초대 경로가 없다')
    return True


def check_app_config(directory, manifest):
    """환경 표식과 API 출처를 모바일이 허용한 계약과 대조한다."""
    path = directory / 'app_config.json'
    if not path.exists() and not path.is_symlink():
        return False
    config = load(path, dict)
    require(config.get('environment') == manifest['app_environment'],
            'app_config.json 의 environment 가 이번 환경과 다르거나 없다')
    base = config.get('api_base_url')
    require(isinstance(base, str) and base in manifest['api_allowed_origins'],
            'app_config.json 의 api_base_url 이 이번 환경의 허용 출처에 없다')
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--android-cert-sha256', action='append',
                        help='Verified installed signer SHA-256; repeat for every permitted signer')
    parser.add_argument('--apple-app-id-prefix',
                        help='Verified signed application-identifier prefix, not an assumed Team ID')
    args = parser.parse_args(argv)
    try:
        directory = args.directory
        require(directory.is_dir(), '배포할 디렉터리가 없다')
        manifest = read_environment(directory)
        package = manifest['android_package']
        check_android(directory, package, args.android_cert_sha256)
        apple = check_apple(directory, package, args.apple_app_id_prefix)
        config = check_app_config(directory, manifest)
        if manifest['app_environment'] == 'prod':
            require(apple, 'prod 에는 apple-app-site-association 이 필요하다')
            require(config, 'prod 에는 app_config.json 이 필요하다')
    except CheckError as error:
        print(f'✗ {error}', file=sys.stderr)
        print('  scripts/mobile-link-associations.py 로 이번 환경의 파일을 만든 뒤 함께 올린다.',
              file=sys.stderr)
        return 1
    print(f"✓ {manifest['app_environment']} 초대·앱링크 파일이 서로 맞는다")
    print('  Android 실제 인증서 대조: ' + ('PASS (제공된 기대값)' if args.android_cert_sha256 else 'NOT_RUN (기대값 미제공)'))
    if not apple:
        print('  iOS 범용 링크: NOT_RUN — 애플 서명 자격이 정해진 뒤 만들어 함께 올린다.')
    else:
        print('  Apple 실제 앱 접두사 대조: ' + ('PASS (제공된 기대값)' if args.apple_app_id_prefix else 'NOT_RUN (기대값 미제공)'))
    if not config:
        print('  app_config.json: NOT_RUN — 주소 파일 검사가 따로 본다.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
