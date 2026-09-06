import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('web_secrets', ROOT / 'scripts/web-secrets.py')
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class WebReleaseTest(unittest.TestCase):
    def test_only_approved_browser_key_is_allowed_and_server_values_still_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            key = 'AIza' + 'a' * 35
            asset = root / 'main.dart.js'
            asset.write_text(key)
            self.assertEqual(scanner.scan([root], {}, {key.encode()}), (1, []))
            self.assertIn('unapproved_google_key', scanner.scan([root], {}, set())[1])
            self.assertIn('server_credential', scanner.scan(
                [root], {'GOOGLE_API_KEY': key}, {key.encode()})[1])

    def test_dotenv_duplicates_links_and_empty_directory_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertIn('no_assets_checked', scanner.scan([root], {}, set())[1])
            (root / '.env').write_text('ordinary=value')
            (root / 'main.dart 2.js').write_text('stale')
            (root / 'linked').symlink_to(root / '.env')
            self.assertEqual(scanner.scan([root], {}, set())[1], [
                'dotenv_asset', 'stale_duplicate_asset', 'symlink_in_assets'])

    def test_encoded_secret_and_private_key_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            secret = 'synthetic/credential+value'
            asset = root / 'payload.wasm'
            asset.write_text(scanner.quote(secret, safe=''))
            self.assertIn('server_credential', scanner.scan(
                [root], {'SOME_TOKEN': secret}, set())[1])
            asset.write_text('-----BEGIN PRIVATE KEY-----')
            self.assertIn('server_credential', scanner.scan([root], {}, set())[1])

    def test_stream_boundaries_and_overridden_secrets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            key = 'AIza' + 'b' * 35
            asset = root / 'large.js'
            # A partial but regex-valid key at a chunk end must not fail early.
            asset.write_bytes(b' ' * (1024 * 1024 - 35) + key.encode() + b';')
            self.assertEqual(scanner.scan([root], {}, {key.encode()}), (1, []))
            self.assertIn('unapproved_google_key', scanner.scan([root], {}, set())[1])
            asset.write_text('synthetic-old-secret')
            self.assertIn('server_credential', scanner.scan([root], [
                ('SERVER_TOKEN', 'synthetic-old-secret'),
                ('SERVER_TOKEN', 'synthetic-new-secret')], set())[1])

    def test_actual_build_helper_preserves_environment_assets_and_rejects_prod_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'client'
            for name in ['tool', 'scripts', 'lib', 'web', 'hosting/legal',
                         'hosting/invite', 'hosting/.well-known', 'bin']:
                (root / name).mkdir(parents=True, exist_ok=True)
            for name in ['tool/build_web.sh', 'scripts/web-secrets.py',
                         'scripts/mobile-release-config.py']:
                shutil.copy2(ROOT / name, root / name)
            for name in ['lib/main.dart', 'web/index.html']:
                (root / name).write_text('source')
            (root / 'pubspec.yaml').write_text('version: 1.2.3+1\n')
            private = root / '.env'
            private.write_text('SERVER_TOKEN=synthetic-private-preserved\n')
            preserved = ['app_config.json', 'legal/privacy.html', 'invite/index.html',
                         '.well-known/assetlinks.json']
            for name in preserved:
                (root / 'hosting' / name).write_text('preserved')
            (root / 'hosting/old.js').write_text('stale build')
            fake_flutter = root / 'bin/flutter'
            fake_flutter.write_text('''#!/usr/bin/env python3
import json,pathlib,sys
args=sys.argv
output=pathlib.Path(args[args.index('--output')+1])
defines=json.loads(pathlib.Path(args[args.index('--dart-define-from-file')+1]).read_text())
assert set(defines)=={'APP_ENV','API_ALLOWED_ORIGINS','APP_CONFIG_URL','GOOGLE_MAPS_WEB_API_KEY'}
output.mkdir(parents=True)
(output/'index.html').write_text('new build')
''')
            fake_flutter.chmod(0o755)
            fake_git = root / 'bin/git'
            fake_git.write_text('#!/bin/sh\nprintf "24\\n"\n')
            fake_git.chmod(0o755)
            env = {'PATH': str(root / 'bin') + os.pathsep + os.environ['PATH'],
                   'APP_ENV': 'test', 'GOOGLE_MAPS_WEB_API_KEY': 'restricted-browser-key',
                   'TMPDIR': temporary}
            result = subprocess.run(['bash', str(root / 'tool/build_web.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(private.read_text(), 'SERVER_TOKEN=synthetic-private-preserved\n')
            self.assertFalse((root / 'hosting/old.js').exists())
            for name in preserved:
                self.assertEqual((root / 'hosting' / name).read_text(), 'preserved')
            self.assertEqual((root / 'hosting/index.html').read_text(), 'new build')
            env['APP_ENV'] = 'prod'
            result = subprocess.run(['bash', str(root / 'tool/build_web.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('must not overwrite', result.stderr)


if __name__ == '__main__':
    unittest.main()
