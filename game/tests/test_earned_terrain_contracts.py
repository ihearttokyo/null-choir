"""Source-only floor maths. Not native collision, physics, or campaign evidence."""
import json
import math
from pathlib import Path
import re
import unittest

GAME = Path(__file__).resolve().parents[1]
CASES = [
    (3, 'test_reliquary_earned_entry.gd', 'R_ACTORS', 'R_CURRENT_FLOORS', 3, 4, 5),
    (4, 'test_nursery_earned_entry.gd', 'N_ACTORS', 'N_CURRENT_FLOORS', 2, 3, 4),
    (5, 'test_nursery_finale_loop.gd', 'NF_O_ACTORS', 'NF_O_CURRENT_FLOORS', 2, 3, 4),
]


def literal(source, name):
    return json.JSONDecoder().raw_decode(source.split('const '+name+' = ', 1)[1])[0]


def floor_y(data, x, z):
    def corner(x, z):
        for region in data['elevations']:
            a, b, c, d = region['rect']
            if a <= x <= c and b <= z <= d:
                if 'axis' in region:
                    return max(0, min(1, ([x, z][region['axis']]-region['start']) /
                                      (region['end']-region['start']))) * region['height']
                return region['height']
        return 0
    tx, tz = math.floor(x), math.floor(z)
    u, v = x-tx, z-tz
    a, b, c, d = corner(tx, tz), corner(tx+1, tz), corner(tx+1, tz+1), corner(tx, tz+1)
    return a+(b-a)*u+(c-b)*v if v <= u else a+(c-d)*u+(d-a)*v


class EarnedFloorContracts(unittest.TestCase):
    def test_intake_upper_ivory_is_current_three_original_two(self):
        current = json.loads((GAME/'data/01_intake.json').read_text())
        originals = literal((GAME/'scripts/floors_v0.gd').read_text(), 'LEVELS')
        self.assertEqual(floor_y(current, 22.5, 12.5), 3.0)
        self.assertEqual(floor_y(originals[0], 22.5, 12.5), 2.0)
        source = (GAME/'tests/test_intake_complete_walk.gd').read_text()
        expected = re.search(r'layout.world_position\(\[22.5,12.5\]\).y == ([\d.]+)', source)
        self.assertEqual(float(expected[1]), 3.0, 'retained current Intake assertion is stale')
        self.assertIn('original_floor(0).world_position([22.5,12.5]).y == 2.0', source)

    def test_independent_actor_heights_and_immutable_originals(self):
        originals = literal((GAME/'scripts/floors_v0.gd').read_text(), 'LEVELS')
        maps = sorted((GAME/'data').glob('0*.json'))
        for index, file, actors, heights, ix, iz, iy in CASES:
            with self.subTest(file=file):
                source = (GAME/'tests'/file).read_text()
                rows = literal(source, actors)
                current = literal(source, heights)
                data = json.loads(maps[index].read_text())
                self.assertEqual(len(rows), len(current))
                for row, height in zip(rows, current):
                    self.assertAlmostEqual(row[iy], floor_y(originals[index], row[ix], row[iz]), places=6, msg=row[0]+' original')
                    self.assertAlmostEqual(height, floor_y(data, row[ix], row[iz]), places=6, msg=row[0]+' current')
                self.assertIn('original_floor('+str(index)+')', source)
                self.assertIn(heights+'[index]', source)

    def test_live_chain_envelopes_label_current_terrain(self):
        sources = {p.name: p.read_text() for p in (GAME/'tests').glob('*.gd')}
        names = {'test_ossuary_finale_exit.gd'}
        while True:
            dependencies = names | {dep for name in names for dep in
                re.findall(r'res://tests/([^"\n]+\.gd)', sources[name]) if dep in sources}
            if dependencies == names:
                break
            names = dependencies
        for path in (GAME/'data').glob('0*.json'):
            self.assertEqual(json.loads(path.read_text())['floor_revision'], 1)
        self.assertIn('const TERRAIN_VERSION = 2', (GAME/'scripts/campaign.gd').read_text())
        for name in names:
            source = (GAME/'tests'/name).read_text()
            for line in source.splitlines():
                if '"version":' in line:
                    self.assertIn('"version":2', line, name+' wrong current save version')
                if '"checkpoint_id":' in line:
                    self.assertIn('"floor_revision":1', line, name+' unlabelled current resource envelope')

    def test_legacy_route_maths_uses_original_floor(self):
        for file in ['test_reliquary_halo_feasibility.gd', 'test_reliquary_blood_story.gd']:
            source = (GAME/'tests'/file).read_text()
            self.assertIn('original_floor(3).world_position(cell).y-floor_y', source)
        # Explicitly exercise both triangles and the historical ramp separately.
        original = literal((GAME/'scripts/floors_v0.gd').read_text(), 'LEVELS')[3]
        self.assertEqual(floor_y(original, 9.5, 24.5), -0.75)
        self.assertEqual(floor_y(original, 9.25, 24.75), -0.625)


if __name__ == '__main__':
    unittest.main()
