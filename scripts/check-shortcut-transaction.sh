#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-shortcut-check.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
python3 - "$repo_root/OpenCCman/Services/GlobalShortcutService.swift" "$audit_dir/Transaction.swift" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
core = source[source.index('// MARK: - Sandbox-compatible'):source.index('// MARK: - Global Shortcut Service')]
snapshot = source[source.index('struct PasteboardSnapshot {'):source.index('// MARK: - Notification Extension')]
Path(sys.argv[2]).write_text('import AppKit\nimport Carbon\n' + core + snapshot)
PY
xcrun swiftc -O "$audit_dir/Transaction.swift" "$repo_root/Tests/Regression/ShortcutTransactionChecks.swift" -o "$audit_dir/check"
"$audit_dir/check"

# The service's switch: its stored value and launch order, without the
# KeyboardShortcuts package or any UI. The real stored properties, init and
# handler setup are compiled with test stand-ins in one file, so the checks can
# call the private init without widening it.
python3 - "$repo_root" "$audit_dir/Preference.swift" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
source = (root / 'OpenCCman/Services/GlobalShortcutService.swift').read_text()
service = source[source.index('// MARK: - Global Shortcut Service'):source.index('    // MARK: - Shortcut Handling')]
keys = (root / 'OpenCCman/Model/UserDefaultsKeys.swift').read_text()
keys = keys[keys.index('enum UserDefaultsKeys: String'):]
checks = (root / 'Tests/Regression/ShortcutPreferenceChecks.swift').read_text()
Path(sys.argv[2]).write_text(checks + '\n' + keys + '\n' + service + '}\n')
PY
xcrun swiftc -swift-version 5 -parse-as-library "$audit_dir/Preference.swift" -o "$audit_dir/check-preference"
"$audit_dir/check-preference"
