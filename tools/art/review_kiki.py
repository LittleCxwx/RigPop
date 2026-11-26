"""Build Kiki motion previews exclusively from the actual Godot render test."""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
report = json.loads((ROOT / "build/kiki-verification.json").read_text(encoding="utf-8"))
renders = Path(report["output"])
output = ROOT / "build/previews"
output.mkdir(parents=True, exist_ok=True)
model = json.loads((Path(report["sample"]) / "character.rigpop.json").read_text(encoding="utf-8"))
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 17)
small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 13)
frames = []
for tick in range(32):
    board = Image.new("RGBA", (960, 370), "#f0f3f6")
    draw = ImageDraw.Draw(board)
    for column, (action, count) in enumerate([("idle", 32), ("wave", 32), ("jump", 24)]):
        if column == 1:
            draw.rectangle((320, 0, 639, 369), fill="#29282d")
        index = min(tick, count - 1)
        board.alpha_composite(Image.open(renders / f"{action}_{index:02d}.png").convert("RGBA"), (column * 320, 5))
        ink = "#e8edf1" if column == 1 else "#364049"
        draw.text((column * 320 + 20, 16), action.upper(), font=font, fill=ink)
        draw.text((column * 320 + 20, 340), "Kiki / Tyson Tan / CC BY-SA 4.0", font=small, fill=ink)
    frames.append(board.convert("RGB"))
frames[0].save(output / "kiki-motion.gif", save_all=True, append_images=frames[1:], duration=63, loop=0)
frames[0].save(output / "kiki-motion.png")

board = Image.new("RGB", (960, 700), "#f0f3f6")
draw = ImageDraw.Draw(board)
for index, clip in enumerate(model["actions"]):
    col, row = index % 3, index // 3
    tile = Image.new("RGBA", (320, 320), "#f0f3f6" if col != 1 else "#29282d")
    frame = int(clip["frames"]) // 3
    tile.alpha_composite(Image.open(renders / f"{clip['id']}_{frame:02d}.png").convert("RGBA"))
    board.paste(tile.convert("RGB"), (col * 320, row * 350))
    draw.text((col * 320 + 20, row * 350 + 12), clip["id"].upper(), font=font,
              fill="#e8edf1" if col == 1 else "#364049")
draw.text((20, 680), "Kiki the Cyber Squirrel / Tyson Tan / CC BY-SA 4.0 / Whole-illustration animation", font=small, fill="#364049")
board.save(output / "kiki-actions.png")
print(output / "kiki-motion.gif")
