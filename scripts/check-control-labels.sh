#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-control-labels.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT

mkdir -p "$audit_dir/Labels.bundle/Contents/Resources"
cat > "$audit_dir/Labels.bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>org.gewill.OpenCCman.ControlLabelChecks</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
</dict></plist>
PLIST
for locale in en zh-Hans zh-Hant; do
  mkdir "$audit_dir/Labels.bundle/Contents/Resources/$locale.lproj"
  cp "$repo_root/OpenCCman/$locale.lproj/Localizable.strings" \
    "$audit_dir/Labels.bundle/Contents/Resources/$locale.lproj/Localizable.strings"
done

xcrun swiftc -g \
  "$repo_root/OpenCCman/extensions/StringExtensions.swift" \
  "$repo_root/Tests/Regression/ControlLabelChecks.swift" \
  -o "$audit_dir/check-control-labels"
"$audit_dir/check-control-labels" "$audit_dir/Labels.bundle"
