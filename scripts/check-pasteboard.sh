#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-pasteboard.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT

# Compile the production type directly; extracting it avoids resolving the app's
# unrelated Swift packages or adding a separate Xcode test target.
python3 - "$repo_root/OpenCCman/Services/GlobalShortcutService.swift" "$audit_dir/PasteboardSnapshot.swift" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = source.index("struct PasteboardSnapshot {")
end = source.index("// MARK: - Notification Extension", start)
Path(sys.argv[2]).write_text("import AppKit\n" + source[start:end])
PY

xcrun swiftc -O \
  "$audit_dir/PasteboardSnapshot.swift" \
  "$repo_root/Tests/Regression/PasteboardChecks.swift" \
  -o "$audit_dir/check-pasteboard"

"$audit_dir/check-pasteboard"
