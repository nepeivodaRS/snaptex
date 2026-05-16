import unittest
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[2]


class BuildScriptTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT_DIR / "scripts" / "build_and_run.sh").read_text()

    def test_build_defaults_to_existing_installed_bundle_id(self):
        self.assertIn("EXISTING_BUNDLE_ID", self.source)
        self.assertIn(
            'BUNDLE_ID="${SNAPTEX_BUNDLE_ID:-${EXISTING_BUNDLE_ID:-dev.snaptex.app}}"',
            self.source,
        )

    def test_build_uses_rnepeiv_signing_identity_and_strips_quarantine(self):
        self.assertIn('DEFAULT_SIGNING_IDENTITY="${SNAPTEX_DEFAULT_SIGNING_IDENTITY:-rnepeiv Local Development}"', self.source)
        self.assertNotIn("installed_signing_identity()", self.source)
        self.assertNotIn("tabchik Local Development", self.source)
        self.assertIn("strip_quarantine()", self.source)
        self.assertIn("xattr -dr com.apple.quarantine", self.source)
        self.assertIn('codesign --verify --deep --strict "$INSTALL_BUNDLE"', self.source)

    def test_build_does_not_silently_fall_back_to_ad_hoc_signing(self):
        self.assertIn("SNAPTEX_ALLOW_ADHOC_SIGNING", self.source)
        self.assertNotIn("code-signing identity failed; used ad-hoc signing", self.source)
        self.assertNotIn("no matching code-signing identity found; used ad-hoc signing", self.source)
        self.assertIn("exit 1", self.source)

    def test_build_reopens_installed_bundle_without_forcing_new_instance(self):
        self.assertIn('/usr/bin/open "$INSTALL_BUNDLE"', self.source)
        self.assertNotIn('/usr/bin/open -n "$INSTALL_BUNDLE"', self.source)

    def test_build_invokes_icon_generator_from_root_dir(self):
        self.assertIn('python "$ROOT_DIR/scripts/make_app_icon.py"', self.source)
        self.assertNotIn("python scripts/make_app_icon.py", self.source)


if __name__ == "__main__":
    unittest.main()
