"""Integration coverage using disposable Git repositories and a fake GitHub API.

No remote pushes, Xcode builds, Swift compilation, or real credentials are used.
"""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import shutil
import time
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/sync-upstream.py"
spec = importlib.util.spec_from_file_location("sync_upstream", SCRIPT)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)
CONFIG = json.loads(SCRIPT.with_name("upstream-sync.json").read_text())


def command(path, *args):
    return subprocess.check_output(["git", "-C", str(path), *args], text=True, stderr=subprocess.DEVNULL).strip()


class FakeGitHub:
    def __init__(self, root, config):
        self.root, self.config = root, config
        self.prs = {config[s]["repository"]: [] for s in ("fork", "app")}
        self.releases = [{"tag_name": t, "draft": False, "prerelease": False}
                         for t in ("ver.1.4.1", "ver.1.4.2")]
        self.green = True
        self.green_checks = {}
        self.post_failure = False
        self.posts = 0

    def repo(self, repo):
        return self.root / (repo + ".git")

    def head(self, repo, ref):
        return command(self.repo(repo), "rev-parse", ref)

    def tag_sha(self, repo, tag):
        return command(self.repo(repo), "rev-parse", tag + "^{commit}")

    def content(self, repo, path, ref):
        return command(self.repo(repo), "show", f"{ref}:{path}")

    def pulls(self, repo, base):
        return copy.deepcopy(self.prs[repo])

    def check_passed(self, repo, commit, name):
        return self.green_checks.get(name, self.green)

    def compare(self, repo, base, head):
        path = self.repo(repo)
        if base == head:
            status = "identical"
        else:
            # Ensure the fork can inspect commits from its local upstream network.
            if repo == self.config["fork"]["repository"]:
                command(path, "fetch", str(self.repo(self.config["fork"]["upstreamRepository"])), "master")
            try:
                command(path, "merge-base", "--is-ancestor", head, base)
                status = "behind"
            except subprocess.CalledProcessError:
                try:
                    command(path, "merge-base", "--is-ancestor", base, head)
                    status = "ahead"
                except subprocess.CalledProcessError:
                    status = "diverged"
        files = command(path, "diff", "--name-only", f"{base}...{head}").splitlines()
        return {"status": status, "files": [{"filename": p} for p in files]}

    def api(self, endpoint, method="GET", body=None, paginate=False):
        if "/releases?" in endpoint:
            return self.releases
        if method == "POST" and endpoint.endswith("/pulls"):
            self.posts += 1
            repo = endpoint[len("repos/"):-len("/pulls")]
            pr = {"head": {"ref": body["head"], "sha": self.head(repo, body["head"]), "repo": {"full_name": repo}},
                  "state": "open", "merged_at": None, "body": body["body"],
                  "html_url": "https://example.test/pull/1"}
            self.prs[repo].append(pr)
            if self.post_failure:
                raise sync.SyncError("connection lost after successful POST", 5)
            return pr
        raise AssertionError(endpoint)


class SyncIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sync-tests-")
        self.root = Path(self.temp.name)
        self.config = copy.deepcopy(CONFIG)
        self.env = patch.dict(os.environ, {"OPENCC_SYNC_TEST_REMOTES": str(self.root), "GIT_ALLOW_PROTOCOL": "file:https:http"})
        self.env.start()
        self.github = FakeGitHub(self.root, self.config)
        core = self.init(self.config["fork"]["coreRepository"])
        self.write_commit(core, "data.txt", "old\n")
        command(core, "tag", "ver.1.4.1")
        self.old_core = command(core, "rev-parse", "HEAD")
        self.write_commit(core, "data.txt", "new\n")
        command(core, "tag", "-a", "ver.1.4.2", "-m", "stable release")
        self.new_core = command(core, "rev-parse", "HEAD")
        upstream = self.init(self.config["fork"]["upstreamRepository"])
        self.write_commit(upstream, "wrapper.swift", "initial\n")
        fork = self.github.repo(self.config["fork"]["repository"])
        fork.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", str(upstream), str(fork)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.identity(fork)
        command(fork, "submodule", "add", str(core), "OpenCC")
        command(fork / "OpenCC", "checkout", self.old_core)
        manifest = fork / self.config["fork"]["manifest"]
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"schemaVersion": 1, "bridgeVersion": 1,
                                       "opencc": {"tag": "ver.1.4.1", "revision": self.old_core}}))
        command(fork, "add", ".")
        command(fork, "commit", "-m", "fork baseline")
        self.fork = fork
        self.old_fork = command(fork, "rev-parse", "HEAD")
        app = self.init(self.config["app"]["repository"], "build")
        project = app / self.config["app"]["project"] / "project.pbxproj"
        project.parent.mkdir(parents=True)
        project.write_text('repositoryURL = "https://github.com/gewill/SwiftyOpenCC";\nrequirement = {\nbranch = master;\nkind = branch;\n};\n')
        lock = app / self.config["app"]["resolved"]
        lock.parent.mkdir(parents=True)
        lock.write_text(json.dumps({"version": 3, "originHash": "old-hash", "pins": [
            {"identity": "swiftyopencc", "state": {"branch": "master", "revision": self.old_fork}},
            {"identity": "another-dependency", "state": {"version": "1.0.0", "revision": "1" * 40}}]}))
        command(app, "add", ".")
        command(app, "commit", "-m", "app baseline")
        self.app = app

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def identity(self, path):
        command(path, "config", "user.name", "Fixture")
        command(path, "config", "user.email", "fixture@example.test")

    def init(self, repo, branch="master"):
        path = self.github.repo(repo)
        path.mkdir(parents=True)
        command(path, "init", "-b", branch)
        self.identity(path)
        return path

    def write_commit(self, path, name, text):
        target = path / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        command(path, "add", ".")
        command(path, "commit", "-m", "fixture change")

    def validator(self, config, data, path):
        # Simulates the independent generator/compiler boundary; the Git merge,
        # clone, submodule checkout, lockfile edit, bundle and publish are real.
        if data["stage"] == "fork":
            manifest = path / config["fork"]["manifest"]
            value = json.loads(manifest.read_text())
            value["opencc"] = {"tag": data["core_tag"], "revision": data["core_sha"]}
            manifest.write_text(json.dumps(value))
            cli_report = path / ".build/official-cli-report.json"
            cli_report.parent.mkdir(exist_ok=True)
            cli_report.write_text(json.dumps({"status": "passed", "opencc": value["opencc"]}))
            # Production .build is ignored; keep fixture artifacts untracked too.
            (path / ".git/info/exclude").write_text(".build/\n")
        else:
            lock = path / config["app"]["resolved"]
            value = json.loads(lock.read_text())
            value["originHash"] = "resolver-updated"
            lock.write_text(json.dumps(value))

    def prepare(self, stage="fork"):
        output = self.root / f"artifacts-{stage}"
        with patch.object(sync, "validate_candidate", side_effect=self.validator):
            data = sync.prepare(self.config, stage, self.github, output)
        return data, output

    def accept_core(self):
        command(self.fork / "OpenCC", "checkout", self.new_core)
        manifest = self.fork / self.config["fork"]["manifest"]
        data = json.loads(manifest.read_text())
        data["opencc"] = {"tag": "ver.1.4.2", "revision": self.new_core}
        self.write_commit(self.fork, self.config["fork"]["manifest"], json.dumps(data))

    def pull(self, stage, candidate, state="open", merged=False):
        return {"head": {"ref": f"codex/sync-{stage}-{candidate}", "sha": "f" * 40,
                         "repo": {"full_name": self.config[stage]["repository"]}},
                "state": state, "merged_at": "today" if merged else None,
                "body": f"{sync.MARKER}{stage} {candidate} -->", "html_url": "https://example.test/pull/1"}

    def test_prepare_and_publish_bundle_preserve_base_and_retry_without_duplicate(self):
        base = command(self.fork, "rev-parse", "master")
        data, output = self.prepare()
        self.assertEqual(command(self.fork, "rev-parse", "master"), base)
        self.assertTrue((output / "diff.patch").exists())
        first = sync.publish(self.config, "fork", self.github, output)
        second = sync.publish(self.config, "fork", self.github, output)
        self.assertEqual(first["pr_url"], second["pr_url"])
        self.assertEqual(second["status"], "waiting")
        self.assertEqual(self.github.posts, 1)
        self.assertEqual(command(self.fork, "rev-parse", "master"), base)
        self.assertEqual(command(self.fork, "rev-parse", data["branch"]), data["head_sha"])

    def test_uncertain_post_is_reconciled(self):
        _, output = self.prepare()
        self.github.post_failure = True
        result = sync.publish(self.config, "fork", self.github, output)
        self.assertEqual(result["pr_url"], "https://example.test/pull/1")
        self.assertEqual(self.github.posts, 1)

    def test_reprepare_recovers_identical_commit_after_push_without_pr(self):
        first, output = self.prepare()
        with patch.object(self.github, "api", side_effect=sync.SyncError("POST unavailable", 5)):
            with self.assertRaises(sync.SyncError):
                sync.publish(self.config, "fork", self.github, output)
        self.assertEqual(self.github.head(self.config["fork"]["repository"], first["branch"]), first["head_sha"])
        time.sleep(1.05)  # Proves wall-clock commit time cannot change the retry SHA.
        retry = self.root / "retry-artifacts"
        with patch.object(sync, "validate_candidate", side_effect=self.validator):
            second = sync.prepare(self.config, "fork", self.github, retry)
        self.assertEqual(first["head_sha"], second["head_sha"])
        self.assertEqual(sync.publish(self.config, "fork", self.github, retry)["status"], "changed")

    def test_noop_and_ignored_candidate(self):
        state = sync.discover(self.config, "fork", self.github)
        self.config["ignoredCandidates"]["fork"].append(state["candidate"])
        self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "noop")
        self.accept_core()
        self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "noop")

    def test_pr_wait_and_human_rejection(self):
        candidate = sync.discover(self.config, "fork", self.github)["candidate"]
        repo = self.config["fork"]["repository"]
        for state in ("open", "closed"):
            self.github.prs[repo] = [self.pull("fork", candidate, state)]
            self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "waiting")

    def test_move_downgrade_major_and_prerelease_policies(self):
        core = self.github.repo(self.config["fork"]["coreRepository"])
        command(core, "tag", "-f", "ver.1.4.1", self.new_core)
        with self.assertRaisesRegex(sync.SyncError, "tag moved"):
            sync.discover(self.config, "fork", self.github)
        command(core, "tag", "-f", "ver.1.4.1", self.old_core)
        self.github.releases = [{"tag_name": "ver.1.4.0", "draft": False, "prerelease": False}]
        with self.assertRaisesRegex(sync.SyncError, "downgrade"):
            sync.discover(self.config, "fork", self.github)
        self.github.releases[0]["tag_name"] = "ver.2.0.0"
        with self.assertRaisesRegex(sync.SyncError, "Major"):
            sync.discover(self.config, "fork", self.github)
        self.github.releases += [{"tag_name": "ver.1.4.2", "draft": False, "prerelease": False}]
        self.github.releases[0]["prerelease"] = True
        self.assertEqual(sync.discover(self.config, "fork", self.github)["core_tag"], "ver.1.4.2")

    def test_workflow_change_blocked(self):
        upstream = self.github.repo(self.config["fork"]["upstreamRepository"])
        self.write_commit(upstream, ".github/workflows/new.yml", "name: incoming\n")
        with self.assertRaisesRegex(sync.SyncError, "workflow"):
            sync.discover(self.config, "fork", self.github)

    def test_merge_conflict_does_not_publish(self):
        upstream = self.github.repo(self.config["fork"]["upstreamRepository"])
        self.write_commit(upstream, "wrapper.swift", "upstream incompatible\n")
        self.write_commit(self.fork, "wrapper.swift", "local patch\n")
        with self.assertRaises(sync.SyncError) as context:
            self.prepare()
        self.assertEqual(context.exception.code, 3)
        self.assertEqual(context.exception.details["conflicts"], ["wrapper.swift"])
        self.assertEqual(self.github.posts, 0)

    def test_base_change_and_changed_bot_branch_block_publication(self):
        data, output = self.prepare()
        self.write_commit(self.fork, "after.swift", "human change\n")
        with self.assertRaisesRegex(sync.SyncError, "base changed"):
            sync.publish(self.config, "fork", self.github, output)
        command(self.fork, "reset", "--hard", data["base_sha"])
        command(self.fork, "branch", data["branch"], data["base_sha"])
        with self.assertRaisesRegex(sync.SyncError, "force-push"):
            sync.publish(self.config, "fork", self.github, output)

    def test_corrupt_bundle_is_rejected(self):
        _, output = self.prepare()
        with (output / "candidate.bundle").open("ab") as stream:
            stream.write(b"corruption")
        with self.assertRaisesRegex(sync.SyncError, "checksum"):
            sync.publish(self.config, "fork", self.github, output)

    def test_failed_validation_creates_no_publishable_bundle(self):
        output = self.root / "failed"
        with patch.object(sync, "validate_candidate", side_effect=sync.SyncError("fixture test failed", 4)):
            with self.assertRaises(sync.SyncError) as context:
                sync.prepare(self.config, "fork", self.github, output)
        self.assertEqual(context.exception.code, 4)
        self.assertFalse((output / "candidate.bundle").exists())
        self.assertTrue((output / "failure.json").exists())
        self.assertTrue((output / "prepare.log").exists())
        self.assertTrue((output / "diff.patch").exists())

    def test_external_fork_same_named_pr_does_not_block(self):
        candidate = sync.discover(self.config, "fork", self.github)["candidate"]
        pr = self.pull("fork", candidate)
        pr["head"]["repo"]["full_name"] = "other/SwiftyOpenCC"
        self.github.prs[self.config["fork"]["repository"]] = [pr]
        self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "changed")

    def test_app_waits_for_fork_and_exact_sha_check_then_updates_only_pin(self):
        self.assertEqual(sync.discover(self.config, "app", self.github)["status"], "waiting")
        self.accept_core()
        self.github.green = False
        self.assertEqual(sync.discover(self.config, "app", self.github)["status"], "waiting")
        self.github.green = True
        data, output = self.prepare("app")
        result = sync.publish(self.config, "app", self.github, output)
        self.assertEqual(result["status"], "changed")
        lock = json.loads(command(self.app, "show", f"{data['head_sha']}:{self.config['app']['resolved']}"))
        self.assertEqual(sync.get_pin(lock)["state"], {"revision": data["fork_sha"]})
        self.assertEqual(lock["pins"][1]["state"]["version"], "1.0.0")

    def test_other_dependency_drift_is_rejected(self):
        self.accept_core()
        def drift(config, data, path):
            self.validator(config, data, path)
            lock = path / config["app"]["resolved"]
            value = json.loads(lock.read_text())
            value["pins"][1]["state"]["version"] = "2.0.0"
            lock.write_text(json.dumps(value))
        with patch.object(sync, "validate_candidate", side_effect=drift):
            with self.assertRaisesRegex(sync.SyncError, "dependency drift"):
                sync.prepare(self.config, "app", self.github, self.root / "drift")

    def test_app_base_ci_must_pass_before_preparation_and_publication(self):
        self.accept_core()
        self.github.green_checks["App Regression"] = False
        state = sync.discover(self.config, "app", self.github)
        self.assertEqual(state["status"], "waiting")
        self.assertIn("App Regression", state["reason"])
        self.github.green_checks["App Regression"] = True
        _, output = self.prepare("app")
        self.github.green_checks["App Regression"] = False
        with self.assertRaisesRegex(sync.SyncError, "App base regression"):
            sync.publish(self.config, "app", self.github, output)
        self.assertEqual(self.github.posts, 0)

    def test_expected_discovery_detects_races(self):
        expected = sync.discover(self.config, "fork", self.github)
        self.write_commit(self.fork, "new.swift", "human\n")
        with self.assertRaisesRegex(sync.SyncError, "changed since detection"):
            sync.prepare(self.config, "fork", self.github, self.root / "race", expected)

    def test_cli_fake_gh_returns_json_and_network_exit_code(self):
        binary = self.root / "bin"
        binary.mkdir()
        fake = binary / "gh"
        fake.write_text('#!/bin/sh\nprintf "%s\\n" "fixture network failure" >&2\nexit 1\n')
        fake.chmod(0o755)
        env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(["python3", str(SCRIPT), "check", "--stage", "fork"], env=env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 5)
        self.assertEqual(json.loads(result.stdout)["status"], "error")

    def test_manifest_network_failure_is_not_misreported_as_missing_migration(self):
        with patch.object(self.github, "content", side_effect=sync.SyncError("network timeout", 5)):
            with self.assertRaises(sync.SyncError) as context:
                sync.discover(self.config, "fork", self.github)
        self.assertEqual(context.exception.code, 5)
        self.assertIn("network timeout", str(context.exception))

    def test_bare_prepare_returns_persistent_artifact_path(self):
        stdout = io.StringIO()
        with patch.object(sync, "GitHub", return_value=self.github), patch.object(sync, "validate_candidate", side_effect=self.validator):
            with patch("sys.stdout", stdout):
                code = sync.main(["prepare", "--stage", "fork"])
        data = json.loads(stdout.getvalue())
        try:
            self.assertEqual(code, 0)
            self.assertTrue((Path(data["artifact_directory"]) / "candidate.bundle").exists())
        finally:
            shutil.rmtree(data["artifact_directory"])

    def test_bare_local_pr_prepares_and_publishes_but_ci_requires_artifact(self):
        stdout = io.StringIO()
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
            with patch.object(sync, "GitHub", return_value=self.github), patch.object(sync, "validate_candidate", side_effect=self.validator):
                with patch("sys.stdout", stdout):
                    code = sync.main(["pr", "--stage", "fork"])
        data = json.loads(stdout.getvalue())
        try:
            self.assertEqual(code, 0)
            self.assertEqual(self.github.posts, 1)
        finally:
            shutil.rmtree(data["artifact_directory"])
        stdout = io.StringIO()
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), patch("sys.stdout", stdout):
            code = sync.main(["pr", "--stage", "fork"])
        self.assertEqual(code, 2)
        self.assertIn("must never build", json.loads(stdout.getvalue())["reason"])

    def test_latest_exact_commit_check_must_be_green(self):
        github = sync.GitHub()
        commit = "a" * 40
        checks = {"check_runs": [
            {"name": "OpenCC Compatibility", "app": {"slug": "github-actions"},
             "head_sha": commit, "status": "completed", "conclusion": "success", "id": 1},
            {"name": "OpenCC Compatibility", "app": {"slug": "github-actions"},
             "head_sha": commit, "status": "completed", "conclusion": "failure", "id": 2}]}
        with patch.object(github, "api", return_value=checks):
            self.assertFalse(github.check_passed("fixture/repo", commit, "OpenCC Compatibility"))
        checks["check_runs"][1]["head_sha"] = "b" * 40
        with patch.object(github, "api", return_value=checks):
            self.assertTrue(github.check_passed("fixture/repo", commit, "OpenCC Compatibility"))

    def test_git_credential_protocol_accepts_github_token_or_persistent_gh_login(self):
        binary = self.root / "credential-bin"
        binary.mkdir()
        fake = binary / "gh"
        fake.write_text('#!/usr/bin/env python3\nimport os,sys\n'
                        'assert sys.argv[1:] == ["auth", "git-credential", "get"]\n'
                        'print("username=x-access-token")\n'
                        'print("password=" + os.environ.get("GITHUB_TOKEN", "fixture-persistent-login"))\n')
        fake.chmod(0o755)
        for token in ("fixture-github-token", None):
            env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"])
            env.pop("GH_TOKEN", None)
            env.pop("GITHUB_TOKEN", None)
            if token:
                env["GITHUB_TOKEN"] = token
            result = subprocess.run(["git", "-c", "credential.helper=", "-c",
                                     "credential.helper=!gh auth git-credential", "credential", "fill"],
                                    input="protocol=https\nhost=github.com\n\n", text=True,
                                    capture_output=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("password=" + (token or "fixture-persistent-login"), result.stdout)

    def test_public_get_uses_read_auth_while_post_retains_write_auth(self):
        binary = self.root / "api-bin"
        binary.mkdir()
        fake = binary / "gh"
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
assert args[0] == 'api'
assert args[args.index('--hostname') + 1] == 'github.com'
method = args[args.index('--method') + 1]
expected = 'fixture-reader' if method == 'GET' else 'fixture-writer'
assert os.environ['GH_TOKEN'] == expected
if '--paginate' in args:
    assert '--slurp' in args
    print(json.dumps([[{'page': 1}], [{'page': 2}]]))
else:
    if method == 'POST':
        with open(args[args.index('--input') + 1]) as stream:
            assert json.load(stream)['body'] == 'literal\\nbody'
    print(json.dumps({'method': method}))
''')
        fake.chmod(0o755)
        env = {"PATH": str(binary) + os.pathsep + os.environ["PATH"],
               "GH_READ_TOKEN": "fixture-reader", "GH_TOKEN": "fixture-writer", "GH_HOST": "outside.test"}
        github = sync.GitHub()
        with patch.dict(os.environ, env):
            self.assertEqual(github.api("repos/other/public/check-runs")["method"], "GET")
            self.assertEqual(github.api("repos/other/public/releases", paginate=True), [{"page": 1}, {"page": 2}])
            self.assertEqual(github.api("repos/target/public/pulls", "POST", {"body": "literal\nbody"})["method"], "POST")

    def test_authenticated_rate_limit_is_an_error_without_anonymous_fallback(self):
        binary = self.root / "rate-limit-bin"
        binary.mkdir()
        calls = self.root / "api-calls"
        fake = binary / "gh"
        fake.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
assert os.environ['GH_TOKEN'] == 'fixture-reader'
with pathlib.Path(os.environ['FIXTURE_CALLS']).open('a') as stream:
    stream.write('request\\n')
print('gh: API rate limit exceeded (HTTP 403)', file=sys.stderr)
raise SystemExit(1)
''')
        fake.chmod(0o755)
        with patch.dict(os.environ, {"PATH": str(binary) + os.pathsep + os.environ["PATH"],
                                     "GH_READ_TOKEN": "fixture-reader", "FIXTURE_CALLS": str(calls)}):
            with self.assertRaises(sync.SyncError) as context:
                sync.GitHub().check_passed("other/public", "a" * 40, "Example Check")
        self.assertEqual(context.exception.code, 5)
        self.assertIn("HTTP 403", str(context.exception))
        self.assertEqual(calls.read_text(), "request\n")

    def test_absolute_or_traversing_api_endpoints_are_rejected_before_gh(self):
        for endpoint in ("https://outside.test/repos/owner/repo/pulls", "//outside.test/repos/owner/repo/pulls",
                         "repos/owner/repo/../../outside", "repos/owner/repo/pulls\nInjected"):
            with patch.object(sync, "run") as process:
                with self.assertRaises(sync.SyncError):
                    sync.GitHub().api(endpoint)
            process.assert_not_called()

    def test_read_token_is_redacted_from_command_logs(self):
        start = len(sync.RUN_LOG)
        with patch.dict(os.environ, {"GH_READ_TOKEN": "fixture-reader-secret"}):
            sync.run(["python3", "-c", "import os; print(os.environ['GH_READ_TOKEN'])"])
        self.assertNotIn("fixture-reader-secret", "\n".join(sync.RUN_LOG[start:]))
        self.assertIn("[REDACTED]", "\n".join(sync.RUN_LOG[start:]))

    def test_merge_promotion_and_rollback_ignore_candidates_without_rewriting_history(self):
        fork_data, fork_artifact = self.prepare("fork")
        sync.publish(self.config, "fork", self.github, fork_artifact)
        command(self.fork, "merge", "--no-ff", fork_data["branch"], "-m", "Review and merge fork PR")
        accepted = command(self.fork, "rev-parse", "HEAD")
        fork_pr = self.github.prs[self.config["fork"]["repository"]][0]
        fork_pr.update(state="closed", merged_at="fixture-merged")
        self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "noop")
        app_data, app_artifact = self.prepare("app")
        sync.publish(self.config, "app", self.github, app_artifact)
        command(self.app, "merge", "--no-ff", app_data["branch"], "-m", "Review and merge app PR")
        promoted = command(self.app, "rev-parse", "HEAD")
        app_pr = self.github.prs[self.config["app"]["repository"]][0]
        app_pr.update(state="closed", merged_at="fixture-merged")
        self.assertEqual(sync.discover(self.config, "app", self.github)["status"], "noop")

        # Roll back through a new commit, preserving the promoted history.
        lock = self.app / self.config["app"]["resolved"]
        pins = json.loads(lock.read_text())
        sync.get_pin(pins)["state"] = {"revision": self.old_fork}
        lock.write_text(json.dumps(pins))
        project = self.app / self.config["app"]["project"] / "project.pbxproj"
        project.write_text(sync.pin_project(project.read_text(), self.old_fork))
        command(self.app, "add", ".")
        command(self.app, "commit", "-m", "Restore prior app revision")
        self.config["ignoredCandidates"]["app"].append(app_data["candidate"])
        ignored = sync.discover(self.config, "app", self.github)
        self.assertEqual(ignored["status"], "noop")
        self.assertIn("ignored", ignored["reason"])
        command(self.app, "merge-base", "--is-ancestor", promoted, "HEAD")

        # Revert the complete fork merge without deleting its ancestry.
        command(self.fork, "revert", "--mainline", "1", "--no-edit", accepted)
        command(self.fork, "merge-base", "--is-ancestor", accepted, "HEAD")
        manifest = json.loads((self.fork / self.config["fork"]["manifest"]).read_text())
        self.assertEqual(manifest["opencc"]["revision"], self.old_core)
        self.config["ignoredCandidates"]["fork"].append(fork_data["candidate"])
        ignored = sync.discover(self.config, "fork", self.github)
        self.assertEqual(ignored["status"], "noop")
        self.assertIn("ignored", ignored["reason"])

        # A genuinely new source remains eligible; the old rejection is scoped.
        upstream = self.github.repo(self.config["fork"]["upstreamRepository"])
        self.write_commit(upstream, "wrapper.swift", "new reviewed upstream change\n")
        self.assertEqual(sync.discover(self.config, "fork", self.github)["status"], "changed")

    def test_fork_requires_cli_report_for_selected_core(self):
        for state in ("missing", "wrong-source", "failed", "malformed", "list"):
            output = self.root / ("cli-failure-" + state)
            def validator(config, data, path):
                self.validator(config, data, path)
                report = path / ".build/official-cli-report.json"
                if state == "missing":
                    report.unlink()
                elif state == "wrong-source":
                    report.write_text(json.dumps({"status": "passed", "opencc": {"tag": "ver.1.4.1", "revision": self.old_core}}))
                elif state == "failed":
                    report.write_text(json.dumps({"status": "failed", "opencc": {"tag": data["core_tag"], "revision": data["core_sha"]}}))
                else:
                    report.write_text("[]" if state == "list" else "{broken")
            with patch.object(sync, "validate_candidate", side_effect=validator):
                with self.assertRaises(sync.SyncError) as failure:
                    sync.prepare(self.config, "fork", self.github, output)
            self.assertEqual(failure.exception.code, 4)
            self.assertTrue((output / "failure.json").exists())
            self.assertFalse((output / "candidate.bundle").exists())
            self.assertEqual((output / "official-cli-report.json").exists(), state != "missing")

    def test_validation_subprocesses_receive_no_tokens(self):
        commands = []
        with patch.dict(os.environ, {"GH_READ_TOKEN": "fixture-reader", "GH_TOKEN": "fixture-secret", "GITHUB_TOKEN": "fixture-secret"}):
            with patch.object(sync, "run", side_effect=lambda args, **kwargs: commands.append(kwargs["env"])):
                sync.validate_candidate(self.config, {"stage": "fork"}, self.root)
        self.assertEqual(len(commands), 4)
        self.assertTrue(all("GH_READ_TOKEN" not in e and "GH_TOKEN" not in e and "GITHUB_TOKEN" not in e for e in commands))


if __name__ == "__main__":
    unittest.main()
