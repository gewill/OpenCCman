#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-quota.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT

xcrun swiftc -O \
  "$repo_root/OpenCCman/Model/TestNumbersPerDayManager.swift" \
  "$repo_root/Tests/Regression/QuotaSupport.swift" \
  "$repo_root/Tests/Regression/QuotaChecks.swift" \
  -o "$audit_dir/check-quota"

"$audit_dir/check-quota"
