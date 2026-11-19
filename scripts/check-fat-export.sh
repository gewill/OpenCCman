#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
mounts=()
cleanup() {
  local mounted
  for mounted in "${mounts[@]:-}"; do
    [[ -z "$mounted" ]] || hdiutil detach "$mounted" || return 1
  done
  rm -rf "$scratch"
}
trap cleanup EXIT
for format in ExFAT FAT32; do
  volume="$scratch/$format"
  mkdir "$volume"
  fs="$format"
  if [[ "$format" == FAT32 ]]; then fs="MS-DOS FAT32"; fi
  hdiutil create -size 300m -fs "$fs" -volname OCMTEST "$volume.dmg"
  hdiutil attach -nobrowse -mountpoint "$volume" "$volume.dmg"
  mounts+=("$volume")
  diskutil info "$volume" | grep -E "File System Personality: +$fs$"
done
OPENCCMAN_TEST_EXPORT_VOLUMES="$scratch/ExFAT:$scratch/FAT32" python3 "$root/scripts/check-core.py"
