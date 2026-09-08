from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
from pathlib import Path
import unittest
from copy import deepcopy

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('ios_signing', ROOT / 'scripts/ios-signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class IosSigningTest(unittest.TestCase):
    def test_profile_matches_exact_app_team_capabilities_and_certificate(self):
        # Synthetic fixture; this is not an Apple certificate/profile or runtime evidence.
        now = datetime(2026, 9, 7, tzinfo=timezone.utc)
        certificate = b'synthetic-profile-certificate-fixture'
        sha1 = hashlib.sha1(certificate).hexdigest()
        config = {'NATIVE_APPLICATION_ID': 'kr.mapservice.client.test',
                  'INVITE_LINK_ORIGIN': 'https://invite.example.com'}
        profile = {
            'UUID': '12345678-1234-1234-1234-1234567890ab',
            'TeamIdentifier': ['A1B2C3D4E5'],
            'ExpirationDate': now + timedelta(days=1),
            'DeveloperCertificates': [certificate],
            'Entitlements': {
                'application-identifier': 'P1R2E3F4I5.kr.mapservice.client.test',
                'com.apple.developer.team-identifier': 'A1B2C3D4E5',
                'get-task-allow': False,
                'com.apple.developer.applesignin': ['Default'],
                'com.apple.developer.associated-domains': ['applinks:invite.example.com'],
            },
        }
        result = signing.validate_profile(profile, config, 'A1B2C3D4E5', 'P1R2E3F4I5', sha1, now)
        self.assertEqual(result['destination'], 'export')
        self.assertEqual(result['provisioningProfiles'], {
            'kr.mapservice.client.test': profile['UUID']})
        mutations = [
            ('ExpirationDate', now - timedelta(seconds=1)),
            ('TeamIdentifier', ['X1X2X3X4X5']),
            ('DeveloperCertificates', [b'wrong certificate']),
            ('ProvisionedDevices', ['test-device']),
            ('ProvisionsAllDevices', True),
            ('UUID', 'invalid'),
        ]
        for key, value in mutations:
            with self.subTest(key=key), self.assertRaises(ValueError):
                signing.validate_profile({**profile, key: value}, config,
                                         'A1B2C3D4E5', 'P1R2E3F4I5', sha1, now)
        for key, value in [
            ('application-identifier', 'P1R2E3F4I5.kr.mapservice.client'),
            ('get-task-allow', True),
            ('com.apple.developer.applesignin', []),
            ('com.apple.developer.associated-domains', ['applinks:wrong.example.com']),
        ]:
            invalid = deepcopy(profile)
            invalid['Entitlements'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                signing.validate_profile(invalid, config, 'A1B2C3D4E5', 'P1R2E3F4I5', sha1, now)


if __name__ == '__main__':
    unittest.main()
