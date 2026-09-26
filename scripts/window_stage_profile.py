"""Bounded, read-only stack sampling of the CI-owned diagnostic process.

No application code changes or local launches. Profiling overhead means this
run is not a latency baseline. Raw stacks are retained for human interpretation.
"""
import json
import hashlib
import math
import re
import subprocess
import time

STAGES = (
    ('import', 'document_10mib-a_import_started', 'document_10mib-a_imported'),
    ('conversion', 'document_10mib-a_conversion_started', 'document_10mib-a_exported'),
)


def complete_rows(path):
    """A writer may be between appending JSON bytes and its final newline."""
    content = path.read_bytes()
    lines = content.split(b'\n')[:-1]
    return [json.loads(line) for line in lines if line]


def check_sample(text, pid):
    if not re.search(r'^Process:\s+OpenCCman\s+\[' + str(pid) + r'\]', text, re.M):
        raise ValueError('Sample does not identify the owned diagnostic PID')
    if 'Call graph:' not in text:
        raise ValueError('Sample has no call graph')


def owned_rows(path, pid):
    rows = complete_rows(path)
    for row in rows:
        if (not isinstance(row, dict) or type(row.get('pid')) is not int
                or row['pid'] != pid or not isinstance(row.get('event'), str)
                or not isinstance(row.get('elapsed_ms'), (float, int))
                or not math.isfinite(row['elapsed_ms'])):
            raise ValueError('Malformed or other-process log record')
        if row['event'].startswith('documents_failed:'):
            raise ValueError('Document driver failed before sampling')
    return rows


def profile_stages(process, cache, output, deadline):
    """Sample only this Popen child; the caller enforces CI and bundle identity."""
    output.mkdir(exist_ok=False)
    report = {'pid': process.pid, 'valid_capture': False,
              'scope': '5-second stack samples, not pure stage timings or a latency baseline',
              'samples': []}
    raw = None
    try:
        for label, start_event, end_event in STAGES:
            while True:
                if process.poll() is not None:
                    raise ValueError('Owned diagnostic process exited before sampling')
                if time.monotonic() >= deadline:
                    raise ValueError('Profiling deadline exceeded')
                files = list(cache.glob(f'lifecycle-{process.pid}-*.jsonl'))
                if len(files) > 1:
                    raise ValueError('Ambiguous owned-process log')
                if files:
                    raw = files[0]
                    rows = owned_rows(raw, process.pid)
                    starts = [r for r in rows if r['event'] == start_event]
                    if len(starts) > 1:
                        raise ValueError('Duplicate profiling start event')
                    if starts:
                        if any(r['event'] == end_event for r in rows):
                            raise ValueError('Stage already completed before sampling')
                        break
                time.sleep(0.05)
            path = output / f'{label}-sample.txt'
            item = {'stage': label, 'start_event': start_event, 'end_event': end_event,
                    'stage_start_elapsed_ms': starts[0]['elapsed_ms'],
                    'last_observed_elapsed_ms_before_sample': rows[-1]['elapsed_ms'],
                    'sample_file': path.name, 'duration_requested_seconds': 5,
                    'interval_requested_ms': 10}
            report['samples'].append(item)
            began = time.monotonic()
            if process.poll() is not None or deadline - began < 5:
                raise ValueError('Owned process or remaining sampling budget unavailable')
            with (output / f'{label}-tool.log').open('w') as log:
                result = subprocess.run(['/usr/bin/sample', str(process.pid), '5', '10',
                                         '-mayDie', '-file', str(path)],
                                        stdout=log, stderr=subprocess.STDOUT,
                                        timeout=min(30, deadline - began))
            item['tool_wall_seconds'] = time.monotonic() - began
            item['exit_code'] = result.returncode
            if result.returncode != 0:
                raise ValueError('System stack sampler failed; inspect tool log')
            check_sample(path.read_text(), process.pid)
            item['sample_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            rows = owned_rows(raw, process.pid)
            ends = [r for r in rows if r['event'] == end_event]
            item['stage_end_seen_at_capture_return'] = bool(ends)
            item['last_observed_elapsed_ms_after_sample'] = rows[-1]['elapsed_ms']
            if ends:
                item['stage_end_elapsed_ms'] = ends[0]['elapsed_ms']
            # A capture may straddle the end of a stage; keep that fact rather
            # than treating all of its stacks as exclusive stage CPU time.
        report['valid_capture'] = True
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        report['error'] = str(error)
        raise
    finally:
        (output / 'capture.json').write_text(json.dumps(report, indent=2) + '\n')
    return report
