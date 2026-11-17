#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-batch.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
# Pure queue and naming rules. Real file I/O, the coordinator and exact output
# comparison run with the locked OpenCC package in scripts/check-core.py.
xcrun swiftc -warnings-as-errors -swift-version 5 \
  "$repo_root/OpenCCman/Services/FileConversionPolicy.swift" \
  "$repo_root/OpenCCman/Model/BatchConversionPlan.swift" \
  "$repo_root/Tests/Regression/BatchConversionChecks.swift" -o "$audit_dir/check-batch"
"$audit_dir/check-batch"
# Batch is Pro only and must never reserve or spend the daily free quota.
if grep -n 'TestNumbersPerDayManager' "$repo_root/OpenCCman/Services/MacBatchConversionCoordinator.swift"; then
  echo "FAIL: batch conversion must not use the daily quota" >&2
  exit 1
fi
echo "PASS: batch conversion does not reference the daily quota"
