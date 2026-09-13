#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-sizing.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
neumorphic_path="${1:-}"
if [[ -z "$neumorphic_path" ]]; then
  neumorphic_path="$audit_dir/neumorphic"
  git clone --quiet --no-checkout https://github.com/gewill/neumorphic.git "$neumorphic_path"
  revision="$(python3 - "$repo_root" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]) / 'OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
print(next(pin['state']['revision'] for pin in json.loads(p.read_text())['pins'] if pin['identity'] == 'neumorphic'))
PY
)"
  git -C "$neumorphic_path" checkout --quiet --detach "$revision"
fi
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(rg --files "$neumorphic_path/Sources/Neumorphic" -g '*.swift')
xcrun swiftc -parse-as-library -emit-library -emit-module -module-name Neumorphic \
  -emit-module-path "$audit_dir/Neumorphic.swiftmodule" \
  -Xlinker -install_name -Xlinker "$audit_dir/libNeumorphic.dylib" \
  "${sources[@]}" -o "$audit_dir/libNeumorphic.dylib"
xcrun swiftc -I "$audit_dir" -L "$audit_dir" -lNeumorphic \
  "$repo_root/OpenCCman/View/AppControlStyle.swift" \
  "$repo_root/Tests/Regression/ControlSizingChecks.swift" -o "$audit_dir/check-sizing"
"$audit_dir/check-sizing"
