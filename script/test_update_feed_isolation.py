"""Prove SceneMux cannot consume another project's Sparkle update feed.

SceneMux is derived from WinMux, which ships a signed Sparkle feed. If a SceneMux
build ever declared a feed URL it did not own, it would install another project's
binary over itself. SceneMux therefore ships with no feed at all, and these checks
fail the build if one appears without being reviewed.
"""

import plistlib
from pathlib import Path
import unittest

REPO = Path(__file__).resolve().parent.parent
INFO_PLIST = REPO / "resources" / "SceneMux-Info.plist"
PROJECT_YML = REPO / "project.yml"

# Sparkle reads the feed from one of these keys. SUFeedURL is the static feed;
# SUPublicEDKey is the EdDSA key an update must be signed with.
FEED_KEYS = ("SUFeedURL", "SUPublicEDKey", "SUFeedAlternateAppcastURL")
OWN_RELEASE_PREFIX = "https://github.com/Chisanan232/SceneMux/releases/"


class UpdateFeedIsolationTest(unittest.TestCase):
    def setUp(self):
        self.info = plistlib.loads(INFO_PLIST.read_bytes())
        self.project = PROJECT_YML.read_text()

    def test_bundle_declares_no_update_feed(self):
        for key in FEED_KEYS:
            self.assertNotIn(key, self.info, f"{INFO_PLIST.name} must not declare {key}")

    def test_bundle_disables_automatic_checks(self):
        self.assertIs(self.info.get("SUEnableAutomaticChecks"), False)

    def test_generated_xcode_project_declares_no_update_feed(self):
        # XcodeGen merges its own info.properties over the plist, so a feed added
        # there would ship even though the plist itself is clean.
        for key in FEED_KEYS:
            self.assertNotIn(key, self.project, f"project.yml must not declare {key}")

    def test_any_declared_feed_would_have_to_be_our_own(self):
        # A feed is allowed to exist later, but only under SceneMux's own releases.
        feed = self.info.get("SUFeedURL")
        if feed is not None:
            self.assertTrue(
                feed.startswith(OWN_RELEASE_PREFIX),
                f"SUFeedURL must point at {OWN_RELEASE_PREFIX}, got {feed}",
            )


if __name__ == "__main__":
    unittest.main()
