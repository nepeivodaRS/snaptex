import unittest
import json
import tempfile
from unittest import mock
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

from tqdm.contrib.concurrent import thread_map

from snaptex_worker import download_model as download_model_module
from snaptex_worker.download_model import (
    JsonProgress,
    build_snapshot_download_kwargs,
    normalize_unimernet_variant,
)


class DownloadModelTests(unittest.TestCase):
    def test_build_snapshot_download_kwargs_uses_variant_repo_and_target(self):
        kwargs = build_snapshot_download_kwargs(
            variant=normalize_unimernet_variant("m"),
            target=Path("/tmp/models/unimernet_small"),
            progress_json=False,
            supported_parameters={"repo_id", "local_dir", "local_dir_use_symlinks"},
        )

        self.assertEqual("wanderkid/unimernet_small", kwargs["repo_id"])
        self.assertEqual("/tmp/models/unimernet_small", kwargs["local_dir"])
        self.assertFalse(kwargs["local_dir_use_symlinks"])
        self.assertNotIn("tqdm_class", kwargs)

    def test_build_snapshot_download_kwargs_adds_json_progress_when_supported(self):
        kwargs = build_snapshot_download_kwargs(
            variant="base",
            target=Path("/tmp/models/unimernet_base"),
            progress_json=True,
            supported_parameters={"repo_id", "local_dir", "tqdm_class"},
        )

        self.assertEqual("wanderkid/unimernet_base", kwargs["repo_id"])
        self.assertIn("tqdm_class", kwargs)

    def test_normalize_unimernet_variant_accepts_model_size_aliases(self):
        self.assertEqual("tiny", normalize_unimernet_variant("s"))
        self.assertEqual("small", normalize_unimernet_variant("m"))
        self.assertEqual("base", normalize_unimernet_variant("l"))

    def test_download_model_uses_structured_provider_directory(self):
        downloaded = []

        def fake_snapshot_download(**kwargs):
            downloaded.append(kwargs)

        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(
                download_model_module,
                "import_snapshot_download",
                return_value=fake_snapshot_download,
            ):
                with redirect_stdout(StringIO()):
                    target = download_model_module.download_model("m", temporary)

            expected = Path(temporary).resolve() / "unimernet" / "m"

        self.assertEqual(expected, target)
        self.assertEqual(str(expected), downloaded[0]["local_dir"])

    def test_download_model_instantiates_paddle_formula_recognition_in_structured_cache(self):
        calls = []

        class FakeFormulaRecognition:
            def __init__(self, **kwargs):
                calls.append(kwargs)

        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(
                download_model_module,
                "import_formula_recognition",
                return_value=FakeFormulaRecognition,
            ):
                with mock.patch.dict("os.environ", {}, clear=True):
                    with redirect_stdout(StringIO()):
                        target = download_model_module.download_model(
                            "l",
                            temporary,
                            provider="paddlepaddle",
                        )

                    expected_cache_home = Path(temporary).resolve() / "paddlepaddle"
                    expected = (
                        expected_cache_home
                        / "official_models"
                        / "PP-FormulaNet_plus-L"
                    )

                    self.assertEqual(
                        str(expected_cache_home),
                        download_model_module.os.environ["PADDLE_PDX_CACHE_HOME"],
                    )

        self.assertEqual(expected, target)
        self.assertEqual({"model_name": "PP-FormulaNet_plus-L"}, calls[0])

    def test_download_model_removes_invalid_paddle_cache_before_loading(self):
        target_existed_during_load = []

        with tempfile.TemporaryDirectory() as temporary:
            target = (
                Path(temporary).resolve()
                / "paddlepaddle"
                / "official_models"
                / "PP-FormulaNet_plus-M"
            )
            target.mkdir(parents=True)
            (target / "inference.json").write_text("partial")

            class FakeFormulaRecognition:
                def __init__(self, **kwargs):
                    target_existed_during_load.append(target.exists())

            with mock.patch.object(
                download_model_module,
                "import_formula_recognition",
                return_value=FakeFormulaRecognition,
            ):
                with redirect_stdout(StringIO()):
                    download_model_module.download_model(
                        "m",
                        temporary,
                        provider="paddlepaddle",
                    )

        self.assertEqual([False], target_existed_during_load)

    def test_json_progress_works_with_tqdm_thread_map(self):
        output = StringIO()

        with redirect_stdout(output):
            result = thread_map(lambda value: value + 1, [1, 2], tqdm_class=JsonProgress)

        self.assertEqual([2, 3], result)
        events = [
            json.loads(line)
            for line in output.getvalue().splitlines()
            if line.strip()
        ]
        self.assertTrue(any(event["event"] == "progress" for event in events))


if __name__ == "__main__":
    unittest.main()
