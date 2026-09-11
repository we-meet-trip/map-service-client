import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('ncp_public', ROOT / 'scripts/prepare-ncp-public.py')
public = importlib.util.module_from_spec(spec)
spec.loader.exec_module(public)
CERT = '0123456789abcdef' * 4
PREFIX = 'A1B2C3D4E5'  # Synthetic fixture only, never a real signing claim.


class NcpPublicTest(unittest.TestCase):
    def reviewed(self, directory):
        pages = {}
        address = '테스트 전용 공개 연락주소 123'
        navigation = ''.join(f'<a href="/legal/{name}.html">정책</a>' for name in public.content.PAGES)
        for name, title in public.content.PAGES.items():
            # Synthetic reviewed text, not a deployable legal document.
            body = ('<html><main><h1>' + title + '</h1><p>' + address + '</p>'
                    '<p>mapadmin26@gmail.com 본인 확인 다른 참여자 백업 접수 처리</p>'
                    '<p>' + '문서 확인을 위한 예제 설명입니다. ' * 40 + '</p>'
                    + navigation + '</main></html>').encode()
            (directory / (name + '.html')).write_bytes(body)
            pages[name] = body
        review = {'status': 'REVIEWED_FOR_PRODUCTION', 'public_contact_address': address,
                  'files': {'legal/' + name + '.html': public.digest(body) for name, body in pages.items()}}
        return pages, review

    def test_actual_policy_draft_is_marked_and_cannot_be_released(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result = public.prepare(root / 'draft', ROOT / 'hosting/legal', [CERT], None, None)
            self.assertEqual(result['status'], 'DRAFT_NOT_SUBMITTABLE')
            self.assertIn('apple_app_id_prefix_missing', result['blockers'])
            self.assertIn('policy_draft:privacy', result['blockers'])
            self.assertFalse((root / 'draft/public/.well-known/apple-app-site-association').exists())
            for name in public.content.PAGES:
                self.assertIn('운영 준비 초안', (root / 'draft/public/legal' / (name + '.html')).read_text())
            with self.assertRaises(ValueError):
                public.prepare(root / 'release', ROOT / 'hosting/legal', [CERT], PREFIX, None, release=True)
            self.assertFalse((root / 'release').exists())

    def test_release_hashes_links_and_private_metadata_stay_separate(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            policy = root / 'policies'; policy.mkdir()
            pages, review = self.reviewed(policy)
            with patch.object(public.subprocess, 'check_output', side_effect=['a' * 40, 'master', '']):
                result = public.prepare(root / 'bundle', policy, [CERT], PREFIX, review, release=True)
            self.assertEqual(result['status'], 'READY_FOR_PUBLICATION')
            self.assertEqual(result['blockers'], [])
            directory = root / 'bundle/public'
            self.assertFalse((directory / 'manifest.json').exists())
            for name, digest in result['files'].items():
                self.assertEqual(public.digest((directory / name).read_bytes()), digest)
            config = json.loads((directory / 'app_config.json').read_text())
            self.assertEqual(config, {'environment': 'prod', 'api_base_url': 'https://api.mapservice.app'})
            aasa = json.loads((directory / '.well-known/apple-app-site-association').read_text())
            self.assertEqual(aasa['applinks']['details'][0]['appID'], PREFIX + '.kr.mapservice.client')
            with self.assertRaises(ValueError):
                public.prepare(root / 'bundle', policy, [CERT], PREFIX, review, release=True)
            pages['privacy'] += b'<p>changed after review</p>'
            self.assertIn('reviewed_policy_hash_mismatch', public.policy_blockers(pages, review))

    def test_placeholder_address_and_unreviewed_text_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            pages, review = self.reviewed(Path(temporary))
            self.assertEqual(public.policy_blockers(pages, review), [])
            for value in ('미정 주소입니다', 'YOUR_ADDRESS', ''):
                with self.subTest(value=value):
                    self.assertIn('public_contact_address_missing', public.policy_blockers(
                        pages, {**review, 'public_contact_address': value}))
            self.assertIn('policy_review_missing', public.policy_blockers(pages, None))
