#!/usr/bin/env python3
"""Exercise the DNS entry point with isolated Kubernetes and Cloudflare fixtures."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("configure-cloudflare.sh")
TUNNEL_ID = "11111111-2222-3333-4444-555555555555"
TOKEN = "cfut_fixture_private_token"

MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, stat, sys, urllib.parse
root = pathlib.Path(os.environ['DNS_FIXTURE'])
args = sys.argv[1:]
tool = pathlib.Path(sys.argv[0]).name
state = json.loads((root / 'state.json').read_text())
call = {'tool': tool, 'args': args}
if tool == 'curl':
    config = pathlib.Path(args[args.index('--config') + 1])
    assert stat.S_IMODE(config.stat().st_mode) == 0o600
    assert stat.S_IMODE(config.parent.stat().st_mode) == 0o700
    assert os.environ['CLOUDFLARE_API_TOKEN'] in config.read_text()
    call['config'] = str(config)
    call['method'] = args[args.index('--request') + 1]
    if '--data-binary' in args:
        call['body'] = json.loads(pathlib.Path(args[args.index('--data-binary') + 1][1:]).read_text())
with (root / 'calls.jsonl').open('a') as output:
    output.write(json.dumps(call) + '\n')
if tool == 'kubectl':
    if args[:2] == ['get', 'configmap']:
        if state.get('forbidden'):
            print('Forbidden: fixture denies ingress state access', file=sys.stderr)
            sys.exit(1)
        if 'ingress' in state:
            print(json.dumps(state['ingress']))
    elif args[:2] == ['get', 'service']:
        print(state.get('origin', '198.51.100.20'))
    else:
        raise AssertionError(args)
else:
    assert tool == 'curl'
    url = urllib.parse.urlparse(args[args.index('--url') + 1])
    assert url.hostname == 'cloudflare.invalid'
    if state.get('api_error'):
        print(json.dumps({'success': False, 'errors': [{'message': state['api_error']}]}))
    elif call['method'] == 'GET' and url.path == '/client/v4/zones':
        print(json.dumps({'success': True, 'result': [{'id': 'fixture-zone'}]}))
    elif call['method'] == 'GET' and url.path.endswith('/dns_records'):
        print(json.dumps({'success': True, 'result': state.get('records', [])}))
    elif call['method'] in ('POST', 'PUT'):
        record = dict(call['body'], id='fixture-record')
        state['records'] = [record]
        (root / 'state.json').write_text(json.dumps(state))
        print(json.dumps({'success': True, 'result': record}))
    else:
        raise AssertionError(args)
'''


class CloudflareTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="devapp-dns-test-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        for name in ("kubectl", "curl"):
            command = self.root / name
            command.write_text(MOCK)
            command.chmod(0o700)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("CLOUDFLARE_", "INGRESS_"))}
        self.env.update(PATH=str(self.root) + os.pathsep + self.env["PATH"],
                        DNS_FIXTURE=str(self.root), CLOUDFLARE_API_TOKEN=TOKEN,
                        CLOUDFLARE_API_BASE="https://cloudflare.invalid/client/v4")

    def run_script(self, state=None, args=(), trace=False):
        (self.root / "state.json").write_text(json.dumps(state or {}))
        (self.root / "calls.jsonl").write_text("")
        result = subprocess.run(["bash", *( ["-x"] if trace else []), str(SCRIPT),
                                 "--zone", "example.com", *args], env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.calls = [json.loads(line) for line in (self.root / "calls.jsonl").read_text().splitlines()]
        self.assertNotIn(self.env["CLOUDFLARE_API_TOKEN"], result.stdout + result.stderr)
        self.assertNotIn(self.env["CLOUDFLARE_API_TOKEN"], json.dumps(self.calls))
        for call in self.calls:
            if "config" in call:
                self.assertFalse(Path(call["config"]).parent.exists(), "Private API files must be cleaned up")
        return result

    def mutations(self):
        return [call for call in self.calls if call.get("method") in ("POST", "PUT", "PATCH", "DELETE")]

    def published(self):
        return {"data": {"mode": "tunnel", "domain": "example.com",
                         "tunnelID": TUNNEL_ID, "publishedTunnelID": TUNNEL_ID}}

    def test_missing_platform_state_creates_direct_record_then_is_idempotent(self):
        result = self.run_script(trace=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        write, = self.mutations()
        self.assertEqual(write["method"], "POST")
        self.assertEqual({key: write["body"][key] for key in ("name", "type", "content", "proxied", "ttl")},
                         {"name": "devapp.example.com", "type": "A", "content": "198.51.100.20", "proxied": True, "ttl": 1})
        result = self.run_script({"records": [dict(write["body"], id="fixture-record")]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_published_ha_updates_direct_record_to_tunnel_and_is_idempotent(self):
        state = {"ingress": self.published(), "records": [{"id": "fixture-record", "type": "A", "content": "198.51.100.20"}]}
        result = self.run_script(state)
        self.assertEqual(result.returncode, 0, result.stderr)
        write, = self.mutations()
        self.assertEqual(write["method"], "PUT")
        self.assertEqual(write["body"]["type"], "CNAME")
        self.assertEqual(write["body"]["content"], TUNNEL_ID + ".cfargotunnel.com")
        self.assertFalse(any(call["args"][:2] == ["get", "service"] for call in self.calls))
        result = self.run_script({"ingress": self.published(), "records": [dict(write["body"], id="fixture-record")]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_incomplete_or_unknown_ha_state_fails_before_cloudflare_access(self):
        changes = ({"publishedTunnelID": ""}, {"domain": "other.example"},
                   {"tunnelID": "invalid"}, {"mode": "unknown"}, {"mode": None})
        for change in changes:
            with self.subTest(change=change):
                state = self.published()
                state["data"].update(change)
                result = self.run_script({"ingress": state})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call["tool"] == "curl" for call in self.calls))

    def test_forbidden_platform_state_never_falls_back_to_direct_dns(self):
        result = self.run_script({"forbidden": True}, args=("--origin-ip", "198.51.100.42"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call["tool"] == "curl" for call in self.calls))

    def test_explicit_origin_cannot_override_published_tunnel(self):
        for environment in (False, True):
            with self.subTest(environment=environment):
                if environment:
                    self.env["CLOUDFLARE_ORIGIN_IP"] = "198.51.100.42"
                result = self.run_script({"ingress": self.published()},
                                         args=() if environment else ("--origin-ip", "198.51.100.42"))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call["tool"] == "curl" for call in self.calls))

    def test_conflicting_address_records_are_not_deleted_or_overwritten(self):
        for other in ("AAAA", "CNAME", "A"):
            with self.subTest(other=other):
                result = self.run_script({"records": [{"id": "one", "type": "A"}, {"id": "two", "type": other}]})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.mutations(), [])

    def test_explicit_direct_origin_overwrites_one_stale_record(self):
        result = self.run_script({"ingress": {"data": {"mode": "direct"}},
                                  "records": [{"id": "one", "type": "AAAA", "content": "2001:db8::1"}]},
                                 args=("--origin-ip", "198.51.100.42", "--host-label", "preview"))
        self.assertEqual(result.returncode, 0, result.stderr)
        write, = self.mutations()
        self.assertEqual(write["method"], "PUT")
        self.assertEqual(write["body"]["name"], "preview.example.com")
        self.assertEqual(write["body"]["content"], "198.51.100.42")
        self.assertFalse(any(call["args"][:2] == ["get", "service"] for call in self.calls))

    def test_invalid_origin_never_reaches_cloudflare(self):
        result = self.run_script(args=("--origin-ip", "198.51.100.999"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call["tool"] == "curl" for call in self.calls))

    def test_api_errors_redact_reflected_token_and_cleanup_credentials(self):
        result = self.run_script({"api_error": "Fixture rejects " + TOKEN})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[redacted]", result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_token_cannot_inject_curl_configuration(self):
        for suffix in ('"', '\\', '\nurl = "https://unexpected.invalid"'):
            with self.subTest(suffix=suffix):
                self.env["CLOUDFLARE_API_TOKEN"] = TOKEN + suffix
                result = self.run_script(trace=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call["tool"] == "curl" for call in self.calls))


if __name__ == "__main__":
    unittest.main()
