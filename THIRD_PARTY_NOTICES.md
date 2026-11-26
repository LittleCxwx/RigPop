# Third-Party Notices

RigPop's original source code and documentation are licensed under the MIT
License; see the root `LICENSE` file. Third-party components and separately
identified assets retain their own copyright and license terms as listed below.

- Godot Engine 4.7.2: MIT license, `licenses/Godot-MIT.txt`; third-party notices in `licenses/Godot-COPYRIGHT.txt`.
- Noto Sans SC variable font: SIL Open Font License 1.1, `licenses/Noto-OFL.txt`. The local font was copied from the supplied FlufflightDemo assets.
- Lucide icon paths: ISC license, `licenses/Lucide.txt`. Paths are rasterized locally for Godot controls.
- `assets/slime.png`: copied from the user's supplied FlufflightDemo as a demo reference asset. Its original provenance and rights are unchanged.
- The humanoid template is authored as editable pixel data in `services/templates.gd`. Lingxi artwork and its source generator are in `assets/templates/lingxi/` and `tools/art/`.
- Blue Adventurer uses Kenney's Toon Characters / Female adventurer, licensed CC0-1.0: https://kenney.nl/assets/toon-characters. The original cutouts and SVG are retained in `tools/art/sources/adventurer/`; registration and assembly are in `tools/art/adapt_adventurer.py`. See `licenses/Kenney-CC0.txt`. This is existing licensed artwork, not AI-generated art.
- Kiki uses Tyson Tan's Chibi Kiki II (2019 Sketch, 2025 Cleanup), from https://krita.org/en/about/mascot/, under CC BY-SA 4.0. Kiki is Krita's mascot. The original PNG is retained in `tools/art/sources/kiki/chibi-ii.png`; `tools/art/adapt_kiki.py` isolates, crops and resizes the figure with its native alpha. The adapted images and Kiki animation data remain CC BY-SA 4.0. See `licenses/Kiki-Attribution.txt` and `licenses/CC-BY-SA-4.0.txt`. This is existing licensed artwork, not AI-generated art. No affiliation or endorsement is implied.
- PSD import uses psd-tools 1.10.9 (MIT), Pillow, NumPy, SciPy, scikit-image and aggdraw, bundled with Python by PyInstaller. Distribution license files accompany the helper under `helpers/psd/RigPopPsd/licenses/` and its `_internal/` metadata.
- Zig 0.13.0 is a build tool only and is not required on the user's machine.

No network services, accounts, telemetry, or online asset generation are used at runtime.
