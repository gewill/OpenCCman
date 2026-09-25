#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-editor-scroll.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc -warnings-as-errors -D WORKSPACE_SCROLL_CHECKS \
  "$repo_root/OpenCCman/Model/WorkspaceEditorReadingState.swift" \
  "$repo_root/OpenCCman/View/WorkspaceScrollKeeper.swift" \
  "$repo_root/Tests/Regression/EditorScrollChecks.swift" \
  -o "$audit_dir/check-editor-scroll"
"$audit_dir/check-editor-scroll"
