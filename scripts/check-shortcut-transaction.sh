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
