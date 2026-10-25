"""Artifact integrity, not artistic or gameplay acceptance."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source/art/descent"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class DescentArt(unittest.TestCase):
    def test_compact_runtime_art(self):
        manifest = json.loads((SOURCE / "MASTER-PINS.json").read_text())
        self.assertEqual(len(manifest["masters"]), 8)
        total = 0
        for row in manifest["masters"]:
            path = ROOT / "game/assets/art/descent" / (row["view"] + ".jpg")
            self.assertEqual(sha(path), row["runtime_sha256"])
            total += path.stat().st_size
            with Image.open(path) as image:
                self.assertEqual(image.size, (640, 360))
                self.assertEqual(image.format, "JPEG")
                self.assertFalse(image.getexif())
        self.assertLess(total, 200 * 1024)

    def test_editable_sources_and_pinned_inputs(self):
        for source in json.loads((SOURCE / "PROVENANCE.json").read_text())["sources"]:
            folder = SOURCE / source["source"]
            for key, name in [("recipe_sha256", "producer.py"), ("inputs_sha256", "inputs.json"),
                              ("inspection_recipe_sha256", "glb_inputs.py"),
                              ("blend_sha256", "native/build01/descent.blend")]:
                self.assertEqual(sha(folder / name), source[key])
            for row in json.loads((folder / "inputs.json").read_text())["assets"].values():
                self.assertEqual(sha(SOURCE / "intro-architecture-inputs02" / row["path"]), row["sha256"])
        for row in json.loads((SOURCE / "heart74/DEPENDENCIES.json").read_text())["files"]:
            self.assertEqual(sha(SOURCE / "heart74" / row["file"]), row["sha256"])

    def test_title_background_provenance(self):
        pins = json.loads((SOURCE / "TITLE-PINS.json").read_text())
        self.assertEqual(sha(SOURCE / "title-native.png"), pins["png_sha256"])
        self.assertEqual(sha(SOURCE / "heart74/native/build01/descent.blend"), pins["blend_sha256"])
        image = ROOT / "game/assets/art/title/cathedral.jpg"
        self.assertEqual(sha(image), pins["runtime_sha256"])
        with Image.open(image) as runtime:
            self.assertEqual(runtime.size, (640, 360))
            self.assertFalse(runtime.getexif())

    def test_changed_master_rejected(self):
        spec = importlib.util.spec_from_file_location("descent_builder", ROOT / "tools/build_descent_runtime.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        manifest = json.loads((SOURCE / "MASTER-PINS.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            changed = Path(directory) / "changed.png"
            changed.write_bytes(b"not an accepted master")
            inputs = {row["view"]: changed for row in manifest["masters"]}
            with self.assertRaisesRegex(ValueError, "Changed master"):
                builder.encode(inputs, manifest)


if __name__ == "__main__":
    unittest.main()
