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
