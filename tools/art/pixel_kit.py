"""Minimal dependency-free pixel canvas used to author RigPop's built-in characters.

Only the standard library is used so the generator runs on any machine that can
build RigPop. ShapES are rasterised at 1x and hand-rounded; outlines are derived
from an alpha dilation so every part keeps the same 1 px contour.
"""

import struct
import zlib


class Canvas:
    def __init__(self, width, height):
        self.w = width
        self.h = height
        self.px = bytearray(width * height * 4)

    def clone(self):
        c = Canvas(self.w, self.h)
        c.px = bytearray(self.px)
        return c

    # --- primitives -----------------------------------------------------
    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.px[i:i + 4] = bytes(color)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            return tuple(self.px[i:i + 4])
        return (0, 0, 0, 0)

    def clear_pixel(self, x, y):
        self.set(x, y, (0, 0, 0, 0))

    def rect(self, x, y, w, h, color):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, color)

    def ellipse(self, cx, cy, rx, ry, color):
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (xx + 0.5 - cx) / max(rx, 0.001)
                dy = (yy + 0.5 - cy) / max(ry, 0.001)
                if dx * dx + dy * dy <= 1.0:
                    self.set(xx, yy, color)

    def poly(self, points, color):
        if len(points) < 3:
            return
        ys = [p[1] for p in points]
        for yy in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(points)):
                x1, y1 = points[i]
                x2, y2 = points[(i + 1) % len(points)]
                if (y1 <= yy + 0.5 < y2) or (y2 <= yy + 0.5 < y1):
                    t = (yy + 0.5 - y1) / (y2 - y1)
                    xs.append(x1 + t * (x2 - x1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for xx in range(int(round(xs[i])), int(round(xs[i + 1])) + 1):
                    self.set(xx, yy, color)

    def line(self, x1, y1, x2, y2, color, width=1):
        steps = int(max(abs(x2 - x1), abs(y2 - y1))) * 2 + 1
        for i in range(steps + 1):
            t = i / steps
            x = x1 + (x2 - x1) * t
            y = y1 + (y2 - y1) * t
            r = width // 2
            for oy in range(-r, r + 1):
                for ox in range(-r, r + 1):
                    self.set(int(round(x)) + ox, int(round(y)) + oy, color)

    # --- derived operations ---------------------------------------------
    def alpha_at(self, x, y):
        return self.get(x, y)[3]

    def mask(self):
        return [self.alpha_at(x, y) > 16 for y in range(self.h) for x in range(self.w)]

    def outline(self, color, diagonal=False):
        """Paint a 1 px contour around every opaque cluster."""
        solid = self.mask()
        for y in range(self.h):
            for x in range(self.w):
                if solid[y * self.w + x]:
                    continue
                neighbours = [
                    (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                ]
                if diagonal:
                    neighbours += [(x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1)]
                for nx, ny in neighbours:
                    if 0 <= nx < self.w and 0 <= ny < self.h and solid[ny * self.w + nx]:
                        self.set(x, y, color)
                        break

    def shade_region(self, box, color, threshold=40, predicate=None):
        """Recolour opaque pixels inside a box (used for soft inner shading)."""
        x0, y0, x1, y1 = box
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                if self.alpha_at(x, y) > threshold:
                    if predicate is None or predicate(x, y):
                        self.set(x, y, color)

    def erase(self, x, y, w, h):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.clear_pixel(xx, yy)

    def blit(self, other, dx, dy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.get(x, y)
                if c[3] > 0:
                    self.set(x + dx, y + dy, c)

    def crop(self, x, y, w, h):
        out = Canvas(w, h)
        for yy in range(h):
            for xx in range(w):
                out.set(xx, yy, self.get(x + xx, y + yy))
        return out

    def flip_x(self):
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.set(self.w - 1 - x, y, self.get(x, y))
        return out

    def used_rect(self):
        minx, miny, maxx, maxy = self.w, self.h, -1, -1
        for y in range(self.h):
            for x in range(self.w):
                if self.alpha_at(x, y) > 0:
                    minx = min(minx, x); maxx = max(maxx, x)
                    miny = min(miny, y); maxy = max(maxy, y)
        if maxx < 0:
            return (0, 0, 0, 0)
        return (minx, miny, maxx - minx + 1, maxy - miny + 1)

    def trim(self):
        x, y, w, h = self.used_rect()
        return self.crop(x, y, max(1, w), max(1, h))

    def to_png(self):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            raw += self.px[y * self.w * 4:(y + 1) * self.w * 4]
        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        header = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))

    def save(self, path):
        with open(path, "wb") as handle:
            handle.write(self.to_png())


def hexc(value):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def rgba(value, alpha):
    return (value[0], value[1], value[2], alpha)
