#!/usr/bin/env python3
"""Generate offline Android icons from the approved original image (Pillow)."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "mobile/prayer_times/assets/branding/app-icon.png"
RES = ROOT / "mobile/prayer_times/android_template/app/src/main/res"


def main():
    source = Image.open(SOURCE).convert("RGBA")
    for density, size in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
        ("xxhdpi", 144), ("xxxhdpi", 192),
    ]:
        target = RES / f"mipmap-{density}"
        target.mkdir(parents=True, exist_ok=True)
        source.resize((size, size), Image.Resampling.LANCZOS).save(
            target / "ic_launcher.png", optimize=True)
        # Android adaptive foreground canvas is 108dp; artwork fits the 66dp
        # safe area so circular and rounded-square launcher masks keep the text.
        canvas_size = round(size * 108 / 48)
        artwork_size = round(canvas_size * 66 / 108)
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        artwork = source.resize((artwork_size, artwork_size), Image.Resampling.LANCZOS)
        inset = (canvas_size - artwork_size) // 2
        canvas.alpha_composite(artwork, (inset, inset))
        canvas.save(target / "ic_launcher_foreground.png", optimize=True)


if __name__ == "__main__":
    main()
