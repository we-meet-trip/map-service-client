import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).parents[1] / 'mobile-release-config.py'
spec = importlib.util.spec_from_file_location('mobile_release_config', MODULE)
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class MobileReleaseConfigTest(unittest.TestCase):
    def production(self, **extra):
        return {
            'API_ALLOWED_ORIGINS': 'https://api.example.com',
            'APP_CONFIG_URL': 'https://config.example.com/prod.json',
            **extra,
        }

    def test_unsigned_test_compile_allows_missing_maps_keys(self):
        actual = config.make_config('test', 'ios', False, {})
        self.assertEqual(actual, {
            'APP_ENV': 'test',
            'API_ALLOWED_ORIGINS': config.TEST_API_ORIGIN,
            'APP_CONFIG_URL': config.TEST_CONFIG_URL,
        })

    def test_prod_never_falls_back_to_test(self):
        for values in [{}, {'API_ALLOWED_ORIGINS': 'https://api.example.com'},
                       self.production(API_ALLOWED_ORIGINS=config.TEST_API_ORIGIN),
                       self.production(APP_CONFIG_URL=config.TEST_CONFIG_URL)]:
            with self.subTest(values=values), self.assertRaises(config.ConfigError):
                config.make_config('prod', 'android', False, values)

    def test_signed_release_requires_only_the_current_platform_key(self):
        for platform in config.PLATFORM_KEYS:
            others = {key: 'other-client-key' for name, key in config.PLATFORM_KEYS.items()
                      if name != platform}
            with self.subTest(platform=platform), self.assertRaises(config.ConfigError):
                config.make_config('prod', platform, True, self.production(**others))
            values = self.production(**others, **{config.PLATFORM_KEYS[platform]: 'platform-client-key'})
            actual = config.make_config('prod', platform, True, values)
            self.assertEqual(set(actual), {
                'APP_ENV', 'API_ALLOWED_ORIGINS', 'APP_CONFIG_URL', config.PLATFORM_KEYS[platform],
            })

    def test_input_secrets_cannot_enter_dart_defines(self):
        values = {
            'APP_DOTENV_B64': 'secret-base64', 'KAKAO_REST_API_KEY': 'server-kakao',
            'GOOGLE_API_KEY': 'server-places', 'JWT_PRIVATE_KEY': 'server-private',
            'VISION_INTERNAL_TOKEN': 'server-vision', 'API_BASE_URL': 'https://untrusted.example',
        }
        result = json.dumps(config.make_config('test', 'android', False, values))
        for value in values.values():
            self.assertNotIn(value, result)

    def test_origins_are_https_and_origin_only(self):
        for invalid in ['http://api.example.com', 'https://api.example.com/path',
                        'https://name:password@api.example.com', 'https://api.example.com?x=1',
                        'https://api.example.com#x', 'https://api.example.com,',
                        'https://api.example.com\nEVIL=x', 'https://api.example.com:bad',
                        'https://api.example.com\\@other.example']:
            with self.subTest(invalid=invalid), self.assertRaises(config.ConfigError):
                config.make_config('prod', 'android', False,
                                   self.production(API_ALLOWED_ORIGINS=invalid))

    def test_config_url_preserves_an_explicit_https_path(self):
        actual = config.make_config('prod', 'ios', False, self.production())
        self.assertEqual(actual['APP_CONFIG_URL'], 'https://config.example.com/prod.json')
        for invalid in ['http://config.example.com/prod.json', 'https://user@config.example.com/x',
                        'https://config.example.com/x?secret=yes']:
            with self.assertRaises(config.ConfigError):
                config.make_config('prod', 'ios', False, self.production(APP_CONFIG_URL=invalid))

    def test_placeholder_or_control_character_key_is_rejected_without_value(self):
        for key in ['replace-client-key', 'your_google_key', 'key\nsecret', 'key;command']:
            with self.subTest(key=key), self.assertRaises(config.ConfigError) as raised:
                config.make_config('test', 'android', True, {'GOOGLE_MAPS_ANDROID_API_KEY': key})
            self.assertNotIn(key, str(raised.exception))

    def test_numeric_versions_and_build_numbers_are_validated(self):
        self.assertEqual(config.release_version('refs/tags/v2.3.4', 'version: 1.0.0+1', '12'), ('2.3.4', '12'))
        self.assertEqual(config.release_version('refs/tags/iosbuild-branch', 'version: 1.0.0+1', '12'), ('1.0.0', '12'))
        for tag in ['v1.2.3;touch-file', 'v$(id)', 'v1.2.3\nextra=value', 'v01.2.3', 'v1.2.3-beta']:
            with self.subTest(tag=tag), self.assertRaises(config.ConfigError):
                config.release_version('refs/tags/' + tag, 'version: 1.0.0+1', '1')
        for number in ['0', '-1', '1;id', '1\n2', '2100000001']:
            with self.subTest(number=number), self.assertRaises(config.ConfigError):
                config.release_version('', 'version: 1.0.0+1', number)

    def test_cli_generates_private_config_without_touching_local_env(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pubspec = root / 'pubspec.yaml'
            pubspec.write_text('version: 1.2.3+1\n')
            output = root / 'defines.json'
            asset = root / '.env'
            asset.write_text('SERVER_SECRET=do-not-package\n')
            github_output = root / 'github-output'
            stdout, stderr = io.StringIO(), io.StringIO()
            environment = {
                'GITHUB_REF': 'refs/heads/develop', 'GITHUB_OUTPUT': str(github_output),
                'GOOGLE_MAPS_ANDROID_API_KEY': 'android-restricted-key',
                'GOOGLE_MAPS_IOS_API_KEY': 'ios-must-not-ship',
                'APP_DOTENV_B64': 'server-secret-must-not-ship',
            }
            with patch.dict(os.environ, environment, clear=True), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status = config.main([
                    '--environment', 'test', '--platform', 'android', '--signed',
                    '--output', str(output),
                    '--pubspec', str(pubspec), '--build-number', '24',
                ])
            self.assertEqual(status, 0, stderr.getvalue())
            actual = json.loads(output.read_text())
            self.assertEqual(actual['GOOGLE_MAPS_ANDROID_API_KEY'], 'android-restricted-key')
            self.assertNotIn('GOOGLE_MAPS_IOS_API_KEY', actual)
            self.assertEqual(asset.read_text(), 'SERVER_SECRET=do-not-package\n')
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            self.assertEqual(github_output.read_text(), 'build_name=1.2.3\nbuild_number=24\n')
            self.assertNotIn('android-restricted-key', stdout.getvalue() + stderr.getvalue())

    def test_tag_cannot_request_test_and_failure_does_not_write_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            asset = root / '.env'
            asset.write_text('preserved-source')
            with patch.dict(os.environ, {'GITHUB_REF': 'refs/tags/v1.2.3'}, clear=True), contextlib.redirect_stderr(io.StringIO()):
                result = config.main(['--environment', 'test', '--platform', 'android',
                                      '--output', str(root / 'defines.json')])
            self.assertEqual(result, 1)
            self.assertEqual(asset.read_text(), 'preserved-source')
            self.assertFalse((root / 'defines.json').exists())


if __name__ == '__main__':
    unittest.main()
