"""Pre-native geometry contract; no Blender or engine imports."""
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

RECIPE = Path(__file__).resolve().parents[1] / 'tools/build_rivet_pistol_v2.py'
spec = importlib.util.spec_from_file_location('rivet_v2', RECIPE)
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


def front_surface(meshes, point):
    """Depth-ray the actual authored triangles, without simulating lighting."""
    hits = []
    x, y = point
    for mesh in meshes:
        for face in mesh['faces']:
            for j in range(1, len(face)-1):
                a, b, c = (mesh['vertices'][face[i]] for i in (0, j, j+1))
                denominator = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
                if abs(denominator) < 1e-8:
                    continue
                u = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denominator
                v = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denominator
                if u >= 0 and v >= 0 and u+v <= 1:
                    hits.append((u*a[2]+v*b[2]+(1-u-v)*c[2], mesh['material'], mesh['name']))
    return min(hits) if hits else None


class RivetGeometryTest(unittest.TestCase):
    def test_receiver_intervals_are_open_to_dark_core(self):
        meshes = art.geometry()
        for point in ((201, 100), (209, 105), (217, 110)):
            hit = front_surface(meshes, point)
            self.assertIsNotNone(hit)
            self.assertIn(hit[1], ('steel', 'oxblood', 'groove'), f'{point}: slab hides the receiver: {hit}')

    def test_reliquary_is_recessed_and_wear_is_bounded(self):
        meshes = art.geometry()
        tablet = front_surface(meshes, (223, 134))
        border = front_surface(meshes, (236, 134))
        self.assertEqual(tablet[1], 'steel')
        self.assertEqual(border[1], 'brass_edge')
        self.assertGreater(tablet[0]-border[0], 3, 'Tablet must lie behind an open raised bezel')
        self.assertEqual(set(art.SURFACES), set(art.PALETTE))
        self.assertEqual(art.linear_rgba('#000000'), (0, 0, 0, 1))
        self.assertEqual(art.linear_rgba('#ffffff'), (1, 1, 1, 1))
        self.assertAlmostEqual(art.linear_rgba('#808080')[0], .21586, places=4)
        for dark, light, frequency, depth in art.SURFACES.values():
            self.assertLess(sum(art.linear_rgba(dark)[:3]), sum(art.linear_rgba(light)[:3]))
            self.assertTrue(7 <= frequency <= 10, 'Wear patches span roughly8-11px, not noisy microtexture')
            self.assertTrue(0 < depth <= .005, 'Subpixel bump must not replace sculptural mesh depth')

    def test_substantial_editable_mesh(self):
        meshes = art.geometry()
        triangles = sum(len(face)-2 for mesh in meshes for face in mesh['faces'])
        self.assertGreaterEqual(triangles, 5000, 'Original thick cage, receiver and glove need real mesh mass')
        self.assertLessEqual(triangles, 20000)
        for label in ('Vertebral rib', 'Receiver', 'Reliquary', 'Glove', 'Forearm', 'Muzzle'):
            self.assertTrue(any(label in m['name'] for m in meshes), label)

    def test_geometry_integrity_and_value_groups(self):
        meshes = art.geometry()
        self.assertEqual(meshes, art.geometry(), 'Recipe is deterministic')
        self.assertEqual(len({m['name'] for m in meshes}), len(meshes))
        self.assertEqual(sum('Vertebral rib' in m['name'] for m in meshes), 6)
        self.assertEqual(sum('Forearm broad wrap' in m['name'] for m in meshes), 9)
        self.assertEqual(sum('Glove curled finger' in m['name'] for m in meshes), 4)
        for mesh in meshes:
            self.assertIn(mesh['material'], art.PALETTE)
            vertices = mesh['vertices']
            for point in vertices:
                self.assertTrue(all(math.isfinite(v) for v in point))
            for face in mesh['faces']:
                self.assertGreaterEqual(len(set(face)), 3)
                self.assertTrue(all(0 <= i < len(vertices) for i in face))
                a, b, c = (vertices[i] for i in face[:3])
                normal = art.cross(tuple(y-x for x, y in zip(a, b)), tuple(y-x for x, y in zip(a, c)))
                self.assertGreater(sum(n*n for n in normal), 1e-10)
        for material, threshold, relation in [('bone_edge', .7, 'above'), ('glove', .25, 'below'), ('brass', .5, 'below')]:
            rgb = art.PALETTE[material][0]
            value = sum(int(rgb[i:i+2], 16) for i in (1, 3, 5))/765
            self.assertTrue(value > threshold if relation == 'above' else value < threshold)
        self.assertFalse(any('flash' in m['name'].lower() or 'smoke' in m['name'].lower() for m in meshes))

    def test_framing_and_same_muzzle_camera(self):
        meshes = art.geometry()
        self.assertEqual(art.FRAMES, ('idle', 'fire', 'recover'))
        posed = []
        for frame in range(3):
            points = [art.pose_point(v, frame) for m in meshes for v in m['vertices']]
            posed.append(points)
            self.assertEqual(art.pose_point(art.MUZZLE, frame), art.MUZZLE)
            self.assertGreaterEqual(min(v[0] for v in points), 90)
            self.assertLessEqual(max(v[0] for v in points), 318)
            self.assertGreaterEqual(min(v[1] for v in points), 45)
            self.assertGreater(max(v[1] for v in points), 200, 'Wrist exits lower edge in every pose')
            # Verify the exact native Y-axis rotation, including its sign.
            for point in (art.MUZZLE, (270, 192, 3)):
                p, pivot = art.world(point), art.world(art.MUZZLE)
                dx, dz = p[0]-pivot[0], p[2]-pivot[2]
                c, s = math.cos(math.radians(art.ROLL[frame])), math.sin(math.radians(art.ROLL[frame]))
                native = (pivot[0]+c*dx+s*dz, p[1], pivot[2]-s*dx+c*dz)
                expected = art.world(art.pose_point(point, frame))
                for a, b in zip(native, expected):
                    self.assertAlmostEqual(a, b)
        self.assertEqual(len({tuple(p) for p in posed}), 3)
        receiver = next(m for m in meshes if m['name'] == 'Receiver dark mass')['vertices']
        self.assertGreater(max(v[1] for v in receiver)-min(v[1] for v in receiver), 45)
        self.assertGreater(max(v[2] for v in receiver)-min(v[2] for v in receiver), 25)

    def test_output_boundary_and_no_overwrite(self):
        # Fixtures stay within the owned candidate tests, never prior receipts.
        owned = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory(dir=owned) as name:
            root = Path(name).resolve()
            fresh = root/'new-native-output'
            self.assertEqual(art.fresh_output(fresh, root), fresh)
            for bad in (root, root.parent/'escape', Path('relative'), root/'../alias'):
                with self.assertRaises(ValueError):
                    art.fresh_output(bad, root)
            fresh.mkdir()
            with self.assertRaises(ValueError):
                art.fresh_output(fresh, root)
            alias = root/'alias'
            alias.symlink_to(fresh, target_is_directory=True)
            with self.assertRaises(ValueError):
                art.fresh_output(alias/'new', root)


if __name__ == '__main__':
    unittest.main()
