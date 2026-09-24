#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <booted-dedicated-iOS-simulator-UDID> [result-directory]" >&2
  exit 2
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
device_id="$1"
result_dir="${2:-${TMPDIR:-/tmp}/openccman-whats-new-ui-$(date +%Y%m%d-%H%M%S)}"
bundle_id="org.gewill.OpenCCman.WhatsNewUITests"

if [[ -e "$result_dir" ]]; then
  echo "Result directory already exists: $result_dir" >&2
  exit 2
fi
mkdir -p "$result_dir"

if ! xcrun simctl list devices booted --json | python3 -c '
import json, sys
udid = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
sys.exit(0 if any(device["udid"] == udid for group in devices.values() for device in group) else 1)
' "$device_id"; then
  echo "Boot a dedicated iOS Simulator first: $device_id" >&2
  exit 2
fi

xcodebuild -project "$repo_root/OpenCCman.xcodeproj" -scheme OpenCCman \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$result_dir/app-derived" -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" build \
  > "$result_dir/app-build.log" 2>&1 || {
    tail -n 80 "$result_dir/app-build.log" >&2
    exit 1
  }

# Only this QA bundle is removed. A fresh install isolates the presentation
# preference and conversion quota for every run.
xcrun simctl uninstall "$device_id" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$result_dir/app-derived/Build/Products/Debug-iphonesimulator/OpenCCman.app"

xcodebuild test \
  -project "$repo_root/Tests/UI/WhatsNewPresentation/WhatsNewPresentation.xcodeproj" \
  -scheme WhatsNewPresentationTests \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$result_dir/test-derived" \
  -resultBundlePath "$result_dir/WhatsNewPresentation.xcresult" \
  CODE_SIGNING_ALLOWED=NO > "$result_dir/ui-tests.log" 2>&1 || {
    tail -n 100 "$result_dir/ui-tests.log" >&2
    exit 1
  }

rg 'Executed [0-9]+ tests|\*\* TEST SUCCEEDED \*\*' "$result_dir/ui-tests.log"
echo "Evidence: $result_dir"
