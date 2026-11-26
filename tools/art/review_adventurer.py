"""Make inspection boards from real Godot renders, never from substitute artwork."""

import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
report = json.loads((ROOT / "build/adventurer-verification.json").read_text(encoding="utf-8"))
renders = Path(report["output"])
output = ROOT / "build/previews"
output.mkdir(parents=True, exist_ok=True)
model = json.loads((Path(report["sample"]) / "character.rigpop.json").read_text(encoding="utf-8"))
actions = [(clip["id"], clip["frames"]) for clip in model["actions"]]

for page in range(2):
    board = Image.new("RGB", (1280, 1160), "#eef2f5")
    draw = ImageDraw.Draw(board)
    for row, (action, count) in enumerate(actions[page * 4:page * 4 + 4]):
        for column, frame in enumerate([0, count // 4, count // 2, count * 3 // 4]):
            tile = Image.new("RGBA", (320, 280), "#eef2f5" if column % 2 == 0 else "#292b32")
            tile.alpha_composite(Image.open(renders / f"{action}_{frame:02d}.png").convert("RGBA"))
            board.paste(tile.convert("RGB"), (column * 320, row * 290 + 10))
            draw.text((column * 320 + 12, row * 290 + 16), f"{action.upper()} / {frame}",
                      fill="#293947" if column % 2 == 0 else "#f0f4f8")
    board.save(output / f"adventurer-actions-{page + 1}.png")

frames = []
for tick in range(32):
    board = Image.new("RGBA", (960, 300), "#eef2f5")
    draw = ImageDraw.Draw(board)
    for column, (action, count, fps) in enumerate([("idle", 8, 8), ("walk", 8, 10), ("wave", 8, 8)]):
        frame = int(tick / 10 * fps) % count
        board.alpha_composite(Image.open(renders / f"{action}_{frame:02d}.png").convert("RGBA"), (column * 320, 20))
        draw.text((column * 320 + 24, 16), action.upper(), fill="#293947")
    frames.append(board.convert("RGB"))
frames[0].save(output / "adventurer-motion.gif", save_all=True, append_images=frames[1:], duration=100, loop=0)
print(output)
