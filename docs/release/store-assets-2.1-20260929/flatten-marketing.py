#!/usr/bin/env python3
"""Flatten newly captured iPad and Mac marketing screenshots for App Store Connect."""

from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent / "marketing"
paths = sorted(path for family in ("ipad", "mac") for path in (root / family).rglob("*.png"))
for path in paths:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        opaque = Image.new("RGB", rgba.size, "white")
        opaque.paste(rgba, mask=rgba.getchannel("A"))
        opaque.save(path, format="PNG", optimize=True)
print(f"Flattened {len(paths)} iPad and Mac screenshots")
