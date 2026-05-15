import unittest
import json
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

from tqdm.contrib.concurrent import thread_map

from snaptex_worker.download_model import JsonProgress, build_snapshot_download_kwargs


class DownloadModelTests(unittest.TestCase):
    def test_build_snapshot_download_kwargs_uses_variant_repo_and_target(self):
        kwargs = build_snapshot_download_kwargs(
            variant="small",
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
