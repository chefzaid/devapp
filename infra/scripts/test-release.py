#!/usr/bin/env python3
"""Exercise publication and recovery with local Git and an isolated release API."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
API = r'''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
state_path = pathlib.Path(os.environ['RELEASE_FIXTURE_STATE'])
state = json.loads(state_path.read_text())
args = sys.argv[1:]
if '--upload-file' in args:
    state['uploads'] += 1
    state_path.write_text(json.dumps(state))
    sys.exit(0)
if '--request' in args and args[args.index('--request') + 1] == 'POST':
    state['posts'] += 1
    if state['mode'] == 'fail' or state.get('release'):
        state_path.write_text(json.dumps(state))
        sys.exit(22)
    request = json.loads(args[args.index('--data') + 1])
    revision = subprocess.check_output(['git', 'rev-parse', request['tag_name'] + '^{commit}'], text=True).strip()
    state['release'] = {'tag_name': request['tag_name'], 'commit': {'id': revision}}
    state_path.write_text(json.dumps(state))
    sys.exit(28 if state['mode'] == 'lost-response' else 0)
if state.get('release'):
    print(json.dumps(state['release']))
else:
    sys.exit(22)
'''


class PublicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='devapp-release-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.work = self.root / 'work'
        self.work.mkdir()
        self.remote = self.root / 'remote.git'
        self.run_command('git', 'init', '-q', '--bare', '--initial-branch=trunk', str(self.remote))
        self.git('init', '-q', '-b', 'trunk')
        self.git('config', 'user.name', 'Release fixture')
        self.git('config', 'user.email', 'release@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        self.git('config', 'tag.gpgsign', 'false')
        self.git('remote', 'add', 'origin', str(self.remote))
        (self.work / 'infra/scripts').mkdir(parents=True)
        for name in ('ci-release.sh', 'ci-set-major-version.sh', 'check-onboarding-revision.sh',
                     'commit-deployment.sh', 'set-image-tags.sh', 'current-version.sh'):
            shutil.copy2(ROOT / 'infra/scripts' / name, self.work / 'infra/scripts' / name)
        self.write('infra/scripts/set-project-version.sh', '#!/bin/sh\nprintf "%s\\n" "$1" > VERSION\n', executable=True)
        self.write('infra/scripts/ci-container-build.sh', '#!/bin/sh\nprintf "build\\n" >> "$RELEASE_FIXTURE_BUILDS"\nmkdir -p package-output/image-digests\nfor name in user-app order-app devapp-web; do\n  printf "sha256:' + 'a' * 64 + '\\n" > "package-output/image-digests/$name"\ndone\n', executable=True)
        for name in ('pom.xml', 'devapp-common/pom.xml', 'order-app/pom.xml', 'user-app/pom.xml',
                     'devapp-web/package.json', 'devapp-web/package-lock.json'):
            self.write(name, 'fixture\n')
        for name in ('user-app/target/user-app.jar', 'order-app/target/order-app.jar',
                     'devapp-web/devapp-web-1.0.1.tar.gz'):
            self.write(name, 'fixture artifact\n')
        self.write('VERSION', '1.0.0\n')
        self.write('infra/k8s/kustomization.yaml', 'images:\n' + ''.join(
            f'  - name: registry.example.test/teams/testing/devapp/{name}\n    newTag: 1.0.0\n'
            for name in ('user-app', 'order-app', 'devapp-web')))
        self.write('.gitignore', 'release.env\npackage-output/\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'Application source')
        self.write('infra/k8s/runtime-config.json', '{"host":"portal.example.test"}\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'Configure deployment [skip ci]')
        self.source = self.git('rev-parse', 'HEAD').stdout.strip()
        self.git('push', '-q', 'origin', 'trunk')
        self.state_path = self.root / 'api.json'
        self.state_path.write_text(json.dumps({'mode': 'success', 'uploads': 0, 'posts': 0}))
        self.builds = self.root / 'builds'
        commands = self.root / 'bin'
        commands.mkdir()
        (commands / 'curl').write_text(API)
        (commands / 'curl').chmod(0o700)
        self.env = {**os.environ, 'PATH': str(commands) + os.pathsep + os.environ['PATH'],
                    'APP_ONBOARDING': 'true', 'APP_VERSION': '1.0.1', 'CI_PIPELINE_ID': '73',
                    'CI_PIPELINE_SOURCE': 'api', 'CI_DEFAULT_BRANCH': 'trunk', 'CI_COMMIT_BRANCH': 'trunk',
                    'CI_COMMIT_SHA': self.source, 'ONBOARDING_EXPECTED_SHA': self.source,
                    'SONAR_SCAN_ONLY': 'false', 'NEW_MAJOR_VERSION': '', 'RELEASE_VERSION': '',
                    'PIPELINE_MODE': 'standard', 'DEPLOYMENT_ENVIRONMENT': 'int', 'CI_PROJECT_PATH': 'teams/testing/devapp',
                    'CI_PROJECT_NAME': 'devapp', 'CI_PROJECT_ID': '735', 'CI_REGISTRY': 'registry.example.test', 'CI_JOB_TOKEN': 'fixture-only-token',
                    'CI_SERVER_URL': 'https://source.example.test', 'CI_API_V4_URL': 'https://source.example.test/api/v4',
                    'PACKAGE_REGISTRY_API_V4_URL': 'http://gitlab.services.test/api/v4',
                    'RELEASE_FIXTURE_STATE': str(self.state_path), 'RELEASE_FIXTURE_BUILDS': str(self.builds)}

    def write(self, name, content, executable=False):
        path = self.work / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        if executable:
            path.chmod(0o700)

    def run_command(self, *args, **kwargs):
        return subprocess.run(args, cwd=self.work, text=True, capture_output=True, timeout=30, check=True, **kwargs)

    def git(self, *args):
        return self.run_command('git', *args)

    def state(self, **changes):
        state = json.loads(self.state_path.read_text())
        state.update(changes)
        self.state_path.write_text(json.dumps(state))
        return state

    def publish(self, **changes):
        result = subprocess.run(['bash', 'infra/scripts/ci-release.sh', 'publish'], cwd=self.work,
                                env={**self.env, **changes}, text=True, capture_output=True, timeout=30)
        self.assertNotIn(self.env['CI_JOB_TOKEN'], result.stdout + result.stderr)
        return result

    def interrupted_publication(self):
        self.state(mode='fail')
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.published = self.git('rev-parse', 'v1.0.1^{commit}').stdout.strip()
        self.tip = self.git('rev-parse', 'refs/remotes/origin/trunk').stdout.strip()
        self.git('checkout', '-q', '--detach', self.source)
        (self.work / 'release.env').unlink()
        self.state(mode='success')

    def test_configuration_only_commit_publishes_and_lost_post_response_is_verified(self):
        self.state(mode='lost-response')
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        release = self.state()['release']
        self.assertEqual(release['commit']['id'], self.git('rev-parse', 'v1.0.1^{commit}').stdout.strip())
        self.assertEqual(self.git('show', 'trunk:infra/k8s/runtime-config.json').stdout,
                         '{"host":"portal.example.test"}\n')
        self.assertIn('NEXT_VERSION=1.1.0', (self.work / 'release.env').read_text())
        manifest = json.loads(self.git('show', 'v1.0.1:infra/releases/1.0.1.json').stdout)
        self.assertEqual(manifest['sourceRevision'], self.source)
        self.assertEqual(set(manifest['images']), {'user-app', 'order-app', 'devapp-web'})
        self.assertEqual(self.git('show', 'trunk:infra/k8s/kustomization.yaml').stdout,
                         self.git('show', self.source + ':infra/k8s/kustomization.yaml').stdout)

    def test_failed_finalization_resumes_without_rebuilding_or_republishing(self):
        self.interrupted_publication()
        trailers = self.git('show', '-s', '--format=%(trailers)', self.tip).stdout
        self.assertIn('Onboarding-Pipeline: 73', trailers)
        self.assertIn('Onboarding-Source: ' + self.source, trailers)
        uploads = self.state()['uploads']
        for _ in range(2):
            result = self.publish()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Resuming GitLab release finalization', result.stdout)
            self.assertIn('PUBLICATION_COMMIT=' + self.tip, (self.work / 'release.env').read_text())
            self.assertEqual(self.git('rev-parse', 'refs/remotes/origin/trunk').stdout.strip(), self.tip)
            self.assertEqual(self.state()['uploads'], uploads)
            self.assertEqual(self.builds.read_text(), 'build\n')

    def test_foreign_pipeline_source_or_non_onboarding_request_cannot_resume(self):
        self.interrupted_publication()
        for change in ({'CI_PIPELINE_ID': '74'}, {'ONBOARDING_EXPECTED_SHA': 'f' * 40},
                       {'CI_PIPELINE_SOURCE': 'web'}, {'SONAR_SCAN_ONLY': 'true'}):
            with self.subTest(change=change):
                self.assertNotEqual(self.publish(**change).returncode, 0)
        self.assertEqual(self.state()['posts'], 1)
        self.assertEqual(self.builds.read_text(), 'build\n')

    def test_advanced_branch_and_moved_or_missing_tag_cannot_resume(self):
        self.interrupted_publication()
        self.git('checkout', '-q', 'trunk')
        self.git('commit', '-q', '--allow-empty', '-m', 'Unrelated change')
        self.git('push', '-q', 'origin', 'trunk')
        self.git('checkout', '-q', '--detach', self.source)
        self.assertNotEqual(self.publish().returncode, 0)
        self.git('push', '-q', '--force', 'origin', self.tip + ':refs/heads/trunk')
        self.git('tag', '--force', 'v1.0.1', self.source)
        self.git('push', '-q', '--force', 'origin', 'refs/tags/v1.0.1')
        self.assertNotEqual(self.publish().returncode, 0)
        self.git('push', '-q', 'origin', ':refs/tags/v1.0.1')
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.builds.read_text(), 'build\n')

    def test_conflicting_api_release_is_rejected(self):
        self.interrupted_publication()
        self.state(release={'tag_name': 'v1.0.1', 'commit': {'id': self.source}})
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.builds.read_text(), 'build\n')

    def test_marked_release_with_invalid_image_manifest_cannot_resume(self):
        self.interrupted_publication()
        self.git('checkout', '-q', '--detach', self.published)
        image_file = self.work / 'infra/releases/1.0.1.json'
        manifest = json.loads(image_file.read_text())
        manifest['images']['user-app']['repository'] = 'registry.foreign.test/other/app'
        image_file.write_text(json.dumps(manifest))
        self.git('add', '.')
        self.git('commit', '-q', '--amend', '--no-edit')
        self.git('tag', '--force', '--annotate', 'v1.0.1', '--message', 'Release fixture')
        self.write('VERSION', '1.1.0\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'Prepare next version', '--trailer', 'Release-Pipeline: 73',
                 '--trailer', 'Release-Source: ' + self.source)
        self.git('push', '-q', '--atomic', '--force', 'origin', 'HEAD:refs/heads/trunk', 'refs/tags/v1.0.1')
        self.git('checkout', '-q', '--detach', self.source)
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.state()['posts'], 1)
        self.assertEqual(self.builds.read_text(), 'build\n')

    def test_feature_branch_cannot_publish_a_release_outside_onboarding(self):
        result = self.publish(APP_ONBOARDING="false", CI_COMMIT_BRANCH="feature/unreleased")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires the default branch", result.stderr)
        self.assertFalse(self.builds.exists())
        self.assertEqual(self.state()["posts"], 0)

    def test_snapshot_version_baseline_is_buildable_but_cannot_be_published_as_a_release(self):
        self.write("VERSION", "2.3.4-SNAPSHOT\n")
        self.git("add", "VERSION")
        self.git("commit", "-qm", "Use a development baseline")
        self.git("commit", "-qm", "A feature change", "--allow-empty")
        environment = {**self.env, "CI_COMMIT_SHA": self.git("rev-parse", "HEAD").stdout.strip()}
        version = self.run_command("sh", "infra/scripts/current-version.sh", env=environment).stdout.strip()
        self.assertEqual(version, "2.3.5-SNAPSHOT")
        self.assertNotEqual(self.publish(APP_VERSION=version).returncode, 0)
        self.assertFalse(self.builds.exists())

    def test_delivery_policy_rejects_invalid_requests_before_building(self):
        cases = (
            ({"DEPLOYMENT_ENVIRONMENT": "int", "CI_COMMIT_BRANCH": "feature/branch"}, True),
            ({"DEPLOYMENT_ENVIRONMENT": "uat", "CI_COMMIT_BRANCH": "feature/branch"}, False),
            ({"DEPLOYMENT_ENVIRONMENT": "prod", "CI_COMMIT_BRANCH": "feature/branch"}, False),
            ({"DEPLOYMENT_ENVIRONMENT": "prod", "RELEASE_VERSION": "1.0.1"}, True),
            ({"DEPLOYMENT_ENVIRONMENT": "prod", "RELEASE_VERSION": "1.0.1-SNAPSHOT"}, False),
            ({"DEPLOYMENT_ENVIRONMENT": "int", "RELEASE_VERSION": "snapshot-latest"}, False),
            ({"DEPLOYMENT_ENVIRONMENT": "prod", "RELEASE_VERSION": "01.0.1"}, False),
            ({"DEPLOYMENT_ENVIRONMENT": "wrong"}, False),
        )
        for changes, accepted in cases:
            with self.subTest(changes=changes):
                result = subprocess.run(["bash", "infra/scripts/ci-release.sh", "validate"], cwd=self.work,
                    env={**self.env, "RELEASE_VERSION": "", **changes}, text=True, capture_output=True, timeout=30)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
        self.assertFalse(self.builds.exists())

    def test_major_version_reads_committed_version_without_a_ci_variable(self):
        environment = {**self.env, 'NEW_MAJOR_VERSION': '2'}
        environment.pop('VERSION', None)
        result = subprocess.run(['bash', 'infra/scripts/ci-set-major-version.sh'], cwd=self.work,
                                env=environment, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git('show', 'origin/trunk:VERSION').stdout, '2.0.0\n')
        self.assertEqual(self.git('show', 'origin/trunk:infra/k8s/runtime-config.json').stdout,
                         '{"host":"portal.example.test"}\n')


if __name__ == '__main__':
    unittest.main()
