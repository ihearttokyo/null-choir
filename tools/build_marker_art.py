"""Image-derived marker sources. HELD: one background CPU asset per cleared run."""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_art as art

ROOT = Path(__file__).resolve().parents[1]
IDS = tuple('marker_' + kind for kind in
            ('ammo', 'health', 'armor', 'key', 'weapon', 'story', 'checkpoint', 'exit'))
REFERENCE = 'source/art/references/marker-system-01.png'
REFERENCE_SHA = '59c2b0db1374acfc9ab75b6978ad14df2d965c3eedd86fe8d8227db4e0895a42'
RECIPE = 'tools/build_marker_art.py'


def plate(name, outline, depth, mat='bone'):
    """Extruded XZ outline; a named editable mass, not a filled screen icon."""
    # Positive XZ winding gives the front (-Y) face its outward normal.
    if sum(x * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * z
           for i, (x, z) in enumerate(outline)) < 0:
        outline = list(reversed(outline))
    n = len(outline)
    verts = [(x, y, z) for y in (-depth / 2, depth / 2) for x, z in outline]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i + n, (i + 1) % n + n, (i + 1) % n, i) for i in range(n)]
    return art.mesh(name, verts, faces, mat)


def base(width=.66, depth=.28):
    art.box('Ground-centered iron manifold', (0, 0, .06), (width, depth, .12), 'iron', .01)
    for side in (-1, 1):
        art.box(f'Ivory mounting foot {side}', (side * (width / 2 - .06), -.015, .035), (.12, depth + .04, .07), 'bone', .01)


def ammo():
    base(.72)
    for i, (x, height) in enumerate(((-.23, .85), (0, 1.02), (.23, .79))):
        lean = x * .12
        art.tube(f'Cartridge pressure shell {i}', [(x, -.025, .13), (x, -.025, .37)], .098, 'iron', 8)
        art.tube(f'Amber cartridge window {i}', [(x, -.025, .36), (x + lean, -.025, height - .19)], .076, 'amber', 8)
        art.tube(f'Cartridge rear support {i}', [(x, .065, .30), (x + lean, .065, height - .12)], .025, 'iron', 6)
        art.tube(f'Iron upper cartridge housing {i}', [(x + lean, -.025, height - .205), (x + lean, -.025, height - .055)], [.108, .10], 'iron', 8)
        band_z = (.36 + height - .19) / 2
        art.tube(f'Iron window retaining band {i}', [(x + lean * .5, -.025, band_z - .024), (x + lean * .5, -.025, band_z + .024)], .095, 'iron', 8)
        art.tube(f'Ivory cartridge crown {i}', [(x + lean, -.025, height - .055), (x + lean, -.025, height)], [.065, .025], 'bone', 8)
        art.ring(f'Steel cartridge retaining collar {i}', (x, -.025, .27), .102, .018, 'steel', segments=12)
        art.tube(f'Cartridge feed elbow {i}', [(x, -.09, .36), (x, -.16, .22), (x, -.13, .12)], .025, 'bone', 6)


def health():
    for side in (-1, 1):
        art.tube(f'Basin splayed foot {side}', [(side * .28, 0, .03), (side * .20, 0, .17)], [.045, .03], 'iron', 6)
    art.ring('Low ivory receiving basin rim', (0, 0, .26), .27, .045, 'bone', segments=16)
    art.tube('Open anterior basin cradle', [(-.33, 0, .40), (-.27, -.05, .22), (0, -.10, .12), (.28, -.05, .22), (.34, 0, .43)], [.042, .05, .05, .05, .04], 'bone', 8)
    art.egg('Asymmetric teal left ventricle', (-.055, 0, .54), (.17, .13, .22), 'teal', 12, 6)
    art.egg('Smaller teal right lobe', (.095, -.01, .59), (.115, .12, .15), 'teal', 12, 6)
    art.tube('Descending organ taper', [(0, -.01, .58), (.035, -.02, .32)], [.12, .025], 'teal', 8)
    art.tube('Ivory organ incision rib', [(-.12, -.115, .64), (-.08, -.15, .48), (.035, -.08, .33)], [.016, .018, .012], 'bone', 5)
    art.tube('Offset return pipe', [(-.24, .04, .28), (-.27, .04, .78), (-.18, .04, .91), (-.05, .04, .87), (.13, .04, .68)], .025, 'iron', 6)
    art.tube('Teal return reservoir', [(-.265, .04, .65), (-.25, .04, .82)], .042, 'teal', 8)


def armor():
    base(.68)
    for side in (-1, 1):
        outline = [(side * .11, .22), (side * .36, .23), (side * .39, .51),
                   (side * .29, .82), (side * .14, 1.02), (side * .18, .66)]
        plate(f'Cobalt crescent carapace {side}', outline, .14, 'cobalt')
        art.tube(f'Ivory inner crescent rim {side}', [(side * .11, -.08, .24), (side * .15, -.08, .46), (side * .19, -.08, .69), (side * .14, -.08, .98)], [.04, .04, .03, .012], 'bone', 6)
        for i in range(3):
            z = .31 + i * .19
            outer = .36 - max(0, i - 1) * .045
            plate(f'Overlapping cobalt plate {side} {i}', [(side * .19, z), (side * outer, z - .02), (side * (outer + .025), z + .13), (side * .19, z + .17)], .18, 'cobalt')
            art.egg(f'Carapace steel hinge {side} {i}', (side * .19, -.105, z + .045), (.024, .018, .024), 'steel', 8, 4)
    art.tube('Lower split sternum brace', [(-.10, 0, .18), (0, 0, .26), (.10, 0, .18)], .035, 'iron', 6)


def key():
    base(.27, .17)
    art.tube('Slender iron lock stem', [(0, 0, .12), (0, 0, .48)], [.036, .048], 'iron', 6)
    art.ring('Ivory circular lock bezel', (0, -.02, .48), .095, .028, 'bone', 'XZ', 16)
    art.ring('Blood inner lock seal', (0, -.045, .48), .057, .014, 'blood', 'XZ', 12)
    for side in (-1, 1):
        plate(f'Blood fork tine {side}', [(side * .065, .53), (side * .115, .58), (side * .13, 1.07), (side * .08, 1.11)], .055, 'blood')
        art.tube(f'Ivory fork root {side}', [(side * .032, 0, .18), (side * .09, 0, .37), (side * .11, 0, .66)], [.025, .04, .024], 'bone', 6)


def weapon():
    base(.74, .32)
    art.tube('Wide ivory U cradle', [(-.35, 0, .70), (-.36, 0, .40), (-.25, 0, .20), (0, 0, .15), (.25, 0, .20), (.36, 0, .40), (.35, 0, .70)], [.045, .055, .065, .055, .065, .055, .045], 'bone', 8)
    art.box('Twin barrel receiver', (0, .06, .43), (.36, .18, .20), 'iron', .015)
    for side in (-1, 1):
        x, z = side * .115, .48
        # Four rings close an annular barrel wall; the muzzle has a real bore.
        verts, faces, steps = [], [], 12
        for radius, y in ((.087, -.30), (.087, .17), (.056, -.30), (.056, .17)):
            verts += [(x + radius * math.cos(i * 2 * math.pi / steps), y,
                       z + radius * math.sin(i * 2 * math.pi / steps)) for i in range(steps)]
        for start, end in ((0, 12), (24, 0), (12, 36), (36, 24)):
            for i in range(steps):
                j = (i + 1) % steps
                faces.append((start + i, end + i, end + j, start + j))
        art.mesh(f'Hollow iron weapon barrel {side}', verts, faces, 'iron')
        art.ring(f'Steel muzzle collar {side}', (x, -.30, z), .088, .013, 'steel', 'XZ', 12)
        art.ring(f'Amber breech band {side}', (x, .13, z), .089, .014, 'amber', 'XZ', 12)
    art.tube('Weapon support neck', [(0, .07, .15), (0, .07, .36)], .042, 'steel', 6)


def story():
    base(.68, .26)
    for side in (-1, 1):
        plate(f'Pale outward-flared codex leaf {side}', [(side * .065, .24), (side * .30, .16), (side * .38, .96), (side * .12, .83)], .09, 'bone')
        art.tube(f'Codex outer iron binding {side}', [(side * .30, -.03, .16), (side * .34, -.03, .60), (side * .38, -.03, .96)], .045, 'iron', 6)
        for i, (x, z) in enumerate(((.32, .35), (.35, .69))):
            art.box(f'Iron codex binding clamp {side} {i}', (side * (x - .01), -.055, z), (.11, .10, .07), 'iron')
            art.tube(f'Steel codex hinge pivot {side} {i}', [(side * x, -.095, z), (side * x, -.145, z)], .031, 'steel', 8)
        art.tube(f'Split pale memory spine {side}', [(side * .028, 0, .25), (side * .028, 0, .79)], .012, 'pale', 6)
        art.tube(f'Codex leaf incised rail {side}', [(side * .10, -.06, .28), (side * .14, -.06, .59), (side * .17, -.06, .82)], .014, 'steel', 5)


def checkpoint():
    for i in range(3):
        angle = -math.pi / 6 + i * 2 * math.pi / 3
        c, s = math.cos(angle), math.sin(angle)
        art.tube(f'Spaced ivory anchoring leg {i}', [(.35 * c, .35 * s, .035), (.26 * c, .26 * s, .45), (.12 * c, .12 * s, 1.05)], [.047, .034, .007], 'bone', 6)
        art.tube(f'Leg inner iron piston {i}', [(.30 * c, .30 * s, .10), (.21 * c, .21 * s, .58)], .016, 'iron', 6)
        art.tube(f'Core suspension arm {i}', [(0, 0, .55), (.24 * c, .24 * s, .55)], .014, 'steel', 6)
    art.egg('Suspended amber checkpoint core', (0, 0, .55), (.125, .125, .125), 'amber', 12, 6)
    art.ring('Core meridian restraint', (0, 0, .55), .155, .017, 'steel', 'XZ', 16)
    art.ring('Core equatorial restraint', (0, 0, .55), .155, .017, 'steel', segments=16)


def exit():
    art.ring('Exit ground mounting ring', (0, 0, .04), .25, .035, 'iron', segments=12)
    for side in (-1, 1):
        art.tube(f'Ivory exit coil support {side}', [(side * .25, .04, .06), (side * .28, .04, .41), (side * .34, .04, .84)], [.04, .026, .026], 'bone', 6)
    for i, (radius, z) in enumerate(((.07, .17), (.12, .32), (.18, .48), (.25, .65), (.34, .84))):
        art.ring(f'Descending ivory coil {i}', (0, 0, z), radius, .023, 'bone', segments=12)
        art.ring(f'Muted violet inner coil {i}', (0, 0, z + .007), radius - .026, .009, 'violet', segments=8)
    art.tube('Exit recessed iron axial pin', [(0, 0, .08), (0, 0, .90)], .013, 'iron', 6)


def build(name):
    scene = art.setup()
    for key, color in (('teal', '#378b87'), ('cobalt', '#3d5394'), ('blood', '#9b303d'),
                       ('pale', '#e1d4b6'), ('violet', '#746182')):
        art.M[key] = art.material('Marker ' + key, color, rough=.60, emission=.35 if key in ('teal', 'pale', 'violet') else 0)
    globals()[name.removeprefix('marker_')]()
    bpy.context.view_layer.update()
    objects = [o for o in scene.objects if o.type == 'MESH']
    extent = art.bounds(objects)
    shift = [-(extent['min'][0] + extent['max'][0]) / 2,
             -(extent['min'][1] + extent['max'][1]) / 2, -extent['min'][2]]
    for obj in objects:
        for i in range(3):
            obj.location[i] += shift[i]
    bpy.context.view_layer.update()
    extent = art.bounds(objects)
    parts = [{'name': o.name, 'vertices': len(o.data.vertices),
              'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in objects]
    triangles = sum(p['triangles'] for p in parts)
    groups = {o.data.materials[0].name for o in objects}
    assert 0 < triangles <= 2500 and len(groups) <= 8, (name, triangles, len(groups))
    assert all(0 < v <= cap for v, cap in zip(extent['size'], (.9, .9, 1.2))), extent
    scene['asset_id'], scene['authoring_recipe'] = name, RECIPE
    scene['recipe_sha256'], scene['reference_sha256'] = art.sha(Path(__file__)), REFERENCE_SHA
    height = extent['size'][2]
    scale = max(height, extent['size'][0], extent['size'][1]) * 1.45
    art.camera(scene, (scale * .65, -scale * 1.6, height * 1.1), (0, 0, height * .48), scale, 128, 128)
    pixels = art.pixels_render(scene, name, 128, 128)
    preview = art.target(art.SCRATCH / f'{name}_preview.png')
    art.png(preview, 128, 128, pixels)
    source = art.save(name)  # Save named independent parts BEFORE runtime material merge.
    # world_export's material merge/export block; its fixed opaque 384px/atlas path is unsuitable.
    for key, mat in art.M.items():
        group = [o for o in scene.objects if o.type == 'MESH' and o.data.materials[0] == mat]
        if not group:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        group[0].name = name + '_' + key
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in scene.objects if o.type == 'MESH']
    for obj in meshes:
        obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    path = art.target(art.OUT / 'world' / f'{name}.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False,
                              export_cameras=False, export_lights=False, export_extras=False,
                              export_materials='EXPORT', export_image_format='AUTO')
    entry = art.record(name, source, [(path, None)], physical_bounds_m=extent,
                       origin='ground-centered at Blender (0,0,0); GLB Y up', triangles=triangles,
                       runtime_mesh_nodes=len(meshes), material_count=len(meshes), loop_id=None)
    entry.update(recipe_sha256=art.sha(Path(__file__)), recipe_dependencies={'tools/build_art.py': art.sha(Path(art.__file__))},
                 reference_images=[{'path': REFERENCE, 'sha256': REFERENCE_SHA}],
                 facing='front Blender -Y; exported Godot +Z', collision='none; marker visuals only',
                 provenance={'method': 'image-derived original Blender geometry', 'authoring_script': RECIPE,
                             'imports': [], 'license': 'Original NULL CHOIR project art'},
                 preview={'path': str(preview.relative_to(ROOT)), 'sha256': art.sha(preview),
                          'bytes': preview.stat().st_size, 'dimensions': [128, 128]})
    receipt_path = art.target(art.SCRATCH / f'{name}_geometry.json')
    entry['geometry_receipt'] = str(receipt_path.relative_to(ROOT))
    receipt = {'asset_id': name, 'source_sha256': entry['source_sha256'], 'recipe_sha256': entry['recipe_sha256'],
               'reference_sha256': REFERENCE_SHA, 'source_meshes': parts, 'physical_bounds_m': extent,
               'material_groups': len(meshes), 'blender_version': bpy.app.version_string,
               'render_engine': scene.render.engine, 'device': scene.cycles.device,
               'threads': scene.render.threads, 'samples': scene.cycles.samples}
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    return entry


def prepare_paths(name):
    art.SCRATCH = ROOT / 'builds/marker-art'  # Check the effective scratch, not the helper default.
    assert art.ROOT == ROOT and art.ART == ROOT / 'source/art' and art.OUT == ROOT / 'game/assets/art'
    manifest_path = art.ART / 'marker-manifest.json'
    candidates = (art.ART / f'{name}.blend', art.OUT / 'world' / f'{name}.glb',
                  art.SCRATCH / f'{name}_preview.png', art.SCRATCH / f'{name}_geometry.json',
                  art.SCRATCH / 'frames' / f'{name}.png')
    # Pin exact intended names/directories; reject directory and leaf symlink aliases before any write.
    assert all(p.resolve() == p and p.is_relative_to(ROOT) for p in (manifest_path, *candidates)), 'output path containment'
    return manifest_path, candidates


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', required=True, choices=IDS)
    opts = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    manifest_path, candidates = prepare_paths(opts.asset)
    sys.path.insert(0, str(ROOT / 'tests'))
    from test_marker_art import check, family_totals, load_inputs, load_manifest, read_model, validate_model
    load_inputs()
    current = load_manifest()
    # Preserve completed work; a failed partial run requires parent review, never blind overwrite/retry.
    assert all(not p.exists() for p in candidates) and opts.asset not in [a['id'] for a in current['assets']], 'existing/partial output: stop for parent review'
    family_totals()
    print('MARKER_START ' + opts.asset, flush=True)
    entry = build(opts.asset)
    validate_model(*read_model((ROOT / entry['outputs'][0]['path']).read_bytes()), entry)
    current['assets'].append(entry)
    # This isolated family manifest never reads or mutates the original art manifest.
    art.target(manifest_path).write_text(json.dumps(current, indent=2) + '\n')
    check(opts.asset)
    print('MARKER_DONE ' + opts.asset + ' ' + entry['outputs'][0]['sha256'], flush=True)


if __name__ == '__main__':
    main()
