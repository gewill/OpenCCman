#!/usr/bin/env python3
"""Opt-in real-source fork replay; never publishes to GitHub.

Prerequisite: an isolated fork checkout with a committed, regenerated older
stable core, and both official release tags in its initialized OpenCC submodule.
The GitHub API is a local fixture; generation, compilers, tests and CLI are real.
Outputs retain the full logs/bundles. Not part of the lightweight CI test suite.
"""
import argparse
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def main():
    if not __debug__:
        raise SystemExit('Run without -O so replay assertions remain enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fork-source', type=Path, required=True)
    parser.add_argument('--upstream-sha', required=True)
    parser.add_argument('--coordinator', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source, output = args.fork_source.resolve(), args.output.resolve()
    if output.exists():
        raise SystemExit('Output must not exist; each replay retains its own evidence')
    if git(source, 'status', '--porcelain'):
        raise SystemExit('Commit the isolated baseline first')
    output.mkdir(parents=True)
    sync = load('replay_coordinator', args.coordinator.resolve())
    fixtures = load('replay_fixtures', ROOT / 'tests/test_upstream_sync.py')
    fixtures.sync = sync
    config = json.loads(args.coordinator.with_name('upstream-sync.json').read_text())
    baseline = git(source, 'rev-parse', 'HEAD')
    manifest = json.loads((source / config['fork']['manifest']).read_text())
    old_tag = manifest['opencc']['tag']
    assert old_tag == 'ver.1.4.1', 'This documented replay expects real 1.4.1 -> 1.4.2'
    assert git(source / 'OpenCC', 'rev-parse', 'HEAD') == manifest['opencc']['revision']
    upstream = sync.sha(args.upstream_sha)
    git(source, 'merge-base', '--is-ancestor', upstream, baseline)
    remotes = output / 'remotes'
    for repository, checkout, ref in [
        (config['fork']['repository'], source, baseline),
        (config['fork']['upstreamRepository'], source, upstream),
        (config['fork']['coreRepository'], source / 'OpenCC', None),
    ]:
        destination = remotes / (repository + '.git')
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--bare', str(checkout), str(destination)], check=True)
        git(destination, 'remote', 'remove', 'origin')
        if ref:
            git(destination, 'update-ref', 'refs/heads/master', ref)
    github = fixtures.FakeGitHub(remotes, config)
    core = remotes / (config['fork']['coreRepository'] + '.git')
    provenance = {
        'scope': 'isolated reconstructed 1.4.1 baseline; real core/compiler; local GitHub API fixture',
        'baseline': baseline, 'wrapperUpstream': upstream,
        'coreBefore': git(core, 'rev-parse', old_tag + '^{commit}'),
        'coreAfter': git(core, 'rev-parse', 'ver.1.4.2^{commit}'),
        'coordinatorSHA256': hashlib.sha256(args.coordinator.read_bytes()).hexdigest(),
        'compatibilitySources': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in sorted((source / 'Configuration/Compatibility').glob('*.json'))},
    }
    write(output / 'sources.json', provenance)
    env = {'OPENCC_SYNC_TEST_REMOTES': str(remotes), 'GIT_ALLOW_PROTOCOL': 'file:https',
           'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'url.' + core.as_uri() + '.insteadOf',
           'GIT_CONFIG_VALUE_0': 'https://github.com/BYVoid/OpenCC'}
    outcomes = {}

    def invoke(label, command, expected=0):
        stream = io.StringIO()
        with patch.object(sync, 'GitHub', return_value=github), contextlib.redirect_stdout(stream):
            status = sync.main([command, '--stage', 'fork', '--config', str(args.coordinator.with_name('upstream-sync.json')),
                                '--output', str(output / label)])
        data = json.loads(stream.getvalue())
        write(output / (label + '.json'), {'exitCode': status, 'result': data})
        assert status == expected, (label, status, data)
        outcomes[label] = {'exitCode': status, 'status': data['status']}
        print(label, status, data['status'], flush=True)
        return data

    with patch.dict(os.environ, env):
        detected = invoke('check', 'check')
        assert detected['status'] == 'changed'
        assert detected['old_core_sha'] == provenance['coreBefore']
        assert detected['core_sha'] == provenance['coreAfter']
        # Real CMake fails before staging resources. No compiler/generator stub.
        with patch.dict(os.environ, {'CXX': str(output / 'intentionally-missing-cxx')}):
            invoke('generation-failure', 'prepare', expected=4)
        assert not (output / 'generation-failure/candidate.bundle').exists()
        assert not (output / 'generation-failure/candidate.json').exists()
        assert (output / 'generation-failure/failure.json').is_file()
        first = invoke('recovered', 'prepare')
        second = invoke('repeated', 'prepare')
        assert first['head_sha'] == second['head_sha'], 'Same sources produced different commits'
        assert first['candidate'] == second['candidate']
        for name in ('recovered', 'repeated'):
            report = json.loads((output / name / 'official-cli-report.json').read_text())
            assert report['status'] == 'passed'
        # Inspect actual generated files through the validated Git bundle.
        fork = github.repo(config['fork']['repository'])
        git(fork, 'fetch', str(output / 'recovered/candidate.bundle'), 'refs/heads/' + first['branch'])
        final_manifest = json.loads(git(fork, 'show', first['head_sha'] + ':' + config['fork']['manifest']))
        write(output / 'generated-manifest.json', final_manifest)
        for name, checksum in provenance['compatibilitySources'].items():
            content = subprocess.check_output(['git', '-C', str(fork), 'show', first['head_sha'] + ':Configuration/Compatibility/' + name])
            assert hashlib.sha256(content).hexdigest() == checksum
            assert final_manifest['files']['Compatibility/' + name] == checksum
        pr = {'head': {'ref': first['branch'], 'sha': first['head_sha'],
                       'repo': {'full_name': config['fork']['repository']}},
              'base': {'ref': 'master'}, 'state': 'open', 'merged_at': None,
              'body': sync.report(first), 'html_url': 'https://example.test/replay/pull/1'}
        github.prs[config['fork']['repository']] = [pr]
        assert invoke('pending', 'prepare')['status'] == 'waiting'
        pr['state'] = 'closed'
        assert invoke('rejected', 'prepare')['status'] == 'waiting'
        github.prs[config['fork']['repository']] = []
        ignored = copy.deepcopy(config)
        ignored['ignoredCandidates']['fork'].append(first['candidate'])
        suppressed = sync.discover(ignored, 'fork', github)
        assert suppressed['status'] == 'noop'
        write(output / 'ignored.json', suppressed)
        # A real local Git pre-receive hook rejects publishing this real bundle.
        # This proves coordinator exit/artifact behavior, not GitHub App permissions.
        hook = fork / 'hooks/pre-receive'
        hook.write_text('#!/bin/sh\nprintf "%s\\n" "Replay intentionally denies writes" >&2\nexit 1\n')
        hook.chmod(0o755)
        try:
            sync.publish(config, 'fork', github, output / 'recovered')
            raise AssertionError('Denied local push unexpectedly succeeded')
        except sync.SyncError as error:
            assert error.code == 5, str(error)
            write(output / 'write-denied.json', {'exitCode': error.code, 'reason': str(error), 'transport': 'local Git pre-receive rejection'})
        assert not git(fork, 'ls-remote', '--heads', str(fork), first['branch'])
        assert github.posts == 0
        write(output / 'summary.json', {'status': 'passed', 'outcomes': outcomes,
              'candidate': first['candidate'], 'headSHA': first['head_sha'],
              'sameSourceSameCommit': True, 'compatibilitySourcesUnchanged': True,
              'writeDeniedExitCode': 5, 'githubMutationCalls': github.posts,
              'notValidated': ['production GitHub App write permissions', 'new future release', 'application promotion build']})
    print('Real-source replay passed; no GitHub writes.', flush=True)


if __name__ == '__main__':
    main()
