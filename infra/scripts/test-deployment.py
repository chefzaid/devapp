#!/usr/bin/env python3
"""Verify real environment rendering and Git promotion with isolated Git/API fixtures."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import yaml


ROOT = Path(__file__).resolve().parents[2]


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "infra/scripts" / file)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


RENDER = module("deployment_renderer", "render-deployment.py")
PUBLICATION = module("publication_fixture", "test-release.py")
INVENTORY = {
    "version": 1,
    "platform": {"domain": "example.test", "internalDomain": "services.test", "services": {
        "postgres": {"host": "100.100.0.10", "port": 30432},
        "redis": {"host": "100.100.0.10", "port": 30379},
        "kafka": {"bootstrapServers": "100.100.0.10:30940", "securityProtocol": "SASL_PLAINTEXT"},
        "vault": {"url": "http://100.100.0.10:30820"},
        "registry": {"host": "registry.example.test", "mirrorEndpoint": "http://100.100.0.10:30500"},
        "keycloak": {"url": "https://keycloak.example.test/auth", "realm": "example"}}},
    "environments": {name: {"clusterName": "apps-" + name, "server": f"https://100.100.{index}.10:6443",
        "namespace": "apps", "domain": (name + "." if name != "prod" else "") + "example.test",
        "ingressAddress": f"203.0.113.{index}", "podCIDR": "10.42.0.0/16", "nodeCIDRs": [f"100.100.{index}.10/32"]}
        for index, name in enumerate(("int", "uat", "prod"), 1)}}
RELEASE = {"version": 1, "releaseVersion": "1.0.1", "sourceRevision": "a" * 40, "pipelineId": "73",
           "images": {name: {"repository": "registry.example.test/teams/testing/devapp/" + name,
                             "digest": "sha256:" + str(index) * 64}
                      for index, name in enumerate(RENDER.IMAGES, 1)}}


def copy_base(destination, source=ROOT):
    for name in ("k8s", "argocd", "overlays"):
        shutil.copytree(source / "infra" / name, destination / "infra" / name, dirs_exist_ok=True)
    # CI runs this check after onboarding has rewritten the template's project
    # and image names. Derive fixture substitutions from the current manifests.
    kustomization = yaml.safe_load((destination / "infra/k8s/kustomization.yaml").read_text())
    replacements = {item["name"]: RELEASE["images"][item["name"].rsplit("/", 1)[-1]]["repository"]
                    for item in kustomization["images"]}
    for path in (destination / "infra").rglob("*"):
        if path.is_file() and path.suffix in (".yaml", ".json", ".properties"):
            content = path.read_text()
            for original, fixture in replacements.items():
                content = content.replace(original, fixture)
            path.write_text(content)
    path = destination / "infra/argocd/application.yaml"
    application = yaml.safe_load(path.read_text())
    application["spec"]["source"]["repoURL"] = "http://gitlab.services.test/teams/testing/devapp.git"
    path.write_text(yaml.safe_dump(application, sort_keys=False))


class RenderingTests(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {"CI_PROJECT_PATH": "teams/testing/devapp"})
        environment.start()
        self.addCleanup(environment.stop)
        temporary = tempfile.TemporaryDirectory(prefix="devapp-environments-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        copy_base(self.root)

    def test_fixture_accepts_an_already_parameterized_checkout(self):
        with tempfile.TemporaryDirectory(prefix="devapp-configured-fixture-") as temporary:
            source = Path(temporary) / "configured"
            fixture = Path(temporary) / "fixture"
            copy_base(source)
            for path in (source / "infra").rglob("*"):
                if path.is_file() and path.suffix in (".yaml", ".json", ".properties"):
                    path.write_text(path.read_text().replace("registry.example.test/teams/testing/devapp",
                        "registry.customer.test/nested/group/portal").replace(
                            "http://gitlab.services.test/teams/testing/devapp.git",
                            "https://gitlab.customer.test/nested/group/portal.git"))
            copy_base(fixture, source)
            metadata = RENDER.render(fixture, INVENTORY, "int", RELEASE, "a" * 40)
            rendered = subprocess.run(["kubectl", "kustomize", str(fixture / "infra/environments/int")],
                                      text=True, capture_output=True, check=True)
            images = [item["spec"]["template"]["spec"]["containers"][0]["image"]
                      for item in yaml.safe_load_all(rendered.stdout) if item["kind"] == "Deployment"]
            self.assertEqual(set(images), set(metadata["images"]))

    def test_renderer_still_rejects_a_foreign_ci_project(self):
        with patch.dict(os.environ, {"CI_PROJECT_PATH": "another/team/project"}):
            with self.assertRaisesRegex(ValueError, "running GitLab project"):
                RENDER.render(self.root, INVENTORY, "int", RELEASE, "a" * 40)

    def test_three_targets_have_isolated_configuration_and_the_same_digests(self):
        previous = {}
        for index, environment in enumerate(RENDER.ENVIRONMENTS, 1):
            revision = str(index) * 40
            metadata = RENDER.render(self.root, INVENTORY, environment, RELEASE, revision)
            for name, contents in previous.items():
                self.assertEqual((self.root / name).read_bytes(), contents)
            application = yaml.safe_load((self.root / f"infra/argocd/{environment}.yaml").read_text())
            self.assertEqual(application["spec"]["destination"], {"name": "apps-" + environment, "namespace": "apps"})
            self.assertEqual(application["spec"]["source"]["targetRevision"], revision)
            result = subprocess.run(["kubectl", "kustomize", f"infra/environments/{environment}"], cwd=self.root,
                                    text=True, capture_output=True, check=True)
            resources = list(yaml.safe_load_all(result.stdout))
            images = [item["spec"]["template"]["spec"]["containers"][0]["image"] for item in resources if item["kind"] == "Deployment"]
            self.assertEqual(set(images), set(metadata["images"]))
            backend = next(item for item in resources if item["kind"] == "ConfigMap" and "DB_NAME" in item.get("data", {}))
            self.assertEqual(backend["data"]["DB_NAME"], "devapp_" + environment)
            self.assertEqual(backend["data"]["KAFKA_TOPIC_PREFIX"], "devapp." + environment + ".")
            self.assertEqual(backend["data"]["REDIS_CACHE_PREFIX"], "devapp:" + environment + ":")
            self.assertEqual(backend["data"]["JWT_AUDIENCE"], "devapp-" + environment + "-web")
            secret = next(item for item in resources if item["kind"] == "ExternalSecret" and item["metadata"]["name"] == "devapp-runtime-credentials")
            self.assertEqual({item["remoteRef"]["key"] for item in secret["spec"]["data"]},
                             {f"apps/devapp/{environment}/{service}" for service in ("database", "redis", "kafka")})
            self.assertFalse(any(item["kind"] == "Job" and item["metadata"]["name"] == "devapp-db-setup" for item in resources))
            previous.update({str(path.relative_to(self.root)): path.read_bytes()
                             for path in (self.root / f"infra/environments/{environment}").rglob("*") if path.is_file()})
            previous[f"infra/argocd/{environment}.yaml"] = (self.root / f"infra/argocd/{environment}.yaml").read_bytes()

    def test_apex_custom_cidrs_and_ha_are_preserved_on_rerun(self):
        settings = self.root / "infra/environments/uat/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text(json.dumps({"appSubdomain": "@", "trustedProxyCIDRs": "10.60.0.0/16", "highAvailability": True}))
        metadata = RENDER.render(self.root, INVENTORY, "uat", RELEASE, "a" * 40)
        self.assertEqual(metadata["host"], "uat.example.test")
        snapshot = {p: p.read_bytes() for p in settings.parent.iterdir()}
        RENDER.render(self.root, INVENTORY, "uat", RELEASE, "a" * 40)
        self.assertEqual(snapshot, {p: p.read_bytes() for p in settings.parent.iterdir()})
        rendered = subprocess.run(["kubectl", "kustomize", str(settings.parent)], text=True, capture_output=True, check=True)
        self.assertTrue(all(item["spec"]["replicas"] == 2 for item in yaml.safe_load_all(rendered.stdout) if item["kind"] == "Deployment"))

    def test_invalid_target_and_foreign_image_are_rejected_before_output(self):
        for change in ("environment", "local", "namespace", "digest", "registry"):
            inventory, release = copy.deepcopy(INVENTORY), copy.deepcopy(RELEASE)
            environment = "int"
            if change == "environment": environment = "other"
            if change == "local": inventory["environments"][environment]["server"] = "https://kubernetes.default.svc"
            if change == "namespace": inventory["environments"][environment]["namespace"] = "infra"
            if change == "digest": release["images"]["user-app"]["digest"] = "latest"
            if change == "registry": release["images"]["user-app"]["repository"] = "registry.other.test/project/user-app"
            with self.subTest(change=change), self.assertRaises(ValueError):
                RENDER.render(self.root, inventory, environment, release, "a" * 40)
        self.assertFalse((self.root / "infra/environments").exists())

    def test_snapshot_manifest_only_renders_for_int_and_cannot_impersonate_a_release(self):
        snapshot = {**copy.deepcopy(RELEASE), "kind": "snapshot", "sourceBranch": "feature/é;$(example)",
                    "releaseVersion": "snapshot-" + RELEASE["sourceRevision"] + "-" + RELEASE["pipelineId"]}
        RENDER.render(self.root, INVENTORY, "int", snapshot, "a" * 40)
        for environment in ("uat", "prod"):
            with self.subTest(environment=environment), self.assertRaisesRegex(ValueError, "Snapshots can only deploy to int"):
                RENDER.render(self.root, INVENTORY, environment, snapshot, "a" * 40)
        snapshot["kind"] = "release"
        with self.assertRaisesRegex(ValueError, "canonical major.minor.patch"):
            RENDER.render(self.root, INVENTORY, "prod", snapshot, "a" * 40)
        snapshot["kind"] = "snapshot"
        snapshot["releaseVersion"] = "snapshot-latest"
        with self.assertRaisesRegex(ValueError, "exact source"):
            RENDER.render(self.root, INVENTORY, "int", snapshot, "a" * 40)

    def test_explicit_legacy_database_adoption_survives_production_rerenders(self):
        settings = self.root / "infra/environments/prod/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text(json.dumps({"databaseName": "devappdb"}))
        for _ in range(2):
            metadata = RENDER.render(self.root, INVENTORY, "prod", RELEASE, "a" * 40)
            self.assertEqual("devappdb", metadata["databaseName"])
            self.assertIn("DB_NAME=devappdb\n", (settings.parent / "backend-runtime.properties").read_text())
            self.assertEqual("devappdb", json.loads(settings.read_text())["databaseName"])
        for environment, database in (("int", "devappdb"), ("uat", "devapp_prod"), ("prod", "anotherdb")):
            target = self.root / f"infra/environments/{environment}/settings.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps({"databaseName": database}))
            with self.subTest(environment=environment), self.assertRaisesRegex(ValueError, "databaseName"):
                RENDER.render(self.root, INVENTORY, environment, RELEASE, "a" * 40)


KUBECTL = r'''#!/usr/bin/env python3
import json,os,pathlib,sys,yaml
path = pathlib.Path(os.environ['DEPLOYMENT_FIXTURE_STATE'])
state = json.loads(path.read_text())
args = [arg for arg in sys.argv[1:] if not arg.startswith('--request-timeout=')]
if args[:2] == ['get','configmap']:
    print(json.dumps({'data': {'environments.json': json.dumps(state['inventory'])}}))
elif args[:2] == ['get','application']:
    app = state.get('applications', {}).get(args[2])
    if app: print(json.dumps(app))
    elif '--ignore-not-found' not in args: sys.exit(1)
elif args[0] == 'apply':
    app = yaml.safe_load(pathlib.Path(args[args.index('-f') + 1]).read_text())
    metadata = json.loads(pathlib.Path('package-output/deployment.json').read_text())
    app['status'] = {'sync': {'revision': app['spec']['source']['targetRevision'], 'status': 'Synced'},
      'health': {'status': 'Healthy'}, 'summary': {'images': metadata['images']},
      'resources': [{'kind':'Deployment','name':name,'health':{'status':'Healthy'}} for name in ('user-app','order-app','devapp-web')]}
    if state.get('wrong_destination'): app['spec']['destination']['name'] = 'wrong-cluster'
    state.setdefault('applications', {})[app['metadata']['name']] = app
    state.setdefault('applied', []).append(app['metadata']['name'])
    path.write_text(json.dumps(state))
elif args[0] != 'annotate':
    raise RuntimeError('Unexpected kubectl invocation: ' + repr(args))
'''


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.fixture = PUBLICATION.PublicationTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        fixture = self.fixture
        copy_base(fixture.work)
        shutil.copy2(ROOT / "infra/scripts/render-deployment.py", fixture.work / "infra/scripts/render-deployment.py")
        fixture.write("infra/deployment-environments.json", json.dumps(INVENTORY))
        fixture.git("add", ".")
        fixture.git("commit", "-qm", "Configure central deployment inventory")
        fixture.source = fixture.git("rev-parse", "HEAD").stdout.strip()
        fixture.env.update(CI_COMMIT_SHA=fixture.source, ONBOARDING_EXPECTED_SHA=fixture.source)
        fixture.git("push", "-q", "origin", "trunk")
        result = fixture.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.state_path = fixture.root / "deployment-state.json"
        self.state_path.write_text(json.dumps({"inventory": INVENTORY}))
        (fixture.root / "bin/kubectl").write_text(KUBECTL)
        (fixture.root / "bin/kubectl").chmod(0o700)
        curl = fixture.root / "bin/curl"
        text = curl.read_text().replace("state_path =", '''if any(arg.startswith('https://devapp.') for arg in sys.argv[1:]):
    metadata = json.loads(pathlib.Path('package-output/deployment.json').read_text())
    url = sys.argv[-1]
    assert url.startswith(metadata['url'] + '/')
    if url.endswith('/runtime-config.json'): print(json.dumps(metadata['runtimeConfig']))
    elif '/health/' in url: print('{"status":"UP"}')
    else: print('<html><app-root></app-root></html>')
    sys.exit(0)
state_path =''', 1)
        curl.write_text(text)
        self.env = {**fixture.env, "DEPLOYMENT_ENVIRONMENT": "int", "DEPLOYMENT_FIXTURE_STATE": str(self.state_path)}

    def state(self, **changes):
        state = json.loads(self.state_path.read_text())
        state.update(changes)
        self.state_path.write_text(json.dumps(state))
        return state

    def deploy(self, **changes):
        return subprocess.run(["bash", "infra/scripts/ci-release.sh", "deploy"], cwd=self.fixture.work,
                              env={**self.env, **changes}, text=True, capture_output=True, timeout=30)

    def test_one_publication_promotes_across_targets_without_rebuilding_or_repointing_other_apps(self):
        fixture = self.fixture
        previous = {}
        for index, environment in enumerate(RENDER.ENVIRONMENTS):
            changes = {"DEPLOYMENT_ENVIRONMENT": environment}
            if index:
                changes.update(RELEASE_VERSION="1.0.1", APP_ONBOARDING="false", CI_PIPELINE_SOURCE="web",
                               CI_PIPELINE_ID=str(74 + index), CI_COMMIT_SHA=fixture.git("rev-parse", "origin/trunk").stdout.strip())
            result = self.deploy(**changes)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            state = self.state()
            for name, app in previous.items():
                self.assertEqual(state["applications"][name], app)
            previous = copy.deepcopy(state["applications"])
            app = state["applications"]["devapp-" + environment]
            runtime = app["spec"]["source"]["targetRevision"]
            tip = fixture.git("rev-parse", "origin/trunk").stdout.strip()
            self.assertNotEqual(runtime, tip)
            self.assertEqual(fixture.git("rev-parse", tip + "^").stdout.strip(), runtime)
            self.assertEqual(app["spec"]["destination"]["name"], "apps-" + environment)
            self.assertEqual(fixture.builds.read_text(), "build\n")
            self.assertEqual(fixture.git("show", "origin/trunk:VERSION").stdout, "1.1.0\n")
        image_sets = [app["status"]["summary"]["images"] for app in previous.values()]
        self.assertTrue(all(images == image_sets[0] for images in image_sets))

    def test_retry_keeps_the_same_git_pointer_and_does_not_rebuild(self):
        result = self.deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        tip = self.fixture.git("rev-parse", "origin/trunk").stdout
        result = self.deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(tip, self.fixture.git("rev-parse", "origin/trunk").stdout)
        self.assertEqual(self.fixture.builds.read_text(), "build\n")

    def test_reassigned_cluster_and_unregistered_environment_never_apply(self):
        changed = copy.deepcopy(INVENTORY)
        changed["environments"]["int"]["clusterName"] = "foreign-cluster"
        self.state(inventory=changed)
        tip = self.fixture.git("rev-parse", "origin/trunk").stdout
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertEqual(tip, self.fixture.git("rev-parse", "origin/trunk").stdout)
        self.assertFalse(self.state().get("applied"))
        self.state(inventory={**INVENTORY, "environments": {}})
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertFalse(self.state().get("applied"))

    def test_advanced_branch_and_invalid_environment_never_apply(self):
        self.fixture.git("commit", "--allow-empty", "-qm", "Another release changed source")
        self.fixture.git("push", "-q", "origin", "trunk")
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertNotEqual(self.deploy(DEPLOYMENT_ENVIRONMENT="../prod").returncode, 0)
        self.assertFalse(self.state().get("applied"))

    def test_unfinalized_release_is_rejected_by_delivery_and_direct_live_renderer(self):
        fixture = self.fixture
        fixture.state(release=None)
        result = self.deploy()
        self.assertNotEqual(result.returncode, 0)
        manifest = fixture.git("show", "v1.0.1:infra/releases/1.0.1.json").stdout
        fixture.write("package-output/deployment-release.json", manifest)
        result = subprocess.run(["python3", "infra/scripts/render-deployment.py", "--inventory",
            "infra/deployment-environments.json", "--environment", "prod", "--release",
            "package-output/deployment-release.json", "--revision", fixture.source, "--verify-live"],
            cwd=fixture.work, env=self.env, text=True, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not finalized", result.stderr)
        self.assertFalse(self.state().get("applied"))

    def test_wrong_live_destination_cannot_report_success(self):
        self.state(wrong_destination=True)
        result = self.deploy()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("target or pinned revision changed", result.stderr)


class SnapshotTests(PromotionTests):
    # Reuse setup helpers, but run only snapshot cases in this subclass.
    test_one_publication_promotes_across_targets_without_rebuilding_or_repointing_other_apps = None
    test_retry_keeps_the_same_git_pointer_and_does_not_rebuild = None
    test_reassigned_cluster_and_unregistered_environment_never_apply = None
    test_advanced_branch_and_invalid_environment_never_apply = None
    test_wrong_live_destination_cannot_report_success = None
    test_unfinalized_release_is_rejected_by_delivery_and_direct_live_renderer = None

    def prepare_branch(self, branch="feature/é;$(example)", pipeline="84"):
        fixture = self.fixture
        fixture.git("checkout", "-q", "trunk")
        fixture.write("infra/environments/int/settings.json", json.dumps({"appSubdomain": "devapp"}))
        fixture.git("add", "infra/environments/int/settings.json")
        fixture.git("commit", "-qm", "Current integration settings")
        fixture.git("push", "-q", "origin", "trunk")
        self.default_tip = fixture.git("rev-parse", "origin/trunk").stdout.strip()
        fixture.git("checkout", "-q", "-b", branch)
        fixture.write("VERSION", "2.0.0-SNAPSHOT\n")
        fixture.write("feature-code.txt", "Feature source, unchanged by delivery\n")
        fixture.write("infra/environments/int/settings.json", json.dumps({"appSubdomain": "stale-branch-host"}))
        fixture.git("add", "VERSION", "feature-code.txt", "infra/environments/int/settings.json")
        fixture.git("commit", "-qm", "Unreleased feature")
        source = fixture.git("rev-parse", "HEAD").stdout.strip()
        fixture.git("push", "-q", "origin", "HEAD:refs/heads/" + branch)
        self.env.update(APP_ONBOARDING="false", CI_PIPELINE_SOURCE="web", CI_PIPELINE_ID=pipeline,
                        CI_COMMIT_BRANCH=branch, CI_COMMIT_SHA=source)
        (fixture.work / "release.env").unlink(missing_ok=True)
        self.snapshot_branch = "gitops/int/" + pipeline
        return source

    def snapshot(self, **changes):
        return subprocess.run(["bash", "infra/scripts/ci-release.sh", "snapshot"], cwd=self.fixture.work,
                              env={**self.env, **changes}, text=True, capture_output=True, timeout=30)

    def test_snapshot_keeps_branch_main_versions_and_other_targets_unchanged_and_retries_without_rebuilding(self):
        source = self.prepare_branch()
        fixture = self.fixture
        tags = fixture.git("ls-remote", "--tags", "origin").stdout
        posts = fixture.state()["posts"]
        result = self.snapshot()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        for _ in range(2):
            result = self.deploy()
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        app = self.state()["applications"]["devapp-int"]
        runtime = app["spec"]["source"]["targetRevision"]
        pointer = fixture.git("rev-parse", "origin/" + self.snapshot_branch).stdout.strip()
        self.assertEqual(fixture.git("rev-parse", pointer + "^").stdout.strip(), runtime)
        self.assertEqual(fixture.git("show", runtime + ":VERSION").stdout, "2.0.0-SNAPSHOT\n")
        self.assertEqual(fixture.git("show", runtime + ":feature-code.txt").stdout, "Feature source, unchanged by delivery\n")
        self.assertEqual(fixture.git("rev-parse", "origin/" + self.env["CI_COMMIT_BRANCH"]).stdout.strip(), source)
        self.assertEqual(fixture.git("rev-parse", "origin/trunk").stdout.strip(), self.default_tip)
        self.assertEqual(fixture.git("ls-remote", "--tags", "origin").stdout, tags)
        self.assertEqual(set(self.state()["applications"]), {"devapp-int"})
        self.assertEqual(fixture.state()["posts"], posts)
        manifest = json.loads(fixture.git("show", runtime + ":infra/snapshots/84.json").stdout)
        self.assertEqual(manifest["sourceBranch"], self.env["CI_COMMIT_BRANCH"])
        self.assertEqual(manifest["releaseVersion"], "snapshot-" + source + "-84")
        self.assertEqual(json.loads(fixture.git("show", runtime + ":infra/environments/int/settings.json").stdout)["appSubdomain"], "devapp")
        fixture.git("checkout", "-q", "--detach", source)
        (fixture.work / "release.env").unlink()
        result = self.snapshot()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(fixture.builds.read_text(), "build\nbuild\n")
        self.assertEqual(fixture.git("rev-parse", "origin/" + self.snapshot_branch).stdout.strip(), pointer)

    def test_snapshots_and_branch_promotions_cannot_reach_uat_or_prod(self):
        self.prepare_branch()
        for environment in ("uat", "prod"):
            self.assertNotEqual(self.snapshot(DEPLOYMENT_ENVIRONMENT=environment).returncode, 0)
            for release in ("", "1.0.1", "1.0.1-SNAPSHOT", "snapshot-latest"):
                with self.subTest(environment=environment, release=release):
                    result = self.deploy(DEPLOYMENT_ENVIRONMENT=environment, RELEASE_VERSION=release)
                    self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.state().get("applied"))
        self.assertEqual(self.fixture.builds.read_text(), "build\n")

    def test_source_advance_before_publication_or_deploy_is_rejected(self):
        self.prepare_branch(branch="feature/slash/nested")
        self.assertEqual(self.snapshot().returncode, 0)
        fixture = self.fixture
        fixture.git("checkout", "-q", self.env["CI_COMMIT_BRANCH"])
        fixture.git("commit", "--allow-empty", "-qm", "Feature advanced")
        fixture.git("push", "-q", "origin", "HEAD:refs/heads/" + self.env["CI_COMMIT_BRANCH"])
        for result in (self.snapshot(), self.deploy()):
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("source branch advanced", result.stderr)
        self.assertFalse(self.state().get("applied"))

    def test_older_snapshot_cannot_replace_a_newer_pipeline(self):
        self.prepare_branch()
        self.assertEqual(self.snapshot().returncode, 0)
        result = self.deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.state()
        state["applications"]["devapp-int"]["metadata"]["annotations"]["devapp.delivery/pipeline"] = "85"
        self.state(**state)
        result = self.deploy()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("newer pipeline", result.stderr)
        self.assertEqual(len(self.state()["applied"]), 1)

    def test_missing_or_tampered_snapshot_receipts_never_deploy(self):
        self.prepare_branch()
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertEqual(self.snapshot().returncode, 0)
        fixture = self.fixture
        path = fixture.work / "infra/snapshots/84.json"
        manifest = json.loads(path.read_text())
        manifest["images"]["user-app"]["digest"] = "sha256:" + "f" * 64
        path.write_text(json.dumps(manifest))
        fixture.git("add", "infra/snapshots/84.json")
        fixture.git("commit", "-qm", "Tamper with snapshot receipt")
        fixture.git("push", "-q", "origin", "HEAD:refs/heads/" + self.snapshot_branch)
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertFalse(self.state().get("applied"))


if __name__ == "__main__":
    unittest.main()
