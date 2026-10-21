import importlib.util
import json
from pathlib import Path
import shutil
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

    def archives(self, policy):
        """보관본은 원본 해시가 고정돼 있어 합성할 수 없다. 저장소의 실제 보관본을 정책 폴더 아래 archive 로 옮겨 둔다."""
        shutil.copytree(ROOT / 'hosting' / public.content.ARCHIVE_DIRECTORY, policy / 'archive')
        return policy / 'archive'

    def draft(self, directory):
        """초안 표식을 단 합성 본문. 배포 가능한 법적 문서가 아니다."""
        pages, _ = self.reviewed(directory)
        for name in public.content.PAGES:
            path = directory / (name + '.html')
            marker = '<p>운영 준비 초안</p></main>'.encode()
            body = path.read_bytes().replace(b'</main>', marker)
            path.write_bytes(body)
            pages[name] = body
        return pages

    def test_policy_draft_is_marked_and_cannot_be_released(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            policy = root / 'policies'; policy.mkdir()
            self.draft(policy)
            self.archives(policy)
            result = public.prepare(root / 'draft', policy, [CERT], None, None)
            self.assertEqual(result['status'], 'DRAFT_NOT_SUBMITTABLE')
            self.assertIn('apple_app_id_prefix_missing', result['blockers'])
            self.assertIn('policy_draft:privacy', result['blockers'])
            self.assertFalse((root / 'draft/public/.well-known/apple-app-site-association').exists())
            for name in public.content.PAGES:
                self.assertIn('운영 준비 초안', (root / 'draft/public/legal' / (name + '.html')).read_text())
            for name in public.content.ARCHIVES:
                self.assertIn('운영 준비 초안', (root / 'draft/public' / name).read_text())
            with self.assertRaises(ValueError):
                public.prepare(root / 'release', policy, [CERT], PREFIX, None, release=True)
            self.assertFalse((root / 'release').exists())

    def test_actual_policy_pages_carry_no_draft_marker_but_still_need_a_review_input(self):
        """저장소의 정책본은 게시본 그대로다.

        초안 표식이 없다는 것과 배포해도 된다는 것은 다르다. 검토 입력이 없으면
        어떤 경우에도 배포 가능 상태가 되지 않는다.
        """
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result = public.prepare(root / 'actual', ROOT / 'hosting/legal', [CERT], PREFIX, None)
            self.assertEqual(result['status'], 'DRAFT_NOT_SUBMITTABLE')
            self.assertNotIn('policy_draft:privacy', result['blockers'])
            self.assertIn('policy_review_missing', result['blockers'])

    def test_release_hashes_links_and_private_metadata_stay_separate(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            policy = root / 'policies'; policy.mkdir()
            pages, review = self.reviewed(policy)
            archive = self.archives(policy)
            with patch.object(public.subprocess, 'check_output', side_effect=['a' * 40, 'master', '']):
                result = public.prepare(root / 'bundle', policy, [CERT], PREFIX, review, release=True)
            self.assertEqual(result['status'], 'READY_FOR_PUBLICATION')
            self.assertEqual(result['blockers'], [])
            directory = root / 'bundle/public'
            self.assertFalse((directory / 'manifest.json').exists())
            for name, digest in result['files'].items():
                self.assertEqual(public.digest((directory / name).read_bytes()), digest)
            # 배포본의 보관본은 저장소 바이트 그대로다(초안 표식 없음).
            for name in public.content.ARCHIVES:
                self.assertEqual((directory / name).read_bytes(), (archive / Path(name).name).read_bytes())
            # 보관본 한 바이트만 바뀌어도 배포 불가가 된다.
            target = archive / 'terms-2026-09-15.html'
            target.write_bytes(target.read_bytes().replace('제1조'.encode(), '제1 조'.encode(), 1))
            with patch.object(public.subprocess, 'check_output', side_effect=['a' * 40, 'master', '']):
                with self.assertRaises(ValueError) as raised:
                    public.prepare(root / 'changed', policy, [CERT], PREFIX, review, release=True)
            self.assertIn('archive_legal/archive/terms-2026-09-15.html:archive_bytes_changed', str(raised.exception))
            self.assertFalse((root / 'changed').exists())
            config = json.loads((directory / 'app_config.json').read_text())
            self.assertEqual(config, {'environment': 'prod', 'api_base_url': 'https://api.mapservice.app'})
            aasa = json.loads((directory / '.well-known/apple-app-site-association').read_text())
            self.assertEqual(aasa['applinks']['details'][0]['appID'], PREFIX + '.kr.mapservice.client')
            with self.assertRaises(ValueError):
                public.prepare(root / 'bundle', policy, [CERT], PREFIX, review, release=True)
            pages['privacy'] += b'<p>changed after review</p>'
            self.assertIn('reviewed_policy_hash_mismatch', public.policy_blockers(pages, review))

    def test_landing_page_and_its_assets_are_published_and_manifested(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            policy = root / 'policies'; policy.mkdir()
            pages, _ = self.reviewed(policy)
            self.archives(policy)
            landing = root / 'landing'; (landing / 'assets').mkdir(parents=True)
            (landing / 'index.html').write_text('<main><h1>MAP</h1></main>')
            (landing / 'assets/shot.webp').write_bytes(b'webp bytes')
            (landing / 'assets/.DS_Store').write_bytes(b'noise')
            with patch.object(public, 'LANDING', landing):
                result = public.prepare(root / 'bundle', policy, [CERT], PREFIX, None)
                directory = root / 'bundle/public'
                self.assertIn('assets/shot.webp', result['files'])
                self.assertNotIn('assets/.DS_Store', result['files'])
                self.assertEqual((directory / 'assets/shot.webp').read_bytes(), b'webp bytes')
                # 초안 표시는 산출물에만 붙고 원본은 그대로여야 한다.
                self.assertIn('운영 준비 초안', (directory / 'index.html').read_text())
                self.assertNotIn('운영 준비 초안', (landing / 'index.html').read_text())
                (landing / 'assets/notes.txt').write_bytes(b'not publishable')
                with self.assertRaises(ValueError):
                    public.prepare(root / 'other', policy, [CERT], PREFIX, None)

    def test_placeholder_address_and_unreviewed_text_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            pages, review = self.reviewed(Path(temporary))
            self.assertEqual(public.policy_blockers(pages, review), [])
            for value in ('미정 주소입니다', 'YOUR_ADDRESS', ''):
                with self.subTest(value=value):
                    self.assertIn('public_contact_address_missing', public.policy_blockers(
                        pages, {**review, 'public_contact_address': value}))
            self.assertIn('policy_review_missing', public.policy_blockers(pages, None))

    def test_archive_folder_must_hold_exactly_the_pinned_archives(self):
        """보관본이 빠지거나, 링크이거나, 정해지지 않은 파일(맥 점파일 포함)이 섞이면 묶음을 만들지 않는다.

        안내가 없거나 두 번 들어가면 초안에서도 막힘 사유로 남는다.
        """
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            policy = root / 'policies'; policy.mkdir()
            self.reviewed(policy)
            with self.assertRaises(ValueError):
                public.prepare(root / 'none', policy, [CERT], PREFIX, None)
            archive = self.archives(policy)
            self.assertIn('legal/archive/privacy-2026-10-15.html',
                          public.prepare(root / 'ok', policy, [CERT], PREFIX, None)['files'])
            (archive / '.DS_Store').write_bytes(b'noise')
            with self.assertRaises(ValueError):
                public.prepare(root / 'dotfile', policy, [CERT], PREFIX, None)
            (archive / '.DS_Store').unlink()
            (archive / 'privacy-2026-10-01.html').write_bytes(b'not pinned')
            with self.assertRaises(ValueError):
                public.prepare(root / 'extra', policy, [CERT], PREFIX, None)
            (archive / 'privacy-2026-10-01.html').unlink()
            target = archive / 'location-terms-2026-09-15.html'
            original = target.read_bytes()
            target.unlink(); target.symlink_to(root / 'policies/location-terms.html')
            with self.assertRaises(ValueError):
                public.prepare(root / 'linked', policy, [CERT], PREFIX, None)
            target.unlink()
            notice = public.content.archive_notice('legal/archive/location-terms-2026-09-15.html')
            target.write_bytes(original.replace(notice, b'<main>', 1))
            result = public.prepare(root / 'bare', policy, [CERT], PREFIX, None)
            self.assertIn('archive_legal/archive/location-terms-2026-09-15.html:archive_notice_missing',
                          result['blockers'])
            target.write_bytes(original.replace(notice, notice + b'\n' + notice, 1))
            result = public.prepare(root / 'twice', policy, [CERT], PREFIX, None)
            self.assertIn('archive_legal/archive/location-terms-2026-09-15.html:archive_notice_duplicated',
                          result['blockers'])
