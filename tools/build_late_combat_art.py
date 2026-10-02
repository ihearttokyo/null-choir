"""Image-derived late combat sources; parent owns all native render jobs.

blender -b -t 4 --python-exit-code 1 --python tools/build_late_combat_art.py --
  --asset ID --output-root FRESH/native --receipt-root FRESH
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_religious_art import candidate_roots

ROOT = Path(__file__).resolve().parents[1]
WEAPONS = ('sawtooth_repeater', 'marrow_launcher', 'choir_disruptor')
ROLES = ('brute', 'guardian', 'summoner')
BOSSES = ('nursery_warden', 'choir_avatar')
IDS = WEAPONS + ROLES + BOSSES
DEPENDENCIES = ('tools/build_art.py', 'tools/build_foundry_art.py',
                'tools/build_processional_art.py', 'tools/build_religious_art.py')
REFERENCES = {
    'weapons-late-01.png': '0295d8a6252ff8176afc17e9818110eb920dc66f08ef5b9593eb9df3df318657',
    'roles-late-01.png': '8d7ae8dea6e781186fa2377ebeb4e24be5de66c5c049c675bd43fd94fdc8b481',
    'boss-nursery-01.png': '2449a8239ff4a6d63e3291c48c284f92985eb6b06c8b046d017a47d2c3eb3cc2',
    'boss-heart-01.png': '938a2bdcc2374b07cb1a907d6762d1a755734010f453fee7afd8a57f2d443c1e',
}
SPECS = {name: {'cell': 320, 'triangle_budget': 18000, 'byte_budget': 256 * 1024} for name in WEAPONS}
SPECS.update({name: {'cell': 128, 'triangle_budget': 16000, 'byte_budget': 512 * 1024,
                    'scale': scale, 'aim': aim} for name, scale, aim in
              (('brute', 4.4, 1.7), ('guardian', 4.7, 1.65), ('summoner', 5.6, 2.15))})
SPECS.update({name: {'cell': 256, 'triangle_budget': 24000, 'byte_budget': 2 * 1024 * 1024,
                    'scale': scale, 'aim': aim} for name, scale, aim in
              (('nursery_warden', 7.3, 2.8), ('choir_avatar', 7.6, 2.8))})


def reference(asset):
    filename = ('weapons-late-01.png' if asset in WEAPONS else 'roles-late-01.png' if asset in ROLES
                else 'boss-nursery-01.png' if asset == 'nursery_warden' else 'boss-heart-01.png')
    return {'path': 'source/art/references/' + filename, 'sha256': REFERENCES[filename]}


def preflight(asset, output_root, receipt_root, project_root):
    if asset not in IDS:
        raise ValueError('Select one exact late-combat asset ID')
    for root in (Path(output_root).absolute(), Path(receipt_root).absolute()):
        if any(p.is_symlink() for p in (root, *root.parents)):
            raise ValueError('Candidate roots must be real directories')
    output, receipt = candidate_roots(output_root, receipt_root, project_root)
    folders = ('source/art', 'game/assets/art/weapons', 'game/assets/art/sprites', 'previews/frames')
    for folder in folders:
        if any(p.is_symlink() for p in (output / folder, *(output / folder).parents) if p.is_relative_to(output)):
            raise ValueError('Candidate subdirectories must not be symlinks')
    folder = 'weapons' if asset in WEAPONS else 'sprites'
    targets = [output / 'source/art' / (asset + '.blend'),
               output / 'game/assets/art' / folder / (asset + '.png'),
               output / 'previews' / (asset + '_contact.png'), receipt / (asset + '_candidate.json')]
    frames = [f'{asset}_{pose}' for pose in ('idle', 'fire', 'recover')] if asset in WEAPONS else [
        f'{asset}_{row}_{column}' for row in range(5) for column in range(8)]
    targets.extend(output / 'previews/frames' / (frame + '.png') for frame in frames)
    if any(p.exists() or p.is_symlink() for p in targets):
        raise FileExistsError('Combat candidate exists; choose fresh roots')
    return output, receipt


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--receipt-root', type=Path, required=True)
    return parser.parse_args(argv)


# Repeated anatomical parts use existing geometry, never an alternate renderer.
def hollow(name, pos, length, radius, wall=.045, mat='bone', flare=1, front=False, aspect=(1, 1)):
    obj = shell(name, [(radius, 0), (radius * flare, length), (radius * flare - wall, length),
                       (radius - wall, 0), (radius, 0)], mat, aspect=aspect, steps=16)
    obj.rotation_euler.x = math.pi / 2 if front else -math.pi / 2
    obj.location = pos
    return obj


def tendon(name, points, width=.04):
    return bend(name, points, (width, width * .45), 'skin', 6, 8)


def piston(name, start, end, radius=.13):
    a, b = Vector(start), Vector(end)
    middle = a.lerp(b, .58)
    art.tube(name + ' bronze cylinder', [a, middle], radius, 'bronze', 8)
    art.tube(name + ' exposed steel rod', [middle, b], radius * .53, 'steel', 8)
    art.joint(name + ' articulation', end, radius * 1.1)


def cage(name, center, scale, mat='bone'):
    x, y, z = center
    rx, ry, rz = scale
    for i in range(6):
        angle = math.tau * i / 6
        c, s = math.cos(angle), math.sin(angle)
        bend(name + f' open stave {i}', [(x, y, z - rz), (x + rx * c, y + ry * s, z - rz * .8),
             (x + rx * c, y + ry * s, z + rz * .8), (x, y, z + rz)], .05, mat, 6, 8)
    for dz in (-rz * .53, rz * .53):
        ring = art.ring(name + f' restraint {dz}', (x, y, z + dz), rx * .83, .04, 'bronze', segments=12)
        ring.scale.y = ry / rx


def hand(name, wrist, spread=.16, biological=True):
    x, y, z = wrist
    art.egg(name + ' palm', wrist, (.18, .17, .11), 'skin' if biological else 'black', 10, 6)
    for i in range(4):
        p = (x + (i - 1.5) * .072, y, z + .03)
        bend(name + f' hooked digit {i}', [p, (p[0] + spread * (i - 1.5), y + .21, z + .06),
             (p[0] + spread * (i - 1.5), y + .32, z - .12), (p[0], y + .15, z - .16)],
             (.035, .012), 'scar' if biological else 'bone', 5, 7)
        art.egg(name + f' knuckle {i}', p, (.045, .054, .045), 'bronze', 8, 4)
    bend(name + ' inward thumb', [(x + .17, y - .08, z), (x + .31, y + .11, z),
         (x + .19, y + .25, z - .1), (x + .09, y + .17, z - .11)], (.05, .022), 'bone', 5, 7)


def weapon_hands(pose, biological=True, wide=.52):
    for side in (-1, 1):
        before = set(bpy.context.scene.objects)
        art.technician_hand(side, pose, biological)
        if not biological:
            for obj in bpy.context.scene.objects:
                if obj not in before and 'worn glove' in obj.name:
                    obj.data.materials.clear()
                    obj.data.materials.append(art.M['black'])
        for i in range(3):
            tendon(f'{side} wrist-to-receiver tendon {i}', [(side * .6, -1.36, .30 + .07 * i),
                   (side * .7, -1.05, .42), (side * wide, -.70, .45),
                   (side * wide * .78, -.35, .42 + .04 * i)], .035)


def gear(name, center, radius, teeth=12):
    x, y, z = center
    art.ring(name + ' open race', center, radius * .7, .045, 'bronze', 'YZ', 16)
    for i in range(teeth):
        a = math.tau * i / teeth
        tooth = art.box(name + f' tooth {i}', (x, y + radius * math.cos(a), z + radius * math.sin(a)),
                        (.10, .10, .085), 'bronze', .009)
        tooth.rotation_euler.x = a
        art.tube(name + f' radial spoke {i}', [(x, y, z), (x, y + radius * .67 * math.cos(a),
                 z + radius * .67 * math.sin(a))], .017, 'steel', 5)


def sawtooth_repeater(pose):
    with assembly('Hooked gloved hands and feed tendons'):
        weapon_hands(pose, False, .39)
    with assembly('Narrow offset bored muzzle and slotted ivory spine'):
        art.box('Repeater narrow steel receiver', (.12, -.20, .47), (.45, 1.07, .31), 'black', .025)
        art.box('Repeater worn surgical top rail', (.12, -.11, .67), (.27, .85, .07), 'bone', .014)
        hollow('Repeater asymmetric hollow nail muzzle', (.13, .04, .50), 1.23, .075, .025, 'steel')
        for i in range(8):
            art.ring(f'Repeater ivory muzzle restraint {i}', (.13, .17 + i * .135, .50), .095, .026, 'bone', 'XZ', 10)
            art.box(f'Repeater open spine slot pier {i}', (-.075, -.42 + i * .11, .56), (.045, .045, .20), 'bone', .006)
        art.box('Repeater left open rib foot rail', (-.075, -.04, .46), (.05, .85, .038), 'bronze')
        art.box('Repeater rear hooked grip', (.30, -.72, .30), (.20, .26, .33), 'black', .025)
        art.ring('Repeater finger guard', (.27, -.58, .27), .14, .025, 'bronze', 'YZ', 12)
    with assembly('Toothed feed wheel and exposed separate nail track'):
        gear('Repeater toothed right feed wheel', (.48, -.20, .40), .23)
        for i in range(7):
            y = -.49 + i * .10
            art.tube(f'Repeater visible feed nail {i}', [(.36, y, .63), (.61, y, .63)], [.035, .007], 'steel', 6)
            art.egg(f'Repeater nail rim {i}', (.37, y, .63), (.020, .047, .047), 'bronze', 8, 4)
        art.box('Repeater separate track support', (.45, -.18, .54), (.19, .79, .04), 'black')
        if pose == 'fire':
            art.tube('Repeater actually ejected nail', [(.66, -.32, .76), (.97, -.13, .84)], [.028, .008], 'steel', 6)
    with assembly('Translating pushrod and asymmetric muzzle discharge'):
        stroke = .17 if pose == 'fire' else .08 if pose == 'recover' else 0
        piston('Repeater sliding action rod', (-.15, -.48 + stroke, .42), (-.15, .58 + stroke, .42), .055)
        art.box('Repeater separate moving bolt', (.12, -.35 + stroke, .58), (.19, .18, .08), 'bronze', .01)
        tendon('Repeater exposed lower feed return', [(-.2, -.72, .28), (-.35, -.48, .34),
               (-.26, .25, .31), (.12, .50, .36)], .038)
        if pose == 'fire':
            art.tube('Repeater narrow nail discharge', [(.13, 1.28, .50), (.12, 1.48, .51),
                     (.18, 1.63, .49)], [.056, .032, .001], 'amber', 6)
        art.egg('Repeater rear pressure index', (-.08, -.54, .69), (.04, .05, .018), 'amber', 8, 4)


def marrow_launcher(pose):
    with assembly('Biological gripping hands and marrow feed tendons'):
        weapon_hands(pose, True, .61)
        for side in (-1, 1):
            for i in range(4):
                art.tube(f'Launcher exposed wrist bone {side} {i}', [(side * .42, -1.33 + i * .1, .38),
                         (side * .62, -1.34 + i * .1, .51), (side * .69, -1.27 + i * .1, .36)],
                         [.025, .036, .018], 'bone', 6)
    with assembly('Genuinely hollow thick split-jaw muzzle'):
        art.box('Launcher broad recoil receiver', (0, -.29, .43), (.93, .73, .29), 'black', .03)
        gape = .04 if pose == 'fire' else .015 if pose == 'recover' else 0
        for side in (-1, 1):
            arc = (-math.pi * .46, math.pi * .46) if side == 1 else (math.pi * .54, math.pi * 1.46)
            jaw = shell(f'Launcher {side} hollow jaw leaf', [(.30, 0), (.38, .84), (.29, .84),
                        (.22, 0), (.30, 0)], 'bone', aspect=(1.13, .88), arc=arc, steps=14)
            jaw.rotation_euler.x = -math.pi / 2
            jaw.location = (side * gape, .21, .53)
            for i in range(5):
                y = .32 + i * .145
                art.tube(f'Launcher articulated jaw tooth {side} {i}', [(side * (.29 + gape), y, .32),
                         (side * (.18 + gape), y + .025, .38)], [.045, .005], 'bone', 6)
            piston(f'Launcher jaw hinge actuator {side}', (side * .46, -.11, .48),
                   (side * (.34 + gape), .72, .50), .062)
        hollow('Launcher inner black pressure throat', (0, -.03, .53), .69, .22, .045, 'black')
    with assembly('Marrow capsule breech and unequal pressure bladder'):
        art.egg('Launcher nonhuman marrow capsule', (0, -.10, .55), (.23, .40, .23), 'skin', 12, 6)
        for y in (-.35, .16):
            art.ring('Launcher capsule pressure restraint', (0, y, .55), .235, .036, 'bronze', 'XZ', 12)
        art.egg('Launcher exposed right pressure bladder', (.47, -.24, .34), (.19, .42, .17), 'skin', 12, 6)
        for i in range(4):
            tendon(f'Launcher bladder vascular groove {i}', [(.47 + i * .035, -.60, .33),
                   (.68, -.31, .48), (.64, .04, .49), (.38, .16, .34)], .022)
        for i in range(3):
            art.ring(f'Launcher bladder bronze cinch {i}', (.47, -.48 + i * .21, .34), .19, .028, 'bronze', 'XZ', 12)
        art.box('Launcher rear bone breech roof', (0, -.38, .73), (.68, .40, .065), 'bone', .015)
        art.ring('Launcher capsule inspection window', (0, -.15, .76), .13, .027, 'bronze', 'XY', 12)
    with assembly('Heavy recoil sled and hot marrow discharge'):
        stroke = .21 if pose == 'fire' else .09 if pose == 'recover' else 0
        for side in (-1, 1):
            piston(f'Launcher recoil sled {side}', (side * .34, -.69 + stroke, .25),
                   (side * .34, .17 + stroke, .25), .073)
        art.box('Launcher visible sled bridge', (0, -.51 + stroke, .27), (.72, .13, .10), 'bronze', .015)
        art.ring('Launcher tendon trigger guard', (.4, -.63, .20), .14, .033, 'bone', 'YZ', 12)
        if pose == 'fire':
            art.egg('Launcher expelled marrow pressure plug', (0, 1.20, .55), (.15, .23, .15), 'skin', 12, 6)
            for side in (-1, 1):
                art.tube(f'Launcher bone-jaw pressure vent {side}', [(side * .22, 1.04, .53),
                         (side * .27, 1.31, .49), (side * .37, 1.46, .39)], [.055, .026, .001], 'amber', 6)


def choir_disruptor(pose):
    with assembly('Tendon-linked hands and branching ivory receiver'):
        weapon_hands(pose, True, .58)
        art.box('Disruptor narrow black choral receiver', (0, -.34, .43), (.47, .71, .24), 'black', .025)
        for side in (-1, 1):
            bend(f'Disruptor branching ivory wing {side}', [(side * .14, -.65, .42),
                 (side * .57, -.37, .42), (side * .50, .42, .57), (side * .27, .86, .57)],
                 (.080, .052), 'bone', 6, 9)
            tendon(f'Disruptor palm to tuning bank {side}', [(side * .58, -.86, .37),
                   (side * .69, -.44, .57), (side * .62, .25, .52), (side * .30, .55, .62)], .041)
    with assembly('Three independent hollow pressure resonators'):
        for i, x in enumerate((-.27, 0, .27)):
            z = .69 if i == 1 else .53
            length = 1.25 if i == 1 else 1.04
            hollow(f'Disruptor real hollow resonator {i}', (x, -.11, z), length, .105, .030, 'bone', 1.30)
            for j in range(4):
                art.ring(f'Disruptor independent resonator copper band {i} {j}', (x, .06 + j * .23, z),
                         .12, .025, 'bronze', 'XZ', 12)
            art.egg(f'Disruptor contained choral cell {i}', (x, .15, z), (.063, .15, .063),
                    'violet' if i == 1 else 'amber', 10, 6)
            for side in (-1, 1):
                art.tube(f'Disruptor chamber support filament {i} {side}', [(x + side * .08, -.07, z),
                         (x + side * .08, .84, z)], .015, 'steel', 5)
    with assembly('Articulating open tuning forks'):
        opened = .13 if pose == 'fire' else .065 if pose == 'recover' else 0
        for side in (-1, 1):
            for i in range(2):
                x = side * (.39 + .11 * i + opened)
                bend(f'Disruptor separate tuning tine {side} {i}', [(side * .30, -.21, .43),
                     (x, .31, .64), (x, .84, .93 - .10 * i), (side * (.27 + opened), 1.14, .81)],
                     (.055, .031), 'bronze', 6, 10)
                art.egg(f'Disruptor tuning knuckle {side} {i}', (x, .47, .77 - .08 * i),
                        (.075, .08, .075), 'bone', 8, 4)
            piston(f'Disruptor fork pivot {side}', (side * .24, -.46, .50),
                   (side * (.39 + opened), .22, .60), .046)
    with assembly('Contained violet pulse and rear regulation'):
        art.ring('Disruptor rear regulator', (0, -.45, .62), .115, .031, 'bronze', 'XZ', 12)
        for i in range(5):
            art.box(f'Disruptor receiver bone vertebra {i}', (0, -.58 + i * .10, .60), (.22, .046, .048), 'bone', .007)
        if pose == 'fire':
            for i, x in enumerate((-.27, 0, .27)):
                z = .69 if i == 1 else .53
                length = 1.30 if i == 1 else 1.09
                art.tube(f'Disruptor finite violet resonator pulse {i}', [(x, length, z),
                         (x, length + .19, z + .035), (x, length + .30, z)], [.055, .034, .001], 'violet', 6)
            tendon('Disruptor visible taut recoil nerve', [(-.33, -.61, .26), (-.12, -.47, .17),
                   (.19, -.36, .18), (.33, -.14, .38)], .030)


def articulated_leg(name, hip, knee, ankle, foot, width=.14):
    art.tube(name + ' upper ivory strut', [hip, knee], [width, width * .72], 'bone', 8)
    art.tube(name + ' lower ivory strut', [knee, ankle], [width * .72, width * .47], 'bone', 8)
    art.joint(name + ' knee', knee, width * 1.1)
    art.joint(name + ' ankle', ankle, width * .7)
    offset = Vector((width * .8, .10, 0))
    tendon(name + ' exposed weight tendon', [Vector(hip) + offset, Vector(knee) + offset * 1.7,
           Vector(ankle) + offset, Vector(foot) + offset * .4], width * .40)
    piston(name + ' leg recoil damper', Vector(hip) - offset, Vector(knee) - offset, width * .51)
    art.box(name + ' grounded bronze foot', (foot[0], foot[1], .09), (width * 2.9, .46, .18), 'bronze', .027)
    for i in range(3):
        art.tube(name + f' separate foot claw {i}', [(foot[0] + (i - 1) * width * .7, foot[1], .13),
                 (foot[0] + (i - 1) * width, foot[1] - .31, .04)], [width * .28, .018], 'bone', 6)


def slotted_mask(name, center, width=.32, height=.48):
    x, y, z = center
    for side in (-1, 1):
        bend(name + f' ram cheek {side}', [(x, y + .03, z + height), (x + side * width, y, z + height * .75),
             (x + side * width * .85, y - .09, z + height * .15), (x + side * .08, y - .10, z - height * .21)],
             (.075, .032), 'bone', 6, 8)
    for i in range(3):
        art.tube(name + f' negative-space grille bar {i}', [(x + (i - 1) * width * .31, y - .10, z + height * .75),
                 (x + (i - 1) * width * .18, y - .14, z - height * .10)], [.028, .016], 'bone', 6)
    art.egg(name + ' recessed black face', (x, y + .04, z + height * .36), (width * .73, .065, height * .72), 'black', 10, 6)


def brute(pose):
    phase = .18 if pose == 'walk_a' else -.18 if pose == 'walk_b' else .08 if pose == 'dead' else 0
    windup = pose == 'attack'
    crouch, lean = (.25, -.35) if windup else (0, 0)
    with assembly('Massive upright tendon legs and asymmetric charge brace'):
        for side in (-1, 1):
            step = phase * side
            articulated_leg(f'Brute planted leg {side}', (side * .42, .05, 1.53 - crouch),
                            (side * (.52 + (.13 if windup else 0)), -.10 + step, .80),
                            (side * .59, .12 - step, .23), (side * .61, -.04 - step, 0), .19)
            art.egg(f'Brute thigh tendon mass {side}', (side * .48, -.02 + step, 1.15 - crouch * .4),
                    (.25, .22, .43), 'skin', 10, 6)
    with assembly('Red load anatomy and ivory ram crown'):
        art.egg('Brute broad exposed muscle torso', (0, lean * .35, 2.17 - crouch), (.63, .43, .66), 'skin', 12, 6)
        art.egg('Brute asymmetric pelvis', (.06, .05, 1.51 - crouch), (.51, .34, .26), 'black', 12, 6)
        for side in (-1, 1):
            for i in range(4):
                bend(f'Brute carved load rib {side} {i}', [(0, .30, 2.55 - crouch - i * .19),
                     (side * .68, .19, 2.55 - crouch - i * .19),
                     (side * .66, -.40 + lean * .2, 2.38 - crouch - i * .18),
                     (side * .20, -.42 + lean * .2, 2.32 - crouch - i * .17)], .057, 'bone', 6, 8)
        slotted_mask('Brute lowered ram face' if windup else 'Brute ram face',
                     (0, -.44 + lean, 2.79 - crouch), .31, .46)
        for side in (-1, 1):
            bend(f'Brute swept ram horn {side}', [(side * .20, -.20 + lean, 3.14 - crouch),
                 (side * .50, .01 + lean, 3.56 - crouch), (side * .55, .31 + lean, 3.55 - crouch),
                 (side * .39, .36 + lean, 3.20 - crouch)], (.075, .019), 'bronze', 6, 10)
    with assembly('Asymmetric piston hammer and hooked counter arm'):
        for side in (-1, 1):
            shoulder = (side * .70, lean * .28, 2.56 - crouch)
            elbow = (side * .98, -.26 if windup else .03 + phase * side, 1.91 - crouch * .6)
            wrist = (side * 1.02, -.70 if windup else -.27 - phase * side, 1.23 if side == -1 else 1.55)
            art.egg(f'Brute shoulder muscle {side}', shoulder, (.30, .31, .29), 'skin', 10, 6)
            art.joint(f'Brute shoulder bearing {side}', shoulder, .25)
            piston(f'Brute exposed arm piston {side}', elbow, wrist, .22 if side == -1 else .13)
            art.tube(f'Brute upper shoulder strut {side}', [shoulder, elbow], [.20, .12], 'black', 8)
            if side == -1:
                art.box('Brute massive asymmetric ram forearm', wrist, (.50, .46, .65), 'bone', .06)
                for i in range(4):
                    art.tube(f'Brute hammer pressure flute {i}', [(wrist[0] + (i - 1.5) * .10, wrist[1] - .24, wrist[2] - .23),
                             (wrist[0] + (i - 1.5) * .10, wrist[1] - .24, wrist[2] + .24)], .028, 'bronze', 6)
            else:
                hand('Brute opposite open hooked claw', wrist, .12)
        art.box('Brute one broad shoulder ram wedge', (.78, .0, 2.75 - crouch), (.67, .58, .17), 'bone', .05)
    with assembly('Rear amber pressure vessels and unarmored nerves'):
        for side in (-1, 1):
            vessel = hollow(f'Brute dorsal pressure cylinder {side}', (side * .32, .40, 2.70 - crouch), .39, .16, .04, 'bronze')
            vessel.rotation_euler.x = 0
            art.egg(f'Brute cylinder amber index {side}', (side * .32, .48, 2.68 - crouch), (.08, .13, .15), 'amber', 10, 6)
            tendon(f'Brute exposed posterior artery {side}', [(side * .30, .48, 2.75 - crouch),
                   (side * .54, .52, 2.36 - crouch), (side * .49, .45, 1.65 - crouch),
                   (side * .26, .33, 1.46 - crouch)], .064)
        for i in range(6):
            art.box(f'Brute posterior spine clamp {i}', (0, .48, 1.62 - crouch + i * .19), (.23, .095, .085), 'bronze', .012)


def shield_leaf(name, center, width, height):
    x, y, z = center
    shape = [(-width / 2, -height / 2), (width / 2, -height / 2), (width / 2, height * .21),
             (width * .18, height * .40), (0, height / 2), (-width / 2, height * .19)]
    verts = [(x + px, y + dy, z + pz) for dy in (-.095, .095) for px, pz in shape]
    n = len(shape)
    art.mesh(name + ' thick lancet plate', verts, [tuple(reversed(range(n))), tuple(range(n, 2 * n))] +
             [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)], 'bone')
    for side in (-1, 1):
        bend(name + f' raised pointed spar {side}', [(x + side * width * .41, y - .12, z - height * .42),
             (x + side * width * .41, y - .12, z + height * .14),
             (x + side * width * .23, y - .12, z + height * .33), (x, y - .12, z + height * .43)],
             .030, 'bronze', 5, 8)
    for i in range(3):
        art.ring(name + f' raised ivory aperture {i}', (x, y - .12, z - .45 + i * .43), .14, .025, 'bronze', 'XZ', 10)


def guardian(pose):
    phase = .12 if pose == 'walk_a' else -.12 if pose == 'walk_b' else .045 if pose == 'dead' else 0
    opening = .58 if pose == 'attack' else 0
    with assembly('Low heavy split-shoe legs'):
        for side in (-1, 1):
            articulated_leg(f'Guardian heavy leg {side}', (side * .45, .13, 1.42),
                            (side * .60, -.04 + phase * side, .76),
                            (side * .61, .10 - phase * side, .21), (side * .61, -.12 - phase * side, 0), .21)
            art.box(f'Guardian broad ankle plate {side}', (side * .61, -.25 - phase * side, .24), (.49, .39, .26), 'bone', .028)
    with assembly('Recessed face and exposed red core'):
        art.egg('Guardian rear torso bellows', (0, .20, 2.05), (.53, .43, .70), 'black', 12, 6)
        cage('Guardian open core restraint', (0, -.18, 2.17), (.42, .32, .55))
        art.egg('Guardian real red core', (0, -.32, 2.22), (.22, .21, .39), 'skin', 12, 6)
        for i in range(3):
            art.tube(f'Guardian core pressure vein {i}', [(-.13, -.51, 2.00 + i * .14),
                     (.02, -.56, 2.03 + i * .14), (.14, -.49, 2.09 + i * .14)], .018, 'amber', 5)
        slotted_mask('Guardian recessed watch face', (0, -.27, 2.94), .23, .36)
        art.box('Guardian separated top cowling', (0, .11, 3.23), (.60, .57, .14), 'bone', .045)
    with assembly('Broad split-lancet shield panels and opening hinges'):
        from mathutils import Matrix
        for side in (-1, 1):
            before = set(bpy.context.scene.objects)
            center = (side * .64, -.66, 2.05)
            shield_leaf(f'Guardian shield {side}', center, 1.02, 2.37)
            art.tube(f'Guardian panel hinge {side}', [(side * .26, -.46, 1.11), (side * .26, -.46, 2.83)], .078, 'steel', 8)
            piston(f'Guardian opening piston {side}', (side * .36, -.03, 2.74), (side * .80, -.58, 2.38), .085)
            if opening:
                pivot = Vector((side * .28, -.44, 2.0))
                transform = Matrix.Translation(pivot) @ Matrix.Rotation(side * opening, 4, 'Z') @ Matrix.Translation(-pivot)
                bpy.context.view_layer.update()
                for obj in bpy.context.scene.objects:
                    if obj not in before:
                        obj.matrix_world = transform @ obj.matrix_world
    with assembly('Unplated posterior nerve seam and copper regulator'):
        for i in range(7):
            art.ring(f'Guardian exposed rear bellows fold {i}', (0, .22, 1.52 + i * .19), .40, .045, 'skin', segments=12)
            art.box(f'Guardian dorsal regulator lock {i}', (.06, .68, 1.50 + i * .18), (.19, .09, .068), 'bronze', .008)
        for side in (-1, 1):
            tendon(f'Guardian vulnerable rear nerve {side}', [(side * .22, .62, 2.98),
                   (side * .36, .76, 2.54), (side * .33, .69, 1.68), (side * .18, .48, 1.31)], .049)
        art.ring('Guardian asymmetric rear copper regulator', (.21, .65, 2.40), .21, .055, 'bronze', 'XZ', 12)
        art.egg('Guardian rear amber regulator center', (.21, .67, 2.40), (.085, .055, .085), 'amber', 8, 4)
    with assembly('Side manipulator arms behind shielding'):
        for side in (-1, 1):
            shoulder = (side * .62, .04, 2.58)
            elbow = (side * .95, -.04, 2.12)
            wrist = (side * (1.15 if opening else .98), -.40, 1.67 + phase * side)
            piston(f'Guardian jointed side arm {side}', shoulder, elbow, .10)
            art.tube(f'Guardian tendon forearm {side}', [elbow, wrist], [.095, .07], 'skin', 6)
            hand(f'Guardian articulated claw {side}', wrist, .075, False)


def summoner(pose):
    phase = .11 if pose == 'walk_a' else -.11 if pose == 'walk_b' else .04 if pose == 'dead' else 0
    expanded = pose == 'attack'
    with assembly('Grounded thin tripod stilt assembly'):
        for i, angle in enumerate((-.90, .90, math.pi)):
            x, y = math.sin(angle), -math.cos(angle)
            step = phase * (1 if i == 0 else -1 if i == 1 else .5)
            articulated_leg(f'Summoner planted stilt {i}', (x * .29, y * .24, 1.50),
                            (x * .61, y * .60 + step, .93), (x * .84, y * .86 - step, .19),
                            (x * .86, y * .89 - step, 0), .073)
        art.egg('Summoner narrow nonhuman pelvis hub', (0, .05, 1.55), (.23, .24, .22), 'bronze', 10, 6)
    with assembly('Open spinal cage and suspended red bud'):
        art.tube('Summoner exposed central spine', [(0, .18, 1.48), (0, .15, 3.41)], [.075, .10], 'black', 8)
        for side in (-1, 1):
            for i in range(6):
                x = side * (.42 + (.20 if expanded else 0))
                z = 3.08 - i * .20
                bend(f'Summoner expanded open rib {side} {i}', [(0, .18, z),
                     (x, .06, z + .04), (x, -.35, z - .08), (side * (.20 if expanded else .08), -.38, z - .14)],
                     (.036, .022), 'bone', 5, 8)
        art.egg('Summoner suspended nonhuman red bud', (.05, -.20, 1.76), (.16, .17, .34), 'skin', 10, 6)
        for side in (-1, 1):
            tendon(f'Summoner bud suspension nerve {side}', [(side * .26, .11, 2.77),
                   (side * .38, -.21, 2.47), (side * .24, -.23, 1.89), (0, -.22, 1.57)], .027)
        for i in range(5):
            art.box(f'Summoner asymmetrical spine regulator {i}', (.10, .28, 2.27 + i * .21), (.10, .09, .07), 'bronze', .006)
    with assembly('Three open mouth horns and suspended halo'):
        for i, x in enumerate((-.66, 0, .66)):
            z = 3.89 if i == 1 else 3.36
            flare = 1.80 if expanded else 1.45
            hollow(f'Summoner actual hollow mouth horn {i}', (x, .05, z), .35, .18, .044, 'bone', flare, True)
            art.ring(f'Summoner mouth collar {i}', (x, .03, z), .19, .035, 'bronze', 'XZ', 12)
            for side in (-1, 1):
                tendon(f'Summoner mouth return {i} {side}', [(x + side * .14, .05, z),
                       (x + side * .19, .19, z - .20), (x + side * .17, .15, 3.01),
                       (side * .12, .22, 2.65)], .026)
            if expanded:
                art.egg(f'Summoner contained horn pressure {i}', (x, -.25, z), (.11, .065, .11), 'amber', 8, 4)
        art.ring('Summoner independent thin halo', (0, .15, 3.74), .51, .024, 'bronze', 'XZ', 16)
        for i in range(6):
            a = i * math.tau / 6
            art.tube(f'Summoner halo radial tether {i}', [(.49 * math.cos(a), .15, 3.74 + .49 * math.sin(a)),
                     (.62 * math.cos(a), .15, 3.74 + .62 * math.sin(a))], [.019, .009], 'bronze', 5)
    with assembly('Ritual-expanded thin arms and dragging nerve cables'):
        for side in (-1, 1):
            shoulder = (side * .32, .09, 3.12)
            elbow = (side * (1.00 if expanded else .67), -.10, 2.94 if expanded else 2.62 + phase * side)
            wrist = (side * (1.38 if expanded else .92), -.34, 3.22 if expanded else 2.41 - phase * side)
            art.tube(f'Summoner open bone arm {side}', [shoulder, elbow, wrist], [.065, .048, .032], 'bone', 6)
            art.joint(f'Summoner small elbow bearing {side}', elbow, .074)
            hand(f'Summoner gesturing ritual hand {side}', wrist, .18)
            for i in range(2):
                tendon(f'Summoner asymmetric hanging nerve {side} {i}', [wrist,
                       (side * (1.5 if expanded else 1.11), .07, 2.04),
                       (side * .96, .31, 1.06 + .16 * i), (side * .54, .42, 1.34)], .021)


def nursery_warden(pose):
    phase = .16 if pose == 'walk_a' else -.16 if pose == 'walk_b' else .06 if pose == 'dead' else 0
    tell = pose == 'attack'
    crouch = .28 if tell else 0
    with assembly('Three heavy walking incubation legs'):
        for i, (x, y) in enumerate(((-1.03, -.47), (1.03, -.47), (.15, 1.09))):
            step = phase * (1 if i == 0 else -1 if i == 1 else .4)
            knee = (x * 1.29, y * 1.1 + step, 1.45)
            ankle = (x * (1.52 if tell else 1.40), y * 1.49 - step, .32)
            foot = (ankle[0], ankle[1] - .05, 0)
            articulated_leg(f'Warden walking tripod leg {i}', (x * .64, y * .55, 2.57 - crouch), knee, ankle, foot, .24)
            for j in range(3):
                tendon(f'Warden independent exposed thigh nerve {i} {j}', [(x * .69, y * .61 + j * .04, 2.5 - crouch),
                       (knee[0] + j * .04, knee[1], 1.9), (knee[0], knee[1] + .14, 1.34),
                       (ankle[0], ankle[1], .47)], .045)
            art.box(f'Warden surgical shin leaf {i}', (ankle[0], ankle[1] - .16, .66), (.36, .15, .57), 'bone', .035)
    with assembly('Open windowed rib torso around black thorn organism'):
        art.egg('Warden basal pressure manifold', (0, .17, 2.48 - crouch), (.80, .50, .35), 'black', 12, 6)
        for side in (-1, 1):
            for i in range(7):
                z = 4.79 - crouch - i * .30
                x = side * (.84 + (.31 if tell else 0))
                bend(f'Warden opening costal window rib {side} {i}', [(0, .30, z),
                     (x, .18, z + .12), (x, -.66, z + .01),
                     (side * (.47 if tell else .21), -.71, z - .18)], (.076, .050), 'bone', 6, 9)
            for i in range(3):
                tendon(f'Warden torso arterial return {side} {i}', [(side * .18, .24, 4.82 - crouch),
                       (side * .55, .19 + i * .055, 4.15 - crouch),
                       (side * .68, -.04, 3.16 - crouch), (side * .16, .05, 2.62 - crouch)], .047)
        for i in range(8):
            a = math.tau * i / 8
            x, y = .19 * math.cos(a), .17 * math.sin(a)
            bend(f'Warden nonhuman thorn organism root {i}', [(x, y, 2.81 - crouch),
                 (x * 2.7, y * 2.5, 3.33 - crouch), (x * 2.9, y * 2, 4.21 - crouch),
                 (x * .8, y * .7, 4.59 - crouch)], (.105, .016), 'black', 6, 10)
            art.tube(f'Warden thorn organism lateral barb {i}', [(x * 2.6, y * 2.2, 3.87 - crouch),
                     (x * 3.6, y * 3.7, 4.05 - crouch)], [.075, .004], 'black', 6)
        slotted_mask('Warden narrow organ regulator crown', (0, -.21, 5.02 - crouch), .27, .42)
    with assembly('Two unequal shoulder seed-cages and pressure windows'):
        for side in (-1, 1):
            radius = .61 if side == -1 else .53
            z = 4.69 - crouch + (.10 if side == -1 else -.08)
            cage(f'Warden {side} independent shoulder seed-cage', (side * 1.42, .07, z), (radius, .48, .85))
            art.egg(f'Warden {side} nonhuman branching seed', (side * 1.42, .07, z), (radius * .63, .30, .55), 'black', 12, 6)
            for i in range(5):
                tendon(f'Warden {side} shoulder seed red root {i}', [(side * 1.42, -.10, z - .59),
                       (side * (1.14 + .10 * i), -.32, z - .34), (side * (1.14 + .10 * i), -.27, z + .39),
                       (side * 1.42, -.03, z + .60)], .029)
            for i in range(2):
                vessel = hollow(f'Warden {side} upright amber pressure window {i}',
                                (side * (.68 + i * .20), -.21, 3.09 - crouch), 1.35, .095, .030, 'bronze')
                vessel.rotation_euler.x = 0
                art.egg(f'Warden {side} pressure-window living index {i}',
                        (side * (.68 + i * .20), -.25, 3.68 - crouch), (.055, .062, .42), 'amber', 10, 6)
    with assembly('Independent pruning clamp and root-nozzle arm'):
        for side in (-1, 1):
            shoulder = (side * 1.19, .13, 3.86 - crouch)
            elbow = (side * 1.76, -.10, 3.10 - crouch)
            wrist = (side * (2.02 if tell else 1.91), -.42 if tell else -.22, 2.31 - crouch)
            art.joint(f'Warden arm shoulder load bearing {side}', shoulder, .25)
            piston(f'Warden heavy unequal arm {side}', shoulder, elbow, .21 if side == -1 else .15)
            if side == -1:
                piston('Warden pruning forearm', elbow, wrist, .19)
                for jaw in (-1, 1):
                    gape = .22 if tell else .11
                    bend(f'Warden true open pruning clamp jaw {jaw}', [wrist,
                         (wrist[0] + jaw * gape, -.51, 1.93 - crouch),
                         (wrist[0] + jaw * gape, -.56, 1.42 - crouch),
                         (wrist[0] + jaw * .055, -.58, 1.52 - crouch)], (.14, .044), 'bone', 8, 9)
                    art.tube(f'Warden clamp surgical cutting edge {jaw}', [(wrist[0] + jaw * gape, -.61, 1.92 - crouch),
                             (wrist[0] + jaw * .07, -.63, 1.48 - crouch)], .027, 'steel', 5)
            else:
                tendon('Warden braided root forearm', [elbow, (2.13, .08, 2.89 - crouch),
                       (2.10, -.18, 2.31 - crouch), wrist], .16)
                for i in range(5):
                    tip = (2.07 + i * .10, -.43 - .07 * i, 1.76 - crouch + .10 * (i % 2))
                    tendon(f'Warden five independently forked nozzle roots {i}', [wrist,
                           (2.14 + i * .07, -.17, 2.12 - crouch),
                           (2.33 + i * .05, -.34, 1.94 - crouch), tip], .055)
                    art.ring(f'Warden root pressure cuff {i}', tip, .059, .018, 'bronze', 'XZ', 8)
    with assembly('Exposed dorsal bellows regulator and pressure anatomy'):
        for i in range(9):
            art.box(f'Warden rear spine load clamp {i}', (0, .59, 2.85 - crouch + i * .25), (.28, .13, .11), 'bronze', .014)
        for side in (-1, 1):
            tendon(f'Warden rear shoulder pressure artery {side}', [(side * 1.37, .32, 4.67 - crouch),
                   (side * .81, .96, 4.31 - crouch), (side * .79, .95, 3.01 - crouch),
                   (side * .46, .38, 2.47 - crouch)], .092)
        art.ring('Warden unplated posterior regulator', (.25, .77, 3.56 - crouch), .33, .071, 'bronze', 'XZ', 16)
        art.egg('Warden asymmetric rear pressure return', (.25, .78, 3.56 - crouch), (.21, .09, .21), 'skin', 10, 6)


def choir_avatar(pose):
    phase = .09 if pose == 'walk_a' else -.09 if pose == 'walk_b' else .025 if pose == 'dead' else 0
    opened = pose == 'attack'
    gap = .47 if opened else .05
    with assembly('Thick hollow oval jaw-ring and independently opening crescents'):
        for side in (-1, 1):
            arc = (-math.pi * .47, math.pi * .47) if side == 1 else (math.pi * .53, math.pi * 1.47)
            leaf = shell(f'Avatar {side} real hollow jaw crescent', [(2.06, -.13), (2.17, -.11), (2.21, .14),
                         (1.91, .14), (1.85, -.11), (2.06, -.13)], 'bone', aspect=(.74, 1.15), arc=arc, steps=20)
            leaf.rotation_euler.x = math.pi / 2
            leaf.location = (side * gap, -.01, 3.0 + phase)
            for i in range(11):
                a = (-.43 + i * .086) * math.pi if side == 1 else (.57 + i * .086) * math.pi
                x, z = side * gap + 1.92 * .74 * math.cos(a), 3.0 + phase + 1.92 * 1.15 * math.sin(a)
                art.tube(f'Avatar inward jaw-ring fang {side} {i}', [(x, -.22, z),
                         (x - .20 * math.cos(a), -.30, z - .26 * math.sin(a))], [.080, .006], 'bone', 6)
                art.egg(f'Avatar separate copper jaw bearing {side} {i}', (x + .12 * math.cos(a), .13, z + .14 * math.sin(a)),
                        (.10, .10, .10), 'bronze', 8, 4)
            tendon(f'Avatar long half-ring tension nerve {side}', [(side * (.25 + gap), .05, 5.32 + phase),
                   (side * (1.76 + gap), .27, 4.42 + phase), (side * (1.76 + gap), .28, 1.51 + phase),
                   (side * (.25 + gap), .04, .62 + phase)], .092)
    with assembly('Three independent nested mouth resonators'):
        for i, (x, z, r) in enumerate(((.04, 4.28, .36), (-.12, 2.95, .44), (.08, 1.56, .31))):
            hollow(f'Avatar real inner mouth resonator {i}', (x, .12, z + phase), .45, r, .070, 'skin', 1.34, True, (.8, 1.12))
            art.ring(f'Avatar inner mouth bone collar {i}', (x, -.34, z + phase), r * 1.27, .060, 'bone', 'XZ', 16)
            for j in range(8):
                a = j * math.tau / 8
                art.tube(f'Avatar independent resonator tooth {i} {j}', [(x + r * 1.2 * math.cos(a), -.36, z + phase + r * 1.2 * math.sin(a)),
                         (x + r * .76 * math.cos(a), -.41, z + phase + r * .76 * math.sin(a))], [.046, .004], 'bone', 5)
            if opened:
                art.egg(f'Avatar contained attack mouth pressure {i}', (x, -.21, z + phase), (.13, .06, .17), 'amber', 8, 4)
    with assembly('Red nerve core and posterior regulators exposed through negative space'):
        art.egg('Avatar red innermost nonhuman core', (.10, .24, 2.93 + phase), (.50, .28, .81), 'skin', 12, 6)
        cage('Avatar core restraining filaments', (.10, .22, 2.93 + phase), (.54, .34, .88), 'bronze')
        for side in (-1, 1):
            for i in range(3):
                tendon(f'Avatar independently visible core nerve {side} {i}', [(side * .43, .31, 3.63 + phase),
                       (side * (.70 + .12 * i), .21, 3.34), (side * (.65 + .1 * i), .13, 2.4),
                       (side * .30, .18, 2.09 + phase)], .041)
        for i in range(8):
            art.box(f'Avatar exposed rear vertebral regulator {i}', (.06, .54, 1.79 + i * .31), (.24, .13, .095), 'bronze', .012)
        art.ring('Avatar asymmetric posterior pressure dial', (.32, .63, 3.23), .29, .050, 'bronze', 'XZ', 12)
        art.egg('Avatar rear red return chamber', (.32, .66, 3.23), (.19, .085, .19), 'skin', 10, 6)
    with assembly('Upper articulated fin arms and hanging bronze instruments'):
        for side in (-1, 1):
            for i in range(3):
                root = (side * 1.1, .14, 4.42 + i * .31 + phase)
                tip = (side * (2.36 + .15 * i + (.20 if opened else 0)), .22, 4.66 + i * .56 + phase)
                bend(f'Avatar upper fin spar {side} {i}', [root, (side * 1.81, .23, root[2] + .28),
                     (side * 2.12, .18, tip[2] + .16), tip], (.072, .026), 'bone', 6, 10)
                bottom = (tip[0] * .77, .26, root[2] - .17)
                vertices = [root, tip, bottom, (root[0], .32, root[2]), (tip[0], .34, tip[2]), (bottom[0], .35, bottom[2])]
                art.mesh(f'Avatar thick red fin membrane {side} {i}', vertices,
                         [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], 'skin')
                art.tube(f'Avatar hanging instrument tether {side} {i}', [tip, (tip[0], .26, tip[2] - .64)], .023, 'black', 5)
                hollow(f'Avatar open suspended bronze weight {side} {i}', (tip[0], .26, tip[2] - .65), .22, .071, .021, 'bronze')
    with assembly('Hooked inverted lower ribs without planted feet'):
        for side in (-1, 1):
            for i in range(3):
                bend(f'Avatar inverted freely hanging rib hook {side} {i}', [(side * (1.1 + .12 * i + gap), .19, 2.26 - .22 * i),
                     (side * (1.86 + .10 * i + gap), .22, 1.46 - .14 * i),
                     (side * (1.82 + .05 * i), -.02, .32 + .16 * i),
                     (side * (.86 + .16 * i), -.14, .05 + .17 * i)], (.105, .021), 'bone', 6, 10)
                tendon(f'Avatar inverted rib arterial return {side} {i}', [(side * (1.02 + gap), .27, 2.57 - .19 * i),
                       (side * 1.69, .39, 1.82), (side * 1.81, .28, .61 + .17 * i),
                       (side * 1.11, -.05, .29 + .17 * i)], .041)
        art.tube('Avatar irregular freely hanging central tail', [(0, .39, 1.55), (.15, .36, .80),
                 (-.09, .18, .35)], [.065, .04, .005], 'black', 6)


def geometry_digest(objects):
    """Fingerprint native geometry/transforms, excluding autogenerated object names."""
    rows = []
    for obj in objects:
        rows.append((tuple(tuple(row) for row in obj.matrix_world),
                     tuple(tuple(v.co) for v in obj.data.vertices),
                     tuple(tuple(p.vertices) for p in obj.data.polygons)))
    return hashlib.sha256(repr(rows).encode()).hexdigest()


def build(asset):
    scene = art.setup()
    instrument.tissue_texture()
    art.M['bone'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = art.rgba('#d6c5a1')
    art.M['bronze'] = art.material('Surgical bronze restraints', '#986439', .72, .46)
    art.M['violet'] = art.material('Contained violet choral pressure', '#9b64e8', emission=1.6)
    weapon = asset in WEAPONS
    frames = ['idle', 'fire', 'recover'] if weapon else art.FRAMES
    groups, poses, prior = [], {}, {}
    for pose in frames:
        group = art.pose_collection(pose)
        instrument.ROOT_COLLECTION = group
        before = set(scene.objects)
        globals()[asset](pose)
        objects = [o for o in scene.objects if o not in before and o.type == 'MESH']
        bpy.context.view_layer.update() # Read evaluated transforms before laying down this pose.
        if weapon:
            recoil = {'idle': (0, 0), 'fire': (.055, -.15), 'recover': (-.025, -.07)}
            if asset == 'marrow_launcher':
                recoil.update(fire=(.09, -.28), recover=(-.045, -.13))
            lift, pull = recoil[pose]
            for obj in objects:
                obj.location.y += pull
                obj.location.z += lift
        elif pose == 'dead':
            # Only this newly created assembly is laid down; earlier posed meshes are untouched.
            from mathutils import Matrix
            roll = Matrix.Rotation(.23, 4, 'Z') @ Matrix.Rotation(math.pi * .47, 4, 'X')
            for obj in objects:
                obj.matrix_world = roll @ obj.matrix_world
        instrument.tissue_uv(objects)
        bpy.context.view_layer.update()
        if not weapon:
            extent = art.bounds(objects)
            low = extent['min'][2]
            for obj in objects:
                obj.location.z -= low
                if pose == 'dead':
                    obj.location.x -= (extent['min'][0] + extent['max'][0]) / 2
                    obj.location.y -= (extent['min'][1] + extent['max'][1]) / 2
            bpy.context.view_layer.update()
        for old, digest in prior.items():
            assert geometry_digest([old]) == digest, (asset, pose, old.name, 'Mutated preceding posed geometry')
        counts = [{'name': o.name, 'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in objects]
        triangles = sum(o['triangles'] for o in counts)
        assert 50 <= len(objects) and triangles <= SPECS[asset]['triangle_budget'], (asset, pose, len(objects), triangles)
        poses[pose] = {'meshes': counts, 'triangles': triangles,
                       'assemblies': [c.name for c in group.children], 'geometry_sha256': geometry_digest(objects),
                       'physical_bounds_m': art.bounds(objects)}
        assert len(group.children) >= 4, (asset, pose, 'Editable assemblies missing')
        prior.update({o: geometry_digest([o]) for o in objects})
        groups.append(group)
        print(f'ART_SOURCE_CHECKPOINT {asset} {pose} {len(objects)} meshes {triangles} triangles', flush=True)
    assert len({p['geometry_sha256'] for p in poses.values()}) == len(frames), 'Poses must change geometry, not just names'
    cell = SPECS[asset]['cell']
    width, height = (320, 200) if weapon else (cell, cell)
    cam = art.camera(scene, (0, -3.4, 2.4) if weapon else (0, -10, 3.5),
                     (0, .3, .95) if weapon else (0, 0, SPECS[asset]['aim']),
                     2.65 if weapon else SPECS[asset]['scale'], width, height)
    scene['asset_id'], scene['authoring_recipe'] = asset, 'tools/build_late_combat_art.py'
    scene['recipe_sha256'] = art.sha(Path(__file__))
    scene['reference_image'] = reference(asset)['path']
    scene['reference_sha256'] = reference(asset)['sha256']
    for group in groups:
        group.hide_render = group != groups[0]
        group.hide_viewport = group != groups[0]
    # Save complete independently editable poses before runtime PNG assembly.
    source = art.save(asset)
    for group in groups:
        group.hide_viewport = False
    cells = []
    for row, group in enumerate(groups):
        for other in groups:
            other.hide_render = other != group
        for column in range(1 if weapon else 8):
            if not weapon:
                angle = math.radians(column * 45)
                cam.location = (10 * math.sin(angle), -10 * math.cos(angle), 3.5)
                cam.rotation_euler = (Vector((0, 0, SPECS[asset]['aim'])) - cam.location).to_track_quat('-Z', 'Y').to_euler()
            frame = f'{asset}_{group.name}' if weapon else f'{asset}_{row}_{column}'
            pixels = art.pixels_render(scene, frame, width, height)
            occupied = [y for y in range(height) if any(pixels[(y * width + x) * 4 + 3] for x in range(width))]
            assert occupied and min(occupied) > 0, (asset, frame, 'Native pose clipped at top')
            if weapon:
                assert min(occupied) >= 24, (asset, frame, 'Weapon obscures central aim')
            else:
                assert max(occupied) < height - 1, (asset, frame, 'Native character clipped at bottom')
                bottom = max(occupied)
                aligned = bytearray(len(pixels))
                shift = height - 9 - bottom
                assert min(occupied) + shift > 0, (asset, frame, 'Baseline alignment clips pose')
                for y in occupied:
                    dest = y + shift
                    aligned[dest * width * 4:(dest + 1) * width * 4] = pixels[y * width * 4:(y + 1) * width * 4]
                pixels = aligned
                if group.name == 'dead':
                    assert min(occupied) + shift >= height // 2, (asset, frame, 'Death has not collapsed')
            cells.append(pixels)
        print(f'ART_CHECKPOINT {asset} {group.name} rendered', flush=True)
    assert len({bytes(p) for p in cells}) == len(cells), 'Every actual native frame must be unique'
    art.atlas(asset, cells, 3 if weapon else 8, 1 if weapon else 5, width, height)
    path = art.OUT / ('weapons' if weapon else 'sprites') / (asset + '.png')
    assert path.stat().st_size <= SPECS[asset]['byte_budget'], (asset, 'Runtime PNG byte budget')
    entry = art.record(asset, source, [(path, [width * (3 if weapon else 8), height * (1 if weapon else 5)])],
                       cell_size=[width, height], columns=3 if weapon else 8, frames=frames, pose_collections=frames,
                       pose_mesh_counts={p: len(v['meshes']) for p, v in poses.items()},
                       origin_px=[160, 200] if weapon else [cell // 2, cell - 8], filter='nearest',
                       facing='weapon looks along Blender +Y' if weapon else 'column0 sees front (-Y); column2 sees right (+X)',
                       yaw_degrees=[] if weapon else list(range(0, 360, 45)),
                       collision='none; runtime sprite, world height and collider owned by parent')
    return entry, poses


def main():
    global bpy, Vector, art, instrument, bend, shell, assembly
    opts = arguments(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    output, receipt = preflight(opts.asset, opts.output_root, opts.receipt_root, ROOT)
    ref = reference(opts.asset)
    assert hashlib.sha256((ROOT / ref['path']).read_bytes()).hexdigest() == ref['sha256'], 'Selected image drift'
    dependencies = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in DEPENDENCIES}
    manifest_data = (ROOT / 'source/art/manifest.json').read_bytes()
    manifest = json.loads(manifest_data)
    assert dependencies['tools/build_art.py'] == manifest['build']['script_sha256'], 'Native helper drift'
    recipe_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    import bpy
    from mathutils import Vector
    import build_art as art
    import build_foundry_art as foundry
    import build_processional_art as instrument
    bend, shell, assembly = foundry.bend, foundry.shell, instrument.assembly
    art.ROOT, art.ART, art.OUT, art.SCRATCH = output, output / 'source/art', output / 'game/assets/art', output / 'previews'
    original_target = art.target
    def isolated_target(path):
        if opts.asset not in WEAPONS and path == art.OUT / 'weapons' / (opts.asset + '.png'):
            path = art.OUT / 'sprites' / (opts.asset + '.png')
        if path.exists() or path.is_symlink():
            raise FileExistsError('Never overwrite a candidate native output: ' + str(path))
        return original_target(path)
    art.target = isolated_target
    print('ART_START ' + opts.asset, flush=True)
    entry, poses = build(opts.asset)
    assert hashlib.sha256(Path(__file__).read_bytes()).hexdigest() == recipe_hash, 'Recipe changed during native job'
    assert dependencies == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in DEPENDENCIES}, 'Helper changed during native job'
    assert hashlib.sha256((ROOT / ref['path']).read_bytes()).hexdigest() == ref['sha256'], 'Reference changed during native job'
    assert (ROOT / 'source/art/manifest.json').read_bytes() == manifest_data, 'Production manifest changed during native job'
    entry.update(recipe_sha256=recipe_hash, recipe_dependencies=dependencies, reference_images=[ref])
    entry['provenance']['authoring_script'] = 'tools/build_late_combat_art.py'
    receipt.mkdir(parents=True, exist_ok=True)
    payload = {'asset': entry, 'poses': poses, 'pose_independence_verified': True, 'output_root': str(output),
               'status': 'native_candidate_not_integrated', 'blender_version': bpy.app.version_string,
               'render_engine': 'Cycles CPU', 'threads': 4, 'samples': 16,
               'preview': str(art.SCRATCH / (opts.asset + '_contact.png')),
               'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest()}
    target = receipt / (opts.asset + '_candidate.json')
    if target.exists() or target.is_symlink():
        raise FileExistsError('Candidate receipt appeared during native job')
    target.write_text(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
