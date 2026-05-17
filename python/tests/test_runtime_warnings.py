import unittest
import warnings

from snaptex_worker.runtime_warnings import configure_warning_filters


class RuntimeWarningTests(unittest.TestCase):
    def test_configure_warning_filters_suppresses_paddle_ccache_warning(self):
        with warnings.catch_warnings(record=True) as caught:
            warnings.resetwarnings()
            configure_warning_filters()

            warnings.warn(
                "No ccache found. Please be aware that recompiling all source files may be required.",
                UserWarning,
            )

        self.assertEqual([], caught)

    def test_configure_warning_filters_preserves_unrelated_user_warnings(self):
        with warnings.catch_warnings(record=True) as caught:
            warnings.resetwarnings()
            configure_warning_filters()

            warnings.warn("A different warning", UserWarning)

        self.assertEqual(1, len(caught))


if __name__ == "__main__":
    unittest.main()
