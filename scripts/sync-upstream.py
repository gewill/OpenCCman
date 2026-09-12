#!/usr/bin/env python3
"""Review-only OpenCC dependency updates. Never merges PRs or force-pushes.

check reads remote state; prepare builds an isolated candidate. pr --prepared
publishes a validated bundle; the local pr shortcut prepares one first.
"""
import argparse
import base64
import copy
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import quote
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

SHA = re.compile(r"^[0-9a-f]{40}$")
TAG = re.compile(r"^ver\.(\d+)\.(\d+)\.(\d+)$")
MARKER = "<!-- opencc-sync:v1 "
RUN_LOG = []


class SyncError(Exception):
    def __init__(self, message, code=3, **details):
        super().__init__(message)
        self.code, self.details = code, details


def run(args, cwd=None, env=None, code=4):
    result = subprocess.run(args, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    logged = f"$ {Path(args[0]).name}\n{result.stdout}\n{result.stderr}\n"
    for key in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
        secret = (env or os.environ).get(key)
        if secret:
            logged = logged.replace(secret, "[REDACTED]")
    RUN_LOG.append(logged)
    if result.returncode:
        # Never include environment values or credential-bearing commands.
        detail = (result.stdout + "\n" + result.stderr).strip()[-6000:]
        raise SyncError(f"{Path(args[0]).name} failed: {detail}", code)
    if result.stderr:
        print(result.stderr.rstrip(), file=sys.stderr)
    return result.stdout.strip()


def git(path, *args, **kwargs):
    return run(["git", "-C", str(path), *args], **kwargs)


def sha(value):
    if not isinstance(value, str) or not SHA.fullmatch(value):
        raise SyncError("Invalid full commit SHA", 2)
    return value


def version(tag):
    match = TAG.fullmatch(tag)
    if not match:
        raise SyncError(f"Not a stable OpenCC tag: {tag}")
    return tuple(map(int, match.groups()))


class GitHub:
    def public_api(self, endpoint, paginate=False):
        """Read public sources without widening a publishing token's scope."""
        url = "https://api.github.com/" + endpoint
        pages = []
        while url:
            if not url.startswith("https://api.github.com/"):
                raise SyncError("Unexpected public API pagination host", 5)
            request = Request(url, headers={"Accept": "application/vnd.github+json",
                                           "User-Agent": "opencc-upstream-sync"})
            try:
                with urlopen(request, timeout=30) as response:
                    value = json.load(response)
                    link = response.headers.get("Link", "")
            except (HTTPError, URLError) as error:
                raise SyncError(f"Public GitHub read failed: {error}", 5) from error
            if not paginate:
                return value
            pages.extend(value)
            next_link = re.search(r'<([^>]+)>; rel="next"', link)
            url = next_link[1] if next_link else None
        return pages

    def api(self, endpoint, method="GET", body=None, paginate=False):
        # A publish token is deliberately scoped to only its write destination.
        # Other public repositories remain readable without granting it access.
        destination = os.environ.get("OPENCC_SYNC_WRITE_REPOSITORY")
        if method == "GET" and destination and not endpoint.startswith(f"repos/{destination}/"):
            return self.public_api(endpoint, paginate)
        args = ["gh", "api", endpoint, "--method", method]
        if paginate:
            args += ["--paginate", "--slurp"]
        if body is None:
            raw = run(args, code=5)
        else:
            # gh --input consumes a file, preserving literal text/newlines.
            with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as stream:
                json.dump(body, stream)
                stream.flush()
                raw = run(args + ["--input", stream.name], code=5)
        result = json.loads(raw) if raw else None
        return [item for page in result for item in page] if paginate else result

    def head(self, repo, ref):
        return sha(self.api(f"repos/{repo}/commits/{quote(ref, safe='')}")["sha"])

    def content(self, repo, path, ref):
        data = self.api(f"repos/{repo}/contents/{quote(path)}?ref={quote(ref, safe='')}")
        if "content" not in data or data.get("encoding") != "base64":
            raise SyncError(f"Cannot read {repo}/{path}", 2)
        return base64.b64decode(data["content"]).decode()

    def pulls(self, repo, base):
        return self.api(f"repos/{repo}/pulls?state=all&base={quote(base)}&per_page=100", paginate=True)

    def tag_sha(self, repo, tag):
        obj = self.api(f"repos/{repo}/git/ref/tags/{quote(tag, safe='')}")["object"]
        for _ in range(8):
            if obj["type"] == "commit":
                return sha(obj["sha"])
            if obj["type"] != "tag":
                break
            obj = self.api(f"repos/{repo}/git/tags/{sha(obj['sha'])}")["object"]
        raise SyncError(f"Tag does not resolve to a commit: {tag}")

    def compare(self, repo, base, head):
        return self.api(f"repos/{repo}/compare/{sha(base)}...{sha(head)}")

    def check_passed(self, repo, commit, name):
        # Latest run of the named check wins; never accept an older green retry.
        # Public checks need no token; the sync App does not need Checks:read.
        pages = self.public_api(f"repos/{repo}/commits/{sha(commit)}/check-runs?filter=latest&per_page=100")
        checks = [c for c in pages["check_runs"] if c["name"] == name
                  and c.get("app", {}).get("slug") == "github-actions"
                  and c.get("head_sha") == commit]
        if not checks:
            return False
        latest = max(checks, key=lambda c: c["id"])
        return latest["status"] == "completed" and latest["conclusion"] == "success"


def candidate_id(stage, values):
    return hashlib.sha256(json.dumps([stage, *values], separators=(",", ":")).encode()).hexdigest()[:20]


def owned_pull(pr, stage, repo):
    head = pr.get("head", {})
    return (head.get("repo", {}).get("full_name") == repo
            and head.get("ref", "").startswith(f"codex/sync-{stage}-")
            and MARKER in (pr.get("body") or ""))


def pull_gate(pulls, stage, repo, candidate=None):
    pulls = [p for p in pulls if p.get("head", {}).get("repo", {}).get("full_name") == repo]
    pending = [p for p in pulls if owned_pull(p, stage, repo) and p["state"] == "open"]
    if pending:
        return {"status": "waiting", "reason": "An update already awaits human review",
                "pr_url": pending[0]["html_url"]}
    if candidate:
        branch = f"codex/sync-{stage}-{candidate}"
        rejected = [p for p in pulls if p["head"]["ref"] == branch
                    and p["state"] == "closed" and not p.get("merged_at")]
        if rejected:
            return {"status": "waiting", "reason": "This candidate was closed without merging; reopen it manually to retry",
                    "pr_url": rejected[0]["html_url"]}
    return None


def discover(config, stage, github):
    cfg = config[stage]
    result = {"schemaVersion": 1, "stage": stage, "repository": cfg["repository"], "base": cfg["base"]}
    pulls = github.pulls(cfg["repository"], cfg["base"])
    gate = pull_gate(pulls, stage, cfg["repository"])
    if gate:
        return {**result, **gate}
    base = github.head(cfg["repository"], cfg["base"])
    result["base_sha"] = base
    fork = config["fork"]
    if stage == "fork":
        try:
            manifest = json.loads(github.content(cfg["repository"], cfg["manifest"], base))
        except SyncError as error:
            if "HTTP 404" in str(error):
                raise SyncError("First merge the official SimpleConverter migration and resource manifest", 2) from error
            raise
        except ValueError as error:
            raise SyncError("The accepted resource manifest is not valid JSON", 2) from error
        if manifest.get("schemaVersion") != 1 or manifest.get("bridgeVersion") != 1:
            raise SyncError("Unsupported bridge/manifest version; manual adapter review required", 2)
        current = manifest["opencc"]
        current_sha, current_tag = sha(current["revision"]), current["tag"]
        if github.tag_sha(cfg["coreRepository"], current_tag) != current_sha:
            raise SyncError(f"Previously accepted tag moved: {current_tag}")
        releases = github.api(f"repos/{cfg['coreRepository']}/releases?per_page=100", paginate=True)
        stable = [r for r in releases if not r["draft"] and not r["prerelease"] and TAG.fullmatch(r["tag_name"])]
        if not stable:
            raise SyncError("No published stable OpenCC release found")
        target_tag = max(stable, key=lambda r: version(r["tag_name"]))["tag_name"]
        old_version, new_version = version(current_tag), version(target_tag)
        if new_version < old_version:
            raise SyncError("Refusing an OpenCC downgrade")
        if new_version[0] != old_version[0]:
            raise SyncError("Major OpenCC upgrades require a manual compatibility migration")
        target_sha = github.tag_sha(cfg["coreRepository"], target_tag)
        upstream = github.head(cfg["upstreamRepository"], cfg["upstreamBase"])
        comparison = github.compare(cfg["repository"], base, upstream)
        incoming = comparison["status"] not in ("identical", "behind")
        if incoming and any(f["filename"].startswith(".github/workflows/")
                            or f.get("previous_filename", "").startswith(".github/workflows/")
                            for f in comparison.get("files", [])):
            raise SyncError("Upstream changes workflow files; review and merge those manually")
        if not incoming and target_sha == current_sha:
            return {**result, "status": "noop", "reason": "Wrapper and OpenCC are current"}
        result.update(upstream_sha=upstream, old_core_sha=current_sha, core_sha=target_sha,
                      old_core_tag=current_tag, core_tag=target_tag, incoming_wrapper=incoming)
        candidate = candidate_id(stage, [upstream, target_sha])
    else:
        fork_state = discover(config, "fork", github)
        if fork_state["status"] != "noop":
            return {**result, "status": "waiting", "reason": "Finish the fork update before promoting it to the app",
                    "fork_status": fork_state["status"], "pr_url": fork_state.get("pr_url")}
        target_sha = github.head(fork["repository"], fork["base"])
        pins = json.loads(github.content(cfg["repository"], cfg["resolved"], base))
        pin = get_pin(pins)
        old_sha = sha(pin["state"]["revision"])
        if old_sha == target_sha:
            return {**result, "status": "noop", "reason": "App already pins the accepted fork revision"}
        if not github.check_passed(fork["repository"], target_sha, fork["requiredCheck"]):
            return {**result, "status": "waiting", "reason": "Fork master needs a passing OpenCC Compatibility check",
                    "fork_sha": target_sha}
        if not github.check_passed(cfg["repository"], base, cfg["requiredCheck"]):
            return {**result, "status": "waiting", "reason": "App build needs a passing App Regression check before a pin upgrade",
                    "fork_sha": target_sha}
        comparison = github.compare(fork["repository"], old_sha, target_sha)
        if comparison["status"] != "ahead":
            raise SyncError("Fork history diverged or moved backwards; review the app pin manually")
        result.update(old_fork_sha=old_sha, fork_sha=target_sha)
        candidate = candidate_id(stage, [target_sha])
    result.update(candidate=candidate, branch=f"codex/sync-{stage}-{candidate}")
    if candidate in config["ignoredCandidates"][stage]:
        return {**result, "status": "noop", "reason": "Candidate explicitly ignored in reviewed configuration"}
    gate = pull_gate(pulls, stage, cfg["repository"], candidate)
    return {**result, **(gate or {"status": "changed"})}


def get_pin(resolved):
    pins = [p for p in resolved["pins"] if p["identity"] == "swiftyopencc"]
    if len(pins) != 1:
        raise SyncError("Expected exactly one SwiftyOpenCC pin", 2)
    return pins[0]


def pin_project(text, revision):
    pattern = re.compile(r'(repositoryURL = "https://github\.com/gewill/SwiftyOpenCC(?:\.git)?";\s*requirement = \{)(.*?)(\n\s*\};)', re.S)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise SyncError("Expected exactly one SwiftyOpenCC project requirement", 2)
    return pattern.sub(lambda m: m[1] + f"\n\t\t\t\tkind = revision;\n\t\t\t\trevision = {sha(revision)};" + m[3], text)


def remote(repo):
    # Fixture transport for hermetic integration tests; unset in Actions.
    fixture = os.environ.get("OPENCC_SYNC_TEST_REMOTES")
    return str(Path(fixture) / (repo + ".git")) if fixture else f"https://github.com/{repo}.git"


def clone(repo, ref, path):
    run(["git", "clone", "--no-checkout", "--branch", ref, remote(repo), str(path)], code=5)
    git(path, "config", "user.name", "OpenCC Sync")
    git(path, "config", "user.email", "opencc-sync@users.noreply.github.com")
    git(path, "config", "commit.gpgsign", "false")


def commit_environment(path, *refs, minimum=0):
    # Re-preparing the same source inputs must recover the same bot branch after
    # a successful push followed by an uncertain/failed PR creation request.
    timestamp = max([minimum, *[int(git(path, "show", "-s", "--format=%ct", ref)) for ref in refs]])
    return dict(os.environ, GIT_AUTHOR_DATE=f"{timestamp} +0000", GIT_COMMITTER_DATE=f"{timestamp} +0000")


def push_candidate(path, head, branch):
    # Reuse gh's environment/keychain authentication without exposing a token or
    # modifying global Git configuration. Works with GH_TOKEN and GITHUB_TOKEN.
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    git(path, "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential",
        "push", "origin", f"{sha(head)}:refs/heads/{branch}", env=env, code=5)


def verify_diff(config, data, path):
    base, head = data["base_sha"], data["head_sha"]
    changed = git(path, "diff", "--name-only", base, head).splitlines()
    if not changed:
        raise SyncError("Candidate contains no changes")
    if any(p.startswith(".github/workflows/") for p in changed):
        raise SyncError("Automatic publication of workflow changes is forbidden")
    if data["stage"] == "app":
        cfg = config["app"]
        project = cfg["project"] + "/project.pbxproj"
        if set(changed) - {project, cfg["resolved"]}:
            raise SyncError("App candidate changes files outside its dependency pin")
        before = git(path, "show", f"{base}:{project}")
        after = git(path, "show", f"{head}:{project}")
        if after != pin_project(before, data["fork_sha"]):
            raise SyncError("App project changed outside SwiftyOpenCC requirement")
        old = json.loads(git(path, "show", f"{base}:{cfg['resolved']}"))
        new = json.loads(git(path, "show", f"{head}:{cfg['resolved']}"))
        expected = copy.deepcopy(old)
        get_pin(expected)["state"] = {"revision": data["fork_sha"]}
        # Xcode owns originHash; all pins and other lockfile fields are invariant.
        expected.pop("originHash", None)
        new.pop("originHash", None)
        if new != expected:
            raise SyncError("Non-SwiftyOpenCC dependency drift detected")
    else:
        cfg = config["fork"]
        if git(path, "rev-parse", f"{head}:{cfg['corePath']}") != data["core_sha"]:
            raise SyncError("Candidate submodule SHA differs from the selected release")
        manifest = json.loads(git(path, "show", f"{head}:{cfg['manifest']}"))
        if manifest.get("opencc") != {"tag": data["core_tag"], "revision": data["core_sha"]}:
            raise SyncError("Candidate resource manifest differs from its selected release")
    git(path, "diff", "--check", base, head)


def validate_candidate(config, data, path):
    cfg = config[data["stage"]]
    # CI injects no write credential here. Strip explicit token variables too;
    # this is not a sandbox for a local developer's keychain/Git configuration.
    clean = {k: v for k, v in os.environ.items() if k not in
             {"GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"}}
    if data["stage"] == "fork":
        run(["python3", cfg["generator"]], cwd=path, env=clean)
        run(["python3", cfg["generator"], "--check"], cwd=path, env=clean)
        run(["swift", "test"], cwd=path, env=clean)
    else:
        run(["xcodebuild", "-resolvePackageDependencies", "-project", cfg["project"],
             "-scheme", cfg["scheme"], "-skipPackageUpdates"], cwd=path, env=clean)
        for command in (["python3", "scripts/check-core.py"], ["bash", "scripts/check-quota.sh"],
                        ["bash", "scripts/check-pasteboard.sh"]):
            run(command, cwd=path, env=clean)


def report(data):
    stage = data["stage"]
    lines = [f"OpenCC {stage} update", "", f"Candidate: `{data['candidate']}`", "",
             f"Base: `{data['repository']}:{data['base']}` at `{data['base_sha']}`", ""]
    if stage == "fork":
        lines += [f"Wrapper upstream: `{data['upstream_sha']}`",
                  f"OpenCC: `{data['old_core_tag']}` / `{data['old_core_sha']}` → `{data['core_tag']}` / `{data['core_sha']}`"]
    else:
        lines += [f"SwiftyOpenCC: `{data['old_fork_sha']}` → `{data['fork_sha']}`"]
    lines += ["", "Validation: " + ", ".join(data.get("checks", [])), "",
              "Human review and merge required. Use **Create a merge commit** for fork updates.",
              "To roll back, restore the app's prior pin in a PR; revert the complete fork update if needed.",
              f"Add `{data['candidate']}` to `ignoredCandidates.{stage}` in the coordinator configuration to suppress this candidate.",
              "", f"{MARKER}{stage} {data['candidate']} -->"]
    return "\n".join(lines) + "\n"


@contextmanager
def candidate_workspace(output, data):
    log_start = len(RUN_LOG)
    with tempfile.TemporaryDirectory(prefix="opencc-sync-") as temp:
        path = Path(temp) / "candidate"
        try:
            yield path
        except Exception as error:
            failure = {**data, "status": "blocked", "reason": str(error),
                       "artifact_directory": str(output), **getattr(error, "details", {})}
            (output / "failure.json").write_text(json.dumps(failure, ensure_ascii=False, indent=2) + "\n")
            (output / "report.md").write_text(report(failure) + "\nFailure: " + str(error) + "\n")
            if (path / ".git").exists():
                result = subprocess.run(["git", "-C", str(path), "diff", "--binary", data["base_sha"]], text=True, capture_output=True)
                (output / "diff.patch").write_text(result.stdout)
            if isinstance(error, SyncError):
                error.details["artifact_directory"] = str(output)
            raise
        finally:
            (output / "prepare.log").write_text("\n".join(RUN_LOG[log_start:]))


def prepare(config, stage, github, output, expected=None):
    data = discover(config, stage, github)
    if data["status"] != "changed":
        return data
    if expected and any(data.get(k) != expected.get(k) for k in
                        ("stage", "base_sha", "candidate", "upstream_sha", "core_sha", "fork_sha")):
        raise SyncError("Remote state changed since detection; run again")
    output = Path(output).resolve()
    if output.exists() and any(output.iterdir()):
        raise SyncError("Output directory must be empty", 2)
    output.mkdir(parents=True, exist_ok=True)
    cfg = config[stage]
    data["artifact_directory"] = str(output)
    with candidate_workspace(output, data) as path:
        clone(cfg["repository"], cfg["base"], path)
        git(path, "checkout", "-b", data["branch"], data["base_sha"])
        if stage == "fork":
            git(path, "fetch", remote(cfg["upstreamRepository"]), cfg["upstreamBase"], code=5)
            if git(path, "rev-parse", "FETCH_HEAD") != data["upstream_sha"]:
                raise SyncError("Wrapper changed during preparation")
            # Also reject workflow edits hidden by an incomplete compare API response.
            commits = git(path, "log", "--format=%H", f"{data['base_sha']}..{data['upstream_sha']}", "--", ".github/workflows")
            if commits:
                raise SyncError("Incoming wrapper history changes workflows; merge manually")
            if data["incoming_wrapper"]:
                try:
                    git(path, "merge", "--no-ff", "--no-edit", data["upstream_sha"], code=3,
                        env=commit_environment(path, data["base_sha"], data["upstream_sha"]))
                except SyncError as error:
                    conflicts = git(path, "diff", "--name-only", "--diff-filter=U").splitlines()
                    raise SyncError("Wrapper merge conflict; no branch was pushed", 3, conflicts=conflicts) from error
            git(path, "submodule", "update", "--init", "--recursive", code=5)
            core = path / cfg["corePath"]
            git(core, "fetch", "origin", f"refs/tags/{data['core_tag']}", code=5)
            if git(core, "rev-parse", "FETCH_HEAD^{commit}") != data["core_sha"]:
                raise SyncError("OpenCC release tag moved during preparation")
            git(core, "checkout", "--detach", data["core_sha"])
        else:
            resolved = path / cfg["resolved"]
            pins = json.loads(resolved.read_text())
            get_pin(pins)["state"] = {"revision": data["fork_sha"]}
            resolved.write_text(json.dumps(pins, ensure_ascii=False, indent=2) + "\n")
            project = path / cfg["project"] / "project.pbxproj"
            project.write_text(pin_project(project.read_text(), data["fork_sha"]))
        validate_candidate(config, data, path)
        git(path, "add", "--all")
        message = (f"chore: sync OpenCC {stage} ({data['candidate']})\n\n"
                   "Log:\n需求描述: 同步已核验的 OpenCC 依赖。\n实现思路: 固定来源 SHA，生成并校验资源，经人工 PR 合并。")
        core_time = int(git(path / cfg["corePath"], "show", "-s", "--format=%ct", data["core_sha"])) if stage == "fork" else 0
        git(path, "commit", "-m", message, env=commit_environment(path, "HEAD", minimum=core_time))
        data["head_sha"] = sha(git(path, "rev-parse", "HEAD"))
        data["checks"] = (["resource generation", "manifest --check", "swift test"] if stage == "fork"
                          else ["locked package resolution", "core", "quota", "pasteboard"])
        verify_diff(config, data, path)
        git(path, "bundle", "create", str(output / "candidate.bundle"), f"refs/heads/{data['branch']}", f"^{data['base_sha']}")
        (output / "diff.patch").write_text(git(path, "diff", "--binary", data["base_sha"], data["head_sha"]) + "\n")
    data["bundle_sha256"] = hashlib.sha256((output / "candidate.bundle").read_bytes()).hexdigest()
    (output / "candidate.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    (output / "report.md").write_text(report(data))
    return data


def publish(config, stage, github, prepared):
    folder = Path(prepared).resolve()
    data = json.loads((folder / "candidate.json").read_text())
    cfg = config[stage]
    if any(data.get(k) != value for k, value in
           {"schemaVersion": 1, "stage": stage, "repository": cfg["repository"], "base": cfg["base"]}.items()):
        raise SyncError("Prepared candidate/configuration mismatch", 2)
    for key in ("base_sha", "head_sha", "upstream_sha", "core_sha") if stage == "fork" else ("base_sha", "head_sha", "fork_sha"):
        sha(data[key])
    expected_candidate = candidate_id(stage, [data["upstream_sha"], data["core_sha"]] if stage == "fork" else [data["fork_sha"]])
    if data.get("candidate") != expected_candidate or data.get("branch") != f"codex/sync-{stage}-{expected_candidate}":
        raise SyncError("Candidate identity mismatch")
    if data["candidate"] in config["ignoredCandidates"][stage]:
        return {**data, "status": "noop", "reason": "Candidate now ignored"}
    bundle = folder / "candidate.bundle"
    if hashlib.sha256(bundle.read_bytes()).hexdigest() != data["bundle_sha256"]:
        raise SyncError("Candidate bundle checksum mismatch")
    pulls = github.pulls(cfg["repository"], cfg["base"])
    same = [p for p in pulls if p["head"]["ref"] == data["branch"]
            and p["head"].get("repo", {}).get("full_name") == cfg["repository"]]
    for pr in same:
        if pr["state"] == "open":
            if pr["head"]["sha"] != data["head_sha"]:
                raise SyncError("The candidate PR was changed by another writer; leaving it untouched")
            return {**data, "status": "waiting", "reason": "Candidate PR already exists", "pr_url": pr["html_url"]}
        if pr.get("merged_at"):
            return {**data, "status": "noop", "reason": "Candidate already merged", "pr_url": pr["html_url"]}
    gate = pull_gate(pulls, stage, cfg["repository"], data["candidate"])
    if gate:
        return {**data, **gate}
    if github.head(cfg["repository"], cfg["base"]) != data["base_sha"]:
        raise SyncError("Target base changed after validation; prepare again")
    if stage == "fork":
        if github.tag_sha(cfg["coreRepository"], data["core_tag"]) != data["core_sha"]:
            raise SyncError("Release tag moved after validation")
    else:
        fork = config["fork"]
        if github.head(fork["repository"], fork["base"]) != data["fork_sha"]:
            raise SyncError("Accepted fork changed after validation; prepare again")
        if not github.check_passed(fork["repository"], data["fork_sha"], fork["requiredCheck"]):
            raise SyncError("Fork compatibility check is no longer passing")
        if not github.check_passed(cfg["repository"], data["base_sha"], cfg["requiredCheck"]):
            raise SyncError("App base regression check is no longer passing")
        if pull_gate(github.pulls(fork["repository"], fork["base"]), "fork", fork["repository"]):
            raise SyncError("A fork update now awaits review; finish it first")
    with tempfile.TemporaryDirectory(prefix="opencc-publish-") as temp:
        path = Path(temp) / "candidate"
        clone(cfg["repository"], cfg["base"], path)
        git(path, "bundle", "verify", str(bundle))
        git(path, "fetch", str(bundle), f"refs/heads/{data['branch']}")
        if git(path, "rev-parse", "FETCH_HEAD") != data["head_sha"]:
            raise SyncError("Bundle head differs from validated head")
        git(path, "merge-base", "--is-ancestor", data["base_sha"], data["head_sha"], code=3)
        verify_diff(config, data, path)
        remote_heads = git(path, "ls-remote", "--heads", "origin", f"refs/heads/{data['branch']}", code=5)
        if remote_heads and remote_heads.split()[0] != data["head_sha"]:
            raise SyncError("Candidate branch already differs; force-push is forbidden. Inspect the existing branch; "
                            "if it is an abandoned bot candidate without a PR or human changes, delete that branch "
                            "manually before preparing again", 3, branch=data["branch"])
        if not remote_heads:
            push_candidate(path, data["head_sha"], data["branch"])
        try:
            pr = github.api(f"repos/{cfg['repository']}/pulls", method="POST", body={
                "title": f"chore: sync OpenCC {stage} ({data.get('core_tag', data.get('fork_sha', '')[:12])})",
                "head": data["branch"], "base": cfg["base"], "body": report(data)})
        except SyncError:
            # A previous uncertain POST or a concurrent publisher may have succeeded.
            matches = [p for p in github.pulls(cfg["repository"], cfg["base"])
                       if p["head"]["ref"] == data["branch"] and p["state"] == "open"
                       and p["head"].get("repo", {}).get("full_name") == cfg["repository"]
                       and p["head"]["sha"] == data["head_sha"]]
            if not matches:
                raise
            pr = matches[0]
    return {**data, "status": "changed", "pr_url": pr["html_url"]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "prepare", "pr"])
    parser.add_argument("--stage", required=True, choices=["fork", "app"])
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("upstream-sync.json"))
    parser.add_argument("--output", type=Path, help="Empty artifact directory; defaults to a persistent temporary directory")
    parser.add_argument("--expected", type=Path, help="Detection JSON whose source SHAs must still match")
    parser.add_argument("--prepared", type=Path, help="Publish validated artifacts without running candidate code (required in CI)")
    args = parser.parse_args(argv)
    code = 0
    try:
        config = json.loads(args.config.read_text())
        if config.get("schemaVersion") != 1:
            raise SyncError("Unsupported coordinator configuration", 2)
        github = GitHub()
        if args.command == "check":
            data = discover(config, args.stage, github)
        elif args.command == "prepare":
            output = args.output or Path(tempfile.mkdtemp(prefix="opencc-candidate-"))
            expected = json.loads(args.expected.read_text()) if args.expected else None
            data = prepare(config, args.stage, github, output, expected)
        else:
            if not args.prepared:
                if os.environ.get("GITHUB_ACTIONS") == "true":
                    raise SyncError("CI pr requires --prepared; the publishing job must never build candidate code", 2)
                output = args.output or Path(tempfile.mkdtemp(prefix="opencc-candidate-"))
                data = prepare(config, args.stage, github, output)
                if data["status"] == "changed":
                    data = publish(config, args.stage, github, output)
            else:
                data = publish(config, args.stage, github, args.prepared)
    except SyncError as error:
        code = error.code
        data = {"schemaVersion": 1, "stage": args.stage,
                "status": "blocked" if code in (2, 3, 4) else "error",
                "reason": str(error), **error.details}
    except (OSError, ValueError, KeyError, TypeError) as error:
        code = 2
        data = {"schemaVersion": 1, "stage": args.stage, "status": "error", "reason": str(error)}
    print(json.dumps(data, ensure_ascii=False, sort_keys=True))
    return code


if __name__ == "__main__":
    sys.exit(main())
