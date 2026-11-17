#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
extension="$repo_root/OpenCCmanTextAction"
project="$repo_root/OpenCCman.xcodeproj/project.pbxproj"
# The model's conversion behavior runs with the locked OpenCC package in
# scripts/check-core.py (TextActionChecks). This script checks the packaging.

fail() { echo "FAIL: $*" >&2; exit 1; }

# Free and unlimited, like the Shortcuts action: no purchase or quota code.
if grep -n -E 'TestNumbersPerDayManager|IAPManager|RevenueCat|Purchases|isPro' "$extension"/*.swift; then
  fail "the Share sheet action must not read purchases or the daily quota"
fi

# Every key the action shows exists in all three languages.
keys="$(grep -h -o -E '"text_action_[a-z_]+"' "$extension"/*.swift | sort -u)"
[[ -n "$keys" ]] || fail "no text_action keys found"
for language in en zh-Hans zh-Hant; do
  strings="$repo_root/OpenCCman/$language.lproj/Localizable.strings"
  for key in $keys '"Copy Result"' '"Cancel"' '"Done"' '"preset_simplified"' '"preset_traditional"' '"preset_taiwan"' '"preset_hong_kong"' '"file_error_size"' '"file_error_encoding"'; do
    grep -q "^$key = " "$strings" || fail "$key is missing from $language"
  done
done
python3 - "$extension/InfoPlist.xcstrings" <<'PYTHON'
import json, sys
names = json.load(open(sys.argv[1]))["strings"]["CFBundleDisplayName"]["localizations"]
missing = {"en", "zh-Hans", "zh-Hant"} - {k for k, v in names.items() if v["stringUnit"]["value"].strip()}
if missing:
    sys.exit(f"FAIL: action display name is missing {sorted(missing)}")
PYTHON

# The action accepts text only and stays an iOS-only embed.
plist="$extension/Info.plist"
[[ "$(plutil -extract NSExtension.NSExtensionPointIdentifier raw "$plist")" == com.apple.ui-services ]] \
  || fail "the extension must be an Action (com.apple.ui-services)"
[[ "$(plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule.NSExtensionActivationSupportsText raw "$plist")" == true ]] \
  || fail "the action must activate for text"
grep -q 'OpenCCmanTextAction.appex in Embed Foundation Extensions \*/ = {isa = PBXBuildFile; fileRef = [0-9A-F]* /\* OpenCCmanTextAction.appex \*/; platformFilter = ios;' "$project" \
  || fail "the action must be embedded for iOS only"

# Versions and identifiers stay in step with the app.
python3 - "$project" <<'PYTHON'
import re, sys
text = open(sys.argv[1]).read()
def values(key):
    return re.findall(rf"\b{key} = ([^;]+);", text)
for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET"):
    found = set(values(key))
    if len(found) != 1:
        sys.exit(f"FAIL: {key} differs between targets: {sorted(found)}")
ids = set(values("PRODUCT_BUNDLE_IDENTIFIER"))
if ids != {'"$(OPENCCMAN_BUNDLE_ID)"', '"$(OPENCCMAN_BUNDLE_ID).TextAction"'}:
    sys.exit(f"FAIL: bundle identifiers must derive from OPENCCMAN_BUNDLE_ID: {sorted(ids)}")
if set(values("OPENCCMAN_BUNDLE_ID")) != {"org.gewill.OpenCCman"}:
    sys.exit("FAIL: OPENCCMAN_BUNDLE_ID must be org.gewill.OpenCCman")
PYTHON

# A command-line PRODUCT_BUNDLE_IDENTIFIER gives the extension the app's own
# identifier and the simulator refuses to install it; QA builds override
# OPENCCMAN_BUNDLE_ID instead.
if grep -rn -E 'PRODUCT_BUNDLE_IDENTIFIER[=]' "$repo_root/scripts" "$repo_root/.github/workflows" --include='*.sh' --include='*.py' --include='*.yml'; then
  fail "override OPENCCMAN_BUNDLE_ID, not PRODUCT_BUNDLE_IDENTIFIER"
fi
echo "PASS: Share sheet action is free, iOS-only, text-only, localized in three languages, versioned with the app and safe for QA bundle overrides"
