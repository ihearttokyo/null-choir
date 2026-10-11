"""Source/geometry contracts only; not native render or recognition acceptance."""
import ast
import hashlib
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / 'tools/build_marker_glyphs.py'


class MarkerGlyphContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('marker_glyphs', FILE)
        cls.recipe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.recipe)

    def test_input_pins_and_recipe_drift(self):
        digest = hashlib.sha256(FILE.read_bytes()).hexdigest()
        self.recipe.check_inputs(digest)
        with self.assertRaises(ValueError):
            self.recipe.check_inputs('0' * 64)
        original = self.recipe.SOURCE_ROOT
        try:
            with tempfile.TemporaryDirectory() as folder:
                self.recipe.SOURCE_ROOT = Path(folder).resolve()
                with self.assertRaises(ValueError):
                    self.recipe.check_inputs(digest)
        finally:
            self.recipe.SOURCE_ROOT = original

    def test_literal_game_ids(self):
        r = self.recipe
        purposes = ('ammo', 'health', 'armor', 'key', 'weapon', 'story', 'checkpoint', 'exit')
        weapons = ('impact_tool', 'rivet_pistol', 'scattergun', 'sawtooth_repeater',
                   'marrow_launcher', 'choir_disruptor')
        self.assertEqual(r.NAMES, purposes + ('seal_blood', 'seal_ivory') + weapons)
        player = (ROOT / 'game/scripts/player.gd').read_text()
        level = (ROOT / 'game/scripts/level.gd').read_text()
        for name in weapons:
            self.assertIn('"asset":"' + name + '"', player)
        for kind in purposes:
            self.assertIn('"' + kind + '":"marker_' + kind + '"', level)
        self.assertEqual(r.CONTRACTS['weapons'], list(weapons))
        self.assertEqual(r.CONTRACTS['seals'], {'blood': 'seal_blood', 'ivory': 'seal_ivory'})
        self.assertEqual(r.CONTRACTS['hud']['heart'], 'health')
        self.assertEqual(r.CONTRACTS['survey'], {k: k for k in ('key', 'story', 'checkpoint', 'exit')})

    def test_candidate_root_is_fresh_external_and_alias_free(self):
        r = self.recipe
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder).resolve()
            good = base / 'candidate'
            paths = r.prepare_paths(good)
            self.assertFalse(good.exists())
            self.assertEqual(set(paths), {'blend', 'atlas', 'metadata', 'receipt'})
            self.assertTrue(all(p.is_relative_to(good) for p in paths.values()))
            for bad in (ROOT, ROOT.parent, ROOT / 'candidate', Path('relative'), base / '..' / 'escape'):
                with self.assertRaises(ValueError):
                    r.prepare_paths(bad)
            good.mkdir()
            partial = good / 'valuable-partial.blend'
            partial.write_bytes(b'preserve')
            with self.assertRaises(ValueError):
                r.prepare_paths(good)
            self.assertEqual(partial.read_bytes(), b'preserve')
            (base / 'alias').symlink_to(base / 'missing', target_is_directory=True)
            with self.assertRaises(ValueError):
                r.prepare_paths(base / 'alias' / 'new')
            project = base / 'other-project'
            (project / 'game').mkdir(parents=True)
            (project / 'game/project.godot').write_text('original')
            with self.assertRaises(ValueError):
                r.prepare_paths(project / 'candidate')

    def test_isolated_blender_environment(self):
        r = self.recipe
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            env = {}
            for variable, child in r.ISOLATION_DIRS.items():
                (root / child).mkdir()
                env[variable] = str(root / child)
            self.assertEqual(r.check_isolation(root, env), env)
            for variable in env:
                bad = dict(env)
                bad[variable] = str(root)
                with self.assertRaises(ValueError):
                    r.check_isolation(root, bad)
            with self.assertRaises(ValueError):
                r.check_isolation(ROOT, env)

    def test_geometry_budget_and_genuine_apertures(self):
        r = self.recipe
        total = 0
        for name in r.NAMES:
            parts = r.geometry(name)
            self.assertTrue(parts, name)
            self.assertEqual(len(parts), len({label for label, _ in parts}))
            for label, polygon in parts:
                self.assertGreaterEqual(len(polygon), 3, (name, label))
                self.assertTrue(all(math.isfinite(v) and abs(v) <= .4375
                                    for point in polygon for v in point), (name, label))
                total += 4 * len(polygon) - 4
        self.assertLess(total, 10000)
        for name, point in [('seal_ivory', (0, .04)), ('seal_blood', (0, -.30)),
                            ('marrow_launcher', (0, 0)), ('choir_disruptor', (.07, 0)),
                            ('key', (0, .25)), ('story', (0, .05))]:
            self.assertFalse(covers(r.geometry(name), *point), (name, 'aperture filled'))
        for name, point in [('seal_blood', (0, -.05)), ('seal_ivory', (0, .33)),
                            ('impact_tool', (0, 0))]:
            self.assertTrue(covers(r.geometry(name), *point), name)
        with self.assertRaises(ValueError):
            r.geometry('unknown')

    def test_retained_plate_emits_independent_sound_faces(self):
        tree = ast.parse((ROOT / 'tools/build_hud_art.py').read_text())
        node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'plate')
        namespace = {}
        exec(compile(ast.Module(body=[node], type_ignores=[]), '<retained HUD plate>', 'exec'), namespace)
        class MeshCapture:
            def mesh(self, name, vertices, faces, material):
                return vertices, faces
        for name in self.recipe.NAMES:
            for label, polygon in self.recipe.geometry(name):
                vertices, faces = namespace['plate'](MeshCapture(), label, polygon, 'ivory', depth=.025)
                self.assertEqual(len(vertices), 2 * len(polygon))
                self.assertEqual(len(faces), len(polygon) + 2)
                for face in faces:
                    self.assertEqual(len(face), len(set(face)), (name, label))
                    normal = [0., 0., 0.]
                    for i, j in zip(face, face[1:] + face[:1]):
                        a, b = vertices[i], vertices[j]
                        normal[0] += (a[1]-b[1])*(a[2]+b[2])
                        normal[1] += (a[2]-b[2])*(a[0]+b[0])
                        normal[2] += (a[0]-b[0])*(a[1]+b[1])
                    self.assertGreater(sum(v*v for v in normal), 1e-12, (name, label, face))
                volume = 0.0
                for face in faces:
                    a = vertices[face[0]]
                    for index in range(1, len(face)-1):
                        b, c = vertices[face[index]], vertices[face[index+1]]
                        volume += (a[0]*(b[1]*c[2]-b[2]*c[1]) + a[1]*(b[2]*c[0]-b[0]*c[2]) + a[2]*(b[0]*c[1]-b[1]*c[0])) / 6
                self.assertGreater(volume, 1e-12, (name, label, 'outward solid'))

    def test_distinct_small_size_geometry_masks_not_visual_acceptance(self):
        for size in (16, 24, 32):
            masks = []
            for name in self.recipe.NAMES:
                parts = self.recipe.geometry(name)
                mask = bytes(covers(parts, (x + .5) / size - .5, .5 - (y + .5) / size)
                             for y in range(size) for x in range(size))
                self.assertGreater(sum(mask), 8, (name, size))
                masks.append(mask)
            self.assertEqual(len(set(masks)), 16, size)

    def test_blood_droplet_keeps_a_real_airgap(self):
        parts = dict(self.recipe.geometry('seal_blood'))
        fork_low = min(y for _, y in parts['blood fork'])
        drop_high = max(y for _, y in parts['isolated blood droplet'])
        self.assertGreaterEqual(fork_low - drop_high, .06 - 1e-9)
        self.assertFalse(covers(list(parts.items()), 0, .07))

    def test_failed_preflight_never_imports_blender_or_writes(self):
        r = self.recipe
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder).resolve()
            isolation = base / 'isolated'
            isolation.mkdir()
            env = {}
            for variable, child in r.ISOLATION_DIRS.items():
                (isolation / child).mkdir()
                env[variable] = str(isolation / child)
            original = r.os.environ
            try:
                r.os.environ = env
                with self.assertRaisesRegex(ValueError, 'drifted input'):
                    r.build(base / 'candidate', isolation, '0'*64)
                self.assertFalse((base / 'candidate').exists())
                with self.assertRaisesRegex(ValueError, 'disjoint'):
                    r.build(isolation / 'candidate', isolation, hashlib.sha256(FILE.read_bytes()).hexdigest())
                self.assertFalse((isolation / 'candidate').exists())
            finally:
                r.os.environ = original

    def pixels(self):
        r = self.recipe
        pixels = bytearray(256 * 256 * 4)
        for index in range(16):
            x, y = index % 4 * 64 + 32, index // 4 * 64 + 32
            pixels[(y * 256 + x) * 4:(y * 256 + x) * 4 + 4] = bytes(r.IVORY_RGBA)
        return pixels

    def test_metadata_regions_palette_binary_alpha_and_gutters(self):
        r = self.recipe
        counts = {name: 100 for name in r.NAMES}
        pixels = self.pixels()
        meta = r.metadata(pixels, counts, 'a' * 64)
        self.assertEqual(meta['dimensions'], [256, 256])
        self.assertEqual(list(meta['sprites']), list(r.NAMES))
        self.assertEqual(meta['contracts'], r.CONTRACTS)
        self.assertEqual(meta['recipe_sha256'], 'a' * 64)
        for index, name in enumerate(r.NAMES):
            self.assertEqual(meta['sprites'][name]['region'], [index % 4 * 64, index // 4 * 64, 64, 64])
        for offset, color in [(3, bytes(r.IVORY_RGBA)),
                              ((32 * 256 + 32) * 4, bytes((1, 2, 3, 255))),
                              ((32 * 256 + 32) * 4, bytes((232, 221, 196, 128)))]:
            bad = bytearray(pixels)
            bad[offset:offset + 4] = color
            with self.assertRaises(ValueError):
                r.metadata(bad, counts, 'a' * 64)
        for bad in (bytearray(), bytearray(len(pixels))):
            with self.assertRaises(ValueError):
                r.metadata(bad, counts, 'a' * 64)
        with self.assertRaises(ValueError):
            r.metadata(pixels, {name: 625 for name in r.NAMES}, 'a' * 64)

    def test_size_limits_are_strict(self):
        self.recipe.check_sizes(128 * 1024 - 1, 8 * 1024 * 1024 - 1)
        for runtime, source in ((0, 1), (128 * 1024, 1), (1, 0), (1, 8 * 1024 * 1024)):
            with self.assertRaises(ValueError):
                self.recipe.check_sizes(runtime, source)

    def test_native_source_saved_before_render_and_no_adoption(self):
        tree = ast.parse(FILE.read_text())
        build = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'build')
        calls = [n for n in ast.walk(build) if isinstance(n, ast.Call)]
        save = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'save_as_mainfile')
        render = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'pixels_render')
        png = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'png')
        self.assertLess(save.lineno, render.lineno)
        self.assertLess(render.lineno, png.lineno)
        self.assertNotIn('bpy.ops.object.join', FILE.read_text())
        self.assertNotIn('manifest.json', FILE.read_text())


def covers(parts, x, y):
    """Even-odd polygon coverage of recipe outlines; no Blender/pixel substitution."""
    for _, polygon in parts:
        inside = False
        for (ax, ay), (bx, by) in zip(polygon, polygon[1:] + polygon[:1]):
            if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                inside = not inside
        if inside:
            return True
    return False


if __name__ == '__main__':
    unittest.main()
