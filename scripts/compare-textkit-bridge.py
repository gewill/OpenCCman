#!/usr/bin/env python3
"""Validate and compare matched, complete TextKit app reflow audits."""
import argparse
import json
from pathlib import Path
import statistics

from app_performance import PROTOCOL, sha256, validate_pins


def load(path, expected_variant):
    metadata_path = path / 'metadata.json'
    metadata = json.loads(metadata_path.read_text())
    validate_pins(metadata)
    if metadata['schema'] != PROTOCOL or metadata['conditions']['suite'] != 'reflow':
        raise ValueError(f'Not a current reflow protocol: {path}')
    if metadata['application_variant'] != expected_variant:
        raise ValueError(f'Wrong editor variant: {path}')
    files = sorted(path.glob('run-*.json'))
    if not files:
        raise ValueError(f'No runs: {path}')
    runs = [json.loads(p.read_text()) for p in files]
    names = [row['name'] for row in runs[0]['rows']]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate stage names')
    complete = []
    excluded = []
    for file, run in zip(files, runs):
        if run.get('status') != 'complete' or run.get('metadata_sha256') != sha256(metadata_path):
            raise ValueError(f'Incomplete or unbound run: {path}')
        if [row['name'] for row in run['rows']] != names:
            raise ValueError('Stage sequence differs')
        foreground_failures = []
        foreground_required = False
        for row in run['rows']:
            if row['memory']['task_info_status'] or row['memory']['rusage_status']:
                raise ValueError('Memory measurement failed')
            foreground_required |= row['name'] == 'root_layout_ready'
            if foreground_required and (not row['app_active'] or row['visible_window_count'] < 1):
                foreground_failures.append(row['name'])
            if row.get('editors_match_model') is False or row.get('export_matches_result') is False:
                raise ValueError('Editor or conversion failed validation')
            if row['name'].startswith('layout_end_'):
                modern = expected_variant == 'textkit2-no-anchor'
                if row.get('textkit2') != modern or row.get('result_textkit2') != modern:
                    raise ValueError('Editor engine differs from expected variant')
        if foreground_failures:
            excluded.append({'file': file.name, 'reason': 'not foreground and visible', 'stages': foreground_failures})
        else:
            complete.append(run)
    if len(complete) < 3:
        raise ValueError(f'Need at least three foreground complete new-process runs: {path}; excluded {excluded}')
    return metadata, complete, excluded


def compare(before, after):
    bm, br, be = load(before, 'unchanged')
    am, ar, ae = load(after, 'textkit2-no-anchor')
    for field in ('hardware', 'os', 'xcode', 'conditions', 'pins', 'resolved_checkout_revisions',
                  'source_commit', 'measurement_harness_commit'):
        if bm[field] != am[field]:
            raise ValueError(f'Comparison condition differs: {field}')
    changed = {name for name in bm['source_hashes'].keys() | am['source_hashes'].keys()
               if bm['source_hashes'].get(name) != am['source_hashes'].get(name)}
    # The analysis script is not compiled into the app; it was written after
    # the first private build. All buildable sources must match except editor.
    changed_buildable = changed - {'scripts/compare-textkit-bridge.py'}
    if changed_buildable != {'OpenCCman/View/WorkspaceTextEditor.swift'}:
        raise ValueError(f'Unexpected changed source: {sorted(changed)}')
    for name in [row['name'] for row in br[0]['rows'] if row['name'].startswith('reflow_convert_')]:
        values = [next(row for row in run['rows'] if row['name'] == name) for run in br + ar]
        for field in ('input_sha256', 'output_sha256'):
            if len({row[field] for row in values}) != 1:
                raise ValueError(f'Corpus or conversion output changed: {name}, {field}')
    def distribution(values):
        return {'median': statistics.median(values), 'range': [min(values), max(values)]}
    stages = {}
    for name in [row['name'] for row in br[0]['rows'] if row['name'].startswith(('reflow_convert_', 'scroll_end_', 'layout_end_'))]:
        rows = [[next(row for row in run['rows'] if row['name'] == name) for run in group] for group in (br, ar)]
        metrics = ['rss_bytes', 'physical_footprint_bytes', 'process_peak_rss_bytes']
        stages[name] = {metric: {'tk1': distribution([row['memory'][metric] for row in rows[0]]),
                                 'tk2_no_anchor': distribution([row['memory'][metric] for row in rows[1]])}
                        for metric in metrics}
        if 'action_ms' in rows[0][0]:
            stages[name]['action_ms'] = {'tk1': distribution([row['action_ms'] for row in rows[0]]),
                                         'tk2_no_anchor': distribution([row['action_ms'] for row in rows[1]])}
        if 'model_completion_ms' in rows[0][0]:
            for metric in ('model_completion_ms', 'result_layout_flush_ms'):
                stages[name][metric] = {'tk1': distribution([row[metric] for row in rows[0]]),
                                         'tk2_no_anchor': distribution([row[metric] for row in rows[1]])}
    return {'schema': 1, 'tk1_samples': len(br), 'tk2_no_anchor_samples': len(ar),
            'excluded': {'tk1': be, 'tk2_no_anchor': ae},
            'source_commit': bm['source_commit'], 'changed_source': sorted(changed),
            'baseline_metadata_sha256': sha256(before / 'metadata.json'),
            'candidate_metadata_sha256': sha256(after / 'metadata.json'),
            'final_peak_rss_bytes': {'tk1': distribution([run['rows'][-1]['memory']['process_peak_rss_bytes'] for run in br]),
                                     'tk2_no_anchor': distribution([run['rows'][-1]['memory']['process_peak_rss_bytes'] for run in ar])},
            'stages': stages}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.before, args.after), indent=2))


if __name__ == '__main__':
    main()
