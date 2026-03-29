"""Build luharide_launcher_master.png: crop LR shield off, letterbox to 1024² (launcher only, not bundled in app)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/branding/luharide_launcher_master.png"
BUNDLED = Path(__file__).resolve().parent / "chatgpt_launcher_source.png"
CURSOR = Path(
    r"C:\Users\orahu\.cursor\projects\d-cur-luharide\assets\c__Users_orahu_AppData_Roaming_Cursor_User_workspaceStorage_1c890846b93f8dcbb992ff0f90a92b8d_images_ChatGPT_Image_Mar_29__2026__08_46_11_AM-63e9aa3e-0ac7-4e00-8433-669c3676ebec.png"
)
OUT = 1024
# First row where LR shield dominates (keep only circular scene above)
CROP_BOTTOM = 532


def main() -> None:
    src = BUNDLED if BUNDLED.is_file() else CURSOR
    if not src.is_file():
        raise SystemExit(f"Missing source. Put PNG at {BUNDLED} or Cursor path in script.")

    im = Image.open(src).convert("RGB")
    w, h = im.size
    cropped = im.crop((0, 0, w, min(CROP_BOTTOM, h)))
    cw, ch = cropped.size
    scale = min(OUT / cw, OUT / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGB", (OUT, OUT), (255, 255, 255))
    canvas.paste(resized, ((OUT - nw) // 2, (OUT - nh) // 2))

    DEST.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(DEST, "PNG", optimize=True)
    print("Wrote", DEST)


if __name__ == "__main__":
    main()
