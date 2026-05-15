import argparse
import inspect
import json
import os
from pathlib import Path

from tqdm.auto import tqdm


MODEL_VARIANTS = ("tiny", "small", "base")


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


def download_model(variant, models_dir, progress_json=False):
    target = Path(models_dir).expanduser().resolve() / f"unimernet_{variant}"
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


def import_snapshot_download():
    from huggingface_hub import snapshot_download

    return snapshot_download


def main():
    parser = argparse.ArgumentParser(description="Download UniMERNet model files")
    parser.add_argument("--variant", choices=MODEL_VARIANTS, default="small")
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

    download_model(
        variant=args.variant,
        models_dir=args.models_dir,
        progress_json=args.progress_json,
    )


if __name__ == "__main__":
    main()
