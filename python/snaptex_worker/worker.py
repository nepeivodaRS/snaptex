import argparse
import contextlib
import io
import json
import os
import sys
import tempfile
import traceback
import warnings
from pathlib import Path

import yaml
from PIL import Image, ImageOps, ImageStat

os.environ.setdefault("NO_ALBUMENTATIONS_UPDATE", "1")
warnings.filterwarnings(
    "ignore",
    message="The image_processor_class argument is deprecated.*",
    category=FutureWarning,
)
warnings.filterwarnings(
    "ignore",
    message="`do_sample` is set to `False`.*",
    category=UserWarning,
)
warnings.filterwarnings(
    "ignore",
    message="A new version of Albumentations is available.*",
    category=UserWarning,
)


LOG_VERBOSITY_RANKS = {
    "normal": 0,
    "verbose": 1,
    "debug": 2,
}
SAMPLED_PASS_TEMPERATURE = 0.85
SAMPLED_PASS_TOP_P = 0.95


def json_response(payload):
    return json.dumps(payload, ensure_ascii=False)


def normalize_log_verbosity(value):
    value = (value or "normal").strip().lower()
    return value if value in LOG_VERBOSITY_RANKS else "normal"


def worker_log(log_verbosity, minimum, message):
    log_verbosity = normalize_log_verbosity(log_verbosity)
    if LOG_VERBOSITY_RANKS[log_verbosity] < LOG_VERBOSITY_RANKS[minimum]:
        return
    print(f"snaptex worker: {message}", file=sys.stderr, flush=True)


def ocr_pass_count(mode):
    if mode == "accurate":
        return 3
    if mode == "balanced":
        return 2
    return 1


def unique(values):
    seen = set()
    result = []
    for value in values:
        value = (value or "").strip()
        if value and value not in seen:
            seen.add(value)
            result.append(value)
    return result


def prediction_strings(output):
    predictions = output.get("pred_str", [])
    if isinstance(predictions, str):
        return [predictions]
    return list(predictions)


def repeat_image_batch(image, batch_size):
    if batch_size <= 1:
        return image
    return image.repeat(batch_size, *([1] * (image.dim() - 1)))


def generate_sampled(model, payload):
    try:
        return model.generate(
            payload,
            do_sample=True,
            temperature=SAMPLED_PASS_TEMPERATURE,
            top_p=SAMPLED_PASS_TOP_P,
        )
    except TypeError:
        return model.generate(payload, do_sample=True)


def image_with_light_background(image):
    if image.mode in ("RGBA", "LA") or "transparency" in image.info:
        background = Image.new("RGBA", image.size, "white")
        return Image.alpha_composite(background, image.convert("RGBA")).convert("RGB")
    return image.convert("RGB")


def should_invert_formula_image(image):
    grayscale = image.convert("L")
    thumbnail = grayscale.copy()
    thumbnail.thumbnail((96, 96))

    histogram = thumbnail.histogram()
    total = sum(histogram)
    if total == 0:
        return False

    dark_ratio = sum(histogram[:96]) / total
    bright_ratio = sum(histogram[160:]) / total
    mean = ImageStat.Stat(thumbnail).mean[0]
    border_mean = dark_background_border_mean(thumbnail)

    return (mean < 130 and dark_ratio > 0.45) or (border_mean < 140 and bright_ratio > 0.0005)


def dark_background_border_mean(image):
    width, height = image.size
    border = max(1, min(width, height) // 12)
    regions = [
        image.crop((0, 0, width, border)),
        image.crop((0, height - border, width, height)),
        image.crop((0, 0, border, height)),
        image.crop((width - border, 0, width, height)),
    ]
    weighted_sum = 0
    pixel_count = 0
    for region in regions:
        count = region.size[0] * region.size[1]
        weighted_sum += ImageStat.Stat(region).mean[0] * count
        pixel_count += count
    return weighted_sum / pixel_count if pixel_count else 255


def normalize_formula_image(image):
    return preprocess_formula_image(image)[0]


def preprocess_formula_image(image):
    rgb_image = image_with_light_background(image)
    info = {
        "input_mode": image.mode,
        "input_size": image.size,
        "normalized_size": rgb_image.size,
        "inverted": False,
        "cropped": False,
        "output_size": rgb_image.size,
    }

    if should_invert_formula_image(rgb_image):
        inverted = ImageOps.autocontrast(ImageOps.invert(rgb_image), cutoff=1)
        processed = crop_dark_formula_content(inverted)
        info["inverted"] = True
        info["cropped"] = processed.size != inverted.size
        info["output_size"] = processed.size
        return processed, info
    return rgb_image, info


def crop_dark_formula_content(image):
    grayscale = image.convert("L")
    mask = grayscale.point(lambda pixel: 255 if pixel < 245 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    content_width = right - left
    content_height = bottom - top
    if content_width <= 0 or content_height <= 0:
        return image

    width, height = image.size
    if content_width > width * 0.95 and content_height > height * 0.95:
        return image

    crop = image.crop(bbox)
    padding_x = max(16, int(content_width * 0.08))
    padding_y = max(12, int(content_height * 0.35))
    canvas = Image.new("RGB", (content_width + padding_x * 2, content_height + padding_y * 2), "white")
    canvas.paste(crop, (padding_x, padding_y))
    return canvas


@contextlib.contextmanager
def quiet_model_output():
    with contextlib.redirect_stdout(io.StringIO()):
        yield


class UniMEREngine:
    def __init__(self, unimernet_path):
        self.unimernet_path = Path(unimernet_path).expanduser().resolve()
        self.cache = {}
        if not self.unimernet_path.exists():
            raise FileNotFoundError(f"UniMERNet path does not exist: {self.unimernet_path}")

        sys.path.insert(0, str(self.unimernet_path))

        import torch
        from unimernet.common.config import Config
        import unimernet.tasks as tasks
        from unimernet.processors import load_processor

        self.torch = torch
        self.Config = Config
        self.tasks = tasks
        self.load_processor = load_processor
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        if self.device.type == "cpu" and getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            # UniMERNet's autocast helper only special-cases CPU. Keep CPU as the conservative default on macOS.
            self.device = torch.device("cpu")

    def predict(self, image_path, model_name, mode, validate_render, log_verbosity="normal"):
        worker_log(
            log_verbosity,
            "verbose",
            f"predict start: model={model_name}, ocr_passes={ocr_pass_count(mode)}, validate_render={validate_render}, device={self.device}",
        )
        model, processor = self._load_model(model_name, log_verbosity)
        source_image = Image.open(image_path)
        raw_image, preprocessing = preprocess_formula_image(source_image)
        worker_log(
            log_verbosity,
            "debug",
            "preprocess: "
            f"input={preprocessing['input_size'][0]}x{preprocessing['input_size'][1]} {preprocessing['input_mode']}, "
            f"inverted={preprocessing['inverted']}, cropped={preprocessing['cropped']}, "
            f"output={preprocessing['output_size'][0]}x{preprocessing['output_size'][1]}",
        )

        passes = ocr_pass_count(mode)
        worker_log(log_verbosity, "verbose", f"generation passes={passes}")

        predictions = []
        inference_mode = getattr(self.torch, "inference_mode", contextlib.nullcontext)
        worker_log(log_verbosity, "debug", "generation pass 1: processor start")
        image = processor(raw_image).unsqueeze(0).to(self.device)
        with inference_mode():
            worker_log(log_verbosity, "debug", "generation pass 1: greedy model.generate start")
            output = model.generate({"image": image}, do_sample=False)
            predictions.extend(prediction_strings(output))

            sampled_passes = passes - 1
            if sampled_passes > 0:
                worker_log(
                    log_verbosity,
                    "debug",
                    f"generation sampled batch: passes={sampled_passes}, temperature={SAMPLED_PASS_TEMPERATURE}, top_p={SAMPLED_PASS_TOP_P}",
                )
                sampled_image = repeat_image_batch(image, sampled_passes)
                output = generate_sampled(model, {"image": sampled_image})
                predictions.extend(prediction_strings(output))

        for index, prediction in enumerate(predictions[:passes]):
            worker_log(log_verbosity, "debug", f"generation pass {index + 1}/{passes}: prediction={prediction[:160]}")

        alternatives = unique(predictions[:passes])
        worker_log(log_verbosity, "verbose", f"predict complete: alternatives={len(alternatives)}")
        return {
            "ok": True,
            "prediction": alternatives[0] if alternatives else "",
            "alternatives": alternatives,
            "model": model_name,
            "mode": mode,
        }

    def _load_model(self, model_name, log_verbosity="normal"):
        if model_name in self.cache:
            worker_log(log_verbosity, "verbose", f"model cache hit: {model_name}")
            return self.cache[model_name]

        worker_log(log_verbosity, "verbose", f"model load start: {model_name}")
        config_path = self._config_for(model_name)
        worker_log(log_verbosity, "debug", f"model config path: {config_path}")
        args = argparse.Namespace(cfg_path=str(config_path), options=None)

        cwd = os.getcwd()
        os.chdir(self.unimernet_path)
        try:
            with quiet_model_output():
                cfg = self.Config(args)
                task = self.tasks.setup_task(cfg)
                model = task.build_model(cfg).to(self.device)
            model.eval()
            generation_config = getattr(model, "generation_config", None)
            if generation_config is not None:
                generation_config.temperature = None
                generation_config.top_p = None
            processor = self.load_processor(
                "formula_image_eval",
                cfg.config.datasets.formula_rec_eval.vis_processor.eval,
            )
        finally:
            os.chdir(cwd)

        self.cache[model_name] = (model, processor)
        worker_log(log_verbosity, "verbose", f"model load complete: {model_name}")
        return model, processor

    def _config_for(self, model_name):
        template = self.unimernet_path / "configs" / "val" / f"unimernet_{model_name}.yaml"
        if not template.exists():
            raise FileNotFoundError(f"Missing UniMERNet config: {template}")

        with template.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)

        models_dir = self.unimernet_path / "models"
        model_dir = models_dir / f"unimernet_{model_name}"
        root_pth = models_dir / f"unimernet_{model_name}.pth"
        nested_pth = model_dir / f"unimernet_{model_name}.pth"
        pytorch_bin = model_dir / "pytorch_model.bin"
        pytorch_pth = model_dir / "pytorch_model.pth"

        data["model"]["model_config"]["model_name"] = str(model_dir)
        data["model"]["tokenizer_config"] = {"path": str(model_dir)}

        if root_pth.exists():
            data["model"]["load_pretrained"] = False
            data["model"]["load_finetuned"] = True
            data["model"]["finetuned"] = str(root_pth)
        elif nested_pth.exists():
            data["model"]["load_pretrained"] = True
            data["model"]["load_finetuned"] = False
            data["model"]["pretrained"] = str(nested_pth)
        elif pytorch_bin.exists():
            data["model"]["load_pretrained"] = True
            data["model"]["load_finetuned"] = False
            data["model"]["pretrained"] = str(pytorch_bin)
        elif pytorch_pth.exists():
            data["model"]["load_pretrained"] = True
            data["model"]["load_finetuned"] = False
            data["model"]["pretrained"] = str(pytorch_pth)
        else:
            raise FileNotFoundError(
                f"Model files not found for unimernet_{model_name}. "
                f"Expected {root_pth}, {nested_pth}, {pytorch_bin}, or {pytorch_pth}."
            )

        temporary = tempfile.NamedTemporaryFile("w", suffix=f"-unimernet-{model_name}.yaml", delete=False)
        with temporary:
            yaml.safe_dump(data, temporary)
        return Path(temporary.name)


def handle_request(line, engine):
    try:
        request = json.loads(line)
    except json.JSONDecodeError as exc:
        return json_response({"ok": False, "error": f"Invalid JSON: {exc}"})

    image_path = Path(request.get("image_path", "")).expanduser()
    if not image_path.exists():
        return json_response({"ok": False, "error": f"Image file not found: {image_path}"})

    model = request.get("model", "small")
    mode = request.get("mode", "balanced")
    validate_render = bool(request.get("validate_render", True))
    log_verbosity = normalize_log_verbosity(request.get("log_verbosity", "normal"))
    worker_log(
        log_verbosity,
        "verbose",
        f"request: image={image_path.name}, model={model}, ocr_passes={ocr_pass_count(mode)}, validate_render={validate_render}",
    )

    try:
        with quiet_model_output():
            result = engine.predict(str(image_path), model, mode, validate_render, log_verbosity)
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        return json_response({"ok": False, "error": str(exc)})

    worker_log(log_verbosity, "verbose", "response: ok=True")
    return json_response(result)


def run(args):
    try:
        with quiet_model_output():
            engine = UniMEREngine(args.unimernet_path)
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        print(json_response({"ok": False, "ready": False, "error": str(exc)}), flush=True)
        return

    print(json_response({"ok": True, "ready": True}), flush=True)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if line == "quit":
            break
        print(handle_request(line, engine), flush=True)


def main():
    parser = argparse.ArgumentParser(description="UniMERNet JSON-line OCR worker")
    parser.add_argument("--unimernet-path", required=True)
    run(parser.parse_args())


if __name__ == "__main__":
    main()
