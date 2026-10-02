"""Original Intake art. Run: blender -b -t 4 --python tools/build_art.py -- [--asset ID]."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
import zlib

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'source/art'
OUT = ROOT / 'game/assets/art'
SCRATCH = ROOT / 'builds/art'
PALETTE = {'burgundy': '#713d48', 'ivory': '#d1ba8f', 'petrol': '#172e32',
           'amber': '#e9a347', 'scar': '#aa6763', 'iron': '#536265', 'black': '#12151b'}
FRAMES = ['idle', 'walk_a', 'walk_b', 'attack', 'dead']
IDS = ['crawler', 'worker', 'impact_tool', 'rivet_pistol', 'skin_bell',
       'siphon_heart', 'ribbed_wall', 'conduit', 'arch', 'floor', 'grate', 'wall',
       'vault_span', 'lumen_sconce', 'witness_relief', 'suspended_cadaver',
       'containment_capsule', 'drain_altar']
M = {}


def target(path):
    path = path.resolve()
    assert any(path.is_relative_to(p.resolve()) for p in (ART, OUT, SCRATCH)), path
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(hexcolor):
    return tuple(int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5)) + (1,)


def png(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\0' + bytes(pixels[y * width * 4:(y + 1) * width * 4]) for y in range(height))
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    target(path).write_bytes(data + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def texture(kind):
    """Authored 64px tiles: riveted seams, alternating grate slots and cut floor slabs."""
    rng = random.Random({'floor': 110, 'grate': 111, 'wall': 112}[kind])
    pixels = bytearray()
    for y in range(64):
        for x in range(64):
            noise = rng.randrange(-7, 8)
            if kind == 'floor':
                seam = x % 32 < 2 or y % 32 < 2
                color = (25, 33, 35) if seam else (67 + noise, 72 + noise, 69 + noise)
                if (x + y * 3) % 53 == 0 and not seam:
                    color = (112, 91, 72)
            elif kind == 'grate':
                slot = x % 8 in (2, 3, 4) and y % 32 not in (0, 1, 30, 31)
                color = (9, 17, 20) if slot else (90 + noise, 93 + noise, 80 + noise)
                if x % 8 == 1 and not slot:
                    color = (137, 133, 108)
            else:
                seam = x % 32 < 2 or y % 32 < 2
                color = (27, 25, 30) if seam else (86 + noise, 54 + noise, 60 + noise)
                if (x % 32 in (4, 27)) and (y % 32 in (4, 27)):
                    color = (174, 142, 96)
                if x % 32 == 2 and not seam:
                    color = (126, 82, 80)
            pixels.extend((*color, 255))
    path = OUT / 'textures' / f'{kind}.png'
    png(path, 64, 64, pixels)
    image = bpy.data.images.load(str(path), check_existing=True)
    image.pack()
    return image, pixels


def material(name, color, metal=0, rough=.7, image=None, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba(color)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = rgba(color)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    if image:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image, tex.interpolation = image, 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    if emission:
        shader.inputs['Emission Color'].default_value = rgba(color)
        shader.inputs['Emission Strength'].default_value = emission
    return mat


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.render.threads_mode, scene.render.threads = 'FIXED', 4
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_percentage = 100
    scene.render.filter_size = .1
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.world = bpy.data.worlds.new('Petrol ambient')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.14, .18, .2, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .45
    M.clear()
    M.update({
        'bone': material('Warm ivory ossification', PALETTE['ivory'], rough=.62),
        'skin': material('Bruised burgundy membrane', PALETTE['burgundy'], rough=.58),
        'scar': material('Suture scar and cartilage', PALETTE['scar'], rough=.65),
        'iron': material('Petrol industrial iron', PALETTE['petrol'], .6, .5),
        'steel': material('Worn rivet steel', PALETTE['iron'], .5, .55),
        'black': material('Deep socket and suture', PALETTE['black']),
        'amber': material('Sick amber lumen', PALETTE['amber'], emission=.6),
    })
    return scene


def finish(obj, name, mat):
    obj.name = name
    obj.data.materials.append(M[mat])
    return obj


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


def egg(name, pos, scale, mat='skin', segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)


def box(name, pos, size, mat='iron', bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Machined bevel', 'BEVEL')
        modifier.width, modifier.segments = bevel, 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat)


def tube(name, points, radii, mat='bone', sides=8):
    """Explicit swept geometry; taper, bends and hooks are editable mesh rings."""
    points = [Vector(p) for p in points]
    if isinstance(radii, (float, int)):
        radii = [radii] * len(points)
    verts, faces = [], []
    for i, p in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        axis = Vector((0, 0, 1)) if abs(tangent.z) < .9 else Vector((1, 0, 0))
        u = tangent.cross(axis).normalized()
        v = tangent.cross(u).normalized()
        for j in range(sides):
            angle = j * 2 * math.pi / sides
            verts.append(p + radii[i] * (u * math.cos(angle) + v * math.sin(angle)))
        if i:
            for j in range(sides):
                a, b = (i - 1) * sides + j, (i - 1) * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(reversed(range(sides))), tuple(range((len(points) - 1) * sides, len(points) * sides))])
    return mesh(name, verts, faces, mat)


def ring(name, center, radius, thickness, mat='bone', plane='XY', segments=24):
    cx, cy, cz = center
    pts = []
    for i in range(segments + 1):
        a = i * 2 * math.pi / segments
        p, q = radius * math.cos(a), radius * math.sin(a)
        pts.append((cx + p, cy + q, cz) if plane == 'XY' else (cx + p, cy, cz + q) if plane == 'XZ' else (cx, cy + p, cz + q))
    return tube(name, pts, thickness, mat)


def joint(name, p, radius=.11):
    egg(name, p, (radius, radius, radius), 'bone', 10, 6)
    ring(name + ' collar', p, radius * 1.05, radius * .2, 'iron', segments=12)


def stitches(name, points, axis=(.07, 0, 0)):
    d = Vector(axis)
    for i, p in enumerate(points):
        p = Vector(p)
        tube(f'{name} {i:02}', [p - d, p + Vector((0, -.035, .025)), p + d], .014, 'black', 5)


def camera(scene, pos, aim, scale, width, height):
    data = bpy.data.cameras.new('Pixel orthographic camera')
    obj = bpy.data.objects.new('Pixel orthographic camera', data)
    scene.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector(aim) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    data.type, data.ortho_scale = 'ORTHO', scale
    scene.camera = obj
    scene.render.resolution_x, scene.render.resolution_y = width, height
    for name, location, color, power, size in [
        ('Ivory key', (-3, -5, 7), (1, .83, .65), 900, 4),
        ('Cold surgical rim', (4, 2, 6), (.36, .68, .72), 1150, 3),
        ('Amber lower fill', (-3, 1, 2), (1, .48, .18), 350, 3),
    ]:
        light = bpy.data.lights.new(name, 'AREA')
        light.energy, light.color, light.shape, light.size = power, color, 'DISK', size
        item = bpy.data.objects.new(name, light)
        scene.collection.objects.link(item)
        item.location = location
        item.rotation_euler = (Vector(aim) - item.location).to_track_quat('-Z', 'Y').to_euler()
    return obj


def pixels_render(scene, name, width, height):
    path = target(SCRATCH / 'frames' / f'{name}.png')
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(str(path), check_existing=False)
    values = list(image.pixels[:])
    result = bytearray(width * height * 4)
    # Native resolution; quantized channels and hard coverage, never smooth-upscaled artwork.
    for y in range(height):
        for x in range(width):
            src, dst = ((height - 1 - y) * width + x) * 4, (y * width + x) * 4
            if values[src + 3] >= .5:
                result[dst:dst + 4] = bytes([min(255, round(values[src + k] * 31) * 8) for k in range(3)] + [255])
    bpy.data.images.remove(image)
    return result


def atlas(name, cells, columns, rows, width, height):
    result = bytearray(width * columns * height * rows * 4)
    for i, cell in enumerate(cells):
        for y in range(height):
            dst = (((i // columns) * height + y) * columns * width + (i % columns) * width) * 4
            result[dst:dst + width * 4] = cell[y * width * 4:(y + 1) * width * 4]
    path = OUT / ('sprites' if name in ('crawler', 'worker') else 'weapons') / f'{name}.png'
    png(path, width * columns, height * rows, result)
    # Contact sheet has a dark backdrop and 2x nearest scale for inspection only.
    preview = bytearray()
    for y in range(height * rows):
        row = bytearray()
        for x in range(width * columns):
            p = (y * width * columns + x) * 4
            color = result[p:p + 4] if result[p + 3] else bytes((24, 28, 34, 255))
            row.extend(color * 2)
        preview.extend(row * 2)
    png(SCRATCH / f'{name}_contact.png', width * columns * 2, height * rows * 2, preview)
    return path


def save(name):
    path = target(ART / f'{name}.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=False, check_existing=False)
    return path


def bounds(objects):
    points = [o.matrix_world @ Vector(corner) for o in objects if o.type == 'MESH' for corner in o.bound_box]
    lo, hi = [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]
    return {'min': [round(v, 3) for v in lo], 'max': [round(v, 3) for v in hi],
            'size': [round(hi[i] - lo[i], 3) for i in range(3)], 'axes': 'Blender XYZ, Z up; GLB/Godot Y up'}


def record(name, source, paths, **extra):
    outputs = []
    for path, dimensions in paths:
        entry = {'path': str(path.relative_to(ROOT)), 'sha256': sha(path), 'bytes': path.stat().st_size}
        if dimensions:
            entry['dimensions'] = dimensions
        outputs.append(entry)
    return {'id': name, 'source': str(source.relative_to(ROOT)), 'source_sha256': sha(source),
            'recipe_sha256': sha(Path(__file__)),
            'outputs': outputs, 'provenance': {'method': 'original Blender geometry and authored pixel textures',
            'authoring_script': 'tools/build_art.py', 'imports': [], 'license': 'Original NULL CHOIR project art'}, **extra}


def pose_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def move_to(coll, objects):
    for obj in objects:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        coll.objects.link(obj)


def crawler(pose):
    existing = set(bpy.context.scene.objects)
    crouch = {'idle': 0, 'walk_a': .07, 'walk_b': -.04, 'attack': .22, 'dead': -.44}[pose]
    z = .82 + crouch
    egg('Segmented carrion thorax', (0, .18, z), (.53, .87, .35), 'skin')
    egg('Exposed ventral wound', (0, -.25, z - .18), (.34, .57, .12), 'scar')
    for i in range(9):
        y = -.45 + i * .155
        rib = .47 * math.sin((i + 1) * math.pi / 11)
        tube(f'Exposed surgical rib {i}', [(-rib, y, z - .02), (-rib * .9, y, z + .19), (0, y - .045, z + .37), (rib * .9, y, z + .19), (rib, y, z - .02)], [.035, .055, .07, .055, .035])
        egg(f'Dorsal vertebra {i}', (0, y, z + .35), (.105, .075, .055), 'bone', 10, 6)
    head_y = -.93 - (.23 if pose == 'attack' else 0)
    egg('Hook crowned jaw', (0, head_y, z + .05), (.34, .37, .23), 'bone')
    egg('Hollow facial cavity', (0, head_y - .29, z + .10), (.23, .12, .155), 'black')
    # An absent face framed by teeth, rather than a recognizable imported skull.
    for side in (-1, 1):
        for i in range(4):
            x = side * (.07 + i * .055)
            tube(f'Crown hook {side} {i}', [(x, head_y + .05, z + .23), (x * 1.65, head_y + .12, z + .57 + i * .04), (x * 2.1, head_y -.03, z + .7 + i * .04), (x * 1.7, head_y - .23, z + .57)], [.08, .06, .038, .005])
        egg(f'Amber suture eye {side}', (side * .22, head_y - .28, z + .18), (.045, .045, .035), 'amber', 8, 4)
        tube(f'Mandibular hook {side}', [(side * .26, head_y, z - .08), (side * .40, head_y - .29, z - .21), (side * .31, head_y - .58, z - .08), (side * .18, head_y - .57, z + .08)], [.08, .055, .04, .003])
    for i in range(6):
        x = (i - 2.5) * .065
        tube(f'Surgical mouth tooth {i}', [(x, head_y - .36, z + .02), (x, head_y - .43, z - .11)], [.027, .002])
    for side in (-1, 1):
        for i in range(4):
            y = -.5 + i * .43
            phase = (1 if (i + (side == 1)) % 2 else -1) * {'idle': 0, 'walk_a': .22, 'walk_b': -.22, 'attack': -.35, 'dead': .34}[pose]
            hip = (side * .38, y, z)
            knee = (side * (.72 + i * .06), y + .17 + phase, z + .05)
            wrist = (side * (1.01 + i * .06), y - .12 - phase, .26 if pose != 'dead' else .12)
            toe = (side * (.91 + i * .07), y - .4 - phase, .08)
            tube(f'Many jointed leg {side} {i}', [hip, knee, wrist, toe], [.095, .068, .044, .009], 'bone')
            joint(f'Knee pin {side} {i}', knee, .08)
            tube(f'Leg hydraulic tendon {side} {i}', [hip, (side * .7, y + phase, z - .15), wrist], .025, 'skin')
            tube(f'Grasp hook {side} {i}', [wrist, (side * 1.22, y - .3 - phase, .1), (side * 1.11, y - .48 - phase, .15)], [.04, .028, .003], 'iron')
    tube('Sutured carrion tail', [(0, .75, z), (.2, 1.2, z + .08), (.34, 1.45, z + .36), (.17, 1.67, z + .51)], [.22, .14, .085, .008], 'skin')
    stitches('Thorax sutures', [(.17, .1 + i * .16, z + .31) for i in range(5)])
    if pose == 'attack':
        tube('Extended barbed tongue', [(0, head_y - .38, z), (0, head_y - .7, z - .02), (.1, head_y - .96, z + .18)], [.06, .04, .005], 'scar')
    if pose == 'dead':
        for obj in list(bpy.context.scene.objects):
            if obj.type == 'MESH' and obj not in existing:
                obj.rotation_euler.y += .25
        egg('Ruptured abdomen', (.23, .2, .17), (.4, .45, .08), 'scar')


def worker(pose):
    existing = set(bpy.context.scene.objects)
    sway = {'idle': 0, 'walk_a': .08, 'walk_b': -.08, 'attack': -.08, 'dead': -.9}[pose]
    top = 2.8 + sway
    # Hollow tapering apron shell, ladder spine and an asymmetric crane limb.
    egg('Excavated torso membrane', (0, .08, 1.95 + sway), (.34, .24, .63), 'skin')
    for i in range(7):
        z = 1.53 + sway + i * .13
        width = .24 + .07 * math.sin(i * .5)
        tube(f'Ossified open rib {i}', [(-width, .06, z), (-width * 1.12, -.17, z + .09), (0, -.28, z + .12), (width * 1.12, -.17, z + .09), (width, .06, z)], .044)
        box(f'Vertebral rack {i}', (0, .31, z), (.14, .1, .09), 'bone', .015)
    egg('Hollow vertical face', (0, -.03, top), (.23, .19, .32), 'bone')
    egg('Deep faceless socket', (0, -.184, top + .03), (.14, .065, .22), 'black')
    for side in (-1, 1):
        tube(f'Cheek seam {side}', [(side * .17, -.17, top + .15), (side * .19, -.20, top - .1), (side * .11, -.16, top - .28)], .025, 'scar')
        tube(f'Raised industrial collar {side}', [(side * .12, .08, 2.48 + sway), (side * .41, .05, 2.62 + sway), (side * .48, -.04, 2.84 + sway)], [.13, .085, .006], 'bone')
    box('Amber slit inside socket', (0, -.25, top + .02), (.04, .018, .12), 'amber')
    # Patient tag suspended across the otherwise empty mouth.
    box('Riveted identification tab', (0, -.22, top - .23), (.16, .035, .09), 'steel', .01)
    for side in (-1, 1):
        stride = {'idle': 0, 'walk_a': .23 * side, 'walk_b': -.23 * side, 'attack': -.06 * side, 'dead': .4 * side}[pose]
        hip = (side * .19, .06, 1.40 + sway * .6)
        knee = (side * .24, stride, .76 + sway * .3)
        ankle = (side * .26, -stride, .19)
        tube(f'Stilt shin {side}', [hip, knee, ankle], [.13, .095, .07])
        joint(f'Knee clamp {side}', knee, .12)
        tube(f'Exposed shin cable {side}', [(side * .28, .12, 1.3 + sway * .5), (side * .33, stride + .07, .77), (side * .34, -stride, .22)], .022, 'black')
        box(f'Slotted steel boot {side}', (side * .26, -.13 - stride, .09), (.28, .43, .18), 'iron', .04)
        for i in range(3):
            box(f'Boot rib {side} {i}', (side * .26, -.27 - stride + i * .08, .17), (.30, .025, .03), 'steel')
    shoulder = (.39, .05, 2.38 + sway)
    elbow = (.90, .05, 1.9 + sway) if pose != 'attack' else (.83, -.18, 2.4 + sway)
    hand = (.82, -.38, 1.36 + sway) if pose != 'attack' else (.65, -.86, 2.38 + sway)
    tube('Asymmetric scaffold upper strut', [shoulder, elbow], [.16, .11], 'iron')
    tube('Scaffold parallel boom', [(.53, .15, 2.40 + sway), Vector(elbow) + Vector((.15, .1, 0))], .07, 'steel')
    tube('Rivet launcher arm', [elbow, hand], [.13, .09], 'steel')
    joint('Crane elbow pin', elbow, .17)
    for i in range(4):
        pos = Vector(elbow).lerp(Vector(hand), i / 4)
        ring(f'Arm pressure collar {i}', pos, .145, .025, 'bone', 'XZ', 12)
    barrel_end = Vector(hand) + Vector((0, -.32, .04))
    tube('Integrated rivet barrel', [hand, barrel_end], .09, 'iron', 10)
    ring('Rivet muzzle', barrel_end, .095, .025, 'bone', 'XZ', 12)
    egg('Black rivet bore', barrel_end, (.06, .015, .06), 'black')
    tube('Arc of launcher cable', [shoulder, (.65, .38, 2.2 + sway), (1.12, .35, 1.65 + sway), hand], .055, 'skin')
    for i in range(5):
        box(f'Shoulder rack rivet {i}', (.35 + i * .10, .12, 2.5 + sway), (.045, .08, .16), 'bone')
    # The opposite arm is thin, dangling and clawed, visibly unlike the launcher.
    tube('Left skeletal hanging arm', [(-.39, .03, 2.38 + sway), (-.57, -.02, 1.86 + sway), (-.5, -.15, 1.3 + sway)], [.085, .065, .035])
    for i in range(4):
        tube(f'Long hanging finger {i}', [(-.50 + i * .025, -.15, 1.31 + sway), (-.63 + i * .06, -.21, 1.07 + sway), (-.59 + i * .05, -.29, 1.00 + sway)], [.025, .018, .003])
    stitches('Belly seam', [(0, -.255, 1.49 + sway + i * .09) for i in range(7)])
    if pose == 'attack':
        egg('Pressure lumen flare', barrel_end + Vector((0, -.08, 0)), (.12, .10, .12), 'amber', 8, 4)
    if pose == 'dead':
        # Collapse the full articulated figure, not merely its material.
        for obj in list(bpy.context.scene.objects):
            if obj.type == 'MESH' and obj not in existing:
                obj.location.z *= .4
                obj.scale.z *= .4
                obj.location.x += .3 * obj.location.z
        egg('Collapsed membrane spill', (0, 0, .06), (.55, .38, .055), 'skin')


def build_enemy(name):
    scene = setup()
    groups = []
    all_objects = []
    for pose in FRAMES:
        before = set(scene.objects)
        (crawler if name == 'crawler' else worker)(pose)
        objects = [o for o in scene.objects if o not in before]
        group = pose_collection(pose)
        move_to(group, objects)
        groups.append(group)
        all_objects.extend(objects)
    cam = camera(scene, (0, -10, 3.5), (0, 0, 1.18 if name == 'crawler' else 1.45), 3.8 if name == 'crawler' else 3.65, 128, 128)
    cells = []
    for row, group in enumerate(groups):
        for coll in groups:
            coll.hide_render = coll != group
        for column in range(8):
            angle = math.radians(column * 45)
            height = 3.5
            cam.location = (10 * math.sin(angle), -10 * math.cos(angle), height)
            aim_z = 1.18 if name == 'crawler' else 1.45
            cam.rotation_euler = (Vector((0, 0, aim_z)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
            cell = pixels_render(scene, f'{name}_{row}_{column}', 128, 128)
            # Feet (or collapsed body) share an exact baseline in every direction and pose.
            bottom = max(y for y in range(128) if any(cell[(y * 128 + x) * 4 + 3] for x in range(128)))
            aligned = bytearray(128 * 128 * 4)
            for y in range(128):
                dest_y = y + 119 - bottom
                if 0 <= dest_y < 128:
                    aligned[dest_y * 512:(dest_y + 1) * 512] = cell[y * 512:(y + 1) * 512]
            cells.append(aligned)
        print(f'ART_CHECKPOINT {name} {group.name} rendered', flush=True)
    path = atlas(name, cells, 8, 5, 128, 128)
    for coll in groups:
        coll.hide_render = coll != groups[0]
        coll.hide_viewport = coll != groups[0]
    cam.location = (0, -10, 3.5)
    cam.rotation_euler = (Vector((0, 0, 1.18 if name == 'crawler' else 1.45)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    source = save(name)
    return record(name, source, [(path, [1024, 640])], cell_size=[128, 128], columns=8, frames=FRAMES,
                  yaw_degrees=list(range(0, 360, 45)), facing='column0 sees front (-Y); camera orbits clockwise viewed from +Z, column2 sees right (+X)',
                  origin_px=[64, 120], filter='nearest', physical_bounds_m=bounds(all_objects), pose_collections=FRAMES)


def technician_hand(side, pose, biological=False):
    x = .5 * side
    recoil = .06 if pose == 'fire' else -.03 if pose == 'recover' else 0
    egg(f'{side} technician sleeve', (x, -1.35, .26 + recoil), (.23, .38, .22), 'iron')
    ring(f'{side} cuff clamp', (x, -1.02, .28 + recoil), .21, .042, 'steel', 'XZ', 16)
    egg(f'{side} worn glove', (x, -.88, .28 + recoil), (.17, .24, .13), 'skin' if biological else 'bone')
    for i in range(4):
        tube(f'{side} jointed glove finger {i}', [(x - .12 + i * .08, -.96, .36 + recoil), (x - .11 + i * .07, -.74, .38 + recoil), (x - .10 + i * .06, -.68, .26 + recoil)], [.039, .035, .02], 'scar' if biological else 'bone')
    for i in range(3):
        box(f'{side} glove knuckle inset {i}', (x -.07 + i * .07, -.9, .4 + recoil), (.05, .065, .025), 'iron', .007)
    tube(f'{side} glove thumb', [(x + side * .12, -.98, .3 + recoil), (x + side * .18, -.79, .28 + recoil), (x + side * .07, -.68, .25 + recoil)], .045, 'bone')
    stitches(f'{side} cuff sutures', [(x, -1.11 - i * .05, .46 + recoil) for i in range(5)])
    if biological:
        tube('First exposed wrist tendon', [(x + .15, -1.34, .35), (x + .18, -1.07, .45), (x + .1, -.93, .41)], [.025, .038, .016], 'scar')


def weapon(name, pose):
    lift = .12 if pose == 'fire' else -.045 if pose == 'recover' else 0
    if name == 'impact_tool':
        technician_hand(-1, pose)
        technician_hand(1, pose, True)
        tube('Double grip torsion handle', [(-.5, -.72, .25 + lift), (0, -.42, .35 + lift), (.5, -.72, .25 + lift)], .095, 'iron', 10)
        for side in (-1, 1):
            for i in range(6):
                ring(f'Tool grip collar {side} {i}', (side * (.26 + i * .035), -.6, .27 + lift), .095, .019, 'steel', 'YZ', 12)
        box('Impact ram actuator housing', (0, -.20, .40 + lift), (.48, .7, .40), 'iron', .075)
        box('Bone ceramic insulating plate', (0, -.31, .64 + lift), (.37, .4, .05), 'bone', .016)
        tube('Hydraulic impact piston', [(0, .02, .40 + lift), (0, .55, .45 + lift)], .13, 'steel', 12)
        # A forked broad impact crown, not a pistol-shaped barrel.
        for side in (-1, 1):
            tube(f'Forked impact claw {side}', [(side * .12, .24, .44 + lift), (side * .34, .52, .44 + lift), (side * .3, .79, .52 + lift)], [.1, .09, .045], 'bone')
        box('Hammer strike pad', (0, .63, .43 + lift), (.38, .16, .20), 'steel', .025)
        for i in range(4):
            box(f'Actuator vent {i}', (-.248, -.35 + i * .12, .42 + lift), (.015, .055, .2), 'black')
        ring('Pressure dial frame', (.16, -.38, .682 + lift), .085, .012, 'steel', 'XY', 16)
        egg('Pressure amber dial', (.16, -.38, .685 + lift), (.07, .07, .007), 'amber', 12, 4)
        tube('Impact hydraulic hose', [(-.17, -.5, .3 + lift), (-.37, -.58, .2), (-.58, -.28, .27), (-.2, .05, .4 + lift)], .037, 'skin')
        if pose == 'fire':
            for side in (-1, 1):
                tube(f'Impact electric arc {side}', [(side * .26, .75, .52), (side * .37, .88, .65), (side * .22, 1.02, .63)], [.023, .018, .002], 'amber', 5)
    else:
        technician_hand(1, pose, True)
        egg('Support technician forearm', (-.28, -1.23, .15), (.21, .32, .18), 'iron')
        egg('Left bracing glove', (-.2, -.73, .23), (.17, .24, .12), 'bone')
        for i in range(4):
            tube(f'Bracing curled finger {i}', [(-.31 + i * .08, -.89, .29), (-.28 + i * .08, -.63, .35), (-.23 + i * .07, -.54, .26)], .034, 'bone')
        box('Angled grip', (.28, -.73, .31 + lift), (.18, .3, .38), 'iron', .035)
        box('Pistol rivet receiver', (.18, -.36, .54 + lift), (.32, .85, .3), 'iron', .045)
        box('Receiver worn ivory spine', (.18, -.33, .70 + lift), (.24, .62, .045), 'bone', .01)
        tube('Long rivet muzzle', [(.18, -.03, .57 + lift), (.18, .84, .6 + lift)], .087, 'steel', 12)
        for i in range(5):
            ring(f'Muzzle heat collar {i}', (.18, .1 + i * .135, .58 + lift), .104, .023, 'iron', 'XZ', 12)
        ring('Muzzle surgical lip', (.18, .84, .6 + lift), .105, .025, 'bone', 'XZ', 16)
        tube('Pistol rear aperture', [(.18, -.6, .71 + lift), (.18, -.55, .82 + lift)], .035, 'steel')
        box('Front sight amber bead', (.18, .63, .735 + lift), (.033, .033, .04), 'amber')
        tube('Magazine manifold', [(-.08, -.45, .47 + lift), (-.2, -.27, .52 + lift), (-.25, -.18, .61 + lift)], .08, 'steel')
        for i in range(5):
            tube(f'Exposed magazine rivet {i}', [(-.28, -.5 + i * .1, .48 + lift), (-.28, -.5 + i * .1, .69 + lift)], [.037, .014], 'bone')
        tube('Vein within trigger hose', [(.34, -.58, .36), (.51, -.49, .43), (.4, -.28, .52 + lift)], .027, 'scar')
        if pose == 'fire':
            # Side flare stays below the screen-center sight line.
            tube('Side pressure flash', [(.3, .76, .56 + lift), (.47, .88, .52 + lift), (.54, 1.08, .48 + lift)], [.08, .055, .003], 'amber')


def build_weapon(name):
    scene = setup()
    groups, all_objects = [], []
    for pose in ('idle', 'fire', 'recover'):
        before = set(scene.objects)
        weapon(name, pose)
        objects = [o for o in scene.objects if o not in before]
        group = pose_collection(pose)
        move_to(group, objects)
        groups.append(group)
        all_objects.extend(objects)
    camera(scene, (0, -3.4, 2.4), (0, .3, .95), 2.65, 320, 200)
    cells = []
    for group in groups:
        for coll in groups:
            coll.hide_render = coll != group
        cells.append(pixels_render(scene, f'{name}_{group.name}', 320, 200))
    path = atlas(name, cells, 3, 1, 320, 200)
    for coll in groups:
        coll.hide_render = coll != groups[0]
        coll.hide_viewport = coll != groups[0]
    source = save(name)
    return record(name, source, [(path, [960, 200])], cell_size=[320, 200], columns=3,
                  frames=['idle', 'fire', 'recover'], origin_px=[160, 200], anchor='bottom center of 320x200 overlay; aim is screen-center above muzzle',
                  filter='nearest', physical_bounds_m=bounds(all_objects), pose_collections=['idle', 'fire', 'recover'])


def bell():
    # An actual thin, open-bottom bell of sutured tissue with a cartilage aperture.
    verts, faces = [], []
    profile = [(2.15, 2.05), (2.30, 2.18), (2.6, 1.96), (3.15, 1.61), (3.8, 1.25), (4.55, .9), (5.15, .64), (5.7, .34)]
    n = 48
    for row, (z, radius) in enumerate(profile):
        for i in range(n):
            a = i * 2 * math.pi / n
            r = radius + .055 * math.sin(a * 12 + row * .6)
            verts.append((r * math.cos(a), r * math.sin(a), z + .09 * math.sin(a * 7)))
            if row:
                a0, b0 = (row - 1) * n + i, (row - 1) * n + (i + 1) % n
                faces.append((a0, b0, b0 + n, a0 + n))
    membrane = mesh('Sutured hollow membrane bell', verts, faces, 'skin')
    solidify = membrane.modifiers.new('Membrane thickness', 'SOLIDIFY')
    solidify.thickness = .045
    bpy.context.view_layer.objects.active = membrane
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    ring('Scalloped cartilage rim', (0, 0, 2.21), 2.1, .16, 'scar', segments=48)
    ring('Ivory rim suture bead', (0, 0, 2.15), 2.05, .055, 'bone', segments=48)
    for i in range(12):
        angle = i * math.pi / 6
        points = [(r * math.cos(angle), r * math.sin(angle), z + .05) for z, r in profile]
        tube(f'Suspended exterior tendon {i:02}', points, [.055, .1, .11, .095, .08, .06, .045, .035], 'bone')
        for j in range(5):
            z, r = profile[j + 2]
            p = Vector((r * math.cos(angle + .07), r * math.sin(angle + .07), z))
            d = Vector((-.1 * math.sin(angle), .1 * math.cos(angle), .055))
            tube(f'Cross suture {i:02} {j}', [p - d, p, p + d], .021, 'black', 5)
    for i in range(8):
        angle = i * math.pi / 4
        # Crowned ribs reach an eight-meter suspension point, open enough to see tissue.
        tube(f'Radial skeletal suspension {i}', [(2.45 * math.cos(angle), 2.45 * math.sin(angle), .18),
              (2.7 * math.cos(angle), 2.7 * math.sin(angle), 3.2),
              (2.15 * math.cos(angle), 2.15 * math.sin(angle), 6.55),
              (.72 * math.cos(angle), .72 * math.sin(angle), 7.65), (0, 0, 8)], [.17, .12, .16, .11, .055], 'iron', 10)
        for z, r in ((.3, 2.45), (3.2, 2.7), (6.55, 2.15)):
            egg(f'Suspension cartilage joint {i} {z}', (r * math.cos(angle), r * math.sin(angle), z), (.24, .24, .24), 'bone', 12, 6)
        tube(f'Upper bone hook {i}', [(.75 * math.cos(angle), .75 * math.sin(angle), 6.1),
             (1.1 * math.cos(angle), 1.1 * math.sin(angle), 6.65), (.8 * math.cos(angle), .8 * math.sin(angle), 7.2),
             (.4 * math.cos(angle), .4 * math.sin(angle), 7.15)], [.13, .1, .06, .008], 'bone')
        tube(f'Taut suspension strand {i}', [(.7 * math.cos(angle), .7 * math.sin(angle), 7.6), (.3 * math.cos(angle), .3 * math.sin(angle), 5.7)], .03, 'scar')
    ring('Skeletal suspension halo', (0, 0, 6.7), 1.12, .10, 'bone', segments=32)
    for i in range(12):
        z = 1.22 + i * .33
        egg(f'Inner exposed tongue vertebra {i}', (0, 0, z), (.23 + .04 * math.sin(i), .25, .20), 'bone', 12, 6)
    tube('Inner fleshy tongue', [(0, 0, 5.4), (.18, 0, 3.8), (0, -.15, 2.1), (.25, -.2, 1.4)], [.12, .18, .3, .48], 'scar', 16)
    egg('Tongue amber node', (.25, -.2, 1.25), (.21, .24, .26), 'amber')
    for i in range(6):
        a = i * math.pi / 3
        tube(f'Rim hanging cartilage fringe {i}', [(1.95 * math.cos(a), 1.95 * math.sin(a), 2.2),
             (2.0 * math.cos(a), 2.0 * math.sin(a), 1.75), (1.83 * math.cos(a), 1.83 * math.sin(a), 1.53)], [.07, .05, .005], 'bone')
    # The suspension terminates in a real restraint dais, not floating stick feet.
    ring('Dais steel perimeter', (0, 0, .16), 3.08, .16, 'steel', segments=48)
    ring('Inner draining channel', (0, 0, .27), 2.40, .065, 'black', segments=48)
    box('Bell restraint foundation', (0, 0, .07), (4.6, 4.6, .14), 'iron', .06)
    for i in range(8):
        a = i * math.pi / 4
        u = Vector((math.cos(a), math.sin(a), 0))
        tube(f'Radial foundation shoe {i}', [u * 2.0 + Vector((0, 0, .18)), u * 3.08 + Vector((0, 0, .18))], .17, 'iron')
        for r in (2.48, 2.85):
            egg(f'Dais hold-down bolt {i} {r}', u * r + Vector((0, 0, .27)), (.10, .10, .055), 'bone', 8, 4)
        # Paired side tendons and lattice collars make the tall crown legible.
        for phase in (-1, 1):
            pts = []
            for j in range(17):
                t = j / 16
                theta = a + phase * .055 * math.sin(t * math.pi * 8)
                radius = 2.65 - .60 * t
                pts.append((radius * math.cos(theta), radius * math.sin(theta), .45 + t * 5.95))
            tube(f'Braided restraint tendon {i} {phase}', pts, .032, 'scar', 6)
        tube(f'Crown flying buttress {i}', [u * 2.12 + Vector((0, 0, 6.5)), u * 2.60 + Vector((0, 0, 7.12)),
             u * 2.25 + Vector((0, 0, 7.7)), u * 1.50 + Vector((0, 0, 7.78))], [.10, .07, .05, .009], 'bone')
        egg(f'Crown amber restraint seal {i}', u * 2.25 + Vector((0, 0, 6.5)), (.10, .10, .16), 'amber', 10, 6)
    ring('Eight point overhead restraint', (0, 0, 8.1), .65, .10, 'steel', segments=24)
    for i in range(24):
        a = i * math.pi / 12
        u = Vector((math.cos(a), math.sin(a), 0))
        tube(f'Dais comb tooth {i}', [u * 2.88 + Vector((0, 0, .24)), u * 2.68 + Vector((0, 0, .55)),
             u * 2.50 + Vector((0, 0, .62))], [.055, .04, .005], 'bone', 6)


def siphon():
    # A low, spreading manifold altar with a suspended anatomically abstract organ.
    box('Manifold altar foot', (0, 0, .16), (4.7, 3.5, .32), 'iron', .15)
    for side in (-1, 1):
        tube(f'Cradle vertebral upright {side}', [(side * 2.1, 0, .3), (side * 2.25, .1, 1.65),
             (side * 1.7, .12, 3.25), (side * .95, .1, 3.85)], [.22, .19, .14, .06])
        for i in range(6):
            joint(f'Cradle ossification {side} {i}', (side * (2.15 - i * .06), .08, .55 + i * .39), .17)
        tube(f'Vein-slung organ tether {side}', [(side * .95, .1, 3.85), (side * .45, 0, 3.48), (side * .32, -.1, 2.65)], [.075, .08, .05], 'scar')
    egg('Drained suspended heart upper left', (-.3, -.1, 2.68), (.56, .38, .55), 'skin')
    egg('Drained suspended heart upper right', (.31, -.02, 2.61), (.48, .36, .48), 'scar')
    tube('Tapered collapsed heart apex', [(0, -.1, 2.65), (.04, -.12, 2.1), (-.15, -.15, 1.7)], [.49, .31, .06], 'skin', 18)
    for i in range(9):
        z = 1.93 + i * .11
        width = .15 + i * .03
        tube(f'Visible heart coronary groove {i}', [(-width, -.42, z), (-.04, -.49, z -.06), (width, -.4, z + .08)], .02, 'black', 5)
    for i in range(7):
        z = 2.12 + i * .13
        tube(f'Heart cross-suture {i}', [(-.12, -.49, z), (.06, -.51, z + .045)], .024, 'bone', 6)
    # Braided large arteries feed a mechanical jaw valve on the front of the altar.
    for side in (-1, 1):
        for strand in range(3):
            points = []
            for j in range(25):
                t = j / 24
                angle = t * math.pi * 5 + strand * math.pi * 2 / 3
                x = side * (1.9 * (1 - t) + .65 * t) + .09 * math.cos(angle)
                y = .7 * math.sin(t * math.pi) + .11 * math.sin(angle)
                z = .45 + .8 * math.sin(t * math.pi) + .065 * math.cos(angle)
                points.append((x, y, z))
            tube(f'Braided manifold artery {side} {strand}', points, .11, 'skin' if strand != 1 else 'scar', 8)
        tube(f'Upper coronary siphon {side}', [(side * .22, .0, 3.08), (side * .65, .2, 3.33), (side * 1.25, .55, 2.6),
             (side * 1.75, .45, 1.05)], [.15, .13, .16, .13], 'skin', 12)
    box('Bite valve mechanical housing', (0, -1.12, .91), (1.65, .7, .88), 'steel', .09)
    box('Dark valve mouth', (0, -1.49, .95), (1.32, .05, .45), 'black')
    for side in (-1, 1):
        tube(f'Articulated valve jaw {side}', [(-.74, -1.55, .95 + side * .23), (0, -1.68, .95 + side * .27),
             (.74, -1.55, .95 + side * .23)], [.12, .13, .12], 'bone')
        for i in range(8):
            x = -.59 + i * .17
            tube(f'Valve bite tooth {side} {i}', [(x, -1.61, .95 + side * .23), (x, -1.66, .95 + side * .04)], [.06, .005], 'bone')
        joint(f'Valve hinge {side}', (side * .79, -1.22, .95), .21)
    tube('Drain throat below suspended organ', [(-.12, -.15, 1.74), (.10, -.6, 1.5), (0, -1.0, 1.28)], [.08, .16, .2], 'scar', 12)
    for side in (-1, 1):
        box(f'Amber manometer frame {side}', (side * 1.56, -1.1, 1.1), (.3, .22, .65), 'iron', .04)
        box(f'Amber manometer column {side}', (side * 1.56, -1.23, 1.14), (.1, .03, .42), 'amber')
    for i in range(8):
        box(f'Foot machine rib {i}', (-1.96 + i * .56, -1.35, .33), (.2, .4, .14), 'steel', .015)
    for side in (-1, 1):
        box(f'Manifold bolted pedestal {side}', (side * 2.12, 0, .26), (.62, 3.4, .52), 'iron', .08)
        for y in (-1.35, -.45, .45, 1.35):
            ring(f'Pedestal clamp washer {side} {y}', (side * 2.12, y, .54), .10, .025, 'steel', segments=12)
            box(f'Pedestal bolt {side} {y}', (side * 2.12, y, .56), (.09, .09, .07), 'bone', .015)
        for i in range(9):
            z = .9 + i * .28
            x = side * (2.14 - max(0, z - 1.5) * .30)
            tube(f'Cradle outward costal fin {side} {i}', [(x, .08, z), (x + side * .28, .1, z + .12),
                 (x + side * .35, -.13, z + .28), (x + side * .19, -.24, z + .34)], [.08, .075, .045, .008], 'bone')
        tube(f'Posterior arterial loop {side}', [(side * .25, .10, 2.98), (side * .55, .48, 3.75),
             (side * 1.12, .78, 4.05), (side * 1.5, .94, 3.45), (side * 1.3, .98, .5)], [.13, .15, .12, .11, .08], 'scar', 12)
        for i in range(5):
            z = 1.1 + i * .48
            ring(f'Arterial pressure cuff {side} {i}', (side * 1.3, .98, z), .15, .035, 'steel', segments=12)
        ring(f'Front pressure gauge rim {side}', (side * 1.32, -1.53, .72), .22, .038, 'bone', 'XZ', 20)
        egg(f'Front pressure gauge face {side}', (side * 1.32, -1.54, .72), (.19, .022, .19), 'black', 16, 6)
        tube(f'Gauge needle {side}', [(side * 1.32, -1.58, .72), (side * 1.32 + .10, -1.58, .82)], .018, 'amber', 5)
    for i in range(11):
        z = .62 + i * .29
        box(f'Rear ladder manifold vertebra {i}', (0, .9, z), (.36, .25, .14), 'steel', .035)
        for side in (-1, 1):
            tube(f'Rear capillary fan {side} {i}', [(0, .83, z), (side * (.4 + i * .03), .66, z + .13),
                 (side * (.9 + i * .045), .55, z + .05)], [.045, .035, .012], 'skin', 6)


def scenery(name):
    if name == 'vault_span':
        for side in (-1, 1):
            box(f'Vault pier shoe {side}', (side * 3.85, 0, .16), (.30, 1.2, .32), 'steel', .04)
            for depth in (-.40, .40):
                tube(f'Vault fluted load rib {side} {depth}', [(side * 3.86, depth, .3), (side * 3.86, depth, 2.1),
                     (side * 3.86, depth, 4.15), (side * 3.55, depth, 4.68), (side * 2.45, depth, 5.24),
                     (side * 1.1, depth, 5.70), (0, depth, 5.89)], [.10, .10, .12, .13, .12, .11, .10], 'bone', 10)
            for i in range(9):
                z = .6 + i * .40
                box(f'Pier vertebral collar {side} {i}', (side * 3.86, 0, z), (.27, .96, .12), 'iron', .03)
                box(f'Pier visible worn tab {side} {i}', (side * 3.86, -.50, z), (.18, .06, .08), 'bone', .015)
            for i in range(7):
                t = i / 7
                x, z = side * (3.60 * (1 - t)), 4.70 + 1.10 * t
                tube(f'Vault transverse vertebra {side} {i}', [(x, -.53, z), (x, -.30, z + .13),
                     (x, .30, z + .13), (x, .53, z)], [.065, .085, .085, .065], 'steel')
            tube(f'Peripheral rising vessel {side}', [(side * 3.88, -.28, .4), (side * 3.9, -.28, 3.6),
                 (side * 3.72, -.28, 4.3), (side * 2.5, -.28, 5.0), (0, -.28, 5.70)], .055, 'skin')
        box('Vault keystone restraint', (0, 0, 5.81), (.40, 1.08, .38), 'iron', .06)
        egg('Keystone amber marrow', (0, -.57, 5.8), (.10, .03, .13), 'amber', 12, 6)
    elif name == 'lumen_sconce':
        box('Wall fastening spine', (0, .15, 1), (.22, .08, 2), 'iron', .03)
        for z in (.15, 1.85):
            box(f'Sconce mount wing {z}', (0, .14, z), (1, .10, .17), 'steel', .03)
            for x in (-.4, .4):
                egg(f'Sconce ivory bolt {x} {z}', (x, .05, z), (.05, .035, .05), 'bone', 8, 4)
        tube('Vertical living amber lumen', [(0, -.20, .28), (.025, -.23, .5), (-.025, -.24, 1.0),
             (.02, -.23, 1.5), (0, -.20, 1.72)], [.06, .12, .13, .12, .055], 'amber', 16)
        for side in (-1, 1):
            tube(f'Ivory ogive cage {side}', [(0, -.18, .18), (side * .27, -.30, .45), (side * .40, -.26, 1),
                 (side * .27, -.30, 1.55), (0, -.18, 1.82)], [.08, .06, .055, .06, .08], 'bone')
            tube(f'Outer vascular brace {side}', [(side * .44, .08, .18), (side * .31, -.15, .65),
                 (side * .30, -.17, 1.40), (side * .44, .08, 1.82)], .025, 'skin', 6)
        for i in range(5):
            z = .48 + i * .26
            tube(f'Cage oblique suture {i}', [(-.27, -.25, z -.09), (0, -.385, z), (.27, -.25, z + .09)], .025, 'steel', 6)
        tube('Lumen black incision', [(-.01, -.35, .42), (-.035, -.37, .9), (.035, -.37, 1.4), (0, -.33, 1.6)], .018, 'black', 5)
    elif name == 'witness_relief':
        # A flayed wing-shaped shell with a missing face; this is wall anatomy, not a standing enemy.
        outline = [(-.6, 0), (-1.4, .45), (-1.75, 1.4), (-1.45, 2.9), (-.65, 4.15),
                   (-.2, 4.8), (.55, 4.55), (1.25, 3.45), (1.65, 2), (1.35, .6), (.5, .12)]
        mesh('Asymmetric iron witness backing', [(x, .2, z) for x, z in outline], [tuple(range(len(outline)))], 'iron')
        for side in (-1, 1):
            profile = [(.4, .3), (.9, .62), (1.5, 1.05), (2.2, 1.24), (2.85, 1.07), (3.35, .61), (3.65, .30)]
            verts, faces = [], []
            for i, (z, width) in enumerate(profile):
                asym = .12 * math.sin(z * 2) if side == 1 else 0
                for j in range(5):
                    t = j / 4
                    verts.append((side * (.10 + width * t) + asym, -.11 - .24 * math.sin(t * math.pi), z + side * .1 * t))
                    if i and j:
                        k = i * 5 + j
                        faces.append((k - 6, k - 5, k, k - 1))
            mesh(f'Stretched flayed thoracic wing {side}', verts, faces, 'skin')
            for i in range(13):
                z = .55 + i * .235
                w = .28 + .98 * math.sin((i + 1) * math.pi / 15)
                tube(f'Layered witness costal arch {side} {i}', [(side * .10, -.43, z), (side * .52, -.46, z + .17),
                     (side * w, -.33, z + .30), (side * (w + .12), -.02, z + .24)], [.045, .055, .04, .012], 'bone', 6)
                tube(f'Second laminar rib {side} {i}', [(side * .18, -.15, z + .06), (side * (w + .25), -.07, z + .15)], [.035, .013], 'scar', 6)
        verts, faces = [], []
        for layer, (rx, rz, y) in enumerate([(.42, .62, -.09), (.35, .54, -.43), (.20, .37, -.33)]):
            for i in range(24):
                a = i * math.pi / 12
                verts.append((.10 + rx * math.cos(a), y, 3.89 + rz * math.sin(a)))
                if layer:
                    k, q = (layer - 1) * 24 + i, (layer - 1) * 24 + (i + 1) % 24
                    faces.append((k, q, q + 24, k + 24))
        mesh('Excised faceless witness shell', verts, faces, 'bone')
        egg('Vacant face interior', (.10, -.05, 3.9), (.19, .07, .36), 'black', 16, 8)
        for i in range(17):
            z = .44 + i * .20
            box(f'Witness bifurcated spine {i}', (.035 * math.sin(i), -.39, z), (.16, .16, .11), 'steel', .025)
        for side in (-1, 1):
            tube(f'Pinned scapular tendon {side}', [(side * 1.65, .13, 1.0), (side * 1.45, -.10, 2.4),
                 (side * .65, -.13, 3.5), (.1, -.15, 4.55)], [.07, .05, .035, .008], 'scar')
            for i in range(6):
                egg(f'Witness amber restraint node {side} {i}', (side * (.38 + .10 * math.sin(i)), -.43, .85 + i * .40), (.045, .035, .075), 'amber', 8, 4)
        stitches('Pinned abdominal incision', [(.2, -.46, .7 + i * .15) for i in range(14)], (.09, 0, .025))
    elif name == 'suspended_cadaver':
        ring('Steel suspension apparatus', (0, 0, 2.72), .90, .08, 'steel', segments=32)
        ring('Ivory isolation liner', (0, 0, 2.70), .74, .045, 'bone', segments=32)
        box('Decommissioned ankle restraint', (0, -.05, .08), (.38, .40, .16), 'iron', .04)
        profile = [(.2, .16), (.5, .26), (.95, .35), (1.35, .46), (1.65, .47), (1.94, .32), (2.18, .10)]
        for i in range(10):
            a = i * math.pi / 5
            verts, faces = [], []
            for row, (z, r) in enumerate(profile):
                for edge in (-1, 1):
                    theta = a + edge * .22 + .13 * math.sin(z * 2)
                    verts.append((r * math.cos(theta), r * .78 * math.sin(theta), z))
                if row:
                    k = row * 2
                    faces.append((k - 2, k - 1, k + 1, k))
            mesh(f'Longitudinal burial membrane {i}', verts, faces, 'skin' if i % 3 else 'scar')
            tube(f'Cocoon longitudinal stitch rail {i}', [(r * math.cos(a), r * .78 * math.sin(a), z) for z, r in profile], .028, 'bone', 6)
        for i in range(13):
            z = .32 + i * .13
            box(f'Exposed technician spinal lock {i}', (.045 * math.sin(i), -.32, z), (.16, .10, .085), 'bone', .018)
            tube(f'Excised spinal root {i}', [(.02, -.33, z), ((-.22 if i % 2 else .22), -.35, z + .09)], [.028, .006], 'scar', 5)
        for i in range(6):
            a = i * math.pi / 3
            for strand in (-1, 1):
                pts = []
                for j in range(17):
                    t = j / 16
                    r = .32 + .54 * t
                    theta = a + strand * .06 * math.sin(t * math.pi * 6)
                    pts.append((r * math.cos(theta), r * math.sin(theta), 1.88 + 1.07 * t))
                tube(f'Braided ceiling tether {i} {strand}', pts, .032, 'steel' if strand == 1 else 'skin', 6)
        for i in range(8):
            z, r = .48 + i * .18, .29 + .15 * math.sin(i * .4)
            # Loose crossing restraints leave cutaways exposing the inner lock spine.
            tube(f'Diagonal mortuary binding {i}', [(-r, 0, z), (-r * .65, -.32, z + .09),
                 (r * .65, -.32, z + .21), (r, 0, z + .25)], .035, 'iron', 6)
        egg('Cadaver sealed lumen tag', (.12, -.39, 1.48), (.075, .025, .13), 'amber', 10, 6)
        box('Ceiling mounting cleat', (0, .05, 2.94), (.40, .40, .12), 'iron', .035)
    elif name == 'containment_capsule':
        box('Surgical reliquary foundation', (0, 0, .12), (2.2, 1.8, .24), 'iron', .08)
        box('Reliquary crown mounting cleat', (0, .36, 4.96), (.28, .36, .08), 'iron', .025)
        box('Inset sump beneath specimen', (0, -.13, .28), (1.4, 1.3, .12), 'black', .03)
        for side in (-1, 1):
            tube(f'Reliquary structural ogive {side}', [(side * .96, .36, .24), (side * .96, .36, 3.8),
                 (side * .77, .36, 4.45), (side * .4, .36, 4.82), (0, .36, 4.9)], [.12, .12, .10, .08, .06], 'steel', 10)
            tube(f'Anterior ivory lancet {side}', [(side * .84, -.58, .3), (side * .87, -.60, 2.8),
                 (side * .72, -.52, 4.0), (side * .32, -.37, 4.7), (0, -.30, 4.88)], [.08, .07, .09, .065, .015], 'bone')
            for i in range(16):
                z = .44 + i * .235
                tube(f'Capsule ribbed sidewall {side} {i}', [(side * .85, -.60, z), (side * 1.03, -.13, z + .08),
                     (side * 1.02, .47, z + .08), (side * .75, .75, z)], [.065, .06, .06, .045], 'iron')
                box(f'Capsule sidewall plate {side} {i}', (side * 1.015, .20, z), (.14, .34, .14), 'steel', .025)
            tube(f'Anterior amber index {side}', [(side * .72, -.66, .6), (side * .74, -.66, 3.6)], .025, 'amber', 6)
            tube(f'Surgical arterial feed {side}', [(side * .82, .45, .3), (side * .62, .64, 1.5),
                 (side * .23, .1, 2.5), (side * .18, -.02, 3.3)], [.09, .07, .05, .025], 'skin')
        for i in range(18):
            z = .63 + i * .175
            x = .06 * math.sin(i * .3)
            box(f'Preserved specimen vertebra {i}', (x, -.05, z), (.16, .19, .10), 'bone', .025)
            width = .13 + .30 * math.sin((i + 1) * math.pi / 20)
            for side in (-1, 1):
                tube(f'Hollow specimen branch {side} {i}', [(x, -.12, z), (side * width, -.25, z + .14),
                     (side * width * .9, -.04, z + .23)], [.028, .023, .008], 'scar' if i % 4 == 0 else 'bone', 6)
        # An open ovoid shell, not a solid capsule concealing a scaled enemy.
        for side in (-1, 1):
            tube(f'Excavated specimen cranial lamina {side}', [(side * .06, -.1, 3.35), (side * .25, -.22, 3.6),
                 (side * .20, -.10, 3.96), (0, -.06, 4.06)], [.065, .055, .05, .025], 'skin')
        egg('Dark excised cranial cavity', (0, .04, 3.75), (.13, .055, .22), 'black', 12, 6)
        tube('Specimen restraint throat', [(0, -.04, 4.03), (.1, .1, 4.43), (0, .26, 4.84)], .04, 'steel')
        ring('Reliquary front pressure dial', (0, -.74, .5), .16, .027, 'bone', 'XZ', 16)
        tube('Reliquary amber dial needle', [(0, -.79, .5), (-.08, -.79, .57)], .015, 'amber', 5)
    elif name == 'drain_altar':
        box('Drain bolted machine foundation', (0, 0, .12), (3, 2.2, .24), 'iron', .06)
        # Annular funnel preserves an actual open central mouth above the recessed throat.
        verts, faces = [], []
        for row, (radius, z) in enumerate([(1.05, .82), (.86, .94), (.62, .75), (.45, .38)]):
            for i in range(40):
                a = i * math.pi / 20
                verts.append((radius * math.cos(a), radius * .80 * math.sin(a), z))
                if row:
                    k, q = (row - 1) * 40 + i, (row - 1) * 40 + (i + 1) % 40
                    faces.append((k, q, q + 40, k + 40))
        mesh('Open mechanical swallowing funnel', verts, faces, 'skin')
        ring('Steel drain mouth ring', (0, 0, .87), .97, .10, 'steel', segments=40)
        egg('Recessed dark drain throat', (0, 0, .32), (.46, .38, .025), 'black', 24, 6)
        for i in range(16):
            a = i * math.pi / 8
            u = Vector((math.cos(a), .80 * math.sin(a), 0))
            tube(f'Radial surgical tooth {i}', [u * .94 + Vector((0, 0, .84)), u * .78 + Vector((0, 0, 1.20)),
                 u * .54 + Vector((0, 0, 1.08))], [.065, .045, .005], 'bone', 6)
            tube(f'External drain actuator {i}', [u * 1.02 + Vector((0, 0, .8)), u * 1.14 + Vector((0, 0, .43)),
                 u * 1.20 + Vector((0, 0, .24))], [.06, .045, .025], 'iron', 6)
        for side in (-1, 1):
            tube(f'Organic sump cable {side}', [(side * 1.37, -.82, .2), (side * 1.32, -.42, .53),
                 (side * 1.17, .22, .63), (side * .72, .64, .81)], [.07, .08, .065, .035], 'scar')
            box(f'Raised drain gauge housing {side}', (side * 1.20, .56, 1.20), (.36, .45, 1.0), 'steel', .06)
            ring(f'Drain gauge face {side}', (side * 1.20, .31, 1.36), .13, .025, 'bone', 'XZ', 16)
            egg(f'Drain gauge dark dial {side}', (side * 1.20, .30, 1.36), (.11, .02, .11), 'black', 12, 4)
            tube(f'Drain gauge needle {side}', [(side * 1.20, .27, 1.36), (side * 1.20 + .07, .27, 1.42)], .014, 'amber', 5)
            for y in (-.9, .9):
                box(f'Drain anchor bolt {side} {y}', (side * 1.3, y, .27), (.12, .12, .1), 'bone', .02)


def kit(name):
    if name == 'ribbed_wall':
        box('Wall membrane panel', (0, .14, 1.75), (3.9, .25, 3.5), 'skin', .03)
        box('Wall lower plinth', (0, 0, .16), (4, .62, .32), 'iron', .04)
        box('Wall upper lintel', (0, 0, 3.38), (4, .62, .24), 'iron', .04)
        for i in range(7):
            x = -1.8 + i * .6
            tube(f'Wall vaulted vertebral rib {i}', [(x, -.14, .3), (x, -.29, 1.1), (x, -.28, 2.3), (x, -.1, 3.2)], [.075, .11, .1, .075])
            for z in (.65, 1.7, 2.8):
                egg(f'Wall rib pin {i} {z}', (x, -.30, z), (.11, .05, .11), 'steel', 10, 6)
        for i in range(12):
            box(f'Wall machine seam {i}', (-1.7 + i * .31, -.015, .5), (.08, .055, .15), 'steel')
    elif name == 'conduit':
        for side in (-1, 1):
            tube(f'Twin industrial organ conduit {side}', [(side * .17, -2, .32), (side * .17, -.6, .32),
                 (side * .2, .5, .45), (side * .35, 1.5, .4), (side * .35, 2, .32)], .14, 'iron', 12)
            for i in range(8):
                ring(f'Conduit pressure rib {side} {i}', (side * .17, -1.75 + i * .5, .32), .17, .03, 'bone', 'XZ', 12)
        tube('Braided conduit vascular insert', [(0, -2, .35), (.09, -.9, .42), (-.09, .4, .47), (.1, 1.1, .4), (0, 2, .3)], .055, 'skin')
        for y in (-1.5, 1.5):
            box(f'Conduit anchor {y}', (0, y, .12), (.92, .22, .24), 'steel', .025)
    else:
        for side in (-1, 1):
            tube(f'Cathedral doorway load rib {side}', [(side * 2.0, 0, .1), (side * 2.0, 0, 2.5),
                 (side * 1.55, 0, 3.8), (side * .6, 0, 4.7), (0, 0, 5)], [.23, .22, .2, .16, .08], 'iron', 12)
            tube(f'Doorway inner ossified rib {side}', [(side * 1.66, -.12, .1), (side * 1.66, -.12, 2.45),
                 (side * 1.2, -.12, 3.65), (0, -.12, 4.6)], [.12, .13, .1, .055])
            for i in range(6):
                z = .35 + i * .43
                box(f'Doorway bone column collar {side} {i}', (side * 1.96, -.12, z), (.58, .58, .13), 'bone', .03)
            box(f'Doorway foot {side}', (side * 1.96, 0, .16), (.75, .9, .32), 'steel', .05)
        ring('Doorway crown halo', (0, -.08, 4.50), .42, .07, 'bone', 'XZ', 20)
        egg('Doorway amber crown', (0, -.08, 4.5), (.12, .1, .20), 'amber')


def world_export(name):
    scene = setup()
    (bell if name == 'skin_bell' else siphon if name == 'siphon_heart' else
     lambda: kit(name) if name in ('arch', 'ribbed_wall', 'conduit') else scenery(name))()
    bpy.context.view_layer.update()
    objects = [o for o in scene.objects if o.type == 'MESH']
    extent = bounds(objects)
    # Bake authored pixel detail into ordinary image-texture materials, no procedural shader export.
    image = bpy.data.images.load(str(OUT / 'textures/surface_atlas.png'), check_existing=True)
    image.pack()
    if name == 'ribbed_wall':
        mat = M['skin']
        shader = mat.node_tree.nodes.get('Principled BSDF')
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image, tex.interpolation = image, 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    for obj in objects:
        if not obj.data.uv_layers:
            uv = obj.data.uv_layers.new(name='Authored tile UV')
            for loop in obj.data.loops:
                p = obj.data.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = (2 / 3 + (p.x * .5 % 1) / 3, p.z * .5)
    height = extent['size'][2]
    scale = max(height, extent['size'][0]) * 1.22
    preview_z = scale * .8 if name == 'drain_altar' else height * .78
    camera(scene, (scale * .52, -scale * 1.4, preview_z), (0, 0, height * .46), scale, 384, 384)
    preview = pixels_render(scene, name + '_hero', 384, 384)
    bg = bytearray(preview)
    for i in range(0, len(bg), 4):
        if not bg[i + 3]:
            bg[i:i + 4] = bytes((24, 28, 34, 255))
    png(SCRATCH / f'{name}_preview.png', 384, 384, bg)
    source = save(name)
    triangles = sum(len(p.vertices) - 2 for o in objects for p in o.data.polygons)
    # Keep authoring objects separate in .blend, merge runtime geometry by material to bound draw calls.
    bpy.ops.object.select_all(action='DESELECT')
    for mat in list(M.values()):
        group = [o for o in scene.objects if o.type == 'MESH' and o.data.materials and o.data.materials[0] == mat]
        if not group:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        group[0].name = name + '_' + mat.name.split()[0].lower()
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in scene.objects if o.type == 'MESH']
    for obj in meshes:
        obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    path = target(OUT / 'world' / f'{name}.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_materials='EXPORT', export_image_format='AUTO')
    return record(name, source, [(path, None)], physical_bounds_m=extent, origin='ground-centered at Blender (0,0,0); GLB Y up',
                  triangles=triangles, runtime_mesh_nodes=len(meshes), material_count=len(meshes),
                  loop_id='intake_loop_bell' if name == 'skin_bell' else 'intake_loop_siphon' if name == 'siphon_heart' else None)


def build_textures():
    scene = setup()
    outputs = [(name, texture(name)) for name in ('floor', 'grate', 'wall')]
    combined = bytearray()
    for y in range(64):
        for name, (image, tile) in outputs:
            combined.extend(tile[y * 256:(y + 1) * 256])
    png(OUT / 'textures/surface_atlas.png', 192, 64, combined)
    atlas_image = bpy.data.images.load(str(OUT / 'textures/surface_atlas.png'))
    atlas_image.pack()
    for i, (name, (image, tile)) in enumerate(outputs):
        mat = material(name + ' authored pixel tile', '#ffffff', image=image)
        obj = box(name + ' UV sample plane', (i * 1.2, 0, .02), (1, 1, .04), 'iron')
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    source = save('texture_library')
    entries = [record(name, source, [(OUT / 'textures' / f'{name}.png', [64, 64])],
                      filter='nearest', tile_size_m=[2, 2], color_space='sRGB', authored_pattern=name) for name, data in outputs]
    entries[-1]['outputs'].append({'path': 'game/assets/art/textures/surface_atlas.png',
                                  'sha256': sha(OUT / 'textures/surface_atlas.png'),
                                  'bytes': (OUT / 'textures/surface_atlas.png').stat().st_size, 'dimensions': [192, 64]})
    entries[-1]['atlas_regions_px'] = {'floor': [0, 0, 64, 64], 'grate': [64, 0, 64, 64], 'wall': [128, 0, 64, 64]}
    return entries


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--asset', choices=IDS, help='Rebuild one identity without touching other art')
    opts = args.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    path = ART / 'manifest.json'
    current = json.loads(path.read_text()) if path.exists() else {'schema_version': 1, 'palette': PALETTE, 'assets': []}
    for entry in current['assets']:
        entry.setdefault('recipe_sha256', current.get('build', {}).get('script_sha256'))
    selected = [opts.asset] if opts.asset else IDS
    current['build'] = {'blender_version': bpy.app.version_string, 'script_sha256': sha(Path(__file__)),
                        'render_engine': 'Cycles CPU', 'threads': 4, 'samples': 16, 'native_pixel_render': True}
    # Textures are one tiny editable source and shared runtime library.
    if any(name in selected for name in ('floor', 'grate', 'wall')) or not (OUT / 'textures/surface_atlas.png').exists():
        entries = build_textures()
        current['assets'] = [a for a in current['assets'] if a['id'] not in ('floor', 'grate', 'wall')] + entries
        target(path).write_text(json.dumps(current, indent=2) + '\n')
    for name in selected:
        if name in ('floor', 'grate', 'wall'):
            continue
        print(f'ART_START {name}', flush=True)
        entry = build_enemy(name) if name in ('crawler', 'worker') else build_weapon(name) if name in ('impact_tool', 'rivet_pistol') else world_export(name)
        current['assets'] = [a for a in current['assets'] if a['id'] != name] + [entry]
        current['assets'].sort(key=lambda a: IDS.index(a['id']))
        target(path).write_text(json.dumps(current, indent=2) + '\n')
        print(f'ART_DONE {name} {entry["outputs"][0]["sha256"]}', flush=True)
    current['assets'].sort(key=lambda a: IDS.index(a['id']))
    target(path).write_text(json.dumps(current, indent=2) + '\n')


if __name__ == '__main__':
    main()
