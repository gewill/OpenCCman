#!/usr/bin/env python3
"""Verify the immutable media candidate against its capture manifest."""

import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent
manifest = json.loads((root / "manifest.json").read_text())
expected = {item["path"] for item in manifest["assets"]}
actual = {
    path.relative_to(root).as_posix()
    for parent in (root / "raw", root / "marketing")
    for path in parent.rglob("*") if path.is_file()
}
assert expected == actual, f"Missing or extra assets: {expected ^ actual}"
assert set(manifest.get("sourceOverrides", {})) <= expected, "A source override names no asset"

for item in manifest["assets"]:
    path = root / item["path"]
    data = path.read_bytes()
    assert len(data) == item["bytes"], item["path"]
    assert hashlib.sha256(data).hexdigest() == item["sha256"], item["path"]
    if path.suffix == ".png":
        with Image.open(path) as image:
            assert image.format == "PNG", item["path"]
            assert image.size == (item["width"], item["height"]), item["path"]
            if item["path"].startswith(("marketing/ipad/", "marketing/mac/")):
                assert image.mode == "RGB", item["path"]

expected_previews = {
    "01-convert-and-clear.mp4": (886, 1920),
    "02-ipad-workspace.mp4": (1200, 1600),
    "03-mac-workspace.mp4": (1920, 1080),
}
for name, size in expected_previews.items():
    final = root / "marketing/preview/zh-Hans" / name
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,profile,level,width,height,avg_frame_rate,sample_rate,channels",
        "-of", "json", str(final),
    ]))
    assert 15 <= float(probe["format"]["duration"]) <= 30, name
    video = next(stream for stream in probe["streams"] if stream["codec_name"] == "h264")
    audio = next(stream for stream in probe["streams"] if stream["codec_name"] == "aac")
    assert (video["width"], video["height"], video["avg_frame_rate"]) == (*size, "30/1"), name
    assert video["level"] <= 40 and audio["channels"] == 2 and audio["sample_rate"] == "48000", name

assert len(list((root / "marketing").rglob("*.png"))) == 30
assert len(list((root / "raw").rglob("*.png"))) == 30
print(f"PASS: {len(expected)} source and marketing assets, 30 titled screenshots, three final App Previews")
