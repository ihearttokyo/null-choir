"""Original Processional instrument, conveyance, floating caster and scattergun.

Run one asset: blender -b -t 4 --python tools/build_processional_art.py -- --asset ID --receipt-dir PATH
Native rendering/export stay in build_art; curved anatomy stays in build_foundry_art.
"""
import argparse
from contextlib import contextmanager
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_art as art
import build_foundry_art as foundry

IDS = ('walking_bone_organ', 'ossified_palanquin', 'caster', 'scattergun')
CAPS = {'walking_bone_organ': (8, 6, 9), 'ossified_palanquin': (8, 6, 6)}
LOOPS = {'walking_bone_organ': 'processional_loop_organ', 'ossified_palanquin': 'processional_loop_palanquin'}
STATS = {}
ROOT_COLLECTION = None
_setup, _save, _target, _atlas = art.setup, art.save, art.target, art.atlas
bend, shell, dial = foundry.bend, foundry.shell, foundry.dial


def tissue_texture():
    """Packed pixel incisions and diagonal staple scars, authored for these identities."""
    for key, palette in [('skin', 'burgundy'), ('scar', 'scar')]:
        image = bpy.data.images.new('Processional ' + key + ' incised tissue', width=64, height=64, alpha=True)
        color, pixels = art.rgba(art.PALETTE[palette]), []
        for y in range(64):
            for x in range(64):
                incision = (x - y // 3 + round(2 * math.sin(y * .25))) % 23
                staple = y % 11 in (0, 1) and incision in (20, 21, 22, 0, 1, 2, 3)
                vein = (2 * x + y + (y // 16) * 7) % 47 < 2
                shade = .26 if incision < 2 else 1.30 if incision == 2 else .53 if vein else 1 + ((x * 7 + y * 19) % 9 - 4) / 65
                rgb = (.33, .37, .34) if staple else tuple(min(1, c * shade) for c in color[:3])
                pixels.extend((*rgb, 1))
        image.pixels.foreach_set(pixels)
        image.pack()
        shader = art.M[key].node_tree.nodes.get('Principled BSDF')
        tex = art.M[key].node_tree.nodes.new('ShaderNodeTexImage')
        tex.image, tex.interpolation = image, 'Closest'
        art.M[key].node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    art.M['amber'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 2.1


def setup():
    scene = _setup()
    tissue_texture()
    return scene


@contextmanager
def assembly(name):
    before = set(bpy.context.scene.objects)
    yield
    coll = bpy.data.collections.new(name)
    ROOT_COLLECTION.children.link(coll)
    art.move_to(coll, [o for o in bpy.context.scene.objects if o not in before])


def tissue_uv(objects):
    for obj in objects:
        if obj.type == 'MESH' and not obj.data.uv_layers:
            uv = obj.data.uv_layers.new(name='Processional incision UV')
            for loop in obj.data.loops:
                p = obj.data.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = (p.x * .8 + p.y * .35, p.z * .8 + p.y * .2)


def organ_pipe(index, x, y, bottom, top, radius):
    """Hollow tube with a real anterior organ-mouth cutout and joined inner walls."""
    steps, levels = 16, (bottom, bottom + .25, bottom + .78, top - .12, top)
    verts, faces = [], []
    for r in (radius, radius - .05):
        for z in levels:
            for i in range(steps):
                a = i * math.tau / steps
                verts.append((x + r * math.cos(a), y + r * math.sin(a), z))
    inner = len(levels) * steps
    for layer in range(2):
        for row in range(len(levels) - 1):
            for j in range(steps):
                if row == 1 and 10 <= j < 14:
                    continue
                k, q = layer * inner + row * steps + j, layer * inner + row * steps + (j + 1) % steps
                face = (k, q, q + steps, k + steps)
                faces.append(face if layer == 0 else tuple(reversed(face)))
    for row in (0, len(levels) - 1):
        for j in range(steps):
            k, q = row * steps + j, row * steps + (j + 1) % steps
            face = (k, q, q + inner, k + inner)
            faces.append(face if row else tuple(reversed(face)))
    for j in (10, 14):
        k = steps + j
        face = (k, k + steps, k + steps + inner, k + inner)
        faces.append(face if j == 10 else tuple(reversed(face)))
    for row in (1, 2):
        for j in range(10, 14):
            k, q = row * steps + j, row * steps + j + 1
            face = (k, q, q + inner, k + inner)
            faces.append(face if row == 1 else tuple(reversed(face)))
    art.mesh(f'Hollow organ pipe with anterior cutout {index:02}', verts, faces, 'bone')
    art.ring(f'Pipe crown machined lip {index:02}', (x, y, top), radius + .018, .032, 'steel', segments=8)
    art.egg(f'Recessed pipe organ mouth {index:02}', (x, y + .035, bottom + .49), (radius * .65, .025, .23), 'black', 10, 6)
    for tooth in range(3):
        px = x + (tooth - 1) * radius * .47
        art.tube(f'Pipe mouth inward tooth {index:02} {tooth}', [(px, y - radius * .79, bottom + .76),
                 (px + .025, y - radius * .82, bottom + .50 + .035 * (tooth % 2))], [.027, .003], 'bone', 5)
    art.box(f'Pipe lower wind socket {index:02}', (x, y, bottom - .06), (radius * 2.4, radius * 2.4, .14), 'iron', .02)
    art.tube(f'Pipe lumen wind feed {index:02}', [(x, y - .08, bottom - .12), (x, y - .20, bottom + .11)], .028, 'amber', 5)
    bend(f'Pipe incised vascular feed {index:02}', [(x, y + .13, 2.50), (x + .08, y + .18, 3.00),
         (x - .10, y + .18, bottom + .39), (x, y + radius + .02, bottom + 1.19)], (.033, .014), 'skin', 5, 8)


def walking_bone_organ():
    with assembly('01 Articulated six-leg walking chassis'):
        art.box('Organ elevated windchest chassis', (0, 0, 2.30), (4.55, 2.55, .30), 'iron', .05)
        for side in (-1, 1):
            for i, y in enumerate((-1.42, 0, 1.42)):
                hip, knee, ankle = (side * 1.9, y * .65, 2.32), (side * 2.77, y + .24, 1.33), (side * 3.12, y - .20, .32)
                art.tube(f'Articulated ivory walking leg {side} {i}', [hip, knee, ankle], [.17, .13, .11], 'bone', 8)
                art.box(f'Walking ground contact {side} {i}', (side * 3.12, y - .40, .10), (.82, .83, .20), 'iron', .045)
                bend(f'Walking hooked metatarsal {side} {i}', [ankle, (side * 3.40, y - .41, .20),
                     (side * 3.53, y - .70, .23), (side * 3.20, y - .74, .17)], (.105, .035), 'bone', 6, 8)
                for j, p in enumerate((hip, knee)):
                    art.egg(f'Walking joint bearing {side} {i} {j}', p, (.18, .18, .18), 'bone', 10, 4)
                    art.ring(f'Walking joint bearing collar {side} {i} {j}', p, .189, .036, 'iron', segments=8)
                art.tube(f'Walking exposed piston {side} {i}', [Vector(hip) + Vector((0, -.14, -.16)),
                         Vector(knee) + Vector((-.1 * side, -.14, -.16))], .06, 'steel', 8)
                art.tube(f'Walking tibial vascular tendon {side} {i}', [Vector(knee) + Vector((0, -.16, .03)),
                         (side * 2.97, y - .31, .84), Vector(ankle) + Vector((0, -.13, .02))], [.045, .034, .02], 'scar', 6)
                for k in range(3):
                    art.box(f'Walking foot surgical rib {side} {i} {k}', (side * 3.12, y - .65 + k * .20, .23), (.66, .035, .07), 'bone', .008)
    with assembly('02 Staggered hollow pipe ranks and wind feeds'):
        for i in range(9):
            x = (i - 4) * .49
            organ_pipe(i, x, .15, 3.15, 8.40 - abs(i - 4) * .54 + .11 * (i % 2), .185 + .018 * (i % 3))
        for i in range(6):
            x = (i - 2.5) * .64
            organ_pipe(i + 9, x, .86, 3.28, 7.63 - abs(i - 2.5) * .58 + .15 * (i % 2), .24)
        for z in (3.40, 4.65):
            art.box(f'Organ pipe-rank horizontal brace {z}', (0, 1.17, z), (4.40, .15, .13), 'iron', .02)
            for i in range(7):
                art.box(f'Rank restraint pin {z} {i}', (-1.95 + i * .65, 1.12, z), (.12, .23, .22), 'steel', .025)
        for side in (-1, 1):
            bend(f'Organ rising cathedral brace {side}', [(side * 2.05, 1.02, 2.4), (side * 2.4, 1.20, 4.3),
                 (side * 1.71, 1.21, 6.5), (side * .44, 1.05, 7.44)], (.13, .045), 'bone', 8, 12)
    with assembly('03 Keyboard console braced pedalboard and stops'):
        art.box('Organ keyboard recessed console', (0, -.98, 3.03), (3.80, .96, .31), 'iron', .045)
        art.box('Organ keyboard black key bed', (0, -1.17, 3.19), (3.15, .62, .06), 'black')
        for i in range(21):
            x = (i - 10) * .14
            art.box(f'Organ ivory manual key {i:02}', (x, -1.24, 3.25 + .01 * (i % 4)), (.125, .58, .07), 'bone', .008)
            if i % 7 not in (2, 6):
                art.box(f'Organ elevated black semitone {i:02}', (x + .07, -1.05, 3.32), (.055, .29, .08), 'black', .008)
        for i in range(14):
            x = (i - 6.5) * .20
            art.box(f'Organ mechanically braced pedal {i:02}', (x, -1.78, 2.14 + .025 * (i % 3)), (.145, .81, .10), 'bone', .012)
            art.tube(f'Organ pedal actuator rod {i:02}', [(x, -1.42, 2.14), (x, -.92, 2.28), (x, -.83, 2.93)], .025, 'steel', 5)
        for side in (-1, 1):
            bend(f'Pedalboard load bracket {side}', [(side * 1.6, -.26, 2.18), (side * 1.73, -.65, 1.77),
                 (side * 1.61, -1.87, 1.85), (side * 1.49, -2.12, 2.13)], .075, 'iron', 6, 8)
            for i in range(5):
                art.tube(f'Organ ivory draw-stop shaft {side} {i}', [(side * 1.75, -1.18, 3.07 + i * .13),
                         (side * 1.75, -1.56, 3.07 + i * .13)], .042, 'steel', 6)
                art.egg(f'Organ amber draw-stop knob {side} {i}', (side * 1.75, -1.59, 3.07 + i * .13), (.063, .046, .05), 'amber', 8, 4)
        dial('Organ windchest pressure gauge', (-2.02, -1.30, 2.73), .21)
    with assembly('04 Asymmetric incised tissue bellows and restraint'):
        for i in range(14):
            z = 3.35 + i * .18
            width = .56 + .16 * (i % 2)
            art.mesh(f'Asymmetric bellows tissue fold {i:02}', [(2.11, -.64, z), (2.11 + width, -.51, z + .07),
                     (2.11 + width, .91, z + .07), (2.11, 1.04, z), (2.11, 1.04, z + .12),
                     (2.11 + width, .91, z + .15), (2.11 + width, -.51, z + .15), (2.11, -.64, z + .12)],
                     [(0, 1, 2, 3), (3, 2, 5, 4), (4, 5, 6, 7), (7, 6, 1, 0)], 'skin' if i % 3 else 'scar')
            art.tube(f'Bellows worked fold incision {i:02}', [(2.11 + width + .015, -.50, z + .10),
                     (2.11 + width + .015, .86, z + .10)], .012, 'black', 4)
        for z in (3.22, 5.95):
            art.box(f'Bellows bone pressure platen {z}', (2.43, .19, z), (1.07, 1.88, .18), 'bone', .035)
        for y in (-.48, .87):
            art.tube(f'Bellows restraining steel tie {y}', [(2.85, y, 3.27), (2.85, y, 5.96)], .035, 'steel', 6)
            art.ring(f'Bellows amber valve {y}', (2.87, y, 4.44), .18, .035, 'amber', 'YZ', 8)
        bend('Bellows vascular wind trunk', [(2.30, .86, 2.37), (3.04, 1.14, 3.47), (3.11, .84, 5.21), (2.31, .37, 5.83)], (.10, .05), 'scar', 8, 16)
        bend('Opposite restrained breathing sac', [(-2.03, .48, 2.5), (-2.52, .91, 3.43), (-2.77, .86, 4.61), (-2.1, .34, 4.99)], (.24, .045), 'skin', 8, 14)
        for i in range(7):
            art.tube(f'Breathing-sac transfixion stitch {i}', [(-2.44, .54, 3.10 + i * .22), (-2.69, .62, 3.16 + i * .22)], .022, 'steel', 5)


def ossified_palanquin():
    with assembly('01 Mandibular ground runners and six carrying limbs'):
        art.box('Palanquin elevated funerary deck', (0, 0, 1.94), (5.50, 2.24, .25), 'iron', .04)
        for side in (-1, 1):
            bend(f'Palanquin jaw-shaped runner {side}', [(-3.36, side * 1.07, 1.01), (-2.1, side * 1.07, .10),
                 (2.00, side * 1.07, .10), (3.35, side * 1.07, 1.08)], (.18, .13), 'bone', 8, 22)
            for i, x in enumerate((-2.37, 0, 2.37)):
                root, elbow, hand = (x, side * .96, 1.95), (x + .27 * side, side * 1.89, 1.18), (x - .17 * side, side * 2.35, .26)
                art.tube(f'Palanquin articulated carrying limb {side} {i}', [root, elbow, hand], [.14, .11, .08], 'bone', 8)
                art.box(f'Palanquin carrying ground pad {side} {i}', (hand[0], hand[1], .10), (.48, .47, .20), 'iron', .025)
                art.egg(f'Carrying elbow pin {side} {i}', elbow, (.16, .16, .16), 'bone', 10, 4)
                art.ring(f'Carrying elbow pin collar {side} {i}', elbow, .168, .032, 'iron', segments=8)
                art.tube(f'Carrying limb tension cable {side} {i}', [Vector(root) + Vector((0, side * .12, -.1)),
                         Vector(elbow) + Vector((0, side * .14, 0)), Vector(hand) + Vector((0, side * .10, .08))], .033, 'scar', 5)
                for k in range(3):
                    bend(f'Carrying grasping finger {side} {i} {k}', [hand, (hand[0] + (k - 1) * .11, side * 2.48, .19),
                         (hand[0] + (k - 1) * .12, side * 2.58, .18), (hand[0] + (k - 1) * .09, side * 2.57, .09)], (.036, .006), 'bone', 5, 6)
            art.tube(f'Long ivory processional carrying pole {side}', [(-3.64, side * 1.37, 1.77), (3.64, side * 1.37, 1.77)], .105, 'bone', 10)
            for i in range(12):
                x = -2.78 + i * .505
                art.tube(f'Mandibular runner inward tooth {side} {i}', [(x, side * 1.06, .57),
                         (x + .06, side * .95, .88 + .08 * (i % 3))], [.072, .003], 'bone', 5)
                art.box(f'Carrying-pole incised ferrule {side} {i}', (x, side * 1.37, 1.77), (.055, .29, .29), 'steel', .012)
    with assembly('02 Split open incised casket and hinged leaves'):
        art.box('Palanquin recessed black casket floor', (0, 0, 2.10), (5.05, 1.76, .08), 'black', .02)
        for side in (-1, 1):
            # Actual lifted, thick leaves leave the central restrained torso exposed.
            verts = [(-2.59, side * .82, 2.18), (-2.36, side * 1.52, 2.94), (1.96, side * 1.55, 2.91),
                     (2.59, side * 1.11, 2.55), (2.57, side * .82, 2.18)]
            verts += [(x, y + side * .06, z - .08) for x, y, z in verts]
            faces = [tuple(range(5)), tuple(reversed(range(5, 10)))]
            faces += [(i, (i + 1) % 5, (i + 1) % 5 + 5, i + 5) for i in range(5)]
            art.mesh(f'Split lifted casket leaf {side}', verts, faces, 'skin')
            bend(f'Carved casket leaf bone edge {side}', [(-2.56, side * .84, 2.24), (-2.4, side * 1.62, 3.0),
                 (2.18, side * 1.63, 3.06), (2.58, side * 1.10, 2.58)], (.075, .04), 'bone', 8, 18)
            for i in range(15):
                x = -2.25 + i * .29
                art.tube(f'Casket worked surface incision {side} {i}', [(x, side * 1.02, 2.44),
                         (x + .10, side * 1.24, 2.68), (x - .03, side * 1.44, 2.89)], [.014, .017, .005], 'black', 4)
                if i % 2 == 0:
                    art.tube(f'Casket surgical staple {side} {i}', [(x - .08, side * 1.19, 2.65),
                             (x + .16, side * 1.21, 2.70)], .020, 'steel', 5)
            for x in (-2.14, -.72, .72, 2.14):
                art.ring(f'Open casket hinge bearing {side} {x}', (x, side * .89, 2.24), .11, .027, 'steel', 'YZ', 8)
        for x in (-2.56, 2.56):
            art.box(f'Casket coffin end shield {x}', (x, 0, 2.28), (.14, 1.73, .38), 'bone', .045)
    with assembly('03 Restrained excised torso and articulated spinal remnant'):
        art.egg('Palanquin incised restrained torso', (-.17, 0, 2.36), (1.33, .42, .28), 'skin', 16, 8)
        art.egg('Torso exposed anterior incision', (-.14, -.34, 2.43), (1.00, .12, .16), 'scar', 16, 6)
        for i in range(12):
            x = -1.37 + i * .203
            art.box(f'Preserved supine vertebra {i:02}', (x, .17, 2.61), (.12, .18, .13), 'bone', .018)
            width = .25 + .18 * math.sin((i + 1) * math.pi / 14)
            bend(f'Preserved supine surgical rib {i:02}', [(x, width, 2.36), (x + .06, width, 2.74),
                 (x + .03, -width, 2.84), (x, -width, 2.41)], (.034, .014), 'bone', 6, 10)
        art.egg('Torso ossified hollow cranial shell', (-1.81, .05, 2.53), (.34, .28, .28), 'bone', 12, 8)
        art.egg('Torso absent facial cavity', (-1.84, -.20, 2.56), (.22, .055, .17), 'black', 12, 6)
        for i in range(5):
            art.tube(f'Restrained cranial socket tooth {i}', [(-2.02 + i * .08, -.25, 2.45),
                     (-2.01 + i * .08, -.27, 2.56)], [.022, .003], 'bone', 5)
        for side in (-1, 1):
            bend(f'Severed restrained abdominal feed {side}', [(1.00, side * .20, 2.34), (1.56, side * .34, 2.44),
                 (1.93, side * .27, 2.38), (2.31, side * .21, 2.22)], (.12, .04), 'scar', 8, 12)
            bend(f'Cadaver amber vascular perfusion {side}', [(-1.33, side * .32, 2.51), (-.74, side * .26, 2.73),
                 (.33, side * .31, 2.49), (1.01, side * .24, 2.40)], (.03, .019), 'amber', 5, 12)
        for i in range(7):
            x = -1.34 + i * .40
            bend(f'Torso transfixing restraint band {i}', [(x, -.83, 2.18), (x - .04, -.53, 2.92),
                 (x + .04, .53, 2.92), (x, .83, 2.18)], .035, 'steel', 6, 12)
            art.box(f'Torso restraint tension lock {i}', (x, -.86, 2.21), (.14, .10, .14), 'bone', .02)
    with assembly('04 Curved ossified canopy and incised crest rails'):
        for i in range(9):
            x = -2.48 + i * .62
            # Two smooth ribs meet above an open interior; no solid roof hides the body.
            for side in (-1, 1):
                bend(f'Curved canopy rib {i:02} {side}', [(x, side * 1.67, 2.30), (x, side * 1.68, 4.13),
                     (x, side * .69, 5.21 + .05 * math.sin(i)), (x, 0, 5.24 + .05 * math.sin(i))], (.095, .047), 'bone', 6, 12)
                art.box(f'Canopy rib bolted socket {i} {side}', (x, side * 1.67, 2.37), (.18, .24, .27), 'steel', .025)
                bend(f'Canopy incised tendon inlay {i} {side}', [(x + .045, side * 1.64, 2.73), (x + .045, side * 1.62, 4.15),
                     (x + .045, side * .64, 5.08), (x + .045, side * .05, 5.21)], .012, 'scar', 4, 10)
        for side in (-1, 1):
            bend(f'Canopy longitudinal ivory crest {side}', [(-2.79, side * .22, 4.91), (-1.27, side * .43, 5.25),
                 (1.25, side * .43, 5.25), (2.79, side * .22, 4.91)], .065, 'bone', 6, 20)
        for i in range(13):
            art.box(f'Canopy crown sagittal lock {i}', (-2.40 + i * .40, 0, 5.24), (.15, .23, .11), 'iron', .015)
    with assembly('05 Suspended mortuary lamps and vascular transport cables'):
        for side in (-1, 1):
            for x in (-2.53, 2.53):
                art.tube(f'Mortuary lamp suspension chain {side} {x}', [(x, side * 1.28, 4.61), (x, side * 1.43, 3.97)], .028, 'steel', 5)
                art.egg(f'Suspended mortuary amber lamp {side} {x}', (x, side * 1.43, 3.66), (.15, .15, .28), 'amber', 10, 6)
                for k in range(4):
                    a = k * math.pi / 2
                    bend(f'Mortuary lamp cage {side} {x} {k}', [(x, side * 1.43, 4.01), (x + .27 * math.cos(a), side * 1.43 + .27 * math.sin(a), 3.83),
                         (x + .25 * math.cos(a), side * 1.43 + .25 * math.sin(a), 3.39), (x, side * 1.43, 3.33)], .028, 'bone', 5, 8)
            bend(f'Palanquin vascular transport cable {side}', [(-3.29, side * 1.33, 1.7), (-1.67, side * 2.21, .75),
                 (1.62, side * 2.21, .75), (3.27, side * 1.33, 1.7)], .072, 'skin', 6, 22)
            for i in range(9):
                art.box(f'Palanquin vascular cable tie {side} {i}', (-2.4 + i * .6, side * 1.65, 1.08), (.075, .21, .18), 'steel', .012)
        dial('Palanquin left mortuary perfusion gauge', (-2.31, -1.59, 2.02), .18)


def caster(pose):
    before = set(bpy.context.scene.objects)
    phase = {'idle': 0, 'walk_a': 1, 'walk_b': -1, 'attack': 2.4, 'dead': 0}[pose]
    # Open crescent mantle: a thick band with real negative space around the suspended spine.
    verts, faces, steps = [], [], 32
    for layer in range(2):
        for edge in range(2):
            for i in range(steps + 1):
                a = math.pi * (.15 + 1.70 * i / steps)
                taper = math.sin(math.pi * i / steps) ** .5
                r = 1 if edge == 0 else 1 - .24 * taper
                x = .93 * r * math.sin(a) + .035 * phase * math.cos(a)
                z = 2.18 + 1.06 * r * math.cos(a) + .075 * math.sin(a)
                verts.append((x, .05 + layer * .19 + .07 * math.sin(2 * a), z))
                if i:
                    k = layer * 2 * (steps + 1) + edge * (steps + 1) + i
                    if edge:
                        face = (k - steps - 2, k - steps - 1, k, k - 1)
                        faces.append(face if layer else tuple(reversed(face)))
    for edge in range(2):
        for i in range(steps):
            k = edge * (steps + 1) + i
            face = (k, k + 1, k + 1 + 2 * (steps + 1), k + 2 * (steps + 1))
            faces.append(face if edge == 0 else tuple(reversed(face)))
    art.mesh('Hollow crescent ossified mantle', verts, faces, 'bone')
    for side in (-1, 1):
        bend(f'Crescent mantle incised outer seam {side}', [(side * .41, .23, 3.12), (side * 1.23, .26, 2.74),
             (side * 1.01, .30, 1.41), (side * .21, .21, 1.14)], (.04, .018), 'scar', 6, 16)
        bend(f'Crescent posterior restraint {side}', [(side * .45, .36, 2.96), (side * .97, .48, 2.4),
             (side * .66, .42, 1.43), (0, .26, 1.24)], .028, 'steel', 5, 14)
    for i in range(11):
        z = 1.36 + i * .137
        art.box(f'Suspended caster spinal segment {i:02}', (.04 * math.sin(i), .12, z), (.12, .15, .08), 'bone', .012)
        art.tube(f'Suspended spinal lateral root {i:02}', [(0, .15, z), ((-.17 if i % 2 else .22), .20, z + .07)], [.027, .005], 'scar', 5)
    art.egg('Caster luminous throat projectile sac', (.04, -.19, 2.46), (.20, .14, .28 if pose != 'attack' else .36), 'amber', 12, 8)
    art.ring('Caster throat surgical lip', (.04, -.33, 2.46), .19, .035, 'bone', 'XZ', 16)
    for i in range(6):
        art.tube(f'Throat valve cartilage tooth {i}', [(-.13 + i * .066, -.33, 2.33), (-.12 + i * .066, -.35, 2.46)], [.021, .002], 'bone', 5)
    for side in (-1, 1):
        shoulder = (side * .71, .04, 2.26)
        elbow = (side * (1.01 + .055 * phase), -.18, 1.85 + .24 * side + .11 * phase)
        hand = (side * .82, -.52 - .15 * phase, 1.92 + .37 * side + .16 * phase)
        art.tube(f'Caster jointed gesturing upper arm {side}', [shoulder, elbow], [.095, .068], 'bone', 8)
        art.tube(f'Caster jointed gesturing forearm {side}', [elbow, hand], [.068, .037], 'bone', 8)
        art.joint(f'Caster exposed elbow pin {side}', elbow, .095)
        art.tube(f'Caster arm vascular tendon {side}', [Vector(shoulder) + Vector((0, .10, -.02)), Vector(elbow) + Vector((0, .10, -.02)), hand], .021, 'skin', 5)
        for i in range(4):
            p = Vector(hand) + Vector(((i - 1.5) * .052, 0, .015 * i))
            art.tube(f'Caster long gesturing finger {side} {i}', [p, p + Vector((side * .10, -.19 - i * .024, .06)),
                     p + Vector((side * .07, -.29 - i * .021, -.04))], [.025, .018, .003], 'scar' if i == 0 else 'bone', 5)
        for ribbon in range(3):
            x = side * (.29 + ribbon * .16)
            length = .62 + .17 * ribbon
            sway = phase * .08 * (ribbon + 1) * side
            art.mesh(f'Dangling split mantle tissue {side} {ribbon}', [(x - .075, .07, 1.39), (x + .075, .07, 1.39),
                     (x + .10 + sway, -.07, .80), (x - .05 + sway, -.07, .80),
                     (x + .08 + sway * .5, .12, 1.39 - length), (x + .02 + sway * .5, .12, 1.39 - length - .14)],
                     [(3, 2, 1, 0), (5, 4, 2, 3)], 'skin' if ribbon % 2 else 'scar')
            art.tube(f'Dangling tissue cut edge {side} {ribbon}', [(x - .075, .045, 1.39), (x - .05 + sway, -.09, .80),
                     (x + .02 + sway * .5, .10, 1.25 - length)], [.022, .016, .004], 'black', 4)
    for i in range(5):
        x = (i - 2) * .11
        bend(f'Caster dangling spinal tendril {i}', [(x, .10, 1.28), (x + phase * .07, -.19, .83),
             (x - .12 + phase * .09, .28, .43), (x + .11 * math.sin(i + phase), -.12 + .07 * i, .055 + .033 * i)],
             (.042, .004), 'scar' if i % 2 else 'bone', 6, 12)
    art.box('Caster asymmetric posterior restraint tag', (.40, .39, 2.73), (.15, .05, .30), 'iron', .015)
    art.tube('Caster posterior amber index', [(.41, .43, 2.62), (.37, .43, 2.81)], .018, 'amber', 5)
    if pose == 'attack':
        art.egg('Caster expelled throat pressure pearl', (.06, -.71, 2.63), (.13, .17, .14), 'amber', 10, 6)
        for side in (-1, 1):
            art.tube(f'Caster attack sac vascular flare {side}', [(0, -.34, 2.46), (side * .14, -.61, 2.60),
                     (side * .10, -.75, 2.70)], [.035, .022, .002], 'amber', 5)
    objects = [o for o in bpy.context.scene.objects if o not in before]
    tissue_uv(objects)
    if pose == 'dead':
        for obj in objects:
            obj.location.z *= .20
            obj.scale.z *= .20
            obj.location.x += .12
        art.egg('Caster collapsed ruptured mantle tissue', (.09, -.13, .10), (.61, .38, .085), 'scar', 16, 6)
        art.egg('Caster extinguished throat remnant', (-.22, -.15, .13), (.19, .12, .055), 'black', 10, 6)


def scattergun(name, pose):
    before = set(bpy.context.scene.objects)
    lift = {'idle': 0, 'fire': .10, 'recover': -.055}[pose]
    pump = .18 if pose == 'recover' else 0
    for side in (-1, 1):
        hand_before = set(bpy.context.scene.objects)
        art.technician_hand(side, pose, True)
        for obj in bpy.context.scene.objects:
            if obj not in hand_before:
                obj.name = f'Scattergun {side} ' + obj.name
                if side == -1:
                    obj.location.y += .42 - pump
                    obj.location.z -= .055
        bend(f'Scattergun exposed wrist vascular cord {side}', [(side * .62, -1.40, .30), (side * .68, -.97, .47),
             (side * .60, -.69, .46), (side * .42, -.56, .36)], (.038, .015), 'scar', 6, 12)
        for i in range(4):
            art.tube(f'Scattergun biological cuff rib {side} {i}', [(side * .36, -1.23 + i * .09, .42),
                     (side * .51, -1.24 + i * .09, .51), (side * .68, -1.23 + i * .09, .40)], [.035, .045, .018], 'bone', 6)
    art.box('Scattergun wide twin-pressure receiver', (0, -.35, .49 + lift), (.96, .76, .31), 'iron', .045)
    art.box('Scattergun wide surgical receiver spine', (0, -.38, .67 + lift), (.79, .66, .055), 'bone', .015)
    art.box('Scattergun right mechanical grip', (.37, -.75, .30 + lift), (.19, .30, .32), 'iron', .03)
    art.ring('Scattergun curved trigger guard', (.36, -.65, .33 + lift), .12, .024, 'steel', 'YZ', 12)
    for side in (-1, 1):
        x = side * .265
        barrel = shell(f'Scattergun hollow pressure bore {side}', [(.132, 0), (.132, 1.30), (.091, 1.30), (.091, 0), (.132, 0)], 'steel', steps=16)
        barrel.rotation_euler.x = -math.pi / 2
        barrel.location = (x, -.24, .52 + lift)
        art.ring(f'Scattergun ivory pressure muzzle {side}', (x, 1.06, .52 + lift), .139, .034, 'bone', 'XZ', 16)
        art.egg(f'Scattergun recessed pressure bore darkness {side}', (x, .96, .52 + lift), (.085, .014, .085), 'black', 12, 6)
        for i in range(5):
            art.ring(f'Scattergun surgical barrel rib {side} {i}', (x, -.06 + i * .205, .52 + lift), .158, .026, 'bone', 'XZ', 12)
            art.box(f'Scattergun barrel rib lock {side} {i}', (x + side * .16, -.06 + i * .205, .52 + lift), (.075, .10, .09), 'iron', .012)
        art.tube(f'Scattergun mechanical pump guide {side}', [(side * .39, -.54, .35 + lift), (side * .39, .70, .35 + lift)], .035, 'steel', 6)
        art.tube(f'Scattergun biological receiver feed {side}', [(side * .47, -.67, .40 + lift), (side * .61, -.23, .49 + lift),
                 (side * .47, .36, .52 + lift)], [.039, .049, .018], 'skin', 6)
        if pose == 'fire':
            bend(f'Scattergun twin pressure discharge {side}', [(x, 1.07, .52 + lift), (x + side * .12, 1.31, .52 + lift),
                 (x + side * .21, 1.49, .48 + lift), (x + side * .16, 1.60, .44 + lift)], (.078, .002), 'amber', 6, 8)
    art.box('Scattergun sliding wide mechanical pump', (0, -.02 - pump, .31 + lift), (.84, .44, .20), 'iron', .035)
    for i in range(7):
        art.box(f'Scattergun mechanical pump grip rib {i}', (0, -.21 - pump + i * .063, .245 + lift), (.87, .024, .13), 'bone', .007)
    art.box('Scattergun low amber bridge sight', (0, .55, .69 + lift), (.08, .12, .035), 'amber', .006)
    for i in range(5):
        art.box(f'Scattergun receiver pressure vent {i}', (-.49, -.62 + i * .125, .48 + lift), (.02, .051, .15), 'black')
    tissue_uv([o for o in bpy.context.scene.objects if o not in before])


def build_scene(name):
    global ROOT_COLLECTION
    ROOT_COLLECTION = bpy.data.collections.new(name + ' editable assemblies')
    bpy.context.scene.collection.children.link(ROOT_COLLECTION)
    (walking_bone_organ if name == 'walking_bone_organ' else ossified_palanquin)()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    tissue_uv(meshes)
    bpy.context.view_layer.update()
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices),
               'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert len(meshes) >= 100 and triangles <= 30000, (name, len(meshes), triangles)
    assert abs(extent['min'][2]) <= .001 and all(v <= cap for v, cap in zip(extent['size'], CAPS[name])), (name, extent)
    prefixes = ({'hollow_pipes': 'Hollow organ pipe with anterior cutout ', 'walking_legs': 'Articulated ivory walking leg ',
                 'pedals': 'Organ mechanically braced pedal ', 'bellows_folds': 'Asymmetric bellows tissue fold '}
                if name == 'walking_bone_organ' else
                {'canopy_ribs': 'Curved canopy rib ', 'carrying_limbs': 'Palanquin articulated carrying limb ',
                 'casket_leaves': 'Split lifted casket leaf ', 'restraint_bands': 'Torso transfixing restraint band '})
    STATS[name] = {'source_mesh_count': len(meshes), 'triangles': triangles, 'physical_bounds_m': extent,
                   'source_hierarchy_groups': len(ROOT_COLLECTION.children), 'source_meshes': counts,
                   'features': {key: sum(o.name.startswith(prefix) for o in meshes) for key, prefix in prefixes.items()}}


def save(name):
    scene = bpy.context.scene
    scene['asset_id'], scene['authoring_recipe'] = name, 'tools/build_processional_art.py'
    scene['recipe_sha256'] = art.sha(Path(__file__))
    if name not in CAPS:
        bpy.context.view_layer.update()
        groups = [c for c in scene.collection.children if c.name in art.FRAMES + ['fire', 'recover']]
        STATS[name] = {'pose_mesh_counts': {c.name: len([o for o in c.objects if o.type == 'MESH']) for c in groups},
                       'source_mesh_count': len([o for o in scene.objects if o.type == 'MESH'])}
    return _save(name)


def target(path):
    # The native atlas writer otherwise classifies every new identity as a weapon.
    if path == art.OUT / 'weapons/caster.png':
        path = art.OUT / 'sprites/caster.png'
    return _target(path)


def atlas(name, *args):
    return target(_atlas(name, *args))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--receipt-dir', type=Path, required=True)
    opts = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    opts.receipt_dir.mkdir(parents=True, exist_ok=True)
    art.SCRATCH = opts.receipt_dir / 'previews'
    art.setup, art.save, art.target, art.atlas = setup, save, target, atlas
    art.scenery, art.worker, art.weapon = build_scene, caster, scattergun
    path = art.ART / 'manifest.json'
    current = json.loads(path.read_text())
    dependencies = {str(Path(m.__file__).relative_to(art.ROOT)): art.sha(Path(m.__file__)) for m in (art, foundry)}
    assert dependencies['tools/build_art.py'] == current['build']['script_sha256'], 'Intake helper drift; do not build'
    assert all(a['recipe_sha256'] == dependencies['tools/build_foundry_art.py'] for a in current['assets'] if a['id'] in foundry.IDS), 'Foundry helper drift; do not build'
    name = opts.asset
    print('ART_START ' + name, flush=True)
    entry = art.world_export(name) if name in CAPS else art.build_enemy(name) if name == 'caster' else art.build_weapon(name)
    entry['recipe_sha256'], entry['recipe_dependencies'] = art.sha(Path(__file__)), dependencies
    entry['provenance']['authoring_script'] = 'tools/build_processional_art.py'
    entry['source_mesh_count'] = STATS[name]['source_mesh_count']
    if name in CAPS:
        entry.update({key: STATS[name][key] for key in ('source_hierarchy_groups', 'features')})
        entry['loop_id'], entry['facing'] = LOOPS[name], 'front Blender -Y; exported Godot +Z'
        assert entry['runtime_mesh_nodes'] <= 7 and entry['triangles'] == STATS[name]['triangles']
    else:
        entry['pose_mesh_counts'] = STATS[name]['pose_mesh_counts']
        if name == 'caster':
            entry['runtime_quad_height_m'] = 3.65
    # Re-read after rendering; retain any independent additions made during the native job.
    latest = json.loads(path.read_text())
    assert latest['build'] == current['build'] and latest['palette'] == current['palette'], 'shared manifest header drift'
    prior = {a['id']: a for a in latest['assets']}
    assert all(prior.get(a['id']) == a for a in current['assets'] if a['id'] != name), 'shared art entry changed during build'
    latest['assets'] = [a for a in latest['assets'] if a['id'] != name] + [entry]
    assert sum(a['outputs'][0]['bytes'] for a in latest['assets'] if a['id'] in CAPS) < 4 * 1024 * 1024, 'Processional GLB budget'
    path.write_text(json.dumps(latest, indent=2) + '\n')
    receipt = {**STATS[name], 'asset': entry, 'blender_version': bpy.app.version_string,
               'render_engine': 'Cycles CPU', 'threads': 4, 'samples': 16,
               'preview': str(art.SCRATCH / (name + ('_preview.png' if name in CAPS else '_contact.png')))}
    (opts.receipt_dir / (name + '_geometry.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'ART_DONE {name} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
