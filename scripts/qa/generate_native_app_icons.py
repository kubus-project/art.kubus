"""Regenerate native launcher icons from the approved app logo.

Requires Pillow (`python -m pip install Pillow`). Both native icon catalogs
place transparent parts of the official light-mode logo on white, keeping the
black mark visible against light or dark launcher surfaces.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "images" / "logo_black.png"
IOS_CATALOG = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def main() -> None:
    with Image.open(SOURCE) as source_file:
        source = source_file.convert("RGBA")

    with (IOS_CATALOG / "Contents.json").open(encoding="utf-8") as stream:
        catalog = json.load(stream)

    for entry in catalog["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        logical_size = float(entry["size"].split("x", maxsplit=1)[0])
        scale = float(entry["scale"].removesuffix("x"))
        pixels = round(logical_size * scale)
        resized = source.resize((pixels, pixels), Image.Resampling.LANCZOS)
        opaque = Image.new("RGB", (pixels, pixels), "white")
        opaque.paste(resized, mask=resized.getchannel("A"))
        opaque.save(IOS_CATALOG / filename, format="PNG", optimize=True)

    for directory, pixels in ANDROID_SIZES.items():
        resized = source.resize((pixels, pixels), Image.Resampling.LANCZOS)
        opaque = Image.new("RGB", (pixels, pixels), "white")
        opaque.paste(resized, mask=resized.getchannel("A"))
        opaque.save(ANDROID_RES / directory / "ic_launcher.png", format="PNG", optimize=True)


if __name__ == "__main__":
    main()
