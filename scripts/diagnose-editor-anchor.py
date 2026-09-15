#!/usr/bin/env python3
"""Run a bounded original/traced prefix probe without changing production sources."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one injection anchor: {old!r}')
    return text.replace(old, new, 1)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repetitions', type=int, default=20)
    args = parser.parse_args()
    if not 1 <= args.repetitions <= 30:
        parser.error('repetitions must be 1...30')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    keeper = ROOT / 'OpenCCman/View/WorkspaceScrollKeeper.swift'
    checks = ROOT / 'Tests/Regression/EditorScrollChecks.swift'
    sources = {str(p.relative_to(ROOT)): sha(p) for p in (keeper, checks)}
    source = keeper.read_text()
    trace = '''    private func diagnostic(_ event: String) {
      let row: [String: Any] = ["event": event, "time": ProcessInfo.processInfo.systemUptime,
        "anchorCharacter": anchor?.character as Any? ?? NSNull(), "anchorOffset": anchor?.lineOffset as Any? ?? NSNull(),
        "pendingCharacter": pending?.character as Any? ?? NSNull(), "pendingOffset": pending?.lineOffset as Any? ?? NSNull(),
        "clip": clip.map { NSStringFromRect($0.bounds) } ?? "nil", "size": NSStringFromSize(size),
        "restoring": restoring, "scheduled": restorationScheduled, "revision": revision]
      FileHandle.standardError.write(try! JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
      FileHandle.standardError.write(Data([10]))
    }

'''
    source = replace_once(source, '    private func textChanged() {', trace + '    private func textChanged() {')
    source = replace_once(source, '    private func viewportChanged() {', '    private func viewportChanged() {\n      diagnostic("viewportChanged")')
    line = '      anchor = Anchor(character: character, lineOffset: point.y - origin.y - rect.minY)'
    source = replace_once(source, line, line + '\n      diagnostic("captured")')
    line = '    private func restore(_ anchor: Anchor, ifSelectionIs selection: NSRange) {'
    source = replace_once(source, line, line + '\n      diagnostic("restoreRequested")')
    source = replace_once(source, '            capture()\n          }', '            capture()\n            diagnostic("restorationFinished")\n          }')
    traced = output / 'TracedKeeper.swift'
    traced.write_text(source)
    tests = checks.read_text()
    first = '    // Coalesced resizes and a new document must not replay an old anchor.'
    last = '\n  @MainActor private static func checkUnlaidOutDocumentEnd'
    if tests.count(first) != 1 or tests.count(last) != 1:
        raise ValueError('Unexpected prefix boundaries')
    tests = tests[:tests.index(first)] + '    withExtendedLifetime(keeper) {}\n    print("PASS: initial width and narrow prefix only")\n  }\n' + tests[tests.index(last):]
    prefix = output / 'PrefixChecks.swift'
    prefix.write_text(tests)
    def command(args):
        return subprocess.check_output(args, cwd=ROOT, text=True).strip()
    report = {
        'protocol': 1, 'sourceSHA': command(['git', 'rev-parse', 'HEAD']),
        'sourceStatus': command(['git', 'status', '--porcelain']),
        'sourceHashes': sources, 'generatedHashes': {p.name: sha(p) for p in (traced, prefix)},
        'os': command(['sw_vers']), 'xcode': command(['xcodebuild', '-version']),
        'compiler': command(['xcrun', 'swiftc', '--version']),
        'repetitionsPerVariant': args.repetitions, 'samples': [],
        'scope': 'Original first width/narrow assertions only; default TextKit font and 80ms settle unchanged; not full app UI acceptance',
        'limitation': 'Synchronous tracing can affect timing. Failed samples remain failures; no retry-until-pass.',
    }
    report_path = output / 'report.json'
    def save():
        report_path.write_text(json.dumps(report, indent=2) + '\n')
    save()
    for variant, file in [('baseline', keeper), ('traced', traced)]:
        with (output / f'{variant}-compile.log').open('wb') as log:
            result = subprocess.run(['xcrun', 'swiftc', '-warnings-as-errors', str(file), str(prefix), '-o', str(output / variant)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        report[variant + 'CompileExit'] = result.returncode
        save()
        if result.returncode:
            return 2
    # Alternate independent processes to avoid treating a batch-time difference as tracing's effect.
    for iteration in range(1, args.repetitions + 1):
        for variant in ('baseline', 'traced'):
            log_path = output / f'{variant}-{iteration:02}.log'
            with log_path.open('wb') as log:
                result = subprocess.run([str(output / variant)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            events = []
            for line in log_path.read_text(errors='replace').splitlines():
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if isinstance(event, dict) and event.get('event') == 'reading-anchor':
                    events.append(event)
            report['samples'].append({'variant': variant, 'iteration': iteration, 'exit': result.returncode, 'log': log_path.name, 'readingAnchors': events})
            save()
    assert all(sha(ROOT / path) == digest for path, digest in sources.items()), 'Production sources changed during probe'
    report['productionSourcesUnchanged'] = True
    report['failedProcesses'] = sum(s['exit'] != 0 for s in report['samples'])
    save()
    print(json.dumps({'report': str(report_path), 'samples': len(report['samples']), 'failedProcesses': report['failedProcesses']}))
    return 1 if report['failedProcesses'] else 0

if __name__ == '__main__':
    sys.exit(main())
