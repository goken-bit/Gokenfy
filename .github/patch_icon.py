#!/usr/bin/env python3
"""Overwrite flutter create's default launcher icons with the Zen icons.

CI regenerates android/ from scratch each build, so after `flutter create` we
copy the committed icon PNGs (rendered by generate_icon.py) into every mipmap
density, replace the adaptive-icon foregrounds, and force a dark adaptive
background so the icon looks consistent on API 26+ launchers.
"""
import os
import shutil

RES = "android/app/src/main/res"
ICONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")

DENSITIES = ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]

# Names: (generated base filename -> source filename)
PLAIN = "ic_launcher.png"
ROUND = "ic_launcher_round.png"
FOREGROUND = "ic_launcher_foreground.png"

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

BACKGROUND_COLOR = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#080A0A</color>
</resources>
"""


def patch() -> None:
    for density in DENSITIES:
        mipmap = os.path.join(RES, f"mipmap-{density}")
        if not os.path.isdir(mipmap):
            continue
        _copy(f"{ICONS}/ic_launcher-{density}.png", os.path.join(mipmap, PLAIN))
        _copy(f"{ICONS}/ic_launcher_round-{density}.png", os.path.join(mipmap, ROUND))
        _copy(
            f"{ICONS}/ic_launcher_foreground-{density}.png",
            os.path.join(mipmap, FOREGROUND),
        )

    # Force a dark background for the adaptive icon on API 26+.
    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w") as f:
        f.write(BACKGROUND_COLOR)

    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        adaptive = os.path.join(RES, "mipmap-anydpi-v26", name)
        os.makedirs(os.path.dirname(adaptive), exist_ok=True)
        with open(adaptive, "w") as f:
            f.write(ADAPTIVE_XML)

    print("Zen launcher icons installed")


def _copy(src: str, dst: str) -> None:
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"  {os.path.relpath(dst, 'android')}")


if __name__ == "__main__":
    patch()
