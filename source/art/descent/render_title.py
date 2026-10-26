"""Render a compact title candidate from the frozen editable Heart74 scene."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE / "heart74"))
import producer

def main():
    import bpy
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    output = args.output.resolve()
    receipt = output.with_suffix(".json")
    if output.exists() or receipt.exists() or not output.parent.is_dir():
        raise ValueError("Fresh PNG/receipt in an existing authoring directory required")
    started = time.monotonic()
    directory, blend, scene = producer.open_native("build01")
    before = producer.sha(blend)
    producer.set_view(scene, producer.make_plan(), "title")
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True, scene=scene.name)
    assert producer.sha(blend) == before
    receipt.write_text(json.dumps({"kind":"compact native Blender title candidate, NOT8Kmaster", "width":1280,"height":720,"samples":64,"cpu_threads":2,"seconds":round(time.monotonic()-started,3),"blend_sha256":before,"blend_unchanged":True,"png_sha256":producer.sha(output),"view":"title","quality":"Final rendered UI/visual acceptance remains open"}, indent=2) + "\n")
    print("PASS compact native title render; frozen source unchanged; not8Kmaster")

if __name__ == "__main__":
    main()
