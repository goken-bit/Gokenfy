#!/usr/bin/env python3
"""Generate the "Zen" app icon (enso ring) as plain + round launcher icons.

Pure-stdlib PNG writer (no Pillow). Run locally, commit the PNGs under
.github/icons/, then patch_icon.py applies them in CI after `flutter create`.
"""
import math
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")

DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Accent green palette (Spotify-inspired).
BG_TOP = (24, 32, 30)      # dark green-charcoal
BG_BOT = (8, 10, 10)       # near black
RING_A = (31, 215, 96)     # bright accent
RING_B = (120, 230, 160)   # soft light green
DOT = (230, 252, 238)      # near-white green

SS = 2  # supersample factor for anti-aliasing


def _clamp(v: float) -> int:
    return max(0, min(255, int(round(v))))


def _lerp(a, b, t):
    return a + (b - a) * t


def pixel_color(px: float, py: float, size: float, safe: bool) -> tuple:
    """Return (r,g,b) for a point in a [0,size] square. safe => adaptive-foreground crop."""
    cx = size / 2.0
    cy = size / 2.0

    # Vertical background gradient.
    t = py / size
    r = _lerp(BG_TOP[0], BG_BOT[0], t)
    g = _lerp(BG_TOP[1], BG_BOT[1], t)
    b = _lerp(BG_TOP[2], BG_BOT[2], t)

    # Enso ring geometry. In "safe" mode shrink to fit the adaptive safe zone.
    scale = 0.62 if safe else 1.0
    ring_r = size * 0.32 * scale
    ring_w = size * 0.055 * scale
    gap_from = math.radians(60)     # open toward bottom-right
    gap_to = math.radians(105)

    dx = px - cx
    dy = py - cy
    dist = math.hypot(dx, dy)

    # Soft glow under the ring.
    glow_r = ring_r + ring_w * 3
    if dist < glow_r:
        gx = 1.0 - dist / glow_r
        glow = 0.25 * gx * gx
        r = _lerp(r, RING_A[0] * 0.5, glow)
        g = _lerp(g, RING_A[1], glow)
        b = _lerp(b, RING_A[2] * 0.5, glow)

    # Ring coverage (anti-aliased band).
    half = ring_w / 2.0
    inner = ring_r - half
    outer = ring_r + half
    if inner < dist < outer:
        band = min(1.0, outer - dist, dist - inner) / half
        # Gradient around the circumference.
        ang = math.atan2(dy, dx)
        t2 = (math.sin(ang) + 1) / 2
        ca = _lerp(RING_A[0], RING_B[0], t2)
        cg = _lerp(RING_A[1], RING_B[1], t2)
        cb = _lerp(RING_A[2], RING_B[2], t2)
        # Gap cutout.
        gap = 0.0
        if gap_from < ang < gap_to:
            gap = 1.0 - min(1.0, (ang - gap_from) / 0.06, (gap_to - ang) / 0.06)
        ring_cov = band * (1.0 - gap)
        r = _lerp(r, ca, ring_cov)
        g = _lerp(g, cg, ring_cov)
        b = _lerp(b, cb, ring_cov)

    # Center dot.
    dot_r = size * 0.045 * scale
    if dist < dot_r:
        dc = 1.0 - dist / dot_r
        r = _lerp(r, DOT[0], dc)
        g = _lerp(g, DOT[1], dc)
        b = _lerp(b, DOT[2], dc)

    return (_clamp(r), _clamp(g), _clamp(b))


def render(size: int, safe: bool) -> bytes:
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter: none
        for x in range(size):
            acc = [0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    px = x + (sx + 0.5) / SS
                    py = y + (sy + 0.5) / SS
                    c = pixel_color(px, py, size, safe)
                    acc[0] += c[0]
                    acc[1] += c[1]
                    acc[2] += c[2]
            n = SS * SS
            raw += bytes((_clamp(acc[0] / n), _clamp(acc[1] / n), _clamp(acc[2] / n)))
    return bytes(raw)


def write_png(path: str, size: int, raw: bytes) -> None:
    def chunk(typ: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # 8-bit RGB
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print(f"wrote {path} ({size}x{size})")


def main() -> None:
    for density, size in DENSITIES.items():
        write_png(os.path.join(OUT, f"ic_launcher-{density}.png"), size, render(size, False))
        write_png(os.path.join(OUT, f"ic_launcher_round-{density}.png"), size, render(size, False))
        # Adaptive foreground uses the same design kept inside the safe zone.
        write_png(
            os.path.join(OUT, f"ic_launcher_foreground-{density}.png"),
            size,
            render(size, True),
        )


if __name__ == "__main__":
    main()
