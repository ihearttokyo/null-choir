"""Engine-free structural checks; rendered fidelity remains a native gate."""
import importlib.util
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1] / 'tools'


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


recipe = load('nursery_refinement', 'build_nursery_gestation_v2.py')


def first_surface(part, x, z):
    origin = (x, -2, z)
    depths = []
    for ia, ib, ic in recipe.triangles(part):
        a, b, c = [part.vertices[i] for i in (ia, ib, ic)]
        e1, e2 = recipe.sub(b, a), recipe.sub(c, a)
        h = recipe.cross((0, 1, 0), e2)
        det = recipe.dot(e1, h)
        if abs(det) < 1e-10:
            continue
        s = recipe.sub(origin, a)
        u = recipe.dot(s, h) / det
        q = recipe.cross(s, e1)
        v = q[1] / det
        t = recipe.dot(e2, q) / det
        if 0 <= u <= 1 and 0 <= v and u + v <= 1 and t > 0:
            depths.append(origin[1] + t)
    return min(depths) if depths else float('inf')


class CraniumGeometry(unittest.TestCase):
    def test_finite_nondegenerate_closed_geometry(self):
        report = recipe.geometry_report(recipe.build_parts())
        self.assertLessEqual(report['triangles'], 20000)
        self.assertEqual(report['groups'], 5)
        head = recipe.cranial_vault()
        edges = {}
        for face in head.faces:
            for a, b in zip(face, face[1:] + face[:1]):
                key = tuple(sorted((a, b)))
                edges.setdefault(key, []).append((a, b))
        self.assertTrue(all(len(uses) == 2 for uses in edges.values()))
        self.assertTrue(all(uses[0] == tuple(reversed(uses[1])) for uses in edges.values()))

    def test_rounded_case_and_separate_recessed_orbits(self):
        head = recipe.cranial_vault()
        case = [v for v in head.vertices if 6.4 < v[2] < 6.8]
        self.assertGreater(max(v[1] for v in case) - min(v[1] for v in case), .65)
        self.assertGreater(max(v[0] for v in case) - min(v[0] for v in case), .73)
        self.assertLess(first_surface(head, 0, 6.35), -.20)
        self.assertGreater(first_surface(head, -.18, 6.28), -.08)
        self.assertGreater(first_surface(head, .18, 6.37), -.08)



if __name__ == '__main__':
    unittest.main()
