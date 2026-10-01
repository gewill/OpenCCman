#!/usr/bin/env python3
"""Refresh hashes and media properties after regenerating this candidate."""

import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent
path = root / "manifest.json"
manifest = json.loads(path.read_text())
source = manifest["candidateCommit"]
# Assets re-captured from a later source name it here; everything else keeps the candidate.
overrides = manifest.get("sourceOverrides", {})
renderer = root.parents[2] / "scripts/store-assets/render-marketing-screenshots.swift"
manifest["rendererSHA256"] = hashlib.sha256(renderer.read_bytes()).hexdigest()
assets = []

for parent in (root / "marketing", root / "raw"):
    for file in sorted(p for p in parent.rglob("*") if p.is_file()):
        relative = file.relative_to(root).as_posix()
        contents = file.read_bytes()
        item = {
            "path": relative,
            "bytes": len(contents),
            "sha256": hashlib.sha256(contents).hexdigest(),
        }
        if file.suffix == ".png":
            with Image.open(file) as image:
                item.update(width=image.width, height=image.height, format=image.format)
        elif file.suffix in (".mp4", ".mov"):
            probe = json.loads(subprocess.check_output([
                "ffprobe", "-v", "error", "-show_entries",
                "format=duration:stream=codec_name,width,height,avg_frame_rate,sample_rate,channels,profile,level",
                "-of", "json", str(file),
            ]))
            item["durationSeconds"] = float(probe["format"]["duration"])
            item["streams"] = probe["streams"]
        if relative != "raw/marketing-copy.json":
            item["uiSourceCommit"] = overrides.get(relative, source)
        assets.append(item)

manifest["assets"] = assets
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(f"Updated {path} with {len(assets)} assets")
