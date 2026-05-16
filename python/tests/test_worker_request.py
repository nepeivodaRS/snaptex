import contextlib
import json
import sys
import types
from unittest import mock
from pathlib import Path
import tempfile
import unittest

from PIL import Image
import yaml

from snaptex_worker.worker import PaddleFormulaEngine, UniMEREngine, handle_request, normalize_model_selection


class FakeEngine:
    def __init__(self):
        self.arguments = None

    def predict(self, image_path, model_selection, mode, validate_render, log_verbosity):
        self.arguments = {
            "image_path": image_path,
            "model": model_selection,
            "mode": mode,
            "validate_render": validate_render,
            "log_verbosity": log_verbosity,
        }
        return {
            "ok": True,
            "prediction": "x",
            "alternatives": ["x"],
            "model": model_selection,
            "mode": mode,
        }


class FakeTensor:
    def __init__(self, batch_size=1):
        self.batch_size = batch_size

    def unsqueeze(self, _dimension):
        return self

    def to(self, _device):
        return self

    def dim(self):
        return 4

    def repeat(self, batch_size, *_repeats):
        return FakeTensor(batch_size)


class FakeProcessor:
    def __call__(self, _image):
        return FakeTensor()


class FakeModel:
    def __init__(self):
        self.calls = []

    def generate(self, payload, **kwargs):
        image = payload["image"]
        batch_size = image.batch_size
        self.calls.append({"batch_size": batch_size, "kwargs": kwargs})
        if kwargs.get("do_sample"):
            return {"pred_str": [f"sampled-{index}" for index in range(batch_size)]}
        return {"pred_str": ["deterministic"]}


class WorkerRequestTests(unittest.TestCase):
    def test_handle_request_passes_log_verbosity_to_engine(self):
        image = Image.new("RGB", (8, 8), "white")
        with tempfile.NamedTemporaryFile(suffix=".png") as handle:
            image.save(handle.name)
            engine = FakeEngine()
            response = handle_request(
                json.dumps(
                    {
                        "image_path": handle.name,
                        "model": {"provider": "paddlepaddle", "size": "l"},
                        "mode": "accurate",
                        "validate_render": True,
                        "log_verbosity": "debug",
                    }
                ),
                engine,
            )

        payload = json.loads(response)

        self.assertTrue(payload["ok"])
        self.assertEqual("debug", engine.arguments["log_verbosity"])
        self.assertEqual("paddlepaddle", engine.arguments["model"]["provider"])
        self.assertEqual("PP-FormulaNet_plus-L", engine.arguments["model"]["model_name"])

    def test_normalize_model_selection_maps_unimernet_size_to_existing_variant(self):
        selection = normalize_model_selection({"provider": "unimernet", "size": "s"})

        self.assertEqual("unimernet", selection["provider"])
        self.assertEqual("s", selection["size"])
        self.assertEqual("tiny", selection["model_name"])

    def test_normalize_model_selection_maps_paddle_size_to_plus_model_name(self):
        selection = normalize_model_selection({"provider": "paddlepaddle", "size": "m"})

        self.assertEqual("paddlepaddle", selection["provider"])
        self.assertEqual("m", selection["size"])
        self.assertEqual("PP-FormulaNet_plus-M", selection["model_name"])

    def test_normalize_model_selection_accepts_legacy_unimernet_string(self):
        selection = normalize_model_selection("base")

        self.assertEqual("unimernet", selection["provider"])
        self.assertEqual("l", selection["size"])
        self.assertEqual("base", selection["model_name"])

    def test_paddle_import_error_reports_exact_install_commands(self):
        original_import = __import__

        def import_without_paddleocr(name, *args, **kwargs):
            if name == "paddleocr":
                raise ModuleNotFoundError("No module named 'paddleocr'")
            return original_import(name, *args, **kwargs)

        engine = PaddleFormulaEngine()

        with mock.patch("builtins.__import__", side_effect=import_without_paddleocr):
            with self.assertRaises(ImportError) as error:
                engine._load_model("PP-FormulaNet_plus-S")

        message = str(error.exception)

        self.assertIn(sys.executable, message)
        self.assertIn("python -m pip install paddlepaddle==3.0.0", message)
        self.assertIn("python -m pip install paddleocr", message)

    def test_config_for_accepts_huggingface_pytorch_model_pth(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "configs" / "val" / "unimernet_base.yaml"
            model_file = root / "models" / "unimernet_base" / "pytorch_model.pth"
            config.parent.mkdir(parents=True)
            model_file.parent.mkdir(parents=True)
            model_file.write_bytes(b"")
            config.write_text(
                yaml.safe_dump(
                    {
                        "model": {
                            "model_config": {},
                            "load_pretrained": False,
                            "load_finetuned": False,
                        }
                    }
                ),
                encoding="utf-8",
            )

            engine = object.__new__(UniMEREngine)
            engine.unimernet_path = root
            resolved_config = engine._config_for("base")

        with Path(resolved_config).open("r", encoding="utf-8") as handle:
            payload = yaml.safe_load(handle)

        self.assertTrue(payload["model"]["load_pretrained"])
        self.assertFalse(payload["model"]["load_finetuned"])
        self.assertEqual(str(model_file), payload["model"]["pretrained"])

    def test_accurate_mode_generates_sampled_passes_as_one_batch(self):
        image = Image.new("RGB", (8, 8), "white")
        with tempfile.NamedTemporaryFile(suffix=".png") as handle:
            image.save(handle.name)
            model = FakeModel()
            engine = object.__new__(UniMEREngine)
            engine.device = "cpu"
            engine.torch = types.SimpleNamespace(inference_mode=contextlib.nullcontext)
            engine._load_model = lambda _model_name, _log_verbosity: (model, FakeProcessor())

            result = engine.predict(handle.name, "tiny", "accurate", True)

        self.assertEqual(["deterministic", "sampled-0", "sampled-1"], result["alternatives"])
        self.assertEqual(2, len(model.calls))
        self.assertEqual({"do_sample": False}, model.calls[0]["kwargs"])
        self.assertEqual(1, model.calls[0]["batch_size"])
        self.assertEqual(2, model.calls[1]["batch_size"])
        self.assertTrue(model.calls[1]["kwargs"]["do_sample"])
        self.assertGreater(model.calls[1]["kwargs"]["temperature"], 0)
        self.assertGreater(model.calls[1]["kwargs"]["top_p"], 0)


if __name__ == "__main__":
    unittest.main()
