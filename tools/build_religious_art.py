"""Image-derived Intake machinery, isolated from authoritative production outputs.

Parent dispatch only: blender -b -t 4 --python tools/build_religious_art.py --
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

IDS = ('intake_throat_frame', 'intake_wheel_reservoir', 'intake_bound_gate',
       'intake_pressure_screen', 'intake_ascending_engine', 'intake_seven_lamps',
       'intake_solar_seal')
TRADITIONS = dict(zip(IDS, ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
REFERENCES = {
    'source/art/references/religion-intake-01.png': '7a7a48f2bde6b0e6047f83fc1fd2ed435fba8d52e2c050c8baf7269b9278c6af',
    'source/art/references/intake-01.png': '9d725c3db9c6568a4b39f87ef167af129237c0e823251c7ad751fe9dbb0fcfff',
}
CAPS = (8, 6, 9)
STATS = {}


def candidate_roots(output_root, receipt_root, project_root):
    """Resolve symlinks and reject production overlap before any writes."""
    output, receipt, project = (Path(p).resolve() for p in (output_root, receipt_root, project_root))
    if any(p.is_relative_to(project) or project.is_relative_to(p) for p in (output, receipt)):
        raise ValueError('Candidate output and receipts must not overlap the production project')
    if not output.is_relative_to(receipt):
        raise ValueError('Candidate output must remain inside the explicit receipt root')
    for folder in ('source/art', 'game/assets/art/world', 'game/assets/art/textures', 'previews/frames'):
        if not (output / folder).resolve().is_relative_to(output):
            raise ValueError('Candidate subdirectories must not escape through symlinks')
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


def witness(name, x, y, z, scale=.5):
    """Carved fictional operator, with open jaw and separate rib/clamp volumes."""
    s = scale
    art.egg(name + ' brow', (x, y, z + .64 * s), (.25 * s, .16 * s, .17 * s), 'bone', 12, 6)
    for side in (-1, 1):
        bend(name + f' open cheek and jaw {side}', [(x + side * .22 * s, y, z + .63 * s),
             (x + side * .26 * s, y - .14 * s, z + .37 * s),
             (x + side * .17 * s, y - .14 * s, z + .19 * s), (x, y, z + .18 * s)], .045 * s, 'bone', 6, 8)
        art.egg(name + f' recessed socket {side}', (x + side * .12 * s, y - .15 * s, z + .59 * s),
                (.068 * s, .035 * s, .058 * s), 'black', 8, 4)
        for i in range(4):
            zz = z + (.08 - i * .13) * s
            bend(name + f' exposed carved rib {side} {i}', [(x, y + .06 * s, zz),
                 (x + side * .37 * s, y + .03 * s, zz + .12 * s),
                 (x + side * .38 * s, y - .17 * s, zz + .08 * s),
                 (x + side * .08 * s, y - .16 * s, zz - .03 * s)], .028 * s, 'bone', 5, 6)
        art.tube(name + f' folded clamp arm {side}', [(x + side * .32 * s, y, z),
                 (x + side * .41 * s, y - .17 * s, z - .39 * s), (x, y - .22 * s, z - .26 * s)], .05 * s, 'steel', 6)
    art.tube(name + ' raised vertebral relief', [(x, y + .03 * s, z + .20 * s),
             (x, y + .02 * s, z - .58 * s)], .047 * s, 'bone', 6)
    for i in range(5):
        art.box(name + f' spinal clamp {i}', (x, y - .04 * s, z + (.1 - i * .14) * s),
                (.15 * s, .06 * s, .052 * s), 'iron')


def throat_frame():
    with assembly('Throat foundation and four tension piers'):
        art.box('Throat open-sump foundation', (0, .18, .13), (5.4, 3.4, .26), 'iron', .04)
        art.box('Throat recessed receiving wound', (0, -.15, .29), (2.7, 1.7, .04), 'black')
        for x in (-2.2, 2.2):
            for y in (-.9, 1.15):
                art.box(f'Throat pier foot {x} {y}', (x, y, .4), (.74, .74, .28), 'steel', .035)
                bend(f'Gothic load pier {x} {y}', [(x, y, .5), (x * 1.04, y, 3.2),
                     (x * .97, y, 6.6), (x * .57, y * .45, 7.8)], (.16, .10), 'bone', 8, 18)
                for i in range(8):
                    art.ring(f'Throat pier copper restraint {x} {y} {i}', (x, y, .8 + i * .72), .21, .045, 'steel', segments=12)
        for side in (-1, 1):
            bend(f'Pointed anterior suspension ogive {side}', [(side * 2.18, -.92, 1.4),
                 (side * 2.6, -.84, 5.5), (side * 1.3, -.55, 7.5), (0, -.12, 8.25)], (.12, .065), 'bone', 8, 22)
            bend(f'Posterior copper pressure arch {side}', [(side * 2.18, 1.15, .5),
                 (side * 2.8, 1.38, 6.7), (side * .8, 1.0, 8.1), (0, .4, 8.25)], .10, 'steel', 8, 20)
    with assembly('Suspended hollow throat and radial bone stays'):
        shell('Flared double-wall throat bell', [(1.50, 3.05), (1.55, 3.23), (1.26, 3.6), (.85, 4.8),
              (.48, 5.8), (.38, 5.8), (.71, 4.8), (1.13, 3.6), (1.36, 3.23), (1.50, 3.05)], 'iron', steps=32)
        shell('Inner blood pressure throat', [(.32, 5.73), (.55, 4.83), (.72, 3.7), (.62, 3.24),
              (.52, 3.24), (.60, 3.7), (.43, 4.83), (.24, 5.73)], 'skin', steps=24)
        art.ring('Throat ivory flared lip', (0, 0, 3.22), 1.50, .10, 'bone', segments=32)
        for i in range(8):
            a = i * math.tau / 8
            c, s = math.cos(a), math.sin(a)
            bend(f'Bell external vertebral tension stay {i}', [(1.49 * c, 1.49 * s, 3.27),
                 (1.08 * c, 1.08 * s, 4.55), (.61 * c, .61 * s, 5.45), (.41 * c, .41 * s, 6.15)], (.075, .042), 'bone', 6, 12)
            for j in range(6):
                t = j / 5
                art.egg(f'Bell articulated stay knuckle {i} {j}', ((1.38 - .86 * t) * c,
                        (1.38 - .86 * t) * s, 3.5 + 2.35 * t), (.105, .09, .075), 'bone', 8, 4)
            art.tube(f'Bell hanging coagulated tongue {i}', [(.65 * c, .65 * s, 3.37),
                     (.57 * c, .57 * s, 2.52), (.34 * c, .34 * s, 1.55 + .15 * (i % 3))], [.10, .07, .003], 'skin', 6)
        art.tube('Throat upper suspension spine', [(0, 0, 5.8), (0, .1, 8.21)], .13, 'steel', 8)
        for i in range(9):
            art.box(f'Throat anterior vertebral suspension lock {i}', (0, -.15, 6.0 + i * .25), (.29, .10, .12), 'bone', .018)
    with assembly('Flayed wing vanes and voice relief valves'):
        for side in (-1, 1):
            # Closed pleated wedges, not a single painted membrane plane.
            for i in range(4):
                z = 3.4 + i * .75
                x = side * (1.15 - i * .12)
                verts = [(x, .23, z), (side * 2.18, .31, z + .45), (side * 2.0, .38, z + 1.15),
                         (x, .39, z), (side * 2.18, .47, z + .45), (side * 2.0, .54, z + 1.15)]
                art.mesh(f'Pleated throat membrane wing {side} {i}', verts,
                         [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], 'skin')
                art.tube(f'Wing ivory spar {side} {i}', [verts[0], verts[1], verts[2]], [.035, .07, .022], 'bone', 6)
            for i in range(3):
                witness(f'Throat screaming relief valve {side} {i}', side * 2.14, -1.02, 1.6 + i * 1.37, .63)
    with assembly('Throat posterior feed and amber instrumentation'):
        for side in (-1, 1):
            bend(f'Throat ground-fed dorsal artery {side}', [(side * 2.15, 1.3, .4),
                 (side * 2.8, 1.65, 3.5), (side * 1.1, 1.4, 6.7), (side * .35, .16, 6.1)], .12, 'steel', 8, 18)
            dial(f'Throat tension regulator {side}', (side * 2.1, -1.35, .91), .22)
            art.egg(f'Throat amber base index {side}', (side * 2.35, -1.26, .58), (.065, .04, .16), 'amber', 8, 4)


def wheel_reservoir():
    with assembly('Reservoir open lotus basin and carved petals'):
        art.box('Reservoir broad machine plinth', (0, .2, .14), (5.4, 4.5, .28), 'iron', .08)
        shell('Reservoir thick concave receiver', [(2.1, 1.65), (2.18, 1.84), (1.96, 1.89), (1.5, 1.45),
              (.7, .83), (.26, .72), (.26, .56), (.87, .66), (1.74, 1.17), (2.1, 1.65)], 'bone', aspect=(1, .87), steps=32)
        art.egg('Reservoir recessed blood pool', (0, 0, .78), (.77, .58, .025), 'skin', 20, 6)
        for i in range(12):
            a = i * math.tau / 12
            verts, faces = [], []
            for layer in range(2):
                for row in range(7):
                    t = row / 6
                    width = .57 * math.sin(math.pi * t) + .035
                    r, z = 1.20 + 1.31 * t, .57 + 2.23 * t - .43 * t * t
                    for cross in (-1, 0, 1):
                        theta = a + cross * width / r
                        verts.append((r * math.cos(theta), .87 * r * math.sin(theta),
                                      z + .19 * (1 - cross * cross) * math.sin(math.pi * t) + layer * .09))
                        if row and cross > -1:
                            k = layer * 21 + row * 3 + cross + 1
                            face = (k - 4, k - 3, k, k - 1)
                            faces.append(face if layer else tuple(reversed(face)))
            for row in range(6):
                for edge in (0, 2):
                    k = row * 3 + edge
                    faces.append((k, k + 3, k + 24, k + 21))
            faces.extend([(0, 21, 23, 2), (18, 20, 41, 39)])
            art.mesh(f'Solid carved lotus receiver petal {i}', verts, faces, 'bone')
            art.tube(f'Lotus petal raised copper vein {i}', [(1.34 * math.cos(a), 1.17 * math.sin(a), .85),
                     (1.92 * math.cos(a), 1.67 * math.sin(a), 1.75),
                     (2.38 * math.cos(a), 2.07 * math.sin(a), 2.31)], [.03, .022, .003], 'steel', 5)
    with assembly('Eight-spoke circulation wheel and bearing pylons'):
        for side in (-1, 1):
            art.box(f'Wheel rear bearing pylon {side}', (side * 1.9, .87, 2.63), (.29, .37, 4.7), 'iron', .035)
            bend(f'Wheel posterior curved circulation yoke {side}', [(side * 2.5, .91, .3),
                 (side * 3.15, 1.22, 4.8), (side * 1.8, .94, 7.0), (0, .81, 7.35)], .10, 'steel', 8, 18)
        for radius, thickness, mat in [(2.13, .13, 'steel'), (1.92, .07, 'bone'), (.72, .08, 'bone')]:
            art.ring(f'Circulation wheel open concentric rim {radius}', (0, .05, 4.86), radius, thickness, mat, 'XZ', 40)
        for i in range(8):
            a = i * math.tau / 8
            c, s = math.cos(a), math.sin(a)
            art.tube(f'Eight-spoke ivory wheel actuator {i}', [(.48 * c, .05, 4.86 + .48 * s),
                     (1.07 * c, -.13, 4.86 + 1.07 * s), (1.89 * c, .05, 4.86 + 1.89 * s)], [.11, .085, .065], 'bone', 8)
            art.egg(f'Circulation wheel spoke hinge {i}', (1.14 * c, -.08, 4.86 + 1.14 * s), (.15, .12, .15), 'steel', 10, 6)
            art.tube(f'Circulation wheel copper index {i}', [(2.02 * c, -.09, 4.86 + 2.02 * s),
                     (2.25 * c, -.09, 4.86 + 2.25 * s)], .045, 'steel', 6)
        shell('Wheel center hollow pressure spindle', [(.36, 2.5), (.42, 6.12), (.28, 6.12), (.25, 2.5)], 'skin', steps=20)
        for i in range(10):
            art.ring(f'Wheel pressure spindle vertebral lock {i}', (0, 0, 2.78 + i * .31), .40, .065, 'bone', segments=12)
    with assembly('Visible descending fluid and open receiving teeth'):
        for i in range(5):
            x = (i - 2) * .14
            bend(f'Reservoir descending blood filament {i}', [(x, -.14, 3.0), (x + .13, -.32, 2.3),
                 (x - .12, -.18, 1.45), (x, -.06, .82)], (.055, .025), 'skin', 6, 14)
        for i in range(12):
            a = i * math.tau / 12
            art.tube(f'Reservoir inward receiving fang {i}', [(1.75 * math.cos(a), 1.52 * math.sin(a), 1.65),
                     (1.36 * math.cos(a), 1.18 * math.sin(a), 2.15),
                     (.91 * math.cos(a), .79 * math.sin(a), 1.9)], [.10, .058, .003], 'bone', 6)
    with assembly('Reservoir flank circulators and calibration'):
        for side in (-1, 1):
            bend(f'Reservoir flank copper return {side}', [(side * 2.35, .8, .29),
                 (side * 2.9, .5, 2.1), (side * 1.7, .4, 2.85), (side * 1.4, .12, 1.5)], .10, 'steel', 8, 18)
            dial(f'Reservoir purification pressure regulator {side}', (side * 2.3, -.73, .7), .20)


def bound_gate():
    with assembly('Bound threshold piers and upturned pressure lintels'):
        for side in (-1, 1):
            art.box(f'Gate independent pier foot {side}', (side * 2.22, 0, .17), (.97, 1.58, .34), 'iron', .045)
            shell(f'Gate tapered ivory pier {side}', [(.29, .34), (.36, 5.95), (.28, 6.22), (.22, 6.22), (.21, .34)],
                  'bone', center=(side * 2.22, 0, 0), steps=16)
            for i in range(9):
                art.ring(f'Gate pier segmented copper collar {side} {i}', (side * 2.22, 0, .73 + i * .59), .39, .065, 'steel', segments=16)
            bend(f'Gate dorsal feed line {side}', [(side * 2.22, .61, .24), (side * 2.9, .7, 3.0),
                 (side * 2.82, .52, 5.6), (side * 1.4, .21, 6.52)], .095, 'steel', 8, 18)
        # Extruded bent lintel: thick central sag, upturned ends and exposed underside.
        for level, height, mat in [(0, 6.2, 'bone'), (1, 6.75, 'steel')]:
            xs = [-3.4, -2.6, -1.3, 0, 1.3, 2.6, 3.4]
            verts, faces = [], []
            for x in xs:
                z = height + .35 * (abs(x) / 3.4) ** 2
                verts.extend([(x, -.33, z), (x, .33, z), (x, .33, z + .25), (x, -.33, z + .25)])
            for i in range(len(xs) - 1):
                for j in range(4):
                    k = i * 4 + j
                    faces.append((k, i * 4 + (j + 1) % 4, (i + 1) * 4 + (j + 1) % 4, k + 4))
            faces.extend([(3, 2, 1, 0), (24, 25, 26, 27)])
            art.mesh(f'Gate upturned extruded lintel {level}', verts, faces, mat)
            for x in (-2.22, 2.22):
                art.box(f'Gate lintel tension clamp {level} {x}', (x, -.38, height + .2), (.2, .16, .56), 'iron', .015)
    with assembly('Braided ivory binding and hanging folded membranes'):
        for strand in range(3):
            points = []
            for i in range(61):
                t = -1 + i / 30
                a = i * math.tau / 9 + strand * math.tau / 3
                points.append((2.45 * t, -.62 + .15 * math.cos(a),
                               5.52 - .53 * (1 - t * t) + .15 * math.sin(a)))
            art.tube(f'Gate three-strand braided binding {strand}', points, .12, 'bone', 6)
        for i in range(6):
            x = -1.72 + i * .69
            z = 5.0 + .08 * abs(x)
            art.tube(f'Gate folded tissue tassel {i}', [(x, -.63, z), (x + .12, -.67, z - .35),
                     (x - .13, -.60, z - .65), (x + .10, -.66, z - .94), (x - .09, -.61, z - 1.31)],
                     [.09, .085, .075, .06, .003], 'skin', 5)
            art.box(f'Gate tassel suture clamp {i}', (x, -.79, z - .08), (.18, .055, .10), 'steel', .01)
    with assembly('Suspended separation organ and open restraints'):
        art.egg('Gate suspended separation bladder', (0, .18, 2.93), (.67, .51, .92), 'skin', 20, 10)
        for i in range(6):
            a = i * math.tau / 6
            c, s = math.cos(a), math.sin(a)
            bend(f'Gate separation restraint rib {i}', [(.20 * c, .18 + .16 * s, 4.04),
                 (1.16 * c, .18 + .86 * s, 3.7), (1.16 * c, .18 + .86 * s, 2.33),
                 (.2 * c, .18 + .16 * s, 1.81)], (.065, .045), 'steel', 8, 16)
        art.tube('Gate organ upper ligament', [(0, .18, 4.0), (0, .13, 5.0)], .075, 'skin', 8)
        art.tube('Gate organ descending filtered tissue', [(0, .18, 2.12), (.11, .12, 1.43), (-.07, .03, .4)], [.13, .085, .006], 'skin', 8)
        for i in range(6):
            art.box(f'Gate vertical bladder suture {i}', (0, -.36, 2.41 + i * .19), (.19, .075, .085), 'bone', .015)
        art.egg('Gate organ anterior amber aperture', (.21, -.36, 2.95), (.055, .025, .21), 'amber', 8, 4)
    with assembly('Gate threshold drains and regulator brackets'):
        for side in (-1, 1):
            art.box(f'Gate low lateral drain {side}', (side * 1.29, .37, .07), (1.17, .65, .14), 'steel', .015)
            dial(f'Gate pier separation regulator {side}', (side * 2.22, -.44, 1.0), .22)


def pressure_screen():
    with assembly('Pressure screen pointed load frame and machined arch relief'):
        art.box('Screen filtration foot', (0, .06, .14), (4.5, 1.8, .28), 'iron', .045)
        for side in (-1, 1):
            for depth, mat, radius in [(-.27, 'bone', .13), (.25, 'steel', .13), (-.45, 'scar', .028)]:
                bend(f'Screen carved pointed arch {side} {depth}', [(side * 1.99, depth, .3),
                     (side * 2.24, depth, 5.61), (side * 1.63, depth, 6.55), (0, depth, 7.43)], radius, mat, 8, 26)
            for i in range(10):
                art.box(f'Screen jamb incised copper block {side} {i}', (side * 2.07, -.36, .7 + i * .47),
                        (.23, .18, .075), 'steel', .012)
        art.tube('Screen lower ivory cross sill', [(-2.06, -.28, .41), (2.06, -.28, .41)], .12, 'bone', 8)
    with assembly('Open eightfold geometric filtration lattice'):
        for row in range(6):
            z = 1.05 + row * .97
            for col in range(-1, 2):
                if row == 5 and col:
                    continue
                x = col * 1.13
                # Two interpenetrating square circuits produce true eight-point apertures.
                for turn in (0, math.pi / 4):
                    points = [(x + .57 * math.cos(turn + j * math.pi / 2), -.19,
                               z + .57 * math.sin(turn + j * math.pi / 2)) for j in range(5)]
                    art.tube(f'Eightfold aperture square {row} {col} {turn:.2f}', points, .047, 'bone', 6)
                art.egg(f'Lattice machined intersection rivet {row} {col}', (x, -.255, z), (.057, .035, .057), 'steel', 8, 4)
                if row < 5 and not (row == 4 and col):
                    art.tube(f'Screen lattice vertical link {row} {col}', [(x, -.19, z + .56),
                             (x, -.19, z + .97 - .56)], .035, 'bone', 6)
                if col < 1 and row < 5:
                    art.tube(f'Screen lattice transverse link {row} {col}', [(x + .55, -.19, z),
                             (x + 1.13 - .55, -.19, z)], .035, 'bone', 6)
        for side in (-1, 1):
            bend(f'Screen crown branching pattern {side}', [(side * 1.52, -.19, 5.55),
                 (side * 1.37, -.19, 6.2), (side * .63, -.19, 6.91), (0, -.19, 7.27)], .042, 'bone', 6, 12)
    with assembly('Rear pressure wound and flanking return valves'):
        shell('Screen rear split vascular column', [(.34, .47), (.42, 5.78), (.29, 6.56), (.18, 6.56),
              (.29, 5.78), (.22, .47)], 'skin', center=(0, .55, 0), arc=(0, math.pi), steps=16)
        for side in (-1, 1):
            bend(f'Screen posterior copper circulation bypass {side}', [(side * 1.94, .56, .3),
                 (side * 2.53, .69, 3.6), (side * 1.77, .56, 6.5), (side * .19, .56, 6.29)], .092, 'steel', 8, 22)
            for i in range(5):
                art.tube(f'Screen exposed vascular branch {side} {i}', [(side * .29, .54, .93 + i * .83),
                         (side * 1.18, .48, 1.14 + i * .83), (side * 1.55, .41, .95 + i * .83)], [.06, .033, .008], 'scar', 6)
    with assembly('Screen low filter collectors and amber instrumentation'):
        for side in (-1, 1):
            art.box(f'Screen lateral filter collector {side}', (side * 1.69, .12, .60), (.57, .74, .66), 'iron', .025)
            dial(f'Screen filter pressure regulator {side}', (side * 1.69, -.29, .68), .20)
            art.egg(f'Screen amber filter index {side}', (side * 1.94, -.34, .52), (.05, .025, .10), 'amber', 8, 4)


def ascending_engine():
    with assembly('Ascending engine low terrace and receiving stair'):
        art.box('Ascending engine square low foundation', (0, .2, .14), (4.6, 3.5, .28), 'iron', .055)
        for i in range(5):
            art.box(f'Ascending engine visual receiving tread {i}', (0, -1.55 - i * .20, .08 + (4 - i) * .065),
                    (1.85, .43, .16 + (4 - i) * .13), 'bone', .018)
        for side in (-1, 1):
            bend(f'Engine lateral tier-feed copper artery {side}', [(side * 2.07, .91, .29),
                 (side * 2.6, 1.48, 3.1), (side * 1.51, 1.04, 5.8), (side * .3, .19, 7.37)], .11, 'steel', 8, 24)
    with assembly('Five open diminishing shrine-machine terraces'):
        for tier in range(5):
            r, z = 1.83 - tier * .28, .65 + tier * 1.27
            art.box(f'Engine carved stepped cornice {tier}', (0, .18, z), (r * 2 + .34, r * 1.43 + .3, .20), 'bone', .025)
            art.box(f'Engine copper under-cornice incision {tier}', (0, .18, z - .13), (r * 2 + .14, r * 1.43 + .16, .05), 'steel')
            for side in (-1, 1):
                for back in (-1, 1):
                    x, y = side * r * .78, .18 + back * r * .53
                    art.tube(f'Engine terrace fluted corner pillar {tier} {side} {back}',
                             [(x, y, z + .09), (x * .91, y * .91, z + 1.01)], [.10, .072], 'bone', 8)
                    # A square-based tapering crown blade has actual sidewall thickness.
                    verts = [(x - .13, y - .13, z + 1.02), (x + .13, y - .13, z + 1.02),
                             (x + .13, y + .13, z + 1.02), (x - .13, y + .13, z + 1.02), (x, y, z + 1.40)]
                    art.mesh(f'Engine terrace carved crown blade {tier} {side} {back}', verts,
                             [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], 'bone')
                bend(f'Engine open anterior niche arch {tier} {side}', [(side * r * .78, -r * .53 + .17, z + .2),
                     (side * r * .70, -r * .53 + .14, z + .94), (side * r * .3, -r * .53 + .12, z + 1.14),
                     (0, -r * .53 + .12, z + 1.17)], .055, 'bone', 6, 12)
            for i in range(7):
                art.box(f'Engine front cornice carved dentil {tier} {i}', ((i - 3) * r / 4,
                        -r * .715, z - .035), (.12, .08, .10), 'bone', .01)
    with assembly('Tiered human operator relief niches'):
        for tier in range(4):
            r, z = 1.83 - tier * .28, .65 + tier * 1.27
            for side in (-1, 1):
                witness(f'Engine tier operator {tier} {side}', side * r * .47, -r * .43, z + .57, .63 - tier * .05)
                art.box(f'Engine operator restraint back {tier} {side}', (side * r * .47, -r * .37, z + .46),
                        (.20, .075, .73), 'iron', .02)
    with assembly('Central ascending wound and tapered crown spindle'):
        shell('Engine visible ascending tissue column', [(.30, .32), (.34, 5.8), (.18, 6.91), (.09, 7.61),
              (.055, 7.61), (.08, 6.91), (.22, 5.8), (.20, .32)], 'skin', center=(0, .18, 0), steps=20)
        for i in range(17):
            z = .73 + i * .36
            art.box(f'Engine central vertebral ascension lock {i}', (0, -.22, z), (.27, .14, .11), 'bone', .014)
            art.egg(f'Engine central amber witness slit {i}', (.08, -.30, z + .04), (.027, .021, .046), 'amber', 8, 4)
        art.ring('Engine upper carved spindle collar', (0, .18, 6.96), .30, .065, 'steel', segments=16)
        art.tube('Engine tapered terminal flame gland', [(0, .18, 7.0), (.1, .14, 7.47), (0, .18, 7.85)], [.15, .095, .001], 'bone', 8)
        dial('Engine front ascending regulator', (0, -1.34, .78), .22)


def seven_lamps():
    with assembly('Lamp distribution roots and split footing'):
        art.box('Seven lamps low distribution plinth', (0, .17, .13), (4.8, 2.8, .26), 'iron', .06)
        for side in (-1, 1):
            for i in range(4):
                y = -.78 + i * .52
                bend(f'Lamp ossified root buttress {side} {i}', [(side * 1.91, y, .27),
                     (side * 1.4, y, .59), (side * .45, .12, 1.25), (side * .16, .12, 2.0)], (.15, .08), 'bone', 8, 12)
            bend(f'Lamp copper ground-fed distribution main {side}', [(side * 2.15, .7, .27),
                 (side * 2.52, .94, 1.84), (side * .51, .59, 2.45), (side * .16, .27, 3.62)], .13, 'steel', 8, 18)
        art.tube('Lamp central fluted ivory trunk', [(0, .14, .34), (0, .14, 6.52)], [.24, .14], 'bone', 10)
        for i in range(9):
            art.ring(f'Lamp trunk copper articulation {i}', (0, .14, .72 + i * .53), .22, .045, 'steel', segments=12)
    with assembly('Three paired branch circuits and central observation vessel'):
        for pair in range(3):
            x, start, top = 1.04 + pair * .89, 4.03 - pair * .68, 6.6 - pair * .15
            for side in (-1, 1):
                bend(f'Lamp paired bone distribution branch {pair} {side}', [(side * .12, .14, start),
                     (side * x * .92, -.01, start + .15), (side * x, .10, top - 1.15),
                     (side * x, .10, top)], (.15, .095), 'bone', 8, 20)
                bend(f'Lamp exposed copper branch feed {pair} {side}', [(side * .22, .32, start - .10),
                     (side * x * .93, .31, start + .10), (side * (x + .17), .31, top - 1.19),
                     (side * (x + .17), .26, top)], .053, 'steel', 6, 16)
                art.egg(f'Lamp fork cartilage joint {pair} {side}', (side * .2, .12, start), (.20, .17, .19), 'scar', 12, 6)
        positions = [(0, 6.65)] + [(side * (1.04 + pair * .89), 6.6 - pair * .15)
                                  for pair in range(3) for side in (-1, 1)]
        for i, (x, z) in enumerate(positions):
            shell(f'Lamp hollow observation vessel {i}', [(.25, z), (.37, z + .13), (.38, z + .78), (.25, z + .94),
                  (.18, z + .94), (.29, z + .75), (.29, z + .20), (.19, z + .12), (.25, z)],
                  'skin', center=(x, .1, 0), steps=16)
            for h in (.08, .85):
                art.ring(f'Lamp copper vessel rim {i} {h}', (x, .1, z + h), .36, .055, 'steel', segments=16)
            for rib in range(6):
                a = rib * math.tau / 6
                art.tube(f'Lamp open vessel restraint cage {i} {rib}', [(x + .32 * math.cos(a), .1 + .32 * math.sin(a), z + .13),
                         (x + .43 * math.cos(a), .1 + .43 * math.sin(a), z + .5),
                         (x + .28 * math.cos(a), .1 + .28 * math.sin(a), z + .90)], .034, 'steel', 6)
            art.tube(f'Lamp amber observation wick {i}', [(x, .1, z + .12), (x, .1, z + .93)], .064, 'amber', 8)
            art.tube(f'Lamp bent amber flame {i}', [(x, .1, z + .93), (x - .06, .1, z + 1.18),
                     (x + .05, .1, z + 1.48)], [.115, .07, .001], 'amber', 8)
    with assembly('Interwoven observation tendons'):
        for side in (-1, 1):
            for i in range(3):
                bend(f'Lamp interwoven living tendon {side} {i}', [(side * .1, -.17, .63),
                     (-side * (.45 + i * .15), -.23, 1.45), (side * (.53 + i * .17), -.22, 2.73),
                     (side * .08, -.18, 3.97 + i * .40)], (.07, .025), 'scar', 6, 18)
    with assembly('Seven-lamp supply regulators'):
        for side in (-1, 1):
            dial(f'Lamp distribution regulator {side}', (side * 1.69, -.99, .68), .23)
        art.box('Lamp central observation aperture', (0, -.24, 3.87), (.09, .05, .35), 'amber', .01)


def solar_seal():
    with assembly('Paired tapered obelisks and carved fictional conduit marks'):
        art.box('Solar seal stepped containment foundation', (0, .14, .14), (6.7, 2.95, .28), 'iron', .05)
        for side in (-1, 1):
            x = side * 2.42
            art.box(f'Solar obelisk raised plinth {side}', (x, .19, .45), (1.19, 1.21, .34), 'bone', .045)
            verts = []
            for z, r in [(.62, .46), (7.02, .27)]:
                verts.extend([(x - r, .17 - r, z), (x + r, .17 - r, z),
                              (x + r, .17 + r, z), (x - r, .17 + r, z)])
            verts.append((x, .17, 7.81))
            art.mesh(f'Solar tapered solid obelisk {side}', verts,
                     [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
                      (4, 5, 8), (5, 6, 8), (6, 7, 8), (7, 4, 8)], 'bone')
            for i in range(16):
                z = 1.08 + i * .345
                y = -.29 + (z - .62) * .19 / 6.4
                # Fictional conduit cuts, not text or purported historical hieroglyphs.
                art.tube(f'Obelisk carved fork incision {side} {i}', [(x - .11, y - .014, z + .10),
                         (x, y - .026, z), (x + .09, y - .014, z + .07)], .016, 'black', 5)
                art.box(f'Obelisk copper incision clamp {side} {i}', (x + .14, y - .03, z), (.035, .03, .12), 'steel')
            bend(f'Solar obelisk dorsal containment pipe {side}', [(side * 2.88, .61, .3),
                 (side * 3.25, .74, 3.3), (side * 2.6, .67, 5.6), (side * 2.42, .18, 7.17)], .10, 'steel', 8, 24)
    with assembly('Radial solar shutter and bound red containment core'):
        for r, thick, mat in [(1.87, .09, 'steel'), (1.17, .06, 'bone'), (.96, .09, 'steel')]:
            art.ring(f'Solar seal open shutter bearing {r}', (0, .11, 4.78), r, thick, mat, 'XZ', 40)
        art.egg('Solar bound red containment core', (0, .11, 4.78), (.90, .35, .90), 'skin', 24, 12)
        for i in range(24):
            a = i * math.tau / 24
            c, s = math.cos(a), math.sin(a)
            length = 2.07 if i % 2 else 2.31
            art.tube(f'Solar radial articulated shutter ray {i}', [(1.01 * c, .11, 4.78 + 1.01 * s),
                     (1.60 * c, .11, 4.78 + 1.60 * s), (length * c, .11, 4.78 + length * s)], [.056, .038, .013], 'steel', 6)
            art.egg(f'Solar ray ivory pivot {i}', (1.6 * c, .03, 4.78 + 1.6 * s), (.078, .068, .078), 'bone', 8, 4)
        for side in (-1, 1):
            bend(f'Solar anterior core restraint {side}', [(side * .10, -.17, 5.68),
                 (side * .73, -.49, 5.35), (side * .73, -.49, 4.22), (side * .10, -.17, 3.88)], .048, 'iron', 8, 16)
        art.tube('Solar bound descending wound', [(0, .12, 3.91), (.15, .16, 2.81),
                 (-.10, .18, 1.40), (0, .1, .33)], [.15, .12, .08, .012], 'skin', 8)
    with assembly('Mummiform operator niches and split crown plates'):
        for side in (-1, 1):
            x = side * 2.42
            witness(f'Solar restrained operator {side}', x, -.47, 1.78, .99)
            for rib in range(7):
                y = -.30 + rib * .085
                art.tube(f'Solar operator pleated crown rib {side} {rib}', [(x - .30, y, 1.78),
                         (x - .37, y, 2.43), (x, y, 2.76), (x + .37, y, 2.43), (x + .30, y, 1.78)], .028, 'steel', 6)
            art.tube(f'Solar operator bound leg relief {side}', [(x - .13, -.43, 1.36),
                     (x, -.44, .85), (x + .13, -.43, 1.36)], .055, 'bone', 6)
    with assembly('Seal amber containment feeds and low regulator'):
        for side in (-1, 1):
            art.tube(f'Solar amber binding ligament {side}', [(side * .13, -.34, 5.55),
                     (side * .14, -.34, 4.81), (side * .12, -.34, 4.01)], .026, 'amber', 6)
            dial(f'Solar containment regulator {side}', (side * 1.36, -.95, .65), .22)
        art.egg('Solar red sump gland', (0, .1, .39), (.38, .37, .085), 'scar', 16, 6)


def setup():
    scene = original_setup()
    foundry.skin_texture()
    # Keep the shared seven-material cap; locally tune steel to reference copper.
    color = art.rgba('#805139')
    art.M['steel'].diffuse_color = color
    art.M['steel'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = color
    return scene


def build_scene(name):
    globals()[name.removeprefix('intake_')]()
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices),
               'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert triangles <= 30000, (name, triangles)
    assert abs(extent['min'][2]) <= .001 and all(v <= cap for v, cap in zip(extent['size'], CAPS)), (name, extent)
    collections = [c.name for c in bpy.context.scene.collection.children if c.objects]
    assert len(collections) >= 4, (name, collections)
    STATS[name] = {'source_mesh_count': len(meshes), 'triangles': triangles, 'physical_bounds_m': extent,
                   'source_hierarchy_groups': len(collections), 'assembly_names': collections, 'source_meshes': counts}
    scene = bpy.context.scene
    scene['asset_id'], scene['authoring_recipe'] = name, 'tools/build_religious_art.py'
    scene['recipe_sha256'] = art.sha(Path(__file__))
    scene['reference_images'] = json.dumps(REFERENCES, sort_keys=True)


def main():
    global bpy, art, foundry, bend, shell, dial, original_setup
    opts = arguments(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    project = Path(__file__).resolve().parents[1]
    output, receipt = candidate_roots(opts.output_root, opts.receipt_root, project)
    destinations = [output / 'source/art' / (opts.asset + '.blend'),
                    output / 'game/assets/art/world' / (opts.asset + '.glb'),
                    output / 'previews' / (opts.asset + '_preview.png'),
                    output / 'previews/frames' / (opts.asset + '_hero.png'),
                    receipt / (opts.asset + '_candidate.json')]
    if any(p.exists() or p.is_symlink() for p in destinations):
        raise FileExistsError('Candidate already exists; choose a fresh batch root, never overwrite it')
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import bpy
    import build_art as art
    import build_foundry_art as foundry
    bend, shell, dial = foundry.bend, foundry.shell, foundry.dial
    manifest_data = (project / 'source/art/manifest.json').read_bytes()
    manifest = json.loads(manifest_data)
    dependencies = {str(Path(m.__file__).relative_to(project)): art.sha(Path(m.__file__)) for m in (art, foundry)}
    assert dependencies['tools/build_art.py'] == manifest['build']['script_sha256'], 'Intake helper drift; do not build'
    assert all(a['recipe_sha256'] == dependencies['tools/build_foundry_art.py'] for a in manifest['assets']
               if a['id'] in foundry.IDS), 'Foundry helper drift; do not build'
    assert all(art.sha(project / path) == digest for path, digest in REFERENCES.items()), 'Reference image drift'
    atlas = project / 'game/assets/art/textures/surface_atlas.png'
    atlas_record = next(o for a in manifest['assets'] for o in a['outputs']
                        if o['path'] == 'game/assets/art/textures/surface_atlas.png')
    assert art.sha(atlas) == atlas_record['sha256'], 'Shared atlas drift'
    original_setup = art.setup
    art.ROOT, art.ART, art.OUT, art.SCRATCH = output, output / 'source/art', output / 'game/assets/art', output / 'previews'
    art.setup, art.scenery = setup, build_scene
    atlas_copy = art.target(art.OUT / 'textures/surface_atlas.png')
    if atlas_copy.exists():
        assert art.sha(atlas_copy) == atlas_record['sha256'], 'Candidate atlas drift'
    else:
        shutil.copyfile(atlas, atlas_copy)
    print('ART_START ' + opts.asset, flush=True)
    entry = art.world_export(opts.asset)
    entry.update({key: STATS[opts.asset][key] for key in ('source_mesh_count', 'source_hierarchy_groups', 'assembly_names')})
    entry.update(recipe_sha256=art.sha(Path(__file__)), recipe_dependencies=dependencies,
                 reference_images=[{'path': p, 'sha256': h} for p, h in REFERENCES.items()],
                 tradition_aesthetic=TRADITIONS[opts.asset], level_id='intake',
                 texture_dependencies={atlas_record['path']: atlas_record['sha256']},
                 facing='front Blender -Y; exported Godot +Z', collision='none; parent authors explicit low bases/solid cover')
    entry['provenance']['authoring_script'] = 'tools/build_religious_art.py'
    entry['provenance']['fiction'] = 'Fictional controller manipulating worship systems; no historical claims or real-person villain attribution'
    assert entry['runtime_mesh_nodes'] <= 7 and entry['triangles'] == STATS[opts.asset]['triangles']
    assert sum(p.stat().st_size for p in (art.OUT / 'world').glob('intake_*.glb')) < 8 * 1024 * 1024, 'Seven-piece GLB budget'
    # Candidate records are parent-review receipts, never a second runtime manifest.
    payload = {**STATS[opts.asset], 'asset': entry, 'output_root': str(output), 'blender_version': bpy.app.version_string,
               'preview': str(art.SCRATCH / (opts.asset + '_preview.png')), 'status': 'native_candidate_not_integrated',
               'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest()}
    receipt.mkdir(parents=True, exist_ok=True)
    destinations[-1].write_text(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
