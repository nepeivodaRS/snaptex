import argparse
import inspect
import json
import os
import shutil
from pathlib import Path

from tqdm.auto import tqdm

from snaptex_worker.runtime_warnings import configure_warning_filters

configure_warning_filters()

MODEL_PROVIDERS = ("unimernet", "paddlepaddle")
MODEL_VARIANTS = ("tiny", "small", "base")
PADDLE_CONFIG_FILENAME = "inference.yml"
MODEL_SIZE_ALIASES = {
    "s": "tiny",
    "m": "small",
    "l": "base",
}
PADDLE_MODEL_ALIASES = {
    "s": "PP-FormulaNet_plus-S",
    "m": "PP-FormulaNet_plus-M",
    "l": "PP-FormulaNet_plus-L",
    "small": "PP-FormulaNet_plus-S",
    "medium": "PP-FormulaNet_plus-M",
    "large": "PP-FormulaNet_plus-L",
    "PP-FormulaNet_plus-S": "PP-FormulaNet_plus-S",
    "PP-FormulaNet_plus-M": "PP-FormulaNet_plus-M",
    "PP-FormulaNet_plus-L": "PP-FormulaNet_plus-L",
}


def default_models_dir():
    configured = os.environ.get("UNIMERNET_MODELS_DIR")
    if configured:
        return configured
    return str(Path.home() / "Library" / "Application Support" / "snaptex" / "UniMERNet" / "models")


def build_snapshot_download_kwargs(variant, target, progress_json, supported_parameters=None):
    if supported_parameters is None:
        supported_parameters = set(inspect.signature(import_snapshot_download()).parameters)

    kwargs = {
        "repo_id": f"wanderkid/unimernet_{variant}",
        "local_dir": str(target),
    }
    if "local_dir_use_symlinks" in supported_parameters:
        kwargs["local_dir_use_symlinks"] = False
    if progress_json and "tqdm_class" in supported_parameters:
        kwargs["tqdm_class"] = JsonProgress
    return kwargs


def normalize_unimernet_variant(value):
    variant = value.strip().lower()
    variant = MODEL_SIZE_ALIASES.get(variant, variant)
    if variant not in MODEL_VARIANTS:
        raise ValueError(f"Unknown UniMERNet model variant: {value}")
    return variant


def normalize_unimernet_storage_name(value):
    variant = normalize_unimernet_variant(value)
    return {
        "tiny": "s",
        "small": "m",
        "base": "l",
    }[variant]


def normalize_paddle_model_name(value):
    trimmed = value.strip()
    model_name = PADDLE_MODEL_ALIASES.get(
        trimmed,
        PADDLE_MODEL_ALIASES.get(trimmed.lower()),
    )
    if not model_name:
        raise ValueError(f"Unknown PaddlePaddle model variant: {value}")
    return model_name


class JsonProgress(tqdm):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("mininterval", 0)
        kwargs.setdefault("miniters", 1)
        kwargs.setdefault("leave", False)
        super().__init__(*args, **kwargs)

    def display(self, *args, **kwargs):
        self._emit()

    def close(self):
        self._emit()
        super().close()

    def _emit(self):
        current = getattr(self, "n", 0)
        total = getattr(self, "total", None)
        progress = None
        if total:
            progress = max(0, min(1, current / total))
        print(
            json.dumps(
                {
                    "event": "progress",
                    "current": current,
                    "total": total,
                    "progress": progress,
                }
            ),
            flush=True,
        )


def download_model(variant, models_dir, provider="unimernet", progress_json=False):
    provider = provider.strip().lower()
    if provider == "unimernet":
        return download_unimernet_model(variant, models_dir, progress_json=progress_json)
    if provider == "paddlepaddle":
        return download_paddle_model(variant, models_dir, progress_json=progress_json)
    raise ValueError(f"Unknown model provider: {provider}")


def download_unimernet_model(variant, models_dir, progress_json=False):
    storage_name = normalize_unimernet_storage_name(variant)
    variant = normalize_unimernet_variant(variant)
    target = Path(models_dir).expanduser().resolve() / "unimernet" / storage_name
    target.mkdir(parents=True, exist_ok=True)

    if progress_json:
        print(json.dumps({"event": "progress", "progress": 0}), flush=True)

    import_snapshot_download()(
        **build_snapshot_download_kwargs(
            variant=variant,
            target=target,
            progress_json=progress_json,
        )
    )

    if progress_json:
        print(json.dumps({"event": "progress", "progress": 1}), flush=True)
        print(json.dumps({"event": "complete", "path": str(target)}), flush=True)
    else:
        print(target)

    return target


def download_paddle_model(variant, models_dir, progress_json=False):
    model_name = normalize_paddle_model_name(variant)
    cache_home = Path(models_dir).expanduser().resolve() / "paddlepaddle"
    target = cache_home / "official_models" / model_name
    cache_home.mkdir(parents=True, exist_ok=True)
    # PaddleOCR owns the actual download. SnapTex steers its cache location so
    # the macOS app can discover, reveal, and delete the installed model files.
    os.environ["PADDLE_PDX_CACHE_HOME"] = str(cache_home)
    remove_invalid_paddle_cache(target)

    if progress_json:
        print(json.dumps({"event": "progress", "progress": 0}), flush=True)

    formula_recognition = import_formula_recognition()
    formula_recognition(model_name=model_name)

    if progress_json:
        print(json.dumps({"event": "progress", "progress": 1}), flush=True)
        print(json.dumps({"event": "complete", "path": str(target)}), flush=True)
    else:
        print(target)

    return target


def remove_invalid_paddle_cache(target):
    if not target.exists() or paddle_model_cache_is_valid(target):
        return
    if target.is_dir():
        shutil.rmtree(target)
    else:
        target.unlink()


def paddle_model_cache_is_valid(target):
    return (target / PADDLE_CONFIG_FILENAME).is_file()


def import_snapshot_download():
    from huggingface_hub import snapshot_download

    return snapshot_download


def import_formula_recognition():
    try:
        from paddleocr import FormulaRecognition
    except ImportError as exc:
        raise ImportError(
            "PaddleOCR is not installed in this Python environment. Install it with "
            "`python -m pip install paddlepaddle==3.0.0` and "
            "`python -m pip install paddleocr`."
        ) from exc
    return FormulaRecognition


def main():
    parser = argparse.ArgumentParser(description="Download OCR model files")
    parser.add_argument("--provider", choices=MODEL_PROVIDERS, default="unimernet")
    parser.add_argument("--variant", default="m")
    parser.add_argument(
        "--models-dir",
        default=default_models_dir(),
    )
    parser.add_argument(
        "--progress-json",
        action="store_true",
        help="Write newline-delimited JSON progress events to stdout.",
    )
    args = parser.parse_args()

    try:
        download_model(
            variant=args.variant,
            models_dir=args.models_dir,
            provider=args.provider,
            progress_json=args.progress_json,
        )
    except ValueError as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()
