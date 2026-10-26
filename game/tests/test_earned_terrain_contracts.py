"""Source-only floor maths. Not native collision, physics, or campaign evidence."""
import hashlib
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

    def test_legacy_chain_envelopes_keep_revision_one_identity(self):
        sources = {p.name: p.read_text() for p in (GAME/'tests').glob('*.gd')}
        names = {'test_ossuary_finale_exit.gd'}
        while True:
            dependencies = names | {dep for name in names for dep in
                re.findall(r'res://tests/([^"\n]+\.gd)', sources[name]) if dep in sources}
            if dependencies == names:
                break
            names = dependencies
        # This authenticated chain remains historical v1 evidence. Current v2
        # maps and their immutable v1 migration sources are checked separately.
        self.assertIn('const TERRAIN_VERSION = 2', (GAME/'scripts/campaign.gd').read_text())
        for name in names:
            source = (GAME/'tests'/name).read_text()
            for line in source.splitlines():
                if '"version":' in line:
                    self.assertIn('"version":2', line, name+' wrong historical save-format version')
                if '"checkpoint_id":' in line:
                    self.assertIn('"floor_revision":1', line, name+' changed historical revision-one resource envelope')

    def test_current_revision_two_retains_all_eight_exact_v1_sources(self):
        fixture_names = [
            'intake_revision1', 'foundry_revision1',
            'processional_choir_walk_revision1', 'reliquary_archive_rim_revision1',
            'nursery_revision1', 'ossuary_revision1',
            'terminal_crossings_revision1', 'terminal_crossings_revision1',
        ]
        maps = sorted((GAME/'data').glob('0*.json'))
        self.assertEqual(len(maps), 8)
        constants = (GAME/'scripts/floors_v1.gd').read_text()
        for index, path in enumerate(maps):
            with self.subTest(map=path.name):
                current = json.loads(path.read_text())
                self.assertEqual(current['floor_revision'], 2)
                fixture = GAME/'tests/fixtures'/fixture_names[index]
                frozen_bytes = (fixture/path.name).read_bytes()
                manifest = dict((name, digest) for digest, name in
                                (line.split('  ') for line in
                                 (fixture/'SHA256SUMS.txt').read_text().splitlines()))
                self.assertEqual(hashlib.sha256(frozen_bytes).hexdigest(), manifest[path.name])
                frozen = json.loads(frozen_bytes)
                prior = (literal(constants, 'INTAKE' if index == 0 else 'FOUNDRY')
                         if index < 2 else json.loads(
                             (GAME/'data/floors/revision1'/(current['id']+'.json')).read_text()))
                self.assertEqual(frozen['floor_revision'], 1)
                for field in ['cell_size', 'rects', 'elevations', 'ceilings', 'floor_revision']:
                    self.assertEqual(prior[field], frozen[field], path.name+' '+field)
                # Terrain migration must not alter earned resource/gate identities.
                for field in ['enemies', 'heroes', 'pickups', 'interactions', 'doors',
                              'encounters', 'spawn', 'spawn_yaw', 'mission']:
                    self.assertEqual(current[field], frozen[field], path.name+' '+field)

    def test_earned_map_sha_pins_still_bind_original_revision_one_bytes(self):
        references = [
            ('test_foundry_earned_walk.gd', 'F_MAP_SHA', 'foundry_revision1/02_foundry.json'),
            ('test_processional_earned_entry.gd', 'P_MAP_SHA',
             'processional_choir_walk_revision1/03_processional.json'),
            ('test_reliquary_earned_entry.gd', 'R_MAP_SHA',
             'reliquary_archive_rim_revision1/04_reliquary.json'),
            ('test_nursery_earned_entry.gd', 'N_MAP_SHA', 'nursery_revision1/05_nursery.json'),
            ('test_nursery_finale_loop.gd', 'NF_OSSUARY_SHA', 'ossuary_revision1/06_ossuary.json'),
        ]
        for file, constant, frozen_path in references:
            with self.subTest(source=file):
                old_pin = literal((GAME/'tests'/file).read_text(), constant)
                self.assertEqual(old_pin, hashlib.sha256(
                    (GAME/'tests/fixtures'/frozen_path).read_bytes()).hexdigest())
        pins = literal((GAME/'tests/test_inversion_earned_entry.gd').read_text(), 'INVERSION_PINS')
        self.assertEqual(pins['res://data/07_inversion.json'], hashlib.sha256(
            (GAME/'tests/fixtures/terminal_crossings_revision1/07_inversion.json').read_bytes()).hexdigest())

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
