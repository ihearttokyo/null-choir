"""Foundry reference-derived machinery; parent owns native dispatch.

blender -b -t 4 --python tools/build_religious_foundry_art.py --
  --asset ID --output-root RECEIPTS/native --receipt-root RECEIPTS
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_religious_art as intake

IDS = ('foundry_cross_spine', 'foundry_slag_wheel', 'foundry_bound_furnace',
       'foundry_pressure_canopy', 'foundry_tower_cluster', 'foundry_lamp_manifold',
       'foundry_solar_crucible')
TRADITIONS = dict(zip(IDS, ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
PURPOSES = dict(zip(IDS, (
    'Combines paired heat streams through a transverse vertebral compression rack',
    'Separates molten binding residue with a horizontal slag flywheel and receiving petals',
    'Heat-treats bindings beneath a membrane-curtain threshold and lateral retorts',
    'Condenses exhaust through nested recessed pressure cells into a pendant drain',
    'Fractionates recovered tissue through five linked staged thermal towers',
    'Distributes seven heated fractions through independently upright observation reservoirs',
    'Traps the final molten charge between winged cooling vanes and inclined containment jaws',
)))
REFERENCES = {
    'source/art/references/religion-foundry-01.png': '87b841d25b1518dd84bad69775a352933deb2c3f77f832ea85a0aa9f06072341',
    'source/art/references/foundry-01.png': 'a267e6aa1b1fc5be932720b3c4b6a8116f0e03b7f537d8f6c8149c1f40a37407',
}
CAPS = (8, 6, 9)
STATS = {}


def preflight(asset, output_root, receipt_root, project_root):
    if asset not in IDS:
        raise ValueError('Select one exact Foundry asset ID')
    output, receipt = intake.candidate_roots(output_root, receipt_root, project_root)
    paths = [output / 'source/art' / (asset + '.blend'),
             output / 'game/assets/art/world' / (asset + '.glb'),
             output / 'previews' / (asset + '_preview.png'),
             output / 'previews/frames' / (asset + '_hero.png'), receipt / (asset + '_candidate.json')]
    if any(p.exists() or p.is_symlink() for p in paths):
        raise FileExistsError('Foundry candidate exists; select a fresh batch root, never overwrite it')
    return output, receipt


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--receipt-root', type=Path, required=True)
    return parser.parse_args(argv)


@contextmanager
def assembly(name):
    before = set(bpy.context.scene.objects)
    yield
    art.move_to(art.pose_collection(name), [o for o in bpy.context.scene.objects if o not in before])


def retort(name, x, y, z, radius, height, core='amber'):
    """Foundry pressure vessel: open anterior window, hollow back and restraint bars."""
    r, h = radius, height
    shell(name + ' cut-open thick posterior jacket', [(r, .12), (r * 1.10, .26), (r * 1.05, h - .27),
          (r * .77, h), (r * .59, h), (r * .84, h - .27), (r * .89, .26), (r * .76, .12)],
          'iron', center=(x, y, z), arc=(-.10, math.pi + .10), steps=16)
    for dz in (.19, h - .20):
        shell(name + f' hollow copper end flange {dz:.2f}', [(r * 1.15, dz - .065), (r * 1.15, dz + .065),
              (r * .70, dz + .065), (r * .70, dz - .065), (r * 1.15, dz - .065)], 'steel', center=(x, y, z), steps=16)
    art.tube(name + ' exposed central fraction', [(x, y, z + .21), (x, y, z + h - .17)], r * .36, core, 8)
    for side in (-1, 1):
        bend(name + f' ivory window stave {side}', [(x + side * r * .68, y - r * .6, z + .27),
             (x + side * r * 1.06, y - r * .62, z + h * .32),
             (x + side * r * 1.06, y - r * .62, z + h * .79),
             (x + side * r * .58, y - r * .6, z + h - .22)], .048, 'bone', 6, 10)
        for i in range(3):
            art.box(name + f' machined window clamp {side} {i}',
                    (x + side * r * .91, y - r * .72, z + h * (.29 + i * .22)), (.13, .14, .085), 'steel', .01)
    art.tube(name + ' tapered crown heat outlet', [(x, y, z + h - .02), (x, y, z + h + .39)], [.11, .06], 'steel', 8)


def cross_spine():
    with assembly('Cross-spine open thermal receiving chassis'):
        art.box('Cross-spine low heat chassis', (0, .16, .13), (5.9, 3.1, .26), 'iron', .055)
        art.box('Cross-spine recessed ash receiver', (0, -.47, .30), (2.5, 1.65, .04), 'black')
        for side in (-1, 1):
            bend(f'Cross-spine pointed firebox arch {side}', [(side * 1.17, -.65, .30),
                 (side * 1.32, -.65, 1.75), (side * .87, -.65, 2.49), (0, -.65, 2.80)], .12, 'bone', 8, 14)
            art.box(f'Cross-spine arch restraint shoe {side}', (side * 1.14, -.64, .55), (.46, .38, .39), 'steel', .025)
        shell('Cross-spine rear open firebox wall', [(1.17, .38), (1.20, 2.39), (.96, 2.62), (.84, 2.62), (.99, .38)],
              'iron', center=(0, .26, 0), aspect=(1, .72), arc=(-.08, math.pi + .08), steps=20)
        for i in range(5):
            x = (i - 2) * .22
            art.tube(f'Cross-spine exposed downward heat thread {i}', [(x, .02, 2.25),
                     (x + .07, -.22, 1.24), (x, -.52, .34)], [.075, .052, .013], 'amber', 6)
    with assembly('Paired segmented chimneys and bridging vertebral rack'):
        for side in (-1, 1):
            x = side * .88
            shell(f'Cross-spine hollow chimney jacket {side}', [(.39, 2.40), (.44, 8.24), (.29, 8.24), (.25, 2.40)],
                  'black', center=(x, .31, 0), steps=16)
            for i in range(13):
                z = 2.68 + i * .405
                shell(f'Cross-spine segmented heat flange {side} {i}', [(.42, z), (.55, z + .05), (.56, z + .21),
                      (.41, z + .27), (.29, z + .27), (.28, z), (.42, z)], 'steel', center=(x, .31, 0), steps=16)
                art.ring(f'Cross-spine exposed molten chimney seam {side} {i}', (x, .31, z + .30), .38, .045, 'amber', segments=16)
            for i in range(10):
                z = 3.02 + i * .45
                bend(f'Cross-spine vertebral transverse arch {side} {i}', [(0, -.25, z),
                     (side * .28, -.47, z + .19), (side * .62, -.32, z + .17), (side * .94, -.1, z)],
                     (.085, .045), 'bone', 6, 9)
        for i in range(13):
            z = 2.66 + i * .40
            art.egg(f'Cross-spine pierced vertebral boss {i}', (0, -.19, z), (.22, .15, .11), 'bone', 10, 4)
            art.egg(f'Cross-spine recessed vertebral aperture {i}', (0, -.345, z + .02), (.085, .025, .048), 'black', 8, 4)
        art.tube('Cross-spine open central molten suture', [(0, .01, 2.65), (0, .01, 8.34)], .070, 'amber', 8)
    with assembly('Transverse ribbed compression feed and end bearings'):
        for side in (-1, 1):
            art.tube(f'Cross-spine transverse feed barrel {side}', [(side * .36, .26, 4.03),
                     (side * 2.75, .26, 4.03)], .31, 'iron', 12)
            for i in range(9):
                x = side * (.70 + i * .215)
                art.ring(f'Cross-spine horizontal barrel pressure fin {side} {i}', (x, .26, 4.03), .38, .053, 'steel', 'YZ', 16)
            art.box(f'Cross-spine barrel end bearing {side}', (side * 2.66, .26, 4.03), (.27, .89, .89), 'bone', .025)
            bend(f'Cross-spine lower side supply {side}', [(side * 2.37, 1.02, .28),
                 (side * 3.04, .86, 1.77), (side * 2.83, .50, 3.67), (side * 2.55, .28, 4.03)], .12, 'steel', 8, 14)
    with assembly('Cross-spine independent pressure towers and regulators'):
        for side in (-1, 1):
            retort(f'Cross-spine lateral pressure retort {side}', side * 2.43, .72, .30, .27, 2.79)
            bend(f'Cross-spine posterior support branch {side}', [(side * 2.42, .90, .29),
                 (side * 2.82, 1.04, 5.7), (side * 1.60, .92, 7.9), (side * .89, .48, 8.08)], .082, 'steel', 6, 14)
            dial(f'Cross-spine thermal regulator {side}', (side * 1.65, -1.10, .76), .20)


def slag_petal(a):
    verts = []
    # Thick creased wedge-petals, taller and more upright than Intake's curved receiver.
    for layer in (0, .12):
        for r, z, width in [(1.12, .54, .13), (1.98, 1.53, .48), (2.18, 2.84, .30), (1.92, 3.19, .01)]:
            for edge in (-1, 0, 1):
                angle = a + edge * width / r
                verts.append((r * math.cos(angle), r * math.sin(angle), z + layer + (1 - edge * edge) * .12))
    faces = []
    for row in range(3):
        for col in range(2):
            k = row * 3 + col
            faces.extend([(k, k + 1, k + 4, k + 3), (k + 12, k + 15, k + 16, k + 13)])
        for edge in (0, 2):
            k = row * 3 + edge
            face = (k, k + 3, k + 15, k + 12)
            faces.append(face if edge == 0 else tuple(reversed(face)))
    for row in (0, 3):
        for col in range(2):
            k = row * 3 + col
            face = (k, k + 12, k + 13, k + 1)
            faces.append(face if row == 0 else tuple(reversed(face)))
    return verts, faces


def slag_wheel():
    with assembly('Slag lotus thick receiver and exposed molten mouth'):
        art.box('Slag-wheel low receiving foundation', (0, .16, .13), (5.3, 4.6, .26), 'iron', .055)
        shell('Slag-wheel deep concave ivory receiver', [(2.01, 1.66), (2.10, 1.83), (1.94, 1.98), (1.42, 1.45),
              (.61, .67), (.21, .55), (.21, .40), (.81, .57), (1.73, 1.22), (2.01, 1.66)], 'bone', steps=24)
        art.egg('Slag-wheel recessed molten pool', (0, 0, .66), (.62, .59, .035), 'amber', 16, 6)
        for i in range(10):
            a = i * math.tau / 10
            verts, faces = slag_petal(a)
            art.mesh(f'Slag-wheel solid creased receiver petal {i}', verts, faces, 'bone')
            art.tube(f'Slag-wheel petal molten incision {i}', [(1.30 * math.cos(a), 1.30 * math.sin(a), .80),
                     (2.02 * math.cos(a), 2.02 * math.sin(a), 1.83), (2.05 * math.cos(a), 2.05 * math.sin(a), 2.80)],
                     [.035, .021, .003], 'amber', 5)
    with assembly('Horizontal open toothed flywheel and vertical heat spindle'):
        for r, z, thickness, mat in [(1.93, 5.76, .13, 'steel'), (1.67, 5.72, .065, 'bone'), (.54, 5.72, .095, 'steel')]:
            art.ring(f'Slag-wheel horizontal flywheel race {r}', (0, 0, z), r, thickness, mat, segments=32)
        for i in range(12):
            a = i * math.tau / 12
            art.tube(f'Slag-wheel horizontal radial spoke {i}', [(.5 * math.cos(a), .5 * math.sin(a), 5.72),
                     (1.80 * math.cos(a), 1.80 * math.sin(a), 5.72)], .075, 'steel', 8)
            tooth = art.box(f'Slag-wheel downward drive tooth {i}', (1.87 * math.cos(a), 1.87 * math.sin(a), 5.39),
                             (.21, .18, .44), 'bone', .015)
            tooth.rotation_euler.z = a
        shell('Slag-wheel open central spindle jacket', [(.35, 2.58), (.38, 6.74), (.23, 6.74), (.21, 2.58)], 'black', steps=16)
        art.tube('Slag-wheel exposed molten spindle fraction', [(0, -.23, 2.7), (0, -.23, 6.71)], .105, 'amber', 8)
        for z in (2.75, 3.77, 4.74, 6.46):
            art.ring(f'Slag-wheel spindle bearing collar {z}', (0, 0, z), .40, .063, 'steel', segments=16)
    with assembly('Twin slag condensers and arched wheel support'):
        for side in (-1, 1):
            retort(f'Slag-wheel cold side fractionator {side}', side * 2.48, .25, .34, .31, 3.49, 'scar')
            bend(f'Slag-wheel rear flywheel hanging yoke {side}', [(side * 2.5, .9, .28),
                 (side * 2.67, 1.15, 6.39), (side * 1.25, .88, 7.12), (0, .56, 7.06)], .10, 'steel', 8, 16)
            bend(f'Slag-wheel support-to-hub bearing strut {side}', [(side * 2.44, .30, 4.07),
                 (side * 2.33, .48, 5.86), (side * .60, .57, 6.05), (side * .21, .1, 5.91)], .073, 'bone', 6, 14)
    with assembly('Molten filaments, lower slag fangs and instrumentation'):
        for i in range(5):
            a = i * math.tau / 5
            art.tube(f'Slag-wheel descending molten fraction {i}', [(.22 * math.cos(a), .22 * math.sin(a), 2.72),
                     (.33 * math.cos(a), .33 * math.sin(a), 1.56), (.16 * math.cos(a), .16 * math.sin(a), .69)],
                     [.059, .041, .01], 'amber', 6)
        for side in (-1, 1):
            dial(f'Slag-wheel receiving heat regulator {side}', (side * 2.18, -1.18, .63), .18)


def curtain_leaf(x, top, length):
    verts, faces = [], []
    for layer in (0, .065):
        for row in range(5):
            t = row / 4
            for edge in (-1, 1):
                verts.append((x + edge * (.22 - .19 * t * t), -.43 + .13 * math.sin(t * math.pi * 3) + layer,
                              top - t * length + edge * .08 * (row % 2)))
    for row in range(4):
        k = row * 2
        faces.extend([(k, k + 2, k + 3, k + 1), (k + 10, k + 11, k + 13, k + 12)])
        for edge in (0, 1):
            k = row * 2 + edge
            face = (k, k + 10, k + 12, k + 2)
            faces.append(face if edge == 0 else tuple(reversed(face)))
    faces.extend([(0, 1, 11, 10), (8, 18, 19, 9)])
    return verts, faces


def bound_furnace():
    with assembly('Bound furnace four independent threshold piers'):
        for side in (-1, 1):
            for back in (-1, 1):
                x, y = side * 2.36, back * .48
                art.box(f'Bound furnace independent footing {side} {back}', (x, y, .14), (.79, .73, .28), 'iron', .025)
                shell(f'Bound furnace hollow threshold pier {side} {back}', [(.23, .28), (.29, 6.16), (.18, 6.16), (.16, .28)],
                      'bone', center=(x, y, 0), steps=12)
                for z in (.67, 2.31, 4.01, 5.71):
                    art.ring(f'Bound furnace pier heat restraint {side} {back} {z}', (x, y, z), .32, .059, 'steel', segments=12)
        for side in (-1, 1):
            bend(f'Bound furnace rising copper lintel side {side}', [(0, .06, 6.62),
                 (side * 1.53, .06, 6.62), (side * 2.76, .06, 6.67), (side * 3.31, .06, 7.05)], .17, 'steel', 10, 12)
            art.box(f'Bound furnace lower horizontal tie {side}', (side * 1.12, .03, 6.05), (2.49, .38, .19), 'iron', .015)
            art.box(f'Bound furnace lintel saddle {side}', (side * 2.35, .03, 6.56), (.28, .89, .42), 'bone', .015)
    with assembly('Hot braided binding and solid hanging curtain leaves'):
        for strand in range(3):
            points = []
            for i in range(43):
                t, a = -1 + i / 21, i * math.tau / 7 + strand * math.tau / 3
                points.append((2.58 * t, -.53 + .13 * math.cos(a),
                               5.86 - .50 * (1 - t * t) + .13 * math.sin(a)))
            art.tube(f'Bound furnace heat-crimped braided binding {strand}', points, .105, 'bone', 6)
        for i in range(6):
            x, top = -1.76 + i * .70, 5.34 + .09 * abs(-1.76 + i * .70)
            verts, faces = curtain_leaf(x, top, 3.03 - .32 * (i % 3))
            art.mesh(f'Bound furnace thick torn membrane curtain {i}', verts, faces, 'scar')
            art.box(f'Bound furnace curtain heat clamp {i}', (x, -.51, top - .04), (.25, .09, .15), 'steel', .01)
            for stitch in range(3):
                z = top - .5 - stitch * .49
                art.tube(f'Bound furnace curtain incision staple {i} {stitch}', [(x - .073, -.51, z),
                         (x + .073, -.51, z + .028)], .012, 'black', 4)
    with assembly('Independent lateral heated retorts and exhaust returns'):
        for side in (-1, 1):
            retort(f'Bound furnace lateral hot retort {side}', side * 2.85, .05, 1.73, .30, 2.12)
            bend(f'Bound furnace pier-to-retort exhaust {side}', [(side * 2.39, .27, .29),
                 (side * 3.42, .44, .9), (side * 3.40, .19, 2.82), (side * 2.86, .08, 3.75)], .093, 'steel', 8, 14)
            bend(f'Bound furnace upper vented return {side}', [(side * 2.85, .05, 4.1),
                 (side * 3.46, .47, 5.87), (side * 2.0, .39, 6.33), (side * 1.73, .06, 6.16)], .082, 'steel', 6, 14)
    with assembly('Threshold receiving trench and low release valves'):
        art.box('Bound furnace low curtain receiving trench', (0, .22, .11), (4.45, 1.63, .22), 'iron', .02)
        for i in range(5):
            x = -1.39 + i * .7
            art.box(f'Bound furnace glowing trench opening {i}', (x, .05, .238), (.43, .83, .025), 'amber')
        for side in (-1, 1):
            dial(f'Bound furnace curtain tension regulator {side}', (side * 2.35, -.89, .74), .20)


def pressure_cell(width):
    """Pure editable pointed cup: thick rim, recessed cavity and closed rear."""
    outline = [(-.5, -.30), (-.5, .19), (0, .59), (.5, .19), (.5, -.30)]
    verts = [(tx * width * scale, depth, tz * scale)
             for depth, scale in [(0, 1), (0, .77), (.34, .68), (.44, .88)] for tx, tz in outline]
    faces = [(front + j, front + (j + 1) % 5, back + (j + 1) % 5, back + j)
             for front, back in [(5, 0), (10, 5), (0, 15)] for j in range(5)]
    faces.extend([(14, 13, 12, 11, 10), (15, 16, 17, 18, 19)])
    return verts, faces


def pressure_canopy():
    with assembly('Canopy four restrained support towers and suspension'):
        art.box('Canopy low pressure receiving foundation', (0, .11, .12), (5.7, 4.9, .24), 'iron', .05)
        for side in (-1, 1):
            for back in (-1, 1):
                x, y = side * 2.35, back * 1.51
                art.box(f'Canopy independent pressure tower foot {side} {back}', (x, y, .41), (.64, .64, .34), 'steel', .025)
                art.tube(f'Canopy posterior tension tower {side} {back}', [(x, y, .57), (x, y, 6.41)], .12, 'iron', 8)
                bend(f'Canopy high suspension brace {side} {back}', [(x, y, 6.39),
                     (x, y, 7.88), (x * .45, y * .45, 8.17), (0, 0, 8.13)], .083, 'steel', 6, 14)
                for z in (1.0, 3.0, 5.0):
                    art.ring(f'Canopy tower segmented lock {side} {back} {z}', (x, y, z), .16, .044, 'bone', segments=12)
    with assembly('Five tiers of actual deep corbelled pressure recesses'):
        for tier, (radius, z, count) in enumerate([(.73, 3.27, 6), (1.44, 3.99, 10),
                                                 (2.18, 4.71, 12), (1.98, 5.43, 10), (1.19, 6.15, 8)]):
            art.ring(f'Canopy stepped corbel carrier {tier}', (0, 0, z - .08), radius, .083, 'steel', segments=24)
            for cell in range(count):
                a = (cell + .5 * (tier % 2)) * math.tau / count
                width = radius * math.tau / count * .84
                local, faces = pressure_cell(width)
                verts = [((radius - depth) * math.cos(a) - tang * math.sin(a),
                          (radius - depth) * math.sin(a) + tang * math.cos(a), z + dz)
                         for tang, depth, dz in local]
                art.mesh(f'Canopy deeply recessed muqarnas cell {tier} {cell}', verts, faces, 'bone')
                lip = [verts[j] for j in (0, 1, 2, 3, 4)]
                art.tube(f'Canopy raised incised cell lip {tier} {cell}', lip, .020, 'scar', 5)
        for i in range(8):
            a = i * math.tau / 8
            bend(f'Canopy upper skeletal lattice rib {i}', [(1.27 * math.cos(a), 1.27 * math.sin(a), 6.51),
                 (1.08 * math.cos(a), 1.08 * math.sin(a), 7.19), (.67 * math.cos(a), .67 * math.sin(a), 7.47),
                 (0, 0, 7.74)], .040, 'bone', 6, 12)
        art.ring('Canopy high open patterned lattice belt', (0, 0, 7.16), .98, .034, 'bone', segments=24)
    with assembly('Open pendant condensation throat and trailing fractions'):
        shell('Canopy thick pendant drain throat', [(.54, 3.30), (.41, 2.58), (.27, 2.08),
              (.18, 2.08), (.29, 2.58), (.41, 3.30)], 'skin', steps=20)
        for i in range(6):
            a = i * math.tau / 6
            art.tube(f'Canopy downward condensed fraction {i}', [(.23 * math.cos(a), .23 * math.sin(a), 2.19),
                     (.18 * math.cos(a), .18 * math.sin(a), 1.32), (.10 * math.cos(a), .10 * math.sin(a), .29)],
                     [.039, .026, .004], 'amber' if i % 2 else 'skin', 6)
        art.egg('Canopy recessed condensate receiver', (0, 0, .28), (.52, .48, .024), 'black', 16, 6)
    with assembly('Rear condensation bypasses and low calibration'):
        for side in (-1, 1):
            bend(f'Canopy diagonal copper exhaust return {side}', [(side * 2.30, 1.48, .59),
                 (side * 2.78, 1.47, 3.89), (side * 1.96, .96, 5.17), (side * 1.32, .31, 5.67)], .075, 'steel', 6, 14)
            dial(f'Canopy exhaust regulator {side}', (side * 2.30, -1.87, .80), .20)


def tower_cluster():
    with assembly('Tower cluster common ground terrace and receiving steps'):
        art.box('Tower cluster low stepped receiving foundation', (0, .13, .13), (5.3, 3.8, .26), 'iron', .055)
        for i in range(5):
            rise = 4 - i
            art.box(f'Tower cluster forward receiving tread {i}', (0, -1.67 - i * .15, .07 + rise * .058),
                    (1.37, .33, .14 + rise * .116), 'bone', .015)
        for side in (-1, 1):
            bend(f'Tower cluster lower fraction return {side}', [(side * 2.19, .69, .27),
                 (side * 2.77, 1.06, 1.97), (side * 1.37, 1.17, 3.13), (side * .28, .45, 2.39)], .095, 'steel', 8, 14)
    with assembly('Five staggered round tower chambers and open tier niches'):
        for index, (x, y, top, radius) in enumerate([(0, .61, 8.02, .51), (-1.02, .76, 6.44, .41),
                                                  (1.02, .76, 6.13, .41), (-1.89, .10, 4.91, .35), (1.89, .10, 5.19, .35)]):
            retort(f'Tower cluster fractionation tower {index}', x, y, .30, radius, top - .30)
            for tier in range(3):
                z = .71 + tier * (top - 1.03) / 3
                r = radius * (1.48 - tier * .10)
                shell(f'Tower cluster carved hollow stage cornice {index} {tier}', [(r, z), (r + .065, z + .10),
                      (r, z + .24), (r * .71, z + .24), (r * .71, z), (r, z)], 'bone', center=(x, y, 0), steps=16)
                for side in (-1, 1):
                    bend(f'Tower cluster pointed open chamber niche {index} {tier} {side}', [(x + side * r * .80, y - .47, z + .2),
                         (x + side * r * .83, y - .50, z + .67), (x + side * r * .42, y - .51, z + .93),
                         (x, y - .49, z + 1.06)], .046, 'bone', 6, 10)
                    art.tube(f'Tower cluster carved niche side flute {index} {tier} {side}', [(x + side * r * .84, y - .53, z + .25),
                             (x + side * r * .84, y - .53, z + .62)], .017, 'steel', 5)
                art.box(f'Tower cluster stage anterior restraint {index} {tier}', (x, y - radius * .86, z + .58),
                        (.10, .06, .35), 'bone', .01)
    with assembly('Cross-linked tower roof conduits and living fractions'):
        for side in (-1, 1):
            bend(f'Tower cluster high curved transfer main {side}', [(0, .63, 7.53),
                 (side * 1.22, 1.02, 7.37), (side * 1.30, .72, 5.73), (side * 1.87, .1, 4.51)], .10, 'steel', 8, 16)
            bend(f'Tower cluster exposed living thermal ligament {side}', [(side * .12, -.06, .44),
                 (side * .73, -.22, 1.73), (side * .37, -.16, 4.29), (side * .12, .01, 6.96)], (.10, .035), 'skin', 6, 16)
        for i in range(9):
            art.box(f'Tower cluster central heat spine relief {i}', (0, -.03, .88 + i * .67), (.29, .15, .13), 'bone', .013)
    with assembly('Cluster low fraction valves and sump outlets'):
        for side in (-1, 1):
            dial(f'Tower cluster receiving regulator {side}', (side * 2.17, -.86, .65), .19)
        art.box('Tower cluster recessed front outlet', (0, -1.28, .47), (.45, .14, .14), 'black', .01)
        art.tube('Tower cluster visible front molten spill', [(0, -1.29, .45), (.03, -1.47, .30), (.08, -1.6, .15)], [.055, .041, .008], 'amber', 6)


def control_blade(x):
    verts = [(x - .20, .26, .27), (x + .20, .26, .27), (x + .13, .28, 4.06), (x, .28, 4.91), (x - .13, .28, 4.06),
             (x - .20, .42, .27), (x + .20, .42, .27), (x + .13, .44, 4.06), (x, .44, 4.91), (x - .13, .44, 4.06)]
    faces = [(4, 3, 2, 1, 0), (5, 6, 7, 8, 9)]
    faces.extend((j, (j + 1) % 5, (j + 1) % 5 + 5, j + 5) for j in range(5))
    return verts, [tuple(reversed(face)) for face in faces]


def lamp_manifold():
    with assembly('Lamp manifold bifurcated roots and front receiving platform'):
        art.box('Lamp manifold broad low distribution foundation', (0, .15, .13), (5.7, 2.9, .26), 'iron', .055)
        for side in (-1, 1):
            bend(f'Lamp manifold braided root fork {side}', [(side * 2.13, .57, .28),
                 (side * 1.63, .69, 1.14), (side * .49, .16, 1.83), (side * .15, .11, 3.17)], .16, 'bone', 8, 14)
            bend(f'Lamp manifold paired trunk copper feed {side}', [(side * 2.25, .85, .28),
                 (side * 2.80, .74, 1.42), (side * .72, .33, 2.17), (side * .17, .28, 3.93)], .12, 'steel', 8, 14)
        art.tube('Lamp manifold exposed central heat distributor', [(0, .12, .28), (0, .12, 5.11)], .13, 'amber', 8)
    with assembly('Seven upright staggered observation retorts and branched feeds'):
        for i in range(7):
            x = (i - 3) * .86
            bottom = 4.62 - abs(i - 3) * .16
            y = .18 + abs(i - 3) * .10
            retort(f'Lamp manifold upright observation reservoir {i}', x, y, bottom, .27, 1.73, 'skin')
            bend(f'Lamp manifold ivory fraction delivery fork {i}', [(0, .1, 1.53 + abs(i - 3) * .48),
                 (x * .82, .15, 2.09 + abs(i - 3) * .32), (x, y, bottom - .67), (x, y, bottom + .08)],
                 (.135, .065), 'bone', 8, 14)
            bend(f'Lamp manifold copper independent return {i}', [(0, .33, .85 + abs(i - 3) * .40),
                 (x * 1.06, .48, 2.83), (x + .12, y + .21, bottom - .33), (x + .12, y + .18, bottom + .34)],
                 .043, 'steel', 6, 12)
            art.egg(f'Lamp manifold fraction gland {i}', (x, y - .14, bottom + .88), (.11, .07, .18), 'scar', 10, 6)
    with assembly('Ivory control blades flanking the distribution tree'):
        for side in (-1, 1):
            x = side * 2.83
            verts, faces = control_blade(x)
            art.mesh(f'Lamp manifold solid tapered control blade {side}', verts, faces, 'bone')
            for i in range(6):
                art.box(f'Lamp manifold blade incision clamp {side} {i}', (x, .21, .92 + i * .45), (.11, .07, .055), 'steel')
    with assembly('Manifold fraction taps and low pressure gauges'):
        for side in (-1, 1):
            dial(f'Lamp manifold fraction regulator {side}', (side * 1.91, -1.04, .68), .20)
        for i in range(7):
            art.box(f'Lamp manifold front independent fraction tap {i}', ((i - 3) * .23, -.72, .51), (.07, .29, .16), 'bone', .01)


def solar_crucible():
    with assembly('Solar crucible broad thick receiver and molten collection'):
        art.box('Solar crucible low winged containment foundation', (0, .13, .13), (7.4, 3.4, .26), 'iron', .055)
        shell('Solar crucible broad concave molten receiver', [(2.16, 1.42), (2.18, 1.66), (1.94, 1.79),
              (1.17, .98), (.33, .51), (.33, .35), (1.30, .67), (1.90, 1.10), (2.16, 1.42)],
              'bone', center=(0, .13, 0), aspect=(1, .60), steps=24)
        art.egg('Solar crucible recessed molten charge pool', (0, .13, .54), (.70, .41, .023), 'amber', 16, 6)
        for side in (-1, 1):
            art.box(f'Solar crucible wing lower receiving rail {side}', (side * 2.51, .51, .48), (1.76, 1.44, .32), 'steel', .025)
    with assembly('Broad feathered cooling wings with incised solid vanes'):
        for side in (-1, 1):
            bend(f'Solar crucible upper wing load spar {side}', [(side * .54, .34, 3.75),
                 (side * 1.66, .44, 3.24), (side * 2.84, .53, 3.43), (side * 3.52, .59, 3.98)], .10, 'steel', 8, 16)
            for i in range(8):
                x, z = side * (.83 + i * .35), 3.09 + .07 * i
                tip_x, tip_z = side * (1.25 + i * .31), 1.85 + .075 * i
                verts = [(x - side * .15, .33, z), (x + side * .21, .35, z + .06), (tip_x + side * .12, .18, tip_z),
                         (tip_x - side * .08, .16, tip_z - .21), (x - side * .15, .48, z),
                         (x + side * .21, .50, z + .06), (tip_x + side * .12, .33, tip_z), (tip_x - side * .08, .31, tip_z - .21)]
                faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
                if side < 0:
                    faces = [tuple(reversed(face)) for face in faces]
                art.mesh(f'Solar crucible thick articulated wing feather {side} {i}', verts, faces, 'bone')
                art.tube(f'Solar crucible carved feather copper seam {side} {i}', [(x, .27, z - .04),
                         (tip_x, .12, tip_z + .07)], [.025, .008], 'steel', 5)
    with assembly('Inclined containment jaws and bound solar charge'):
        for side in (-1, 1):
            plate = art.box(f'Solar crucible inclined solid containment jaw {side}', (side * 1.56, -.12, 2.47),
                            (.57, .61, 4.20), 'bone', .035)
            plate.rotation_euler.y = side * .20
            for i in range(6):
                z = 1.03 + i * .53
                x = side * (1.30 + .16 * z)
                art.box(f'Solar crucible fictional jaw control incision {side} {i}', (x, -.46, z), (.10, .06, .075), 'black')
            bend(f'Solar crucible posterior jaw pressure line {side}', [(side * 2.56, .91, .27),
                 (side * 3.01, 1.03, 2.45), (side * 2.51, .85, 4.55), (side * 1.51, .26, 4.59)], .09, 'steel', 8, 16)
        art.egg('Solar crucible bound red charge organ', (0, .11, 3.77), (.74, .38, .74), 'skin', 20, 10)
        art.ring('Solar crucible radial charge retaining race', (0, .11, 3.77), .99, .075, 'steel', 'XZ', 28)
        for i in range(16):
            a = i * math.tau / 16
            c, s = math.cos(a), math.sin(a)
            art.tube(f'Solar crucible short articulated shutter ray {i}', [(.84 * c, .10, 3.77 + .84 * s),
                     (1.14 * c, .10, 3.77 + 1.14 * s), (1.40 * c, .10, 3.77 + 1.40 * s)], [.065, .045, .024], 'steel', 6)
        for side in (-1, 1):
            bend(f'Solar crucible anterior ivory core clamp {side}', [(side * .06, -.21, 4.48),
                 (side * .77, -.39, 4.09), (side * .72, -.41, 3.33), (side * .07, -.20, 3.05)], .050, 'bone', 6, 12)
    with assembly('Final molten binding drain and low release regulators'):
        art.tube('Solar crucible molten final binding filament', [(0, -.10, 3.11), (.10, -.08, 2.13),
                 (-.04, .07, 1.23), (0, .13, .56)], [.095, .081, .049, .014], 'amber', 8)
        for side in (-1, 1):
            dial(f'Solar crucible final charge regulator {side}', (side * 2.53, -.79, .78), .22)
            art.egg(f'Solar crucible low red fraction valve {side}', (side * 2.30, -.72, .40), (.21, .14, .075), 'scar', 10, 6)


def setup():
    scene = original_setup()
    foundry.skin_texture()
    for key, color in [('steel', '#784d32'), ('iron', '#252b2d'), ('bone', '#b9ad92')]:
        rgba = art.rgba(color)
        art.M[key].diffuse_color = rgba
        art.M[key].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = rgba
    image = bpy.data.images.load(str(art.OUT / 'textures/surface_atlas.png'), check_existing=True)
    image.pack()
    nodes = art.M['iron'].node_tree
    texture = nodes.nodes.new('ShaderNodeTexImage')
    texture.image, texture.interpolation = image, 'Closest'
    nodes.links.new(texture.outputs['Color'], nodes.nodes.get('Principled BSDF').inputs['Base Color'])
    return scene


def build_scene(name):
    globals()[name.removeprefix('foundry_')]()
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices),
               'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert triangles <= 30000, (name, triangles)
    assert abs(extent['min'][2]) <= .001 and all(v <= cap for v, cap in zip(extent['size'], CAPS)), (name, extent)
    groups = [c.name for c in bpy.context.scene.collection.children if c.objects]
    assert len(groups) >= 4, (name, groups)
    STATS[name] = {'source_mesh_count': len(meshes), 'triangles': triangles, 'physical_bounds_m': extent,
                   'source_hierarchy_groups': len(groups), 'assembly_names': groups, 'source_meshes': counts}
    scene = bpy.context.scene
    scene['asset_id'], scene['authoring_recipe'] = name, 'tools/build_religious_foundry_art.py'
    scene['recipe_sha256'] = art.sha(Path(__file__))
    scene['reference_images'], scene['machine_purpose'] = json.dumps(REFERENCES, sort_keys=True), PURPOSES[name]


def main():
    global bpy, art, foundry, bend, shell, dial, original_setup
    opts = arguments(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    project = Path(__file__).resolve().parents[1]
    output, receipt = preflight(opts.asset, opts.output_root, opts.receipt_root, project)
    import bpy
    import build_art as art
    import build_foundry_art as foundry
    bend, shell, dial = foundry.bend, foundry.shell, foundry.dial
    manifest_data = (project / 'source/art/manifest.json').read_bytes()
    manifest = json.loads(manifest_data)
    dependencies = {str(Path(m.__file__).relative_to(project)): art.sha(Path(m.__file__)) for m in (art, foundry, intake)}
    assert dependencies['tools/build_art.py'] == manifest['build']['script_sha256'], 'Shared art helper drift; do not build'
    assert all(a['recipe_sha256'] == dependencies['tools/build_foundry_art.py'] for a in manifest['assets']
               if a['id'] in foundry.IDS), 'Original Foundry helper drift; do not build'
    assert all(art.sha(project / path) == digest for path, digest in REFERENCES.items()), 'Foundry reference drift'
    atlas = project / 'game/assets/art/textures/surface_atlas.png'
    atlas_record = next(o for a in manifest['assets'] for o in a['outputs']
                        if o['path'] == 'game/assets/art/textures/surface_atlas.png')
    assert art.sha(atlas) == atlas_record['sha256'], 'Shared atlas drift'
    original_setup = art.setup
    art.ROOT, art.ART, art.OUT, art.SCRATCH = output, output / 'source/art', output / 'game/assets/art', output / 'previews'
    art.setup, art.scenery = setup, build_scene
    atlas_path = art.OUT / 'textures/surface_atlas.png'
    if atlas_path.is_symlink():
        raise ValueError('Foundry candidate atlas must not be a symlink')
    atlas_copy = art.target(atlas_path)
    if atlas_copy.exists():
        assert art.sha(atlas_copy) == atlas_record['sha256'], 'Candidate atlas drift'
    else:
        shutil.copyfile(atlas, atlas_copy)
    print('ART_START ' + opts.asset, flush=True)
    entry = art.world_export(opts.asset)
    entry.update({key: STATS[opts.asset][key] for key in ('source_mesh_count', 'source_hierarchy_groups', 'assembly_names')})
    entry.update(recipe_sha256=art.sha(Path(__file__)), recipe_dependencies=dependencies,
                 reference_images=[{'path': p, 'sha256': h} for p, h in REFERENCES.items()],
                 tradition_aesthetic=TRADITIONS[opts.asset], level_id='foundry', machine_purpose=PURPOSES[opts.asset],
                 texture_dependencies={atlas_record['path']: atlas_record['sha256']},
                 facing='front Blender -Y; exported Godot +Z', collision='none; parent authors explicit bases/solid cover')
    entry['provenance']['authoring_script'] = 'tools/build_religious_foundry_art.py'
    entry['provenance']['fiction'] = 'Fictional controller commandeering worship systems; no real-community villains or historical claims'
    assert entry['runtime_mesh_nodes'] <= 7 and entry['triangles'] == STATS[opts.asset]['triangles']
    assert sum((art.OUT / 'world' / (asset + '.glb')).stat().st_size for asset in IDS
               if (art.OUT / 'world' / (asset + '.glb')).exists()) < 8 * 1024 * 1024, 'Seven Foundry GLB budget'
    payload = {**STATS[opts.asset], 'asset': entry, 'output_root': str(output), 'blender_version': bpy.app.version_string,
               'preview': str(art.SCRATCH / (opts.asset + '_preview.png')), 'status': 'native_candidate_not_integrated',
               'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest()}
    receipt.mkdir(parents=True, exist_ok=True)
    (receipt / (opts.asset + '_candidate.json')).write_text(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
