"""Actual healing-source/recipe contracts, not Godot/native/visual acceptance.

Uses retained eight editable glTF/bin/GLB assets and the runtime counterparts.
Mutations stay in memory or an automatically removed temporary directory.
"""
from pathlib import Path
import copy
import importlib.util
import io
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "source/art/healing_machinery/runtime_contract"
spec = importlib.util.spec_from_file_location("healing_registry_recipe", CONTRACT / "build_registry.py")
recipe = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(CONTRACT))
try:
    spec.loader.exec_module(recipe)
    from render_contract import render_hash, quant, normal_codes, normal_decode
finally:
    sys.path.pop(0)


def function_body(source, name):
    begin = source.index("func " + name + "(")
    match = re.search(r"\n(?:static )?func |\nclass ", source[begin + 1:])
    return source[begin:begin + 1 + match.start()] if match else source[begin:]


def glb_parts(data):
    magic, version, length = struct.unpack_from("<III", data)
    if (magic, version, length) != (0x46546C67, 2, len(data)):
        raise ValueError("Invalid GLB header")
    size, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise ValueError("Missing GLB JSON")
    document = json.loads(data[20:20 + size])
    binary_size, binary_kind = struct.unpack_from("<II", data, 20 + size)
    if binary_kind != 0x004E4942:
        raise ValueError("Missing GLB binary")
    return document, data[28 + size:28 + size + binary_size]


class HealingMachinerySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = ROOT / "source/art/healing_machinery"
        cls.runtime = ROOT / "game/assets/art/healing_machinery"
        cls.registry_bytes = (ROOT / "game/data/healing_machinery_registry.json").read_bytes()
        cls.registry = json.loads(cls.registry_bytes)
        cls.scenes = {}
        for path in sorted((cls.source / "models").glob("*.gltf")):
            cls.scenes[path.stem] = recipe.source_scene(path)
        cls.helper = (ROOT / "game/scripts/healing_machinery.gd").read_text()

    def attributes(self, family, name="DialFace"):
        document, buffer = self.scenes[family]
        node = next(n for n in document["nodes"] if n["name"] == name)
        primitive = document["meshes"][node["mesh"]]["primitives"][0]
        read = lambda key: recipe.read_accessor(document, buffer, primitive["attributes"][key])
        return (read("POSITION"), read("NORMAL"), read("TEXCOORD_0"), read("COLOR_0"),
                recipe.read_accessor(document, buffer, primitive["indices"]))

    def test_portable_recipe_reproduces_exact_runtime_bytes_and_helper_pin(self):
        self.assertEqual(recipe.registry_bytes(ROOT), self.registry_bytes)
        self.assertEqual(recipe.HISTORICAL_KIT_MANIFEST_SHA256,
                         self.registry["kitManifestSHA256"])
        helper_sha = re.search(r'const REGISTRY_SHA = "([a-f0-9]{64})"', self.helper)[1]
        self.assertEqual(recipe.sha256(self.registry_bytes), helper_sha)

    def test_actual_eight_glb_gltf_binary_and_runtime_identities(self):
        self.assertEqual(len(self.scenes), 8)
        self.assertEqual(set(self.scenes), set(self.registry["families"]))
        for family, (document, binary) in self.scenes.items():
            with self.subTest(family=family):
                raw = (self.source / "models" / (family + ".glb")).read_bytes()
                self.assertEqual(raw, (self.runtime / "models" / (family + ".glb")).read_bytes())
                self.assertEqual(recipe.sha256(raw), self.registry["families"][family]["sourceGLBSHA256"])
                glb_document, glb_binary = glb_parts(raw)
                editable = copy.deepcopy(document)
                editable["buffers"][0].pop("uri")
                self.assertEqual(editable, glb_document)
                self.assertEqual(binary, glb_binary[:len(binary)])
                self.assertEqual(document["images"], [{"uri": "../raw/texture-atlas.png"}])
                self.assertEqual(len({n["name"] for n in document["nodes"]}), len(document["nodes"]))

    def test_decoded_source_rgba8_pixels_and_one_pixel_negative(self):
        source = (self.source / "raw/texture-atlas.png").read_bytes()
        self.assertEqual(source, (self.runtime / "raw/texture-atlas.png").read_bytes())
        self.assertEqual(recipe.sha256(source), self.registry["atlasSHA256"])
        with Image.open(io.BytesIO(source)) as image:
            rgba = image.convert("RGBA")
            pixels = rgba.tobytes()
            self.assertEqual((rgba.width, rgba.height), (1254, 1254))
        expected = self.registry["atlasPixels"]["baseLevelSHA256"]
        self.assertEqual(recipe.sha256(pixels), expected)
        wrong = bytearray(pixels)
        wrong[0] ^= 1
        self.assertNotEqual(recipe.sha256(wrong), expected)
        self.assertIn("_image_sha(texture.get_image())", self.helper)
        self.assertIn("pixels.convert(Image.FORMAT_RGBA8)", self.helper)

    def test_all_actual_render_node_fingerprints(self):
        for family, (document, _binary) in self.scenes.items():
            pins = self.registry["families"][family]["nodes"]
            self.assertEqual(set(pins), {n["name"] for n in document["nodes"]})
            for node in document["nodes"]:
                pin = pins[node["name"]]
                if "mesh" not in node:
                    self.assertEqual(pin[0], "")
                    continue
                arrays = self.attributes(family, node["name"])
                self.assertEqual(render_hash(*arrays), pin[0])
                self.assertEqual(len(arrays[-1]) // 3, pin[1])
                self.assertEqual(pin[3] if len(pin) > 3 else [0, 0, 0], node.get("translation", [0, 0, 0]))
                self.assertEqual(pin[4] if len(pin) > 4 else [1, 1, 1], node.get("scale", [1, 1, 1]))

    def test_real_uv_color_normal_winding_negatives_keep_position_geometry(self):
        for family in self.scenes:
            positions, normals, uvs, colors, indices = self.attributes(family)
            baseline = render_hash(positions, normals, uvs, colors, indices)
            wrong_uv = list(uvs)
            wrong_uv[0] = (uvs[0][0] + .1, uvs[0][1])
            wrong_color = list(colors)
            wrong_color[0] = (max(0, colors[0][0] - .1), *colors[0][1:])
            wrong_normal = list(normals)
            wrong_normal[0] = tuple(-v for v in normals[0])
            wrong_indices = list(indices)
            wrong_indices[1], wrong_indices[2] = wrong_indices[2], wrong_indices[1]
            for changed in [(normals, wrong_uv, colors, indices),
                            (normals, uvs, wrong_color, indices),
                            (wrong_normal, uvs, colors, indices),
                            (normals, uvs, colors, wrong_indices)]:
                self.assertNotEqual(render_hash(positions, *changed), baseline)
            self.assertEqual(recipe.shape_hash(positions, indices),
                             recipe.shape_hash(positions, wrong_indices))

    def test_exact_fixed_collision_aggregate_excludes_stock_and_needle(self):
        for family, (document, _binary) in self.scenes.items():
            positions, indices = [], []
            for node in document["nodes"]:
                if "mesh" not in node or node["name"] in ["StockVolume", "StockNeedle"]:
                    continue
                local, _normal, _uv, _color, local_indices = self.attributes(family, node["name"])
                translation = node.get("translation", [0, 0, 0])
                scale = node.get("scale", [1, 1, 1])
                offset = len(positions)
                positions.extend(tuple(v[j] * scale[j] + translation[j] for j in range(3)) for v in local)
                indices.extend(i + offset for i in local_indices)
            expected = self.registry["families"][family]
            self.assertEqual(len(indices) // 3, expected["fixedTriangles"])
            self.assertEqual(recipe.shape_hash(positions, indices), expected["fixedSHA256"])
            wrong = list(positions)
            wrong[0] = (positions[0][0] + .01, *positions[0][1:])
            self.assertNotEqual(recipe.shape_hash(wrong, indices), expected["fixedSHA256"])
            fluid, _n, _u, _c, fluid_indices = self.attributes(family, "StockVolume")
            plus_fluid = indices + [i + len(positions) for i in fluid_indices]
            self.assertNotEqual(recipe.shape_hash(positions + fluid, plus_fluid), expected["fixedSHA256"])

    def test_frozen_quantization_cyclic_order_and_normal_storage_simulation(self):
        self.assertEqual([quant(v) for v in [.00005, -.00005, .00025, -.00025]], [1, -1, 3, -3])
        for family in self.scenes:
            positions, normals, uvs, colors, indices = self.attributes(family)
            baseline = render_hash(positions, normals, uvs, colors, indices)
            rotated = []
            triangles = [indices[i:i + 3] for i in range(0, len(indices), 3)]
            for triangle in reversed(triangles):
                rotated.extend(triangle[1:] + triangle[:1])
            self.assertEqual(render_hash(positions, normals, uvs, colors, rotated), baseline)
            for normal in set(normals):
                # Declared source-codec simulation only; not observed Godot4.7.2 parity.
                decoded = normal_decode(normal_codes(normal))
                self.assertLess(max(abs(a - b) for a, b in zip(normal, decoded)), .00015)

    def test_actual_source_sampler_material_uv_defaults_and_import_configuration(self):
        for family, (document, _binary) in self.scenes.items():
            self.assertEqual(document["samplers"], [{"magFilter": 9729, "minFilter": 9729,
                                                     "wrapS": 33071, "wrapT": 33071}])
            self.assertNotIn("KHR_texture_transform", document.get("extensionsUsed", []))
            self.assertEqual(len(document["materials"]), 16)
            for material in document["materials"]:
                info = material["pbrMetallicRoughness"]["baseColorTexture"]
                self.assertEqual(info.get("texCoord", 0), 0)
                self.assertFalse(info.get("extensions"))
                self.assertEqual(material["extensions"], {"KHR_materials_unlit": {}})
                self.assertFalse(material.get("doubleSided", False))
            settings = (self.runtime / "models" / (family + ".glb.import")).read_text()
            self.assertIn("meshes/force_disable_compression=true", settings)
            self.assertIn("meshes/generate_lods=false", settings)
        texture = (self.runtime / "raw/texture-atlas.png.import").read_text()
        for setting in ["compress/mode=0", "detect_3d/compress_to=0", "mipmaps/generate=false",
                        "process/fix_alpha_border=false", "process/premult_alpha=false"]:
            self.assertIn(setting, texture)
        for predicate in ["painted.uv1_scale.is_equal_approx(Vector3.ONE)",
                          "painted.uv1_offset.is_equal_approx(Vector3.ZERO)",
                          "painted.uv1_triplanar", "painted.uv1_world_triplanar",
                          "painted.use_point_size", "painted.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_LINEAR",
                          "painted.texture_repeat", "painted.detail_enabled", "painted.heightmap_enabled"]:
            self.assertIn(predicate, function_body(self.helper, "_material_ok"))

    def test_authored_vertex_color_route_is_explicit_import_only_not_runtime_repair(self):
        script = (ROOT / "game/scripts/healing_machinery_post_import.gd").read_text()
        self.assertTrue(script.startswith("@tool\nextends EditorScenePostImport\n"))
        paths = set(re.findall(r'"(res://assets/art/healing_machinery/models/[^"\n]+\.glb)"', script))
        self.assertEqual(paths, {s["path"] for s in self.registry["families"].values()})
        self.assertIn("if get_source_file() not in SOURCE_PATHS:", script)
        self.assertIn("arrays[Mesh.ARRAY_COLOR] is PackedColorArray", script)
        self.assertIn("arrays[Mesh.ARRAY_COLOR].size()!=arrays[Mesh.ARRAY_VERTEX].size()", script)
        self.assertLess(script.index("if materials.is_empty():"),
                        script.index("material.vertex_color_use_as_albedo=true"))
        self.assertEqual(script.count("material.vertex_color_use_as_albedo=true"), 1)
        for family in self.scenes:
            settings = (self.runtime / "models" / (family + ".glb.import")).read_text()
            self.assertIn('import_script/path="res://scripts/healing_machinery_post_import.gd"', settings)
        for family, (document, binary) in self.scenes.items():
            for node in document["nodes"]:
                if "mesh" in node:
                    positions, _normal, _uv, colors, _indices = self.attributes(family, node["name"])
                    self.assertEqual(len(colors), len(positions))
                    self.assertTrue(colors)
        self.assertIn("not painted.vertex_color_use_as_albedo", function_body(self.helper, "_material_ok"))
        self.assertNotIn("vertex_color_use_as_albedo=", self.helper)
        native = (ROOT / "game/tests/test_reservoir_runtime_rig_contract.gd").read_text()
        self.assertIn("live disabled COLOR_0 route rejected without runtime auto-repair", native)

    def test_same_material_uv_sampler_route_negatives_derived_source_model(self):
        def route_ok(m):
            return (m["scale"] == (1, 1, 1) and m["offset"] == (0, 0, 0)
                    and not any(m[k] for k in ["triplanar", "world", "points", "repeat", "detail", "height"])
                    and m["filter"] == "LINEAR")
        material = {"scale": (1, 1, 1), "offset": (0, 0, 0), "triplanar": False,
                    "world": False, "points": False, "repeat": False, "detail": False,
                    "height": False, "filter": "LINEAR"}
        original = material.copy()
        identity = id(material)
        for key, value in [("scale", (0, 0, 0)), ("offset", (.1, 0, 0)),
                           ("triplanar", True), ("world", True), ("points", True),
                           ("repeat", True), ("detail", True), ("height", True), ("filter", "NEAREST")]:
            material[key] = value
            self.assertEqual(id(material), identity)
            self.assertFalse(route_ok(material))
            material.clear()
            material.update(original)
            self.assertTrue(route_ok(material))

    def test_stock_full_partial_hidden_empty_source_bounds(self):
        for family, spec in self.registry["families"].items():
            positions, _n, _u, _c, _indices = self.attributes(family, "StockVolume")
            stock = spec["stock"]
            self.assertEqual((min(v[1] for v in positions), max(v[1] for v in positions)), (0, 1))
            for fraction in [0, .5, 1]:
                height = stock["fullHeightMeters"] * (fraction if fraction else 1)
                self.assertGreater(height, 0)
                ys = [v[1] * height + stock["bottomMeters"] for v in positions]
                self.assertAlmostEqual(min(ys), stock["bottomMeters"])
                self.assertAlmostEqual(max(ys), stock["bottomMeters"] + height)
            self.assertFalse(stock["emptyState"]["visible"])
            self.assertEqual(stock["emptyState"]["scalePolicy"], "preserve-full-authored-scale")

    def test_persistent_level_build_order_and_ephemeral_refresh_source_semantics(self):
        level = (ROOT / "game/scripts/level.gd").read_text()
        build = function_body(level, "build")
        self.assertLess(build.index("healing_machinery.build("), build.index("_build_navigation()"))
        main = (ROOT / "game/scripts/main.gd").read_text()
        self.assertLess(main.index("level.build(self,state.level_index)"), main.index("player = Player.new()"))
        runtime = (ROOT / "game/scripts/earned_supply_runtime.gd").read_text()
        refresh = function_body(runtime, "refresh")
        self.assertIn("for marker in _equipment.values()", refresh)
        self.assertNotIn("for marker in _markers.values()", refresh)
        self.assertIn("healing_machinery.update_stock(", refresh)
        self.assertIn("_markers[station.id]=game.level.healing_stations[station.id].root", refresh)
        self.assertNotIn("_reservoir_rig", runtime)
        fixed = function_body(self.helper, "_fixed_faces")
        self.assertIn('name in ["StockVolume","StockNeedle"]', fixed)
        self.assertIn("part.transform*point", fixed)
        self.assertNotIn("BoxShape3D", self.helper)
        self.assertIn("row.colliders.size()!=1", self.helper)

    def test_cli_is_portable_read_only_by_default_and_stdout_exact(self):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        script = CONTRACT / "build_registry.py"
        frozen = {p: recipe.sha256(p.read_bytes()) for p in [ROOT / "game/data/healing_machinery_registry.json",
                                                           ROOT / "game/scripts/healing_machinery.gd"]}
        with tempfile.TemporaryDirectory() as temporary:
            checked = subprocess.run([sys.executable, str(script)], cwd=temporary, env=env,
                                     capture_output=True, check=True)
            self.assertIn(b"exact source registry PASS", checked.stdout)
            actual = subprocess.check_output([sys.executable, str(script), "--stdout"], cwd=temporary, env=env)
            self.assertEqual(actual, self.registry_bytes)
        self.assertEqual({p: recipe.sha256(p.read_bytes()) for p in frozen}, frozen)

    def test_explicit_output_is_fresh_only_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "registry.json"
            self.assertEqual(recipe.main(["--output", str(output)]), 0)
            self.assertEqual(output.read_bytes(), self.registry_bytes)
            with self.assertRaises(FileExistsError):
                recipe.main(["--output", str(output)])
            self.assertEqual(output.read_bytes(), self.registry_bytes)

    def test_public_recipe_has_no_machine_private_path_or_history_dependency(self):
        files = list(CONTRACT.glob("*.py")) + [Path(__file__)]
        for path in files:
            text = path.read_text()
            for forbidden in ["/Users/", "rejected-history", "tar.gz", "earned-arsenal-prep"]:
                # The test's own negative literals are not a recipe dependency.
                if path == Path(__file__):
                    continue
                self.assertNotIn(forbidden, text)
        self.assertLess(sum(p.stat().st_size for p in files), 64 * 1024)


if __name__ == "__main__":
    unittest.main()
