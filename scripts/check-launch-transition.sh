#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-launch-transition.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT

# Build for the app's macOS deployment target so availability problems show up here.
xcrun swiftc -O -target "$(uname -m)-apple-macos12.0" \
  "$repo_root/OpenCCman/Model/LaunchMotion.swift" \
  "$repo_root/OpenCCman/View/LaunchTransition.swift" \
  "$repo_root/OpenCCman/Model/WhatsNew.swift" \
  "$repo_root/Tests/Regression/LaunchTransitionChecks.swift" \
  -o "$audit_dir/check-launch-transition"
"$audit_dir/check-launch-transition"

# The app icon draws the same mark; its ring layers and dark colours must follow LaunchMark.
xcrun swiftc -O -target "$(uname -m)-apple-macos12.0" \
  "$repo_root/OpenCCman/Model/LaunchMotion.swift" \
  "$repo_root/scripts/render-brand-mark.swift" \
  -o "$audit_dir/render-brand-mark"
"$audit_dir/render-brand-mark" --check

python3 - "$repo_root" <<'PY'
import json, plistlib, sys
from pathlib import Path
root = Path(sys.argv[1])
launch = plistlib.loads((root / "OpenCCman/Info.plist").read_bytes())["UILaunchScreen"]
assets = root / "OpenCCman/Assets.xcassets"
assert (assets / f"{launch['UIColorName']}.colorset/Contents.json").is_file()
images = json.loads((assets / f"{launch['UIImageName']}.imageset/Contents.json").read_text())["images"]
files = [i for i in images if "filename" in i]
assert {(i["scale"], bool(i.get("appearances"))) for i in files} == {(s, d) for s in ("2x", "3x") for d in (False, True)}
for i in files:
    assert (assets / f"{launch['UIImageName']}.imageset" / i["filename"]).is_file(), i["filename"]
# The launch colour must equal the pinned Neumorphic surface, or the first frame jumps.
colors = json.loads((assets / f"{launch['UIColorName']}.colorset/Contents.json").read_text())["colors"]
values = [tuple(round(float(c["color"]["components"][k]), 3) for k in ("red", "green", "blue")) for c in colors]
assert values == [(0.925, 0.941, 0.953), (0.188, 0.192, 0.208)], values
print("PASS: launch screen colour and mark assets (light and dark, @2x and @3x)")
PY
