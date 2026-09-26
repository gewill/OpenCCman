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

# A failed assertion left VoiceOver enabled after one XCUITest run despite the
# test's defer. Independently restore the dedicated Simulator's prior state.
xcrun devicectl device info voiceover --device "$device_id" \
  --json-output "$result_dir/voiceover-before.json" >/dev/null
initial_voiceover="$(python3 - "$result_dir/voiceover-before.json" <<'PY'
import json, sys
print(str(json.load(open(sys.argv[1]))['result']['enabled']).lower())
PY
)"
restore_voiceover() {
  xcrun devicectl device info voiceover --device "$device_id" \
    --json-output "$result_dir/voiceover-after-test.json" >/dev/null || return 1
  local current
  current="$(python3 - "$result_dir/voiceover-after-test.json" <<'PY'
import json, sys
print(str(json.load(open(sys.argv[1]))['result']['enabled']).lower())
PY
)"
  if [[ "$current" != "$initial_voiceover" ]]; then
    if [[ "$initial_voiceover" == true ]]; then
      xcrun devicectl device settings voiceover --device "$device_id" --enable >/dev/null || return 1
    else
      xcrun devicectl device settings voiceover --device "$device_id" --disable >/dev/null || return 1
    fi
  fi
  xcrun devicectl device info voiceover --device "$device_id" \
    --json-output "$result_dir/voiceover-restored.json" >/dev/null || return 1
  python3 - "$result_dir/voiceover-restored.json" "$initial_voiceover" <<'PY'
import json, sys
actual = str(json.load(open(sys.argv[1]))['result']['enabled']).lower()
if actual != sys.argv[2]:
    raise SystemExit(f'VoiceOver restoration failed: expected {sys.argv[2]}, got {actual}')
PY
}
on_exit() {
  local result=$?
  trap - EXIT
  restore_voiceover || result=1
  exit "$result"
}
trap on_exit EXIT

xcodebuild -project "$repo_root/OpenCCman.xcodeproj" -scheme OpenCCman \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$result_dir/app-derived" -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace=YES build \
  > "$result_dir/app-build.log" 2>&1 || {
    tail -n 80 "$result_dir/app-build.log" >&2
    exit 1
  }

# Expose only the unsigned QA app's Documents directory to the native Files
# picker. The production Info.plist and file-sharing behavior are unchanged.
app_bundle="$result_dir/app-derived/Build/Products/Debug-iphonesimulator/OpenCCman.app"
plutil -insert UIFileSharingEnabled -bool YES "$app_bundle/Info.plist"

# Only this QA bundle is removed. A fresh install isolates the presentation
# preference and conversion quota for every run.
xcrun simctl uninstall "$device_id" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app_bundle"
qa_container="$(xcrun simctl get_app_container "$device_id" "$bundle_id" data)"
python3 - "$qa_container" <<'PY'
from pathlib import Path
import sys

documents = Path(sys.argv[1]) / 'Documents'
documents.mkdir(exist_ok=True)
(documents / 'success.txt').write_bytes('測試導入\r\n😀 café\r\n'.encode('utf-8'))
(documents / 'bad-encoding.txt').write_bytes(b'\xff\xfe\x80')
PY

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
