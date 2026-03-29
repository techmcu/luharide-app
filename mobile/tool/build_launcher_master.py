"""Build luharide_launcher_master.png for Android/iOS launcher only (not bundled in Flutter assets)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/branding/luharide_launcher_master.png"
BUNDLED = Path(__file__).resolve().parent / "pin_road_launcher_source.png"
CURSOR = Path(
    r"C:\Users\orahu\.cursor\projects\d-cur-luharide\assets\c__Users_orahu_AppData_Roaming_Cursor_User_workspaceStorage_1c890846b93f8dcbb992ff0f90a92b8d_images_ChatGPT_Image_Mar_29__2026__09_33_26_AM-1e3ddb2e-2268-4811-acfc-a35641995aeb.png"
)
OUT = 1024


def main() -> None:
    src = BUNDLED if BUNDLED.is_file() else CURSOR
    if not src.is_file():
        raise SystemExit(f"Missing source. Put PNG at {BUNDLED} or update CURSOR in script.")

    im = Image.open(src).convert("RGB")
    w, h = im.size
    # Cover crop to OUT² so art fills the icon (no letterboxing shrink).
    scale = max(OUT / w, OUT / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - OUT) // 2
    top = (nh - OUT) // 2
    out = resized.crop((left, top, left + OUT, top + OUT))

    DEST.parent.mkdir(parents=True, exist_ok=True)
    out.save(DEST, "PNG", optimize=True)
    print("Wrote", DEST, "from", src.name)


if __name__ == "__main__":
    main()
