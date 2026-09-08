#!/usr/bin/env python3
"""Stop Xcode builds when Dart defines and native bundle/link settings disagree."""
import base64
import importlib.util
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit

MODULE = Path(__file__).resolve().parents[2] / 'scripts/mobile-release-config.py'
spec = importlib.util.spec_from_file_location('mobile_release_config', MODULE)
config_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_module)


def verify(environ):
    defines = {}
    try:
        for item in environ.get('DART_DEFINES', '').split(','):
            if item:
                name, value = base64.b64decode(item, validate=True).decode().split('=', 1)
                if name in defines:
                    raise ValueError('duplicate define')
                defines[name] = value
    except (ValueError, UnicodeError):
        raise ValueError('Malformed DART_DEFINES') from None
    environment = defines.get('APP_ENV', 'test')
    config = config_module.make_config(environment, 'ios', False, defines)
    expected = {
        'MAP_APP_ENV': environment,
        'MAP_APPLICATION_ID': config['NATIVE_APPLICATION_ID'],
        'PRODUCT_BUNDLE_IDENTIFIER': config['NATIVE_APPLICATION_ID'],
        'MAP_INVITE_SCHEME': config['INVITE_URL_SCHEME'],
        'MAP_KAKAO_SCHEME': config['KAKAO_CALLBACK_SCHEME'],
        'MAP_INVITE_HOST': urlsplit(config['INVITE_LINK_ORIGIN']).hostname,
    }
    for field, value in expected.items():
        if environ.get(field) != value:
            raise ValueError(f'{field} disagrees with Dart config; regenerate NativeEnvironment.xcconfig')
    for field in config_module.native_identity(environment):
        if field in defines and defines[field] != config[field]:
            raise ValueError(f'{field} disagrees with APP_ENV')


if __name__ == '__main__':
    try:
        verify(os.environ)
    except ValueError as error:
        print(f'error: native environment rejected: {error}', file=sys.stderr)
        raise SystemExit(1)
    print('Native bundle ID, callback, invite host and Dart environment agree')
