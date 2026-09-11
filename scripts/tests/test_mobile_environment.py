import base64
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


config = module('config', 'scripts/mobile-release-config.py')
links = module('links', 'scripts/mobile-link-associations.py')
ios = module('ios', 'ios/Flutter/verify_native_environment.py')


class MobileEnvironmentTest(unittest.TestCase):
    def production(self):
        return {'API_ALLOWED_ORIGINS': 'https://api.mapservice.app',
                'APP_CONFIG_URL': 'https://mapservice.app/app_config.json',
                'INVITE_LINK_ORIGIN': 'https://mapservice.app',
                'PUBLIC_SITE_ORIGIN': 'https://mapservice.app'}

    def test_native_identity_is_distinct_and_cannot_be_overridden(self):
        for environment in ('test', 'prod'):
            values = self.production() if environment == 'prod' else {}
            values.update({key: 'other-environment' for key in config.native_identity(environment)})
            actual = config.make_config(environment, 'ios', False, values)
            for key, value in config.native_identity(environment).items():
                self.assertEqual(actual[key], value)
        for key in config.native_identity('test'):
            self.assertNotEqual(config.native_identity('test')[key], config.native_identity('prod')[key])

    def test_xcode_gate_rejects_stale_native_config_for_every_identity_field(self):
        values = config.make_config('prod', 'ios', False, self.production())
        native = dict(line.split(' = ', 1) for line in config.ios_xcconfig(values).splitlines()
                      if ' = ' in line)
        native['PRODUCT_BUNDLE_IDENTIFIER'] = values['NATIVE_APPLICATION_ID']
        native['DART_DEFINES'] = ','.join(base64.b64encode(f'{k}={v}'.encode()).decode()
                                         for k, v in values.items())
        ios.verify(native)
        for key in ['MAP_APP_ENV', 'MAP_APPLICATION_ID', 'PRODUCT_BUNDLE_IDENTIFIER',
                    'MAP_INVITE_SCHEME', 'MAP_KAKAO_SCHEME', 'MAP_INVITE_HOST']:
            with self.subTest(key=key), self.assertRaises(ValueError):
                ios.verify({**native, key: 'stale-test-value'})
        with self.assertRaises(ValueError):
            ios.verify({**native, 'DART_DEFINES': 'malformed'})

    def test_generated_associations_contain_only_the_selected_app(self):
        for environment in ('test', 'prod'):
            values = config.make_config(environment, 'ios', False,
                                        self.production() if environment == 'prod' else {})
            # Synthetic certificate/prefix for isolated fixture only.
            artifacts = links.make_associations(values, ['0123456789abcdef' * 4], 'A1B2C3D4E5')
            identity = config.native_identity(environment)
            target = artifacts['.well-known/assetlinks.json'][0]['target']
            self.assertEqual(target['package_name'], identity['NATIVE_APPLICATION_ID'])
            aasa = artifacts['.well-known/apple-app-site-association']['applinks']['details']
            self.assertEqual(aasa, [{'appID': 'A1B2C3D4E5.' + identity['NATIVE_APPLICATION_ID'],
                                    'paths': ['/invite/*']}])
            self.assertEqual(artifacts['invite-environment.json']['invite_scheme'], identity['INVITE_URL_SCHEME'])
            self.assertNotIn('GOOGLE_MAPS', json.dumps(artifacts))

    def test_missing_prefix_certificate_and_wrong_environment_are_rejected(self):
        values = config.make_config('test', 'ios', False, {})
        for certificates, prefix in [([], 'A1B2C3D4E5'), (['00' * 32], 'A1B2C3D4E5'),
                                     (['0123456789abcdef' * 4], ''),
                                     (['bad'], 'A1B2C3D4E5')]:
            with self.subTest(prefix=prefix), self.assertRaises(ValueError):
                links.make_associations(values, certificates, prefix)
        with self.assertRaises(ValueError):
            links.make_associations({**values, 'NATIVE_APPLICATION_ID': 'kr.mapservice.client'},
                                    ['0123456789abcdef' * 4], 'A1B2C3D4E5')

    def test_cli_cannot_overwrite_another_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'output'
            output.mkdir()
            existing = output / 'invite-environment.json'
            original = json.dumps({'app_environment': 'prod'})
            existing.write_text(original)
            source = root / 'config.json'
            source.write_text(json.dumps(config.make_config('test', 'ios', False, {})))
            result = subprocess.run(['python3', str(ROOT / 'scripts/mobile-link-associations.py'),
                                     '--config', str(source), '--output-dir', str(output),
                                     '--android-cert-sha256', '0123456789abcdef' * 4,
                                     '--apple-app-id-prefix', 'A1B2C3D4E5'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(existing.read_text(), original)
            self.assertFalse((output / '.well-known/assetlinks.json').exists())

    def test_native_sources_consume_generated_identity(self):
        manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text()
        self.assertIn('android:scheme="${inviteScheme}"', manifest)
        self.assertIn('android:scheme="${kakaoScheme}"', manifest)
        info = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())
        self.assertEqual([entry['CFBundleURLSchemes'][0] for entry in info['CFBundleURLTypes']],
                         ['$(MAP_KAKAO_SCHEME)', '$(MAP_INVITE_SCHEME)'])
        entitlements = plistlib.loads((ROOT / 'ios/Runner/Runner.entitlements').read_bytes())
        self.assertEqual(entitlements['com.apple.developer.associated-domains'],
                         ['applinks:$(MAP_INVITE_HOST)'])
        self.assertIn('verify_native_environment.py', (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text())


if __name__ == '__main__':
    unittest.main()
