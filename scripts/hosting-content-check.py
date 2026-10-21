#!/usr/bin/env python3
"""Check public policy bodies locally and optionally anonymous HTTPS bytes."""
import argparse
import concurrent.futures
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
import subprocess
import tempfile
from datetime import datetime, timezone

PAGES = {'privacy': 'MAP 개인정보처리방침', 'terms': 'MAP 이용약관',
         'location-terms': 'MAP 위치기반서비스 이용약관',
         'support': 'MAP 지원 및 신고 안내', 'delete-account': 'MAP 계정 및 개인정보 삭제 요청'}
ALIASES = {**{name: name for name in PAGES}, 'delete': 'delete-account', 'account-deletion': 'delete-account'}
# 이전 판 보관본. 원본은 그 시기의 게시본 바이트 그대로이고, <main> 바로 뒤에 안내 한 줄만 더한다.
# 값은 (문서, 안내 제목, 원본 sha256) — 보관본 파일 자체의 해시가 아니다.
ARCHIVE_DIRECTORY = 'legal/archive/'
_FIRST = '이전 판(적용 2026-09-15~2026-10-22)'
_NOTICE = '변경 예정 안내를 더한 이전 판(적용 2026-10-15~2026-10-22)'
ARCHIVES = {
    'legal/archive/privacy-2026-09-15.html': (
        'privacy', _FIRST, '0e34f017fc5ba93eb8551c6a1aaac3cf33e47bddd23b35d6ebf836c9d6f0becc'),
    'legal/archive/terms-2026-09-15.html': (
        'terms', _FIRST, 'bd049421e06dc3c4350ac2d0e458246b22d495e9bb1675ee7d98dc54106dd7f1'),
    'legal/archive/location-terms-2026-09-15.html': (
        'location-terms', _FIRST, '30353ef128f62c9a1737786a3a617ed0448975d72584daa988898f450ec3f47e'),
    'legal/archive/privacy-2026-10-15.html': (
        'privacy', _NOTICE, 'b94f5d293c493f2396929d94d6ae01f01ddb695935263af706e4b9c181eb4a87'),
    'legal/archive/terms-2026-10-15.html': (
        'terms', _NOTICE, '48fa823464100e011506cacd6825a9ea6b23310192bac0b37c36419bcd3f29b6'),
    'legal/archive/location-terms-2026-10-15.html': (
        'location-terms', _NOTICE, 'f751363d55ceeb6257ee5404374a31371af002202e5caa93774f8d1a319b9bf2'),
}


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.tags, self.hrefs, self.text = [], [], []
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        self.tags.append(tag)
        self.hrefs.extend(v for k, v in attrs if k == 'href')
    def handle_data(self, data):
        self.text.append(data)


def validate_body(body, name):
    text = body.decode('utf-8')
    page = Page(text)
    visible = ' '.join(page.text)
    errors = []
    if PAGES[name] not in visible or 'h1' not in page.tags or len(visible) < 500:
        errors.append('missing_policy_body')
    if any(word in text for word in ('flutter_bootstrap', 'main.dart.js', '<flutter-view')):
        errors.append('spa_fallback')
    if re.search(r'\bTODO\b|\bTBD\b|YOUR_ADDRESS|주소를 입력', text, re.I):
        errors.append('placeholder')
    if 'mapadmin26@gmail.com' not in visible:
        errors.append('missing_contact')
    if not all('/legal/'+p+'.html' in page.hrefs for p in PAGES):
        errors.append('missing_absolute_policy_navigation')
    if name == 'delete-account':
        for phrase in ('본인 확인', '다른 참여자', '백업', '접수', '처리'):
            if phrase not in visible:
                errors.append('missing_deletion_'+phrase)
    return errors


def archive_notice(path):
    """보관본에서 <main> 을 대신하는 바이트. 안내는 현재 판으로 돌아가는 링크 하나다."""
    page, title, _ = ARCHIVES[path]
    return ('<main>\n<aside role="note" class="notice"><strong>' + title + '</strong>'
            ' — <a href="/legal/' + page + '.html">현재 판 보기</a></aside>').encode()


def validate_archive(body, path):
    """안내를 한 번만 더했고, 안내를 걷어 내면 원본 바이트와 같아야 한다."""
    notice = archive_notice(path)
    if body.count(notice) == 0:
        return ['archive_notice_missing']
    if body.count(notice) > 1:
        return ['archive_notice_duplicated']
    if hashlib.sha256(body.replace(notice, b'<main>', 1)).hexdigest() != ARCHIVES[path][2]:
        return ['archive_bytes_changed']
    return []


def archive_files(folder):
    """보관 폴더의 파일을 읽는다. 정해진 이름 밖의 파일은 맥 점파일을 포함해 모두 거부하고, 링크도 거부한다."""
    if folder.is_symlink():
        raise ValueError('symlink_archive_directory')
    found = {ARCHIVE_DIRECTORY + path.name: path for path in (folder.iterdir() if folder.is_dir() else ())}
    unexpected = sorted(set(found) - set(ARCHIVES))
    if unexpected:
        raise ValueError('unexpected_archive_file: ' + ', '.join(unexpected))
    result = {}
    for name in ARCHIVES:
        path = found.get(name)
        if path is None or path.is_symlink() or not path.is_file():
            raise ValueError('archive_missing_or_not_regular: ' + name)
        result[name] = path.read_bytes()
    return result


def routes():
    result = {'/legal/'+name+'.html': name for name in PAGES}
    for alias, name in ALIASES.items():
        for prefix in ('/', '/legal/'):
            for suffix in ('', '/'):
                result[prefix+alias+suffix] = name
    return result


def fetch(origin, route, name, source_hash):
    result = {'url': origin+route, 'expected_source_sha256': source_hash}
    try:
        # Use curl's configured trust store, with TLS verification and redirects disabled.
        # Each request has no auth, cookie jar or user curl configuration.
        with tempfile.TemporaryDirectory(prefix='map-policy-probe-') as temp:
            body_path, header_path = Path(temp)/'body', Path(temp)/'headers'
            response = subprocess.run(['curl', '-q', '--silent', '--show-error',
                '--proto', '=https', '--max-time', '20', '--max-filesize', '300000',
                '--header', 'Accept: text/html', '--header', 'Cache-Control: no-cache',
                '--dump-header', str(header_path), '--output', str(body_path),
                '--write-out', '%{http_code}\n%{content_type}', origin+route],
                capture_output=True, text=True, timeout=25)
            if response.returncode:
                result.update(status='FAIL', errors=['curl_transport'], curl_exit=response.returncode)
                return result
            status, content_type = response.stdout.split('\n', 1)
            headers = dict(line.split(': ', 1) for line in header_path.read_text().splitlines() if ': ' in line)
            body = body_path.read_bytes()
            result.update(http_status=int(status), content_type=content_type,
                          cache_control=next((v for k,v in headers.items() if k.lower()=='cache-control'), ''),
                          bytes=len(body), sha256=hashlib.sha256(body).hexdigest())
        errors = validate_body(body, name)
        if result['http_status'] != 200 or 'text/html' not in result['content_type']:
            errors.append('status_or_content_type')
        if result['sha256'] != source_hash:
            errors.append('source_hash_mismatch')
        result.update(status='FAIL' if errors else 'PASS', errors=errors)
    except (OSError, UnicodeError, ValueError, subprocess.TimeoutExpired) as error:
        result.update(status='FAIL', errors=[type(error).__name__])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--firebase', type=Path, required=True)
    parser.add_argument('--origin')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    checks, hashes = [], {}
    try:
        for name in PAGES:
            path = args.directory/'legal'/(name+'.html')
            if path.is_symlink():
                raise ValueError('symlink_policy')
            body = path.read_bytes()
            errors = validate_body(body, name)
            hashes[name] = hashlib.sha256(body).hexdigest()
            checks.append({'source': 'legal/'+name+'.html', 'sha256': hashes[name],
                           'status': 'FAIL' if errors else 'PASS', 'errors': errors})
        archives = {}
        for path, body in archive_files(args.directory / ARCHIVE_DIRECTORY).items():
            errors = validate_archive(body, path)
            archives[path] = hashlib.sha256(body).hexdigest()
            checks.append({'source': path, 'sha256': archives[path],
                           'status': 'FAIL' if errors else 'PASS', 'errors': errors})
        config = json.loads(args.firebase.read_text())['hosting']
        for route, name in routes().items():
            if route == '/legal/'+name+'.html':
                continue
            matching = next((r for r in config['rewrites'] if r.get('source') in (route, '**')), {})
            checks.append({'route': route, 'status': 'PASS' if matching.get('destination') == '/legal/'+name+'.html' else 'FAIL'})
        if args.origin:
            if not re.fullmatch(r'https://[a-z0-9.-]+', args.origin):
                raise ValueError('HTTPS origin required')
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                pending = [pool.submit(fetch, args.origin, route, name, hashes[name]) for route, name in routes().items()]
                pending += [pool.submit(fetch, args.origin, '/' + path, ARCHIVES[path][0], digest)
                            for path, digest in archives.items()]
                checks.extend(f.result() for f in pending)
    except (OSError, ValueError, KeyError) as error:
        checks.append({'status': 'FAIL', 'error': type(error).__name__})
    result = {'observed_utc': datetime.now(timezone.utc).isoformat(), 'scope': 'anonymous_https' if args.origin else 'local_source',
              'status': 'PASS' if checks and all(c['status'] == 'PASS' for c in checks) else 'FAIL', 'checks': checks}
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'status': result['status'], 'scope': result['scope'], 'checks':len(checks),
                      'failed':sum(c['status']=='FAIL' for c in checks)}))
    return result['status'] != 'PASS'

if __name__ == '__main__':
    sys.exit(main())
