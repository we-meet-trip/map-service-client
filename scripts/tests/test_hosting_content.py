import importlib.util
import json
from pathlib import Path
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

if __name__ == '__main__':
    unittest.main()
