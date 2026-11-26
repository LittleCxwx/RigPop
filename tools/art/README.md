# Character Artwork

Blue Adventurer is an adaptation of Kenney's **Toon Characters / Female adventurer**:
https://kenney.nl/assets/toon-characters (CC0-1.0, `licenses/Kenney-CC0.txt`).

The original PNG cutouts, reference pose and SVG are in `sources/adventurer/`.
`adapt_adventurer.py` reads the author's SVG transforms to register the PNG cutouts
without redrawing them. It creates nine editable biped parts and two face variants.
The accepted reference is `sources/adventurer/master.png`; the feet use one shared
origin. Runtime motions use RigPop's existing role-based FK presets, not generated
video or a pre-rendered character animation sheet.

Rebuild the committed PNGs with Python 3.12, Pillow 11.0.0 and resvg-py 0.5.0:

```powershell
python tools/art/adapt_adventurer.py
```

`assets/templates/adventurer/provenance.json` records source, registration and hash.
Review the assembled character over both light and dark in `review.png`, then inspect
the real Godot action previews. Pixel-art Lingxi and its generator remain separate.
