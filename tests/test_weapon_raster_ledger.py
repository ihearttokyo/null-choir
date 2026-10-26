"""Small dependency-free negative tests for the registered raster ledger validator.

These tests use synthetic path/PNG inputs only; they do not assert that any of
six production assets or native Godot receipts currently pass.
"""
from __future__ import annotations

import struct
import sys
import unittest
import hashlib
import json
import zlib
from pathlib import Path
from tempfile import TemporaryDirectory

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "source/art/weapon-raster-v3"))
import validate_ledger as ledger


def png_rgba(width=1, height=1, pixels=b"\x00\x00\x00\x00"):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload +
                struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))
    scanlines = b"".join(b"\x00" + pixels[y * width * 4:(y + 1) * width * 4]
                         for y in range(height))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))


class SafePathTests(unittest.TestCase):
    def test_repository_relative_path_allowed(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root = Path(tmp)
            (root / "source").mkdir()
            path = ledger.safe_rel(root, "source/ledger.json", label="test")
            self.assertEqual(path, root / "source/ledger.json")

    def test_absolute_and_private_path_rejected(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root = Path(tmp)
            for value in ("/Users/secret/file.png", "~/private.png", "C:/private.png", "file:///tmp/a"):
                with self.subTest(value=value), self.assertRaises(ledger.ContractError):
                    ledger.safe_rel(root, value, label="test")

    def test_traversal_and_noncanonical_paths_rejected(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root = Path(tmp)
            for value in ("source/../secret.png", "source//file.png", "source/./file.png", "source\\file.png"):
                with self.subTest(value=value), self.assertRaises(ledger.ContractError):
                    ledger.safe_rel(root, value, label="test")

    def test_symlink_path_rejected(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root = Path(tmp)
            outside = Path(tmp).parent / (Path(tmp).name + "-outside")
            outside.mkdir()
            try:
                (root / "alias").symlink_to(outside, target_is_directory=True)
                with self.assertRaises(ledger.ContractError):
                    ledger.safe_rel(root, "alias/file.png", label="test")
            finally:
                outside.rmdir()


class PngDecoderTests(unittest.TestCase):
    def test_synthetic_rgba_png_decodes(self):
        data = png_rgba(pixels=b"\x11\x22\x33\xff")
        dims, pixels = ledger.png_rgba(data)
        self.assertEqual(dims, (1, 1))
        self.assertEqual(pixels, b"\x11\x22\x33\xff")

    def test_corrupt_crc_rejected(self):
        data = bytearray(png_rgba())
        data[29] ^= 0x01
        with self.assertRaises(ledger.ContractError):
            ledger.png_rgba(bytes(data))

    def test_non_rgba_png_rejected(self):
        # Valid PNG structure but unsupported RGB color type.
        def chunk(kind, payload):
            return (struct.pack(">I", len(payload)) + kind + payload +
                    struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))
        ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
        data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
                chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00")) + chunk(b"IEND", b""))
        with self.assertRaises(ledger.ContractError):
            ledger.png_rgba(data)


class SmallShapeTests(unittest.TestCase):
    def test_exact_known_six_weapon_ids(self):
        self.assertEqual(len(ledger.IDS), 6)
        self.assertEqual(ledger.NATIVE_SIZE, (960, 200))
        self.assertEqual(ledger.CELL_SIZE, (320, 200))
        self.assertEqual(ledger.FRAMES, ("idle", "fire", "recover"))

    def test_pose_anchor_bounds_reject_outside_cell(self):
        for bad in ([-1, 0], [320, 199], [0, float("inf")], [True, 0]):
            with self.subTest(bad=bad), self.assertRaises(ledger.ContractError):
                ledger._finite_pair(bad, label="anchor", upper=(320, 200))


class LedgerGateTests(unittest.TestCase):
    def make_root(self, tmp):
        root=Path(tmp)
        catalog=root/"source/art/manifest.json"
        catalog.parent.mkdir(parents=True)
        catalog.write_text('{"assets":[]}\n')
        digest=hashlib.sha256(catalog.read_bytes()).hexdigest()
        entries=[{"id":asset_id,"weapon_index":index} for index,asset_id in enumerate(sorted(ledger.IDS))]
        doc={
          "schema_version":1,
          "kind":"six-production-directed-registered-raster-weapon-atlases",
          "runtime_contract":{"atlas":[960,200],"cell_size":[320,200],"columns":3,
            "frames":["idle","fire","recover"],"alpha":[0,255],"origin_px":[160,200],"impact_flash":False},
          "legacy_catalog":{"path":"source/art/manifest.json","sha256_unchanged":digest},
          "assets":entries,
        }
        target=root/"source/art/weapon-raster-v3.json"
        target.write_text(json.dumps(doc))
        return root,target,doc

    def test_duplicate_or_unknown_ids_rejected_before_asset_reads(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root,path,doc=self.make_root(tmp)
            doc["assets"][0]["id"]="unknown_weapon"
            path.write_text(json.dumps(doc))
            with self.assertRaisesRegex(ledger.ContractError,"exact known six weapon IDs"):
                ledger.validate_ledger(root,"source/art/weapon-raster-v3.json")
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root,path,doc=self.make_root(tmp)
            doc["assets"][0]["id"]=doc["assets"][1]["id"]
            path.write_text(json.dumps(doc))
            with self.assertRaisesRegex(ledger.ContractError,"exact known six weapon IDs"):
                ledger.validate_ledger(root,"source/art/weapon-raster-v3.json")

    def test_mutated_shared_atlas_contract_rejected(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root,path,doc=self.make_root(tmp)
            doc["runtime_contract"]["columns"]=4
            path.write_text(json.dumps(doc))
            with self.assertRaisesRegex(ledger.ContractError,"shared runtime atlas contract"):
                ledger.validate_ledger(root,"source/art/weapon-raster-v3.json")

    def test_absolute_path_leak_rejected(self):
        with TemporaryDirectory(dir=Path.cwd()) as tmp:
            root,path,doc=self.make_root(tmp)
            doc["provenance"]="candidate at /Users/private/generated.png"
            path.write_text(json.dumps(doc))
            with self.assertRaisesRegex(ledger.ContractError,"private/absolute path leak"):
                ledger.validate_ledger(root,"source/art/weapon-raster-v3.json")


if __name__ == "__main__":
    unittest.main()
