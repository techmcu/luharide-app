"""Copy Gemini launcher PNG, remove bottom-right AI sparkle, write luharide_launcher_master.png."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/branding/luharide_launcher_master.png"
BUNDLED = Path(__file__).resolve().parent / "gemini_launcher_source.png"
CURSOR_SRC = Path(
    r"C:\Users\orahu\.cursor\projects\d-cur-luharide\assets\c__Users_orahu_AppData_Roaming_Cursor_User_workspaceStorage_1c890846b93f8dcbb992ff0f90a92b8d_images_Gemini_Generated_Image_14ahdn14ahdn14ah-be7fd10f-7c02-4c24-8b47-8ba145a0dbf9.png"
)


def main() -> None:
    src = BUNDLED if BUNDLED.is_file() else CURSOR_SRC
    if not src.is_file():
        raise SystemExit(f"Source not found. Put Gemini PNG at {BUNDLED} or Cursor path in script.")
    im = Image.open(src).convert("RGB")
    w, h = im.size

    # Clean outer margin (bottom-left): no AI sparkle there
    ref = im.crop((0, max(0, h - 200), min(220, w), h))
    med = ImageStat.Stat(ref).median
    fill = tuple(int(x) for x in med[:3])

    # AI sparkle only in outer corner — keep pad small so icon white frame is not touched
    pad = min(100, int(min(w, h) * 0.1))
    ImageDraw.Draw(im).rectangle([w - pad, h - pad, w, h], fill=fill)

    im.save(DEST, "PNG", optimize=True)
    print("Wrote", DEST, im.size, "fill", fill)


if __name__ == "__main__":
    main()
