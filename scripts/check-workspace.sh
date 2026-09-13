#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-workspace.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc "$repo_root/OpenCCman/Model/WorkspaceLayout.swift" \
  "$repo_root/Tests/Regression/WorkspaceChecks.swift" -o "$audit_dir/check-workspace"
"$audit_dir/check-workspace"
