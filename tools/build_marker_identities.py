"""Isolated image-derived marker candidates; run one asset per background Blender job."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

SOURCE_ROOT = Path(__file__).resolve().parents[1]
IDS = ('marker_ivorykey', 'marker_ammo_shells', 'marker_ammo_sawtooth',
       'marker_ammo_marrow', 'marker_ammo_choir')
REFERENCE = 'source/art/references/marker-identities-v2.png'
REFERENCE_SHA = '061ac88b9d4ff2ae70da4b1996cc1f6d4cda92bf05a698d5887159a8fb2475f0'
RECIPE = 'tools/build_marker_identities.py'
HELPER_SHA = {'tools/build_art.py': '07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a',
              'tools/build_marker_art.py': '9151707aced076b1c0040b0417499c6a32a1eab6e88f273562488a2759c67c9c'}
DIMENSION_CAP = (.9, .9, 1.2)
TRIANGLE_CAP, MATERIAL_CAP, GLB_CAP = 2500, 8, 150000


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_inputs():
    for relative, digest in {**HELPER_SHA, REFERENCE: REFERENCE_SHA}.items():
        path = SOURCE_ROOT / relative
        if path.resolve() != path or not path.is_file() or sha(path) != digest:
            raise ValueError('missing, aliased or drifted input: ' + relative)


def prepare_paths(root, name):
    root = Path(root)
    if name not in IDS:
        raise ValueError('unrecognized marker identity')
    if not root.is_absolute() or root.resolve() != root:
        raise ValueError('candidate root must be absolute, canonical and symlink-free')
    if root == SOURCE_ROOT or root in SOURCE_ROOT.parents or SOURCE_ROOT in root.parents:
        raise ValueError('candidate root must be outside original project')
    for ancestor in (root, *root.parents):
        if (ancestor / 'game/project.godot').exists() or (ancestor / 'tools/build_art.py').exists():
            raise ValueError('candidate root must not be inside any original project')
    scratch = root / 'builds/marker-identities'
    paths = {'source': root / 'source/art' / f'{name}.blend',
             'model': root / 'game/assets/art/world' / f'{name}.glb',
             'preview': scratch / f'{name}_preview.png',
             'frame': scratch / 'frames' / f'{name}.png',
             'receipt': scratch / f'{name}_geometry.json'}
    for path in paths.values():
        if path.resolve() != path or not path.is_relative_to(root) or path.exists():
            raise ValueError('aliased, escaped or existing candidate output: ' + str(path))
    return paths


def check_geometry(extent, triangles, groups):
    if not 0 < triangles <= TRIANGLE_CAP or not 0 < groups <= MATERIAL_CAP:
        raise ValueError('triangle/material budget')
    if any(len(extent[key]) != 3 or not all(math.isfinite(v) for v in extent[key])
           for key in ('min', 'max', 'size')):
        raise ValueError('invalid physical bounds')
    lo, hi, size = (extent[key] for key in ('min', 'max', 'size'))
    if not all(0 < v <= cap for v, cap in zip(size, DIMENSION_CAP)):
        raise ValueError('physical dimension budget')
    if (abs(lo[2]) > 1e-6 or any(abs(lo[i] + hi[i]) > 1e-6 for i in (0, 1))
            or any(abs(hi[i] - lo[i] - size[i]) > 1e-6 for i in range(3))):
        raise ValueError('ground-centered bounds')


def check_glb_size(size):
    if not 0 < size <= GLB_CAP:
        raise ValueError('compact GLB budget')


def check_preview(pixels):
    if len(pixels) != 128 * 128 * 4:
        raise ValueError('preview must be 128px RGBA')
    alpha = pixels[3::4]
    if not any(alpha) or not any(a == 0 for a in alpha):
        raise ValueError('empty or opaque preview')
    border = [alpha[y * 128 + x] for y in range(128) for x in range(128)
              if x in (0, 127) or y in (0, 127)]
    if any(border):
        raise ValueError('clipped preview silhouette')


def xz_tube(art, name, points, radii, mat='bone', sides=8, plane='XZ'):
    """Fixed +Y for XZ or -Z for XY; the XY rotation preserves outward winding."""
    points = [tuple(p) for p in points]
    radii = [radii] * len(points) if isinstance(radii, (float, int)) else list(radii)
    if plane not in ('XZ', 'XY'):
        raise ValueError('unsupported fixed sweep plane')
    axis = 1 if plane == 'XZ' else 2
    if (len(points) < 2 or sides < 3 or len(radii) != len(points)
            or any(len(p) != 3 or not all(math.isfinite(v) for v in p) for p in points)
            or any(p[axis] != points[0][axis] for p in points)
            or any(not math.isfinite(r) or r <= 0 for r in radii)):
        raise ValueError('invalid XZ sweep')
    if plane == 'XY':
        points = [(x, -z, y) for x, y, z in points]
    closed = points[0] == points[-1]
    if closed:
        if len(points) < 4 or radii[0] != radii[-1]:
            raise ValueError('invalid closed XZ sweep')
        points, radii = points[:-1], radii[:-1]
    vertices, faces = [], []
    count = len(points)
    for i, (x, y, z) in enumerate(points):
        before = points[(i - 1) % count] if closed else points[max(i - 1, 0)]
        after = points[(i + 1) % count] if closed else points[min(i + 1, count - 1)]
        dx, dz = after[0] - before[0], after[2] - before[2]
        length = math.hypot(dx, dz)
        if length == 0:
            raise ValueError('zero tangent in XZ sweep')
        for j in range(sides):
            angle = j * 2 * math.pi / sides
            offset = radii[i] * math.sin(angle)
            vertices.append((x - offset * dz / length, y + radii[i] * math.cos(angle),
                             z + offset * dx / length))
    for i in range(count if closed else count - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            next_ring = ((i + 1) % count) * sides
            faces.append((a, b, next_ring + (j + 1) % sides, next_ring + j))
    if not closed:
        faces.extend([tuple(reversed(range(sides))), tuple(range((count - 1) * sides, count * sides))])
    if plane == 'XY':
        vertices = [(x, z, -y) for x, y, z in vertices]
    return art.mesh(name, vertices, faces, mat)


def xy_ring(art, name, center, radius, thickness, mat='bone', segments=24):
    cx, cy, cz = center
    points = [(cx + radius * math.cos(i * 2 * math.pi / segments),
               cy + radius * math.sin(i * 2 * math.pi / segments), cz) for i in range(segments)]
    return xz_tube(art, name, points + [points[0]], thickness, mat, 8, plane='XY')


def ivorykey(art, plate):
    # Three separate antlers and a genuine diamond aperture distinguish ivory from blood.
    for side in (-1, 1):
        points = [(side * .145 * math.cos(math.radians(-70 + i * 17.5)), 0,
                   .18 + .145 * math.sin(math.radians(-70 + i * 17.5))) for i in range(9)]
        xz_tube(art, f'Slit handle half {side}', points, .025, 'steel', 6)
        xz_tube(art, f'Ivory lateral antler {side}',
                 [(side * .085, 0, .66), (side * .27, 0, .76),
                  (side * .35, 0, .97), (side * .31, 0, 1.10)],
                 [.048, .045, .033, .006], 'bone', 8)
        art.tube(f'Lock shoulder sleeve {side}',
                 [(side * .085, 0, .66), (side * .13, 0, .685)], .053, 'steel', 6)
    diamond = [(0, 0, .37), (.135, 0, .54), (0, 0, .71), (-.135, 0, .54), (0, 0, .37)]
    xz_tube(art, 'Open ivory diamond bezel', diamond, .028, 'bone', 6)
    art.tube('Central ivory antler', [(0, 0, .71), (0, 0, .88), (0, 0, 1.15)],
             [.042, .032, .003], 'bone', 8)
    art.tube('Short lock neck', [(0, 0, .32), (0, 0, .39)], .034, 'iron', 6)
    for side in (-1, 1):
        art.tube(f'Handle hinge pin {side}', [(side * .145, -.025, .18),
                 (side * .145, -.055, .18)], .023, 'iron', 6)


def shells(art, plate):
    for i, (x, height) in enumerate(((-.18, .84), (.18, .94))):
        art.tube(f'Broad shell body {i}', [(x, 0, .10), (x, 0, .54)], .125, 'steel', 10)
        art.tube(f'Pressed shell casing {i}', [(x, 0, .53), (x, 0, height)], .12, 'skin', 10)
        art.tube(f'Shell flanged heel {i}', [(x, 0, .035), (x, 0, .095)], .148, 'iron', 10)
        xy_ring(art, f'Shell brass shoulder {i}', (x, 0, .51), .125, .012, 'bone', segments=10)
        xy_ring(art, f'Crimped shell crown {i}', (x, 0, height), .105, .016, 'steel', segments=10)
        for tooth in range(4):
            angle = tooth * math.pi / 2
            px, py = x + .077 * math.cos(angle), .077 * math.sin(angle)
            art.tube(f'Shell crimp seam {i} {tooth}', [(px, py, height - .045),
                     (px, py, height + .01)], .012, 'iron', 5)
    art.tube('Low shell feed link', [(-.18, .065, .16), (.18, .065, .16)], .023, 'iron', 6)


def sawtooth(art, plate):
    for i in range(5):
        x = (i - 2) * .14
        height = .96 + (i % 2) * .06
        art.tube(f'Cartridge spine {i}', [(x, 0, .08), (x, 0, height - .12), (x, 0, height)],
                 [.047, .047, .002], 'steel', 6)
        art.tube(f'Spine ivory collar {i}', [(x, 0, .70), (x, 0, .75)], .056, 'bone', 6)
        art.tube(f'Spine foot {i}', [(x, 0, .025), (x, 0, .095)], .055, 'iron', 6)
    plate('Narrow segmented feed web', [(-.34, .31), (.34, .31), (.34, .40), (-.34, .40)], .10, 'iron')
    for i in range(7):
        x = -.30 + i * .10
        plate(f'Saw tooth {i}', [(x - .047, .40), (x + .047, .40), (x, .51)], .115, 'bone')


def marrow(art, plate):
    # Separate side plates leave a through-hole; no dark decal stands in for the aperture.
    for side in (-1, 1):
        plate(f'Hollow marrow spear side {side}',
              [(side * .052, .45), (side * .145, .39), (side * .165, .71),
               (side * .095, .98), (0, 1.12), (side * .047, .91), (side * .061, .70)],
              .15, 'bone')
        plate(f'Splayed marrow fin {side}', [(side * .10, .14), (side * .25, .035),
              (side * .225, .37), (side * .14, .51)], .18, 'steel')
        art.tube(f'Marrow side suture {side}', [(side * .15, -.09, .46),
                 (side * .14, -.09, .66)], .012, 'iron', 5)
    plate('Marrow lance tip', [(-.048, .97), (.048, .97), (0, 1.12)], .15, 'bone')
    art.tube('Marrow basal socket', [(0, 0, .04), (0, 0, .43)], [.083, .075], 'iron', 8)
    xy_ring(art, 'Marrow socket collar', (0, 0, .16), .084, .017, 'steel', segments=10)


def choir(art, plate):
    for side in (-1, 1):
        plate(f'Resonant tine {side}', [(side * .052, .42), (side * .17, .49),
              (side * .205, .95), (side * .165, 1.12), (side * .115, 1.05),
              (side * .095, .61), (side * .052, .55)], .12, 'steel')
        art.tube(f'Teal inner resonance rail {side}', [(side * .09, -.065, .60),
                 (side * .12, -.065, .91), (side * .14, -.065, 1.02)], .014, 'teal', 5)
        xz_tube(art, f'Splayed choir brace {side}', [(side * .18, 0, .05),
                 (side * .24, 0, .17), (side * .17, 0, .34), (side * .06, 0, .43)],
                 [.028, .034, .036, .032], 'iron', 6)
    art.tube('Choir tuning stem', [(0, 0, .025), (0, 0, .49)], [.045, .037], 'steel', 8)
    art.tube('Choir transverse root', [(-.052, 0, .49), (.052, 0, .49)], .038, 'steel', 6)
    xy_ring(art, 'Choir lower vertebral cuff', (0, 0, .19), .054, .017, 'bone', segments=10)


RECIPES = dict(zip(IDS, (ivorykey, shells, sawtooth, marrow, choir)))


def build(root, name):
    root = Path(root)
    paths = prepare_paths(root, name)
    check_inputs()  # Fail before importing Blender or writing any candidates.
    sys.path.insert(0, str(SOURCE_ROOT / 'tools'))
    import bpy
    import build_art as art
    from build_marker_art import plate

    art.ROOT, art.ART, art.OUT = root, root / 'source/art', root / 'game/assets/art'
    art.SCRATCH = root / 'builds/marker-identities'
    scene = art.setup()
    art.M['teal'] = art.material('Muted choir resonance', '#378b87', rough=.6, emission=.12)
    RECIPES[name](art, plate)
    bpy.context.view_layer.update()
    objects = [o for o in scene.objects if o.type == 'MESH']
    # Use unrounded native bounds for centering and hard dimension gates.
    points = [o.matrix_world @ art.Vector(corner) for o in objects for corner in o.bound_box]
    lo, hi = [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]
    shift = [-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]]
    for obj in objects:
        for i in range(3):
            obj.location[i] += shift[i]
    bpy.context.view_layer.update()
    points = [o.matrix_world @ art.Vector(corner) for o in objects for corner in o.bound_box]
    lo, hi = [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]
    extent = {'min': lo, 'max': hi, 'size': [hi[i] - lo[i] for i in range(3)],
              'axes': 'Blender XYZ, Z up; GLB/Godot Y up'}
    parts = [{'name': o.name, 'vertices': len(o.data.vertices),
              'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in objects]
    triangles = sum(p['triangles'] for p in parts)
    groups = {o.data.materials[0].name for o in objects}
    check_geometry(extent, triangles, len(groups))
    recipe_sha = sha(Path(__file__))
    scene['asset_id'], scene['authoring_recipe'] = name, RECIPE
    scene['recipe_sha256'], scene['reference_sha256'] = recipe_sha, REFERENCE_SHA
    scene['recipe_dependencies'] = json.dumps(HELPER_SHA, sort_keys=True)
    height = extent['size'][2]
    scale = max(extent['size']) * 1.35
    art.camera(scene, (scale * .08, -scale * 1.6, height * .65),
               (0, 0, height * .50), scale, 128, 128)
    source = art.save(name)  # Named independent native parts BEFORE runtime material merge.
    pixels = art.pixels_render(scene, name, 128, 128)
    check_preview(pixels)
    art.png(paths['preview'], 128, 128, pixels)
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
    bpy.ops.export_scene.gltf(filepath=str(art.target(paths['model'])), export_format='GLB',
                              use_selection=True, export_apply=True, export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_extras=False, export_materials='EXPORT', export_image_format='AUTO')
    check_glb_size(paths['model'].stat().st_size)
    entry = art.record(name, source, [(paths['model'], None)], physical_bounds_m=extent,
                       origin='ground-centered at Blender (0,0,0); GLB Y up', triangles=triangles,
                       runtime_mesh_nodes=len(meshes), material_count=len(meshes), loop_id=None)
    entry.update(recipe_sha256=recipe_sha, recipe_dependencies=HELPER_SHA,
                 reference_images=[{'path': REFERENCE, 'sha256': REFERENCE_SHA}],
                 facing='front Blender -Y; exported Godot +Z', collision='none; marker visuals only',
                 provenance={'method': 'image-derived original Blender geometry', 'authoring_script': RECIPE,
                             'imports': [], 'license': 'Original NULL CHOIR project art'},
                 preview={'path': str(paths['preview'].relative_to(root)), 'sha256': sha(paths['preview']),
                          'bytes': paths['preview'].stat().st_size, 'dimensions': [128, 128]},
                 source_meshes=parts, native_source_saved_before_runtime_merge=True,
                 reference_sha256=REFERENCE_SHA, blender_version=bpy.app.version_string,
                 render_engine=scene.render.engine, device=scene.cycles.device,
                 threads=scene.render.threads, samples=scene.cycles.samples)
    art.target(paths['receipt']).write_text(json.dumps(entry, indent=2) + '\n')
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', required=True, choices=IDS)
    parser.add_argument('--output-root', required=True, type=Path)
    opts = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    print('MARKER_IDENTITY_START ' + opts.asset, flush=True)
    entry = build(opts.output_root, opts.asset)
    print('MARKER_IDENTITY_DONE ' + opts.asset + ' ' + entry['outputs'][0]['sha256'], flush=True)


if __name__ == '__main__':
    main()
