#!/bin/bash
set -euo pipefail

# Compiles OpenCCman/AppIcon.icon as Xcode does for both platforms and checks the
# layered light, dark and tinted icons and the flattened fallbacks for the
# deployment targets. actool can only render an Icon Composer file on macOS 26+.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if (( $(sw_vers -productVersion | cut -d. -f1) < 26 )); then
  echo "Compiling AppIcon.icon needs macOS 26 or later; this host runs $(sw_vers -productVersion)." >&2
  exit 1
fi
out_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-app-icon.XXXXXX")"
trap 'rm -rf "$out_dir"' EXIT

compile() {
  local platform="$1"
  shift
  mkdir -p "$out_dir/$platform"
  xcrun actool "$repo_root/OpenCCman/Assets.xcassets" "$repo_root/OpenCCman/AppIcon.icon" \
    --compile "$out_dir/$platform" --platform "$platform" --app-icon AppIcon \
    --output-partial-info-plist "$out_dir/$platform/partial.plist" \
    --output-format human-readable-text --errors --warnings "$@" > "$out_dir/$platform/actool.log"
  if grep -q "com.apple.actool.errors" "$out_dir/$platform/actool.log"; then
    cat "$out_dir/$platform/actool.log" >&2
    exit 1
  fi
  xcrun assetutil --info "$out_dir/$platform/Assets.car" > "$out_dir/$platform/assets.json"
}
compile macosx --minimum-deployment-target 12.0 --target-device mac
compile iphoneos --minimum-deployment-target 15.0 --target-device iphone --target-device ipad

python3 - "$out_dir" <<'PY'
import json, plistlib, sys
from pathlib import Path
out = Path(sys.argv[1])

def appearances(platform, kind):
    items = json.loads((out / platform / "assets.json").read_text())[1:]
    return {i.get("Appearance", "any") for i in items if i.get("Name") == "AppIcon" and i.get("AssetType") == kind}

# macOS 26+: layered icon in each appearance; macOS 12-15: icns.
assert (out / "macosx/AppIcon.icns").is_file(), "no AppIcon.icns for macOS 12-15"
mac = plistlib.loads((out / "macosx/partial.plist").read_bytes())
assert mac.get("CFBundleIconFile") == "AppIcon" and mac.get("CFBundleIconName") == "AppIcon", mac
stacks = appearances("macosx", "IconImageStack")
assert stacks >= {"NSAppearanceNameAqua", "NSAppearanceNameDarkAqua", "ISAppearanceTintable"}, stacks

# iOS 26+: layered icon; iOS 18: flattened any/dark/tinted; iOS 15-17: loose PNGs.
for name in ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"):
    assert (out / "iphoneos" / name).is_file(), f"no {name} for iOS 15-17"
primary = plistlib.loads((out / "iphoneos/partial.plist").read_bytes())["CFBundleIcons"]["CFBundlePrimaryIcon"]
assert primary["CFBundleIconName"] == "AppIcon", primary
flattened = appearances("iphoneos", "Icon Image")
assert flattened >= {"any", "UIAppearanceDark", "ISAppearanceTintable"}, flattened
stacks = appearances("iphoneos", "IconImageStack")
assert stacks >= {"UIAppearanceLight", "UIAppearanceDark", "ISAppearanceTintable"}, stacks
print("PASS: AppIcon.icon compiles for macOS 12+ and iOS 15+ with light, dark and tinted icons and flattened fallbacks")
PY
