#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-window-reopen.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc \
  "$repo_root/OpenCCman/Model/MainWindowReopenController.swift" \
  "$repo_root/Tests/Regression/MainWindowReopenChecks.swift" \
  -o "$audit_dir/check-window-reopen"
"$audit_dir/check-window-reopen"
