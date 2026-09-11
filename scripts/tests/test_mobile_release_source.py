import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release_source', Path(__file__).parents[1] / 'mobile-release-source.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)


class ReleaseSourceTest(unittest.TestCase):
    def test_actual_git_branches_tags_and_stale_checkout(self):
        with tempfile.TemporaryDirectory() as temporary:
            def git(*args):
                return subprocess.check_output(['git', '-C', temporary, *args],
                                               text=True, stderr=subprocess.DEVNULL).strip()
            git('init', '-b', 'master')
            git('config', 'user.name', 'Fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            git('commit', '--allow-empty', '-m', 'root')
            master = git('rev-parse', 'HEAD')
            git('update-ref', 'refs/remotes/origin/master', master)
            git('tag', 'v1.0.1')
            git('checkout', '-b', 'develop')
            git('commit', '--allow-empty', '-m', 'test')
            develop = git('rev-parse', 'HEAD')
            git('update-ref', 'refs/remotes/origin/develop', develop)
            git('tag', 'v9.9.9')
            git('tag', 'iosbuild-test')
            with patch.object(source, 'git', side_effect=git), patch.object(source.subprocess, 'run', wraps=subprocess.run) as run:
                # Only merge-base uses run; force the fixture repository without changing cwd.
                run.side_effect = lambda command, **kwargs: run._mock_wraps(command, cwd=temporary, **kwargs)
                self.assertEqual(source.verify('test', 'refs/heads/develop', develop), 'develop')
                self.assertEqual(source.verify('test', 'refs/tags/iosbuild-test', develop), 'develop')
                for environment, ref, sha in [
                    ('prod', 'refs/heads/develop', develop),
                    ('test', 'refs/heads/feature-launch', develop),
                    ('prod', 'refs/tags/v1.0.1', develop),
                    ('test', 'refs/heads/develop', master),
                ]:
                    with self.subTest(ref=ref), self.assertRaises(ValueError):
                        source.verify(environment, ref, sha)
                with self.assertRaises(subprocess.CalledProcessError):
                    source.verify('prod', 'refs/tags/v9.9.9', develop)
                git('checkout', '--detach', master)
                self.assertEqual(source.verify('prod', 'refs/tags/v1.0.1', master), 'master')
