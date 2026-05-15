#!/usr/bin/env python3
import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


CONTENT_SCALE = 0.86

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
    icon = trim_outer_padding(ensure_transparent_edges(source))

    iconset = Path(iconset_path)
    iconset.mkdir(parents=True, exist_ok=True)
    for name, size in ICON_SPECS:
        render_icon(icon, size).save(iconset / name)

    if app_icon_png_path is not None:
        render_icon(icon, 1024).save(app_icon_png_path)


def render_icon(icon, size):
    max_content_size = max(1, int(round(size * CONTENT_SCALE)))
    scale = min(max_content_size / icon.width, max_content_size / icon.height)
    content_size = (
        max(1, int(round(icon.width * scale))),
        max(1, int(round(icon.height * scale))),
    )
    resized = resize_rgba(icon, content_size)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = ((size - content_size[0]) // 2, (size - content_size[1]) // 2)
    canvas.alpha_composite(resized, origin)
    return smooth_outer_edge(canvas)


def resize_rgba(image, size):
    array = np.asarray(image, dtype=np.float32)
    alpha = array[:, :, 3:4] / 255.0
    array[:, :, :3] *= alpha

    premultiplied = Image.fromarray(np.clip(array, 0, 255).astype(np.uint8))
    resized = np.asarray(premultiplied.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)

    alpha = resized[:, :, 3:4]
    visible = alpha[:, :, 0] >= 48
    resized[:, :, :3][visible] = np.clip(
        resized[:, :, :3][visible] * 255.0 / alpha[:, :, :1][visible],
        0,
        255,
    )
    resized[:, :, :3][~visible] = 0
    return Image.fromarray(np.clip(resized, 0, 255).astype(np.uint8))


def smooth_outer_edge(image):
    array = np.asarray(image, dtype=np.uint8).copy()
    alpha = array[:, :, 3]
    outer_edge = np.zeros(alpha.shape, dtype=bool)
    transparent = alpha == 0
    visible = alpha > 0

    for offset in range(1, 4):
        outer_edge[offset:, :] |= transparent[:-offset, :]
        outer_edge[:-offset, :] |= transparent[offset:, :]
        outer_edge[:, offset:] |= transparent[:, :-offset]
        outer_edge[:, :-offset] |= transparent[:, offset:]

    red = array[:, :, 0]
    green = array[:, :, 1]
    blue = array[:, :, 2]
    max_channel = np.maximum(np.maximum(red, green), blue)
    min_channel = np.minimum(np.minimum(red, green), blue)
    bright_neutral = (min_channel > 70) & ((max_channel - min_channel) <= 24)

    cleanup = visible & outer_edge & bright_neutral
    array[:, :, 0][cleanup] = 24
    array[:, :, 1][cleanup] = 25
    array[:, :, 2][cleanup] = 30
    return Image.fromarray(array)


def ensure_transparent_edges(image):
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] < 255:
        return image

    pixels = image.load()
    width, height = image.size
    transparent = set()
    queue = deque()

    def enqueue(x, y):
        if (x, y) not in transparent and is_light_neutral(pixels[x, y]):
            transparent.add((x, y))
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                enqueue(nx, ny)

    if not transparent:
        return image

    result = image.copy()
    result_pixels = result.load()
    for x, y in transparent:
        red, green, blue, _ = result_pixels[x, y]
        result_pixels[x, y] = (red, green, blue, 0)
    return result


def is_light_neutral(pixel):
    red, green, blue, alpha = pixel
    return alpha > 0 and min(red, green, blue) >= 230 and max(red, green, blue) - min(red, green, blue) <= 8


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
