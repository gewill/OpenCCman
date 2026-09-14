#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep logs and xcresult on failure as well as success. Caller may choose an artifact directory.
audit_dir="${1:-$(mktemp -d "${TMPDIR:-/tmp}/openccman-storekit.XXXXXX")}"
mkdir -p "$audit_dir"
printf 'StoreKit artifacts: %s\n' "$audit_dir"
python3 - "$repo_root" <<'PY'
import json, pathlib, sys, xml.etree.ElementTree as ET
root = pathlib.Path(sys.argv[1])
catalog = json.loads((root / 'Tests/StoreKit/Products.storekit').read_text())
products = catalog['products']
assert len(products) == 1 and products[0]['productID'] == 'ios_openccman_pro_lifetime_3'
assert products[0]['type'] == 'NonConsumable' and not catalog['subscriptionGroups']
assert products[0]['productID'] in (root / 'OpenCCman/IAPManager.swift').read_text()
scheme = ET.parse(root / 'OpenCCman.xcodeproj/xcshareddata/xcschemes/OpenCCman-StoreKit.xcscheme')
assert scheme.find('LaunchAction').get('buildConfiguration') == 'Debug'
reference = scheme.find('.//StoreKitConfigurationFileReference').get('identifier')
assert (root / 'OpenCCman.xcodeproj' / reference).resolve().is_file()
assert all(x.get('buildForArchiving') == 'NO' for x in scheme.findall('.//BuildActionEntry'))
print('PASS: local catalog and non-archiving Debug scheme')
PY
xcodebuild test \
  -project "$repo_root/Tests/StoreKit/StoreKitRegression.xcodeproj" \
  -scheme StoreKitRegression -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -derivedDataPath "$audit_dir/DerivedData" \
  -resultBundlePath "$audit_dir/StoreKit.xcresult" \
  > "$audit_dir/xcodebuild.log" 2>&1 || {
    tail -n 80 "$audit_dir/xcodebuild.log"
    exit 1
  }
python3 - "$audit_dir/xcodebuild.log" <<'PYLOG'
import pathlib, re, sys
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if re.search(r'Test Case .*passed|Executed|TEST SUCCEEDED', line):
        print(line)
PYLOG
