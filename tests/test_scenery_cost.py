"""Synthetic, stdlib-only census contracts; safe to import."""
from contextlib import redirect_stdout, redirect_stderr
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import struct
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

from tools import scenery_cost as cost


def geometry():
    return {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": 42}],
        "bufferViews": [{"buffer": 0, "byteLength": 36},
                        {"buffer": 0, "byteOffset": 36, "byteLength": 6}],
        "accessors": [{"bufferView": 0, "componentType": 5126,
                       "type": "VEC3", "count": 3},
                      {"bufferView": 1, "componentType": 5123,
                       "type": "SCALAR", "count": 3}],
        "materials": [{}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0},
                                    "indices": 1, "material": 0}]}],
        "nodes": [{"mesh": 0}, {"mesh": 0}],
        "scenes": [{"nodes": [0, 1]}], "scene": 0,
    }


def glb_bytes(g=None, raw=None, bin_bytes=44):
    raw = json.dumps(geometry() if g is None else g).encode() if raw is None else raw
    raw += b" " * (-len(raw) % 4)
    return (struct.pack("<4sII", b"glTF", 2, 28 + len(raw) + bin_bytes)
            + struct.pack("<I4s", len(raw), b"JSON") + raw
            + struct.pack("<I4s", bin_bytes, b"BIN\0") + bytes(bin_bytes))


def map_data():
    return {"id": "intake", "rects": [[0, 0, 0, 0]],
            "heroes": [{"id": "landmark"}],
            "scenery": [{"art": "landmark"}, {"art": "landmark"}],
            "lights": [{"fixture_yaw": 0}, {}],
            "pickups": [{"id": "pickup"}], "interactions": [{"id": "interaction"}],
            "loops": [{"hero": "not_a_placement"}], "ceilings": []}


def run_main(argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = cost.main(argv)
    return code, json.loads(out.getvalue()), out.getvalue(), err.getvalue()


class MetadataOnly(io.BytesIO):
    def __init__(self, data):
        super().__init__(data)
        self.limit = 28 + struct.unpack_from("<I", data, 12)[0]
        self.requests = []

    def read(self, size=-1):
        if size < 0 or self.tell() + size > self.limit:
            raise AssertionError("BIN payload read attempted")
        self.requests.append(size)
        return super().read(size)


class CensusTests(unittest.TestCase):
    def test_duplicate_nodes_keep_shared_accessors_stored_once(self):
        report = cost.analyze_glb(geometry(), 44)
        self.assertEqual(report["stored"]["mesh_definitions"], 1)
        self.assertEqual(report["stored"]["position_accessor_elements"], 3)
        self.assertEqual(report["stored"]["index_accessor_elements"], 3)
        self.assertEqual(report["scene"]["mesh_node_references"], 2)
        self.assertEqual(report["scene"]["primitive_references"], 2)
        self.assertEqual(report["scene"]["used_materials"], 1)
        self.assertEqual(report["scene"]["position_element_references"], 6)
        self.assertEqual(report["scene"]["index_element_references"], 6)
        self.assertEqual(report["scene"]["triangle_slots"], 2)

    def test_parent_multiple_primitives_shared_material_and_unused_mesh(self):
        g = geometry()
        g["meshes"][0]["primitives"] *= 2
        g["meshes"].append(copy.deepcopy(g["meshes"][0]))
        g["nodes"].append({"children": [0, 1]})
        g["scenes"][0]["nodes"] = [2]
        report = cost.analyze_glb(g, 44)
        self.assertEqual(report["stored"]["mesh_definitions"], 2)
        self.assertEqual(report["stored"]["primitive_definitions"], 4)
        self.assertEqual(report["stored"]["position_accessor_elements"], 3)
        self.assertEqual(report["stored"]["index_accessor_elements"], 3)
        self.assertEqual(report["scene"]["reachable_nodes"], 3)
        self.assertEqual(report["scene"]["primitive_references"], 4)
        self.assertEqual(report["scene"]["triangle_slots"], 4)
        self.assertEqual(report["scene"]["used_materials"], 1)

    def test_union_boundaries_and_count_fields(self):
        data = map_data()
        data["rects"] = [[-1, 0, 0, 0], [0, 0, 1, 0], [-1, 0, 0, 0]]
        data["ceilings"] = [{"rect": [-1, 0, -1, 0], "height": 12}]
        report = cost.placements(data)
        self.assertEqual((report["tile_count"], report["boundary_edges"]), (3, 8))
        self.assertEqual(report["assets"]["ribbed_wall"]["boundary_kit"], 8)
        self.assertEqual(report["assets"]["conduit"]["boundary_kit"], 8)
        self.assertEqual(report["assets"]["landmark"]["hero"], 1)
        self.assertEqual(report["assets"]["landmark"]["scenery"], 2)
        self.assertEqual(report["assets"]["containment_capsule"]["fresh_marker"], 2)
        self.assertEqual(report["assets"]["lumen_sconce"]["light_fixture"], 1)
        self.assertNotIn("not_a_placement", report["assets"])
        data["scenery"][0]["tradition_aesthetic"] = "Christian"
        self.assertEqual(cost.placements(data), report)

    def test_intake_retained_rectangle_regression(self):
        data = map_data()
        data["rects"] = [[11,26,17,30], [11,20,17,25], [5,23,11,24], [5,19,6,23],
                         [2,12,9,18], [5,7,6,12], [4,7,12,9], [13,7,14,10], [11,10,17,19],
                         [17,22,23,23], [22,18,23,23], [20,11,26,18], [23,9,24,11],
                         [17,7,24,9], [13,5,14,9], [10,0,18,4], [1,15,2,16]]
        report = cost.placements(data)
        self.assertEqual((report["tile_count"], report["boundary_edges"]), (411, 214))

    def test_map_bounds_before_expansion_and_missing_arrays(self):
        cases = ([[0,0,1000000,1000000]], [[0,0,63,63]] * 17,
                 [[0,0,63,63], [64,0,64,0]], [[1,0,0,0]], [[True,0,0,0]])
        for rects in cases:
            with self.subTest(rects=rects[:2]), self.assertRaises(cost.CensusError):
                data = map_data()
                data["rects"] = rects
                cost.placements(data)
        for key in ("rects", "heroes", "scenery", "lights", "pickups", "interactions"):
            data = map_data()
            del data[key]
            with self.subTest(missing=key), self.assertRaises(cost.CensusError):
                cost.placements(data)

    def test_bad_graphs_even_when_unreachable(self):
        cases = [([{ "mesh": 0}], [0,0]),
                 ([{"children": [1]}, {"children": [0]}], []),
                 ([{"children": [2]}, {"children": [2]}, {"mesh": 0}], [0,1]),
                 ([{"children": [1,1]}, {"mesh": 0}], [0]),
                 ([{"children": [1]}, {"mesh": 0}], [0,1])]
        for nodes, roots in cases:
            with self.subTest(nodes=nodes), self.assertRaises(cost.CensusError):
                g = geometry()
                g["nodes"], g["scenes"][0]["nodes"] = nodes, roots
                cost.analyze_glb(g, 44)

    def test_every_reference_rejects_bad_json_indices(self):
        for bad in (-1, True, False, 1.0, "0", None, 99, []):
            mutations = [lambda g: g["nodes"][0].update(mesh=bad),
                         lambda g: g["scenes"][0].update(nodes=[bad]),
                         lambda g: g["nodes"][0].update(children=[bad]),
                         lambda g: g["meshes"][0]["primitives"][0].update(indices=bad),
                         lambda g: g["meshes"][0]["primitives"][0].update(material=bad),
                         lambda g: g["meshes"][0]["primitives"][0]["attributes"].update(POSITION=bad),
                         lambda g: g["accessors"][0].update(bufferView=bad)]
            for number, mutate in enumerate(mutations):
                with self.subTest(bad=bad, reference=number), self.assertRaises(cost.CensusError):
                    g = geometry()
                    mutate(g)
                    cost.analyze_glb(g, 44)

    def test_unsupported_features_and_modes(self):
        mutations = [lambda g: g.update(animations=[]), lambda g: g.update(skins=[]),
                     lambda g: g.update(extensionsUsed=["EXT_mesh_gpu_instancing"]),
                     lambda g: g["nodes"][0].update(extensions={"EXT_mesh_gpu_instancing": {}}),
                     lambda g: g["accessors"][0].update(sparse={}),
                     lambda g: g["meshes"][0]["primitives"][0].update(targets=[]),
                     lambda g: g["meshes"][0].update(weights=[]),
                     lambda g: g["nodes"][0].update(skin=0),
                     lambda g: g["buffers"][0].update(uri="outside.bin"),
                     lambda g: g.update(images=[{"uri": "outside.png"}]),
                     lambda g: g["meshes"][0]["primitives"][0].pop("indices"),
                     lambda g: g["accessors"][1].update(count=2),
                     lambda g: g.update(scene=True), lambda g: g.update(scene=1),
                     lambda g: g["scenes"].append({"nodes": []}),
                     lambda g: g.update(nodes=[{}] * 257)]
        for mode in (0, 1, 3, 5, 6, True):
            mutations.append(lambda g, mode=mode: g["meshes"][0]["primitives"][0].update(mode=mode))
        for number, mutate in enumerate(mutations):
            with self.subTest(case=number), self.assertRaises(cost.CensusError):
                g = geometry()
                mutate(g)
                cost.analyze_glb(g, 44)

    def test_emissive_extension_and_optional_images(self):
        g = geometry()
        g["extensionsUsed"] = [cost.ALLOWED_EXTENSION]
        g["materials"][0]["extensions"] = {cost.ALLOWED_EXTENSION: {"emissiveStrength": 2}}
        self.assertEqual(cost.analyze_glb(g, 44)["encoded_image_view_bytes"], 0)
        g["images"] = [{"bufferView": 0, "mimeType": "image/png"}] * 2
        self.assertEqual(cost.analyze_glb(g, 44)["encoded_image_view_bytes"], 36)

    def test_accessor_view_spans_and_interleaving(self):
        g = geometry()
        g["buffers"][0]["byteLength"] = 54
        g["bufferViews"][0].update(byteLength=48, byteStride=16)
        g["bufferViews"][1]["byteOffset"] = 48
        self.assertEqual(cost.analyze_glb(g, 56)["stored"]["position_accessor_elements"], 3)
        mutations = [lambda g: g["bufferViews"][0].update(byteLength=43),
                     lambda g: g["accessors"][0].update(byteOffset=8),
                     lambda g: g["bufferViews"][0].update(byteOffset=20),
                     lambda g: g["bufferViews"][0].update(byteStride=8),
                     lambda g: g["bufferViews"][0].update(buffer=True)]
        for number, mutate in enumerate(mutations):
            with self.subTest(case=number), self.assertRaises(cost.CensusError):
                bad = copy.deepcopy(g)
                mutate(bad)
                cost.analyze_glb(bad, 56)

    def test_cancelling_offsets_do_not_hide_accessor_misalignment(self):
        for accessor in (0, 1):
            g = geometry()
            if accessor == 0:
                g["buffers"][0]["byteLength"] = 46
                g["bufferViews"][0].update(byteOffset=1, byteLength=39)
                g["bufferViews"][1]["byteOffset"] = 40
                g["accessors"][0]["byteOffset"] = 3
                bin_bytes = 48
            else:
                g["buffers"][0]["byteLength"] = 44
                g["bufferViews"][1].update(byteOffset=35, byteLength=9)
                g["accessors"][1]["byteOffset"] = 3
                bin_bytes = 44
            with self.subTest(accessor=accessor), self.assertRaises(cost.CensusError):
                cost.analyze_glb(g, bin_bytes)

    def test_header_reader_never_requests_payload_and_hash_is_metadata_only(self):
        data = glb_bytes()
        stream = MetadataOnly(data)
        report = cost.read_glb(stream, len(data))
        n = struct.unpack_from("<I", data, 12)[0]
        self.assertEqual(stream.requests, [12, 8, n, 8])
        self.assertEqual(stream.tell(), 28 + n)
        self.assertEqual(report["metadata_sha256"], hashlib.sha256(data[:28+n]).hexdigest())
        self.assertFalse(report["full_binary_verified"])
        changed = data[:-44] + b"x" * 44
        self.assertEqual(cost.read_glb(MetadataOnly(changed), len(changed))["metadata_sha256"],
                         report["metadata_sha256"])
        self.assertNotEqual(hashlib.sha256(data).hexdigest(), report["metadata_sha256"])

    def test_corrupt_chunks_caps_duplicate_keys_nonfinite_and_deep_json(self):
        good = glb_bytes()
        cases = [(good[:10], len(good)), (good[:25], len(good)),
                 (b"BAD!" + good[4:], len(good)), (good, len(good)+4),
                 (good + b"xxxx", len(good)+4),
                 (glb_bytes(raw=b'{"asset": {}, "asset": {}}'), None),
                 (glb_bytes(raw=b'{"x": NaN}'), None),
                 (glb_bytes(raw=b'{"x": 1e9999}'), None),
                 (glb_bytes(raw=b'{"x":' + b'['*1100 + b'0' + b']'*1100 + b'}'), None),
                 (glb_bytes(raw=b'{"x":' + b'9'*5000 + b'}'), None)]
        for number, (data, size) in enumerate(cases):
            with self.subTest(case=number), self.assertRaises(cost.CensusError):
                cost.read_glb(io.BytesIO(data), len(data) if size is None else size)
        for size in (cost.MAX_JSON + 4, 3):
            header = struct.pack("<4sIII4s", b"glTF", 2, 28+size+44, size, b"JSON")
            stream = io.BytesIO(header)
            with self.assertRaises(cost.CensusError):
                cost.read_glb(stream, 28+size+44)
            self.assertEqual(stream.tell(), 20)
        with self.assertRaises(cost.CensusError):
            cost.read_glb(io.BytesIO(), cost.MAX_GLB + 1)

    def test_source_pins_are_the_accepted_compatibility_contract(self):
        actual = Path(__file__).absolute().parents[1] / "game/scripts/level.gd"
        self.assertEqual(hashlib.sha256(actual.read_bytes()).hexdigest(),
                         cost.SOURCE_PINS["game/scripts/level.gd"])
        self.assertEqual(cost.SOURCE_PINS, {
            "game/scripts/level.gd": "fbeb3f64a587a999dd46b81d2b5b73cf8d477f82af500502810d97ca0d64dc35",
            "game/scripts/level_data.gd": "402f065c8b284b06b947aa4bedf1940e6f314538c3aa69f9fe4bfd2c08019758"})


class ProjectTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix=".scenery-test-", dir=Path(__file__).absolute().parents[1])
        self.addCleanup(temp.cleanup)
        self.parent = Path(temp.name)
        self.root = self.parent / "project"
        self.root.mkdir()
        pins = {}
        for path in cost.SOURCE_PINS:
            raw = ("synthetic placement source: " + path).encode()
            self.write(path, raw)
            pins[path] = hashlib.sha256(raw).hexdigest()
        patcher = mock.patch.dict(cost.SOURCE_PINS, pins, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.manifest = {"schema_version": 1, "assets": []}
        self.data = glb_bytes()
        for asset in ("landmark", "ribbed_wall", "conduit", "lumen_sconce", "containment_capsule"):
            path = "game/assets/art/world/" + asset + ".glb"
            self.write(path, self.data)
            self.manifest["assets"].append({"id": asset, "triangles": 2, "runtime_mesh_nodes": 1,
                                           "material_count": 1,
                                           "outputs": [{"path": path, "bytes": len(self.data),
                                                        "sha256": "0" * 64}]})
        self.save_manifest()
        for name in cost.MAPS:
            data = map_data()
            data["id"] = name.split("_", 1)[1]
            self.write("game/data/" + name + ".json", json.dumps(data).encode())

    def write(self, path, raw):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)

    def save_manifest(self):
        self.write("source/art/manifest.json", json.dumps(self.manifest).encode())

    def assert_error(self):
        code, report, _, stderr = run_main(["--project-root", str(self.root)])
        self.assertEqual(code, 2)
        self.assertEqual(report["status"], "error")
        self.assertNotIn("levels", report)
        self.assertNotIn("assets", report)
        self.assertEqual(stderr, "")
        return report

    def test_cli_deterministic_all_eight_unique_storage_and_expansion(self):
        first = run_main(["--project-root", str(self.root)])
        second = run_main(["--project-root", str(self.root)])
        self.assertEqual(first, second)
        code, report, _, stderr = first
        self.assertEqual((code, stderr, report["status"]), (0, "", "complete"))
        self.assertEqual(len(report["levels"]), 8)
        self.assertEqual(len(report["assets"]), 5)
        self.assertEqual(len(report["source_evidence"]), 11)
        self.assertFalse(report["runtime_measured"])
        for level in report["levels"]:
            self.assertEqual(level["totals"]["placements"], 14)
            self.assertEqual(level["totals"]["unique_file_bytes"], 5 * len(self.data))
            self.assertEqual(level["totals"]["expanded_scene"]["triangle_slots"], 28)
            self.assertEqual(level["assets"]["landmark"]["placements"], 3)

    def test_cli_reader_is_unbuffered_and_bin_prohibition_covers_real_file_path(self):
        original = cost.os.fdopen
        calls = []
        limit = len(self.data) - 44
        class Guard:
            def __init__(self, stream, glb):
                self.stream, self.glb = stream, glb
            def __enter__(self):
                return self
            def __exit__(self, *args):
                return self.stream.__exit__(*args)
            def tell(self):
                return self.stream.tell()
            def read(self, size):
                if self.glb:
                    self_position = self.stream.tell()
                    if size < 0 or self_position + size > limit:
                        raise AssertionError("CLI attempted BIN read")
                    calls.append((self_position, size))
                return self.stream.read(size)
        def guarded(fd, mode, buffering):
            self.assertEqual(buffering, 0)
            stream = original(fd, mode, buffering=buffering)
            self.assertIsInstance(stream, io.FileIO)
            return Guard(stream, os.fstat(fd).st_size == len(self.data))
        with mock.patch.object(cost.os, "fdopen", side_effect=guarded):
            code, _, _, _ = run_main(["--project-root", str(self.root)])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 5 * 4)
        self.assertTrue(all(start + size <= limit for start, size in calls))

    def test_cli_usage_and_root_canonicality_before_touch(self):
        for argv in ([], ["--project-root"], ["--help"], ["--other", str(self.root)]):
            with self.subTest(argv=argv), mock.patch.object(cost.os, "open") as opened:
                self.assertEqual(run_main(argv)[0], 2)
                opened.assert_not_called()
        for path in ("relative", str(self.root) + "/../project", str(self.root) + "/.",
                     str(self.root) + "//x", str(self.root) + "\\x"):
            with self.subTest(path=path), mock.patch.object(cost.os, "open") as opened:
                self.assertEqual(run_main(["--project-root", path])[0], 2)
                opened.assert_not_called()

    def test_source_pin_drift(self):
        self.write("game/scripts/level.gd", b"changed semantics")
        self.assertIn("pin drift", self.assert_error()["error"])

    def test_numeric_parity_and_duplicate_manifest_ownership(self):
        baseline = copy.deepcopy(self.manifest)
        for field in ("triangles", "runtime_mesh_nodes", "material_count", "bytes"):
            for value in (True, 99):
                self.manifest = copy.deepcopy(baseline)
                entry = self.manifest["assets"][0]
                (entry["outputs"][0] if field == "bytes" else entry)[field] = value
                self.save_manifest()
                with self.subTest(field=field, value=value):
                    self.assert_error()
        for duplicate in ("id", "path"):
            self.manifest = copy.deepcopy(baseline)
            if duplicate == "id":
                self.manifest["assets"].append(copy.deepcopy(self.manifest["assets"][0]))
            else:
                self.manifest["assets"][1]["outputs"][0]["path"] = self.manifest["assets"][0]["outputs"][0]["path"]
            self.save_manifest()
            with self.subTest(duplicate=duplicate):
                self.assert_error()

    def test_deceptive_output_and_asset_paths(self):
        baseline = copy.deepcopy(self.manifest)
        for path in ("/outside.glb", "../outside.glb", "game/assets/art/../outside.glb",
                     "game/assets/art//world/landmark.glb", "game/assets/art/world/other.glb"):
            self.manifest = copy.deepcopy(baseline)
            self.manifest["assets"][0]["outputs"][0]["path"] = path
            self.save_manifest()
            with self.subTest(path=path):
                self.assert_error()
        self.manifest = copy.deepcopy(baseline)
        self.manifest["assets"][0]["id"] = "../outside"
        self.save_manifest()
        self.assert_error()

    def test_missing_unsupported_and_duplicate_json_have_no_partial_success(self):
        target = self.root / "game/assets/art/world/landmark.glb"
        target.unlink()
        self.assert_error()
        bad = geometry()
        bad["extensionsUsed"] = ["KHR_draco_mesh_compression"]
        target.write_bytes(glb_bytes(bad))
        self.assert_error()
        self.write("source/art/manifest.json", b'{"schema_version":1,"schema_version":1}')
        self.assertIn("duplicate JSON key", self.assert_error()["error"])

    def test_symlink_leaf_and_intermediate_and_root(self):
        target = self.root / "game/assets/art/world/landmark.glb"
        other = target.with_name("alias.glb")
        target.rename(other)
        target.symlink_to(other)
        self.assert_error()
        target.unlink()
        other.rename(target)
        world = target.parent
        world.rename(world.with_name("real_world"))
        world.symlink_to(world.with_name("real_world"), target_is_directory=True)
        self.assert_error()
        alias = self.parent / "root_alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.assertEqual(run_main(["--project-root", str(alias)])[0], 2)

    def test_nonregular_and_hardlink_alias(self):
        target = self.root / "game/assets/art/world/landmark.glb"
        target.unlink()
        os.mkfifo(target)
        self.assert_error()
        target.unlink()
        target.write_bytes(self.data)
        os.link(target, target.with_name("hardlink.glb"))
        self.assert_error()

    def test_dataless_flags_reject_without_opening_payload(self):
        with self.assertRaises(cost.CensusError):
            cost.resident(SimpleNamespace(st_flags=getattr(stat, "SF_DATALESS", 0x40000000)))
        original = cost.resident
        ino = (self.root / "game/assets/art/world/landmark.glb").stat().st_ino
        def dataless(info):
            if info.st_ino == ino:
                original(SimpleNamespace(st_flags=getattr(stat, "SF_DATALESS", 0x40000000)))
            original(info)
        with mock.patch.object(cost, "resident", side_effect=dataless):
            self.assertIn("hydration forbidden", self.assert_error()["error"])

    def test_mutation_during_glb_read(self):
        original = cost.read_glb
        def mutate(stream, size):
            report = original(stream, size)
            target = self.root / "game/assets/art/world/conduit.glb"
            with target.open("ab") as output:
                output.write(b"x")
            return report
        with mock.patch.object(cost, "read_glb", side_effect=mutate):
            self.assertIn("changed during read", self.assert_error()["error"])

    def test_source_change_after_initial_pin_is_rejected_at_final_evidence_check(self):
        original = cost.read_glb
        def mutate(stream, size):
            report = original(stream, size)
            self.write("game/scripts/level.gd", b"late source change")
            return report
        with mock.patch.object(cost, "read_glb", side_effect=mutate):
            self.assertIn("changed after read", self.assert_error()["error"])

    def test_root_replacement_is_rejected_even_with_held_directory_fd(self):
        original = cost.read_glb
        changed = False
        def replace(stream, size):
            nonlocal changed
            report = original(stream, size)
            if not changed:
                changed = True
                self.root.rename(self.parent / "moved_project")
                self.root.mkdir()
            return report
        with mock.patch.object(cost, "read_glb", side_effect=replace):
            self.assertIn("directory path replaced", self.assert_error()["error"])

    def test_caps_source_manifest_map_and_referenced_exports(self):
        for constant in ("MAX_SOURCE", "MAX_MANIFEST", "MAX_MAP"):
            with self.subTest(cap=constant), mock.patch.object(cost, constant, 1):
                self.assert_error()
        with mock.patch.object(cost, "MAX_EXPORTS", 4):
            self.assert_error()


if __name__ == "__main__":
    unittest.main()
