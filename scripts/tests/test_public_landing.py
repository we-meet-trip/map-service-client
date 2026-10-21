import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('public_landing', ROOT / 'scripts/verify-public-landing.py')
landing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(landing)
ARCHIVE = 'legal/archive/privacy-2026-09-15.html'


class BaselineTest(unittest.TestCase):
    """공개 중 묶음과 새 묶음의 차이 판정. 컨테이너 없이 파일만 본다."""

    def bundle(self, root):
        public = root / 'public'
        for name in landing.MOBILE_FACING | {'index.html'}:
            (public / name).parent.mkdir(parents=True, exist_ok=True)
            (public / name).write_bytes(b'live ' + name.encode())
        for name in landing.content.PAGES:
            (public / 'legal').mkdir(exist_ok=True)
            (public / 'legal' / (name + '.html')).write_bytes(b'<main>' + name.encode())
        live = {str(p.relative_to(public)): landing.digest(p.read_bytes()) for p in public.rglob('*') if p.is_file()}
        baseline = root / 'live.json'
        baseline.write_text(json.dumps({'files': live}))
        (public / 'index.html').write_bytes(b'<main id="' + landing.NOTICE_ID.encode() + b'">')
        return public, baseline

    def judge(self, public, baseline):
        actual = {str(p.relative_to(public)): landing.digest(p.read_bytes()) for p in public.rglob('*') if p.is_file()}
        failures = []
        landing.check_baseline(actual, public, baseline, failures)
        return failures

    def test_only_pinned_archives_may_appear_and_they_must_match_the_original(self):
        with tempfile.TemporaryDirectory() as temporary:
            public, baseline = self.bundle(Path(temporary))
            shutil.copytree(ROOT / 'hosting/legal/archive', public / 'legal/archive')
            self.assertEqual(self.judge(public, baseline), [])
            # 초안 묶음은 보관본에도 초안 표식이 붙는다. 표식을 걷어 내고 판정한다.
            body = (public / ARCHIVE).read_bytes()
            draft = body.replace(b'<main>', landing.DRAFT_NOTICE, 1)
            (public / ARCHIVE).write_bytes(draft)
            self.assertEqual(self.judge(public, baseline), [])
            (public / ARCHIVE).write_bytes(draft.replace(b'</main>', b'<p>x</p></main>'))
            self.assertEqual(self.judge(public, baseline), ['archive_bytes_changed: ' + ARCHIVE])
            notice = landing.content.archive_notice(ARCHIVE)
            (public / ARCHIVE).write_bytes(body.replace(notice, notice + b'\n' + notice, 1))
            self.assertEqual(self.judge(public, baseline), ['archive_notice_duplicated: ' + ARCHIVE])
            (public / ARCHIVE).unlink()
            self.assertEqual(self.judge(public, baseline), ['archive missing: ' + ARCHIVE])
            (public / ARCHIVE).write_bytes(body)
            (public / 'legal/archive/privacy-2026-10-01.html').write_bytes(b'unpinned')
            self.assertEqual(self.judge(public, baseline),
                             ['unexpected new files: legal/archive/privacy-2026-10-01.html'])

if __name__ == '__main__':
    unittest.main()
