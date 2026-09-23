#!/usr/bin/env python3
"""Serve a freshly built public bundle with the production Caddy config and probe it locally."""
import argparse
import hashlib
import http.client
import importlib.util
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CADDYFILE = ROOT.parent / 'map-service-infra/edge/Caddyfile.prod'
IMAGE = 'caddy:2-alpine'
NAME = 'map-landing-check'
PORT = 8420
HOST = 'mapservice.app'
# 한국 App Store 의 공개 주소. 페이지가 이 주소를 그대로 걸고 있어야 한다.
APP_STORE_URL = 'https://apps.apple.com/kr/app/m-a-p/id6811266533'
# ncp-production-serving.py 가 공개 직전에 반드시 있어야 한다고 보는 경로들.
REQUIRED = {'index.html', 'app_config.json', 'invite-environment.json', 'invite/index.html',
            '.well-known/apple-app-site-association', '.well-known/assetlinks.json',
            *('legal/' + name + '.html' for name in
              ('privacy', 'terms', 'location-terms', 'support', 'delete-account'))}
# 번들 바깥에서 소비되는 파일들. 설치된 앱과 딥링크 검증이 이 바이트를 그대로 읽는다.
MOBILE_FACING = {'app_config.json', 'invite-environment.json', 'invite/index.html',
                 '.well-known/apple-app-site-association', '.well-known/assetlinks.json'}
DRAFT_NOTICE = ('<main>\n<aside role="note"><strong>운영 준비 초안 — 스토어 제출 및 '
                '운영 공개 불가</strong></aside>').encode()


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


content = module('landing_content', 'hosting-content-check.py')


def digest(body):
    return hashlib.sha256(body).hexdigest()


def docker(args, **kw):
    return subprocess.run(['docker', *args], capture_output=True, text=True, **kw)


def port_free():
    with socket.socket() as probe:
        return probe.connect_ex(('127.0.0.1', PORT)) != 0


def request(path):
    """Ask the local container as if it were the public site; never follow a redirect."""
    connection = http.client.HTTPConnection('127.0.0.1', PORT, timeout=10)
    try:
        connection.request('GET', path, headers={'Host': HOST, 'Accept': '*/*'})
        response = connection.getresponse()
        return response.status, dict(response.getheaders()), response.read()
    finally:
        connection.close()


def adapt(work):
    """Turn the production Caddyfile into a local config without editing the file itself."""
    result = docker(['run', '--rm', '--network', 'none', '--pull', 'never',
                     '-e', 'EDGE_EMAIL=landing-check@invalid',
                     '-v', f'{CADDYFILE}:/etc/caddy/Caddyfile:ro', IMAGE,
                     'caddy', 'adapt', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile'])
    if result.returncode:
        raise SystemExit('caddy adapt failed: ' + result.stderr[-500:])
    config = json.loads(result.stdout)
    servers = config['apps']['http']['servers']
    before = json.dumps([s.get('routes') for s in servers.values()], sort_keys=True)
    for server in servers.values():
        server['listen'] = [':80']
        server['automatic_https'] = {'disable': True}
    config['apps'].pop('tls', None)
    after = json.dumps([s.get('routes') for s in servers.values()], sort_keys=True)
    # 경로 판정은 한 글자도 건드리지 않았음을 증명한다. 여기가 어긋나면 이 검사는
    # 운영과 다른 설정을 시험한 것이 된다.
    if before != after:
        raise SystemExit('routing changed while neutralising TLS')
    path = work / 'caddy.json'
    path.write_text(json.dumps(config))
    return path


def build(work, cert, prefix):
    output = work / 'bundle'
    result = subprocess.run([sys.executable, str(ROOT / 'scripts/prepare-ncp-public.py'),
                             '--output-dir', str(output), '--android-cert-sha256', cert,
                             '--apple-app-id-prefix', prefix], capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('bundle preparation failed: ' + result.stderr[-500:])
    return output, json.loads((output / 'manifest.json').read_text())


def check_inventory(public, manifest, failures):
    """ncp-production-serving.py 가 공개 직전에 거는 것과 같은 단언을 미리 건다."""
    files = manifest['files']
    actual = {}
    for path in public.rglob('*'):
        if path.is_symlink():
            failures.append('symlink in bundle: ' + path.name)
        elif path.is_file():
            actual[str(path.relative_to(public))] = digest(path.read_bytes())
    if not 0 < len(files) <= 10000:
        failures.append(f'file count out of range: {len(files)}')
    if set(actual) != set(files):
        failures.append('manifest and disk disagree: '
                        + str(set(actual) ^ set(files)))
    for name, value in actual.items():
        if files.get(name) != value:
            failures.append('hash mismatch: ' + name)
    missing = REQUIRED - set(actual)
    if missing:
        failures.append('required route missing: ' + ', '.join(sorted(missing)))
    return actual


def check_baseline(actual, public, baseline, failures):
    """공개 중인 번들과 대조해 모바일이 읽는 파일이 그대로인지 확인한다."""
    live = json.loads(Path(baseline).read_text())['files']
    for name in sorted(MOBILE_FACING):
        if actual.get(name) != live.get(name):
            failures.append('mobile-facing file changed: ' + name)
    for name in sorted(n for n in live if n.startswith('legal/')):
        stripped = (public / name).read_bytes().replace(DRAFT_NOTICE, b'<main>', 1)
        if digest(stripped) != live.get(name):
            failures.append('legal page changed: ' + name)
    if actual.get('index.html') == live.get('index.html'):
        failures.append('index.html did not change; the landing was not published')
    added = set(actual) - set(live)
    if added != {n for n in actual if n.startswith('assets/')}:
        failures.append('unexpected new files: ' + str(added))
    if set(live) - set(actual):
        failures.append('files disappeared: ' + str(set(live) - set(actual)))


def check_routes(public, actual, failures):
    for name in sorted(REQUIRED):
        status, headers, body = request('/' + name)
        if status != 200 or not body:
            failures.append(f'required route not served: /{name} -> {status}')
        if name.endswith('.json') or name.startswith('.well-known/'):
            if 'application/json' not in headers.get('Content-Type', ''):
                failures.append('json content type missing: /' + name)
    status, _, _ = request('/')
    if status != 200:
        failures.append(f'root not served: {status}')
    # 재작성이 전부 동시에 살아 있는지. 200 만으로는 엉뚱한 문서를 줘도 통과하므로
    # 받은 바이트가 그 문서의 해시와 같은지까지 본다.
    rewrites = {'/privacy': 'privacy', '/privacy/': 'privacy', '/terms': 'terms',
                '/location-terms': 'location-terms', '/support': 'support',
                '/legal/terms': 'terms', '/delete': 'delete-account',
                '/delete-account': 'delete-account', '/account-deletion': 'delete-account'}
    for route, name in rewrites.items():
        status, _, body = request(route)
        if status != 200 or digest(body) != actual.get('legal/' + name + '.html'):
            failures.append(f'rewrite broken: {route} -> {status}')
    status, _, body = request('/invite/anything')
    if status != 200 or digest(body) != actual.get('invite/index.html'):
        failures.append(f'invite rewrite broken: {status}')
    status, _, _ = request('/legal/not-present')
    if status != 404:
        failures.append(f'/legal/not-present must be 404, got {status}')


def check_assets(public, actual, failures):
    types = {'.webp': 'image/webp', '.svg': 'image/svg+xml'}
    names = sorted(n for n in actual if n.startswith('assets/'))
    if not names:
        failures.append('no assets published')
    for name in names:
        status, headers, body = request('/' + name)
        if status != 200:
            failures.append(f'asset not served: /{name} -> {status}')
            continue
        # 바이트가 같아야 어떤 매처도 이 요청을 가로채지 않았다는 뜻이 된다.
        if digest(body) != actual[name]:
            failures.append('asset body was rewritten: ' + name)
        expected = types[Path(name).suffix]
        if expected not in headers.get('Content-Type', ''):
            failures.append(f'wrong content type for {name}: {headers.get("Content-Type")}')
        if headers.get('X-Content-Type-Options') != 'nosniff':
            failures.append('nosniff header missing on ' + name)
        if 'Cache-Control' in headers:
            failures.append('asset unexpectedly matched a header matcher: ' + name)
    status, _, _ = request('/assets/does-not-exist.webp')
    if status != 404:
        failures.append(f'missing asset must be 404, got {status}')


def check_landing(public, failures):
    body = request('/')[2].decode('utf-8')
    page = content.Page(body)
    visible = ' '.join(page.text)
    if 'mapadmin26@gmail.com' not in visible:
        failures.append('contact address is not visible on the landing')
    for name in content.PAGES:
        if '/legal/' + name + '.html' not in page.hrefs:
            failures.append('landing is missing the policy link: ' + name)
    if 'MAPY' in body:
        failures.append('landing uses a wrong product name')
    if any(word in body for word in ('flutter_bootstrap', 'main.dart.js', '<flutter-view')):
        failures.append('landing carries an app shell')
    if 'AI' in visible and 'AI 추천은 외부 AI 전송 동의 후 이용' not in visible:
        failures.append('AI is mentioned without the consent footnote')
    if APP_STORE_URL not in page.hrefs:
        failures.append('landing does not link the published App Store page')
    if 'aria-disabled="true"' in body or '준비 중' in body:
        failures.append('landing still carries a store placeholder')
    for store in ('play.google.com', 'onestore.co.kr'):
        if store in body:
            failures.append('landing links a store that has no release: ' + store)
    # 가리키는 자산이 번들에 실제로 있는지. 오타 하나면 그림만 조용히 깨진다.
    for target in sorted(set(re.findall(r'(?:src|href)="/(assets/[^"]+)"', body))):
        if not (public / target).is_file():
            failures.append('landing references a missing asset: ' + target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--android-cert-sha256', required=True)
    parser.add_argument('--apple-app-id-prefix', required=True)
    parser.add_argument('--baseline-manifest', required=True,
                        help='Manifest of the bundle currently published')
    args = parser.parse_args()

    if not shutil.which('docker'):
        raise SystemExit('docker is required')
    if docker(['image', 'inspect', IMAGE]).returncode:
        raise SystemExit(IMAGE + ' is not present locally; this check never pulls')
    if not port_free():
        raise SystemExit(f'127.0.0.1:{PORT} is already in use')
    caddy_before = digest(CADDYFILE.read_bytes())

    work = Path(tempfile.mkdtemp(prefix='landing-check-'))
    failures = []
    try:
        output, manifest = build(work, args.android_cert_sha256, args.apple_app_id_prefix)
        public = output / 'public'
        actual = check_inventory(public, manifest, failures)
        check_baseline(actual, public, args.baseline_manifest, failures)
        config = adapt(work)
        docker(['rm', '-f', NAME])
        started = docker(['run', '--rm', '-d', '--name', NAME, '--pull', 'never',
                          '-p', f'127.0.0.1:{PORT}:80',
                          '-v', f'{public}:/srv/public:ro', '-v', f'{config}:/etc/caddy/caddy.json:ro',
                          IMAGE, 'caddy', 'run', '--config', '/etc/caddy/caddy.json'])
        if started.returncode:
            raise SystemExit('container failed to start: ' + started.stderr[-500:])
        # 도커가 호스트 포트를 먼저 잡기 때문에 포트가 찼는지로는 안을 알 수 없다.
        # 실제 응답이 올 때까지 기다린다.
        for attempt in range(50):
            try:
                request('/')
                break
            except OSError:
                if attempt == 49:
                    raise SystemExit('container did not start serving')
                time.sleep(0.2)
        check_routes(public, actual, failures)
        check_assets(public, actual, failures)
        check_landing(public, failures)
    finally:
        docker(['rm', '-f', NAME])
        shutil.rmtree(work, ignore_errors=True)

    if digest(CADDYFILE.read_bytes()) != caddy_before:
        failures.append('the production Caddyfile was modified')
    print(json.dumps({'status': 'FAIL' if failures else 'PASS', 'files': len(manifest['files']),
                      'assets': sum(n.startswith('assets/') for n in manifest['files']),
                      'failures': failures}, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
