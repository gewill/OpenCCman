#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
plutil -lint "$repo_root/OpenCCman.xcodeproj/project.pbxproj" \
  "$repo_root/OpenCCman/Info.plist" \
  "$repo_root/OpenCCman/OpenCCman.entitlements" \
  "$repo_root/OpenCCman/PrivacyInfo.xcprivacy"

while IFS= read -r -d '' source; do
  xcrun swiftc -frontend -parse "$source"
done < <(rg --files -0 -g '*.swift' "$repo_root/OpenCCman")

while IFS= read -r -d '' localization; do
  plutil -lint "$localization"
done < <(rg --files -0 -g '*.strings' "$repo_root/OpenCCman")
