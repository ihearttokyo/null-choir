"""Portable source/RGBA regression checks for the integrated Nursery region.

Run from the repository or this private preparation folder. No Godot/native work.
"""
from pathlib import Path
from collections import deque
import hashlib
import json
import re
import unittest

from PIL import Image


def repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "game/scripts/enemy.gd").is_file() and (parent / "game/assets/art/regions/nursery-warden-node-v1.json").is_file():
            return parent
    raise RuntimeError("Could not locate canonical publication root from test path")


ROOT = repo_root()
LOCAL_PACKET = Path(__file__).resolve().parents[1]
LIVE_FIXTURE = ROOT / "game/tests/test_warden_live_pressure.gd"
if not LIVE_FIXTURE.is_file():
    LIVE_FIXTURE = LOCAL_PACKET / "game/tests/test_warden_live_pressure.gd"
MANIFEST_PATH = ROOT / "game/assets/art/regions/nursery-warden-node-v1.json"
ATLAS_PATH = ROOT / "game/assets/art/sprites/bodies-v1/nursery_warden.png"
SOURCE_FRAME = ROOT / "source/art/bodies-v1/nursery_warden/frames/raw-attack-00.png"
SOURCE_BLEND = ROOT / "source/art/bodies-v1/nursery_warden/nursery_warden.blend"
MANIFEST = json.loads(MANIFEST_PATH.read_text())


def connected_amber_components(image: Image.Image):
    remaining = set()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if a >= 128 and r * 100 > g * 115 and g * 100 > b * 115 and r > 140 and g > 120 and b < 110:
                remaining.add((x, y))
    components = []
    while remaining:
        seed = min(remaining, key=lambda point: (point[1], point[0]))
        remaining.remove(seed)
        component = {seed}
        queue = deque([seed])
        while queue:
            x, y = queue.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    point = (x + dx, y + dy)
                    if point in remaining:
                        remaining.remove(point)
                        component.add(point)
                        queue.append(point)
        components.append(component)
    return sorted(components, key=lambda comp: (-len(comp), min(y for x, y in comp), min(x for x, y in comp)))


def manifest_mask():
    spec = MANIFEST["mask"]
    points = set()
    for y, x0, x1 in spec["runs_y_x0_x1"]:
        points.update((x, y) for x in range(x0, x1))
    return points


class WardenPressureRegionSourceTests(unittest.TestCase):
    def test_encoded_and_decoded_art_pins_match_integrated_manifest(self):
        atlas_bytes = ATLAS_PATH.read_bytes()
        raw_bytes = SOURCE_FRAME.read_bytes()
        self.assertEqual(hashlib.sha256(atlas_bytes).hexdigest(), MANIFEST["runtime_atlas_png_sha256"])
        self.assertEqual(hashlib.sha256(SOURCE_BLEND.read_bytes()).hexdigest(), MANIFEST["source_blend_sha256"])
        atlas = Image.open(ATLAS_PATH).convert("RGBA")
        raw = Image.open(SOURCE_FRAME).convert("RGBA")
        self.assertEqual(atlas.size, (2048, 1280))
        self.assertEqual(raw.size, (256, 256))
        self.assertEqual(hashlib.sha256(atlas.tobytes()).hexdigest(), MANIFEST["runtime_atlas_rgba_sha256"])
        self.assertEqual(hashlib.sha256(raw_bytes).hexdigest(), MANIFEST["source_frame_png_sha256"])
        self.assertEqual(hashlib.sha256(raw.tobytes()).hexdigest(), MANIFEST["source_frame_rgba_sha256"])
        frame = MANIFEST["runtime_frame"]
        self.assertEqual((frame["pose"], frame["pose_row"], frame["direction"], frame["atlas_frame"]), ("attack", 3, 0, 24))
        self.assertEqual(frame["atlas_cell_origin_xy"], [0, 768])
        cell = atlas.crop((0, 768, 256, 1024))
        self.assertEqual(hashlib.sha256(cell.tobytes()).hexdigest(), frame["rgba_sha256"])
        self.assertFalse(frame["equals_source_frame_rgba"])
        self.assertNotEqual(cell.tobytes(), raw.tobytes())

    def test_rle_equals_unique_largest_opaque_amber_component(self):
        atlas = Image.open(ATLAS_PATH).convert("RGBA")
        cell = atlas.crop((0, 768, 256, 1024))
        components = connected_amber_components(cell)
        self.assertEqual(len(components[0]), 234)
        self.assertEqual(len(components[1]), 216)
        self.assertGreater(len(components[0]), len(components[1]))
        points = manifest_mask()
        self.assertEqual(points, components[0])
        mask_bytes = bytearray(256 * 256)
        for x, y in points:
            mask_bytes[y * 256 + x] = 1
            self.assertGreaterEqual(cell.getpixel((x, y))[3], 128)
        self.assertEqual(len(points), MANIFEST["mask"]["pixel_count"])
        self.assertEqual(hashlib.sha256(mask_bytes).hexdigest(), MANIFEST["mask"]["mask_sha256"])
        self.assertEqual(len(MANIFEST["mask"]["runs_y_x0_x1"]), 53)
        self.assertEqual(MANIFEST["mask"]["bounds_xyxy_half_open"], [125, 142, 142, 167])

    def test_opaque_in_envelope_negative_is_not_rectangle_fill(self):
        atlas = Image.open(ATLAS_PATH).convert("RGBA")
        cell = atlas.crop((0, 768, 256, 1024))
        points = manifest_mask()
        x0, y0, x1, y1 = MANIFEST["mask"]["bounds_xyxy_half_open"]
        self.assertLess(len(points), (x1 - x0) * (y1 - y0) * 0.75)
        witness = (125, 142)
        self.assertTrue(x0 <= witness[0] < x1 and y0 <= witness[1] < y1)
        self.assertNotIn(witness, points)
        self.assertEqual(cell.getpixel(witness), (144, 104, 88, 255))
        self.assertNotIn((0, 0), points)
        self.assertLess(cell.getpixel((0, 0))[3], 128)

    def test_runtime_helper_and_native_test_bind_actual_attack_cell(self):
        helper = (ROOT / "game/scripts/warden_pressure_window.gd").read_text()
        for contract in (
            'const ATLAS_PATH := "res://assets/art/sprites/bodies-v1/nursery_warden.png"',
            "const FRAME := 24",
            "const RUNTIME_FRAME_RGBA_SHA256 :=",
            "const MASK_SHA256 :=",
            'contact.get("coverage") != "visible_sprite"',
            'contact.get("collider_id") != actor_id',
            "contact.get(\"sprite_frame\") != FRAME",
            'telegraph_time <= 0 or committed_variant != 0',
            "source != player",
            "shot_tick != physics_tick",
            "last_shot_sequence(weapon) != shot_sequence",
        ):
            self.assertIn(contract, helper)
        gd = LIVE_FIXTURE.read_text()
        self.assertIn('load_level(4)', gd)
        self.assertIn('spec.get("id") == WARDEN_ID and spec.get("kind") == WARDEN_ID', gd)
        self.assertIn("warden.configure(game,spec)", gd)
        self.assertIn("_await_normal_window(warden,player)", gd)
        self.assertIn("player.fire()", gd)
        self.assertIn("hp_before-warden.hp == expected_damage", gd)
        self.assertIn("OPAQUE_NON_NODE_PIXEL", gd)
        self.assertIn("contact.get(\"collider\") == wall", gd)
        # The fixture may observe production state, but must not manufacture a weakpoint window.
        for forbidden in (r"warden\.telegraph_time\s*=(?!=)", r"warden\._committed_variant\s*=(?!=)", r"warden\.sprite\.frame\s*=(?!=)", r"warden\.target\s*=(?!=)"):
            self.assertNotRegex(gd, forbidden)

    def test_live_fixture_uses_actual_combat_visual_state_phase_api(self):
        enemy = (ROOT / "game/scripts/enemy.gd").read_text()
        visual_state = re.search(r"(?ms)^func combat_visual_state\(\).*?(?=^func )", enemy)
        self.assertIsNotNone(visual_state, "the assertion is bound to the actual production Enemy API")
        source_api = visual_state.group(0)
        self.assertRegex(source_api, r'return \{"phase":stage,')
        self.assertNotRegex(source_api, r'"stage"\s*:')
        gd = LIVE_FIXTURE.read_text()
        self.assertIn('warden.combat_visual_state().get("phase") == "windup"', gd)

    def test_snapshot_and_existing_worker_clutch_source_contract_remain_separate(self):
        enemy = (ROOT / "game/scripts/enemy.gd").read_text()
        snapshot = re.search(r"(?ms)^func snapshot\(\).*?(?=^func )", enemy).group(0)
        worker = re.search(r"(?ms)^func _try_worker_clutch\(.*?(?=^func )", enemy).group(0)
        self.assertIn('return {"id":id,"hp":hp,"position":[position.x,position.y,position.z],"yaw":canonical_yaw(rotation.y),"alerted":alerted}', snapshot)
        self.assertEqual(hashlib.sha256(worker.encode()).hexdigest(), "b2f62ea4daf9b1a2270cfc6675dd0bfca015627b291252fc315cef1943b99f96")
        self.assertNotIn("WardenPressureWindow", worker)
        self.assertIn('if kind != "worker"', worker)
        self.assertIn("WorkerHitRegions.region", worker)


if __name__ == "__main__":
    unittest.main()
