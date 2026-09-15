#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-workspace-editor.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc -warnings-as-errors -swift-version 5 -target "$(uname -m)-apple-macos11.0" \
  "$repo_root/OpenCCman/View/WorkspaceScrollKeeper.swift" \
  "$repo_root/OpenCCman/View/WorkspaceTextEditor.swift" \
  "$repo_root/OpenCCman/extensions/StringExtensions.swift" \
  "$repo_root/Tests/Regression/WorkspaceTextEditorChecks.swift" \
  -o "$audit_dir/check-workspace-editor"
"$audit_dir/check-workspace-editor"
