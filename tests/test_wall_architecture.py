"""Pure authored-profile/map bounds, not a native physics or visual acceptance claim."""
import ast
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'game/scripts/wall_architecture.gd').read_text()
FAMILIES = ast.literal_eval(SOURCE.split('const FAMILIES = ', 1)[1].split('\nconst FACES', 1)[0])

def profile(chapter, height=6.0, size=4.0, variant=0):
    """Evaluate the source's literal profile data and explicitly tested scaling rule."""
    family = FAMILIES[chapter]
    depth = family['depth']
    parts = [[-2, 2, 0, height, depth, depth + .18, 0, 'solid_backing'],
             [-2, 2, 0, min(1.05, height), -.10, depth, 0, 'continuous_plinth'],
             [-2, -1.8, 0, height, -.10, depth, 1, 'structural_return'],
             [1.8, 2, 0, height, -.10, depth, 1, 'structural_return'],
             [-2, 2, max(0, height - .16), height, -.10, depth, 1, 'roof_return']]
    for entry in family['parts']:
        p = entry.copy()
        if variant % 2:
            p[0], p[1] = -p[1], -p[0]
            if len(p) > 8:
                p[8] = -p[8]
        p[2], p[3] = min(p[2], height), min(p[3], height)
        if p[3] > p[2]:
            parts.append(p)
    count = math.ceil(size / .60)
    for i in range(1, count):
        x = -size / 2 + i * size / count
        parts.append([(x - .06) * 4 / size, (x + .06) * 4 / size,
                      0, height, -.1, depth, 1, 'solid_aperture_rib'])
    for p in parts:
        p[0] *= size / 4
        p[1] *= size / 4
        if len(p) > 8:
            p[8] *= size / 4
    return parts

class WallArchitectureTests(unittest.TestCase):
    def test_eight_structurally_distinct_families(self):
        self.assertEqual(set(FAMILIES), {'intake', 'foundry', 'processional', 'reliquary',
                                        'nursery', 'ossuary', 'inversion', 'heart'})
        self.assertEqual(len({f['name'] for f in FAMILIES.values()}), 8)
        # Ignore materials/names: these must be genuinely different 3D shapes.
        self.assertEqual(len({str([p[:6] + p[8:] for p in f['parts']])
                              for f in FAMILIES.values()}), 8)
        self.assertTrue(all(f['depth'] >= .94 and len(f['parts']) >= 5 for f in FAMILIES.values()))

    def test_all_parts_contained_in_legacy_inward_envelope(self):
        for chapter in FAMILIES:
            for size in (2.0, 4.0, 6.0):
                for height in (6.0, 14.0, 30.0):
                    for variant in (0, 1):
                        for p in profile(chapter, height, size, variant):
                            lean = p[8] if len(p) > 8 else 0
                            with self.subTest(chapter=chapter, part=p[7]):
                                self.assertGreater(p[1], p[0])
                                self.assertGreater(p[3], p[2])
                                self.assertGreater(p[5], p[4])
                                self.assertGreaterEqual(min(p[0], p[0] + lean), -size / 2 - 1e-9)
                                self.assertLessEqual(max(p[1], p[1] + lean), size / 2 + 1e-9)
                                self.assertGreaterEqual(p[4], -.12)
                                self.assertLess(p[5], size) # Never reaches next exterior cell.
                                self.assertGreaterEqual(p[2], 0)
                                self.assertLessEqual(p[3], height)

    def test_real_full_height_apertures_block_capsule_even_above_sill(self):
        for chapter in FAMILIES:
            for size in (2.0, 4.0, 6.0):
                parts = profile(chapter, 30, size)
                bars = [p for p in parts if p[7] in ('solid_aperture_rib', 'structural_return')]
                intervals = sorted((p[0], p[1]) for p in bars)
                gaps = [b[0] - a[1] for a, b in zip(intervals, intervals[1:])]
                self.assertLessEqual(max(gaps), .48 + 1e-9)
                self.assertLess(max(gaps), .64)
                self.assertTrue(all(p[2] == 0 and p[3] == 30 and p[4] == -.1 for p in bars))
                # A horizontal player capsule cannot have its center outside the
                # floor: even at d=0 the nearest visible rib intersects radius .32.
                self.assertLess(math.hypot(max(gaps) / 2, .10), .32)

    def test_each_map_uses_only_nonwalkable_boundaries_and_bounded_batches(self):
        for path in sorted((ROOT / 'game/data').glob('0*.json')):
            data = json.loads(path.read_text())
            cells = {(x, z) for x0, z0, x1, z1 in data['rects']
                     for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)}
            edges = [(x, z, dx, dz) for x, z in cells for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
                     if (x + dx, z + dz) not in cells]
            self.assertGreater(len(edges), 0)
            # Actual source guard, not an assumption about map authoring.
            self.assertIn('if layout.is_walkable(cell+direction): continue', SOURCE)
            parts = profile(data['id'])
            self.assertLess(len(edges) * len(parts) * 36, 1_500_000)
            chunks = {(x // 4, z // 4) for x, z, _, _ in edges}
            self.assertLess(len(chunks) * 5 + len(edges), len(edges) * 5)
            self.assertGreaterEqual(len(data['loops']), 2)

    def test_same_triangles_for_visible_mesh_and_collision_no_front_occlusion(self):
        self.assertIn('tool.add_vertex(vertices[index])\n\t\t\ttriangles.append(vertices[index])', SOURCE)
        self.assertIn('shape.set_faces(chunks[key].triangles)', SOURCE)
        self.assertIn('var back: Array = parts[0]', SOURCE)
        self.assertIn('RecessedWallBacking', SOURCE)
        self.assertNotIn('create_trimesh_collision', SOURCE) # No different proxy mesh.
        self.assertIn('_highest_support(layout)+3.0', SOURCE)
        self.assertIn('layout.surface_faces()', SOURCE)
        self.assertIn('for door in layout.data.doors', SOURCE)
        self.assertIn('for support in spec.get("supports",[])', SOURCE)

    def test_floor_and_gate_paths_preserved_overlay_removed(self):
        level = (ROOT / 'game/scripts/level.gd').read_text()
        self.assertIn('WallArchitecture.build(self,layout,wall_material)', level)
        self.assertNotIn('_place_model("ribbed_wall"', level)
        self.assertNotIn('var wall = _box(dimensions', level)
        self.assertIn('func _build_gate(spec: Dictionary)', level)
        self.assertIn('floor_bodies.append(mesh.get_child(0))', level)
        self.assertIn('func _build_surface_patch(bank_material: Material)', level)
        self.assertIn('if layout.is_walkable(cell+direction) and tall >', level)

if __name__ == '__main__':
    unittest.main()
