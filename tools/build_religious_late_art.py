"""Five image-derived late-level machine sets; parent owns all native jobs."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_religious_art as intake
import build_religious_foundry_art as thermal

LEVEL_IDS = {
    'reliquary': ('reliquary_face_halo', 'reliquary_memory_wheel', 'reliquary_bound_gate', 'reliquary_cell_vault',
                  'reliquary_tower_cluster', 'reliquary_seven_vessels', 'reliquary_winged_seal'),
    'nursery': ('nursery_gestation_engine', 'nursery_seed_orrery', 'nursery_bound_gate', 'nursery_cell_canopy',
                'nursery_tower_cluster', 'nursery_seven_vessels', 'nursery_winged_cradle'),
    'ossuary': ('ossuary_rib_bridge', 'ossuary_bone_mandala', 'ossuary_bound_gate', 'ossuary_cell_archive',
                'ossuary_tower_cluster', 'ossuary_seven_reservoirs', 'ossuary_winged_sarcophagus'),
    'inversion': ('inversion_surgical_cradle', 'inversion_tilted_gyroscope', 'inversion_bound_gate', 'inversion_cell_prism',
                  'inversion_tower_cluster', 'inversion_seven_vessels', 'inversion_winged_cradle'),
    'heart': ('heart_mouth_restraint', 'heart_pulse_mandala', 'heart_bound_gate', 'heart_cell_crown',
              'heart_tower_cluster', 'heart_seven_reservoirs', 'heart_winged_seal'),
}
IDS = tuple(asset for assets in LEVEL_IDS.values() for asset in assets)
HEROES = tuple(asset for assets in LEVEL_IDS.values() for asset in assets[:2])
TRADITIONS = {asset: tradition for assets in LEVEL_IDS.values() for asset, tradition in
              zip(assets, ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian'))}
REFERENCES = dict(zip(LEVEL_IDS, (
    'e7ae48a255ac9d774e41a61cb66b7da4c32cc79abe78d074af1c3156c724125a',
    'ce876b7f9cd940c17222a836a82f9540fcdfb0124b00b7d7ecd7d4e30837c71f',
    '4f7d989d4e749fe18b6a1bc119de302d6e5f27a593d62a7154eadad3fd624a0b',
    'dca8eecc5b292131a0f4eb578a8189681722de86c541b603f9ae9155699caa15',
    '0e31156d973594539682535332c5e5c620674fda60296976db5a4eaeb0b1acca',
)))
PURPOSES = dict(zip(IDS, (
    'Indexes recovered identities on an upright face halo and articulated spinal reader',
    'Cycles memory through suspended face-gallery cells above a receiving lotus',
    'Measures memorial transfers through an open threshold with hanging witness vessels',
    'Stores harvested recollections in deep pointed cells around an open retrieval passage',
    'Raises archived witness fragments through stepped inspection chambers',
    'Separates seven retained identity streams in upright witness vessels',
    'Locks an indexed identity into a winged upright seal and lateral restraint vanes',
    'Grows a new control body in an elongated pointed gestation chamber',
    'Sorts developing seeds through tilted oval cradles on a low orbital receiver',
    'Transfers developing organisms through a bound threshold and two hanging pods',
    'Feeds suspended embryos from a flared cellular incubation canopy',
    'Grades growth through staggered gestation towers and exposed root feeds',
    'Balances seven suspended growth pods on a delicate distributing tree',
    'Positions an unfinished body in a reclining cradle with swept protective vanes',
    'Routes bone transport under a longitudinal vertebral arch with a clear central passage',
    'Sorts recovered remains around a horizontal rib mandala and hollow central spindle',
    'Weighs skeletal transfers using empty suspended cages at a rooted bone threshold',
    'Archives recovered bones in staggered open niches and branching retrieval paths',
    'Sifts marrow through three linked tiered skeletal towers',
    'Separates recovered marrow in seven ossified reservoirs on a heavy articulated manifold',
    'Presents a sealed upright bone body between steep wing braces and flanking obelisks',
    'Reorients a restrained body inside a narrow surgical frame and opposing blades',
    'Reverses the orientation of a suspended lotus using three tilted gyroscopic races',
    'Tensions inverted transfers across an open bound gate with lateral empty cages',
    'Suspends a double-ended cellular prism on an exposed transfer axis',
    'Moves stored bodies through offset towers joined by sloping spiral transfers',
    'Returns seven orientation signals through twisted branches and offset reservoirs',
    'Holds a vertical inverted body between tall wing blades and opposed restraints',
    'Restrains the controller mouth using a deep toothed annulus and rear tissue throat',
    'Regulates an exposed lobed pulse organ using separated petal clamps and radial feeds',
    'Measures arterial transfers through a vertebral threshold with two hanging organ cages',
    'Distributes pulse pressure through a domed cellular crown with deep red cavities',
    'Stages pressure ascent through a stepped tissue tower and exposed arterial returns',
    'Divides final pulse flow among seven red reservoirs on broad bone branches',
    'Holds the final pulse core inside a horizontal winged seal between two obelisks',
)))
CAPS = (8, 6, 9)
STATS = {}


def group_budget(asset, output):
    """Count only this level's seven GLBs; other valid groups share the batch."""
    total = sum((Path(output) / 'game/assets/art/world' / (name + '.glb')).stat().st_size
                for name in LEVEL_IDS[asset.split('_', 1)[0]]
                if (Path(output) / 'game/assets/art/world' / (name + '.glb')).exists())
    assert total < 8 * 1024 * 1024, (asset, total, 'Seven-piece level GLB budget')
    return total


def preflight(asset, output_root, receipt_root, project_root):
    if asset not in IDS:
        raise ValueError('Select one exact late-level asset ID')
    for root in (Path(output_root).absolute(), Path(receipt_root).absolute()):
        if any(p.is_symlink() for p in (root, *root.parents)):
            raise ValueError('Candidate roots must use real directories, not symlink paths')
    output, receipt = intake.candidate_roots(output_root, receipt_root, project_root)
    for folder in ('source/art', 'game/assets/art/world', 'game/assets/art/textures', 'previews/frames'):
        if any(p.is_symlink() for p in (output / folder, *(output / folder).parents) if p.is_relative_to(output)):
            raise ValueError('Candidate output directories must not be symlinks')
    targets = (output / 'source/art' / (asset + '.blend'), output / 'game/assets/art/world' / (asset + '.glb'),
               output / 'previews' / (asset + '_preview.png'), output / 'previews/frames' / (asset + '_hero.png'),
               receipt / (asset + '_candidate.json'))
    if any(p.exists() or p.is_symlink() for p in targets):
        raise FileExistsError('Late candidate exists; select fresh candidate roots')
    if (output / 'game/assets/art/textures/surface_atlas.png').is_symlink():
        raise ValueError('Candidate atlas must not be a symlink')
    return output, receipt


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--receipt-root', type=Path, required=True)
    return parser.parse_args(argv)


# Small repeated anatomical assemblies, not alternate geometry/export helpers.
def footing(name, width, depth):
    art.box(name + ' grounded shoe', (0, 0, .12), (width, depth, .24), 'iron', .035)
    for side in (-1, 1):
        art.box(name + f' incised front mounting rim {side}', (side * width * .28, -depth * .43, .29),
                (width * .30, .12, .08), 'steel', .01)


def face(name, x, y, z, scale):
    art.egg(name + ' split brow', (x, y, z + scale * .28), (.30 * scale, .18 * scale, .25 * scale), 'bone', 10, 5)
    for side in (-1, 1):
        art.egg(name + f' eye recess {side}', (x + side * .14 * scale, y - .16 * scale, z + .3 * scale),
                (.075 * scale, .035 * scale, .066 * scale), 'black', 8, 4)
        bend(name + f' hollow jaw {side}', [(x + side * .26 * scale, y, z + .23 * scale),
             (x + side * .31 * scale, y - .13 * scale, z), (x + side * .15 * scale, y - .14 * scale, z - .24 * scale),
             (x, y - .08 * scale, z - .26 * scale)], .043 * scale, 'bone', 6, 7)
    art.tube(name + ' nasal relief', [(x, y - .18 * scale, z + .28 * scale), (x, y - .22 * scale, z + .05 * scale)],
             [.06 * scale, .025 * scale], 'bone', 5)


def niche(name, x, y, z, width, height, depth, charge='amber'):
    verts, faces = thermal.pressure_cell(width)
    art.mesh(name + ' thick recessed pointed cell', [(vx, vy * depth / .44, vz * height / .89) for vx, vy, vz in verts], faces, 'bone').location = (x, y, z)
    if charge:
        art.egg(name + ' captive deep charge', (x, y + depth * .68, z + .06 * height),
                (width * .16, depth * .13, height * .21), charge, 10, 5)
    for side in (-1, 1):
        art.box(name + f' engraved edge lock {side}', (x + side * width * .40, y - .026, z - .12 * height),
                (.045, .07, .12 * height), 'steel', .008)


def pod(name, x, y, z, radius, height, charge='skin'):
    r, h = radius, height
    shell(name + ' open posterior capsule', [(r * .46, 0), (r, h * .23), (r * 1.08, h * .58), (r * .39, h),
          (r * .23, h), (r * .89, h * .58), (r * .81, h * .23), (r * .31, 0), (r * .46, 0)],
          'iron', center=(x, y, z), arc=(0, math.pi), steps=12)
    for i in range(5):
        a = i * math.tau / 5
        c, s = math.cos(a), math.sin(a)
        bend(name + f' curved capsule stave {i}', [(x + r * .45 * c, y + r * .45 * s, z),
             (x + r * 1.55 * c, y + r * 1.55 * s, z + h * .25),
             (x + r * 1.48 * c, y + r * 1.48 * s, z + h * .78),
             (x + r * .37 * c, y + r * .37 * s, z + h)], .045, 'bone', 6, 9)
    for zz, rr in ((z, r * .45), (z + h * .48, r * 1.03), (z + h, r * .37)):
        art.ring(name + f' capsule flange {zz}', (x, y, zz), rr, .045, 'steel', segments=12)
    if charge:
        art.egg(name + ' exposed captive core', (x, y, z + h * .51), (r * .53, r * .45, h * .31), charge, 12, 7)
        art.tube(name + ' amber observation slit', [(x, y - r * .54, z + h * .40), (x, y - r * .54, z + h * .62)], .025, 'amber', 5)


def pointed_pair(name, x, y, bottom, top, width):
    for side in (-1, 1):
        bend(name + f' thick pointed brace {side}', [(x + side * width, y, bottom),
             (x + side * width * 1.2, y + .08, top - 1.8), (x + side * width * .55, y, top - .5),
             (x, y, top)], (.13, .055), 'bone', 6, 12)


def obelisks(name, x, top):
    for side in (-1, 1):
        art.box(name + f' obelisk grounded base {side}', (side * x, .40, .16), (.66, .8, .32), 'iron', .02)
        art.tube(name + f' tapered obelisk shaft {side}', [(side * x, .40, .32), (side * x, .40, top - .55),
                 (side * x, .40, top)], [.24, .14, .006], 'bone', 4)
        for i in range(8):
            art.box(name + f' shaft carved clamp {side} {i}', (side * x, .16, .9 + i * (top - 1.4) / 8),
                    (.14, .065, .07), 'steel', .01)


def wing_vanes(name, root, reach, rise, count, swept=False):
    x, y, z = root
    for side in (-1, 1):
        for i in range(count):
            t = i / (count - 1)
            tipz = z + rise * t
            tipx = side * (reach - .75 * t)
            bend(name + f' separate articulated feather {side} {i}', [(x + side * .43, y, z + t * .6),
                 (x + side * reach * .45, y - .13, z + t * rise * .67),
                 (x + tipx, y + (.95 * t if swept else .08), tipz - .12),
                 (x + tipx * (.82 if swept else 1), y + (.55 * t if swept else .12), tipz + .13)],
                 (.16, .012), 'bone', 6, 9)
            art.tube(name + f' feather incised root {side} {i}', [(x + side * .58, y - .17, z + t * .65),
                     (x + side * reach * .45, y - .27, z + t * rise * .67)], [.021, .007], 'steel', 4)


def tower(name, x, y, bottom, tiers, width, step, charge):
    for j in range(tiers):
        w, z = width * (1 - j * .12), bottom + j * step
        art.box(name + f' tier ring slab {j}', (x, y, z), (w * 1.52, w * 1.20, .14), 'steel', .018)
        for side in (-1, 1):
            niche(name + f' front alcove {j} {side}', x + side * w * .32, y - w * .5, z + step * .34,
                  w * .56, step * .85, w * .52, charge)
        for side in (-1, 1):
            art.tube(name + f' tier vertical carved corner {j} {side}', [(x + side * w * .72, y - w * .50, z + .06),
                     (x + side * w * .55, y - w * .42, z + step)], [.065, .045], 'bone', 6)
    art.tube(name + ' crown axial finial', [(x, y, bottom + tiers * step - .24), (x, y, bottom + tiers * step + .47)], [.12, .012], 'steel', 6)


def reliquary_face_halo():
    with assembly('Halo spinal reader and grounded retrieval shoes'):
        footing('Identity reader', 4.85, 2.85)
        art.tube('Halo exposed reading spine', [(0, .08, .28), (0, .08, 7.91)], .10, 'steel', 8)
        for j in range(21):
            z = .67 + j * .33
            art.box(f'Halo vertebral indexing plate {j}', (0, -.07, z), (.35, .17, .12), 'bone', .018)
            art.tube(f'Halo marrow reading slit {j}', [(-.08, -.17, z), (.08, -.17, z)], .022, 'amber', 5)
    with assembly('Upright face carousel and twelve hollow witness masks'):
        for r, mat in ((2.26, 'steel'), (1.59, 'bone'), (.60, 'steel')):
            art.ring('Halo carved annular race ' + str(r), (0, 0, 5.83), r, .072, mat, 'XZ', 32)
        for i in range(12):
            a = i * math.tau / 12
            x, z = 1.98 * math.cos(a), 5.83 + 1.98 * math.sin(a)
            face(f'Halo indexed witness mask {i}', x, -.15, z, .64)
            art.tube(f'Halo radial index blade {i}', [(0, .14, 5.83), (2.43 * math.cos(a), .14, 5.83 + 2.43 * math.sin(a))],
                     [.052, .008], 'steel', 5)
    with assembly('Pointed retrieval buttresses and deep open sockets'):
        for side in (-1, 1):
            pointed_pair(f'Halo lateral retrieval portal {side}', side * 1.52, -.12, .32, 3.68, .52)
            bend(f'Halo bone exterior load arch {side}', [(side * 2.13, .73, .27), (side * 2.66, .90, 3.03),
                 (side * 1.78, .77, 4.40), (side * .35, .16, 5.80)], .13, 'bone', 6, 14)
            niche(f'Halo recessed retrieval socket {side}', side * 1.52, .14, 1.25, .72, 1.62, .65)
    with assembly('Axial identity return tendons and posterior linkage'):
        for side in (-1, 1):
            bend(f'Halo returning identity tendon {side}', [(side * .38, .16, 6.91), (side * .64, .47, 4.65),
                 (side * .77, .67, 2.30), (side * .27, -.58, .36)], .06, 'skin', 6, 12)
            dial(f'Halo low indexing regulator {side}', (side * .64, -.93, .66), .17)


def reliquary_memory_wheel():
    with assembly('Lotus memory receiver and low radial drive'):
        footing('Memory wheel', 5.85, 4.75)
        shell('Memory receiving deep lotus basin', [(2.15, 1.14), (2.13, 1.38), (.59, .49), (.43, .35),
              (.59, .28), (2.15, 1.14)], 'bone', aspect=(1, .85), steps=24)
        for i in range(12):
            a = i * math.tau / 12
            verts, faces = thermal.slag_petal(a)
            art.mesh(f'Memory low separate lotus petal {i}', [(x * 1.13, y * .86, z * .51 + .16) for x, y, z in verts], faces, 'bone')
    with assembly('Suspended thick gallery drum and open memory cells'):
        for z in (3.60, 5.86):
            shell(f'Memory deep gallery annulus {z}', [(2.15, z), (2.24, z + .16), (1.69, z + .16), (1.69, z), (2.15, z)], 'iron', steps=24)
        for i in range(10):
            a = i * math.tau / 10
            x, y = 1.91 * math.cos(a), 1.91 * math.sin(a)
            pod(f'Memory rotating gallery cell {i}', x, y, 3.76, .27, 1.93, None)
            # Each carved mask faces radially outward, preserving modeled open jaws.
            before = set(bpy.context.scene.objects)
            face(f'Memory captive face {i}', 0, -.24, 4.52, .73)
            bpy.context.view_layer.update()
            for obj in set(bpy.context.scene.objects) - before:
                for vertex in obj.data.vertices:
                    p = obj.matrix_world @ vertex.co
                    vertex.co = (x - p.x * math.sin(a) - p.y * math.cos(a),
                                 y + p.x * math.cos(a) - p.y * math.sin(a), p.z)
                obj.location, obj.rotation_euler, obj.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
    with assembly('Exposed lift spindle and four articulated suspension feet'):
        shell('Memory hollow axial spindle', [(.24, .26), (.24, 6.45), (.13, 6.45), (.13, .26), (.24, .26)], 'steel', steps=12)
        for i in range(4):
            a = i * math.tau / 4
            bend(f'Memory suspended support leg {i}', [(2.38 * math.cos(a), 1.90 * math.sin(a), .25),
                 (2.83 * math.cos(a), 2.05 * math.sin(a), 2.30), (2.11 * math.cos(a), 1.74 * math.sin(a), 5.0),
                 (1.29 * math.cos(a), 1.14 * math.sin(a), 6.24)], .09, 'steel', 6, 12)
    with assembly('Upper indexed crown and visible return ligaments'):
        for i in range(10):
            a = i * math.tau / 10
            art.tube(f'Memory crown radial feed {i}', [(.22 * math.cos(a), .22 * math.sin(a), 6.22),
                     (2.08 * math.cos(a), 2.08 * math.sin(a), 6.12)], .043, 'bone', 5)
            bend(f'Memory identity return {i}', [(.21 * math.cos(a), .21 * math.sin(a), 3.8),
                 (.58 * math.cos(a), .58 * math.sin(a), 2.7), (1.04 * math.cos(a), 1.04 * math.sin(a), 1.6),
                 (.77 * math.cos(a), .77 * math.sin(a), .71)], .04, 'skin', 5, 9)
        for side in (-1, 1):
            dial(f'Memory low return regulator {side}', (side * .64, -1.10, .66), .17)


def reliquary_bound_gate():
    with assembly('Memorial threshold high double lintel and open piers'):
        for side in (-1, 1):
            art.box(f'Memorial independent pier foot {side}', (side * 1.93, .26, .14), (.85, 1.75, .28), 'iron', .025)
            shell(f'Memorial hollow load pier {side}', [(.25, .28), (.22, 6.56), (.12, 6.56), (.14, .28), (.25, .28)],
                  'bone', center=(side * 1.93, .26, 0), steps=12)
            for j in range(2):
                bend(f'Memorial upturned lintel {side} {j}', [(0, .26, 6.1 + j * .7), (side * 1.31, .26, 6.1 + j * .7),
                     (side * 2.54, .26, 6.17 + j * .7), (side * 3.1, .26, 6.54 + j * .7)], .13, 'bone', 8, 10)
    with assembly('Suspended lateral memorial capsules'):
        for side in (-1, 1):
            pod(f'Memorial hanging witness vessel {side}', side * 2.65, .19, 2.07, .37, 1.96, 'skin')
            art.tube(f'Memorial suspended capsule hanger {side}', [(side * 2.65, .19, 4.03), (side * 2.65, .19, 6.45)], .045, 'steel', 6)
            face(f'Memorial vessel carved witness {side}', side * 2.65, -.09, 2.97, .47)
    with assembly('Braided memorial binding and returning tendons'):
        for i in range(3):
            bend(f'Memorial sagging binding strand {i}', [(-1.93, .02, 5.61), (-.80, -.13, 4.81 - i * .12),
                 (.80, -.13, 4.81 - i * .12), (1.93, .02, 5.61)], .07, 'skin', 6, 14)
        for side in (-1, 1):
            bend(f'Memorial posterior tendon {side}', [(side * 1.86, .35, 5.47), (side * 2.46, .81, 3.85),
                 (side * 2.1, .97, .89), (side * 1.78, .68, .28)], .075, 'steel', 6, 10)
    with assembly('Carved memorial pier joints and transfer regulators'):
        for side in (-1, 1):
            for z in (1.3, 3.3, 5.4):
                art.ring(f'Memorial pier locked joint {side} {z}', (side * 1.93, .26, z), .30, .05, 'steel', segments=12)
            dial(f'Memorial transfer index {side}', (side * 1.93, -.65, .62), .18)


def reliquary_cell_vault():
    with assembly('Pointed archive shell and retrieval passage supports'):
        footing('Cell vault', 5.80, 2.20)
        pointed_pair('Vault central open retrieval arch', 0, -.58, .24, 3.18, .77)
        for side in (-1, 1):
            bend(f'Vault exterior pointed load edge {side}', [(side * 2.56, .38, .24), (side * 2.70, .38, 5.86),
                 (side * 1.49, .38, 7.45), (0, .38, 8.40)], .12, 'steel', 6, 14)
    with assembly('Seven rows of individually recessed memory cells'):
        for row in range(7):
            cols = 5 - max(0, row - 3)
            for col in range(cols):
                x = (col - (cols - 1) / 2) * .96
                if row < 2 and abs(x) < .55:
                    continue
                niche(f'Vault memory recess {row} {col}', x, -.08 + row * .018, .87 + row * .98, .84, 1.28, .90)
    with assembly('Carved retrieval anatomy and witness masks'):
        for side in (-1, 1):
            face(f'Vault portal witnessing face {side}', side * .98, -.74, 2.12, .46)
            for i in range(6):
                art.box(f'Vault incised buttress vertebra {side} {i}', (side * 2.54, -.19, .72 + i * .65), (.21, .14, .15), 'bone', .016)
    with assembly('Posterior memory collectors and low calibration'):
        for side in (-1, 1):
            bend(f'Vault exposed posterior collector {side}', [(side * .42, .90, 7.15), (side * 1.45, .86, 5.25),
                 (side * 1.70, .76, 1.60), (side * .75, .63, .30)], .09, 'skin', 6, 14)
            dial(f'Vault retrieval regulator {side}', (side * 1.78, -.91, .62), .19)


def reliquary_tower_cluster():
    with assembly('Stepped archive ground ring and five ascent towers'):
        footing('Archive towers', 5.85, 3.65)
        for i, (x, y, tiers) in enumerate([(-1.86, -.1, 3), (0, .50, 6), (1.86, -.1, 3), (-.92, 1.2, 4), (.92, 1.2, 4)]):
            tower(f'Archive stepped tower {i}', x, y, .34, tiers, .83, 1.04, 'skin')
    with assembly('Broad open central retrieval stair surround'):
        pointed_pair('Archive central chamber mouth', 0, -.59, .25, 2.4, .57)
        for j in range(5):
            art.box(f'Archive low symbolic stair {j}', (0, -.70 + j * .12, .28 + j * .07), (1.05, .14, .10), 'bone', .008)
    with assembly('Exterior tier returns and carved witnesses'):
        for side in (-1, 1):
            bend(f'Archive buttressed tier return {side}', [(side * 2.60, .83, .25), (side * 2.57, .89, 3.88),
                 (side * .88, .96, 5.80), (side * .37, .74, 6.40)], .08, 'steel', 6, 12)
            witness(f'Archive lower carved guardian {side}', side * 1.87, -.58, 1.13, .48)
    with assembly('Axial archive transfer rail and foot regulators'):
        art.tube('Archive rear vertical transfer spindle', [(0, 1.2, .27), (0, 1.2, 6.74)], .075, 'skin', 6)
        for side in (-1, 1):
            dial(f'Archive ascent selection {side}', (side * 1.25, -1.23, .59), .18)


def reliquary_seven_vessels():
    with assembly('Witness manifold roots and axial reader'):
        footing('Witness vessels', 5.95, 2.40)
        art.tube('Witness central reading spine', [(0, .21, .28), (0, .21, 4.28)], .13, 'steel', 8)
        for i in range(11):
            art.box(f'Witness spinal feed lock {i}', (0, .01, .60 + i * .32), (.35, .14, .10), 'bone', .012)
    with assembly('Seven distinct upright retained identity cells'):
        for i in range(7):
            x = (i - 3) * .76
            z = 4.23 - .18 * abs(i - 3)
            pod(f'Witness retained vessel {i}', x, .18, z, .25, 2.25, 'amber')
            face(f'Witness identity relief {i}', x, -.015, z + .91, .42)
    with assembly('Separated curved memory-distribution branches'):
        for i in range(7):
            x = (i - 3) * .76
            z = 4.23 - .18 * abs(i - 3)
            bend(f'Witness independent branch {i}', [((i - 3) * .10, .34, 1.13), (x * .76, .46, 2.24),
                 (x, .22, 3.38), (x, .18, z)], .09, 'bone', 6, 12)
            bend(f'Witness rear memory cable {i}', [((i - 3) * .08, .68, .39), (x * .58, .72, 2.30),
                 (x, .47, 3.45), (x, .41, z + .13)], .042, 'skin', 5, 10)
    with assembly('Low identity gauges and braced manifold heels'):
        for side in (-1, 1):
            bend(f'Witness heel brace {side}', [(side * 2.32, .52, .24), (side * 1.70, .64, 1.33),
                 (side * .50, .61, 1.77), (0, .31, 2.4)], .12, 'steel', 6, 10)
            dial(f'Witness vessel selection {side}', (side * 1.14, -.67, .60), .20)


def reliquary_winged_seal():
    with assembly('Standing seal chassis and flanking index obelisks'):
        footing('Winged memory seal', 7.10, 2.90)
        obelisks('Winged memory seal', 3.03, 7.36)
    with assembly('Deep upright seal casket and captive identity'):
        pod('Winged memory seal open standing casket', 0, .18, .74, .59, 4.60, None)
        witness('Winged memory seal full carved witness', 0, -.23, 3.33, 1.38)
        pointed_pair('Winged memory seal casket surround', 0, -.13, .45, 5.72, .77)
    with assembly('Horizontal independent engraved seal vanes'):
        wing_vanes('Winged memory seal', (0, .42, 2.50), 3.29, 1.90, 12)
        for side in (-1, 1):
            bend(f'Seal articulated lower wing root {side}', [(side * .52, .41, 1.65), (side * 1.98, .75, 1.51),
                 (side * 2.64, .84, 2.83), (side * 3.02, .62, 4.40)], .11, 'steel', 6, 12)
    with assembly('Rear identity return and anterior seal controls'):
        for side in (-1, 1):
            bend(f'Seal indexed return tendon {side}', [(side * .36, .82, 4.40), (side * 1.20, 1.11, 2.87),
                 (side * 1.47, .80, .82), (side * .43, -.34, .37)], .06, 'skin', 6, 11)
            dial(f'Seal final memory clamp {side}', (side * 1.63, -.88, .58), .19)


def nursery_gestation_engine():
    with assembly('Gestation narrow grounded chassis and root feeds'):
        footing('Gestation engine', 3.85, 3.15)
        for side in (-1, 1):
            bend(f'Gestation exposed root {side}', [(side * 1.61, .67, .25), (side * 1.73, .75, 1.36),
                 (side * .58, .46, 2.77), (side * .27, .23, 3.2)], .13, 'skin', 6, 12)
    with assembly('Elongated pointed hollow chamber and thick membrane ribs'):
        pointed_pair('Gestation anterior pointed restraint', 0, -.39, .26, 8.43, 1.11)
        pointed_pair('Gestation posterior pointed restraint', 0, .75, .26, 8.31, .91)
        shell('Gestation cut-open elongated posterior membrane', [(.58, 1.3), (.91, 2.25), (1.04, 5.56), (.74, 7.28),
              (.09, 8.16), (.06, 8.05), (.63, 7.23), (.91, 5.56), (.79, 2.25), (.46, 1.3), (.58, 1.3)],
              'skin', center=(0, .24, 0), aspect=(1, .58), arc=(0, math.pi), steps=16)
        for z in (1.47, 3.38, 5.45, 7.26):
            art.ring(f'Gestation transverse open chamber rib {z}', (0, .24, z), .79 if z < 7 else .62, .075, 'steel', segments=16)
    with assembly('Visible growing body and branching tendril anatomy'):
        art.egg('Gestation forming torso', (0, .25, 4.09), (.37, .24, .89), 'skin', 14, 8)
        face('Gestation uncompleted face', 0, -.02, 5.02, .68)
        for i in range(9):
            z = 2.03 + i * .61
            for side in (-1, 1):
                bend(f'Gestation forming costal tendril {side} {i}', [(0, .52, z), (side * .79, .54, z + .12),
                     (side * .89, -.08, z + .33), (side * .41, -.12, z + .45)], (.048, .018), 'scar', 5, 8)
    with assembly('Four thin satellite needles and chamber controls'):
        for side in (-1, 1):
            for y in (-.63, .96):
                art.tube(f'Gestation satellite needle {side} {y}', [(side * 1.57, y, .24), (side * 1.57, y, 3.18),
                         (side * 1.57, y, 3.71)], [.115, .067, .005], 'bone', 4)
            dial(f'Gestation nutrient regulator {side}', (side * .93, -1.03, .67), .19)


def nursery_seed_orrery():
    with assembly('Seed sorting low bowl and open gear receiver'):
        footing('Seed orrery', 5.75, 4.85)
        shell('Seed thick low orbital bowl', [(1.70, 1.02), (1.87, 1.26), (1.53, 1.18), (.53, .39),
              (.53, .27), (1.70, 1.02)], 'steel', aspect=(1, .86), steps=24)
        for z in (.44, .70):
            art.ring(f'Seed receiver incised tooth race {z}', (0, 0, z), 1.16, .065, 'bone', segments=24)
        for i in range(15):
            a = i * math.tau / 15
            art.box(f'Seed exposed gear tooth {i}', (1.15 * math.cos(a), 1.15 * math.sin(a), .70), (.13, .13, .17), 'bone', .01)
    with assembly('Nine tilted oval growth cradles and radial seats'):
        from mathutils import Matrix
        for i in range(9):
            a = i * math.tau / 9
            before = set(bpy.context.scene.objects)
            pod(f'Seed independent growth cradle {i}', 0, 0, 0, .29, 1.75, 'skin')
            transform = Matrix.Translation((1.51 * math.cos(a), 1.25 * math.sin(a), 1.13)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(.49, 4, 'Y')
            bpy.context.view_layer.update()
            for obj in set(bpy.context.scene.objects) - before:
                obj.matrix_world = transform @ obj.matrix_world
            bend(f'Seed articulated cradle heel {i}', [(.55 * math.cos(a), .55 * math.sin(a), .42),
                 (1.75 * math.cos(a), 1.42 * math.sin(a), .45), (2.21 * math.cos(a), 1.81 * math.sin(a), 1.17),
                 (1.51 * math.cos(a), 1.25 * math.sin(a), 1.22)], .10, 'bone', 6, 10)
    with assembly('Inner seed calibration orbits and exposed developing axis'):
        art.ring('Seed inner inclined calibration ring', (0, 0, 1.57), .91, .055, 'steel', 'XZ', 24)
        art.ring('Seed upper horizontal sorting ring', (0, 0, 1.80), 1.10, .047, 'bone', segments=24)
        pod('Seed small axial forming organism', 0, 0, .83, .25, 1.79, 'scar')
    with assembly('Articulated root distribution under the bowl'):
        for i in range(7):
            a = i * math.tau / 7
            bend(f'Seed low branching nutrient return {i}', [(.13, .08, .41), (.72 * math.cos(a), .65 * math.sin(a), .35),
                 (2.24 * math.cos(a), 1.85 * math.sin(a), .32), (2.59 * math.cos(a), 2.0 * math.sin(a), .29)],
                 (.085, .026), 'skin', 6, 10)
        dial('Seed orrery sorting regulator', (0, -1.68, .77), .20)


def nursery_bound_gate():
    with assembly('Incubation threshold rooted piers and curved beams'):
        for side in (-1, 1):
            art.box(f'Incubation rooted pier shoe {side}', (side * 1.85, .2, .14), (.76, 1.34, .28), 'iron', .025)
            bend(f'Incubation live bone pier {side}', [(side * 1.85, .2, .28), (side * 1.67, .26, 2.61),
                 (side * 1.94, .21, 4.63), (side * 1.83, .2, 6.53)], .19, 'bone', 8, 14)
            for j in range(2):
                bend(f'Incubation folded beam {side} {j}', [(0, .16, 6.04 + j * .64), (side * 1.24, .16, 6.04 + j * .64),
                     (side * 2.58, .16, 6.21 + j * .64), (side * 3.14, .16, 6.51 + j * .64)], .13, 'bone', 8, 11)
    with assembly('Two large freely hung oval incubation pods'):
        for side in (-1, 1):
            pod(f'Incubation lateral large pod {side}', side * 2.57, .19, 1.35, .53, 2.72, 'skin')
            bend(f'Incubation suspension stem {side}', [(side * 2.57, .19, 4.07), (side * 2.63, .37, 4.54),
                 (side * 2.54, .30, 5.23), (side * 2.60, .16, 6.33)], .048, 'steel', 6, 10)
    with assembly('Bound root braid and hanging short tissue slips'):
        for j in range(3):
            bend(f'Incubation braided nutrient knot {j}', [(-1.85, -.11, 5.71), (-.87, -.23, 5.03 - j * .13),
                 (.87, -.23, 5.03 - j * .13), (1.85, -.11, 5.71)], .09, 'skin', 6, 12)
        for j in range(5):
            art.tube(f'Incubation short hanging slip {j}', [((j - 2) * .49, -.15, 5.13), ((j - 2) * .47, -.13, 4.51)], [.07, .018], 'scar', 5)
    with assembly('Posterior growth supports and two low regulators'):
        for side in (-1, 1):
            bend(f'Incubation hind growth brace {side}', [(side * 2.11, .89, .24), (side * 2.23, .92, 2.67),
                 (side * 1.99, .72, 4.36), (side * 1.86, .46, 5.63)], .09, 'steel', 6, 12)
            dial(f'Incubation transfer gate regulator {side}', (side * 1.85, -.70, .68), .18)


def nursery_cell_canopy():
    with assembly('Canopy rooted nutrient trunk and spread heel anatomy'):
        footing('Incubation canopy', 5.70, 4.55)
        for i in range(7):
            a = i * math.tau / 7
            bend(f'Canopy thick nutrient root {i}', [(2.50 * math.cos(a), 1.98 * math.sin(a), .26),
                 (1.58 * math.cos(a), 1.21 * math.sin(a), .31), (.51 * math.cos(a), .45 * math.sin(a), 1.84),
                 (.22 * math.cos(a), .22 * math.sin(a), 3.55)], .12, 'skin', 6, 12)
        shell('Canopy open narrow axial trunk', [(.49, .3), (.44, 3.98), (.27, 3.98), (.31, .3), (.49, .3)], 'iron', steps=12)
    with assembly('Flared three-dimensional cellular incubation crown'):
        from mathutils import Matrix
        for row in range(4):
            r = .82 + row * .45
            z = 3.50 + row * .91
            for i in range(8):
                a = i * math.tau / 8 + (row % 2) * math.pi / 8
                before = set(bpy.context.scene.objects)
                niche(f'Canopy radial deep cavity {row} {i}', 0, 0, 0, .70 + row * .11, 1.28, .64, 'amber')
                transform = Matrix.Translation((r * math.cos(a), r * math.sin(a), z)) @ Matrix.Rotation(a + math.pi / 2, 4, 'Z')
                bpy.context.view_layer.update()
                for obj in set(bpy.context.scene.objects) - before:
                    obj.matrix_world = transform @ obj.matrix_world
            art.ring(f'Canopy crown corbel support {row}', (0, 0, z), r, .08, 'steel', segments=24)
    with assembly('Five suspended egg capsules beneath open canopy'):
        for i in range(5):
            a = i * math.tau / 5
            x, y = 1.64 * math.cos(a), 1.45 * math.sin(a)
            pod(f'Canopy hanging developing egg {i}', x, y, 1.70, .24, 1.33, 'scar')
            art.tube(f'Canopy developing egg suspension {i}', [(x, y, 3.03), (x, y, 4.50)], .034, 'steel', 5)
    with assembly('Pointed crown stays and trunk observation ports'):
        for i in range(6):
            a = i * math.tau / 6
            bend(f'Canopy upper curved crown stay {i}', [(2.05 * math.cos(a), 2.05 * math.sin(a), 6.72),
                 (1.50 * math.cos(a), 1.50 * math.sin(a), 7.04), (.65 * math.cos(a), .65 * math.sin(a), 7.45), (0, 0, 7.65)], .065, 'bone', 6, 10)
        dial('Canopy nutrient trunk regulator', (0, -.65, 1.30), .19)


def nursery_tower_cluster():
    with assembly('Staggered gestation tower chambers and broad root base'):
        footing('Gestation towers', 5.55, 3.70)
        for i, (x, y, bottom, height) in enumerate([(-1.67, 0, .35, 3.65), (-.71, .87, 1.32, 4.85),
                                                  (.27, .07, .39, 7.15), (1.25, .98, .34, 4.67), (1.98, -.22, .27, 2.75)]):
            pod(f'Growth tower elongated chamber {i}', x, y, bottom, .33, height, 'skin')
    with assembly('Independent gothic supports and high hatching spines'):
        for x, y, top in [(-1.67, 0, 4.35), (-.71, .87, 6.58), (.27, .07, 7.90), (1.25, .98, 5.34), (1.98, -.22, 3.35)]:
            pointed_pair('Growth pointed hatching chamber ' + str(x), x, y - .17, .26, top, .48)
    with assembly('Exposed branching root feeds and axial formation ribs'):
        for i in range(8):
            x = (i - 3.5) * .60
            bend(f'Growth low interconnected feed root {i}', [(x, -.97, .27), (x * .85, -.79, .44),
                 (x * .55, .44, 1.21), (.28, .51, 2.39)], .076, 'scar', 6, 11)
        for i in range(10):
            z = 1.1 + i * .54
            art.box(f'Growth central vertebral restraint {i}', (.27, -.35, z), (.33, .14, .11), 'bone', .015)
    with assembly('Low seed-selection pipes and separate chamber gauges'):
        for side in (-1, 1):
            dial(f'Growth gestation selection {side}', (side * 1.27, -1.22, .56), .19)
            art.tube(f'Growth hatch vent {side}', [(side * 1.07, 1.29, .29), (side * 1.07, 1.29, 3.10)], .075, 'steel', 6)


def nursery_seven_vessels():
    with assembly('Delicate distributing tree and root shoes'):
        footing('Suspended growth tree', 5.85, 3.15)
        bend('Growth tree central curving stem', [(0, .4, .26), (-.24, .4, 2.03), (.18, .37, 4.72), (0, .30, 7.02)], .10, 'bone', 6, 14)
        for side in (-1, 1):
            bend(f'Growth tree rooting tendon {side}', [(side * 2.18, .64, .24), (side * 1.03, .63, .33),
                 (side * .29, .57, 1.15), (0, .4, 1.58)], .08, 'skin', 6, 10)
    with assembly('Seven staggered freely hanging growth pods'):
        for i in range(7):
            x, y = (i - 3) * .76, .23 + .18 * (i % 2)
            z = 3.83 + .27 * abs(i - 3)
            pod(f'Growth tree suspended pod {i}', x, y, z, .24, 1.44, 'skin')
            art.tube(f'Growth tree thin pod suspension {i}', [(x, y, z + 1.44), (x, y, 6.51 - .16 * abs(i - 3))], .032, 'steel', 5)
    with assembly('Branching overhead nutrient conduits and tension strings'):
        for i in range(7):
            x = (i - 3) * .76
            top = 6.51 - .16 * abs(i - 3)
            bend(f'Growth tree long spread branch {i}', [(0, .30, 2.10 + abs(i - 3) * .25),
                 (x * .77, .56, 3.57), (x, .36, top - .62), (x, .23 + .18 * (i % 2), top)], .057, 'bone', 6, 12)
            bend(f'Growth tree top tension string {i}', [(0, .30, 7.02), (x * .29, .30, 6.58),
                 (x * .75, .33, top + .06), (x, .23, top)], .022, 'steel', 5, 9)
    with assembly('Visible root branching relief and distribution dial'):
        face('Growth tree central incomplete root face', 0, -.07, 1.46, .45)
        for i in range(5):
            art.box(f'Growth tree low sampling tap {i}', ((i - 2) * .24, -.61, .36), (.08, .27, .15), 'bone', .009)
        dial('Growth tree ratio selector', (0, -.56, .89), .16)


def nursery_winged_cradle():
    with assembly('Reclining nursery chassis and flanking narrow needles'):
        footing('Winged gestation cradle', 7.05, 4.30)
        obelisks('Winged gestation cradle', 3.05, 5.73)
    with assembly('Horizontal open cradle with exposed forming body'):
        from mathutils import Matrix
        before = set(bpy.context.scene.objects)
        pod('Winged gestation open reclining cradle', 0, 0, 0, .54, 2.98, 'skin')
        transform = Matrix.Translation((-1.49, .03, 1.25)) @ Matrix.Rotation(math.pi / 2, 4, 'Y')
        bpy.context.view_layer.update()
        for obj in set(bpy.context.scene.objects) - before:
            obj.matrix_world = transform @ obj.matrix_world
        face('Winged gestation unfinished body face', -.98, -.32, 1.44, .60)
        shell('Winged gestation low concave receiving trough', [(1.75, .53), (1.87, .78), (1.61, .85), (.61, .37),
              (.51, .26), (1.75, .53)], 'bone', aspect=(1, .55), steps=24)
    with assembly('Swept curved protective wings and separate feather tips'):
        wing_vanes('Winged gestation', (0, .68, 1.39), 3.13, 3.90, 13, swept=True)
        for side in (-1, 1):
            bend(f'Winged gestation outer curved restraint {side}', [(side * .74, .6, .42), (side * 3.01, 1.21, 1.45),
                 (side * 2.79, 1.27, 4.88), (side * 1.65, 1.05, 5.66)], (.14, .027), 'steel', 6, 14)
    with assembly('Articulated cradle heels and exposed nutrient return'):
        for side in (-1, 1):
            for y in (-.66, .75):
                art.tube(f'Winged gestation separate heel {side} {y}', [(side * 1.42, y, .24), (side * 1.0, y, 1.03)], [.16, .09], 'bone', 6)
            bend(f'Winged gestation returning root {side}', [(side * 1.06, .33, 1.75), (side * 1.76, .78, 1.08),
                 (side * 2.20, .45, .49), (side * 1.62, -.68, .29)], .07, 'skin', 6, 10)
            dial(f'Winged gestation positioning control {side}', (side * 1.72, -1.05, .56), .18)


def ossuary_rib_bridge():
    with assembly('Bridge four anatomical end supports outside the passage'):
        for side in (-1, 1):
            for y in (-2.23, 2.23):
                x = side * 1.94
                art.box(f'Bridge independent pier heel {side} {y}', (x, y, .15), (.74, .69, .30), 'iron', .025)
                shell(f'Bridge hollow femoral support {side} {y}', [(.28, .30), (.24, 3.88), (.13, 3.88), (.16, .30), (.28, .30)],
                      'bone', center=(x, y, 0), steps=12)
                face(f'Bridge pier anatomical head {side} {y}', x, y - .14, 3.93, .69)
    with assembly('Nine paired ribs over the genuine central transport passage'):
        for i in range(9):
            y = -2.15 + i * .54
            top = 5.80 + .65 * math.sin(i * math.pi / 8)
            for side in (-1, 1):
                bend(f'Bridge enclosing raised rib {side} {i}', [(side * 1.93, y, 2.95),
                     (side * 2.21, y, 4.91), (side * 1.24, y, top), (0, y, top)], (.14, .085), 'bone', 8, 14)
                art.tube(f'Bridge raised lateral costal brace {side} {i}', [(side * 1.94, y, 3.0),
                         (side * 1.91, y + .16, 4.39)], .074, 'steel', 6)
            art.egg(f'Bridge upper vertebral knuckle {i}', (0, y, top), (.24, .19, .15), 'bone', 10, 5)
            art.tube(f'Bridge upper spinous process {i}', [(0, y, top), (.02, y + .12, top + .55)], [.10, .007], 'bone', 6)
    with assembly('Longitudinal spine and paired transport-side rails'):
        art.tube('Bridge overhead longitudinal spine', [(0, -2.25, 5.85), (0, -1.10, 6.20), (0, 0, 6.48),
                 (0, 1.10, 6.20), (0, 2.25, 5.85)], .11, 'steel', 8)
        for side in (-1, 1):
            art.tube(f'Bridge raised exterior longitudinal rail {side}', [(side * 1.94, -2.40, 1.05), (side * 1.94, 2.40, 1.05)], .065, 'bone', 6)
            for i in range(7):
                art.tube(f'Bridge side rail upright {side} {i}', [(side * 1.94, -1.95 + i * .65, .24),
                         (side * 1.94, -1.95 + i * .65, 1.05)], .038, 'steel', 5)
    with assembly('Lateral marrow-return anatomy and pier regulators'):
        for side in (-1, 1):
            bend(f'Bridge outer return tendon {side}', [(side * 1.92, -2.22, .3), (side * 2.36, -.94, 2.0),
                 (side * 2.34, 1.1, 2.80), (side * 1.92, 2.22, 3.51)], .08, 'skin', 6, 12)
            dial(f'Bridge marrow transfer control {side}', (side * 1.94, -2.59, .63), .17)
        # No deck, central shoe or anatomy occupies |x| < 1.12 below z=2.6.
        # Parent authors the actual walkable floor and traversal collision.


def ossuary_bone_mandala():
    with assembly('Mandala low radial skeletal ground support'):
        footing('Bone sorting mandala', 5.85, 5.30)
        for i in range(8):
            a = i * math.tau / 8
            bend(f'Mandala arched supporting leg {i}', [(2.53 * math.cos(a), 2.20 * math.sin(a), .25),
                 (2.64 * math.cos(a), 2.28 * math.sin(a), .51), (1.89 * math.cos(a), 1.68 * math.sin(a), 1.27),
                 (1.76 * math.cos(a), 1.61 * math.sin(a), 1.61)], .13, 'bone', 6, 11)
    with assembly('Broad horizontal bone annulus and exposed radial ribs'):
        for r, z in ((2.40, 1.58), (1.73, 1.59), (.62, 1.60)):
            art.ring(f'Mandala separate skeletal sorting race {r}', (0, 0, z), r, .12 if r > 1 else .06, 'bone', segments=32)
        for i in range(12):
            a = i * math.tau / 12
            art.tube(f'Mandala exposed radial sorting rib {i}', [(.60 * math.cos(a), .60 * math.sin(a), 1.60),
                     (1.15 * math.cos(a), 1.15 * math.sin(a), 1.73), (2.38 * math.cos(a), 2.38 * math.sin(a), 1.61)], [.065, .095, .11], 'bone', 6)
            face(f'Mandala indexed skull {i}', 2.33 * math.cos(a), 2.33 * math.sin(a) - .09, 1.70, .50)
    with assembly('Open central marrow spindle and segmented tower'):
        shell('Mandala hollow marrow spindle', [(.29, .29), (.28, 4.57), (.15, 4.57), (.17, .29), (.29, .29)], 'steel', steps=16)
        for i in range(9):
            z = 1.82 + i * .27
            art.ring(f'Mandala central spinal flange {i}', (0, 0, z), .34, .069, 'bone', segments=12)
            art.tube(f'Mandala spinal marrow seam {i}', [(0, -.23, z), (0, -.23, z + .13)], .026, 'amber', 5)
    with assembly('Four skeletal balance cages and hanging sorting loops'):
        for i in range(4):
            a = i * math.tau / 4 + math.pi / 4
            x, y = 1.64 * math.cos(a), 1.64 * math.sin(a)
            pod(f'Mandala empty balance cage {i}', x, y, 2.50, .20, 1.27, None)
            art.tube(f'Mandala balance arm {i}', [(0, 0, 4.13), (x, y, 4.13), (x, y, 3.77)], .046, 'steel', 5)
        dial('Mandala recovered-bone sorter', (0, -1.09, .61), .21)


def ossuary_bound_gate():
    with assembly('Rooted skeletal threshold and heavy open piers'):
        for side in (-1, 1):
            art.box(f'Bone threshold grounded root foot {side}', (side * 1.78, .24, .14), (.80, 1.61, .28), 'iron', .025)
            art.tube(f'Bone threshold thick articulated pier {side}', [(side * 1.78, .24, .28), (side * 1.68, .24, 2.12),
                     (side * 1.89, .24, 3.73), (side * 1.78, .24, 5.92)], [.23, .27, .20, .21], 'bone', 8)
            for i in range(8):
                art.ring(f'Bone threshold pier vertebra {side} {i}', (side * 1.78, .24, .79 + i * .58), .26, .056, 'steel', segments=12)
    with assembly('Double curved bone lintels and anatomical binding'):
        for side in (-1, 1):
            for j in range(2):
                bend(f'Bone threshold heavy carved beam {side} {j}', [(0, .24, 5.63 + j * .56), (side * 1.19, .24, 5.59 + j * .56),
                     (side * 2.40, .24, 5.77 + j * .56), (side * 2.93, .24, 6.14 + j * .56)], .16, 'bone', 8, 10)
        bend('Bone threshold deep binding tendon', [(-1.78, -.1, 5.2), (-.76, -.24, 4.53), (.76, -.24, 4.53), (1.78, -.1, 5.2)], .105, 'skin', 6, 14)
        face('Bone threshold central bound clamp', 0, -.31, 4.94, .50)
    with assembly('Two genuinely empty suspended weighing cages'):
        for side in (-1, 1):
            pod(f'Bone threshold empty weighing cage {side}', side * 2.50, .22, 2.0, .33, 1.64, None)
            art.tube(f'Bone threshold weighing cage chain {side}', [(side * 2.50, .22, 3.64), (side * 2.50, .22, 5.93)], .04, 'steel', 5)
    with assembly('Rooted pier anatomy and weighing-control shoes'):
        for side in (-1, 1):
            for j in range(3):
                bend(f'Bone threshold spreading tendon toe {side} {j}', [(side * 1.78, .26, 1.40),
                     (side * (1.80 + j * .14), .35, .62), (side * (2.19 + j * .17), .47, .41),
                     (side * (2.24 + j * .19), .50, .29)], .056, 'bone', 5, 9)
            dial(f'Bone threshold weighing regulator {side}', (side * 1.78, -.69, .63), .18)


def ossuary_cell_archive():
    with assembly('Archive offset ground feet and branching open retrieval piers'):
        footing('Bone archive', 5.95, 2.30)
        pointed_pair('Archive central retrieval void', 0, -.29, .25, 3.36, .76)
        for side in (-1, 1):
            bend(f'Archive forked exterior retrieval pier {side}', [(side * 2.51, .30, .25), (side * 2.85, .47, 3.01),
                 (side * 2.63, .56, 5.39), (side * 2.23, .48, 7.58)], .13, 'bone', 6, 14)
    with assembly('Staggered irregular skeletal storage cavities'):
        for col in range(5):
            x = (col - 2) * 1.02
            for row in range(5 + col % 2):
                z = .90 + row * 1.20 + .22 * (col % 2)
                if abs(x) < .4 and row < 2:
                    continue
                niche(f'Archive deep skeletal niche {col} {row}', x, -.03 + .13 * (col % 2), z, .91, 1.40, .98, None)
                for j in range(3):
                    art.tube(f'Archive exposed stored bone {col} {row} {j}', [(x - .22 + j * .16, .49, z - .28),
                             (x - .13 + j * .13, .54, z + .18)], [.035, .023], 'bone', 5)
    with assembly('Carved retrieval guardians and branching rib relief'):
        for side in (-1, 1):
            witness(f'Archive carved skeletal keeper {side}', side * 1.23, -.25, 1.32, .54)
            for row in range(5):
                z = 1.23 + row * 1.12
                bend(f'Archive irregular costal edge relief {side} {row}', [(side * 2.4, .43, z), (side * 2.73, .20, z + .26),
                     (side * 2.41, -.12, z + .39), (side * 2.11, -.17, z + .45)], .046, 'steel', 5, 8)
    with assembly('Rear bone-return tree and lower registry gauges'):
        for side in (-1, 1):
            bend(f'Archive posterior return branch {side}', [(side * .12, .93, 6.58), (side * 1.87, .99, 5.02),
                 (side * 1.73, .91, 2.13), (side * .67, .79, .34)], .09, 'skin', 6, 13)
            dial(f'Archive bone registry control {side}', (side * 1.93, -.84, .62), .17)


def ossuary_tower_cluster():
    with assembly('Three linked marrow towers on independent bone platforms'):
        footing('Ossuary tower cluster', 6.40, 3.40)
        for i, (x, y, tiers) in enumerate([(-1.99, .08, 4), (0, .78, 6), (1.99, .08, 4)]):
            tower(f'Ossuary segmented marrow tower {i}', x, y, .34, tiers, .95, 1.00, 'amber')
    with assembly('Exposed elevated skeletal transfer braces'):
        for side in (-1, 1):
            bend(f'Ossuary lower exposed transfer brace {side}', [(side * 2.0, .51, 2.11),
                 (side * 1.37, .81, 2.39), (side * .59, .89, 2.74), (0, .86, 2.84)], .07, 'bone', 6, 10)
            bend(f'Ossuary high exposed transfer brace {side}', [(side * 2.0, .53, 4.16),
                 (side * 1.31, .70, 4.63), (side * .62, .83, 5.03), (0, .89, 5.24)], .065, 'steel', 6, 10)
    with assembly('Skull inspection relief and open tower roots'):
        for side in (-1, 1):
            face(f'Ossuary tower root carved skull {side}', side * 1.99, -.66, 1.03, .56)
            bend(f'Ossuary lateral bone root {side}', [(side * 2.62, .55, .25), (side * 2.68, .62, 1.26),
                 (side * 2.13, .63, 2.45), (side * 1.99, .57, 3.59)], .10, 'bone', 6, 12)
    with assembly('Rear marrow return anatomy and selector gauges'):
        for side in (-1, 1):
            bend(f'Ossuary exposed rear marrow return {side}', [(side * .38, .99, 5.98), (side * 1.17, 1.08, 4.6),
                 (side * 2.21, 1.06, 1.63), (side * 2.39, .97, .3)], .08, 'skin', 6, 13)
            dial(f'Ossuary tower marrow selector {side}', (side * 1.25, -1.08, .57), .18)


def ossuary_seven_reservoirs():
    with assembly('Heavy recovered-marrow root manifold and jointed pelvis'):
        footing('Marrow reservoirs', 6.25, 2.85)
        shell('Marrow manifold open thick central bearing', [(.44, .26), (.52, 1.25), (.33, 1.53), (.20, 1.45),
              (.30, 1.21), (.29, .26), (.44, .26)], 'steel', steps=16)
        for side in (-1, 1):
            bend(f'Marrow manifold weight-bearing heel {side}', [(side * 2.49, .54, .25), (side * 2.09, .70, 1.09),
                 (side * .73, .61, 1.90), (0, .35, 2.29)], .15, 'bone', 8, 12)
    with assembly('Seven ossified closed-back marrow reservoirs'):
        for i in range(7):
            x, z = (i - 3) * .80, 3.58 + .15 * (i % 2)
            pod(f'Marrow recovered reservoir {i}', x, .21, z, .27, 2.18, 'scar')
            for j in range(5):
                art.ring(f'Marrow reservoir vertebral armor {i} {j}', (x, .21, z + .28 + j * .35), .29, .032, 'bone', segments=12)
    with assembly('Seven thick branched marrow pipelines and articulated joints'):
        for i in range(7):
            x, z = (i - 3) * .80, 3.58 + .15 * (i % 2)
            bend(f'Marrow heavy distribution branch {i}', [((i - 3) * .09, .35, 1.0), (x * .74, .52, 1.86),
                 (x * 1.06, .31, 2.71), (x, .21, z)], .12, 'bone', 8, 12)
            art.ring(f'Marrow pipeline elbow joint {i}', (x * .75, .45, 2.1), .17, .04, 'steel', 'XZ', 12)
    with assembly('Carved marrow reading face and low independent taps'):
        face('Marrow root reader', 0, -.29, 1.42, .68)
        for i in range(7):
            art.box(f'Marrow recovered fraction tap {i}', ((i - 3) * .25, -.74, .38), (.09, .35, .15), 'bone', .01)
        for side in (-1, 1):
            dial(f'Marrow reservoir fraction gauge {side}', (side * 1.56, -.91, .61), .19)


def ossuary_winged_sarcophagus():
    with assembly('Steep-standing sarcophagus restraint bed and four needles'):
        footing('Ossuary winged sarcophagus', 6.90, 3.15)
        obelisks('Ossuary winged sarcophagus', 2.98, 6.79)
    with assembly('Upright deep bone casket and exposed inner skeleton'):
        pod('Ossuary upright open sarcophagus', 0, .38, .65, .48, 5.30, None)
        witness('Ossuary preserved carved body', 0, .05, 3.54, 1.33)
        pointed_pair('Ossuary steep casket rim', 0, -.10, .46, 6.54, .65)
    with assembly('Steep spread feather buttresses and wing-root bones'):
        wing_vanes('Ossuary steep winged sarcophagus', (0, .57, 1.42), 2.57, 5.06, 13)
        for side in (-1, 1):
            bend(f'Ossuary elevated wing root {side}', [(side * .32, .8, .31), (side * 1.92, .85, 1.29),
                 (side * 2.20, .72, 4.64), (side * 1.72, .56, 6.70)], (.13, .033), 'steel', 6, 14)
    with assembly('Independent low casket clamps and skeletal return lines'):
        for side in (-1, 1):
            bend(f'Ossuary lower skeletal return line {side}', [(side * .31, .58, 4.93), (side * 1.02, 1.12, 2.77),
                 (side * 1.22, 1.17, 1.03), (side * .70, .78, .29)], .07, 'skin', 6, 12)
            dial(f'Ossuary final casket clamp control {side}', (side * 1.50, -1.0, .63), .19)


def inversion_surgical_cradle():
    with assembly('Inversion surgical ground frame and four piston shoes'):
        footing('Surgical inversion cradle', 4.95, 3.15)
        for side in (-1, 1):
            for y in (-.62, .76):
                art.tube(f'Inversion surgical lower piston {side} {y}', [(side * 1.69, y, .24), (side * 1.45, y, 2.31)], .12, 'steel', 8)
                art.ring(f'Inversion surgical piston joint {side} {y}', (side * 1.54, y, 1.27), .18, .044, 'bone', segments=12)
    with assembly('Four opposing tall bowed surgical restraint blades'):
        for side in (-1, 1):
            for y in (-.54, .71):
                bend(f'Inversion tall pointed surgical blade {side} {y}', [(side * 1.73, y, .42),
                     (side * 2.28, y, 4.92), (side * .81, y, 7.76), (side * .54, y, 8.48)], (.19, .007), 'bone', 8, 18)
                art.tube(f'Inversion blade incised rear edge {side} {y}', [(side * 1.79, y + .08, 1.58),
                         (side * 1.86, y + .08, 4.93), (side * .97, y + .08, 7.28)], .041, 'steel', 5)
    with assembly('Open body restraint and transverse articulated surgery arms'):
        pod('Inversion open restrained surgical body', 0, .13, 1.87, .42, 4.63, 'scar')
        for z in (3.22, 4.73):
            art.tube(f'Inversion transverse surgical clamp {z}', [(-1.49, -.13, z), (1.49, -.13, z)], .074, 'steel', 6)
            for side in (-1, 1):
                bend(f'Inversion curved articulated clamp jaw {side} {z}', [(side * 1.49, -.13, z), (side * .68, -.73, z + .20),
                     (side * .34, -.80, z + .07), (side * .18, -.43, z)], .065, 'bone', 6, 9)
        face('Inversion reversed carved surgical face', 0, -.09, 5.95, .57)
    with assembly('Paired orientation-return tendons and surgical controls'):
        for side in (-1, 1):
            bend(f'Inversion long returning surgical tendon {side}', [(side * .28, .37, 6.93), (side * .78, 1.04, 4.97),
                 (side * 1.11, .93, 2.47), (side * .74, .64, .32)], .07, 'skin', 6, 14)
            dial(f'Inversion body-angle selector {side}', (side * 1.22, -.91, .58), .19)


def inversion_tilted_gyroscope():
    with assembly('Gyroscope four separated feet and diagonal axis bearings'):
        footing('Inversion gyroscope', 5.95, 5.20)
        for side in (-1, 1):
            for y in (-1.28, 1.28):
                bend(f'Gyroscope diagonal foot {side} {y}', [(side * 2.40, y, .24), (side * 2.21, y, .72),
                     (side * 1.93, y * .74, 1.54), (side * 1.56, y * .52, 2.31)], .12, 'bone', 8, 11)
        art.tube('Gyroscope visible tilted drive axis', [(-1.97, .36, 1.76), (1.95, -.36, 5.75)], .075, 'steel', 8)
    with assembly('Three genuinely tilted thick orbital races'):
        from mathutils import Matrix
        for i, (r, angle, axis) in enumerate([(2.42, .37, 'Y'), (2.22, .72, 'X'), (2.08, -.48, 'Y')]):
            before = set(bpy.context.scene.objects)
            art.ring(f'Gyroscope independent thick orbital race {i}', (0, 0, 0), r, .13 if i == 0 else .095, 'steel' if i != 1 else 'bone', 'XZ', 40)
            for j in range(8):
                a = j * math.tau / 8
                art.egg(f'Gyroscope orbital bearing lug {i} {j}', (r * math.cos(a), 0, r * math.sin(a)), (.15, .12, .14), 'bone', 10, 5)
            transform = Matrix.Translation((0, 0, 3.57)) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Rotation(i * .41, 4, 'Z')
            bpy.context.view_layer.update()
            for obj in set(bpy.context.scene.objects) - before:
                obj.matrix_world = transform @ obj.matrix_world
    with assembly('Suspended lotus cradle within open gyroscopic volume'):
        shell('Gyroscope suspended concave receiving bowl', [(1.08, 2.70), (1.21, 2.95), (.88, 2.89), (.21, 2.16),
              (.16, 2.05), (1.08, 2.70)], 'bone', steps=20)
        for i in range(8):
            a = i * math.tau / 8
            verts, faces = thermal.slag_petal(a)
            art.mesh(f'Gyroscope suspended split lotus clamp {i}', [(x * .64, y * .64, z * .51 + 1.69) for x, y, z in verts], faces, 'bone')
            art.tube(f'Gyroscope independent cradle suspension {i}', [(1.39 * math.cos(a), 1.39 * math.sin(a), 3.06),
                     (.40 * math.cos(a), .40 * math.sin(a), 5.18)], .027, 'skin', 5)
        art.egg('Gyroscope orientation captive pulse', (0, 0, 3.44), (.19, .18, .28), 'amber', 12, 7)
    with assembly('Articulated rear drive and axis regulators'):
        for side in (-1, 1):
            bend(f'Gyroscope articulated rear drive {side}', [(side * 2.04, .98, .26), (side * 2.18, 1.29, 2.07),
                 (side * 1.69, 1.14, 4.26), (side * .63, .82, 5.70)], .08, 'steel', 6, 12)
            dial(f'Gyroscope orientation regulator {side}', (side * 1.56, -1.67, .65), .18)


def inversion_bound_gate():
    with assembly('Inverted threshold tall divergent piers and high beams'):
        for side in (-1, 1):
            art.box(f'Inverted threshold ground anchor {side}', (side * 1.75, .31, .14), (.77, 1.67, .28), 'iron', .03)
            art.tube(f'Inverted threshold divergent pier {side}', [(side * 1.75, .31, .28), (side * 2.01, .31, 3.72),
                     (side * 1.86, .31, 7.02)], [.20, .14, .21], 'bone', 8)
            for j in range(2):
                bend(f'Inverted threshold upward beam {side} {j}', [(0, .31, 6.77 + j * .58), (side * 1.48, .31, 6.77 + j * .58),
                     (side * 2.73, .31, 6.87 + j * .58), (side * 3.17, .31, 7.21 + j * .58)], .13, 'bone', 8, 12)
    with assembly('Two suspended orientation cages and tilted empty cells'):
        for side in (-1, 1):
            pod(f'Inverted threshold empty side cage {side}', side * 2.50, .26, 1.31, .35, 2.15, None)
            art.tube(f'Inverted threshold cage tension stem {side}', [(side * 2.50, .26, 3.46), (side * 2.50, .26, 6.95)], .042, 'steel', 5)
    with assembly('Sagging tissue sheets above the clear central threshold'):
        for side in (-1, 1):
            verts, faces = thermal.curtain_leaf(side * 1.0, 5.70, 1.51)
            art.mesh(f'Inverted threshold folded side membrane {side}', verts, faces, 'skin')
        for j in range(3):
            bend(f'Inverted threshold deeply bound tendon {j}', [(-1.87, .03, 6.15), (-.61, -.06, 5.35 - j * .16),
                 (.61, -.06, 5.35 - j * .16), (1.87, .03, 6.15)], .073, 'scar', 6, 14)
    with assembly('Divergent pier vertebrae and low orientation gauges'):
        for side in (-1, 1):
            for z in (1.2, 2.8, 4.5, 6.2):
                art.ring(f'Inverted threshold pier vertebra {side} {z}', (side * (1.80 if z < 3 else 1.92), .31, z), .24, .05, 'steel', segments=12)
            dial(f'Inverted threshold transfer control {side}', (side * 1.75, -.61, .68), .18)


def inversion_cell_prism():
    with assembly('Cell prism slender axial support and spread ground heels'):
        footing('Inverted cell prism', 3.90, 3.40)
        shell('Cell prism open central transfer axis', [(.15, .24), (.15, 8.65), (.08, 8.65), (.08, .24), (.15, .24)], 'steel', steps=12)
        for side in (-1, 1):
            bend(f'Cell prism grounded heel brace {side}', [(side * 1.42, .44, .24), (side * .91, .61, .49),
                 (side * .40, .52, 1.15), (0, .27, 1.70)], .08, 'bone', 6, 10)
    with assembly('Double-ended radial cellular prism with deep recesses'):
        from mathutils import Matrix
        for half in (-1, 1):
            for row in range(3):
                r, z = 1.18 - row * .34, 4.20 + half * row * 1.17
                for i in range(6):
                    a = i * math.tau / 6
                    before = set(bpy.context.scene.objects)
                    niche(f'Cell prism independent radial pocket {half} {row} {i}', 0, 0, 0, .90 - row * .16, 1.34, .65)
                    transform = Matrix.Translation((r * math.cos(a), r * math.sin(a), z)) @ Matrix.Rotation(a + math.pi / 2, 4, 'Z')
                    if half < 0:
                        transform = transform @ Matrix.Rotation(math.pi, 4, 'Y')
                    bpy.context.view_layer.update()
                    for obj in set(bpy.context.scene.objects) - before:
                        obj.matrix_world = transform @ obj.matrix_world
                art.ring(f'Cell prism exposed corbel bearing {half} {row}', (0, 0, z), r, .064, 'steel', segments=24)
    with assembly('Opposed tapered crown stays and skeletal transfer tips'):
        for side in (-1, 1):
            for half in (-1, 1):
                bend(f'Cell prism tapered crown restraint {side} {half}', [(side * 1.52, .18, 4.22),
                     (side * 1.51, .18, 4.22 + half * 1.83), (side * .42, .18, 4.22 + half * 3.48),
                     (0, .18, 4.22 + half * 3.91)], .06, 'bone', 6, 13)
    with assembly('Exposed inverted return cables and low cell controls'):
        for side in (-1, 1):
            bend(f'Cell prism exposed rear cable {side}', [(side * .12, .27, 7.85), (side * 1.27, .70, 5.19),
                 (side * .77, .73, 2.24), (side * .24, .43, .3)], .042, 'skin', 5, 13)
            dial(f'Cell prism lower axis gauge {side}', (side * .91, -.71, .57), .16)


def inversion_tower_cluster():
    with assembly('Five offset body-storage towers and split root base'):
        footing('Inversion transfer towers', 6.30, 4.55)
        for i, (x, y, bottom, tiers) in enumerate([(-2.01, .12, .33, 3), (-1.11, 1.18, 1.14, 4),
                                                  (0, .35, .38, 6), (1.19, 1.10, .73, 4), (2.11, -.04, .31, 3)]):
            tower(f'Inversion offset transfer tower {i}', x, y, bottom, tiers, .74, .97, 'scar')
    with assembly('Five sloping orbital transfer bridges between tower tiers'):
        for i, (x1, y1, z1, x2, y2, z2) in enumerate([(-2.0, .1, 1.90, -1.1, 1.18, 3.03),
                                                    (-1.1, 1.18, 3.03, 0, .35, 4.18),
                                                    (0, .35, 4.18, 1.19, 1.10, 3.49),
                                                    (1.19, 1.10, 3.49, 2.11, -.04, 2.31),
                                                    (2.11, -.04, 2.31, 0, .35, 1.32)]):
            for j in range(6):
                t = j / 5
                x, y, z = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z1 + (z2 - z1) * t
                obj = art.box(f'Inversion articulated ramp tread {i} {j}', (x, y, z), (.31, .48, .12), 'bone', .012)
                obj.rotation_euler.z = math.atan2(y2 - y1, x2 - x1)
            for side in (-1, 1):
                art.tube(f'Inversion inclined ramp relief rail {i} {side}', [(x1, y1 + side * .26, z1 + .15),
                         (x2, y2 + side * .26, z2 + .15)], .036, 'steel', 5)
    with assembly('Skeletal root clamps and high body-transfer returns'):
        for side in (-1, 1):
            witness(f'Inversion lower transport operator {side}', side * 1.99, -.46, 1.11, .46)
            bend(f'Inversion tower curved posterior return {side}', [(side * 2.69, .72, .25), (side * 2.86, 1.31, 2.55),
                 (side * 1.65, 1.71, 5.10), (side * .45, 1.02, 6.36)], .077, 'skin', 6, 14)
    with assembly('Low orientation-selection wheels and separate transfer shafts'):
        for side in (-1, 1):
            dial(f'Inversion ramp direction selector {side}', (side * 1.22, -1.28, .55), .18)
            art.tube(f'Inversion detached rear transfer shaft {side}', [(side * 2.63, .65, .24), (side * 2.63, .65, 4.12)], .067, 'steel', 6)


def inversion_seven_vessels():
    with assembly('Twisted low transfer root and helical anatomical trunk'):
        footing('Inverted seven vessels', 5.80, 3.10)
        for i in range(3):
            points = [(.24 * math.cos(j * .49 + i * math.tau / 3), .28 + .24 * math.sin(j * .49 + i * math.tau / 3),
                       .31 + j * .29) for j in range(13)]
            art.tube(f'Inverted helical trunk strand {i}', points, .075, 'bone' if i == 0 else 'skin', 6)
    with assembly('Seven offset upright orientation reservoirs'):
        for i in range(7):
            x, z = (i - 3) * .71, 3.45 + .32 * (3 - abs(i - 3))
            pod(f'Inverted orientation reservoir {i}', x, .16 + .18 * (i % 2), z, .24, 2.10, 'amber')
    with assembly('Twisted asymmetric distribution branches and winding returns'):
        for i in range(7):
            x, z = (i - 3) * .71, 3.45 + .32 * (3 - abs(i - 3))
            bend(f'Inverted winding distribution branch {i}', [((i - 3) * .07, .36, .80), (x * .56, .83, 2.17),
                 (x * 1.11, .50, z - .78), (x, .16 + .18 * (i % 2), z)], .085, 'bone', 6, 13)
            bend(f'Inverted opposite reservoir return {i}', [(x, .38, z + .31), (x * .88, .96, z - .30),
                 (-x * .25, .91, 1.55), ((i - 3) * .06, .66, .33)], .032, 'steel', 5, 12)
    with assembly('Separate heel anatomy and axial inversion selector'):
        for side in (-1, 1):
            bend(f'Inverted tree spread heel {side}', [(side * 2.32, .7, .24), (side * 1.15, .65, .35),
                 (side * .52, .52, 1.20), (0, .41, 1.57)], .11, 'steel', 6, 10)
            dial(f'Inverted tree phase selector {side}', (side * 1.20, -.84, .59), .18)
        face('Inverted axial reader face', 0, -.13, 1.80, .46)


def inversion_winged_cradle():
    with assembly('Tall opposed restraint chassis and split vertical feet'):
        footing('Inversion wing cradle', 6.45, 3.0)
        for side in (-1, 1):
            art.tube(f'Inversion wing outer broken blade {side}', [(side * 2.69, .22, .24), (side * 2.52, .22, 6.87),
                     (side * 2.06, .22, 8.36)], [.27, .17, .010], 'bone', 4)
            for i in range(8):
                art.box(f'Inversion outer blade incised seam {side} {i}', (side * 2.63, -.02, .87 + i * .64), (.13, .10, .11), 'steel', .013)
    with assembly('Vertical open inverted body cell and opposed clamps'):
        pod('Inversion wing open upright cell', 0, .24, 1.08, .47, 5.45, 'scar')
        for z in (1.76, 5.85):
            for side in (-1, 1):
                bend(f'Inversion wing opposed body clamp {side} {z}', [(side * 2.35, .3, z), (side * 1.12, -.06, z + .12),
                     (side * .71, -.28, z + .21), (side * .42, -.20, z)], .083, 'steel', 6, 10)
        face('Inversion wing captive identity face', 0, -.10, 5.67, .62)
    with assembly('Tall wing vanes and split dorsal feather supports'):
        wing_vanes('Inversion vertical restraint', (0, .61, 1.01), 2.85, 6.39, 14)
        for side in (-1, 1):
            bend(f'Inversion dorsal feather edge {side}', [(side * .56, .87, .35), (side * 2.54, .94, 2.89),
                 (side * 2.35, .85, 6.98), (side * 1.02, .67, 7.90)], .07, 'steel', 6, 14)
    with assembly('Orientation cables and low opposed restraint gauges'):
        for side in (-1, 1):
            bend(f'Inversion wing returning cable {side}', [(side * .24, .48, 6.68), (side * 1.54, 1.11, 4.67),
                 (side * 1.59, .97, 1.32), (side * .68, .59, .29)], .058, 'skin', 6, 13)
            dial(f'Inversion wing restraint ratio {side}', (side * 1.18, -.96, .61), .18)


def pulse_organ(name, x, y, z, scale):
    for i, (dx, dy, dz, rx, ry, rz) in enumerate([(-.22, 0, .12, .43, .31, .59), (.28, -.04, .02, .46, .34, .68),
                                                (-.28, .03, .55, .30, .29, .32), (.22, .06, .60, .30, .28, .31)]):
        art.egg(name + f' independently modeled pulse lobe {i}', (x + dx * scale, y + dy * scale, z + dz * scale),
                (rx * scale, ry * scale, rz * scale), 'skin', 14, 8)
    for side in (-1, 1):
        bend(name + f' raised coronary artery {side}', [(x + side * .28 * scale, y - .32 * scale, z - .47 * scale),
             (x + side * .50 * scale, y - .39 * scale, z + .02 * scale),
             (x + side * .35 * scale, y - .33 * scale, z + .62 * scale),
             (x + side * .06 * scale, y - .27 * scale, z + .77 * scale)], .036 * scale, 'scar', 5, 9)
        bend(name + f' curved exposed upper pulse outlet {side}', [(x + side * .18 * scale, y + .02 * scale, z + .61 * scale),
             (x + side * .24 * scale, y + .03 * scale, z + 1.11 * scale),
             (x + side * .50 * scale, y + .13 * scale, z + 1.01 * scale),
             (x + side * .48 * scale, y + .13 * scale, z + .78 * scale)], .085 * scale, 'skin', 6, 10)


def heart_mouth_restraint():
    with assembly('Mouth restraint broad ground chassis and pointed arch'):
        footing('Controller mouth', 7.35, 4.80)
        pointed_pair('Controller mouth exterior gothic restraint', 0, .04, .24, 8.18, 2.46)
        for side in (-1, 1):
            art.tube(f'Mouth main load pier {side}', [(side * 2.58, .31, .24), (side * 2.61, .31, 6.0)], .16, 'steel', 8)
            for i in range(9):
                art.box(f'Mouth pier anatomical lock {side} {i}', (side * 2.57, -.02, .76 + i * .55), (.36, .13, .12), 'bone', .014)
    with assembly('Deep open mouth annulus and recessed rear tissue throat'):
        mouth = shell('Controller mouth thick flared open annulus', [(2.11, 1.82), (2.28, 1.47), (1.99, .61), (1.60, .1),
                      (1.23, .1), (1.71, .65), (1.94, 1.50), (1.87, 1.82), (2.11, 1.82)], 'skin', steps=40)
        mouth.rotation_euler.x, mouth.location = math.pi / 2, (0, .71, 3.83)
        rear = shell('Controller mouth narrowing hollow rear throat', [(1.62, 0), (1.39, -.38), (.67, -.86), (.57, -.86),
                     (1.23, -.38), (1.44, 0), (1.62, 0)], 'scar', steps=32)
        rear.rotation_euler.x, rear.location = math.pi / 2, (0, .80, 3.83)
        for y, r in ((-1.16, 2.15), (-.68, 2.22), (.69, 1.58)):
            art.ring(f'Mouth independent annular cartilage restraint {y}', (0, y, 3.83), r, .10, 'bone', 'XZ', 40)
    with assembly('Thirty separate fangs and engraved jaw-root cartilage'):
        for i in range(30):
            a = i * math.tau / 30
            c, s = math.cos(a), math.sin(a)
            art.tube(f'Mouth articulated individual tooth {i}', [(1.96 * c, -1.10, 3.83 + 1.96 * s),
                     (1.70 * c, -1.22, 3.83 + 1.70 * s), (1.40 * c, -1.08, 3.83 + 1.40 * s)], [.092, .077, .005], 'bone', 6)
            art.egg(f'Mouth separate raised fang root {i}', (2.15 * c, -1.04, 3.83 + 2.15 * s), (.115, .095, .12), 'scar', 10, 5)
    with assembly('Flayed lateral mouth vanes and rear pressure returns'):
        for side in (-1, 1):
            for i in range(3):
                verts, faces = thermal.curtain_leaf(side * (2.79 + i * .25), 6.17 + i * .34, 2.64 + i * .25)
                art.mesh(f'Mouth thick lateral flayed vane {side} {i}', verts, faces, 'skin')
            bend(f'Mouth outer tissue-wing tension stay {side}', [(side * 2.72, .42, .27), (side * 3.61, .54, 2.55),
                 (side * 3.52, .51, 5.19), (side * 3.18, .46, 6.92)], .09, 'steel', 6, 14)
            bend(f'Mouth posterior returning artery {side}', [(side * .93, 1.13, 5.10), (side * 1.80, 1.62, 4.14),
                 (side * 2.33, 1.54, 1.97), (side * 1.48, .90, .31)], .105, 'skin', 8, 12)
            dial(f'Mouth restraint release regulator {side}', (side * 1.86, -1.50, .60), .20)


def heart_pulse_mandala():
    with assembly('Pulse mandala radial ground ring and split receiving basin'):
        footing('Pulse mandala', 6.40, 5.20)
        shell('Pulse deep radial receiver', [(2.11, 1.21), (2.18, 1.43), (1.85, 1.49), (.57, .53), (.44, .3),
              (2.11, 1.21)], 'steel', steps=24)
        for i in range(8):
            a = i * math.tau / 8
            art.tube(f'Pulse exposed receiver radial clamp {i}', [(.48 * math.cos(a), .48 * math.sin(a), .45),
                     (2.52 * math.cos(a), 2.02 * math.sin(a), .29)], [.14, .08], 'bone', 6)
    with assembly('Eight separated thick pulse petals and lobe-clear openings'):
        for i in range(8):
            a = i * math.tau / 8
            verts, faces = thermal.slag_petal(a)
            art.mesh(f'Pulse separate articulated petal clamp {i}', [(x * 1.25, y * 1.02, z * 1.13 + .09) for x, y, z in verts], faces, 'bone')
            art.egg(f'Pulse separate petal hinge {i}', (1.63 * math.cos(a), 1.47 * math.sin(a), 1.3), (.19, .16, .17), 'steel', 10, 5)
    with assembly('Exposed lobed pulse organ and hollow upper control hood'):
        pulse_organ('Pulse mandala central organ', 0, -.01, 2.72, 1.45)
        shell('Pulse mandala hollow upper regulator hood', [(.50, 4.22), (.58, 4.61), (.32, 5.28), (.21, 5.28),
              (.42, 4.61), (.35, 4.22), (.50, 4.22)], 'bone', steps=16)
        art.tube('Pulse mandala hood axial control', [(0, .06, 5.15), (0, .06, 5.71)], [.085, .006], 'steel', 6)
    with assembly('Radial coronary feeds and independent low pulse dials'):
        for i in range(6):
            a = i * math.tau / 6
            bend(f'Pulse radial coronary feeder {i}', [(.36 * math.cos(a), .36 * math.sin(a), 3.26),
                 (1.46 * math.cos(a), 1.20 * math.sin(a), 2.43), (1.90 * math.cos(a), 1.72 * math.sin(a), .68),
                 (2.60 * math.cos(a), 2.08 * math.sin(a), .31)], .075, 'skin', 6, 12)
        for side in (-1, 1):
            dial(f'Pulse mandala regulating dial {side}', (side * 1.59, -1.60, .67), .19)


def heart_bound_gate():
    with assembly('Arterial threshold vertebral piers and double beams'):
        for side in (-1, 1):
            art.box(f'Arterial threshold rooted pier foot {side}', (side * 1.82, .34, .14), (.8, 1.71, .28), 'iron', .025)
            art.tube(f'Arterial threshold spinal axis {side}', [(side * 1.82, .34, .28), (side * 1.82, .34, 6.34)], .13, 'steel', 8)
            for i in range(12):
                art.egg(f'Arterial threshold individual vertebra {side} {i}', (side * 1.82, .34, .66 + i * .43), (.25, .20, .14), 'bone', 10, 5)
                art.tube(f'Arterial threshold lateral process {side} {i}', [(side * 1.82, .34, .72 + i * .43),
                         (side * 2.13, .36, .74 + i * .43)], [.075, .025], 'bone', 5)
            for j in range(2):
                bend(f'Arterial threshold curved lintel {side} {j}', [(0, .34, 6.05 + j * .59), (side * 1.26, .34, 6.02 + j * .59),
                     (side * 2.72, .34, 6.16 + j * .59), (side * 3.16, .34, 6.48 + j * .59)], .13, 'bone', 8, 11)
    with assembly('Two hanging open arterial organs and external cage ribs'):
        for side in (-1, 1):
            pod(f'Arterial threshold hanging organ cage {side}', side * 2.57, .30, 2.03, .37, 1.76, None)
            pulse_organ(f'Arterial threshold hanging small organ {side}', side * 2.57, .23, 2.70, .52)
            art.tube(f'Arterial threshold suspension artery {side}', [(side * 2.57, .30, 3.79), (side * 2.57, .30, 6.33)], .052, 'skin', 6)
    with assembly('Bound pressure-transfer braid and carved tissue anchors'):
        for j in range(3):
            bend(f'Arterial threshold bound pulse braid {j}', [(-1.82, .02, 5.34), (-.62, -.1, 4.58 - j * .12),
                 (.62, -.1, 4.58 - j * .12), (1.82, .02, 5.34)], .081, 'skin', 6, 14)
        for side in (-1, 1):
            face(f'Arterial threshold tissue anchor face {side}', side * 1.82, .02, 3.59, .43)
    with assembly('Returning arteries and low threshold pressure gauges'):
        for side in (-1, 1):
            bend(f'Arterial threshold posterior return {side}', [(side * 1.82, .46, 5.34), (side * 2.43, .88, 3.63),
                 (side * 2.07, 1.01, 1.08), (side * 1.78, .74, .3)], .09, 'scar', 6, 12)
            dial(f'Arterial threshold pressure release {side}', (side * 1.82, -.60, .64), .19)


def heart_cell_crown():
    with assembly('Pulse crown four weight-bearing tissue piers and ground ring'):
        footing('Pulse cell crown', 5.65, 4.35)
        for side in (-1, 1):
            for y in (-.83, .94):
                art.tube(f'Pulse crown articulated load pier {side} {y}', [(side * 1.67, y, .24),
                         (side * 1.60, y, 3.13), (side * 1.43, y, 4.65)], [.16, .11, .13], 'bone', 8)
        pointed_pair('Pulse crown open anterior pressure portal', 0, -.91, .26, 3.81, .75)
    with assembly('Domed cellular crown of deep red pressure cavities'):
        from mathutils import Matrix
        for row, (r, z, count) in enumerate([(1.87, 2.27, 9), (1.66, 3.47, 9), (1.21, 4.63, 7), (.64, 5.67, 5)]):
            for i in range(count):
                a = i * math.tau / count + (row % 2) * .19
                before = set(bpy.context.scene.objects)
                niche(f'Pulse crown independent red pocket {row} {i}', 0, 0, 0, .92 - .08 * row, 1.35, .83, 'skin')
                transform = Matrix.Translation((r * math.cos(a), r * math.sin(a), z)) @ Matrix.Rotation(a + math.pi / 2, 4, 'Z')
                bpy.context.view_layer.update()
                for obj in set(bpy.context.scene.objects) - before:
                    obj.matrix_world = transform @ obj.matrix_world
            art.ring(f'Pulse crown dome corbel ring {row}', (0, 0, z + .21), r, .065, 'steel', segments=24)
    with assembly('Pointed dome ribs and hollow apical feed hood'):
        for i in range(6):
            a = i * math.tau / 6
            bend(f'Pulse crown domed relief rib {i}', [(2.18 * math.cos(a), 2.18 * math.sin(a), 2.11),
                 (2.48 * math.cos(a), 2.48 * math.sin(a), 4.22), (.74 * math.cos(a), .74 * math.sin(a), 6.80),
                 (0, 0, 7.12)], .075, 'bone', 6, 13)
        shell('Pulse crown hollow apical receiving throat', [(.25, 6.51), (.33, 6.99), (.20, 7.16), (.12, 7.16),
              (.19, 6.99), (.15, 6.51), (.25, 6.51)], 'steel', steps=12)
    with assembly('Coronary distribution anatomy and front sampling dials'):
        for side in (-1, 1):
            bend(f'Pulse crown arterial return root {side}', [(side * .47, .5, 5.99), (side * 1.36, 1.17, 3.19),
                 (side * 1.99, 1.34, 1.06), (side * 2.35, 1.41, .29)], .115, 'skin', 6, 14)
            dial(f'Pulse crown flow regulator {side}', (side * 1.17, -1.54, .57), .18)


def heart_tower_cluster():
    with assembly('Single stepped pulse ascent engine and radial satellite chambers'):
        footing('Heart ascent engine', 6.35, 4.85)
        tower('Heart central stepped ascent', 0, .28, .35, 6, 1.35, 1.07, 'skin')
        for i in range(5):
            a = i * math.tau / 5
            pod(f'Heart ascent radial pulse satellite {i}', 1.96 * math.cos(a), 1.74 * math.sin(a), .34,
                .30, 2.36 + .25 * (i % 2), 'skin')
    with assembly('Broad sloping arterial buttress tendons and split root anatomy'):
        for i in range(8):
            a = i * math.tau / 8
            bend(f'Heart ascent thick sloping tissue buttress {i}', [(2.72 * math.cos(a), 2.12 * math.sin(a), .27),
                 (1.87 * math.cos(a), 1.53 * math.sin(a), .59), (.72 * math.cos(a), .75 * math.sin(a), 3.41),
                 (.41 * math.cos(a), .41 * math.sin(a), 5.88)], (.17, .065), 'skin', 8, 15)
    with assembly('Independent exterior bone root splints and crown cartilage'):
        for side in (-1, 1):
            bend(f'Heart ascent split external bone splint {side}', [(side * 2.58, .74, .26), (side * 2.14, .91, 1.38),
                 (side * .94, .81, 4.29), (side * .27, .60, 6.90)], .085, 'bone', 6, 13)
        face('Heart ascent central pressure reading face', 0, -.50, 1.58, .60)
    with assembly('Exposed axial arterial feed and low ascent-control bank'):
        art.tube('Heart ascent upper pulsing feed', [(0, .81, .3), (0, .81, 6.75)], .09, 'scar', 6)
        for side in (-1, 1):
            dial(f'Heart ascent pressure selector {side}', (side * 1.39, -1.70, .58), .20)


def heart_seven_reservoirs():
    with assembly('Broad final pulse manifold and divided grounded heels'):
        footing('Final pulse reservoirs', 6.45, 3.20)
        shell('Final pulse thick hollow sternum bearing', [(.47, .26), (.52, 2.89), (.32, 3.21), (.21, 3.14),
              (.34, 2.89), (.32, .26), (.47, .26)], 'bone', steps=16)
        for side in (-1, 1):
            bend(f'Final pulse articulated heel {side}', [(side * 2.57, .68, .24), (side * 2.24, .73, 1.17),
                 (side * .82, .65, 2.03), (0, .35, 2.5)], .14, 'steel', 8, 12)
    with assembly('Seven high red pulse reservoirs with open restraint staves'):
        for i in range(7):
            x, z = (i - 3) * .78, 4.39 + .31 * (3 - abs(i - 3))
            pod(f'Final pulse independent red reservoir {i}', x, .24, z, .27, 2.12, 'skin')
            art.egg(f'Final pulse reservoir lower sampling bulb {i}', (x, .10, z + .30), (.15, .12, .17), 'scar', 10, 5)
    with assembly('Long bowed ivory branches and twin rear coronary mains'):
        for i in range(7):
            x, z = (i - 3) * .78, 4.39 + .31 * (3 - abs(i - 3))
            bend(f'Final pulse separate long branch {i}', [((i - 3) * .08, .42, 1.18), (x * .55, .56, 2.76),
                 (x * 1.10, .24, z - .95), (x, .24, z)], .117, 'bone', 8, 14)
            bend(f'Final pulse coronary reservoir return {i}', [(x, .41, z + .15), (x * .88, .98, z - .46),
                 (x * .31, .89, 1.37), ((i - 3) * .08, .70, .29)], .051, 'scar', 6, 12)
    with assembly('Carved pulse reading face and seven independent control taps'):
        face('Final pulse central marrow witness', 0, -.39, 2.38, .72)
        for i in range(7):
            art.box(f'Final pulse independent front tap {i}', ((i - 3) * .26, -.90, .44), (.10, .36, .20), 'bone', .01)
        for side in (-1, 1):
            dial(f'Final pulse reservoir selector {side}', (side * 1.53, -1.10, .62), .21)


def heart_winged_seal():
    with assembly('Final heart seal broad ground bed and restraint obelisks'):
        footing('Heart winged seal', 7.35, 3.50)
        obelisks('Heart winged seal', 3.15, 6.49)
    with assembly('Hollow winged pulse chamber and visible lobed organ'):
        pod('Heart final open pulse chamber', 0, .28, 1.47, .71, 3.30, None)
        pulse_organ('Heart final sealed pulse', 0, .11, 2.73, 1.11)
        shell('Heart final winged low cartilage bowl', [(1.33, 1.16), (1.49, 1.37), (1.21, 1.45), (.36, .62),
              (.29, .46), (1.33, 1.16)], 'bone', aspect=(1, .65), steps=24)
    with assembly('Broad horizontal final seal vanes and carved root ribs'):
        wing_vanes('Heart horizontal final seal', (0, .57, 2.10), 3.43, 2.33, 14)
        for side in (-1, 1):
            bend(f'Heart seal curved superior wing edge {side}', [(side * .56, .55, 4.66), (side * 1.87, .53, 4.49),
                 (side * 2.93, .52, 4.03), (side * 3.31, .49, 3.86)], .09, 'steel', 6, 12)
    with assembly('Descending final arteries and separate release clamps'):
        for side in (-1, 1):
            bend(f'Heart final descending return artery {side}', [(side * .33, .19, 3.50), (side * 1.06, .75, 2.83),
                 (side * 1.17, .73, 1.10), (side * .29, .20, .34)], .088, 'skin', 6, 12)
            dial(f'Heart final seal-release clamp {side}', (side * 1.78, -1.0, .62), .20)
        art.tube('Heart final central drain artery', [(0, .25, 2.31), (0, .25, .34)], [.10, .062], 'scar', 6)


def setup():
    scene = original_setup()
    instrument.tissue_texture()
    for key, color in [('iron', '#252b2d'), ('steel', '#75513a'), ('bone', '#b7ae96')]:
        rgba = art.rgba(color)
        art.M[key].diffuse_color = rgba
        art.M[key].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = rgba
    # The packed atlas must be consumed even by bone/iron-only structures.
    image = bpy.data.images.load(str(art.OUT / 'textures/surface_atlas.png'), check_existing=True)
    image.pack()
    nodes = art.M['iron'].node_tree
    texture = nodes.nodes.new('ShaderNodeTexImage')
    texture.image, texture.interpolation = image, 'Closest'
    nodes.links.new(texture.outputs['Color'], nodes.nodes.get('Principled BSDF').inputs['Base Color'])
    return scene


def build_scene(name):
    globals()[name]()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    instrument.tissue_uv(meshes)
    # Bake native transforms before bounds; rotated local boxes overstate actual vertices.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices), 'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons),
               'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert triangles <= 30000, (name, triangles)
    assert abs(extent['min'][2]) <= .001 and all(v <= cap for v, cap in zip(extent['size'], CAPS)), (name, extent)
    groups = [c.name for c in bpy.context.scene.collection.children if c.objects]
    assert len(groups) >= 4, (name, groups)
    STATS[name] = {'source_mesh_count': len(meshes), 'triangles': triangles, 'physical_bounds_m': extent,
                   'source_hierarchy_groups': len(groups), 'assembly_names': groups, 'source_meshes': counts}
    scene = bpy.context.scene
    scene['asset_id'], scene['authoring_recipe'] = name, 'tools/build_religious_late_art.py'
    level = name.split('_', 1)[0]
    scene['recipe_sha256'] = art.sha(Path(__file__))
    scene['reference_images'] = json.dumps({f'source/art/references/religion-{level}-01.png': REFERENCES[level]}, sort_keys=True)
    scene['machine_purpose'], scene['loop_hero_candidate'] = PURPOSES[name], name in HEROES


def main():
    global bpy, art, instrument, assembly, witness, bend, shell, dial, original_setup
    opts = arguments(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    project = Path(__file__).resolve().parents[1]
    output, receipt = preflight(opts.asset, opts.output_root, opts.receipt_root, project)
    import bpy
    import build_art as art
    import build_foundry_art as foundry
    import build_processional_art as instrument
    bend, shell, dial = foundry.bend, foundry.shell, foundry.dial
    intake.bpy, intake.art, intake.bend = bpy, art, bend
    assembly, witness = intake.assembly, intake.witness
    manifest_data = (project / 'source/art/manifest.json').read_bytes()
    manifest = json.loads(manifest_data)
    dependencies = {str(Path(m.__file__).relative_to(project)): art.sha(Path(m.__file__)) for m in (art, foundry, instrument, intake, thermal)}
    assert dependencies['tools/build_art.py'] == manifest['build']['script_sha256'], 'Parent must reconcile shared helper/manifest provenance'
    for module in (foundry, instrument):
        assert all(a['recipe_sha256'] == dependencies[str(Path(module.__file__).relative_to(project))]
                   for a in manifest['assets'] if a['id'] in module.IDS), 'Original native recipe drift'
    level = opts.asset.split('_', 1)[0]
    reference = f'source/art/references/religion-{level}-01.png'
    assert art.sha(project / reference) == REFERENCES[level], 'Selected reference drift'
    atlas_record = next(o for a in manifest['assets'] for o in a['outputs'] if o['path'] == 'game/assets/art/textures/surface_atlas.png')
    atlas = project / atlas_record['path']
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
    entry.update({k: STATS[opts.asset][k] for k in ('source_mesh_count', 'source_hierarchy_groups', 'assembly_names')})
    entry.update(recipe_sha256=art.sha(Path(__file__)), recipe_dependencies=dependencies,
                 reference_images=[{'path': reference, 'sha256': REFERENCES[level]}], level_id=level,
                 tradition_aesthetic=TRADITIONS[opts.asset], machine_purpose=PURPOSES[opts.asset],
                 loop_hero_candidate=opts.asset in HEROES, loop_assignment='parent map-owned; no loop ID invented',
                 texture_dependencies={atlas_record['path']: atlas_record['sha256']},
                 facing='front Blender -Y; exported Godot +Z', collision='none; parent authors explicit bases/solid cover')
    entry['provenance']['authoring_script'] = 'tools/build_religious_late_art.py'
    entry['provenance']['fiction'] = 'Fictional controller commandeering worship systems; no real-community villains or historical claims'
    assert entry['loop_id'] is None and entry['runtime_mesh_nodes'] <= 7 and entry['triangles'] == STATS[opts.asset]['triangles']
    total = group_budget(opts.asset, output)
    payload = {**STATS[opts.asset], 'asset': entry, 'output_root': str(output), 'blender_version': bpy.app.version_string,
               'preview': str(art.SCRATCH / (opts.asset + '_preview.png')), 'status': 'native_candidate_not_integrated',
               'level_glb_bytes_after_export': total, 'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest()}
    receipt.mkdir(parents=True, exist_ok=True)
    (receipt / (opts.asset + '_candidate.json')).write_text(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
