"""Pure exterior-envelope fixture contract; actual Godot ray/mutation tests unrun."""
import ast
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ExteriorContactContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / 'game/tests/test_floor_wall_contacts.gd').read_text()

    def test_independent_two_metre_limit_covers_but_does_not_copy_profiles(self):
        self.assertIn('const OUTWARD_LIMIT = 2.0', self.source)
        code = '\n'.join(line.split('#', 1)[0] for line in self.source.splitlines())
        self.assertNotIn('WallArchitecture.', code)
        wall = (ROOT / 'game/scripts/wall_architecture.gd').read_text()
        families = ast.literal_eval(wall.split('const FAMILIES = ', 1)[1].split('\nconst FACES', 1)[0])
        self.assertEqual(len(families), 8)
        self.assertLessEqual(max(f['depth'] + .18 for f in families.values()), 1.58 + 1e-9)
        self.assertLess(max(f['depth'] + .18 for f in families.values()), 2.0)

    def test_all_boundary_cells_lateral_samples_heights_and_counts_retained(self):
        for term in ['for cell in level.layout.tiles:',
                     'for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:',
                     'if level.layout.is_walkable(cell+direction): continue',
                     'for u in [.1,.5,.9]:',
                     'for offset in [.02,level.layout.roof_height(cell)-.02]:', 'queries += 1',
                     'failures.append(', 'queries>0 and failures.is_empty() and missing_backing_refused']:
            self.assertIn(term, self.source)
        self.assertEqual(self.source.count('queries += 1'), 1)
        data = json.loads((ROOT / 'game/data/01_intake.json').read_text())
        cells = {(x,z) for a,b,c,d in data['rects'] for x in range(a,c+1) for z in range(b,d+1)}
        edges = sum((x+dx,z+dz) not in cells for x,z in cells for dx,dz in [(-1,0),(1,0),(0,-1),(0,1)])
        self.assertEqual(edges * 3 * 2, 1260)

    def test_floor_seam_first_and_no_retry_past_wrong_hit(self):
        ray = self.source.split('func wall_ray(', 1)[1].split('func owned_wall_hit', 1)[0]
        self.assertIn('PhysicsRayQueryParameters3D.create(start,seam,1)', ray)
        self.assertIn('if not hit.is_empty(): return hit', ray)
        self.assertIn('PhysicsRayQueryParameters3D.create(seam,end,1)', ray)
        self.assertLess(ray.index('if not hit.is_empty(): return hit'), ray.index('create(seam,end,1)'))
        for term in ['var start = inside+Vector3.UP*offset', 'var seam = point+Vector3.UP*offset',
                     'var end = seam+outward*OUTWARD_LIMIT', 'if not owned_wall_hit(level,hit):']:
            self.assertIn(term, self.source)
        owned = self.source.split('func owned_wall_hit', 1)[1].split('func missing_backing_control', 1)[0]
        for term in ['not hit.is_empty()', 'hit.collider is StaticBody3D',
                     'hit.collider.get_parent() == level', 'begins_with("WallArchitecture_")']:
            self.assertIn(term, owned)

    def test_actual_missing_backing_mutates_only_fixture_shape_and_restores_it(self):
        negative = self.source.split('func missing_backing_control', 1)[1]
        for term in ['layout.world_position([4.0,7.5])', 'Vector3.LEFT',
                     'layout.roof_height(Vector2i(4,7))-.02', 'original.get_faces()',
                     'depth < .2 or depth > OUTWARD_LIMIT or absf(local.z)>2.001',
                     'ConcavePolygonShape3D.new()', 'open_shape.set_faces(retained)',
                     'collider.shape = open_shape', 'var open_exterior: bool = open_hit.is_empty()',
                     'collider.shape = original', 'return open_exterior and restored']:
            self.assertIn(term, negative)
        mutation = negative.split('collider.shape = open_shape', 1)[1].split('collider.shape = original', 1)[0]
        self.assertEqual(mutation.count('await physics_frame'), 2)
        self.assertNotIn('return ', mutation)
        self.assertNotIn('set_faces(', mutation)  # Original resource is never rewritten.
        self.assertNotIn('original.set_faces', negative)
        self.assertIn('if index == 0: missing_backing_refused = await missing_backing_control', self.source)

    def test_old_planar_counterexample_is_a_gap_not_exterior_leak(self):
        # Known Intake centre u=.5: original +/-0.2 ray cannot reach .94 backing.
        rib_centres = [-2 + i * 4 / 7 for i in range(1, 7)]
        self.assertTrue(all(abs(x) > .06 for x in rib_centres))
        self.assertGreater(.94, .2)
        self.assertLess(.94 + .18, 2.0)
        self.assertGreater(7 - .16, 5.98)  # Global closure floor4+3, not local roof6.


if __name__ == '__main__':
    unittest.main()
