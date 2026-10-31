#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-diff.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc -warnings-as-errors -swift-version 5 \
  "$repo_root/OpenCCman/Model/ConversionDiff.swift" \
  "$repo_root/OpenCCman/Model/ConversionDiffSnapshot.swift" \
  "$repo_root/Tests/Regression/ConversionDiffChecks.swift" -o "$audit_dir/check-diff"
"$audit_dir/check-diff"
