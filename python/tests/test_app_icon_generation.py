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

    def test_repo_logo_generates_at_normal_app_icon_visual_size(self):
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

            self.assertFalse(has_bright_translucent_edge(large_icon))
            self.assertLessEqual(max(right - left, bottom - top) / 1024, 0.87)
            self.assertGreaterEqual(left, 68)
            self.assertGreaterEqual(top, 68)

            switcher_icon = Image.open(iconset / "icon_128x128@2x.png").convert("RGBA")
            switcher_bbox = switcher_icon.getchannel("A").getbbox()
            self.assertIsNotNone(switcher_bbox)
            switcher_left, switcher_top, switcher_right, switcher_bottom = switcher_bbox
            switcher_occupancy = max(
                switcher_right - switcher_left,
                switcher_bottom - switcher_top,
            ) / switcher_icon.width
            self.assertGreaterEqual(switcher_occupancy, 0.82)
            self.assertLessEqual(switcher_occupancy, 0.84)

            for small_name in ("icon_16x16.png", "icon_32x32@2x.png", "icon_128x128.png"):
                small_icon = Image.open(iconset / small_name).convert("RGBA")
                small_bbox = small_icon.getchannel("A").getbbox()
                self.assertIsNotNone(small_bbox)
                small_left, small_top, small_right, small_bottom = small_bbox
                self.assertLessEqual(small_left, 1)
                self.assertLessEqual(small_top, 1)
                self.assertGreaterEqual(small_right, small_icon.width - 1)
                self.assertGreaterEqual(small_bottom, small_icon.height - 1)


def has_bright_translucent_edge(image):
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if 0 < alpha < 48 and min(red, green, blue) > 180:
                return True
    return False


if __name__ == "__main__":
    unittest.main()
