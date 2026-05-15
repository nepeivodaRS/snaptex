import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


ROOT_DIR = Path(__file__).resolve().parents[2]


def load_icon_module():
    script_path = ROOT_DIR / "scripts" / "make_app_icon.py"
    spec = importlib.util.spec_from_file_location("make_app_icon", script_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AppIconGenerationTests(unittest.TestCase):
    def test_iconset_preserves_alpha_and_crops_outer_padding(self):
        module = load_icon_module()

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "logo.png"
            iconset = root / "AppIcon.iconset"

            image = Image.new("RGBA", (1254, 1254), (255, 255, 255, 0))
            draw = ImageDraw.Draw(image)
            draw.rounded_rectangle((75, 65, 1178, 1181), radius=160, fill=(18, 19, 23, 255))
            image.save(source)

            module.generate_iconset(source, iconset)

            large_icon = Image.open(iconset / "icon_512x512@2x.png").convert("RGBA")
            alpha = large_icon.getchannel("A")

            self.assertEqual((1024, 1024), large_icon.size)
            bbox = alpha.getbbox()
            self.assertIsNotNone(bbox)
            left, top, right, bottom = bbox

            self.assertEqual(0, large_icon.getpixel((0, 0))[3])
            self.assertGreater(large_icon.getpixel((512, 512))[3], 240)
            self.assertGreaterEqual(left, 44)
            self.assertGreaterEqual(top, 44)
            self.assertLessEqual(right, 980)
            self.assertLessEqual(bottom, 980)
            self.assertFalse(has_bright_translucent_edge(large_icon))

    def test_repo_logo_generates_without_visible_outer_rim(self):
        module = load_icon_module()

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            iconset = root / "AppIcon.iconset"

            module.generate_iconset(ROOT_DIR / "Sources" / "SnapTexApp" / "Resources" / "logo.png", iconset)

            large_icon = Image.open(iconset / "icon_512x512@2x.png").convert("RGBA")
            alpha = large_icon.getchannel("A")
            bbox = alpha.getbbox()
            self.assertIsNotNone(bbox)
            left, top, right, bottom = bbox

            self.assertFalse(has_bright_outer_edge(large_icon))
            self.assertLessEqual(max(right - left, bottom - top) / 1024, 0.87)
            self.assertGreaterEqual(left, 68)
            self.assertGreaterEqual(top, 68)


def has_bright_translucent_edge(image):
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if 0 < alpha < 48 and min(red, green, blue) > 180:
                return True
    return False


def has_bright_outer_edge(image):
    pixels = image.load()
    width, height = image.size
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or min(red, green, blue) <= 90:
                continue
            if max(red, green, blue) - min(red, green, blue) > 16:
                continue
            neighbors = [
                pixels[x - 1, y][3],
                pixels[x + 1, y][3],
                pixels[x, y - 1][3],
                pixels[x, y + 1][3],
            ]
            if min(neighbors) == 0:
                return True
    return False


if __name__ == "__main__":
    unittest.main()
