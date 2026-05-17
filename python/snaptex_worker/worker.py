import argparse
import contextlib
import io
import json
import os
import sys
import tempfile
import traceback
from pathlib import Path

import yaml
from PIL import Image, ImageOps, ImageStat

try:
    from snaptex_worker.runtime_warnings import configure_warning_filters
except ModuleNotFoundError:
    from runtime_warnings import configure_warning_filters

os.environ.setdefault("NO_ALBUMENTATIONS_UPDATE", "1")
configure_warning_filters()


LOG_VERBOSITY_RANKS = {
    "normal": 0,
    "verbose": 1,
    "debug": 2,
}
SAMPLED_PASS_TEMPERATURE = 0.85
SAMPLED_PASS_TOP_P = 0.95
MODEL_SIZES = {"s", "m", "l"}
UNIMERNET_SIZE_TO_VARIANT = {
    "s": "tiny",
    "m": "small",
    "l": "base",
}
UNIMERNET_VARIANT_TO_SIZE = {
    "tiny": "s",
    "small": "m",
    "base": "l",
}
PADDLE_SIZE_TO_MODEL = {
    "s": "PP-FormulaNet_plus-S",
    "m": "PP-FormulaNet_plus-M",
    "l": "PP-FormulaNet_plus-L",
}


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


def normalize_model_selection(value):
    # The Swift side now sends provider/size dictionaries, but older settings
    # may still contain legacy UniMERNet strings such as "tiny" or "base".
    if value is None:
        return make_model_selection("unimernet", "m")

    if isinstance(value, dict):
        provider = normalize_model_provider(value.get("provider"))
        size = normalize_model_size(value.get("size"))
        return make_model_selection(provider, size)

    if isinstance(value, str):
        identifier = value.strip().lower()
        if identifier in UNIMERNET_VARIANT_TO_SIZE:
            return make_model_selection("unimernet", UNIMERNET_VARIANT_TO_SIZE[identifier])
        if identifier in MODEL_SIZES:
            return make_model_selection("unimernet", identifier)
        for size, model_name in PADDLE_SIZE_TO_MODEL.items():
            if identifier in {f"paddlepaddle-{size}", model_name.lower()}:
                return make_model_selection("paddlepaddle", size)

    raise ValueError(f"Unknown OCR model selection: {value}")


def normalize_model_provider(value):
    provider = (value or "unimernet").strip().lower()
    if provider in {"unimernet", "uni_mer_net"}:
        return "unimernet"
    if provider in {"paddle", "paddlepaddle", "paddle_paddle"}:
        return "paddlepaddle"
    raise ValueError(f"Unknown OCR model provider: {value}")


def normalize_model_size(value):
    size = (value or "m").strip().lower()
    if size in MODEL_SIZES:
        return size
    if size in UNIMERNET_VARIANT_TO_SIZE:
        return UNIMERNET_VARIANT_TO_SIZE[size]
    raise ValueError(f"Unknown OCR model size: {value}")


def make_model_selection(provider, size):
    if provider == "unimernet":
        model_name = UNIMERNET_SIZE_TO_VARIANT[size]
    elif provider == "paddlepaddle":
        model_name = PADDLE_SIZE_TO_MODEL[size]
    else:
        raise ValueError(f"Unknown OCR model provider: {provider}")

    return {
        "provider": provider,
        "size": size,
        "model_name": model_name,
        "response": {
            "provider": provider,
            "size": size,
        },
    }


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


def paddle_prediction_strings(output):
    items = output if isinstance(output, list) else [output]
    predictions = []
    for item in items:
        prediction = paddle_prediction_string(item)
        if prediction:
            predictions.append(prediction)
    return predictions


def paddle_prediction_string(item):
    if isinstance(item, dict):
        return prediction_from_mapping(item)

    for attribute in ("res", "json"):
        value = getattr(item, attribute, None)
        if callable(value):
            value = value()
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except json.JSONDecodeError:
                pass
        if isinstance(value, dict):
            prediction = prediction_from_mapping(value)
            if prediction:
                return prediction

    return None


def prediction_from_mapping(value):
    if "rec_formula" in value:
        return str(value["rec_formula"]).strip()
    nested = value.get("res")
    if isinstance(nested, dict) and "rec_formula" in nested:
        return str(nested["rec_formula"]).strip()
    return None


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
        # Normalize dark screenshots to black-on-white before OCR so the model
        # inputs match the light-background path used elsewhere.
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
        if not (self.unimernet_path / "unimernet").is_dir():
            raise FileNotFoundError(
                "UniMERNet runtime path is missing the unimernet Python package: "
                f"{self.unimernet_path}"
            )
        if not (self.unimernet_path / "configs" / "val").is_dir():
            raise FileNotFoundError(
                "UniMERNet runtime path is missing config templates: "
                f"{self.unimernet_path / 'configs' / 'val'}"
            )

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

    def predict(self, image_path, model_name, mode, validate_render, log_verbosity="normal", model_storage_path=None):
        worker_log(
            log_verbosity,
            "verbose",
            f"predict start: model={model_name}, ocr_passes={ocr_pass_count(mode)}, validate_render={validate_render}, device={self.device}",
        )
        model, processor = self._load_model(model_name, log_verbosity, model_storage_path=model_storage_path)
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

    def _load_model(self, model_name, log_verbosity="normal", model_storage_path=None):
        storage_key = str(Path(model_storage_path).expanduser()) if model_storage_path else ""
        cache_key = (model_name, storage_key)
        if cache_key in self.cache:
            worker_log(log_verbosity, "verbose", f"model cache hit: {model_name}")
            return self.cache[cache_key]

        worker_log(log_verbosity, "verbose", f"model load start: {model_name}")
        config_path = self._config_for(model_name, model_storage_path=model_storage_path)
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

        self.cache[cache_key] = (model, processor)
        worker_log(log_verbosity, "verbose", f"model load complete: {model_name}")
        return model, processor

    def _config_for(self, model_name, model_storage_path=None):
        template = self.unimernet_path / "configs" / "val" / f"unimernet_{model_name}.yaml"
        if not template.exists():
            raise FileNotFoundError(f"Missing UniMERNet config: {template}")

        with template.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)

        models_dir = self.unimernet_path / "models"
        model_dirs = []
        if model_storage_path:
            model_dirs.append(Path(model_storage_path).expanduser())
        storage_name = UNIMERNET_VARIANT_TO_SIZE.get(model_name)
        if storage_name:
            model_dirs.append(models_dir / "unimernet" / storage_name)
        model_dirs.extend(
            [
                models_dir / "unimernet" / model_name,
                models_dir / f"unimernet_{model_name}",
            ]
        )
        legacy_model_dir = models_dir / f"unimernet_{model_name}"
        root_pth = models_dir / f"unimernet_{model_name}.pth"

        if root_pth.exists():
            # Older local setups stored one fine-tuned checkpoint at the runtime
            # root. Keep that path working while newer downloads live under
            # provider/size directories.
            data["model"]["model_config"]["model_name"] = str(legacy_model_dir)
            data["model"]["tokenizer_config"] = {"path": str(legacy_model_dir)}
            data["model"]["load_pretrained"] = False
            data["model"]["load_finetuned"] = True
            data["model"]["finetuned"] = str(root_pth)
        else:
            expected = [root_pth]
            for model_dir in model_dirs:
                candidates = [
                    model_dir / f"unimernet_{model_name}.pth",
                    model_dir / "pytorch_model.bin",
                    model_dir / "pytorch_model.pth",
                ]
                expected.extend(candidates)
                pretrained = next((candidate for candidate in candidates if candidate.exists()), None)
                if pretrained is None:
                    continue

                data["model"]["model_config"]["model_name"] = str(model_dir)
                data["model"]["tokenizer_config"] = {"path": str(model_dir)}
                data["model"]["load_pretrained"] = True
                data["model"]["load_finetuned"] = False
                data["model"]["pretrained"] = str(pretrained)
                break
            else:
                expected_paths = ", ".join(str(path) for path in expected)
                raise FileNotFoundError(
                    f"Model files not found for unimernet_{model_name}. "
                    f"Expected {expected_paths}."
                )

        temporary = tempfile.NamedTemporaryFile("w", suffix=f"-unimernet-{model_name}.yaml", delete=False)
        with temporary:
            yaml.safe_dump(data, temporary)
        return Path(temporary.name)


class PaddleFormulaEngine:
    def __init__(self):
        self.cache = {}

    def predict(self, image_path, model_selection, mode, validate_render, log_verbosity="normal"):
        model_name = model_selection["model_name"]
        model_dir = model_selection.get("model_storage_path")
        worker_log(
            log_verbosity,
            "verbose",
            f"predict start: model={model_name}, ocr_passes=1, validate_render={validate_render}, device=paddleocr",
        )
        model = self._load_model(model_name, log_verbosity, model_dir=model_dir)

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

        temporary = tempfile.NamedTemporaryFile(suffix="-snaptex-paddle.png", delete=False)
        temporary_path = Path(temporary.name)
        temporary.close()
        try:
            raw_image.save(temporary_path, format="PNG")
            output = model.predict(input=str(temporary_path), batch_size=1)
        finally:
            temporary_path.unlink(missing_ok=True)

        alternatives = unique(paddle_prediction_strings(output))
        worker_log(log_verbosity, "verbose", f"predict complete: alternatives={len(alternatives)}")
        return {
            "ok": True,
            "prediction": alternatives[0] if alternatives else "",
            "alternatives": alternatives,
            "model": model_selection["response"],
            "mode": mode,
        }

    def _load_model(self, model_name, log_verbosity="normal", model_dir=None):
        cache_key = (model_name, str(model_dir or ""))
        if cache_key in self.cache:
            worker_log(log_verbosity, "verbose", f"model cache hit: {model_name}")
            return self.cache[cache_key]

        worker_log(log_verbosity, "verbose", f"model load start: {model_name}")
        if model_dir:
            # PaddleOCR downloads official models under PADDLE_PDX_CACHE_HOME.
            # Point it at SnapTex's model directory so in-app deletion and
            # reveal actions operate on the same files PaddleOCR uses.
            cache_home = paddle_cache_home(model_dir)
            cache_home.mkdir(parents=True, exist_ok=True)
            os.environ["PADDLE_PDX_CACHE_HOME"] = str(cache_home)

        try:
            from paddleocr import FormulaRecognition
        except ImportError as exc:
            python = sys.executable
            raise ImportError(
                "PaddlePaddle OCR support requires paddleocr and paddlepaddle in the worker Python environment. "
                f"Python: {python}. "
                f"Install with: {python} -m pip install paddlepaddle==3.0.0 "
                "-i https://www.paddlepaddle.org.cn/packages/stable/cpu/ && "
                f"{python} -m pip install paddleocr. "
                "You can also rerun scripts/setup_snaptex_env.sh from the SnapTex checkout."
            ) from exc

        kwargs = {"model_name": model_name}

        with quiet_model_output():
            model = FormulaRecognition(**kwargs)
        self.cache[cache_key] = model
        worker_log(log_verbosity, "verbose", f"model load complete: {model_name}")
        return model


def paddle_cache_home(model_dir):
    model_dir = Path(model_dir).expanduser()
    if model_dir.parent.name == "official_models":
        return model_dir.parent.parent
    return model_dir.parent


class OCREngine:
    def __init__(self, unimernet_path):
        self.unimernet_path = unimernet_path
        self.unimernet_engine = None
        self.paddle_engine = None

    def predict(self, image_path, model_selection, mode, validate_render, log_verbosity="normal"):
        provider = model_selection["provider"]
        if provider == "unimernet":
            result = self._unimernet().predict(
                image_path,
                model_selection["model_name"],
                mode,
                validate_render,
                log_verbosity,
                model_selection.get("model_storage_path"),
            )
            result["model"] = model_selection["response"]
            return result

        if provider == "paddlepaddle":
            return self._paddle().predict(image_path, model_selection, mode, validate_render, log_verbosity)

        raise ValueError(f"Unknown OCR model provider: {provider}")

    def _unimernet(self):
        if self.unimernet_engine is None:
            self.unimernet_engine = UniMEREngine(self.unimernet_path)
        return self.unimernet_engine

    def _paddle(self):
        if self.paddle_engine is None:
            self.paddle_engine = PaddleFormulaEngine()
        return self.paddle_engine


def handle_request(line, engine):
    try:
        request = json.loads(line)
    except json.JSONDecodeError as exc:
        return json_response({"ok": False, "error": f"Invalid JSON: {exc}"})

    image_path = Path(request.get("image_path", "")).expanduser()
    if not image_path.exists():
        return json_response({"ok": False, "error": f"Image file not found: {image_path}"})

    try:
        model = normalize_model_selection(request.get("model"))
    except ValueError as exc:
        return json_response({"ok": False, "error": str(exc)})

    model_storage_value = request.get("model_storage_path")
    model_storage_path = model_storage_value.strip() if isinstance(model_storage_value, str) else ""
    if model_storage_path:
        model["model_storage_path"] = str(Path(model_storage_path).expanduser())

    mode = request.get("mode", "balanced")
    validate_render = bool(request.get("validate_render", True))
    log_verbosity = normalize_log_verbosity(request.get("log_verbosity", "normal"))
    worker_log(
        log_verbosity,
        "verbose",
        f"request: image={image_path.name}, model={model['model_name']}, ocr_passes={ocr_pass_count(mode)}, validate_render={validate_render}",
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
    engine = OCREngine(args.unimernet_path)
    print(json_response({"ok": True, "ready": True}), flush=True)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if line == "quit":
            break
        print(handle_request(line, engine), flush=True)


def main():
    parser = argparse.ArgumentParser(description="SnapTex JSON-line OCR worker")
    parser.add_argument("--unimernet-path", required=True)
    run(parser.parse_args())


if __name__ == "__main__":
    main()
