#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-window-sizing.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc "$repo_root/OpenCCman/Model/MainWindowGeometry.swift" \
  "$repo_root/Tests/Regression/MainWindowGeometryChecks.swift" -o "$audit_dir/check-window-sizing"
"$audit_dir/check-window-sizing"
xcrun swiftc "$repo_root/OpenCCman/Model/MainWindowGeometry.swift" \
  "$repo_root/OpenCCman/View/MainWindowSizing.swift" \
  "$repo_root/Tests/Regression/MainWindowNativeChecks.swift" -o "$audit_dir/check-native-window"
"$audit_dir/check-native-window"
"$audit_dir/check-native-window" restore
