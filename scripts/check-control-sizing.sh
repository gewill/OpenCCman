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
# Materialize discovery in a checked command, not process substitution: failures
# there do not propagate reliably through Bash 3.2's errexit behavior.
python3 - "$neumorphic_path/Sources/Neumorphic" > "$audit_dir/sources.list" <<'PY'
import os, sys
from pathlib import Path
root = Path(sys.argv[1])
if not root.is_dir():
    raise SystemExit("Missing Neumorphic source directory")
def fail(error):
    raise error
sources = sorted(Path(parent) / name
                 for parent, _, names in os.walk(root, onerror=fail)
                 for name in names if name.endswith('.swift'))
if not sources:
    raise SystemExit("No Neumorphic Swift sources found")
for source in sources:
    sys.stdout.buffer.write(os.fsencode(source) + b'\0')
PY
[[ -s "$audit_dir/sources.list" ]] || { echo "Empty Neumorphic source list" >&2; exit 1; }
sources=()
while IFS= read -r -d '' source; do sources+=("$source"); done < "$audit_dir/sources.list"
xcrun swiftc -parse-as-library -emit-library -emit-module -module-name Neumorphic \
  -emit-module-path "$audit_dir/Neumorphic.swiftmodule" \
  -Xlinker -install_name -Xlinker "$audit_dir/libNeumorphic.dylib" \
  "${sources[@]}" -o "$audit_dir/libNeumorphic.dylib"
app_dir="$audit_dir/ControlChecks.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cat > "$app_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>org.gewill.OpenCCman.ControlChecks</string>
  <key>CFBundleExecutable</key><string>check-sizing</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
for locale in en zh-Hans zh-Hant; do
  cp -R "$repo_root/OpenCCman/$locale.lproj" "$app_dir/Resources/"
done
xcrun swiftc -I "$audit_dir" -L "$audit_dir" -lNeumorphic \
  "$repo_root/OpenCCman/View/AppControlStyle.swift" \
  "$repo_root/OpenCCman/View/SegmentView.swift" \
  "$repo_root/OpenCCman/extensions/StringExtensions.swift" \
  "$repo_root/Tests/Regression/SegmentLayoutChecks.swift" \
  "$repo_root/Tests/Regression/ControlSizingChecks.swift" -o "$app_dir/MacOS/check-sizing"
"$app_dir/MacOS/check-sizing"
