#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-whats-new.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT

xcrun swiftc -O \
  "$repo_root/OpenCCman/Model/WhatsNew.swift" \
  "$repo_root/Tests/Regression/WhatsNewChecks.swift" \
  -o "$audit_dir/check-whats-new"
"$audit_dir/check-whats-new"

python3 - "$repo_root" <<'PY'
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
keys = {"whats_new_title", "whats_new_done"}
keys.update(f"whats_new_{card}_{part}" for card in ("workspace", "presets", "files", "reliability") for part in ("title", "detail"))
for path in sorted((root / "OpenCCman").glob("*.lproj/Localizable.strings")):
    strings = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))
    actual = {key for key in strings if key.startswith("whats_new_")}
    assert actual == keys, f"{path.parent.name}: missing or obsolete keys: {actual ^ keys}"
    assert all(strings[key].strip() for key in keys), f"{path.parent.name}: empty localization"
    print(f"PASS: {path.parent.name}, all {len(keys)} What’s New strings")
PY
