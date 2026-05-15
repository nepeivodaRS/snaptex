import unittest

from PIL import Image, ImageChops, ImageDraw, ImageStat

from snaptex_worker.worker import normalize_formula_image, should_invert_formula_image


class WorkerPreprocessingTests(unittest.TestCase):
    def test_dark_formula_image_is_inverted_before_recognition(self):
        image = Image.new("RGB", (120, 48), "black")
        draw = ImageDraw.Draw(image)
        draw.line((16, 24, 104, 24), fill="white", width=3)
        draw.text((36, 12), "x+y", fill="white")

        normalized = normalize_formula_image(image)

        self.assertTrue(should_invert_formula_image(image))
        self.assertGreater(ImageStat.Stat(normalized.convert("L")).mean[0], 220)

    def test_sparse_dark_formula_image_is_inverted_before_recognition(self):
        image = Image.new("RGB", (900, 180), "black")
        draw = ImageDraw.Draw(image)
        draw.line((260, 92, 640, 92), fill=(210, 210, 210), width=2)
        draw.text((330, 70), "R(theta, phi)", fill=(210, 210, 210))

        normalized = normalize_formula_image(image)

        self.assertTrue(should_invert_formula_image(image))
        self.assertGreater(ImageStat.Stat(normalized.convert("L")).mean[0], 240)

    def test_sparse_dark_formula_image_is_cropped_to_formula_content(self):
        image = Image.new("RGB", (900, 180), "black")
        draw = ImageDraw.Draw(image)
        draw.line((260, 92, 640, 92), fill=(210, 210, 210), width=2)
        draw.text((330, 70), "R(theta, phi)", fill=(210, 210, 210))

        normalized = normalize_formula_image(image)

        self.assertLess(normalized.size[0], image.size[0])
        self.assertLess(normalized.size[1], image.size[1])

    def test_light_formula_image_is_not_inverted(self):
        image = Image.new("RGB", (120, 48), "white")
        draw = ImageDraw.Draw(image)
        draw.line((16, 24, 104, 24), fill="black", width=3)
        draw.text((36, 12), "x+y", fill="black")

        normalized = normalize_formula_image(image)
        difference = ImageChops.difference(image, normalized)

        self.assertFalse(should_invert_formula_image(image))
        self.assertIsNone(difference.getbbox())


if __name__ == "__main__":
    unittest.main()
