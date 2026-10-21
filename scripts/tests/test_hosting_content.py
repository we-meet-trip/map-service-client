import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('content', ROOT/'scripts/hosting-content-check.py')
content = importlib.util.module_from_spec(spec)
spec.loader.exec_module(content)

class HostingContentTest(unittest.TestCase):
    def test_fallback_and_placeholders_cannot_pass_with_only_a_title(self):
        real = (ROOT/'hosting/legal/support.html').read_bytes()
        self.assertEqual(content.validate_body(real, 'support'), [])
        self.assertIn('spa_fallback', content.validate_body(real+b'<script src="flutter_bootstrap.js"></script>', 'support'))
        self.assertIn('placeholder', content.validate_body(real+b' TODO ', 'support'))
        self.assertIn('missing_policy_body', content.validate_body(b'<title>MAP</title>', 'support'))
    def test_alias_before_fallback_and_absolute_links_required(self):
        real = (ROOT/'hosting/legal/support.html').read_bytes()
        self.assertIn('missing_absolute_policy_navigation', content.validate_body(real.replace(b'/legal/privacy.html', b'privacy.html'), 'support'))
        with tempfile.TemporaryDirectory() as temp:
            config = json.loads((ROOT/'firebase.json').read_text())
            config['hosting']['rewrites'].insert(0, {'source': '**', 'destination': '/index.html'})
            target=Path(temp)/'firebase.json';target.write_text(json.dumps(config))
            result=subprocess.run(['python3',str(ROOT/'scripts/hosting-content-check.py'),'--directory',str(ROOT/'hosting'),'--firebase',str(target)],capture_output=True)
            self.assertEqual(result.returncode,1)
    def test_archive_is_the_pinned_original_plus_one_notice(self):
        for path in content.ARCHIVES:
            body = (ROOT/'hosting'/path).read_bytes()
            self.assertEqual(content.validate_archive(body, path), [])
            self.assertIn(b'/legal/' + content.ARCHIVES[path][0].encode() + b'.html', content.archive_notice(path))
        path = 'legal/archive/privacy-2026-09-15.html'
        body = (ROOT/'hosting'/path).read_bytes()
        notice = content.archive_notice(path)
        self.assertEqual(content.validate_archive(body.replace(notice, b'<main>'), path), ['archive_notice_missing'])
        self.assertEqual(content.validate_archive(body.replace(notice, notice + b'\n' + notice), path), ['archive_notice_duplicated'])
        self.assertEqual(content.validate_archive(body.replace(notice, notice + b'\n' + notice[7:]), path), ['archive_bytes_changed'])
        self.assertEqual(content.validate_archive(body.replace(b'</main>', b'<p>x</p></main>'), path), ['archive_bytes_changed'])
    def test_predeploy_rejects_a_stray_or_missing_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            hosting = Path(temp)/'hosting'
            shutil.copytree(ROOT/'hosting', hosting)
            command = ['python3', str(ROOT/'scripts/hosting-content-check.py'), '--directory', str(hosting), '--firebase', str(ROOT/'firebase.json')]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            stray = hosting/'legal/archive/terms-2026-10-01.html'
            stray.write_bytes(b'unpinned')
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
            stray.unlink()
            (hosting/'legal/archive/.DS_Store').write_bytes(b'noise')
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
            (hosting/'legal/archive/.DS_Store').unlink()
            (hosting/'legal/archive/terms-2026-09-15.html').unlink()
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)

if __name__ == '__main__':
    unittest.main()
