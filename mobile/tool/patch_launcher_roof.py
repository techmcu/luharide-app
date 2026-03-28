"""Roof sign '7, 8' (yellow on black) + fit to 1024² white canvas for launcher / in-app."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/branding/luharide_launcher_master.png"

# Tuned on 1376×768 master — black roof plate above yellow body (body starts ~y=531).
_ROOF = (574, 498, 640, 536)


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    draw = ImageDraw.Draw(im)
    x0, y0, x1, y1 = _ROOF
    draw.rounded_rectangle((x0, y0, x1, y1), radius=8, fill=(18, 18, 22, 255))
    draw.rounded_rectangle((x0, y0, x1, y1), radius=8, outline=(55, 55, 62, 255), width=1)

    try:
        font = ImageFont.truetype("arialbd.ttf", 26)
    except OSError:
        try:
            font = ImageFont.truetype("arial.ttf", 26)
        except OSError:
            font = ImageFont.load_default()

    text = "7, 8"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (x0 + x1) / 2 - tw / 2
    ty = (y0 + y1) / 2 - th / 2 - 1
    draw.text((tx, ty), text, fill=(255, 235, 59, 255), font=font)

    w, h = im.size
    inset = 0.9
    scale = min(1024 / w, 1024 / h) * inset
    nw, nh = int(w * scale), int(h * scale)
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    canvas.paste(resized, ((1024 - nw) // 2, (1024 - nh) // 2), resized)
    canvas.save(SRC, "PNG")
    print("Wrote", SRC, "1024², roof text patched")


if __name__ == "__main__":
    main()
