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

for item in manifest["assets"]:
    path = root / item["path"]
    data = path.read_bytes()
    assert len(data) == item["bytes"], item["path"]
    assert hashlib.sha256(data).hexdigest() == item["sha256"], item["path"]
    if path.suffix == ".png":
        with Image.open(path) as image:
            assert image.format == "PNG", item["path"]
            assert image.size == (item["width"], item["height"]), item["path"]

final = root / "marketing/preview/zh-Hans/01-convert-and-clear.mp4"
probe = json.loads(subprocess.check_output([
    "ffprobe", "-v", "error", "-show_entries",
    "format=duration:stream=codec_name,width,height,avg_frame_rate,sample_rate,channels",
    "-of", "json", str(final),
]))
assert 15 <= float(probe["format"]["duration"]) <= 30
video = next(stream for stream in probe["streams"] if stream["codec_name"] == "h264")
audio = next(stream for stream in probe["streams"] if stream["codec_name"] == "aac")
assert (video["width"], video["height"], video["avg_frame_rate"]) == (886, 1920, "30/1")
assert audio["channels"] == 2
print(f"PASS: {len(expected)} source and marketing assets, 21 titled screenshots, one final App Preview")
