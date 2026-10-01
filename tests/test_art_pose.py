"""Blender regression: each authored pose must leave earlier poses unchanged."""
from pathlib import Path
import runpy

art = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/build_art.py'))
bpy = art['bpy']

for kind in ('worker', 'crawler'):
    art['setup']()
    earlier = {}
    for pose in art['FRAMES']:
        art[kind](pose)
        for obj, transform in earlier.items():
            assert (tuple(obj.location), tuple(obj.scale), tuple(obj.rotation_euler)) == transform, (kind, pose, obj.name, 'mutated earlier pose')
        earlier = {obj: (tuple(obj.location), tuple(obj.scale), tuple(obj.rotation_euler))
                   for obj in bpy.context.scene.objects if obj.type == 'MESH'}
    assert earlier
print('PASS isolated authored poses: idle, stride, attack and death never mutate preceding geometry')
