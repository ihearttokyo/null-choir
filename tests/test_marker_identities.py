"""Engine-free recipe contracts; these fixtures do not certify rendered art."""
import ast
import importlib.util
import math
from pathlib import Path
import tempfile
from types import FunctionType
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / 'tools/build_marker_identities.py'


def load_recipe():
    spec = importlib.util.spec_from_file_location('marker_identities', RECIPE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MarkerIdentityContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = load_recipe()

    def test_closed_ids_and_reference(self):
        self.assertEqual(self.recipe.IDS, ('marker_ivorykey', 'marker_ammo_shells',
                         'marker_ammo_sawtooth', 'marker_ammo_marrow', 'marker_ammo_choir'))
        self.assertEqual(self.recipe.REFERENCE_SHA,
                         '061ac88b9d4ff2ae70da4b1996cc1f6d4cda92bf05a698d5887159a8fb2475f0')
        self.recipe.check_inputs()

    def test_helper_pin_drift_is_rejected(self):
        original = self.recipe.SOURCE_ROOT
        with tempfile.TemporaryDirectory() as folder:
            try:
                self.recipe.SOURCE_ROOT = Path(folder).resolve()
                with self.assertRaises(ValueError):
                    self.recipe.check_inputs()
                helper = self.recipe.SOURCE_ROOT / 'tools/build_art.py'
                helper.parent.mkdir()
                helper.write_text('changed helper')
                with self.assertRaisesRegex(ValueError, 'drifted input'):
                    self.recipe.check_inputs()
            finally:
                self.recipe.SOURCE_ROOT = original

    def test_candidate_paths_and_no_original_writes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve() / 'candidate'
            paths = self.recipe.prepare_paths(root, self.recipe.IDS[0])
            self.assertEqual(set(paths), {'source', 'model', 'preview', 'frame', 'receipt'})
            self.assertTrue(all(p.is_relative_to(root) for p in paths.values()))
            self.assertFalse(root.exists(), 'preflight must not write')
            for bad in ('marker_key', 'marker_ammo', '../escape', 'unknown'):
                with self.assertRaises(ValueError):
                    self.recipe.prepare_paths(root, bad)
            for bad in (ROOT, ROOT / 'candidate', ROOT.parent, Path('relative')):
                with self.assertRaises(ValueError):
                    self.recipe.prepare_paths(bad, self.recipe.IDS[0])
            root.mkdir()
            paths['source'].parent.mkdir(parents=True)
            paths['source'].write_bytes(b'valuable partial source')
            with self.assertRaises(ValueError):
                self.recipe.prepare_paths(root, self.recipe.IDS[0])
            self.assertEqual(paths['source'].read_bytes(), b'valuable partial source')

    def test_symlinks_and_escapes(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder).resolve()
            (base / 'real').mkdir()
            (base / 'alias').symlink_to(base / 'real', target_is_directory=True)
            for root in (base / 'alias', base / 'real' / '..' / 'escape'):
                with self.assertRaises(ValueError):
                    self.recipe.prepare_paths(root, self.recipe.IDS[0])
            root = base / 'candidate'
            root.mkdir()
            (root / 'source').symlink_to(base / 'real', target_is_directory=True)
            with self.assertRaises(ValueError):
                self.recipe.prepare_paths(root, self.recipe.IDS[0])
            (base / 'project' / 'game').mkdir(parents=True)
            (base / 'project' / 'game/project.godot').write_text('original')
            with self.assertRaises(ValueError):
                self.recipe.prepare_paths(base / 'project' / 'new', self.recipe.IDS[0])

    def test_budget_boundaries(self):
        good = {'min': [-.45, -.45, 0], 'max': [.45, .45, 1.2], 'size': [.9, .9, 1.2]}
        self.recipe.check_geometry(good, 2500, 8)
        for triangles, groups in ((2501, 8), (0, 8), (2500, 9), (2500, 0)):
            with self.assertRaises(ValueError):
                self.recipe.check_geometry(good, triangles, groups)
        for field, value in (('size', [.90001, .9, 1.2]), ('size', [.9, .9, 1.20001]),
                             ('min', [-.45, -.45, -.01]), ('max', [.5, .45, 1.2]),
                             ('size', [math.nan, .9, 1.2])):
            bad = dict(good, **{field: value})
            with self.assertRaises(ValueError):
                self.recipe.check_geometry(bad, 100, 3)
        self.recipe.check_glb_size(150000)
        for size in (0, 150001):
            with self.assertRaises(ValueError):
                self.recipe.check_glb_size(size)

    def test_preview_alpha_and_framing(self):
        pixels = bytearray(128 * 128 * 4)
        pixels[(64 * 128 + 64) * 4 + 3] = 255
        self.recipe.check_preview(pixels)
        for bad in (bytearray(), bytearray(128 * 128 * 4), bytearray([255] * (128 * 128 * 4))):
            with self.assertRaises(ValueError):
                self.recipe.check_preview(bad)
        pixels[3] = 255
        with self.assertRaises(ValueError):
            self.recipe.check_preview(pixels)

    def test_native_source_precedes_runtime_merge(self):
        tree = ast.parse(RECIPE.read_text())
        build = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'build')
        calls = [n for n in ast.walk(build) if isinstance(n, ast.Call)]
        save = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'save')
        join = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'join')
        export = next(n for n in calls if isinstance(n.func, ast.Attribute) and n.func.attr == 'gltf')
        self.assertLess(save.lineno, join.lineno)
        self.assertLess(join.lineno, export.lineno)
        self.assertIn('recipe_dependencies', RECIPE.read_text())
        self.assertIn('reference_sha256', RECIPE.read_text())
        self.assertNotIn('marker-manifest.json', RECIPE.read_text())


class Capture:
    """Capture real recipe primitive arguments, not Blender or raster output."""
    def __init__(self):
        self.parts = []

    def tube(self, name, points, radii, mat='bone', sides=8):
        self.parts.append(('tube', name, points, radii, mat, sides))

    def ring(self, name, center, radius, thickness, mat='bone', plane='XY', segments=24):
        # Match retained helper's actual ring path construction.
        cx, cy, cz = center
        points = [(cx + radius * math.cos(i * 2 * math.pi / segments),
                   cy + radius * math.sin(i * 2 * math.pi / segments) if plane == 'XY' else cy,
                   cz if plane == 'XY' else cz + radius * math.sin(i * 2 * math.pi / segments))
                  for i in range(segments + 1)]
        self.tube(name, points, thickness, mat)

    def mesh(self, name, vertices, faces, mat):
        self.parts.append(('mesh', name, vertices, faces, mat))


def captured_geometry(recipe, name, art=None):
    art = art if art is not None else Capture()
    helper_tree = ast.parse((ROOT / 'tools/build_marker_art.py').read_text())
    plate_node = next(n for n in helper_tree.body if isinstance(n, ast.FunctionDef) and n.name == 'plate')
    namespace = {'art': art}
    exec(compile(ast.Module(body=[plate_node], type_ignores=[]), '<retained plate>', 'exec'), namespace)
    build = recipe.RECIPES[name]
    if type(art) is Capture:
        # Retain the original antler-envelope witnesses; emitted surfaces are checked separately.
        def sweep(art, name, *args, **kwargs):
            if name.startswith('Ivory lateral antler'):
                return art.tube(name, *args, **kwargs)
            return recipe.xz_tube(art, name, *args, **kwargs)
        build = FunctionType(build.__code__, dict(build.__globals__, xz_tube=sweep))
    build(art, namespace['plate'])
    return art.parts


def covers(parts, x, z):
    # Conservative XZ tube envelope and exact planar plate silhouette, not pixel QA.
    for kind, _, points, radii, *_ in parts:
        if kind == 'mesh':
            for face in radii:
                polygon = [(points[i][0], points[i][2]) for i in face]
                inside = False
                for (ax, az), (bx, bz) in zip(polygon, polygon[1:] + polygon[:1]):
                    if (az > z) != (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax:
                        inside = not inside
                if inside:
                    return True
        else:
            radius = radii if isinstance(radii, (int, float)) else max(radii)
            for a, b in zip(points, points[1:]):
                dx, dz = b[0] - a[0], b[2] - a[2]
                length = dx * dx + dz * dz
                t = min(1, max(0, ((x - a[0]) * dx + (z - a[2]) * dz) / length)) if length else 0
                if math.hypot(x - a[0] - t * dx, z - a[2] - t * dz) <= radius:
                    return True
    return False


class MarkerGeometryFixtures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = load_recipe()
        cls.parts = {name: captured_geometry(cls.recipe, name) for name in cls.recipe.IDS}

    def test_source_primitive_triangle_and_material_budgets(self):
        for name, parts in self.parts.items():
            triangles = 0
            for part in parts:
                if part[0] == 'mesh':
                    triangles += sum(len(face) - 2 for face in part[3])
                else:
                    sides = part[5]
                    triangles += (len(part[2]) - 1) * sides * 2 + 2 * (sides - 2)
            self.assertGreater(triangles, 0, name)
            self.assertLessEqual(triangles, 2500, name)
            self.assertLessEqual(len({p[4] for p in parts}), 8, name)
            self.assertEqual(len({p[1] for p in parts}), len(parts), name)

    def test_distinct_grayscale_silhouettes(self):
        masks = [tuple(covers(parts, x / 100, z / 100)
                       for z in range(3, 116, 3) for x in range(-42, 43, 3))
                 for parts in self.parts.values()]
        self.assertEqual(len(set(masks)), 5)
        for i, a in enumerate(masks):
            for b in masks[i + 1:]:
                self.assertGreater(sum(x != y for x, y in zip(a, b)), 35)

    def test_ivory_three_antlers_and_open_diamond_slit(self):
        parts = self.parts['marker_ivorykey']
        self.assertEqual(sum('antler' in p[1].lower() for p in parts), 3)
        for x, z in ((0, .54), (0, .18), (0, .05), (.17, .94), (-.17, .94)):
            self.assertFalse(covers(parts, x, z), (x, z))
        self.assertTrue(covers(parts, 0, 1.05))
        self.assertTrue(covers(parts, .31, 1.03))
        self.assertTrue(covers(parts, -.31, 1.03))

    def test_ammo_family_motifs_and_real_gaps(self):
        shells = self.parts['marker_ammo_shells']
        self.assertEqual(sum('shell body' in p[1].lower() for p in shells), 2)
        self.assertFalse(covers(shells, 0, .75))
        saw = self.parts['marker_ammo_sawtooth']
        self.assertEqual(sum('cartridge spine' in p[1].lower() for p in saw), 5)
        self.assertGreaterEqual(sum('saw tooth' in p[1].lower() for p in saw), 6)
        self.assertFalse(covers(saw, .07, .86))
        marrow = self.parts['marker_ammo_marrow']
        self.assertFalse(covers(marrow, 0, .81))
        self.assertTrue(covers(marrow, 0, 1.02))
        choir = self.parts['marker_ammo_choir']
        self.assertEqual(sum('resonant tine' in p[1].lower() for p in choir), 2)
        self.assertFalse(covers(choir, 0, .85))
        self.assertTrue(covers(choir, 0, .30))


class Vector(tuple):
    """Only the vector arithmetic used by the unchanged retained tube AST."""
    def __add__(self, other):
        return Vector(a + b for a, b in zip(self, other))

    def __sub__(self, other):
        return Vector(a - b for a, b in zip(self, other))

    def __mul__(self, value):
        return Vector(a * value for a in self)

    __rmul__ = __mul__

    @property
    def z(self):
        return self[2]

    def cross(self, other):
        x, y, z = self
        a, b, c = other
        return Vector((y * c - z * b, z * a - x * c, x * b - y * a))

    def normalized(self):
        length = math.sqrt(sum(a * a for a in self))
        return self * (1 / length) if length else Vector((0, 0, 0))


class MeshCapture(Capture):
    """Execute the retained primitive AST and collect its actual emitted faces."""
    def __init__(self):
        super().__init__()
        tree = ast.parse((ROOT / 'tools/build_art.py').read_text())
        nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ('tube', 'ring')]
        self.namespace = {'Vector': Vector, 'math': math, 'mesh': self.mesh}
        exec(compile(ast.Module(body=nodes, type_ignores=[]), '<retained tube/ring>', 'exec'), self.namespace)

    def tube(self, *args, **kwargs):
        return self.namespace['tube'](*args, **kwargs)

    def ring(self, *args, **kwargs):
        return self.namespace['ring'](*args, **kwargs)


def edge_crosses(a, b, c, d):
    a, b, c, d = (Vector(p) for p in (a, b, c, d))
    u, v, w = b - a, d - c, a - c
    dot = lambda p, q: sum(x * y for x, y in zip(p, q))
    aa, bb, cc, dd, ee = dot(u, u), dot(u, v), dot(v, v), dot(u, w), dot(v, w)
    determinant = aa * cc - bb * bb
    if abs(determinant) < 1e-20:
        return False
    t, s = (bb * ee - cc * dd) / determinant, (aa * ee - bb * dd) / determinant
    return (1e-8 < t < 1 - 1e-8 and 1e-8 < s < 1 - 1e-8
            and sum(p * p for p in w + u * t - v * s) < 1e-18)


def bad_faces(parts):
    defects = []
    for _, name, vertices, faces, _ in parts:
        for number, face in enumerate(faces):
            points = [Vector(vertices[i]) for i in face]
            normal = Vector((0, 0, 0))
            for a, b in zip(points, points[1:] + points[:1]):
                normal = normal + a.cross(b)
            zero = sum(v * v for v in normal) < 1e-20
            crossing = len(points) == 4 and (edge_crosses(*points) or
                       edge_crosses(points[1], points[2], points[3], points[0]))
            if zero or crossing:
                defects.append((name, number, face, zero, crossing))
    return defects


class EmittedFaceRegression(unittest.TestCase):
    def test_exact_legacy_diamond_bow_tie_is_reproduced(self):
        art = MeshCapture()
        art.tube('legacy diamond', [(0, 0, .37), (.135, 0, .54), (0, 0, .71),
                 (-.135, 0, .54), (0, 0, .37)], .028, 'bone', 6)
        _, _, vertices, faces, _ = art.parts[0]
        self.assertEqual(faces[1], (1, 2, 8, 7))
        a, b, c, d = (Vector(vertices[i]) for i in faces[1])
        self.assertLess(sum(v * v for v in (b + c) * .5 - (d + a) * .5), 1e-20)
        self.assertTrue(edge_crosses(b, c, d, a))
        self.assertEqual(len(bad_faces(art.parts)), 4)

    def test_fixed_sweep_closed_seam_is_manifold(self):
        recipe = load_recipe()
        parts = captured_geometry(recipe, 'marker_ivorykey', MeshCapture())
        _, _, vertices, faces, _ = next(p for p in parts if p[1] == 'Open ivory diamond bezel')
        self.assertEqual(len(vertices), 24)
        self.assertEqual(len(faces), 24)
        self.assertTrue(all(len(face) == 4 for face in faces), 'closed sweep has no duplicate caps')
        edges = {}
        for face in faces:
            for a, b in zip(face, face[1:] + face[:1]):
                edge = tuple(sorted((a, b)))
                edges[edge] = edges.get(edge, 0) + 1
        self.assertTrue(all(count == 2 for count in edges.values()))

    def test_fixed_plane_input_validation(self):
        recipe = load_recipe()
        for points, radii in (([(0, 0, 0)], .02),
                              ([(0, 0, 0), (0, .1, 1)], .02),
                              ([(0, 0, 0), (math.nan, 0, 1)], .02),
                              ([(0, 0, 0), (0, 0, 1)], 0),
                              ([(0, 0, 0), (0, 0, 1)], [.02]),
                              ([(0, 0, 0), (0, 0, 0)], .02),
                              ([(0, 0, 0), (1, 0, 1), (0, 0, 0)], .02),
                              ([(0, 0, 0), (1, 0, 1), (-1, 0, 1), (0, 0, 0)],
                               [.02, .02, .02, .03])):
            art = MeshCapture()
            with self.assertRaises(ValueError):
                recipe.xz_tube(art, 'invalid sweep', points, radii)
            self.assertEqual(art.parts, [])

    def test_all_candidate_emitted_faces_are_sound(self):
        recipe = load_recipe()
        for name in recipe.IDS:
            with self.subTest(asset=name):
                parts = captured_geometry(recipe, name, MeshCapture())
                self.assertEqual(bad_faces(parts), [], 'crossed or zero-area emitted face')
                triangles = sum(len(face) - 2 for p in parts for face in p[3])
                self.assertLessEqual(triangles, 2500)
                points = [v for p in parts for v in p[2]]
                size = [max(p[i] for p in points) - min(p[i] for p in points) for i in range(3)]
                self.assertTrue(all(0 < v <= cap for v, cap in zip(size, (.9, .9, 1.2))))
                self.assertLessEqual(len({p[4] for p in parts}), 8)


def triangles_for_face(face, vertices, other_diagonal=False):
    if len(face) == 3:
        return [face]
    if len(face) == 4:
        return [(face[0], face[1], face[3]), (face[1], face[2], face[3])] if other_diagonal else [
                (face[0], face[1], face[2]), (face[0], face[2], face[3])]
    # Ear clipping keeps concave retained plate caps inside their actual outline.
    normal = Vector((0, 0, 0))
    for a, b in zip(face, face[1:] + face[:1]):
        normal = normal + Vector(vertices[a]).cross(Vector(vertices[b]))
    axis = max(range(3), key=lambda i: abs(normal[i]))
    xy = {i: tuple(v for j, v in enumerate(vertices[i]) if j != axis) for i in face}
    turn = lambda a, b, c: (xy[b][0] - xy[a][0]) * (xy[c][1] - xy[a][1]) - (xy[b][1] - xy[a][1]) * (xy[c][0] - xy[a][0])
    area = sum(xy[a][0] * xy[b][1] - xy[b][0] * xy[a][1] for a, b in zip(face, face[1:] + face[:1]))
    sign = 1 if area > 0 else -1
    remaining, result = list(face), []
    while len(remaining) > 3:
        for index, b in enumerate(remaining):
            a, c = remaining[index - 1], remaining[(index + 1) % len(remaining)]
            if sign * turn(a, b, c) <= 1e-14:
                continue
            if any(all(sign * turn(x, y, q) >= -1e-14 for x, y in ((a, b), (b, c), (c, a)))
                   for q in remaining if q not in (a, b, c)):
                continue
            result.append((a, b, c))
            remaining.pop(index)
            break
        else:
            raise AssertionError('fixture polygon cannot be triangulated')
    return result + [tuple(remaining)]


def proper_triangle_hit(a, b, triangle):
    a, b = Vector(a), Vector(b)
    p, q, r = (Vector(v) for v in triangle)
    direction, e1, e2 = b - a, q - p, r - p
    dot = lambda x, y: sum(i * j for i, j in zip(x, y))
    h = direction.cross(e2)
    determinant = dot(e1, h)
    if abs(determinant) < 1e-14:
        return None
    offset = a - p
    u = dot(offset, h) / determinant
    cross = offset.cross(e1)
    v, t = dot(direction, cross) / determinant, dot(e2, cross) / determinant
    return (t, u, v) if 1e-8 < t < 1 - 1e-8 and u > 1e-8 and v > 1e-8 and u + v < 1 - 1e-8 else None


def self_intersections(part, other_diagonal=False):
    _, name, vertices, faces, _ = part
    triangles, edges = [], {}
    for number, face in enumerate(faces):
        for triangle in triangles_for_face(face, vertices, other_diagonal):
            points = [vertices[i] for i in triangle]
            bounds = [(min(p[i] for p in points), max(p[i] for p in points)) for i in range(3)]
            triangles.append((number, triangle, bounds))
            for a, b in zip(triangle, triangle[1:] + triangle[:1]):
                edges.setdefault(tuple(sorted((a, b))), set()).add(number)
    for (a, b), owners in edges.items():
        pa, pb = vertices[a], vertices[b]
        bounds = [(min(pa[i], pb[i]), max(pa[i], pb[i])) for i in range(3)]
        for number, triangle, target in triangles:
            if number in owners or a in triangle or b in triangle:
                continue
            if any(hi < low - 1e-10 or high < lo - 1e-10 for (lo, hi), (low, high) in zip(bounds, target)):
                continue
            hit = proper_triangle_hit(pa, pb, [vertices[i] for i in triangle])
            if hit:
                return [(name, (a, b), triangle, hit)]
    return []


class CrossFaceAndSeamRegression(unittest.TestCase):
    def test_exact_retained_antler_cross_face_witness(self):
        art = MeshCapture()
        art.tube('legacy antler', [(.085, 0, .66), (.27, 0, .76), (.35, 0, .97), (.31, 0, 1.10)],
                 [.048, .045, .033, .006], 'bone', 8)
        vertices = art.parts[0][2]
        hit = proper_triangle_hit(vertices[9], vertices[17], [vertices[i] for i in (10, 19, 18)])
        self.assertIsNotNone(hit)
        self.assertAlmostEqual(hit[0], .550386565, places=8)
        self.assertEqual(bad_faces(art.parts), [], 'per-face checks miss this cross-face defect')
        for diagonal in (False, True):
            self.assertTrue(self_intersections(art.parts[0], diagonal))

    def test_every_named_mesh_has_no_proper_self_intersection(self):
        recipe = load_recipe()
        for name in recipe.IDS:
            for part in captured_geometry(recipe, name, MeshCapture()):
                for diagonal in (False, True):
                    with self.subTest(asset=name, part=part[1], diagonal=diagonal):
                        self.assertEqual(self_intersections(part, diagonal), [])

    def test_every_mesh_is_closed_and_outward_under_both_diagonals(self):
        recipe = load_recipe()
        for name in recipe.IDS:
            for _, part, vertices, faces, _ in captured_geometry(recipe, name, MeshCapture()):
                directed = {}
                for face in faces:
                    for edge in zip(face, face[1:] + face[:1]):
                        directed[edge] = directed.get(edge, 0) + 1
                self.assertTrue(all(count == 1 and directed.get((b, a)) == 1
                                    for (a, b), count in directed.items()), part)
                rounded = [tuple(round(v, 12) for v in p) for p in vertices]
                self.assertEqual(len(set(rounded)), len(vertices), part + ' duplicate seam vertices')
                for diagonal in (False, True):
                    volume = 0
                    for face in faces:
                        for a, b, c in triangles_for_face(face, vertices, diagonal):
                            cross = Vector(vertices[b]).cross(Vector(vertices[c]))
                            volume += sum(x * y for x, y in zip(vertices[a], cross)) / 6
                    self.assertGreater(volume, 1e-12, part + ' outward signed volume')

    def test_xy_ring_seams_share_one_closed_vertex_loop(self):
        recipe = load_recipe()
        names = ('Shell brass shoulder 0', 'Crimped shell crown 0',
                 'Shell brass shoulder 1', 'Crimped shell crown 1',
                 'Marrow socket collar', 'Choir lower vertebral cuff')
        rings = [p for name in recipe.IDS for p in captured_geometry(recipe, name, MeshCapture())
                 if p[1] in names]
        self.assertEqual({p[1] for p in rings}, set(names))
        self.assertEqual(len(rings), 6)
        for _, _, vertices, faces, _ in rings:
            self.assertEqual(len(vertices), 80)
            self.assertEqual(len(faces), 80)
            self.assertTrue(all(len(face) == 4 for face in faces))
        with self.assertRaises(ValueError):
            recipe.xz_tube(MeshCapture(), 'unsupported plane', [(0, 0, 0), (1, 0, 1)], .02, plane='YZ')
        with self.assertRaises(ValueError):
            recipe.xz_tube(MeshCapture(), 'off XY plane', [(0, 0, 0), (1, 0, 1)], .02, plane='XY')

    def test_emitted_antler_solids_and_real_air_gaps(self):
        parts = captured_geometry(load_recipe(), 'marker_ivorykey', MeshCapture())
        for x in (-.33, .33):
            self.assertTrue(covers(parts, x, 1.03))
        for x, z in ((0, .54), (0, .18), (0, .05), (.17, .94), (-.17, .94)):
            self.assertFalse(covers(parts, x, z))


if __name__ == '__main__':
    unittest.main()
