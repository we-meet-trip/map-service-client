#!/usr/bin/env python3
"""Verify the checked-out release commit against develop/test or master/prod."""
import argparse
import os
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(['git', *args], text=True, stderr=subprocess.DEVNULL).strip()


def verify(environment, ref, source_sha):
    branch = {'test': 'develop', 'prod': 'master'}[environment]
    tag_prefix = 'refs/tags/v' if environment == 'prod' else 'refs/tags/iosbuild-'
    if ref != f'refs/heads/{branch}' and not ref.startswith(tag_prefix):
        raise ValueError(f'{environment} builds require {branch} or its release tag')
    if not re.fullmatch(r'[0-9a-f]{40}', source_sha) or git('rev-parse', 'HEAD') != source_sha:
        raise ValueError('checked-out commit differs from the requested source SHA')
    if ref.startswith('refs/tags/') and git('rev-parse', '--verify', ref + '^{commit}') != source_sha:
        raise ValueError('release tag differs from the requested source SHA')
    subprocess.run(['git', 'merge-base', '--is-ancestor', source_sha,
                    'refs/remotes/origin/' + branch], check=True, capture_output=True)
    return branch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--environment', choices=('test', 'prod'), required=True)
    args = parser.parse_args()
    try:
        branch = verify(args.environment, os.environ.get('GITHUB_REF', ''),
                        os.environ.get('GITHUB_SHA', ''))
        print(f'Release source verified: {args.environment} from {branch}')
    except (KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print('Release source rejected: ' + (str(error) if isinstance(error, ValueError)
                                             else type(error).__name__), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
