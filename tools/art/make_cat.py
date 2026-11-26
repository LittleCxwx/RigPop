"""Generates the built-in 灵犀 (Lingxi) cat character used by RigPop templates.

Every part is drawn in one shared character space so cut-outs keep their offsets;
`make_cat.py` then converts each bounding box into part position/pivot values and
writes both the PNGs and `character.rigpop.json` for the built-in template.

Coordinate space: 96 x 96, ground line at y = 88, body centre x = 48.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pixel_kit import Canvas, hexc  # noqa: E402

W = H = 96
ORIGIN_X, ORIGIN_Y = 48, 88

OUT = hexc("#2b2c48")
OUT_SOFT = hexc("#4b4c6e")
WHITE = hexc("#fbfaf9")
WHITE_2 = hexc("#e7e3eb")
SHADE = hexc("#cdc9de")
SHADE_2 = hexc("#a9a4c4")
PINK = hexc("#d69da3")
PINK_2 = hexc("#b9808c")
BLUE = hexc("#6560ea")
BLUE_2 = hexc("#4742bd")
BLUE_3 = hexc("#8b88f2")
EYE = hexc("#3f57ad")
EYE_2 = hexc("#677cdb")
EYE_DARK = hexc("#232b58")
NOSE = hexc("#c98d9c")
MOUTH = hexc("#6b5b78")


def draw_body(c):
    """Sitting torso: narrow chest, wide hips, rounded bottom."""
    c.ellipse(48, 71, 15, 12, WHITE)
    c.rect(35, 58, 27, 14, WHITE)
    c.ellipse(48, 60, 12, 7, WHITE)
    # chest fluff
    c.ellipse(48, 63, 5, 4, WHITE_2)
    c.set(48, 68, SHADE)
    c.set(47, 69, SHADE)
    c.set(49, 69, SHADE)
    # side shading, left and right rims
    for x in range(30, 67):
        for y in range(54, 86):
            if not c.alpha_at(x, y):
                continue
            dx = abs(x + 0.5 - 48)
            if dx > 10.5:
                c.set(x, y, SHADE)
            elif dx > 8.5:
                c.set(x, y, WHITE_2)
    c.outline(OUT)


def draw_head(c):
    """Head with wide cheeks, side tufts and a small crown tuft."""
    c.ellipse(48, 33, 22, 19, WHITE)
    # crown tuft: three short spikes
    c.poly([(42, 16), (44, 10), (48, 15)], WHITE)
    c.poly([(49, 14), (53, 8), (55, 16)], WHITE)
    # cheek tufts: two spikes each side, pointing outward-down
    c.poly([(29, 38), (21, 41), (28, 44), (30, 43)], WHITE)
    c.poly([(67, 38), (75, 41), (68, 44), (66, 43)], WHITE)
    # lower shading
    for x in range(20, 77):
        for y in range(16, 58):
            if not c.alpha_at(x, y):
                continue
            dx = abs(x + 0.5 - 48) / 22.0
            dy = (y + 0.5 - 34) / 19.0
            rim = dx * dx + dy * dy
            if rim > 0.74 and dy > -0.3:
                c.set(x, y, SHADE)
    c.outline(OUT)


def draw_ear(c, flip=False):
    """Wide-based triangular ear with pink inner fur."""
    if flip:
        c.poly([(59, 24), (72, 4), (73, 26)], WHITE)
        c.poly([(63, 22), (70, 10), (71, 22)], PINK)
        c.set(69, 13, PINK_2)
        c.set(70, 16, PINK_2)
    else:
        c.poly([(24, 26), (37, 4), (38, 24)], WHITE)
        c.poly([(26, 22), (33, 10), (34, 22)], PINK)
        c.set(27, 17, PINK_2)
        c.set(28, 20, PINK_2)
    c.outline(OUT)


def draw_arm(c, flip=False):
    """Hanging paw with a rounded wrist; anchor at the shoulder."""
    cx = 62 if flip else 34
    c.ellipse(cx, 68, 5.5, 7, WHITE)
    c.ellipse(cx, 73, 5, 4, WHITE)
    edge = cx + 4 if flip else cx - 4
    for y in range(59, 78):
        c.set(edge, y, WHITE_2)
        c.set(edge + (1 if flip else -1), y, WHITE_2)
    c.outline(OUT)


def draw_leg(c, flip=False):
    """Sitting paw seen from the front with toe splits."""
    cx = 56 if flip else 40
    c.ellipse(cx, 82, 7, 5, WHITE)
    c.rect(cx - 6, 79, 13, 4, WHITE)
    c.outline(OUT)
    for x in (cx - 2, cx + 3):
        c.set(x, 85, SHADE_2)
    c.set(cx - 5, 84, WHITE_2)


def draw_tail(c):
    """Curled tail rising behind the body on the right, tip flicked outward."""
    for cx, cy, rr in ((62, 80, 4.4), (67, 77, 4.2), (71, 73, 4.0), (74, 68, 3.8),
                       (76, 63, 3.6), (76, 58, 3.5), (73, 54, 3.6), (69, 53, 3.8)):
        c.ellipse(cx, cy, rr, rr, WHITE)
    c.outline(OUT)
    for point in ((62, 78), (71, 73), (78, 63), (73, 56)):
        c.set(point[0], point[1], WHITE_2)
        c.set(point[0], point[1] + 1, WHITE_2)


def draw_scarf(c):
    """Neck wrap sitting under the chin."""
    c.ellipse(48, 55, 15, 6, BLUE)
    c.rect(33, 50, 30, 6, BLUE)
    # folded highlight on the left shoulder
    c.poly([(34, 51), (42, 50), (40, 58), (34, 57)], BLUE_3)
    # knot
    c.ellipse(36, 55, 4, 4, BLUE_2)
    c.outline(OUT)


def draw_scarf_tail(c):
    """Trailing ribbon: own part so it can be keyframed or driven by secondary motion."""
    c.poly([(33, 53), (22, 48), (12, 49), (18, 54), (14, 57), (26, 58), (32, 60)], BLUE)
    c.poly([(12, 49), (5, 47), (13, 53)], BLUE_2)
    c.poly([(30, 55), (19, 52), (25, 57)], BLUE_3)
    c.outline(OUT)


def draw_face(c):
    """Narrow, confident eyes drawn after the head outline so they stay crisp."""
    for side in (-1, 1):
        ex = 48 + side * 10
        # almond silhouette, wider than tall
        c.ellipse(ex, 36, 5.4, 6.0, EYE_DARK)
        c.erase(int(ex - 6), int(41.0), 13, 2)
        c.ellipse(ex, 35, 4.6, 5.2, EYE)
        c.ellipse(ex - side * 0.8, 36.5, 2.8, 3.4, EYE_2)
        # upper lid
        c.line(ex - 6, 31, ex + 6, 31, OUT, 1)
        c.line(ex - 5, 32, ex + 5, 32, EYE_DARK, 1)
        # highlight
        c.set(int(ex - side * 2), 33, (255, 255, 255, 255))
        c.set(int(ex - side * 1), 33, (255, 255, 255, 255))
        c.set(int(ex - side * 2), 34, (255, 255, 255, 255))
    # nose + mouth
    c.poly([(46, 46), (50, 46), (48, 48)], NOSE)
    c.set(48, 49, MOUTH)
    c.set(47, 50, MOUTH)
    c.set(49, 50, MOUTH)
    # whisker dots, kept subtle so they do not read as a band
    for x, y in ((33, 43), (33, 47), (34, 45), (62, 43), (62, 47), (61, 45)):
        c.set(x, y, SHADE_2)


# id, parent, anchor (character space), z, display name, draw function
PARTS = [
    ("scarf_tail", "body", (34, 56), -2, "围巾飘带", draw_scarf_tail),
    ("tail", "body", (58, 78), -1, "尾巴", draw_tail),
    ("leg_l", "body", (40, 76), 0, "左爪", lambda c: draw_leg(c, False)),
    ("leg_r", "body", (56, 76), 0, "右爪", lambda c: draw_leg(c, True)),
    ("body", "", (48, 74), 1, "身体", draw_body),
    ("scarf", "body", (48, 55), 2, "围巾", draw_scarf),
    ("arm_l", "body", (32, 61), 3, "左臂", lambda c: draw_arm(c, False)),
    ("arm_r", "body", (64, 61), 3, "右臂", lambda c: draw_arm(c, True)),
    ("ear_l", "head", (30, 20), 4, "左耳", lambda c: draw_ear(c, False)),
    ("ear_r", "head", (66, 20), 4, "右耳", lambda c: draw_ear(c, True)),
    ("head", "body", (48, 52), 5, "头部", None),
]


def build_parts():
    """Draw each part on its own canvas, returning images plus placement data."""
    result = []
    for part_id, parent, anchor, z, title, draw in PARTS:
        canvas = Canvas(W, H)
        if part_id == "head":
            draw_head(canvas)
            draw_face(canvas)
        else:
            draw(canvas)
        x, y, w, h = canvas.used_rect()
        image = canvas.crop(x, y, max(1, w), max(1, h))
        result.append({
            "id": part_id,
            "parent": parent,
            "title": title,
            "z": z,
            "anchor": anchor,
            "offset": (x, y),
            "image": image,
        })
    return result


def compose(parts):
    canvas = Canvas(W, H)
    for part in sorted(parts, key=lambda p: p["z"]):
        canvas.blit(part["image"], part["offset"][0], part["offset"][1])
    return canvas


def upscale(canvas, factor):
    out = Canvas(canvas.w * factor, canvas.h * factor)
    for y in range(out.h):
        for x in range(out.w):
            out.set(x, y, canvas.get(x // factor, y // factor))
    return out


# The standard rig: every built-in character uses these ids so preset actions and
# imported artwork can be retargeted without hand-placing parts again.
RIG_ID = "rigpop.quadruped.v1"
ANCHORS = {part[0]: part[2] for part in PARTS}


def emit_template(out_dir):
    """Write PNGs plus a character.rigpop.json that the editor loads as a template."""
    import shutil

    parts = build_parts()
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(os.path.join(out_dir, "assets"))
    model = {
        "format_version": 1,
        "id": "character_lingxi_template",
        "name": "灵犀",
        "rig": RIG_ID,
        "parts": [],
        "actions": [],
        "palette": ["2b2c48", "fbfaf9", "e7e3eb", "c2bfd7", "655eea", "4742bd",
                    "8b88f2", "d69da3", "3f57ad", "677cdb"],
        "bindings": [],
        "game": {"speed": 115.0, "collision_radius": 9.0},
        "desktop": {"scale": 4, "always_on_top": True, "wander": False},
        "modules": {},
    }
    for part in parts:
        x, y = part["offset"]
        ax, ay = part["anchor"]
        parent = part["parent"]
        px, py = ANCHORS[parent] if parent else (ORIGIN_X, ORIGIN_Y)
        asset = "assets/%s.png" % part["id"]
        part["image"].save(os.path.join(out_dir, "assets", "%s.png" % part["id"]))
        model["parts"].append({
            "id": part["id"],
            "role": part["id"],
            "name": part["title"],
            "parent": parent,
            "position": [ax - px, ay - py],
            "pivot": [ax - x, ay - y],
            "rotation": 0.0,
            "z": part["z"],
            "visible": True,
            "asset": asset,
        })
    with open(os.path.join(out_dir, "character.rigpop.json"), "w", encoding="utf-8") as handle:
        json.dump(model, handle, ensure_ascii=False, indent="\t")
    return model


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    project = os.path.abspath(os.path.join(here, "..", ".."))
    template_dir = os.path.join(project, "assets", "templates", "lingxi")
    model = emit_template(template_dir)
    compose(build_parts()).save(os.path.join(here, "preview_character.png"))
    upscale(compose(build_parts()), 5).save(os.path.join(here, "preview_x5.png"))
    print("template:", template_dir, len(model["parts"]), "parts")
    for part in build_parts():
        print(part["id"], part["offset"], part["image"].w, part["image"].h)
