"""Register Kenney's existing CC0 cutouts on RigPop's editable biped rig."""

import argparse
import copy
import hashlib
import io
import json
import re
import shutil
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw
import resvg_py

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/art/sources/adventurer"
OUTPUT = ROOT / "assets/templates/adventurer"
SVG_NS = "http://www.w3.org/2000/svg"
HREF = "{http://www.w3.org/1999/xlink}href"
TITLE = "\u84dd\u8863\u5192\u9669\u5bb6"
NAMES = {
    "body": "\u8eaf\u5e72", "head": "\u5934\u90e8", "hair": "\u540e\u53d1",
    "arm_l": "\u5de6\u81c2", "arm_r": "\u53f3\u81c2",
    "hand_l": "\u5de6\u624b", "hand_r": "\u53f3\u624b",
    "leg_l": "\u5de6\u817f", "leg_r": "\u53f3\u817f",
}
PARENTS = {"body": "", "head": "body", "hair": "head", "arm_l": "body",
           "arm_r": "body", "hand_l": "arm_l", "hand_r": "arm_r",
           "leg_l": "body", "leg_r": "body"}
ORDER = {"hair": -3, "leg_l": -2, "leg_r": -1, "arm_l": 0, "arm_r": 1,
         "body": 2, "hand_l": 3, "hand_r": 4, "head": 5}


def import_source(directory):
    character = directory / "Female adventurer"
    SOURCE.mkdir(parents=True, exist_ok=True)
    shutil.copy2(character / "Vector/character_femaleAdventurer.svg", SOURCE / "character.svg")
    shutil.copy2(directory / "License.txt", ROOT / "licenses/Kenney-CC0.txt")
    for name in ["back", "body", "head", "headFocus", "headShock", "arm", "hand", "leg"]:
        shutil.copy2(character / f"PNG/Parts HD/{name}.png", SOURCE / f"{name}.png")
    shutil.copy2(character / "PNG/Poses HD/character_femaleAdventurer_idle.png", SOURCE / "master.png")


def matrix(group):
    values = [float(v) for v in re.findall(r"[-+0-9.]+", group.attrib["transform"])]
    if len(values) != 6:
        raise ValueError("Expected the author's SVG matrix transform")
    return values


def render_group(definitions, group):
    root = ET.Element(f"{{{SVG_NS}}}svg", {"width": "192", "height": "256", "viewBox": "0 0 96 128"})
    root.append(copy.deepcopy(definitions))
    root.append(copy.deepcopy(group))
    return Image.open(io.BytesIO(resvg_py.svg_to_bytes(svg_string=ET.tostring(root, encoding="unicode")))).convert("RGBA")


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "assets").mkdir(exist_ok=True)
    svg = ET.parse(SOURCE / "character.svg").getroot()
    poses = svg.find(".//*[@id='poses']")
    entries = {}
    for group in poses:
        transform = matrix(group)
        if not (0 <= transform[4] < 96 and 0 <= transform[5] < 128):
            continue
        href = next(node.get(HREF) for node in group.iter() if node.tag.endswith("use"))
        kind = href[1:].split("_0_Layer")[0]
        if kind == "shadow":
            continue
        source = "back" if kind == "Symbol_1" else kind
        role = "hair" if source == "back" else source
        if role in ("arm", "hand", "leg"):
            role += "_l" if transform[0] < 0 else "_r"
        bounds = render_group(svg[0], group).getbbox()
        image = Image.open(SOURCE / f"{source}.png").convert("RGBA")
        if transform[0] < 0:
            image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # The author's cutout export has a one-pixel transparent border on some parts.
        image = image.crop(image.getbbox())
        drawn_size = (bounds[2] - bounds[0], bounds[3] - bounds[1])
        if abs(image.width - drawn_size[0]) > 3 or abs(image.height - drawn_size[1]) > 3:
            raise ValueError(f"{role}: source bounds disagree: {image.size}, {drawn_size}")
        entries[role] = {"image": image, "at": bounds[:2], "anchor": [transform[4] * 2, transform[5] * 2]}

    if set(entries) != set(PARENTS):
        raise ValueError(f"Incomplete biped: {entries.keys()}")
    entries["hair"]["anchor"] = entries["head"]["anchor"][:]
    ground = max(entry["at"][1] + entry["image"].height for entry in entries.values())
    origin = [96, ground]
    parts = []
    preview = Image.new("RGBA", (192, 256))
    for role in sorted(entries, key=ORDER.get):
        entry = entries[role]
        image, at, anchor = entry["image"], entry["at"], entry["anchor"]
        image.save(OUTPUT / f"assets/{role}.png")
        preview.alpha_composite(image, at)
    for role in PARENTS:
        entry = entries[role]
        parent = PARENTS[role]
        anchor = entry["anchor"]
        parent_anchor = entries[parent]["anchor"] if parent else origin
        parts.append({"id": role, "name": NAMES[role], "role": role, "parent": parent,
                      "position": [round(anchor[i] - parent_anchor[i], 3) for i in (0, 1)],
                      "pivot": [round(anchor[i] - entry["at"][i], 3) for i in (0, 1)],
                      "rotation": 0, "z": ORDER[role], "visible": True, "asset": f"assets/{role}.png"})
    for source, target in [("headFocus", "head_focus"), ("headShock", "head_surprised")]:
        image = Image.open(SOURCE / f"{source}.png").convert("RGBA")
        image.crop(image.getbbox()).save(OUTPUT / f"assets/{target}.png")
    base_action = {"id": "idle", "name": "Idle", "frames": 8, "fps": 8,
                   "loop": True, "overlay": False, "priority": 0, "conflict": "replace", "lock_movement": False, "tracks": {}}
    wave = dict(base_action, id="wave", name="Wave", overlay=True, loop=False)
    model = {"format_version": 1, "id": "template_adventurer", "name": TITLE,
             "rig": "rigpop.biped.v1", "parts": parts, "actions": [base_action, wave],
             "palette": ["f4cd9f", "d99a70", "c7845d", "a56247", "5e9cb5", "397b99", "80593e", "f8f4df"],
             "bindings": [{"key": key, "gesture": "hold", "command": command} for key, command in
                          [("A", "move_left"), ("D", "move_right"), ("W", "move_up"), ("S", "move_down")]]
                         + [{"key": "Space", "gesture": "tap", "command": "wave"}],
             "game": {"speed": 115, "collision_radius": 16},
             "desktop": {"scale": 1, "always_on_top": True, "wander": False},
             "modules": {"rigpop.rig": {"motion_scale": 2}, "rigpop.art": {
                 "source": "Kenney Toon Characters / Female adventurer", "license": "CC0-1.0",
                 "url": "https://kenney.nl/assets/toon-characters", "art_source": "existing"}}}
    (OUTPUT / "character.rigpop.json").write_text(json.dumps(model, ensure_ascii=False, indent=2), encoding="utf-8")
    preview.save(OUTPUT / "preview.png")
    source_hash = hashlib.sha256((SOURCE / "character.svg").read_bytes()).hexdigest()
    report = {"art_source": "existing", "route": "Kenney CC0 original PNG cutouts", "model": None,
              "source_sha256": source_hash, "canvas": [192, 256], "root": origin,
              "parts": {role: {"anchor": entry["anchor"], "position": entry["at"], "size": entry["image"].size} for role, entry in entries.items()}}
    (OUTPUT / "provenance.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    board = Image.new("RGB", (576, 360), "#f0f3f5")
    draw = ImageDraw.Draw(board)
    for index, background in enumerate(["#f0f3f5", "#292b32"]):
        tile = Image.new("RGBA", (288, 360), background)
        tile.alpha_composite(preview, (48, 50))
        board.paste(tile.convert("RGB"), (288 * index, 0))
    draw.text((20, 20), "BLUE ADVENTURER / KENNEY CC0 / EDITABLE BIPED", fill="#293947")
    board.save(OUTPUT / "review.png")
    print(json.dumps(report))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    if args.source:
        import_source(args.source)
    build()
