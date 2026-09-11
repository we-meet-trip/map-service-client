#!/usr/bin/env python3
"""Install validated signing inputs on an ephemeral GitHub macOS runner only.

The script creates an export archive configuration; it never uploads to Apple.
Secrets must be environment-scoped GitHub secrets, never repository files.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import subprocess
import sys
from urllib.parse import urlsplit


def validate_profile(profile, config, team, prefix, certificate_sha1, now=None):
    if not re.fullmatch(r'[A-Z0-9]{10}', team) or not re.fullmatch(r'[A-Z0-9]{10}', prefix):
        raise ValueError('IOS_TEAM_ID and IOS_APP_ID_PREFIX must be explicitly configured')
    if not re.fullmatch(r'[0-9A-Fa-f]{40}', certificate_sha1):
        raise ValueError('IOS_DISTRIBUTION_CERT_SHA1 is required')
    entitlements = profile.get('Entitlements', {})
    application = prefix + '.' + config['NATIVE_APPLICATION_ID']
    if (profile.get('TeamIdentifier') != [team]
            or entitlements.get('com.apple.developer.team-identifier') != team
            or entitlements.get('application-identifier') != application):
        raise ValueError('Provisioning profile team or application identifier mismatch')
    expiry = profile.get('ExpirationDate')
    if not isinstance(expiry, datetime):
        raise ValueError('Provisioning profile expiration is missing')
    now = now or datetime.now(timezone.utc)
    if expiry.replace(tzinfo=timezone.utc) <= now:
        raise ValueError('Provisioning profile is expired')
    if (entitlements.get('get-task-allow') is not False or profile.get('ProvisionedDevices')
            or profile.get('ProvisionsAllDevices')):
        raise ValueError('An App Store distribution profile is required')
    if 'Default' not in entitlements.get('com.apple.developer.applesignin', []):
        raise ValueError('Provisioning profile must permit Sign in with Apple')
    domains = entitlements.get('com.apple.developer.associated-domains', [])
    if '*' not in domains and ('applinks:' + urlsplit(config['INVITE_LINK_ORIGIN']).hostname) not in domains:
        raise ValueError('Provisioning profile must permit the invite Associated Domain')
    certificates = profile.get('DeveloperCertificates', [])
    if not any(hashlib.sha1(cert).hexdigest().upper() == certificate_sha1.upper()
               for cert in certificates if isinstance(cert, bytes)):
        raise ValueError('Distribution signing certificate does not belong to the provisioning profile')
    uuid = profile.get('UUID', '')
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', uuid):
        raise ValueError('Provisioning profile UUID is invalid')
    return {
        'method': 'app-store-connect', 'destination': 'export',
        'signingStyle': 'manual', 'teamID': team,
        'signingCertificate': certificate_sha1.upper(),
        'provisioningProfiles': {config['NATIVE_APPLICATION_ID']: uuid},
        'manageAppVersionAndBuildNumber': False,
    }


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise ValueError(f'{Path(args[0]).name} signing operation failed; private output suppressed')
    return result.stdout


def private_write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'wb') as file:
        os.fchmod(file.fileno(), 0o600)
        file.write(value)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'cleanup'])
    parser.add_argument('--config')
    parser.add_argument('--xcconfig')
    args = parser.parse_args(argv)
    try:
        if os.environ.get('GITHUB_ACTIONS') != 'true' or sys.platform != 'darwin':
            raise ValueError('Signing setup is restricted to ephemeral GitHub macOS runners')
        temporary = Path(os.environ['RUNNER_TEMP'])
        keychain = temporary / 'map-native-signing.keychain-db'
        state = temporary / 'map-native-signing-state.json'
        if args.action == 'cleanup':
            if keychain.exists():
                run('security', 'delete-keychain', str(keychain))
            if state.exists():
                profile = Path(json.loads(state.read_text())['profile'])
                profile.unlink(missing_ok=True)
            for name in ['map-native-signing-state.json', 'map-signing.p12',
                         'map-signing.mobileprovision', 'map-export-options.plist']:
                (temporary / name).unlink(missing_ok=True)
            return 0
        required = ['IOS_DISTRIBUTION_P12_B64', 'IOS_DISTRIBUTION_P12_PASSWORD',
                    'IOS_APP_STORE_PROFILE_B64', 'IOS_TEAM_ID', 'IOS_APP_ID_PREFIX',
                    'IOS_DISTRIBUTION_CERT_SHA1']
        for field in required:
            if not os.environ.get(field):
                raise ValueError(f'{field} is required for signed IPA preparation')
        config = json.loads(Path(args.config).read_text())
        p12 = temporary / 'map-signing.p12'
        source_profile = temporary / 'map-signing.mobileprovision'
        private_write(p12, base64.b64decode(os.environ['IOS_DISTRIBUTION_P12_B64'], validate=True))
        private_write(source_profile, base64.b64decode(os.environ['IOS_APP_STORE_PROFILE_B64'], validate=True))
        profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(source_profile)))
        export = validate_profile(profile, config, os.environ['IOS_TEAM_ID'],
                                  os.environ['IOS_APP_ID_PREFIX'], os.environ['IOS_DISTRIBUTION_CERT_SHA1'])
        destination = Path.home() / 'Library/MobileDevice/Provisioning Profiles' / (profile['UUID'] + '.mobileprovision')
        if destination.exists() or keychain.exists():
            raise ValueError('Refusing to replace existing signing inputs')
        private_write(state, json.dumps({'profile': str(destination)}).encode())
        private_write(destination, source_profile.read_bytes())
        password = secrets.token_urlsafe(32)
        run('security', 'create-keychain', '-p', password, str(keychain))
        run('security', 'set-keychain-settings', '-lut', '21600', str(keychain))
        run('security', 'unlock-keychain', '-p', password, str(keychain))
        run('security', 'import', str(p12), '-P', os.environ['IOS_DISTRIBUTION_P12_PASSWORD'],
            '-A', '-t', 'cert', '-f', 'pkcs12', '-k', str(keychain))
        run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', password, str(keychain))
        run('security', 'list-keychains', '-d', 'user', '-s', str(keychain))
        identities = run('security', 'find-identity', '-v', '-p', 'codesigning', str(keychain)).decode()
        if os.environ['IOS_DISTRIBUTION_CERT_SHA1'].upper() not in identities.upper():
            raise ValueError('Expected valid distribution identity is unavailable')
        private_write(temporary / 'map-export-options.plist', plistlib.dumps(export))
        with Path(args.xcconfig).open('a') as output:
            output.write('\nCODE_SIGN_STYLE = Manual\n')
            output.write('DEVELOPMENT_TEAM = ' + os.environ['IOS_TEAM_ID'] + '\n')
            output.write('CODE_SIGN_IDENTITY = ' + os.environ['IOS_DISTRIBUTION_CERT_SHA1'].upper() + '\n')
            output.write('PROVISIONING_PROFILE_SPECIFIER = ' + profile['UUID'] + '\n')
        print('Validated environment-specific App Store signing profile; no upload performed')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'iOS signing preparation rejected: {error if isinstance(error, ValueError) and not isinstance(error, json.JSONDecodeError) else type(error).__name__}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
