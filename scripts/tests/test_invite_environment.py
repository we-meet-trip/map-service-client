import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('node'), 'Node runtime is needed for browser-script fixtures')
class InviteEnvironmentTest(unittest.TestCase):
    def render(self, overrides=None, api='https://api.example.com', token='TOKEN', preview_failure=False):
        config = {
            'schema_version': 1, 'app_environment': 'test',
            'android_package': 'kr.mapservice.client.test', 'invite_scheme': 'mapservice-test',
            'invite_origin': 'https://invite.example.com',
            'api_allowed_origins': ['https://api.example.com'],
            'app_config_url': 'https://config.example.com/test.json',
            **(overrides or {}),
        }
        script = re.search(r'<script>(.*?)</script>',
                           (ROOT / 'hosting/invite/index.html').read_text(), re.S).group(1)
        fixture = r'''
const vm = require('node:vm');
const input = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
const elements = Object.fromEntries(['icon', 'title', 'sub', 'meta', 'open', 'hint'].map(id => [id, {
  attributes: {'aria-disabled': 'true'},
  setAttribute(k, v) { this.attributes[k] = v; },
  getAttribute(k) { return this.attributes[k]; },
  removeAttribute(k) { delete this.attributes[k]; },
  addEventListener() {},
}]));
const requests = [];
const location = {origin: 'https://invite.example.com', pathname: '/invite/' + input.token,
  search: '', hash: '', href: 'https://invite.example.com/invite/' + input.token};
const context = { URL, navigator: {userAgent: 'Android'},
  window: {location}, document: {getElementById: id => elements[id]},
  fetch: async (url, options) => {
    requests.push({url, options});
    if (url === '/invite-environment.json') return {ok: true, json: async () => input.config};
    if (url === input.config.app_config_url) return {ok: true, json: async () => ({api_base_url: input.api})};
    if (input.preview_failure) throw new Error('offline');
    return {ok: true, json: async () => ({title: 'Fixture room'})};
  },
};
vm.runInNewContext(input.script, context);
setTimeout(() => process.stdout.write(JSON.stringify({requests, button: elements.open,
  title: elements.title.textContent})), 5);
'''
        result = subprocess.run(['node', '-e', fixture], input=json.dumps({
            'config': config, 'api': api, 'token': token, 'script': script,
            'preview_failure': preview_failure}), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_verified_environment_opens_only_test_package_and_scheme(self):
        result = self.render()
        self.assertEqual(result['button']['attributes']['aria-disabled'], 'false')
        url = result['button']['attributes']['href']
        self.assertIn('scheme=mapservice-test;package=kr.mapservice.client.test;', url)
        self.assertEqual(len(result['requests']), 3)
        for request in result['requests']:
            self.assertEqual(request['options']['credentials'], 'omit')
            self.assertEqual(request['options']['redirect'], 'error')

    def test_wrong_environment_origin_and_unknown_schema_never_enable_launch(self):
        for invalid in [{'app_environment': 'prod'}, {'android_package': 'kr.mapservice.client'},
                        {'invite_scheme': 'mapservice'}, {'schema_version': 2},
                        {'invite_origin': 'https://other.example.com'},
                        {'app_config_url': 'http://config.example.com/test.json'}]:
            with self.subTest(invalid=invalid):
                result = self.render(invalid)
                self.assertEqual(result['button']['attributes']['aria-disabled'], 'true')
                self.assertEqual(len(result['requests']), 1)

    def test_untrusted_api_origin_cannot_receive_invite_token(self):
        for api in ['https://attacker.example.com', 'https://api.example.com/path',
                    'https://user@api.example.com', 'http://api.example.com']:
            with self.subTest(api=api):
                result = self.render(api=api)
                self.assertEqual(len(result['requests']), 2)
                self.assertEqual(result['button']['attributes']['aria-disabled'], 'false')

    def test_offline_preview_retains_valid_environment_launch(self):
        result = self.render(preview_failure=True)
        self.assertEqual(result['button']['attributes']['aria-disabled'], 'false')

    def test_invalid_token_is_rejected_before_network(self):
        for token in ['A/extra', 'a%2Fb', 'bad;intent', 'A' * 257]:
            with self.subTest(token=token):
                result = self.render(token=token)
                self.assertEqual(result['requests'], [])
                self.assertEqual(result['button']['attributes']['aria-disabled'], 'true')


if __name__ == '__main__':
    unittest.main()
