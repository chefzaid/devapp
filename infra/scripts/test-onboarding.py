#!/usr/bin/env python3
"""Exercise the app's declarative onboarding configuration without live services."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = json.loads((ROOT / "infra/onboarding.json").read_text())
APP = CONTRACT["registry"]["path"].split("/")[1]


def command(args, cwd, *, env=None, check=True):
    return subprocess.run(args, cwd=cwd, env=env, check=check, text=True,
                          capture_output=True, timeout=60)


def expand(value, context):
    return re.sub(r"\{\{([A-Z_]+)\}\}", lambda match: context[match[1]], value)


def render_fixture(root, context):
    state_path = root / "infra/onboarding-values.json"
    previous = json.loads(state_path.read_text()).get("bindings", {}) if state_path.exists() else {}
    bindings = {item["from"]: expand(item["to"], context) for item in CONTRACT["replacements"]}
    replacements = {}
    for original, rendered in bindings.items():
        old = previous.get(original, original)
        if old in replacements and replacements[old] != rendered:
            raise AssertionError("Conflicting previous onboarding bindings")
        replacements[old] = rendered
    pattern = re.compile("|".join(re.escape(key) for key in sorted(replacements, key=len, reverse=True)))
    for name in CONTRACT["files"]:
        path = root / name
        path.write_text(pattern.sub(lambda match: replacements[match[0]], path.read_text()))
    state_path.write_text(json.dumps({"version": 1, "context": context, "bindings": bindings}))


def rendered_resources(root, profile="infra/k8s"):
    return list(yaml.safe_load_all(command(["kubectl", "kustomize", profile], root).stdout))


def release_rule(variables):
    for rule in yaml.safe_load((ROOT / ".gitlab-ci.yml").read_text())["01-release"]["rules"]:
        clauses = rule["if"].split(" && ")
        matches = []
        for clause in clauses:
            match = re.fullmatch(r'\$([A-Z_]+) == (?:"([^"]*)"|\$([A-Z_]+))', clause)
            if not match:
                raise AssertionError("Review a changed release rule: " + clause)
            expected = match[2] if match[2] is not None else variables.get(match[3], "")
            matches.append(variables.get(match[1], "") == expected)
        if all(matches):
            return rule.get("when", "on_success")
    return "absent"


class RenderingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix=APP + "-onboarding-render-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        shutil.copytree(ROOT / "infra", self.root / "infra", ignore=shutil.ignore_patterns("__pycache__"))
        for name in CONTRACT["files"]:
            source = ROOT / name
            self.assertTrue(source.is_file(), name)
            self.assertFalse(source.is_symlink(), name)
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        self.context = {
            "PUBLIC_DOMAIN": "example.test", "INTERNAL_DNS_ZONE": "services.test",
            "APP_SUBDOMAIN": "portal", "APP_HOST": "portal.example.test",
            "TLS_SECRET_NAME": "example-test-tls",
            "GITLAB_PROJECT_PATH": "teams/testing/" + APP + "-copy", "GITLAB_PROJECT_ID": "735",
            "GITLAB_PUBLIC_URL": "https://source.example.test",
            "GITLAB_INTERNAL_URL": "http://gitlab.services.test",
            "GITLAB_REPOSITORY_URL": "http://gitlab.services.test/teams/testing/" + APP + "-copy.git",
            "REGISTRY_HOST": "registry.example.test", "REGISTRY_PUSH_HOST": "gitlab-registry.services.test:5050",
            "GITHUB_OWNER": "example-org", "GITHUB_REPOSITORY": APP + "-copy",
            "DEFAULT_BRANCH": "trunk", "KEYCLOAK_REALM": "people",
            "PLATFORM_SECURITY_PROJECT_PATH": "platform/security",
            "SONAR_PROJECT_KEY": "teams:testing:" + APP + "-copy",
        }

    def assert_configuration(self, context):
        resources = rendered_resources(self.root)
        for resource in resources:
            if resource.get("kind") == "Ingress":
                self.assertEqual({rule["host"] for rule in resource["spec"]["rules"]}, {context["APP_HOST"]})
                self.assertEqual(resource["spec"]["tls"][0]["secretName"], context["TLS_SECRET_NAME"])
        expected_prefix = context["REGISTRY_HOST"] + "/" + context["GITLAB_PROJECT_PATH"] + "/"
        for resource in resources:
            if resource.get("kind") == "Deployment":
                for container in resource["spec"]["template"]["spec"]["containers"]:
                    self.assertTrue(container["image"].startswith(expected_prefix), container["image"])
        self.assertIn(CONTRACT["registry"]["path"], json.dumps(resources))
        self.assertIn(context["SONAR_PROJECT_KEY"], (self.root / "sonar-project.properties").read_text())
        workflow = yaml.safe_load((self.root / ".github/workflows/sync-gitlab.yml").read_text())
        env = workflow["jobs"]["sync-repository"]["env"]
        if env.get("GITLAB_REPOSITORY") == "${{ vars.GITLAB_REPOSITORY }}":
            # add-repos installs the generic reconciler; its settings are GitHub Variables.
            self.assertEqual(env["GITLAB_API_URL"], "${{ vars.GITLAB_API_URL }}")
            self.assertEqual(env["GITLAB_HOST"], "${{ vars.GITLAB_HOST }}")
        else:
            self.assertEqual(str(env["GITLAB_PROJECT_ID"]), context["GITLAB_PROJECT_ID"])
            self.assertEqual(env["GITLAB_REPOSITORY"], context["GITLAB_PUBLIC_URL"] + "/" + context["GITLAB_PROJECT_PATH"] + ".git")
        ci = yaml.safe_load((self.root / ".gitlab-ci.yml").read_text())
        self.assertEqual(ci["variables"]["REGISTRY_PUSH_HOST"], context["REGISTRY_PUSH_HOST"])
        self.assertEqual(ci["02-deploy"]["environment"]["url"], "https://" + context["APP_HOST"])
        if "keycloak" in CONTRACT:
            client = json.loads((self.root / CONTRACT["keycloak"]["file"]).read_text())
            self.assertEqual(client["webOrigins"], ["https://" + context["APP_HOST"]])
            self.assertEqual(client["redirectUris"], ["https://" + context["APP_HOST"] + "/*"])
            self.assertEqual(client["clientId"], APP + "-web")
            self.assertEqual(client["attributes"]["pkce.code.challenge.method"], "S256")
            for environment in ("prod", "uat"):
                frontend = self.root / f"devapp-web/src/environments/environment.{environment}.ts"
                self.assertIn("https://keycloak." + context["PUBLIC_DOMAIN"] + "/auth", frontend.read_text())
                self.assertIn("keycloakRealm: '" + context["KEYCLOAK_REALM"] + "'", frontend.read_text())
        else:
            cors = self.root / "indezy-server/src/main/resources/application-kubernetes.yml"
            self.assertIn("https://" + context["APP_HOST"], cors.read_text())
        rendered_resources(self.root, "infra/overlays/ha")

    def test_custom_hosts_project_paths_and_identity_render_together(self):
        render_fixture(self.root, self.context)
        self.assert_configuration(self.context)
        command(["sh", "infra/scripts/set-image-tags.sh", "9.8.7"], self.root)
        for resource in rendered_resources(self.root, "infra/overlays/ha"):
            if resource.get("kind") == "Deployment":
                for container in resource["spec"]["template"]["spec"]["containers"]:
                    self.assertTrue(container["image"].endswith(":9.8.7"), container["image"])
        for script in ("configure-gitlab.sh", "configure-repository-sync.sh", "configure-code-quality.sh"):
            command(["bash", "-n", "infra/scripts/" + script], self.root)

    def test_imported_sync_workflow_uses_github_variables(self):
        path = self.root / ".github/workflows/sync-gitlab.yml"
        workflow = yaml.safe_load(path.read_text())
        env = workflow["jobs"]["sync-repository"]["env"]
        env.pop("GITLAB_PROJECT_ID", None)
        for key in ("GITLAB_REPOSITORY", "GITLAB_API_URL", "GITLAB_HOST"):
            env[key] = "${{ vars." + key + " }}"
        path.write_text(yaml.safe_dump(workflow))
        render_fixture(self.root, self.context)
        self.assert_configuration(self.context)

    def test_rerun_and_apex_to_subdomain_changes_keep_stable_data_identity(self):
        render_fixture(self.root, self.context)
        snapshot = {name: (self.root / name).read_bytes() for name in CONTRACT["files"]}
        render_fixture(self.root, self.context)
        self.assertEqual(snapshot, {name: (self.root / name).read_bytes() for name in CONTRACT["files"]})
        apex = dict(self.context, APP_SUBDOMAIN="@", APP_HOST=self.context["PUBLIC_DOMAIN"])
        render_fixture(self.root, apex)
        self.assert_configuration(apex)
        changed = dict(apex, APP_SUBDOMAIN="renamed", APP_HOST="renamed.example.test")
        render_fixture(self.root, changed)
        self.assert_configuration(changed)
        self.assertEqual(CONTRACT["registry"]["path"], "apps/" + APP + "/registry")


class ReleaseTests(unittest.TestCase):
    def test_publication_commit_marks_only_onboarding_and_supports_same_image(self):
        with tempfile.TemporaryDirectory(prefix="onboarding-commit-test.") as directory:
            work = Path(directory)
            def run(*arguments, environment=None, check=True):
                return subprocess.run(arguments, cwd=work, env=environment, check=check,
                                      text=True, capture_output=True)
            run("git", "init", "-q", "-b", "main")
            run("git", "config", "user.name", "Onboarding test")
            run("git", "config", "user.email", "test@example.invalid")
            run("git", "config", "commit.gpgsign", "false")
            (work / "config").write_text("public settings")
            run("git", "add", ".")
            helper = str(ROOT / "infra/scripts/commit-deployment.sh")
            ordinary = {**os.environ, "APP_ONBOARDING": "false"}
            run("bash", helper, "ordinary deployment", environment=ordinary)
            initial = run("git", "rev-parse", "HEAD").stdout.strip()
            self.assertNotIn("Onboarding-", run("git", "show", "-s", "--format=%B").stdout)
            environment = {**os.environ, "APP_ONBOARDING": "true", "CI_PIPELINE_ID": "73", "CI_COMMIT_SHA": initial}
            # Even an unchanged image gets an identifiable successful publication.
            run("bash", helper, "onboarding deployment", environment=environment)
            published = run("git", "rev-parse", "HEAD").stdout.strip()
            self.assertNotEqual(published, initial)
            trailers = run("git", "show", "-s", "--format=%(trailers)").stdout
            self.assertEqual(trailers.splitlines(), ["Onboarding-Pipeline: 73", "Onboarding-Source: " + initial, ""])
            result = run("bash", helper, "invalid metadata", environment={**environment, "CI_PIPELINE_ID": ""}, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(run("git", "rev-parse", "HEAD").stdout.strip(), published)

    def test_only_explicit_api_onboarding_bypasses_manual_release(self):
        defaults = {"CI_PIPELINE_SOURCE": "api", "CI_COMMIT_BRANCH": "trunk",
                    "CI_DEFAULT_BRANCH": "trunk", "APP_ONBOARDING": "true",
                    "SONAR_SCAN_ONLY": "false", "PIPELINE_MODE": "standard"}
        self.assertEqual(release_rule(defaults), "on_success")
        settings = {**os.environ, **defaults, "CI_COMMIT_MESSAGE": "Configure repository [skip ci]", "CI_OPEN_MERGE_REQUESTS": "1"}
        rules = yaml.safe_load((ROOT / ".gitlab-ci.yml").read_text())["workflow"]["rules"]
        selected = next(rule for rule in rules if subprocess.run(
            ["bash", "-c", "[[ " + rule["if"] + " ]]"], env=settings, capture_output=True).returncode == 0)
        self.assertEqual(selected.get("when", "on_success"), "on_success")
        self.assertEqual(release_rule(dict(defaults, APP_ONBOARDING="false")), "manual")
        self.assertEqual(release_rule(dict(defaults, CI_PIPELINE_SOURCE="push")), "manual")
        self.assertEqual(release_rule(dict(defaults, CI_PIPELINE_SOURCE="web", PIPELINE_MODE="full")), "on_success")
        self.assertEqual(release_rule(dict(defaults, SONAR_SCAN_ONLY="true")), "never")
        self.assertEqual(release_rule(dict(defaults, CI_COMMIT_BRANCH="feature")), "absent")

    def test_revision_guard_rejects_stale_source_before_publication_and_accepts_release_descendant(self):
        with tempfile.TemporaryDirectory(prefix=APP + "-onboarding-git-") as directory:
            root = Path(directory)
            remote, work = root / "remote.git", root / "work"
            command(["git", "init", "--quiet", "--bare", "--initial-branch=main", str(remote)], root)
            command(["git", "clone", "--quiet", str(remote), str(work)], root)
            command(["git", "config", "user.name", "Onboarding test"], work)
            command(["git", "config", "user.email", "test@example.invalid"], work)
            command(["git", "config", "commit.gpgsign", "false"], work)
            (work / "infra/scripts").mkdir(parents=True)
            for name in ("ci-release.sh", "check-onboarding-revision.sh"):
                shutil.copy2(ROOT / "infra/scripts" / name, work / "infra/scripts" / name)
            command(["git", "add", "."], work)
            command(["git", "commit", "--quiet", "-m", "configured app"], work)
            initial = command(["git", "rev-parse", "HEAD"], work).stdout.strip()
            command(["git", "push", "--quiet", "origin", "main"], work)
            env = dict(os.environ, APP_ONBOARDING="true", CI_PIPELINE_SOURCE="api",
                       CI_COMMIT_BRANCH="main", CI_DEFAULT_BRANCH="main", CI_COMMIT_SHA=initial,
                       ONBOARDING_EXPECTED_SHA=initial, SONAR_SCAN_ONLY="false", APP_VERSION="1.0.0")
            guard = ["bash", "infra/scripts/check-onboarding-revision.sh"]
            command(guard + ["build"], work, env=env)
            command(guard + ["publish"], work, env=env)
            missing = dict(env, ONBOARDING_EXPECTED_SHA="")
            self.assertNotEqual(command(guard + ["publish"], work, env=missing, check=False).returncode, 0)
            command(["git", "commit", "--quiet", "--allow-empty", "-m", "release images"], work)
            command(["git", "commit", "--quiet", "--allow-empty", "-m", "next version"], work)
            released = command(["git", "rev-parse", "HEAD"], work).stdout.strip()
            command(["git", "push", "--quiet", "origin", "main"], work)
            command(["git", "checkout", "--quiet", "--detach", initial], work)
            stale = command(["bash", "infra/scripts/ci-release.sh", "publish"], work, env=env, check=False)
            self.assertNotEqual(stale.returncode, 0)
            self.assertIn("moved before publication", stale.stderr)
            self.assertNotIn("KANIKO_EXECUTOR", stale.stderr)
            command(guard + ["deploy"], work, env=dict(env, DEPLOY_REVISION=released))
            self.assertNotEqual(command(guard + ["deploy"], work, env=dict(env, DEPLOY_REVISION=initial), check=False).returncode, 0)
            command(guard + ["publish"], work, env=dict(env, APP_ONBOARDING="false"))


if __name__ == "__main__":
    unittest.main()
