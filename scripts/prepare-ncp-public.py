#!/usr/bin/env python3
"""Prepare NCP static files separately from Firebase; never publish or infer policy facts."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


mobile = module('ncp_mobile', 'mobile-release-config.py')
associations = module('ncp_associations', 'mobile-link-associations.py')
content = module('ncp_content', 'hosting-content-check.py')
secrets = module('ncp_secrets', 'web-secrets.py')
DRAFT_NOTICE = '<aside role="note"><strong>운영 준비 초안 — 스토어 제출 및 운영 공개 불가</strong></aside>'
PENDING = re.compile(r'DRAFT_NOT_SUBMITTABLE|운영 준비 초안|제한 시험 (?:단계|서비스|환경)|'
                     r'주소는 아직 확정되지|정식 운영 전|아직 검증되지|검증이 완료되지')


def digest(body):
    return hashlib.sha256(body).hexdigest()


def read_file(path):
    if not path.is_file() or path.is_symlink():
        raise ValueError('source must be a regular file, not a symlink')
    return path.read_bytes()


def policy_blockers(pages, review):
    """Verification binds the exact reviewed policy bytes; it is not legal certification."""
    blockers = []
    for name, body in pages.items():
        blockers.extend('policy_' + name + ':' + error for error in content.validate_body(body, name))
        if PENDING.search(body.decode('utf-8')):
            blockers.append('policy_draft:' + name)
    if not review or review.get('status') != 'REVIEWED_FOR_PRODUCTION':
        blockers.append('policy_review_missing')
        return blockers
    address = review.get('public_contact_address', '')
    if (not isinstance(address, str) or len(address.strip()) < 5
            or re.search(r'TODO|TBD|미정|미확정|YOUR_', address, re.I)):
        blockers.append('public_contact_address_missing')
    else:
        for name in ('privacy', 'terms', 'location-terms'):
            if address not in ' '.join(content.Page(pages[name].decode('utf-8')).text):
                blockers.append('public_contact_address_not_in_policy:' + name)
    if review.get('files') != {'legal/' + name + '.html': digest(body) for name, body in pages.items()}:
        blockers.append('reviewed_policy_hash_mismatch')
    return blockers


def prepare(output, policy_directory, certificates, apple_prefix, review, *, release=False):
    if output.exists() or output.is_symlink():
        raise ValueError('output directory must be new; existing Firebase or production files are never overwritten')
    pages = {name: read_file(policy_directory / (name + '.html')) for name in content.PAGES}
    blockers = policy_blockers(pages, review)
    source_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    source_ref = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    source_changes = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'],
                                            cwd=ROOT, text=True).strip()
    if source_ref != 'master' or source_changes:
        blockers.append('source_requires_clean_master_checkout')
    if not apple_prefix:
        blockers.append('apple_app_id_prefix_missing')
    config = mobile.make_config('prod', 'web', False, mobile.PROD_URLS)
    generated = associations.make_associations(config, certificates, apple_prefix, allow_missing_apple=not release)
    if release and blockers:
        raise ValueError('release blocked: ' + ', '.join(blockers))
    artifacts = {path: (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
                 for path, value in generated.items()}
    artifacts['app_config.json'] = (json.dumps({'environment': 'prod', 'api_base_url': mobile.PROD_URLS['API_ALLOWED_ORIGINS']}) + '\n').encode()
    artifacts['invite/index.html'] = read_file(ROOT / 'hosting/invite/index.html')
    for name, body in pages.items():
        if not release:
            body = body.replace(b'<main>', ('<main>\n' + DRAFT_NOTICE).encode(), 1)
        artifacts['legal/' + name + '.html'] = body
    links = ''.join(f'<li><a href="/legal/{name}.html">{title}</a></li>' for name, title in content.PAGES.items())
    artifacts['index.html'] = ('<!doctype html><html lang="ko"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1"><title>MAP 지원</title>'
        '<main><h1>MAP</h1>' + ('' if release else DRAFT_NOTICE) + '<ul>' + links + '</ul></main></html>\n').encode()
    public = output / 'public'
    public.mkdir(parents=True)
    for name, body in artifacts.items():
        path = public / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    # No client SDK keys are needed by this static site; reject every Google key.
    private_values = [*secrets.env_values(ROOT / '.env').items(),
                      *secrets.env_values(ROOT.parent / 'map-service-infra/.env').items(),
                      *secrets.env_values(ROOT.parent / 'map-service-infra/.env.test').items(),
                      *os.environ.items()]
    _, failures = secrets.scan([public], private_values, set())
    if failures:
        # Keep failed draft output for inspection; no publication-ready manifest is emitted.
        raise ValueError('static secret scan failed: ' + ', '.join(failures))
    manifest = {
        'schema_version': 1, 'status': 'READY_FOR_PUBLICATION' if release else 'DRAFT_NOT_SUBMITTABLE',
        'environment': 'prod', 'source_ref': source_ref, 'source_sha': source_sha,
        'public_site_origin': mobile.PROD_URLS['PUBLIC_SITE_ORIGIN'],
        'api_origin': mobile.PROD_URLS['API_ALLOWED_ORIGINS'],
        'android_package': config['NATIVE_APPLICATION_ID'], 'apple_app_id_prefix': apple_prefix,
        'files': {name: digest(body) for name, body in artifacts.items()},
        'blockers': blockers,
        'validation_scope': 'Static bundle only; no deployment, device, store or legal acceptance claim',
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--policy-directory', type=Path, default=ROOT / 'hosting/legal')
    parser.add_argument('--policy-review', type=Path, help='Verified policy content metadata; never published')
    parser.add_argument('--android-cert-sha256', action='append', required=True)
    parser.add_argument('--apple-app-id-prefix', help='Actual signed App ID prefix; never assume the Team ID')
    parser.add_argument('--release', action='store_true', help='Require clean master, actual signing metadata and reviewed final policies')
    args = parser.parse_args()
    try:
        review = json.loads(read_file(args.policy_review)) if args.policy_review else None
        if review is not None and not isinstance(review, dict):
            raise ValueError('policy review must be an object')
        result = prepare(args.output_dir, args.policy_directory, args.android_cert_sha256,
                         args.apple_app_id_prefix, review, release=args.release)
        print(json.dumps({'status': result['status'], 'files': len(result['files']),
                          'blockers': result['blockers']}, ensure_ascii=False))
        return 0
    except (OSError, ValueError, TypeError, subprocess.CalledProcessError) as error:
        print('NCP public preparation rejected: ' + (str(error) if isinstance(error, ValueError)
                                                     and not isinstance(error, json.JSONDecodeError)
                                                     else type(error).__name__), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
