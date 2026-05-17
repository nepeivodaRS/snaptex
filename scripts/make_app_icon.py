#!/usr/bin/env python3
import argparse
from pathlib import Path

import numpy as np
from PIL import Image


CONTENT_SCALE = 0.83
SMALL_ICON_CONTENT_SCALE = 1.0
SMALL_ICON_MAX_SIZE = 128
VISIBLE_ALPHA_THRESHOLD = 160

ICON_SPECS = (
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
)


def generate_iconset(source_path, iconset_path, app_icon_png_path=None):
    source = Image.open(source_path).convert("RGBA")
    icon = trim_outer_padding(source)

    iconset = Path(iconset_path)
    iconset.mkdir(parents=True, exist_ok=True)
    for name, size in ICON_SPECS:
        render_icon(icon, size).save(iconset / name)

    if app_icon_png_path is not None:
        render_icon(icon, 1024).save(app_icon_png_path)


def render_icon(icon, size):
    max_content_size = max(1, int(round(size * content_scale_for_size(size))))
    scale = min(max_content_size / icon.width, max_content_size / icon.height)
    content_size = (
        max(1, int(round(icon.width * scale))),
        max(1, int(round(icon.height * scale))),
    )
    resized = resize_rgba(icon, content_size)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = ((size - content_size[0]) // 2, (size - content_size[1]) // 2)
    canvas.alpha_composite(resized, origin)
    return canvas


def content_scale_for_size(size):
    if size <= SMALL_ICON_MAX_SIZE:
        return SMALL_ICON_CONTENT_SCALE
    return CONTENT_SCALE


def resize_rgba(image, size):
    array = np.asarray(image, dtype=np.float32)
    alpha = array[:, :, 3:4] / 255.0
    array[:, :, :3] *= alpha

    premultiplied = Image.fromarray(np.clip(array, 0, 255).astype(np.uint8))
    resized = np.asarray(premultiplied.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)

    alpha = resized[:, :, 3:4]
    visible = alpha[:, :, 0] >= VISIBLE_ALPHA_THRESHOLD
    resized[:, :, :3][visible] = np.clip(
        resized[:, :, :3][visible] * 255.0 / alpha[:, :, :1][visible],
        0,
        255,
    )
    resized[:, :, :3][~visible] = 0
    return Image.fromarray(np.clip(resized, 0, 255).astype(np.uint8))


def trim_outer_padding(image):
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def main():
    parser = argparse.ArgumentParser(description="Generate a snaptex AppIcon.iconset from a logo PNG.")
    parser.add_argument("source")
    parser.add_argument("iconset")
    parser.add_argument("--app-icon-png")
    args = parser.parse_args()

    generate_iconset(
        Path(args.source),
        Path(args.iconset),
        Path(args.app_icon_png) if args.app_icon_png else None,
    )


if __name__ == "__main__":
    main()
