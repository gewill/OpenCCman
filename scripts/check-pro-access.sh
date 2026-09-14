#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/openccman-pro-access.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
xcrun swiftc -O \
  "$repo_root/OpenCCman/Model/ProAccessUpdate.swift" \
  "$repo_root/OpenCCman/Model/TestNumbersPerDayManager.swift" \
  "$repo_root/Tests/Regression/QuotaSupport.swift" \
  "$repo_root/Tests/Regression/ProAccessChecks.swift" \
  -o "$audit_dir/check-pro-access"
"$audit_dir/check-pro-access"
python3 - "$repo_root" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
source = (root / 'OpenCCman/Scene/CustomerCenterScene.swift').read_text()
keys = set(re.findall(r'"(customer_center_[a-z_]+)"', source))
for locale in ('en', 'zh-Hans', 'zh-Hant'):
    strings = (root / f'OpenCCman/{locale}.lproj/Localizable.strings').read_text()
    for key in keys:
        assert re.search(r'"' + key + r'"\s*=\s*"[^"\n]+";', strings), (locale, key)
print('PASS: Customer Center localized keys in English, Simplified and Traditional Chinese')
PY
