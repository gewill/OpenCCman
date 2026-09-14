"""Regenerate comparisons and per-run stage deltas; never modify input metadata."""
import importlib.util
import json
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('comparison', ROOT / 'scripts/compare-app-performance.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def write(name, data):
    (HERE / name).write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    write('engine-comparison.json', module.compare(HERE / 'opencc-1.2.0', HERE / 'opencc-1.4.2'))
    write('idle-layout-comparison.json', module.compare(HERE / 'opencc-1.4.2', HERE / 'background-layout-off'))
    groups = {}
    for name in ('opencc-1.2.0', 'opencc-1.4.2', 'background-layout-off'):
        _, runs = module.load(HERE / name)
        stages = {}
        for index, row in enumerate(runs[0]['rows']):
            if index == 0:
                continue
            stages[row['name']] = {}
            for field in ('process_cpu_ms', 'elapsed_ms'):
                values = [r['rows'][index][field] - r['rows'][index - 1][field] for r in runs]
                stages[row['name']][field] = {'samples': values, 'median': statistics.median(values),
                                            'range': [min(values), max(values)]}
        groups[name] = stages
    write('stage-deltas.json', groups)
