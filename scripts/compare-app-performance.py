#!/usr/bin/env python3
"""Compare repeatable app audits. Warnings request investigation, never prove regression."""
import argparse
import json
from pathlib import Path
import statistics

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from app_performance import TIMINGS, PROTOCOL, sha256, validate_pins


def load(directory):
    metadata = json.loads((directory / 'metadata.json').read_text())
    if metadata.get('schema') != PROTOCOL:
        raise ValueError('Legacy measurement protocol; regenerate baseline')
    validate_pins(metadata)
    runs = [json.loads(p.read_text()) for p in sorted(directory.glob('run-*.json'))]
    if len(runs) < 3:
        raise ValueError('At least three independent processes are required')
    names = [r['name'] for r in runs[0]['rows']]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate stage names')
    for run in runs:
        if run.get('metadata_sha256') != sha256(directory / 'metadata.json'):
            raise ValueError('Run provenance differs from metadata')
        foreground_required = False
        if run['status'] != 'complete' or [r['name'] for r in run['rows']] != names:
            raise ValueError('Incomplete or inconsistent stage set')
        configs = [r['options'] for r in run['rows'] if r['name'].startswith('configuration_')]
        if set(configs) != {2, 1, 1025, 33, 1057, 65, 1089} or len(configs) != 7:
            raise ValueError('Missing effective configuration coverage')
        for row in run['rows']:
            foreground_required |= row['name'] == 'root_layout_ready'
            if foreground_required and (row.get('app_active') is not True or row.get('visible_window_count', 0) < 1):
                raise ValueError('Foreground or visible-window condition violated')
            if row.get('editors_match_model') is False:
                raise ValueError('Exact editor validation failed')
            if row['memory']['task_info_status'] != 0 or row['memory']['rusage_status'] != 0:
                raise ValueError('Memory collection failed')
            if row.get('export_matches_result') is False:
                raise ValueError('Correctness check failed')
    return metadata, runs


def compare(before, after):
    bm, br = load(before)
    am, ar = load(after)
    for key in ('hardware', 'os', 'xcode', 'conditions'):
        if bm[key] != am[key]:
            raise ValueError(f'Conditions differ: {key}')
    def other_pins(m):
        return [p for p in m['pins']['pins'] if p['identity'] != 'swiftyopencc']
    if other_pins(bm) != other_pins(am):
        raise ValueError('Unrelated dependency drift')
    if bm['source_hashes']['Tests/Benchmarks/AppPerformanceAudit.swift'] != am['source_hashes']['Tests/Benchmarks/AppPerformanceAudit.swift']:
        raise ValueError('Measurement harness differs')
    for path in ('scripts/benchmark-app.py', 'scripts/app_performance.py'):
        if bm['source_hashes'].get(path) != am['source_hashes'].get(path):
            raise ValueError('Measurement driver differs')
    results = []
    for index, row in enumerate(br[0]['rows']):
        name = row['name']
        left = [r['rows'][index] for r in br]
        right = [next((v for v in r['rows'] if v['name'] == name), None) for r in ar]
        if any(v is None for v in right):
            raise ValueError(f'Missing stage {name}')
        if 'input_sha256' in row:
            if len({v['input_sha256'] for v in left + right}) != 1:
                raise ValueError(f'Input corpus differs in {name}')
            if len({v['output_sha256'] for v in left}) != 1 or len({v['output_sha256'] for v in right}) != 1:
                raise ValueError(f'Nondeterministic output in {name}')
        entry = {'name': name, 'metrics': {}, 'output_changed': row.get('output_sha256') != right[0].get('output_sha256')}
        for key in TIMINGS:
            if key not in row:
                continue
            b = statistics.median(v[key] for v in left)
            a = statistics.median(v[key] for v in right)
            entry['metrics'][key] = {'before_median': b, 'after_median': a, 'delta': a-b,
                                     'before_range': [min(v[key] for v in left), max(v[key] for v in left)],
                                     'after_range': [min(v[key] for v in right), max(v[key] for v in right)],
                                     'review': a-b > max(10, b*0.2)}
        for key in ('rss_bytes', 'physical_footprint_bytes', 'process_peak_rss_bytes'):
            b = statistics.median(v['memory'][key] for v in left)
            a = statistics.median(v['memory'][key] for v in right)
            entry['metrics'][key] = {'before_median': b, 'after_median': a, 'delta': a-b,
                                     'review': a-b > max(16*1024*1024, b*0.1)}
        entry['models_still_alive'] = [v.get('extra_models_alive') for v in right if 'extra_models_alive' in v]
        results.append(entry)
    return {'schema': 1, 'before_samples': len(br), 'after_samples': len(ar), 'stages': results,
            'interpretation': 'Review thresholds (time > max(20%,10ms); memory > max(10%,16MiB)) are triage heuristics, not statistical significance or release gates.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.before, args.after), indent=2))


if __name__ == '__main__':
    main()
