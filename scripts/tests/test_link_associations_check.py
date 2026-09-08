import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CHECK = ROOT / 'scripts/link-associations-check.py'
PACKAGE = 'kr.mapservice.client.test'
PRINT = ':'.join(f'{value:02X}' for value in range(1, 33))
PROD_PACKAGE = 'kr.mapservice.client'
PROD_API = 'https://api.map.example.com'


def manifest(**overrides):
    base = {
        'schema_version': 1,
        'app_environment': 'test',
        'android_package': PACKAGE,
        'invite_scheme': 'mapservice-test',
        'invite_origin': 'https://mapcenter-b59ca.web.app',
        'app_config_url': 'https://mapcenter-b59ca.web.app/app_config.json',
        'api_allowed_origins': ['https://mapapptest.duckdns.org'],
        'public_site_origin': 'https://mapcenter-b59ca.web.app',
    }
    base.update(overrides)
    return base


def assetlinks(package=PACKAGE, fingerprints=(PRINT,)):
    return [{'relation': ['delegate_permission/common.handle_all_urls'],
             'target': {'namespace': 'android_app', 'package_name': package,
                        'sha256_cert_fingerprints': list(fingerprints)}}]


def association(app_id=f'ABCDE12345.{PACKAGE}', paths=('/invite/*',)):
    return {'applinks': {'apps': [], 'details': [{'appID': app_id, 'paths': list(paths)}]}}


def production():
    return manifest(app_environment='prod', android_package=PROD_PACKAGE,
                    invite_scheme='mapservice', invite_origin='https://map.example.com',
                    app_config_url='https://map.example.com/app_config.json',
                    api_allowed_origins=[PROD_API], public_site_origin='https://map.example.com')


class LinkAssociationCheckTest(unittest.TestCase):
    def build(self, directory, *, invite=..., links=..., apple=None, app_config=None):
        root = Path(directory)
        (root / '.well-known').mkdir(parents=True, exist_ok=True)
        if invite is not None:
            body = manifest() if invite is ... else invite
            (root / 'invite-environment.json').write_text(json.dumps(body))
        if links is not None:
            body = assetlinks() if links is ... else links
            (root / '.well-known/assetlinks.json').write_text(json.dumps(body))
        if apple is not None:
            (root / '.well-known/apple-app-site-association').write_text(json.dumps(apple))
        if app_config is not None:
            (root / 'app_config.json').write_text(json.dumps(app_config))
        return root

    def run_check(self, root, *options):
        return subprocess.run(['python3', str(CHECK), '--directory', str(root), *options],
                              capture_output=True, text=True)

    def check(self, *, options=(), **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            return self.run_check(self.build(directory, **kwargs), *options)

    def test_consistent_android_only_directory_passes_and_reports_the_missing_ios_file(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('iOS', result.stdout)
        self.assertIn('NOT_RUN', result.stdout)

    def test_missing_invite_manifest_stops_the_publish(self):
        result = self.check(invite=None)
        self.assertEqual(result.returncode, 1)
        self.assertIn('invite-environment.json', result.stderr)

    def test_assetlinks_for_another_package_is_not_accepted(self):
        result = self.check(links=assetlinks(package='kr.mapservice.client'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('패키지', result.stderr)

    def test_placeholder_signing_fingerprint_is_rejected(self):
        for fingerprint in ('AA:BB', ':'.join(['AA'] * 32), ':'.join(['AB'] * 32)):
            result = self.check(links=assetlinks(fingerprints=(fingerprint,)))
            self.assertEqual(result.returncode, 1)
            self.assertIn('지문', result.stderr)

    def test_present_association_must_name_the_same_app_and_invite_path(self):
        self.assertEqual(self.check(apple=association()).returncode, 0)
        wrong_app = self.check(apple=association(app_id='ABCDE12345.kr.mapservice.client'))
        self.assertEqual(wrong_app.returncode, 1)
        self.assertIn('appID', wrong_app.stderr)
        wrong_path = self.check(apple=association(paths=('/other/*',)))
        self.assertEqual(wrong_path.returncode, 1)
        self.assertIn('paths', wrong_path.stderr)
        empty = self.check(apple={'applinks': {'apps': [], 'details': []}})
        self.assertEqual(empty.returncode, 1)
        self.assertIn('details', empty.stderr)

    def test_app_config_pointing_outside_the_allowed_origins_is_rejected(self):
        good = self.check(app_config={'environment': 'test', 'api_base_url': 'https://mapapptest.duckdns.org'})
        self.assertEqual(good.returncode, 0, good.stderr)
        bad = self.check(app_config={'environment': 'test', 'api_base_url': 'https://other.example.com'})
        self.assertEqual(bad.returncode, 1)
        self.assertIn('api_base_url', bad.stderr)

    def test_app_config_environment_must_be_present_and_match(self):
        for environment in (None, 'prod', 'staging'):
            with self.subTest(environment=environment):
                result = self.check(app_config={'environment': environment,
                                               'api_base_url': 'https://mapapptest.duckdns.org'})
                self.assertEqual(result.returncode, 1)
                self.assertIn('environment', result.stderr)

    def test_association_relations_and_paths_must_be_arrays(self):
        for field, value in (('relation', 'delegate_permission/common.handle_all_urls'),
                             ('relation', 123), ('paths', '/invite/*'), ('paths', 123)):
            links, apple = assetlinks(), association()
            target = links[0] if field == 'relation' else apple['applinks']['details'][0]
            target[field] = value
            with self.subTest(field=field, value=value):
                result = self.check(links=links, apple=apple)
                self.assertEqual(result.returncode, 1)
                self.assertNotIn('Traceback', result.stderr)

    def test_identity_is_bound_to_the_environment_including_extra_statements(self):
        for override in ({'android_package': PROD_PACKAGE}, {'invite_scheme': 'mapservice'}):
            self.assertEqual(self.check(invite=manifest(**override)).returncode, 1)
        self.assertEqual(self.check(links=assetlinks() + assetlinks(package=PROD_PACKAGE)).returncode, 1)
        for override in ({'android_package': PACKAGE}, {'invite_scheme': 'mapservice-test'}):
            result = self.check(invite={**production(), **override}, links=assetlinks(PROD_PACKAGE),
                                apple=association(f'ABCDE12345.{PROD_PACKAGE}'),
                                app_config={'environment': 'prod', 'api_base_url': PROD_API})
            self.assertEqual(result.returncode, 1)

    def test_prod_rejects_every_known_test_endpoint(self):
        for field, value in (
                ('invite_origin', 'https://mapcenter-b59ca.web.app'),
                ('public_site_origin', 'https://mapcenter-b59ca.firebaseapp.com'),
                ('app_config_url', 'https://mapcenter-b59ca.web.app/app_config.json'),
                ('api_allowed_origins', ['https://mapapptest.duckdns.org'])):
            invite = production()
            invite[field] = value
            with self.subTest(field=field):
                result = self.check(invite=invite, links=assetlinks(PROD_PACKAGE),
                                    apple=association(f'ABCDE12345.{PROD_PACKAGE}'),
                                    app_config={'environment': 'prod', 'api_base_url': PROD_API})
                self.assertEqual(result.returncode, 1)
                self.assertIn('prod configuration', result.stderr)

    def test_prod_requires_apple_and_remote_config(self):
        args = {'invite': production(), 'links': assetlinks(PROD_PACKAGE),
                'apple': association(f'ABCDE12345.{PROD_PACKAGE}'),
                'app_config': {'environment': 'prod', 'api_base_url': PROD_API}}
        self.assertEqual(self.check(**args).returncode, 0)
        for field in ('apple', 'app_config'):
            with self.subTest(field=field):
                result = self.check(**{**args, field: None})
                self.assertEqual(result.returncode, 1)
                self.assertIn('prod', result.stderr)

    def test_external_signer_and_prefix_are_compared_without_claiming_console_verification(self):
        options = ('--android-cert-sha256', PRINT.replace(':', '').lower(),
                   '--apple-app-id-prefix', 'ABCDE12345')
        matched = self.check(apple=association(), options=options)
        self.assertEqual(matched.returncode, 0, matched.stderr)
        self.assertIn('PASS (제공된 기대값)', matched.stdout)
        other_print = ':'.join(f'{value:02X}' for value in range(33, 65))
        mismatch = self.check(apple=association(), options=('--android-cert-sha256', other_print))
        self.assertEqual(mismatch.returncode, 1)
        self.assertNotIn(other_print, mismatch.stderr)
        extra = self.check(links=assetlinks(fingerprints=(PRINT, other_print)),
                           options=('--android-cert-sha256', PRINT))
        self.assertEqual(extra.returncode, 1)
        multi = self.check(links=assetlinks(fingerprints=(PRINT, other_print)),
                           options=('--android-cert-sha256', PRINT, '--android-cert-sha256', other_print))
        self.assertEqual(multi.returncode, 0, multi.stderr)
        for apple in (None, association()):
            mismatch = self.check(apple=apple, options=('--apple-app-id-prefix', 'ZYXWV98765'))
            self.assertEqual(mismatch.returncode, 1)
            self.assertNotIn('ZYXWV98765', mismatch.stderr)
        unbound = self.check(apple=association())
        self.assertIn('Apple 실제 앱 접두사 대조: NOT_RUN', unbound.stdout)

    def test_environment_and_origin_fields_must_be_well_formed(self):
        for override in ({'app_environment': 'staging'}, {'schema_version': 2}, {'schema_version': True},
                         {'api_allowed_origins': ['http://mapapptest.duckdns.org']},
                         {'app_config_url': 'https://elsewhere.example.com/app_config.json'},
                         {'android_package': 'notapackage'},
                         {'invite_origin': 'https://bad-.example.com'},
                         {'invite_origin': 'https://map.example.com:8443'},
                         {'app_config_url': 'https://mapcenter-b59ca.web.app/app_config.json?x=1'},
                         {'app_config_url': 'https://mapcenter-b59ca.web.app/app_config.json#x'},
                         {'api_allowed_origins': ['https://mapapptest.duckdns.org/path']},
                         {'api_allowed_origins': ['https://mapapptest.duckdns.org,https://api.example.com']}):
            with self.subTest(override=override):
                self.assertEqual(self.check(invite=manifest(**override)).returncode, 1)

    def test_actual_repository_hosting_directory_is_evaluated_by_the_predeploy_hook(self):
        hook = (ROOT / 'firebase.json').read_text()
        self.assertIn('bash tool/check_link_associations.sh', json.loads(hook)['hosting']['predeploy'])
        # The tracked directory carries no per-environment association files, so the
        # hook must stop a publish made straight from a fresh checkout.
        self.assertEqual(self.run_check(ROOT / 'hosting').returncode, 1)


if __name__ == '__main__':
    unittest.main()
