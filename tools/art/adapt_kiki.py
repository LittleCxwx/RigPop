"""Prepare Tyson Tan's licensed Chibi Kiki II as a full-art RigPop template.

No character art is generated or redrawn here. The source's alpha components
separate the figure from the decorative lettering and stars without keying.
"""

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/art/sources/kiki/chibi-ii.png"
OUTPUT = ROOT / "assets/templates/kiki"
TITLE = "Kiki \u00b7 Q\u7248\u8d5b\u535a\u677e\u9f20"
PAGE = "https://krita.org/en/about/mascot/"
URL = "https://krita.org/images/pages/electrichearts_20200928A_kiki_a_trans_EN.png"


def action(ident, title, count=32, fps=16, loop=True, overlay=False):
    return {"id": ident, "name": title, "frames": count, "fps": fps,
            "loop": loop, "overlay": overlay, "priority": 0,
            "conflict": "replace", "lock_movement": False, "tracks": {}}


def animate(clip, motion):
    clip["tracks"]["body"] = [
        {"frame": frame, "position": [round(x, 3), round(y, 3)], "rotation": round(angle, 3)}
        for frame in range(clip["frames"])
        for x, y, angle in [motion(frame / max(1, clip["frames"] - 1))]
    ]
    return clip


def make_actions():
    tau = math.tau
    clips = [
        animate(action("idle", "\u60ac\u6d6e\u5f85\u673a"),
                lambda t: (0, -2 * (1 - math.cos(tau * t)), math.sin(tau * t) * 1.2)),
        animate(action("walk", "\u6f02\u6d6e\u79fb\u52a8", 24),
                lambda t: (0, -3 * (1 - math.cos(tau * t)), math.sin(tau * t) * 2)),
        animate(action("run", "\u8f7b\u5feb\u6f02\u6d6e", 20),
                lambda t: (math.sin(tau * t) * 1.5, -4 * (1 - math.cos(tau * t)), math.sin(tau * t) * 3)),
        animate(action("wave", "\u6447\u6446\u95ee\u5019", 32, loop=False, overlay=True),
                lambda t: (0, -3 * math.sin(math.pi * t) ** 2,
                           math.sin(3 * tau * t) * math.sin(math.pi * t) * 3)),
        animate(action("nod", "\u6b6a\u5934\u81f4\u610f", 24, loop=False, overlay=True),
                lambda t: (0, 2 * math.sin(math.pi * t) ** 2, -4 * math.sin(math.pi * t) ** 2)),
        animate(action("jump", "\u8df3\u8dc3", 24, loop=False),
                lambda t: (0, -20 * math.sin(math.pi * t) ** 2, -3 * math.sin(tau * t))),
    ]
    return clips


def prepare():
    (OUTPUT / "assets").mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    rgba = np.asarray(source)
    labels, count = ndimage.label(rgba[:, :, 3] > 8)
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    figure_id = int(areas.argmax())
    ys, xs = np.nonzero(labels == figure_id)
    bounds = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
    # Include anti-aliased edge pixels belonging to this figure, never the logo.
    expanded = ndimage.binary_dilation(labels == figure_id, iterations=3)
    figure = rgba.copy()
    figure[:, :, 3] = np.where(expanded, rgba[:, :, 3], 0)
    master = Image.fromarray(figure).crop(tuple(bounds))
    master.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    master.save(OUTPUT / "master.png")
    height = 240
    width = round(master.width * height / master.height)
    runtime = master.resize((width, height), Image.Resampling.LANCZOS)
    runtime.save(OUTPUT / "assets/body.png")
    runtime.save(OUTPUT / "preview.png")
    model = {
        "format_version": 1, "id": "template_kiki", "name": TITLE, "rig": "",
        "parts": [{"id": "body", "name": "Kiki \u5b8c\u6574\u7acb\u7ed8", "role": "body", "parent": "",
                   "position": [0, -120], "pivot": [width / 2, 120], "rotation": 0,
                   "z": 0, "visible": True, "asset": "assets/body.png"}],
        "actions": make_actions(), "palette": ["ffffff", "cce5fa", "a9f5fc", "ed93b5", "bf5182", "303638"],
        "bindings": [{"key": key, "gesture": "hold", "command": command} for key, command in
                     [("A", "move_left"), ("D", "move_right"), ("W", "move_up"), ("S", "move_down")]]
                    + [{"key": "Space", "gesture": "tap", "command": "wave"}],
        "game": {"speed": 115, "collision_radius": 16, "visual_scale": 0.75},
        "desktop": {"scale": 1, "always_on_top": True, "wander": False},
        "modules": {"rigpop.art": {
            "source": "Tyson Tan / Chibi Kiki II", "author": "Tyson Tan", "art_source": "existing",
            "license": "CC-BY-SA-4.0", "url": PAGE, "image_url": URL,
            "texture_filter": "linear", "animation": "whole-illustration transforms",
            "changes": "Figure isolated from lettering and sparkles, cropped and resized; root motion authored in RigPop."
        }}
    }
    (OUTPUT / "character.rigpop.json").write_text(json.dumps(model, ensure_ascii=False, indent=2), encoding="utf-8")
    provenance = {"art_source": "existing", "route": "Krita official mascot gallery",
                  "author": "Tyson Tan", "title": "Chibi Kiki II (2019 Sketch, 2025 Cleanup)",
                  "license": "CC-BY-SA-4.0", "source_url": URL, "license_source": PAGE,
                  "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  "source_dimensions": source.size, "figure_bounds": bounds,
                  "master_dimensions": master.size, "runtime_dimensions": runtime.size,
                  "alpha_source": "original native transparency", "component_count": count,
                  "animation": "whole-illustration transforms, not articulated limb animation",
                  "changes": model["modules"]["rigpop.art"]["changes"]}
    (OUTPUT / "provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    board = Image.new("RGB", (900, 620), "#f1f4f6")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    draw.text((30, 20), "CHIBI KIKI II  /  TYSON TAN  /  CC BY-SA 4.0", font=font, fill="#29353a")
    draw.text((30, 50), "Existing artwork adapted for RigPop. Full-illustration motion.", font=small, fill="#57666c")
    large = master.copy()
    large.thumbnail((410, 490), Image.Resampling.LANCZOS)
    board.paste(large, (30 + (410 - large.width) // 2, 92), large)
    draw.rectangle((460, 90, 870, 580), fill="#28282c")
    board.paste(large, (460 + (410 - large.width) // 2, 92), large)
    draw.text((30, 595), "Original character: Kiki the Cyber Squirrel, Krita mascot.  krita.org/en/about/mascot/", font=small, fill="#57666c")
    board.save(OUTPUT / "review.png")
    print(json.dumps(provenance))


if __name__ == "__main__":
    prepare()
