"""Generate real PSD fixtures and verify the decoder with all PSD compressions."""

import tempfile
import unittest
from pathlib import Path

from PIL import Image
from psd_tools import PSDImage
from psd_tools.api.layers import Group, PixelLayer
from psd_tools.constants import Compression, BlendMode

from import_psd import decode

FIXTURES = Path(__file__).resolve().parents[2] / "tests" / "output" / "psd"


def fixture(path, compression):
    psd = PSDImage.new("RGBA", (320, 240))
    group = Group.new("Character", parent=psd)
    group.name = "角色"
    group.opacity = 128
    for name, xy, color in [("身体", (130, 150), (30, 170, 110, 255)),
                            ("头部", (125, 100), (240, 220, 180, 255)),
                            ("左臂", (105, 155), (40, 100, 220, 255)),
                            ("装饰", (115, 80), (220, 60, 60, 255))]:
        image = Image.new("RGBA", (30, 25), (0, 0, 0, 0))
        image.paste(color, (3, 4, 27, 23))
        layer = PixelLayer.frompil(image, psd, "Layer", left=xy[0], top=xy[1], compression=compression)
        layer.name = name
        group.append(layer)
        if name == "头部": layer.opacity = 128
        if name == "装饰": layer.visible = False
    psd.save(path)


class ImportTests(unittest.TestCase):
    def test_compression_offsets_opacity_hidden_and_groups(self):
        FIXTURES.mkdir(parents=True, exist_ok=True)
        for compression in Compression:
            with self.subTest(compression=compression):
                source = FIXTURES / f"case_{compression.value}.psd"
                fixture(source, compression)
                with tempfile.TemporaryDirectory() as temporary:
                    result = decode(source, Path(temporary))
                    self.assertEqual(len(result["layers"]), 4)
                    body, head, arm, hidden = result["layers"]
                    self.assertEqual(body["position"], [133, 154])
                    self.assertEqual(body["group"], "角色")
                    self.assertFalse(hidden["visible"])
                    with Image.open(Path(temporary) / body["image"]) as image:
                        self.assertEqual(image.size, (24, 19))
                        self.assertAlmostEqual(image.getpixel((5, 5))[3], 128, delta=1)
                    with Image.open(Path(temporary) / head["image"]) as image:
                        self.assertAlmostEqual(image.getpixel((5, 5))[3], 64, delta=1)
                    with Image.open(Path(temporary) / hidden["image"]) as image:
                        self.assertGreater(image.getpixel((5, 5))[3], 0)

    def test_invalid_and_unsupported_documents(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "cmyk.psd"
            PSDImage.new("CMYK", (8, 8)).save(source)
            with self.assertRaisesRegex(ValueError, "8-bit RGB"):
                decode(source, Path(temporary))
            source.write_bytes(b"8BPSbroken")
            with self.assertRaises(Exception):
                decode(source, Path(temporary))


if __name__ == "__main__":
    unittest.main()
