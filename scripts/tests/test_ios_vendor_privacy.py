"""Small synthetic manifests only; no CocoaPods, Flutter or native build calls."""
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('ios_vendor_privacy', ROOT / 'scripts/ios_vendor_privacy.py')
privacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(privacy)


class IosVendorPrivacyTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.pods, self.app = self.root / 'Pods', self.root / 'Runner.app'
        self.pods.mkdir()
        self.app.mkdir()
        self.lock = self.root / 'Podfile.lock'
        self.lock_text = ('PODS:\n  - Flutter (1.0.0)\n  - Google-Maps-iOS-Utils (6.1.0):\n'
                          '    - GoogleMaps (~> 9.0)\n  - GoogleMaps (9.4.0):\n'
                          '    - GoogleMaps/Maps (= 9.4.0)\n  - GoogleMaps/Maps (9.4.0)\n'
                          '\nDEPENDENCIES:\n  - GoogleMaps (= 9.4.0)\n')
        self.lock.write_text(self.lock_text)
        (self.pods / 'Manifest.lock').write_text(self.lock_text)
        self.source = self.pods / 'GoogleMaps/Maps/Resources/GoogleMapsResources/GoogleMaps.bundle/PrivacyInfo.xcprivacy'
        self.bundled = self.app / 'GoogleMapsResources.bundle/GoogleMaps.bundle/PrivacyInfo.xcprivacy'
        self.source.parent.mkdir(parents=True)
        self.bundled.parent.mkdir(parents=True)
        # Deliberately synthetic; the production reference digest is never accepted for this fixture.
        self.value = {'NSPrivacyCollectedDataTypes': [], 'fixture': 'synthetic'}
        self.raw = plistlib.dumps(self.value)
        self.source.write_bytes(self.raw)
        self.bundled.write_bytes(plistlib.dumps(self.value, fmt=plistlib.FMT_BINARY))
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({'MinimumOSVersion': '15.0'}))
        canonical = json.dumps(self.value, sort_keys=True, separators=(',', ':')).encode()
        for name, value in [('VENDOR_SOURCE_SHA256', privacy.sha256(self.raw)),
                            ('VENDOR_DECLARATIONS_SHA256', privacy.sha256(canonical))]:
            context = patch.object(privacy, name, value)
            context.start()
            self.addCleanup(context.stop)

    def inspect(self):
        return privacy.inspect_vendor_privacy(self.lock, self.pods, self.app)

    def test_binary_app_manifest_preserves_genuine_declarations(self):
        result = self.inspect()
        self.assertEqual(result['status'], 'PASS')
        self.assertNotEqual(result['installed_vendor_manifest']['sha256'],
                            result['bundled_vendor_manifest']['sha256'])
        self.assertEqual(result['installed_vendor_manifest']['declarations_sha256'],
                         result['bundled_vendor_manifest']['declarations_sha256'])

    def test_flutter_plugin_manifest_cannot_replace_google_vendor_manifest(self):
        self.bundled.unlink()
        plugin = self.app / 'google_maps_flutter_ios_privacy.bundle/PrivacyInfo.xcprivacy'
        plugin.parent.mkdir()
        plugin.write_bytes(self.raw)
        with self.assertRaisesRegex(ValueError, 'lacks its own'):
            self.inspect()

    def test_modified_vendor_bytes_and_changed_app_declarations_fail(self):
        self.source.write_bytes(self.raw + b'\n')
        with self.assertRaisesRegex(ValueError, 'source bytes'):
            self.inspect()
        self.source.write_bytes(self.raw)
        self.bundled.write_bytes(plistlib.dumps({'NSPrivacyTracking': False}))
        with self.assertRaisesRegex(ValueError, 'declarations differ'):
            self.inspect()

    def test_current_missing_manifest_sdk_and_unreviewed_new_major_fail(self):
        for old, new in [('9.4.0', '8.4.0'), ('9.4.0', '10.0.0'), ('6.1.0', '6.1.3')]:
            self.lock.write_text(self.lock_text.replace(old, new))
            with self.subTest(new=new), self.assertRaisesRegex(ValueError, 'Resolved'):
                self.inspect()

    def test_installed_lock_and_minimum_os_must_match(self):
        (self.pods / 'Manifest.lock').write_text(self.lock_text + '\n')
        with self.assertRaisesRegex(ValueError, 'installed manifest'):
            self.inspect()
        (self.pods / 'Manifest.lock').write_text(self.lock_text)
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({'MinimumOSVersion': '14.0'}))
        with self.assertRaisesRegex(ValueError, 'iOS minimum'):
            self.inspect()

    def test_selective_resolution_rejects_unrelated_pod_changes(self):
        baseline = self.root / 'before.lock'
        baseline.write_text(self.lock_text.replace('9.4.0', '8.4.0').replace('6.1.0', '5.0.0'))
        privacy.check_lock(self.lock, baseline)
        baseline.write_text(baseline.read_text().replace('Flutter (1.0.0)', 'Flutter (0.9.0)'))
        with self.assertRaisesRegex(ValueError, 'unrelated pod'):
            privacy.check_lock(self.lock, baseline)

    def test_vendor_symlink_outside_bundle_fails(self):
        outside = self.root / 'outside.xcprivacy'
        outside.write_bytes(self.raw)
        self.bundled.unlink()
        self.bundled.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'artifact root'):
            self.inspect()

    def test_duplicate_or_ambiguous_pod_entry_fails(self):
        self.lock.write_text(self.lock_text.replace('  - Flutter (1.0.0)',
                                                  '  - Flutter (1.0.0)\n  - Flutter (1.0.0)'))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            privacy.check_lock(self.lock)


if __name__ == '__main__':
    unittest.main()
