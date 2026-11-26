"""Isolated PSD decoder. Only PNGs and a versioned JSON manifest cross into Godot."""

import argparse
import json
from pathlib import Path

from psd_tools import PSDImage

MAX_SIZE = 4096
MAX_LAYERS = 256
MAX_PIXELS = 64 * 1024 * 1024


def decode(source: Path, output: Path) -> dict:
    if source.stat().st_size > 256 * 1024 * 1024:
        raise ValueError("PSD exceeds the 256 MiB input limit")
    psd = PSDImage.open(source)
    if max(psd.size) > MAX_SIZE or min(psd.size) < 1:
        raise ValueError("PSD canvas must be between 1 and 4096 pixels per side")
    if psd.color_mode.name != "RGB" or psd.depth != 8:
        raise ValueError("Convert the PSD to 8-bit RGB before importing")
    descendants = list(psd.descendants())
    if len(descendants) > MAX_LAYERS:
        raise ValueError("PSD exceeds the 256 layer limit")
    result = {"version": 1, "width": psd.width, "height": psd.height,
              "layers": [], "warnings": [], "error": ""}
    pixels = 0

    def visit(group, path="", parent_visible=True):
        nonlocal pixels
        for index, layer in enumerate(group):
            key = f"{path}/{index}"
            visible = parent_visible and layer.visible
            if layer.is_group():
                visit(layer, key, visible)
                continue
            if not layer.has_pixels():
                result["warnings"].append(f"{layer.name}: no raster pixels; skipped")
                continue
            left, top, right, bottom = layer.bbox
            width, height = right - left, bottom - top
            if width < 1 or height < 1:
                continue
            pixels += width * height
            if max(width, height) > MAX_SIZE or pixels > MAX_PIXELS:
                raise ValueError("Layer data exceeds the 4096 px / 64 megapixel limit")
            if max(abs(left), abs(top), abs(right), abs(bottom)) > MAX_SIZE * 2:
                raise ValueError("Layer coordinates exceed the supported canvas range")
            notes = []
            if layer.blend_mode.value != b"norm":
                notes.append("blend mode imported as normal")
            if layer.clipping_layer:
                notes.append("clipping requires merging with the base layer in Photoshop")
            if layer.has_effects():
                notes.append("layer effects require rasterizing in Photoshop")
            if layer.kind in ("type", "smartobject"):
                notes.append("using the saved raster representation")
            image = layer.composite(viewport=layer.bbox, force=True, apply_icc=False,
                                    layer_filter=lambda item: True)
            if image is None:
                result["warnings"].append(f"{layer.name}: could not render; skipped")
                continue
            image = image.convert("RGBA")
            box = image.getchannel("A").getbbox()
            if box is None:
                continue
            image = image.crop(box)
            opacity = 1.0
            ancestor = layer.parent
            groups = []
            while ancestor is not None and not isinstance(ancestor, PSDImage):
                groups.append(ancestor.name)
                opacity *= ancestor.opacity / 255.0
                if ancestor.has_mask() or getattr(ancestor.blend_mode, "value", b"pass") not in (b"norm", b"pass"):
                    notes.append("group masks/blending require merging in Photoshop")
                ancestor = ancestor.parent
            if opacity < 1.0:
                image.putalpha(image.getchannel("A").point(lambda value: round(value * opacity)))
            filename = f"layer_{len(result['layers']):03d}.png"
            image.save(output / filename)
            result["layers"].append({
                "key": key, "name": layer.name, "group": "/".join(reversed(groups)),
                "position": [left + box[0], top + box[1]], "image": filename,
                "visible": visible, "opacity": layer.opacity, "note": "; ".join(notes),
                "z": len(result["layers"]),
            })
            result["warnings"].extend(f"{layer.name}: {note}" for note in notes)

    visit(psd)
    if not result["layers"]:
        raise ValueError("No usable raster layers found in PSD")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    try:
        result = decode(args.source, args.output)
    except Exception as exc:
        result = {"version": 1, "error": f"{type(exc).__name__}: {exc}"}
    (args.output / "manifest.json").write_text(
        json.dumps(result, ensure_ascii=False), encoding="utf-8")
    return 1 if result.get("error") else 0


if __name__ == "__main__":
    raise SystemExit(main())
