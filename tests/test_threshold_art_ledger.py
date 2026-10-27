from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "tools" / "threshold_art_ledger.py"
spec = importlib.util.spec_from_file_location("threshold_art_ledger", TOOL)
validator = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = validator
spec.loader.exec_module(validator)

ASSETS = [
    ("containment_gate", "intake", 8.2),
    ("foundry_gate", "foundry", 8.2),
    ("processional_gate", "processional", 8.2),
    ("reliquary_index_gate", "reliquary", 12.2),
    ("nursery_growth_gate", "nursery", 12.2),
    ("ossuary_transfer_gate", "ossuary", 12.2),
    ("inversion_alignment_gate", "inversion", 12.2),
    ("heart_final_gate", "heart", 12.2),
]
PNG = b"\x89PNG\r\n\x1a\nsynthetic-raster-payload"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write(path: Path, data: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return digest(data)


def json_bytes(obj) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def make_glb(asset_id: str, images: list[tuple[str, bytes]], *, external_image=False) -> bytes:
    binary = bytearray()
    views = []
    image_records = []
    for name, image in images:
        offset = len(binary)
        binary.extend(image)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(image)})
        while len(binary) % 4:
            binary.append(0)
        if external_image:
            image_records.append({"uri": name + ".png", "mimeType": "image/png", "name": name})
        else:
            image_records.append({"bufferView": len(views)-1, "mimeType": "image/png", "name": name})
    textures = [{"source": i} for i in range(len(images))]
    materials = [{"pbrMetallicRoughness": {"baseColorTexture": {"index": i}}} for i in range(len(images))]
    document = {
        "asset": {"version": "2.0", "generator": "unit-fixture"},
        "scene": 0, "scenes": [{"nodes": list(range(5))}],
        "nodes": [{"name": name} for name in validator.ROLES],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": views,
        "images": image_records,
        "textures": textures,
        "materials": materials,
    }
    encoded = json_bytes(document)
    encoded += b" " * ((-len(encoded)) % 4)
    binary_bytes = bytes(binary)
    json_chunk = struct.pack("<I4s", len(encoded), b"JSON") + encoded
    bin_chunk = struct.pack("<I4s", len(binary_bytes), b"BIN\x00") + binary_bytes
    total = 12 + len(json_chunk) + len(bin_chunk)
    return struct.pack("<4sII", b"glTF", 2, total) + json_chunk + bin_chunk


class ThresholdLedgerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=str(Path(tempfile.gettempdir()).resolve()))
        self.root = Path(self.tmp.name)
        self.ledger_path = "source/art/threshold-art-ledger-test.json"
        self.entries = []
        registry_lines = []
        for asset_id, scene, width in ASSETS:
            registry_lines.append(f'"{asset_id}":{{"scene":"{scene}","width":{width}}}')
        reg_text = "extends RefCounted\nconst REGISTRY={" + ",".join(registry_lines) + "}\nstatic func create(spec):\n\treturn {}\n"
        write(self.root / "game/scripts/gate_art.gd", reg_text.encode())
        for source_path in validator.NATIVE_CODE_SOURCES[1:]:
            write(self.root / source_path, ("# synthetic source fixture: " + source_path + "\n").encode())
        for i, (asset_id, scene, width) in enumerate(ASSETS, 1):
            size = [width, 5, 0.6]
            write(self.root / f"game/data/{i:02d}_{scene}.json", json_bytes({"doors": [{"id": asset_id, "size": size}]}))
            self.entries.append(self._make_entry(asset_id, scene, size))
        self._save_ledger()

    def tearDown(self):
        self.tmp.cleanup()

    def _make_entry(self, asset_id: str, scene: str, size: list) -> dict:
        source_dir = f"source/art/living-thresholds-v3/{scene}"
        runtime_path = f"game/assets/art/thresholds-v3/{scene}_threshold.glb"
        runtime_uri = "res://" + runtime_path.removeprefix("game/")
        source_bytes = b"BLENDER-v4-unit-fixture-" + asset_id.encode()
        source_rel = f"{source_dir}/{scene}_threshold.blend"
        source_sha = write(self.root / source_rel, source_bytes)
        recipe_rel = f"{source_dir}/build_source.py"
        recipe_sha = write(self.root / recipe_rel, b"# deterministic source builder fixture\n")
        raw_specs = [("membrane", f"{scene}_membrane.png", PNG), ("hardware", f"{scene}_hardware.png", PNG)]
        raw_inputs = []
        for role, filename, raw in raw_specs:
            path = f"{source_dir}/raw/{filename}"
            raw_inputs.append({"path": path, "sha256": write(self.root / path, raw)})
        uv_rel = f"{source_dir}/uv-registration.json"
        uv = {
            "coordinates": "test local UV coordinates",
            "membrane": {"file": f"raw/{raw_specs[0][1]}", "sha256": raw_inputs[0]["sha256"]},
            "hardware": {"file": f"raw/{raw_specs[1][1]}", "sha256": raw_inputs[1]["sha256"]},
        }
        uv_bytes = json_bytes(uv)
        uv_sha = write(self.root / uv_rel, uv_bytes)
        runtime = make_glb(asset_id, [(Path(p["path"]).stem, data) for p, (_, _, data) in zip(raw_inputs, raw_specs)])
        runtime_sha = write(self.root / runtime_path, runtime)
        sidecar = (
            '[remap]\nimporter="scene"\ntype="PackedScene"\n[deps]\n'
            f'source_file="{runtime_uri}"\n[params]\ngltf/embedded_image_handling=3\n'
        )
        write(self.root / (runtime_path + ".import"), sidecar.encode())
        proof_rel = f"{source_dir}/source-proof.json"
        proof = {
            "source": Path(source_rel).name, "source_sha256": source_sha,
            "recipe": Path(recipe_rel).name, "recipe_sha256": recipe_sha,
            "candidate_glb_sha256": runtime_sha, "candidate_glb_bytes": len(runtime),
            "packed_images": [
                {"name": Path(p["path"]).stem, "packed_sha256": p["sha256"]}
                for p in raw_inputs
            ],
        }
        proof_bytes = json_bytes(proof)
        proof_sha = write(self.root / proof_rel, proof_bytes)
        native_rel = f"{source_dir}/native-qualification.json"
        native = {
            "schema": "null-choir.threshold-native-qualification",
            "asset_id": asset_id, "runtime_sha256": runtime_sha,
            "source_blend_sha256": source_sha, "source_proof_sha256": proof_sha,
            "exit_code": 0, "strict": True, "diagnostics": [],
            "engine_version": "fixture-only-not-a-run", "run_id": "synthetic-unit-fixture",
            "claim_scope": "normal-import-and-runtime-consumer",
            "code_source_hashes": {path: digest((self.root / path).read_bytes()) for path in validator.NATIVE_CODE_SOURCES},
        }
        native_sha = write(self.root / native_rel, json_bytes(native))
        review_rel = f"{source_dir}/independent-intended-use.json"
        review = {
            "asset_id": asset_id, "asset_sha256": runtime_sha,
            "decision": "PASS", "scope": validator.REVIEW_SCOPE, "reviewer_independent": True,
            "coverage": {"actual_level": True, "closed": True, "four_key_states": True, "released": True, "front_and_back": True},
        }
        review_sha = write(self.root / review_rel, json_bytes(review))
        return {
            "id": asset_id, "dimensions": size,
            "runtime": {"path": runtime_path, "uri": runtime_uri, "sha256": runtime_sha, "bytes": len(runtime)},
            "importer_policy": {"importer": "scene", "resource_type": "PackedScene", "embedded_image_handling": 3},
            "source_blend": {"path": source_rel, "sha256": source_sha},
            "recipe": {"path": recipe_rel, "sha256": recipe_sha},
            "uv_registration": {"path": uv_rel, "sha256": uv_sha},
            "used_raw_inputs": raw_inputs,
            "source_proof": {"path": proof_rel, "sha256": proof_sha},
            "native_qualification": {"path": native_rel, "sha256": native_sha},
            "independent_intended_use": {"path": review_rel, "sha256": review_sha},
        }

    def _ledger(self) -> dict:
        return {"schema": validator.SCHEMA, "schema_version": validator.VERSION,
                "kind": "eight-authored-threshold-assets", "assets": self.entries}

    def _save_ledger(self):
        write(self.root / self.ledger_path, json_bytes(self._ledger()))

    def _refresh_runtime(self, index: int, data: bytes):
        entry = self.entries[index]
        write(self.root / entry["runtime"]["path"], data)
        entry["runtime"]["sha256"] = digest(data)
        entry["runtime"]["bytes"] = len(data)
        self._save_ledger()

    def _refresh_receipt(self, index: int, filename: str, field: str, value):
        entry = self.entries[index]
        path = self.root / entry[field]["path"]
        record = json.loads(path.read_text())
        record[filename] = value
        data = json_bytes(record)
        new_digest = write(path, data)
        entry[field]["sha256"] = new_digest
        self._save_ledger()

    def test_complete_eight_asset_contract_structural_pass(self):
        result = validator.validate_ledger(self.root, self.ledger_path)
        self.assertEqual(result["status"], "STRUCTURAL_EIGHT_THRESHOLD_LEDGER_VALID")
        self.assertEqual(result["assets"], 8)
        self.assertTrue(result["complete_registry"])

    def test_partial_is_explicit_test_only_and_not_release_valid(self):
        self.entries = self.entries[:1]
        self._save_ledger()
        with self.assertRaises(validator.ContractError):
            validator.validate_ledger(self.root, self.ledger_path)
        result = validator.validate_ledger(self.root, self.ledger_path, allow_partial=True)
        self.assertEqual(result["status"], "INCOMPLETE_CANDIDATE_NOT_RELEASE_VALID")
        self.assertFalse(result["complete_registry"])

    def test_seven_is_not_accepted_by_default(self):
        self.entries = self.entries[:7]
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "exact complete"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_duplicate_and_unknown_ids_rejected(self):
        self.entries[-1]["id"] = self.entries[0]["id"]
        self._save_ledger()
        with self.assertRaises(validator.ContractError):
            validator.validate_ledger(self.root, self.ledger_path)
        self.entries[-1]["id"] = "unregistered_gate"
        self._save_ledger()
        with self.assertRaises(validator.ContractError):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_data_dimensions_are_authoritative(self):
        data = self.root / "game/data/01_intake.json"
        document = json.loads(data.read_text())
        document["doors"][0]["size"][0] = 8.3
        write(data, json_bytes(document))
        with self.assertRaisesRegex(validator.ContractError, "GateArt width or authored door dimensions"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_bad_runtime_hash_and_bad_container_rejected(self):
        entry = self.entries[0]
        runtime_path = self.root / entry["runtime"]["path"]
        original = runtime_path.read_bytes()
        runtime_path.write_bytes(b"not a glb")
        entry["runtime"]["sha256"] = digest(b"not a glb")
        entry["runtime"]["bytes"] = len(b"not a glb")
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "not a GLB"):
            validator.validate_ledger(self.root, self.ledger_path)
        runtime_path.write_bytes(original)

    def test_bad_sha_is_rejected_before_container_validation(self):
        self.entries[0]["runtime"]["sha256"] = "0" * 64
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "SHA-256 mismatch"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_unmarked_blender_source_is_rejected(self):
        entry = self.entries[0]
        path = self.root / entry["source_blend"]["path"]
        digest_value = write(path, b"not a Blender or Zstandard container")
        entry["source_blend"]["sha256"] = digest_value
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "Blender or Zstandard"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_wrong_import_policy_is_rejected(self):
        self.entries[0]["importer_policy"]["embedded_image_handling"] = 2
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "embedded image handling 3"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_external_glb_image_rejected(self):
        entry = self.entries[0]
        scene = ASSETS[0][1]
        images = [(scene + "_membrane", PNG), (scene + "_hardware", PNG)]
        malformed = make_glb(entry["id"], images, external_image=True)
        self._refresh_runtime(0, malformed)
        with self.assertRaisesRegex(validator.ContractError, "embedded by bufferView"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_native_receipt_must_bind_exact_source_and_glb(self):
        entry = self.entries[0]
        path = self.root / entry["native_qualification"]["path"]
        receipt = json.loads(path.read_text())
        receipt["runtime_sha256"] = "0" * 64
        data = json_bytes(receipt)
        entry["native_qualification"]["sha256"] = write(path, data)
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "native run receipt binding"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_independent_pass_must_bind_exact_scoped_artifact(self):
        entry = self.entries[0]
        path = self.root / entry["independent_intended_use"]["path"]
        review = json.loads(path.read_text())
        review["asset_sha256"] = "f" * 64
        entry["independent_intended_use"]["sha256"] = write(path, json_bytes(review))
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "not bound to exact runtime"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_absolute_traversal_and_symlink_paths_rejected(self):
        entry = self.entries[0]
        entry["source_blend"]["path"] = "/private/source.blend"
        self._save_ledger()
        with self.assertRaises(validator.ContractError):
            validator.validate_ledger(self.root, self.ledger_path)
        entry["source_blend"]["path"] = "source/art/living-thresholds-v3/intake/../../elsewhere.blend"
        self._save_ledger()
        with self.assertRaises(validator.ContractError):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_symlink_source_path_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            outside_file = Path(outside) / "external.blend"
            outside_file.write_bytes(b"BLENDER-external")
            entry = self.entries[0]
            link = self.root / "source/art/living-thresholds-v3/intake/raw/outside.blend"
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(outside_file)
            entry["source_blend"] = {"path": "source/art/living-thresholds-v3/intake/raw/outside.blend", "sha256": digest(outside_file.read_bytes())}
            self._save_ledger()
            with self.assertRaisesRegex(validator.ContractError, "symlink"):
                validator.validate_ledger(self.root, self.ledger_path)

    def test_duplicate_raw_input_reference_rejected(self):
        entry = self.entries[0]
        entry["used_raw_inputs"].append(dict(entry["used_raw_inputs"][0]))
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "duplicate raw input"):
            validator.validate_ledger(self.root, self.ledger_path)

    def test_source_file_cannot_be_owned_by_two_gate_entries(self):
        self.entries[1]["source_blend"] = dict(self.entries[0]["source_blend"])
        self._save_ledger()
        with self.assertRaisesRegex(validator.ContractError, "duplicate file ownership"):
            validator.validate_ledger(self.root, self.ledger_path)



class MainSelftestCompatibilityTests(unittest.TestCase):
    """Exact historical/current Main pair, tiny synthetic native receipts only."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.compat_rel = "source/art/living-thresholds-v3/compatibility/main-worker-selftest-compatibility-v1.json"
        repository = Path(__file__).resolve().parents[1]
        self.descriptor = json.loads((repository / self.compat_rel).read_text())
        original_rel = self.descriptor["historical_source"]["path"]
        write(self.root / original_rel, (repository / original_rel).read_bytes())
        # This unit fixture exercises the retained two-site selftest bridge,
        # not the separately qualified v0.094 source generation.
        historical_main = (repository / "source/art/consumer-qualification-v0094/provenance/main-before-v0094.gd").read_bytes()
        assert digest(historical_main) == validator.SELFTEST_MAIN_SHA
        write(self.root / validator.MAIN_SOURCE, historical_main)
        for path in validator.NATIVE_CODE_SOURCES:
            if path != validator.MAIN_SOURCE:
                write(self.root / path, ("independent fixture " + path).encode())
        self.receipt = {
            "schema": "null-choir.threshold-native-qualification", "asset_id": "containment_gate",
            "runtime_sha256": "a"*64, "source_blend_sha256": "b"*64, "source_proof_sha256": "c"*64,
            "exit_code": 0, "strict": True, "diagnostics": [], "engine_version": "test",
            "run_id": "historical-fixture", "claim_scope": "normal-import-and-runtime-consumer",
            "code_source_hashes": {path: digest((self.root/path).read_bytes()) for path in validator.NATIVE_CODE_SOURCES},
        }
        self.receipt["code_source_hashes"][validator.MAIN_SOURCE] = validator.HISTORICAL_MAIN_SHA
        self.native_rel = "source/art/living-thresholds-v3/intake/native-qualification.json"
        self.entry = {"native_qualification": {"path": self.native_rel, "sha256": write(self.root/self.native_rel,json_bytes(self.receipt))}}
    def tearDown(self):
        self.temp.cleanup()
    def compatibility(self):
        ref = {"path": self.compat_rel, "sha256": write(self.root/self.compat_rel,json_bytes(self.descriptor))}
        return validator._main_selftest_compatibility(self.root, ref, set())
    def native(self, compatibility=None):
        return validator._native_receipt(self.root,self.entry,asset_id="containment_gate",
            source_dir="source/art/living-thresholds-v3/intake",runtime_sha="a"*64,
            source_sha="b"*64,source_proof_sha="c"*64,owned=set(),main_compatibility=compatibility)
    def test_exact_pair_reconstructs_and_reuses_historical_receipt_without_rewrite(self):
        before=(self.root/self.native_rel).read_bytes()
        compatibility=self.compatibility()
        self.native(compatibility)
        self.assertEqual((self.root/self.native_rel).read_bytes(),before)
        self.assertEqual(compatibility["scope"],"historical-gate-evidence-reuse-only-not-current-native-qualification")
    def test_old_strict_path_unchanged_and_missing_bridge_fails_new_Main(self):
        self.assertIsNone(validator._main_selftest_compatibility(self.root,None,set()))
        with self.assertRaisesRegex(validator.ContractError,"stale at game/scripts/main.gd"):
            self.native()
        old=(self.root/self.descriptor["historical_source"]["path"]).read_bytes()
        write(self.root/validator.MAIN_SOURCE,old)
        self.native()
    def test_wrong_old_or_current_hash_rejected(self):
        for key in ["historical_source","current_source"]:
            old=self.descriptor[key]["sha256"]
            self.descriptor[key]["sha256"]="0"*64
            with self.subTest(key=key),self.assertRaises(validator.ContractError):
                self.compatibility()
            self.descriptor[key]["sha256"]=old
    def test_foreign_source_path_and_arbitrary_replacement_rejected(self):
        self.descriptor["current_source"]["path"]="game/scripts/level.gd"
        with self.assertRaises(validator.ContractError):
            self.compatibility()
        self.descriptor["current_source"]["path"]=validator.MAIN_SOURCE
        self.descriptor["replacements"][0]["function"]="unlock_door"
        with self.assertRaises(validator.ContractError):
            self.compatibility()
    def test_unrelated_Main_runtime_change_and_changed_snapshot_rejected(self):
        write(self.root/validator.MAIN_SOURCE,(self.root/validator.MAIN_SOURCE).read_bytes()+b"\\n# unrelated runtime edit\\n")
        with self.assertRaises(validator.ContractError):
            self.compatibility()
        historical=self.root/self.descriptor["historical_source"]["path"]
        write(historical,historical.read_bytes()+b"\\n# changed original\\n")
        with self.assertRaises(validator.ContractError):
            self.compatibility()
    def test_all_other_five_code_source_pins_remain_strict(self):
        compatibility=self.compatibility()
        for path in validator.NATIVE_CODE_SOURCES:
            if path == validator.MAIN_SOURCE:
                continue
            original=(self.root/path).read_bytes()
            write(self.root/path,original+b" changed")
            with self.subTest(path=path),self.assertRaisesRegex(validator.ContractError,"stale at "+path):
                self.native(compatibility)
            write(self.root/path,original)
    def test_malformed_descriptor_or_false_native_scope_rejected(self):
        self.descriptor["fresh_native_qualification"]=True
        with self.assertRaises(validator.ContractError):
            self.compatibility()
        self.descriptor["fresh_native_qualification"]=False
        self.descriptor["replacements"].pop()
        with self.assertRaises(validator.ContractError):
            self.compatibility()

if __name__ == "__main__":
    unittest.main()
