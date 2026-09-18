import json
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]


class ManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / "manifest.json").read_text())

    def test_identity_and_entry_point(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(self.manifest["id"], "jesusarchive.eyes")
        self.assertEqual(self.manifest["kinds"], ["bar-widget"])
        entry_point = self.manifest["entryPoints"]["barWidget"]
        self.assertTrue((ROOT / entry_point).is_file())

    def test_widget_has_no_settings(self):
        widget = self.manifest["barWidget"]
        self.assertNotIn("defaults", widget)
        self.assertNotIn("schema", widget)


if __name__ == "__main__":
    unittest.main()
