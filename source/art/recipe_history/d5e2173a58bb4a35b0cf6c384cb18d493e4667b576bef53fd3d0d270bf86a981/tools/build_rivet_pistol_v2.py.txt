"""Original fantasy prop; run only through the parent's bounded Blender job."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True

FRAMES = ('idle', 'fire', 'recover')
ROLL = (0.0, 1.6, -0.65)
MUZZLE = (140.0, 62.0, 22.0)
HELPER_SHA = '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581'
REFERENCE_SHA = '246d6f6b39d252115465feac28832664285686567f1612db9df9301cfeff8e15'
PALETTE = {
    'bone': ('#b6a078', 0.05, .66), 'bone_edge': ('#dac7a0', 0.05, .58),
    'brass': ('#84663b', .68, .47), 'brass_edge': ('#b89557', .62, .43),
    'patina': ('#314c43', .35, .74), 'steel': ('#242c30', .72, .44),
    'groove': ('#13191b', .3, .7), 'oxblood': ('#542128', .1, .64),
    'glove': ('#222322', 0, .86), 'wrap': ('#393832', 0, .83),
}
SURFACES = {
    'bone': ('#756043', '#b6a078', 8, .004),
    'bone_edge': ('#9a8059', '#dac7a0', 8, .004),
    'brass': ('#3e3021', '#a17e44', 10, .003),
    'brass_edge': ('#705331', '#bf9b5a', 10, .003),
    'patina': ('#183830', '#416254', 7, .002),
    'steel': ('#11191b', '#3d4544', 10, .002),
    'groove': ('#0c1113', '#20282a', 7, .001),
    'oxblood': ('#311218', '#7e303a', 7, .002),
    'glove': ('#111513', '#2e3029', 9, .005),
    'wrap': ('#282820', '#514c3e', 9, .005),
}


def linear_rgba(color):
    values = [int(color[i:i+2], 16)/255 for i in (1, 3, 5)]
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)


def weathered_material(helper, name):
    color, metallic, roughness = PALETTE[name]
    mat = helper.material(name, color, metallic, roughness)
    dark, light, frequency, depth = SURFACES[name]
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    coords = nodes.new('ShaderNodeTexCoord')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = frequency
    noise.inputs['Detail'].default_value = 1.3
    noise.inputs['Roughness'].default_value = .6
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .28
    ramp.color_ramp.elements[0].color = linear_rgba(dark)
    ramp.color_ramp.elements[1].position = .72
    ramp.color_ramp.elements[1].color = linear_rgba(light)
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .24
    bump.inputs['Distance'].default_value = depth
    # Local coordinates preserve the same broad wear patches across linked poses.
    links.new(coords.outputs['Object'], noise.inputs['Vector'])
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], shader.inputs['Base Color'])
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    return mat


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def add(a, b):
    return tuple(x+y for x, y in zip(a, b))


def scale(a, n):
    return tuple(x*n for x in a)


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    length = math.sqrt(sum(x*x for x in a))
    if length < 1e-8:
        raise ValueError('Degenerate geometry direction')
    return scale(a, 1/length)


def basis(axis):
    axis = unit(axis)
    u = unit(cross(axis, (0, 0, 1) if abs(axis[2]) < .9 else (1, 0, 0)))
    return u, cross(axis, u)


def mesh(name, vertices, faces, material):
    return {'name': name, 'vertices': vertices, 'faces': faces, 'material': material}


def ellipsoid(name, center, radii, material, angle=0, sides=20, rings=10):
    vertices = [(0, 0, -radii[2])]
    for j in range(1, rings):
        a = math.pi*j/rings
        for i in range(sides):
            b = math.tau*i/sides
            vertices.append((radii[0]*math.sin(a)*math.cos(b), radii[1]*math.sin(a)*math.sin(b), -radii[2]*math.cos(a)))
    vertices.append((0, 0, radii[2]))
    faces = [(0, 1+(i+1)%sides, 1+i) for i in range(sides)]
    for j in range(rings-2):
        for i in range(sides):
            a, b = 1+j*sides+i, 1+j*sides+(i+1)%sides
            faces.append((a, b, b+sides, a+sides))
    end = len(vertices)-1
    faces.extend((end, end-sides+i, end-sides+(i+1)%sides) for i in range(sides))
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    return mesh(name, [add(center, (c*x-s*y, s*x+c*y, z)) for x, y, z in vertices], faces, material)


def sweep(name, points, radii, material, sides=12):
    vertices, faces = [], []
    for i, point in enumerate(points):
        before, after = points[max(0, i-1)], points[min(len(points)-1, i+1)]
        u, v = basis(tuple(b-a for a, b in zip(before, after)))
        for j in range(sides):
            a = math.tau*j/sides
            vertices.append(add(point, add(scale(u, radii[i]*math.cos(a)), scale(v, radii[i]*math.sin(a)))))
        if i:
            for j in range(sides):
                a, b = (i-1)*sides+j, (i-1)*sides+(j+1)%sides
                faces.append((a, b, b+sides, a+sides))
    faces.extend((tuple(reversed(range(sides))), tuple(range(len(vertices)-sides, len(vertices)))))
    return mesh(name, vertices, faces, material)


def collar(name, center, axis, radius, length, material, sides=20):
    axis = unit(axis)
    u, v = basis(axis)
    vertices, faces = [], []
    for offset, r in ((-length/2, radius), (length/2, radius), (length/2, radius*.71), (-length/2, radius*.71)):
        for i in range(sides):
            a = math.tau*i/sides
            vertices.append(add(center, add(scale(axis, offset), add(scale(u, r*math.cos(a)), scale(v, r*math.sin(a))))))
    for j in range(4):
        for i in range(sides):
            a, b = j*sides+i, j*sides+(i+1)%sides
            faces.append((a, b, ((j+1)%4)*sides+(i+1)%sides, ((j+1)%4)*sides+i))
    return mesh(name, vertices, faces, material)


def plate(name, outline, depth, thickness, material):
    n = len(outline)
    vertices = [(x, y, depth+d) for d in (0, thickness) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces.extend((i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n))
    return mesh(name, vertices, faces, material)


def geometry():
    """Coordinates are camera-local pixel units with real depth, not image planes."""
    parts = []
    axis = (48, 28, -22)
    parts.append(sweep('Muzzle black steel barrel', [MUZZLE, (164, 76, 11), (193, 94, -2)], [8, 9, 12], 'steel', 20))
    # A recessed dark cap sits behind the annular lip; no flash geometry.
    parts.append(ellipsoid('Muzzle recessed bore', (140.4, 62.3, 24), (5, 5, 1.5), 'groove'))
    for i, (x, y, z, r) in enumerate(((140, 62, 22, 10), (151, 68, 17, 10), (166, 77, 10, 11), (186, 89, 0, 14))):
        parts.append(collar(f'Muzzle receiver band {i}', (x, y, z), axis, r, 4 if i else 5, 'brass' if i%2 == 0 else 'steel'))
        parts.append(collar(f'Worn band edge {i}', (x-1, y-.6, z+.5), axis, r+.4, .9, 'brass_edge'))
    parts.append(ellipsoid('Receiver dark mass', (214, 108, 0), (35, 19, 16), 'steel', 32))
    parts.append(ellipsoid('Receiver oxblood inner recess', (213, 108, -18), (22, 6, 3), 'oxblood', 32))
    parts.append(sweep('Receiver open vertebral spine', [(191, 84, -7), (209, 94, -10), (228, 106, -10), (242, 121, -7)], [3.4, 3.2, 3, 3.4], 'bone', 16))
    for label, center, radius in [('front', (190, 92, -1), 16), ('rear', (239, 121, -4), 16)]:
        parts.append(collar(f'Receiver brass cage collar {label}', center, axis, radius, 4, 'brass'))
        parts.append(collar(f'Receiver worn collar edge {label}', add(center, (-1, -.6, .5)), axis, radius+.3, 1, 'brass_edge'))
    for i in range(6):
        x, y = 189+i*8, 94+i*5
        parts.append(sweep(f'Vertebral rib {i}', [(x+8, y-10, -3), (x+2, y-8, -13), (x-3, y, -24), (x-3, y+12, -22), (x+2, y+18, -9)], [3.1, 3.2, 2.8, 2.6, 3.3], 'bone_edge', 12))
        parts.append(ellipsoid(f'Vertebral root {i}', (x+7, y-9, -3), (5, 4, 4), 'bone', 30, 16, 8))
        parts.append(ellipsoid(f'Brass rib rivet {i}', (x+2, y+17, -12), (2.3, 2.3, 1.2), 'brass_edge', sides=12, rings=6))
    # Vent openings are deep dark channels beneath thick raised rims.
    for i in range(3):
        x, y = 169+i*5, 83+i*3
        parts.append(sweep(f'Receiver vent dark slot {i}', [(x, y+4, -13), (x+8, y+9, -16)], [2.5, 2.5], 'groove'))
        parts.append(sweep(f'Receiver vent oxblood inset {i}', [(x+1, y+4.5, -16), (x+7, y+8.5, -19)], [1, 1], 'oxblood'))
        parts.append(sweep(f'Receiver vent raised rim {i}', [(x, y+1, -14), (x+8, y+6, -17)], [.9, .9], 'brass'))
    parts.append(plate('Carved bone cheek plate', [(237, 123), (245, 129), (245, 141), (239, 143), (234, 136)], -22, 5, 'bone'))
    for i in range(3):
        parts.append(sweep(f'Carved cheek groove {i}', [(238+i*2, 130+i, -23), (239+i*2, 138+i*.5, -23)], [.7, .5], 'groove', 8))
    bezel = [(217, 122, -30), (225, 115, -30), (232, 121, -30), (239, 143, -30), (224, 149, -30), (216, 138, -30), (217, 122, -30)]
    parts.append(sweep('Reliquary brass surround', bezel, [1.4]*len(bezel), 'brass_edge', 12))
    parts.append(plate('Reliquary recessed tablet', [(217, 122), (225, 115), (232, 121), (239, 143), (224, 149), (216, 138)], -27, 2, 'steel'))
    for i in range(2):
        parts.append(sweep(f'Reliquary incised border {i}', [(220+i*12, 126, -28), (223+i*12, 141, -28)], [.65, .65], 'groove', 8))
    parts.append(ellipsoid('Reliquary relief head', (225, 126, -30), (2.5, 3, 1.6), 'bone_edge', sides=12, rings=6))
    parts.append(sweep('Reliquary draped relief', [(225, 129, -30), (228, 137, -30), (232, 141, -30)], [1.8, 2.8, 2.5], 'brass_edge'))
    parts.append(sweep('Receiver lower bone strut', [(183, 117, -8), (197, 129, -12), (215, 137, -8)], [4.6, 5.5, 4.5], 'bone', 16))
    for i, (x, y) in enumerate(((185, 114), (198, 126), (240, 114), (245, 137), (231, 99))):
        parts.append(ellipsoid(f'Receiver bolt {i}', (x, y, -18), (3, 3, 1.4), 'brass', sides=12, rings=6))
        parts.append(sweep(f'Bolt cut {i}', [(x-1.5, y, -19.5), (x+1.5, y, -19.5)], [.5, .5], 'groove', 6))
    parts.append(ellipsoid('Receiver patina patch', (198, 129, -17), (3.5, 1.7, .7), 'patina', 30, 12, 6))
    parts.append(sweep('Short rear brass cap', [(237, 119, 0), (250, 129, -4)], [10, 8], 'brass', 16))
    parts.append(collar('Rear cap black inset', (251, 129, -4), axis, 7, 2, 'steel'))
    parts.append(sweep('Dark pistol grip', [(233, 131, 4), (243, 158, 2)], [9, 11], 'groove', 16))
    parts.append(sweep('Under-grip open guard', [(214, 129, -8), (207, 140, -9), (215, 152, -12), (231, 153, -12)], [2, 2, 2, 2], 'brass', 12))
    parts.append(ellipsoid('Glove palm', (244, 159, -8), (23, 18, 15), 'glove', 36))
    parts.append(ellipsoid('Glove thumb', (228, 147, -17), (15, 7, 6), 'wrap', 28))
    for i in range(4):
        parts.append(ellipsoid(f'Glove curled finger {i}', (232+i*3, 154+i*7, -24), (11-i*.7, 4.8, 5.5), 'glove', 27, 16, 8))
        parts.append(sweep(f'Glove knuckle seam {i}', [(226+i*3, 153+i*7, -28), (232+i*3, 156+i*7, -29)], [.7, .7], 'wrap', 8))
    parts.append(ellipsoid('Forearm dark wrapped mass', (270, 192, 3), (47, 27, 23), 'glove', 38, 24, 12))
    for i in range(9):
        x, y = 250+i*5.4, 167+i*5
        parts.append(sweep(f'Forearm broad wrap {i}', [(x-8, y+9, -9), (x-6, y+2, -20), (x+4, y-2, -23), (x+15, y+1, -15), (x+18, y+8, -4)], [1.8, 2.2, 2.5, 2.3, 1.8], 'wrap', 10))
    parts.append(ellipsoid('Glove wrist brass medallion', (256, 171, -25), (5, 6, 1.3), 'brass', 35, 16, 8))
    parts.append(ellipsoid('Medallion ivory stud', (256, 170, -27), (1.4, 2.6, 1), 'bone_edge', 35, 12, 6))
    parts.append(sweep('Low bone sight', [(152, 63, 16), (155, 57, 14)], [1.5, 1.5], 'brass_edge', 10))
    return parts


def pose_point(point, frame):
    x, y, d = point
    c, s = math.cos(math.radians(ROLL[frame])), math.sin(math.radians(ROLL[frame]))
    x, y = x-MUZZLE[0], y-MUZZLE[1]
    return (MUZZLE[0]+c*x-s*y, MUZZLE[1]+s*x+c*y, d)


def world(point):
    x, y, depth = point
    return (x/80, depth/80, (200-y)/80)


def fresh_output(path, owned):
    path, owned = Path(path), Path(owned)
    if not path.is_absolute() or not owned.is_absolute() or path.resolve() != path or owned.resolve() != owned:
        raise ValueError('Output must use canonical absolute paths without symlink aliases')
    if not path.is_relative_to(owned) or path == owned or path.exists():
        raise ValueError('Output must be a fresh descendant of the explicit owned job root')
    return path


def build(repo, output, owned):
    output = fresh_output(output, owned)
    if output.is_relative_to(repo) or repo.is_relative_to(output):
        raise ValueError('Native output must be separate from the read-only source repository')
    helper_path = repo/'tools/build_art.py'
    if sha(helper_path) != HELPER_SHA:
        raise ValueError('Shared helper drift; parent must review/re-pin before native run')
    reference = Path(__file__).resolve().parents[1]/'source/art/references/rivet-pistol-reference-v2.png'
    if sha(reference) != REFERENCE_SHA:
        raise ValueError('Selected reference drift')
    import bpy
    from mathutils import Matrix, Vector
    from bpy_extras.object_utils import world_to_camera_view
    if bpy.app.version[:3] != (5, 2, 2):
        raise ValueError('Expected Blender 5.2.2')
    spec = importlib.util.spec_from_file_location('rivet_shared_art', helper_path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    output.mkdir(parents=True, exist_ok=False)
    helper.ART, helper.OUT, helper.SCRATCH = output/'source/art', output/'game/assets/art', output/'previews'
    scene = helper.setup()
    scene.render.threads = 2
    scene.cycles.samples = 16
    scene.cycles.seed = 35
    for name in PALETTE:
        helper.M[name] = weathered_material(helper, name)
    parts = geometry()
    groups, originals = [], []
    for frame, name in enumerate(FRAMES):
        group = bpy.data.collections.new(name)
        scene.collection.children.link(group)
        for i, part in enumerate(parts):
            if frame == 0:
                obj = helper.mesh(part['name'], [world(p) for p in part['vertices']], part['faces'], part['material'])
                for polygon in obj.data.polygons:
                    polygon.use_smooth = 'Glove' in part['name'] or 'Forearm dark' in part['name']
                for collection in list(obj.users_collection):
                    collection.objects.unlink(obj)
                originals.append(obj)
            else:
                obj = originals[i].copy()
            obj.name = f'{name} / {part["name"]}'
            group.objects.link(obj)
            # Linked editable meshes; one coherent camera and muzzle-pivoted pose.
            pivot = Vector(world(MUZZLE))
            obj.matrix_world = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(ROLL[frame]), 4, 'Y') @ Matrix.Translation(-pivot)
        groups.append(group)
    helper.camera(scene, (2, -6, 1.25), (2, 0, 1.25), 4, 320, 200)
    scene.camera.data.sensor_fit = 'HORIZONTAL'
    bpy.context.view_layer.update()
    for frame, group in enumerate(groups):
        for point in (MUZZLE, (270, 192, 3)):
            projected = world_to_camera_view(scene, scene.camera, group.objects[0].matrix_world @ Vector(world(point)))
            expected = pose_point(point, frame)
            if abs(projected.x*320-expected[0]) > .05 or abs((1-projected.y)*200-expected[1]) > .05:
                raise ValueError('Native camera/pose projection differs from pre-native framing')
    # House camera lights are retained; only the fill is reduced for dark separation.
    for obj in scene.objects:
        if obj.type == 'LIGHT' and obj.name == 'Cold surgical rim':
            obj.data.energy = 450
    cells = []
    for group in groups:
        for collection in groups:
            collection.hide_render = collection != group
        cells.append(helper.pixels_render(scene, f'rivet_pistol_v2_{group.name}', 320, 200))
    pixel_bounds = []
    for cell in cells:
        alpha = cell[3::4]
        if set(alpha) != {0, 255} or sum(a != 0 for a in alpha) < 5000:
            raise ValueError('Native hard-alpha silhouette is missing or too thin')
        occupied = [(i%320, i//320) for i, a in enumerate(alpha) if a]
        bounds = [min(x for x, y in occupied), min(y for x, y in occupied), max(x for x, y in occupied), max(y for x, y in occupied)]
        if bounds[1] < 45 or bounds[2] > 318 or bounds[3] != 199:
            raise ValueError(f'Native framing escaped aim/right/wrist contract: {bounds}')
        pixel_bounds.append(bounds)
    if len(set(map(bytes, cells))) != 3:
        raise ValueError('Native poses must differ')
    atlas = helper.atlas('rivet_pistol_v2', cells, 3, 1, 320, 200)
    # Native-size sheet: same rendered bytes on light and dark, no fake HUD values.
    contact = bytearray(960*400*4)
    for row, background in enumerate(((22, 24, 28, 255), (142, 138, 127, 255))):
        for frame, cell in enumerate(cells):
            for y in range(200):
                for x in range(320):
                    src = (y*320+x)*4
                    dst = ((row*200+y)*960+frame*320+x)*4
                    contact[dst:dst+4] = cell[src:src+4] if cell[src+3] else bytes(background)
    helper.png(helper.SCRATCH/'rivet_pistol_v2_native_contact.png', 960, 400, contact)
    for collection in groups:
        collection.hide_render = collection != groups[0]
        collection.hide_viewport = collection != groups[0]
    source = helper.save('rivet_pistol_v2')
    with source.open('rb') as file:
        header = file.read(7)
    if header != b'BLENDER' or source.stat().st_size > 20*1024*1024:
        raise ValueError('Editable uncompressed source exceeded contract')
    if atlas.stat().st_size > 300*1024:
        raise ValueError('Runtime atlas exceeded contract')
    triangles = sum(len(face)-2 for part in parts for face in part['faces'])
    entry = {'id': 'rivet_pistol', 'source': 'source/art/rivet_pistol_v2.blend', 'source_sha256': sha(source),
        'outputs': [{'path': 'game/assets/art/weapons/rivet_pistol.png', 'sha256': sha(atlas), 'bytes': atlas.stat().st_size, 'dimensions': [960, 200]}],
        'provenance': {'method': 'original primitive Blender geometry and editable procedural material nodes', 'render_method': 'native CPU orthographic render, quantized nearest RGBA sprites', 'authoring_script': 'tools/build_rivet_pistol_v2.py', 'imports': [], 'license': 'Original NULL CHOIR project art',
            'references': [{'path': 'source/art/references/rivet-pistol-reference-v2.png', 'sha256': REFERENCE_SHA}]},
        'recipe_sha256': sha(Path(__file__)), 'recipe_dependencies': {'tools/build_art.py': HELPER_SHA},
        'cell_size': [320, 200], 'columns': 3, 'frames': list(FRAMES), 'pose_collections': list(FRAMES),
        'origin_px': [160, 200], 'anchor': 'Existing HUD320x200 at180,143; local muzzle140,62 before sway/recoil', 'filter': 'nearest',
        'unique_mesh_triangles': triangles, 'pose_triangles': dict.fromkeys(FRAMES, triangles), 'muzzle_px': [140, 62], 'texture_atlas': None,
        'pose_pixel_bounds': dict(zip(FRAMES, pixel_bounds)), 'physical_bounds_m': helper.bounds([obj for group in groups for obj in group.objects])}
    (output/'manifest-entry-proposal.json').write_text(json.dumps(entry, indent=2)+'\n')
    (output/'native-resource-receipt.json').write_text(json.dumps({'source_bytes': source.stat().st_size, 'runtime_bytes': atlas.stat().st_size,
        'mesh_parts': len(parts), 'unique_triangles': triangles, 'blender_version': bpy.app.version_string, 'device': 'CPU', 'threads': scene.render.threads,
        'candidate_runtime_sibling': str(atlas), 'promotion_runtime_target': entry['outputs'][0]['path']}, indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--owned-job-root', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    build(args.repo.resolve(), args.output_root, args.owned_job_root)
