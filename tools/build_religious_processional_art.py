"""Processional reference-derived acoustic machinery; parent owns native dispatch."""
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

IDS = ('processional_pipe_choir', 'processional_gong_carousel', 'processional_bound_drums',
       'processional_acoustic_canopy', 'processional_reed_chariot', 'processional_seven_reeds',
       'processional_winged_sarcophagus')
TRADITIONS = dict(zip(IDS, ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
PURPOSES = dict(zip(IDS, (
    'Forces recovered breath through a stationary cruciform pipe choir and articulated wind distributor',
    'Sorts procession timing through a low rotating bank of struck gongs and folded receiving tongues',
    'Measures passage through a bound open threshold using two suspended rib-drum resonators',
    'Concentrates returning sound inside deep domed recesses above an open acoustic portal',
    'Transports and pumps marching breath in a wheeled tiered chariot with exposed bellows chambers',
    'Separates seven breath signals through long hollow reeds and independent articulated wind bases',
    'Carries the final voice in a horizontal ribbed sarcophagus with winged sound vanes and a standing witness',
)))
REFERENCES = {
    'source/art/references/religion-processional-01.png': '8839f307d5b40d6440b6d40bf072d72e495d7dec4929cecbe89d559f42d42b46',
    'source/art/references/overhaul-01.png': '128bdefcf43afc37d74fad4c8b5683af46b0cb6a35f6c3a2ba7ab7e5e66e7869',
}
CAPS = (8, 6, 9)
STATS = {}


def preflight(asset, output_root, receipt_root, project_root):
    if asset not in IDS:
        raise ValueError('Select one exact Processional asset ID')
    output, receipt = intake.candidate_roots(output_root, receipt_root, project_root)
    paths = [output / 'source/art' / (asset + '.blend'),
             output / 'game/assets/art/world' / (asset + '.glb'),
             output / 'previews' / (asset + '_preview.png'),
             output / 'previews/frames' / (asset + '_hero.png'), receipt / (asset + '_candidate.json')]
    if any(p.exists() or p.is_symlink() for p in paths):
        raise FileExistsError('Processional candidate exists; select a fresh batch root')
    if (output / 'game/assets/art/textures/surface_atlas.png').is_symlink():
        raise ValueError('Processional candidate atlas must not be a symlink')
    return output, receipt


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--receipt-root', type=Path, required=True)
    return parser.parse_args(argv)


def pipe_choir():
    with assembly('Stationary cruciform windchest and open receiving arch'):
        art.box('Choir stationary ground windchest', (0, .15, .13), (6.35, 2.75, .26), 'iron', .04)
        art.box('Choir recessed wind receiver', (0, -.39, .29), (1.72, 1.17, .07), 'black', .01)
        for side in (-1, 1):
            bend(f'Choir pointed receiving arch {side}', [(side * .87, -.46, .33), (side * .96, -.46, 1.81),
                 (side * .55, -.46, 2.4), (0, -.46, 2.72)], .11, 'bone', 8, 12)
            art.tube(f'Choir recessed breath conduit {side}', [(side * .27, .18, .32), (side * .18, .22, 2.93)], .065, 'skin', 6)
    with assembly('Seven high hollow pipes and six flanking wind ranks'):
        for i in range(7):
            x = (i - 3) * .46
            instrument.organ_pipe(i, x, .45, 2.12, 8.42 - abs(i - 3) * .43, .185)
        for side in (-1, 1):
            for i in range(3):
                x = side * (2.02 + i * .38)
                instrument.organ_pipe(10 + i + (3 if side > 0 else 0), x, .11, .77, 4.14 - i * .43, .145)
        for z in (2.37, 4.97):
            art.box(f'Choir rear rank restraint {z}', (0, .88, z), (3.35, .17, .16), 'steel', .02)
    with assembly('Articulated cross-arm wind distributor and carved witness'):
        witness('Choir fictional carved wind operator', 0, -.14, 4.61, 1.18)
        art.tube('Choir cross-arm transverse wind main', [(-2.72, -.10, 5.69), (2.72, -.10, 5.69)], .135, 'steel', 10)
        for side in (-1, 1):
            bend(f'Choir articulated transverse arm {side}', [(side * .27, -.34, 5.49), (side * 1.07, -.42, 5.78),
                 (side * 2.08, -.30, 5.57), (side * 2.66, -.11, 5.70)], (.105, .045), 'bone', 8, 12)
            for j in range(3):
                x = side * (.88 + j * .57)
                art.ring(f'Choir transverse pressure joint {side} {j}', (x, -.1, 5.69), .18, .035, 'bone', 'YZ', 12)
            bend(f'Choir forked hip wind return {side}', [(side * .13, -.15, 4.22), (side * .42, -.25, 3.5),
                 (side * .3, -.27, 3.0), (side * .69, -.12, 2.7)], .075, 'bone', 6, 10)
            art.tube(f'Choir stretched exposed breath tendon {side}', [(side * .34, -.18, 4.59),
                     (side * .42, -.08, 3.46), (side * .16, -.12, 2.83)], [.08, .045, .019], 'skin', 6)
    with assembly('Rear buttress wind feeds and carved relief shoes'):
        for side in (-1, 1):
            bend(f'Choir rear stationary cathedral buttress {side}', [(side * 2.72, .72, .28),
                 (side * 2.4, 1.13, 3.8), (side * 1.77, .97, 6.73), (side * .31, .78, 8.17)], .09, 'steel', 6, 14)
            for i in range(4):
                art.box(f'Choir carved buttress vertebral shoe {side} {i}', (side * 2.70, -.52, .59 + i * .28),
                        (.31, .19, .13), 'bone', .014)
            dial(f'Choir wind regulator {side}', (side * 1.62, -.76, .67), .18)


def gong_carousel():
    with assembly('Low lotus wind receiver and ten folded sound tongues'):
        art.box('Gong-carousel low rotating chassis', (0, .14, .12), (5.95, 3.85, .24), 'iron', .04)
        shell('Gong-carousel thick concave receiving basin', [(1.62, 1.14), (1.75, 1.34), (1.61, 1.43),
              (.79, .55), (.31, .39), (.31, .27), (.93, .42), (1.62, 1.14)], 'bone', steps=24)
        art.ring('Gong-carousel exposed low rotation bearing', (0, 0, .43), 1.35, .10, 'steel', segments=24)
        for i in range(10):
            a = i * math.tau / 10
            c, s = math.cos(a), math.sin(a)
            bend(f'Gong-carousel folded ivory receiving tongue {i}', [(.64 * c, .64 * s, .39),
                 (1.52 * c, 1.52 * s, .33), (2.64 * c, 1.60 * s, 1.57), (2.28 * c, 1.40 * s, 1.88)],
                 (.18, .065), 'bone', 8, 12)
            art.egg(f'Gong-carousel thick tongue diaphragm {i}', (1.58 * c, 1.10 * s, .77), (.24, .16, .40), 'skin', 10, 6)
    with assembly('Open arched carousel frame and five concave gongs'):
        for side in (-1, 1):
            bend(f'Gong-carousel restrained suspension bow {side}', [(side * 2.72, .45, .27),
                 (side * 2.89, .65, 4.43), (side * 1.51, .79, 5.57), (0, .67, 5.70)], .10, 'steel', 8, 14)
            art.tube(f'Gong-carousel low diagonal support {side}', [(side * 2.6, .89, .3), (side * 2.14, .89, 3.47)], .08, 'bone', 6)
        for i, (x, y, z, r) in enumerate([(-1.76, -.08, 3.39, .68), (0, -.23, 3.80, .84),
                                        (1.76, -.08, 3.39, .68), (-1.0, 1.07, 3.83, .49), (1.0, 1.07, 3.83, .49)]):
            disk = shell(f'Gong-carousel thick concave struck gong {i}', [(r * .10, -.13), (r * .53, -.09),
                         (r, .035), (r * 1.04, .095), (r * 1.04, .15), (r * .96, .12),
                         (r * .50, -.03), (r * .10, -.06), (r * .10, -.13)], 'steel', steps=24)
            disk.rotation_euler.x, disk.location = math.pi / 2, (x, y, z)
            art.egg(f'Gong-carousel raised struck boss {i}', (x, y - .02, z), (r * .22, .13, r * .22), 'steel', 12, 6)
            art.tube(f'Gong-carousel articulated suspension tie {i}', [(x, y, z + r), (x * .92, y + .10, 5.16)], .038, 'bone', 6)
            for j in range(8):
                a = j * math.tau / 8
                art.tube(f'Gong-carousel incised gong relief spoke {i} {j}', [(x + r * .58 * math.cos(a), y - .01, z + r * .58 * math.sin(a)),
                         (x + r * .84 * math.cos(a), y - .075, z + r * .84 * math.sin(a))], .012, 'black', 4)
    with assembly('Articulated striker arms and returning breath ligaments'):
        for side in (-1, 1):
            bend(f'Gong-carousel jointed striker linkage {side}', [(side * 2.49, -.56, 1.29),
                 (side * 2.48, -.63, 2.46), (side * 1.14, -.73, 2.82), (side * .31, -.70, 3.70)], .068, 'bone', 6, 12)
            art.egg(f'Gong-carousel soft impact mallet {side}', (side * .31, -.66, 3.70), (.16, .19, .19), 'scar', 10, 6)
            bend(f'Gong-carousel returned breath trunk {side}', [(side * 1.35, .54, 1.30),
                 (side * 1.1, .70, 2.26), (side * .37, .42, 2.44), (side * .20, .10, 3.24)], .11, 'skin', 6, 12)
    with assembly('Central rotating wind spindle and low timing calibration'):
        shell('Gong-carousel hollow wind spindle', [(.25, .3), (.22, 2.66), (.14, 2.66), (.17, .3)], 'iron', steps=16)
        for i in range(6):
            a = i * math.tau / 6
            art.tube(f'Gong-carousel low radial drive {i}', [(.20 * math.cos(a), .20 * math.sin(a), .49),
                     (1.40 * math.cos(a), 1.40 * math.sin(a), .49)], .045, 'steel', 6)
        dial('Gong-carousel cadence regulator', (0, -1.19, .63), .21)


def bound_drums():
    with assembly('Bound threshold four piers and double curved lintels'):
        for side in (-1, 1):
            for back in (-1, 1):
                x, y = side * 1.99, back * .46
                art.box(f'Drum threshold independent footing {side} {back}', (x, y, .13), (.71, .70, .26), 'iron', .035)
                shell(f'Drum threshold open ivory pier {side} {back}', [(.20, .26), (.25, 6.1), (.15, 6.1), (.12, .26)],
                      'bone', center=(x, y, 0), steps=12)
                for z in (1.0, 2.8, 4.6, 5.8):
                    art.ring(f'Drum threshold restrained pier joint {side} {back} {z}', (x, y, z), .28, .05, 'steel', segments=12)
            for level in (0, 1):
                z = 6.07 + level * .62
                bend(f'Drum threshold upturned articulated lintel {side} {level}', [(0, .08, z),
                     (side * 1.38, .08, z + .02), (side * 2.48, .08, z + .1), (side * 3.22, .08, z + .50)], .12, 'bone', 8, 12)
    with assembly('Braided acoustic binding and short folded vocal pendants'):
        for strand in range(3):
            points = []
            for i in range(37):
                t, a = -1 + i / 18, i * math.tau / 7 + strand * math.tau / 3
                points.append((2.15 * t, -.43 + .10 * math.cos(a), 5.78 - .33 * (1 - t * t) + .10 * math.sin(a)))
            art.tube(f'Drum threshold braided listening binding {strand}', points, .075, 'bone', 6)
        for i in range(5):
            verts, faces = thermal.curtain_leaf(-1.28 + i * .64, 5.35, .65 + .11 * (i % 2))
            art.mesh(f'Drum threshold short folded voice pendant {i}', verts, faces, 'scar')
            art.box(f'Drum threshold pendant copper ferrule {i}', (-1.28 + i * .64, -.44, 5.30), (.25, .10, .10), 'steel', .01)
    with assembly('Twin lateral hollow rib-drum resonators'):
        for side in (-1, 1):
            x = side * 2.78
            shell(f'Drum threshold open double-wall oval resonator {side}', [(.30, 1.06), (.63, 1.44), (.76, 2.12),
                  (.68, 3.03), (.29, 3.53), (.19, 3.53), (.57, 3.03), (.64, 2.12), (.52, 1.44), (.21, 1.06)],
                  'skin', center=(x, .13, 0), aspect=(.80, 1), steps=20)
            for i in range(8):
                a = i * math.tau / 8
                c, s = math.cos(a), math.sin(a)
                bend(f'Drum threshold articulated curved rib {side} {i}', [(x + .25 * c, .13 + .29 * s, 1.08),
                     (x + .72 * c, .13 + .90 * s, 1.80), (x + .63 * c, .13 + .84 * s, 2.96),
                     (x + .20 * c, .13 + .28 * s, 3.52)], .054, 'bone', 6, 12)
            for z, r in [(1.11, .3), (2.1, .74), (3.51, .29)]:
                art.ring(f'Drum threshold transverse rib restraint {side} {z}', (x, .13, z), r, .046, 'steel', segments=16)
            art.tube(f'Drum threshold upper hanging axle {side}', [(x, .13, 3.5), (side * 2.55, .13, 5.88)], .09, 'steel', 8)
            art.tube(f'Drum threshold exposed sound throat {side}', [(x, .13, 1.13), (x, -.10, .69)], [.17, .09], 'black', 8)
    with assembly('Low drum cradles and independent threshold returns'):
        for side in (-1, 1):
            art.box(f'Drum threshold low resonator cradle {side}', (side * 2.78, .13, .14), (1.36, 1.6, .28), 'iron', .04)
            bend(f'Drum threshold returning sound ligament {side}', [(side * 2.74, -.1, .68),
                 (side * 2.08, -.03, .47), (side * 1.63, .50, .51), (side * 1.97, .47, 2.13)], .073, 'skin', 6, 12)
            dial(f'Drum threshold tension regulator {side}', (side * 1.97, -.76, .68), .18)


def acoustic_canopy():
    with assembly('Tall domed acoustic frame and clear central portal'):
        art.box('Acoustic canopy shallow ground plinth', (0, .12, .13), (5.50, 3.5, .26), 'iron', .04)
        for side in (-1, 1):
            bend(f'Acoustic canopy pointed open portal side {side}', [(side * 1.0, -.78, .28),
                 (side * 1.13, -.77, 2.65), (side * .65, -.79, 3.48), (0, -.79, 3.95)], .10, 'bone', 8, 14)
            bend(f'Acoustic canopy exterior domed rib {side}', [(side * 2.49, .2, .27),
                 (side * 2.65, .2, 5.78), (side * 1.40, .2, 8.26), (0, .2, 8.66)], .09, 'steel', 6, 14)
    with assembly('Seven vertical dome tiers of actual acoustic recesses'):
        for tier, (r, z, count) in enumerate([(2.22, 2.74, 8), (2.28, 3.65, 8), (2.10, 4.57, 7),
                                             (1.83, 5.49, 6), (1.43, 6.41, 5), (.91, 7.33, 3), (.43, 8.05, 1)]):
            shell(f'Acoustic canopy half-dome corbel belt {tier}', [(r, z - .1), (r, z + .03),
                  (r - .10, z + .03), (r - .10, z - .1), (r, z - .1)], 'steel',
                  center=(0, .16, 0), aspect=(1, .72), arc=(-math.pi, 0), steps=24)
            for cell in range(count):
                a = -math.pi + (cell + .5) * math.pi / count
                local, faces = thermal.pressure_cell(r * math.pi / count * .87)
                verts = [((r - depth) * math.cos(a) - tang * math.sin(a),
                          .16 + .72 * ((r - depth) * math.sin(a) + tang * math.cos(a)), z + dz)
                         for tang, depth, dz in local]
                art.mesh(f'Acoustic canopy deep domed muqarnas recess {tier} {cell}', verts, faces, 'bone')
                art.tube(f'Acoustic canopy carved cell lip {tier} {cell}', [verts[j] for j in (0, 1, 2, 3, 4)], .017, 'scar', 5)
    with assembly('Open portal lattice tracery and carved breath ribs'):
        for side in (-1, 1):
            for i in range(3):
                x, z = side * (.19 + i * .22), 1.0 + i * .61
                bend(f'Acoustic canopy raised interlaced portal rib {side} {i}', [(x, -.95, .32),
                     (side * (.78 - i * .12), -.97, z), (side * .72, -.98, z + .89), (0, -.95, 3.57 - i * .25)], .031, 'bone', 6, 10)
            for i in range(4):
                z = .91 + i * .48
                art.tube(f'Acoustic canopy oblique portal lattice tie {side} {i}', [(0, -.95, z),
                         (side * .79, -.95, z + .47)], .024, 'bone', 5)
    with assembly('Posterior hollow echo returns and restrained listening feet'):
        for side in (-1, 1):
            shell(f'Acoustic canopy posterior open echo tower {side}', [(.23, .31), (.28, 5.51), (.17, 5.51), (.13, .31)],
                  'iron', center=(side * 2.24, .95, 0), steps=12)
            bend(f'Acoustic canopy posterior echo return {side}', [(side * 2.22, .97, .31),
                 (side * 2.52, 1.37, 3.31), (side * 1.95, 1.35, 5.24), (side * .69, .70, 7.54)], .09, 'skin', 6, 14)
            witness(f'Acoustic canopy carved listening foot {side}', side * 2.20, -.08, 1.21, .43)
            dial(f'Acoustic canopy echo regulator {side}', (side * 1.47, -.99, .63), .17)


def reed_chariot():
    with assembly('Four open spoke wheels and articulated axle chassis'):
        art.box('Reed chariot elevated open carrying deck', (0, 0, 1.69), (3.70, 2.62, .22), 'iron', .04)
        for y in (-.95, .95):
            art.tube(f'Reed chariot transverse wheel axle {y}', [(-2.25, y, 1.13), (2.25, y, 1.13)], .105, 'steel', 8)
            for side in (-1, 1):
                x = side * 2.19
                art.ring(f'Reed chariot open ivory transport wheel {side} {y}', (x, y, 1.13), 1.03, .10, 'bone', 'YZ', 24)
                art.ring(f'Reed chariot copper inner wheel race {side} {y}', (x, y, 1.13), .84, .045, 'steel', 'YZ', 24)
                art.egg(f'Reed chariot carved axle boss {side} {y}', (x, y, 1.13), (.17, .22, .22), 'bone', 12, 6)
                for i in range(10):
                    a = i * math.tau / 10
                    art.tube(f'Reed chariot articulated wheel spoke {side} {y} {i}', [(x, y + .15 * math.cos(a), 1.13 + .15 * math.sin(a)),
                             (x, y + .92 * math.cos(a), 1.13 + .92 * math.sin(a))], .044, 'steel', 6)
        for side in (-1, 1):
            art.tube(f'Reed chariot chassis side tie {side}', [(side * 1.82, -1.25, 1.67), (side * 1.82, 1.25, 1.67)], .10, 'bone', 8)
    with assembly('Open tiered temple carriage and stepped roof terraces'):
        for side in (-1, 1):
            for back in (-1, 1):
                x, y = side * 1.29, back * .86
                shell(f'Reed chariot carved hollow chamber pillar {side} {back}', [(.18, 1.8), (.23, 5.25), (.13, 5.25), (.10, 1.8)],
                      'bone', center=(x, y, 0), steps=12)
                for z in (2.14, 3.20, 4.65):
                    art.ring(f'Reed chariot pillar corbel joint {side} {back} {z}', (x, y, z), .26, .04, 'steel', segments=12)
        for tier, (z, w, d) in enumerate([(5.16, 3.62, 2.56), (5.90, 2.76, 2.08), (6.64, 1.99, 1.61), (7.36, 1.21, 1.13)]):
            for side in (-1, 1):
                art.box(f'Reed chariot hollow roof side cornice {tier} {side}', (side * w / 2, 0, z), (.16, d, .18), 'bone', .02)
                art.box(f'Reed chariot hollow roof front cornice {tier} {side}', (0, side * d / 2, z), (w, .16, .18), 'bone', .02)
                bend(f'Reed chariot stepped roof load rib {tier} {side}', [(side * w * .46, 0, z),
                     (side * w * .41, 0, z + .55), (side * w * .19, 0, z + .75), (0, 0, z + .81)], .051, 'bone', 6, 10)
        instrument.organ_pipe(40, 0, .35, 5.25, 8.34, .16)
    with assembly('Twin exposed pleated bellows and wind transfer chambers'):
        for side in (-1, 1):
            x = side * .68
            shell(f'Reed chariot open back wind chamber {side}', [(.36, 1.91), (.43, 4.82), (.30, 4.82), (.24, 1.91)],
                  'iron', center=(x, .21, 0), arc=(-.10, math.pi + .1), steps=12)
            for i in range(9):
                z = 2.13 + i * .27
                art.ring(f'Reed chariot thick bellows diaphragm fold {side} {i}', (x, .21, z), .31 + .043 * (i % 2), .078, 'skin', segments=12)
                art.tube(f'Reed chariot diaphragm incision {side} {i}', [(x - .20, -.12, z), (x + .20, -.12, z)], .014, 'black', 4)
            bend(f'Reed chariot independent pumping trunk {side}', [(x, .4, 2.0), (side * 1.52, .5, 3.48),
                 (side * 1.53, .44, 4.76), (side * .16, .4, 5.34)], .087, 'skin', 6, 12)
    with assembly('Carved carriage operators front treads and coupling'):
        for side in (-1, 1):
            witness(f'Reed chariot carved carriage witness {side}', side * 1.21, -.89, 3.76, .52)
            dial(f'Reed chariot pumping regulator {side}', (side * 1.43, -1.03, 2.04), .18)
        for i in range(5):
            art.box(f'Reed chariot front climbing tread {i}', (0, -1.09 - i * .13, 1.71 + (4 - i) * .16), (.75, .28, .10), 'bone', .013)
        art.tube('Reed chariot articulated front coupling', [(0, -1.03, 1.70), (0, -1.97, 1.43)], .11, 'steel', 8)
        art.ring('Reed chariot open processional coupling eye', (0, -2.08, 1.43), .20, .045, 'bone', 'XY', 12)


def seven_reeds():
    with assembly('Four independent carved listening wind bases'):
        art.box('Seven reeds low collective distribution foundation', (0, .16, .12), (6.37, 2.9, .24), 'iron', .04)
        for i in range(4):
            x = (i - 1.5) * 1.23
            shell(f'Seven reeds hollow independent wind base {i}', [(.33, .29), (.4, 1.77), (.26, 1.77), (.2, .29)],
                  'iron', center=(x, .3, 0), arc=(-.09, math.pi + .09), steps=12)
            witness(f'Seven reeds carved listening base relief {i}', x, .01, 1.31, .47)
            for z in (.4, 1.82):
                art.ring(f'Seven reeds wind-base open restraint {i} {z}', (x, .3, z), .43, .052, 'bone', segments=12)
    with assembly('Seven long hollow anterior-cut reed chambers'):
        for i in range(7):
            x = (i - 3) * .86
            bottom = 4.50 - abs(i - 3) * .10
            instrument.organ_pipe(60 + i, x, .17, bottom, 7.75 - abs(i - 3) * .19, .175)
            art.ring(f'Seven reeds exposed upper tongue collar {i}', (x, .17, bottom + 1.18), .22, .027, 'steel', segments=12)
    with assembly('Independently articulated bifurcated wind-delivery necks'):
        for i in range(7):
            x, base = (i - 3) * .86, ((i // 2) - 1.5) * 1.23
            bottom = 4.50 - abs(i - 3) * .10
            bend(f'Seven reeds open ivory delivery neck {i}', [(base, .25, 1.81), (base + (x - base) * .3, .1, 2.60),
                 (x, .1, bottom - .68), (x, .17, bottom - .03)], (.095, .065), 'bone', 8, 12)
            bend(f'Seven reeds copper articulated neck tie {i}', [(base, .49, 1.25), (base + (x - base) * .6, .45, 2.96),
                 (x + .15, .37, bottom - .58), (x + .14, .35, bottom + .12)], .041, 'steel', 6, 10)
            art.tube(f'Seven reeds exposed inner reed tongue {i}', [(x, .06, bottom + .27),
                     (x + .018, .03, bottom + .64)], [.039, .009], 'scar', 5)
    with assembly('Low divided breath chest and cadence returns'):
        for i in range(7):
            art.box(f'Seven reeds independent low signal socket {i}', ((i - 3) * .25, -.60, .45), (.12, .28, .17), 'bone', .012)
        for side in (-1, 1):
            bend(f'Seven reeds posterior return {side}', [(side * 2.53, .93, .25), (side * 2.70, 1.0, 1.36),
                 (side * 1.33, .95, 2.01), (side * .25, .48, 1.84)], .09, 'skin', 6, 12)
            dial(f'Seven reeds cadence regulator {side}', (side * 2.37, -.83, .64), .19)


def winged_sarcophagus():
    with assembly('Four restrained support feet and horizontal hollow voice chest'):
        for side in (-1, 1):
            for back in (-1, 1):
                x, y = side * 2.28, back * .71
                art.box(f'Voice sarcophagus independent ground shoe {side} {back}', (x, y, .13), (.72, .64, .26), 'iron', .035)
                bend(f'Voice sarcophagus restrained support limb {side} {back}', [(x, y, .29),
                     (x + side * .18, y, 1.01), (x - side * .27, y, 1.91), (x - side * .24, y, 2.37)], .115, 'bone', 8, 12)
        chest = shell('Voice sarcophagus long open double-wall chamber', [(.44, -2.49), (.87, -1.93), (.93, 1.93),
                      (.44, 2.49), (.28, 2.49), (.75, 1.93), (.69, -1.93), (.28, -2.49)], 'skin', steps=20)
        chest.rotation_euler.y, chest.location = math.pi / 2, (0, .40, 2.48)
        art.tube('Voice sarcophagus exposed horizontal inner voice', [(-2.25, .4, 2.48), (2.25, .4, 2.48)], .22, 'scar', 10)
    with assembly('Articulated ivory chest ribs and separate front witness capsule'):
        for i in range(13):
            x = -2.07 + i * .345
            art.ring(f'Voice sarcophagus articulated horizontal rib cage {i}', (x, .4, 2.48), .98, .058, 'bone', 'YZ', 20)
            art.box(f'Voice sarcophagus carved rib joint {i}', (x, -.59, 2.49), (.11, .14, .29), 'steel', .013)
        shell('Voice sarcophagus standing hollow witness hood', [(.42, 1.15), (.51, 3.63), (.40, 4.37),
              (.30, 4.37), (.38, 3.63), (.29, 1.15)], 'bone', center=(0, -.99, 0), arc=(-.10, math.pi + .1), steps=16)
        witness('Voice sarcophagus fictional standing witness', 0, -1.02, 3.55, .93)
        for side in (-1, 1):
            bend(f'Voice sarcophagus capsule open anterior frame {side}', [(side * .40, -1.15, 1.16),
                 (side * .59, -1.15, 3.24), (side * .46, -1.15, 4.16), (0, -1.15, 4.46)], .061, 'steel', 6, 12)
    with assembly('Broad articulated winged acoustic louvres and bird-post supports'):
        for side in (-1, 1):
            for i in range(9):
                bend(f'Voice sarcophagus thick swept wing sound vane {side} {i}', [(side * .55, -.12, 2.72 + i * .14),
                     (side * 1.95, -.11, 2.84 + i * .21), (side * 3.31, -.02, 3.30 + i * .21),
                     (side * 3.70, .02, 3.52 + i * .17)], (.094, .031), 'bone', 8, 12)
                art.tube(f'Voice sarcophagus raised wing vane incision {side} {i}', [(side * 1.88, -.2, 2.84 + i * .21),
                         (side * 3.12, -.12, 3.22 + i * .20)], .015, 'steel', 5)
            bend(f'Voice sarcophagus posterior bird-post {side}', [(side * 1.62, 1.01, .29),
                 (side * 1.85, 1.10, 4.94), (side * 1.72, .89, 6.55), (side * 1.22, .64, 6.79)], .11, 'bone', 8, 14)
            art.egg(f'Voice sarcophagus carved bird-post crest {side}', (side * 1.22, .64, 6.79), (.25, .17, .14), 'bone', 12, 6)
            art.tube(f'Voice sarcophagus carved hooked crest beak {side}', [(side * 1.21, .56, 6.83),
                     (side * .91, .40, 6.78), (side * .92, .35, 6.62)], [.072, .048, .01], 'steel', 6)
    with assembly('Upper voice gong and horizontal transfer ligaments'):
        gong = shell('Voice sarcophagus thick upper concave gong', [(.09, -.11), (.39, -.07), (.77, .06),
                     (.80, .11), (.76, .15), (.35, -.005), (.09, -.04), (.09, -.11)], 'steel', steps=24)
        gong.rotation_euler.x, gong.location = math.pi / 2, (0, .65, 5.73)
        for side in (-1, 1):
            bend(f'Voice sarcophagus gong suspension return {side}', [(side * 1.70, .9, 5.92),
                 (side * 1.09, .97, 5.63), (side * .50, .81, 5.26), (side * .34, .65, 5.10)], .052, 'steel', 6, 10)
            bend(f'Voice sarcophagus anterior voice transfer {side}', [(side * 2.22, .14, 2.4),
                 (side * 2.57, -.34, 1.45), (side * 1.59, -.72, .45), (side * .2, -.44, .35)], .08, 'skin', 6, 12)
            dial(f'Voice sarcophagus final voice regulator {side}', (side * 2.27, -.91, .64), .19)


def setup():
    scene = original_setup()
    instrument.tissue_texture()
    for key, color in [('steel', '#75513a'), ('iron', '#252b2d'), ('bone', '#b7ae96')]:
        rgba = art.rgba(color)
        art.M[key].diffuse_color = rgba
        art.M[key].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = rgba
    return scene


def build_scene(name):
    globals()[name.removeprefix('processional_')]()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    instrument.tissue_uv(meshes)
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
    scene['asset_id'], scene['authoring_recipe'] = name, 'tools/build_religious_processional_art.py'
    scene['recipe_sha256'], scene['reference_images'] = art.sha(Path(__file__)), json.dumps(REFERENCES, sort_keys=True)
    scene['machine_purpose'] = PURPOSES[name]


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
    assert all(art.sha(project / p) == h for p, h in REFERENCES.items()), 'Processional reference drift'
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
                 reference_images=[{'path': p, 'sha256': h} for p, h in REFERENCES.items()], level_id='processional',
                 tradition_aesthetic=TRADITIONS[opts.asset], machine_purpose=PURPOSES[opts.asset],
                 texture_dependencies={atlas_record['path']: atlas_record['sha256']},
                 facing='front Blender -Y; exported Godot +Z', collision='none; parent authors explicit bases/solid cover')
    entry['provenance']['authoring_script'] = 'tools/build_religious_processional_art.py'
    entry['provenance']['fiction'] = 'Fictional controller commandeering worship systems; no real-community villains or historical claims'
    assert entry['loop_id'] is None and entry['runtime_mesh_nodes'] <= 7 and entry['triangles'] == STATS[opts.asset]['triangles']
    assert sum((art.OUT / 'world' / (name + '.glb')).stat().st_size for name in IDS
               if (art.OUT / 'world' / (name + '.glb')).exists()) < 8 * 1024 * 1024, 'Seven Processional GLB budget'
    payload = {**STATS[opts.asset], 'asset': entry, 'output_root': str(output), 'blender_version': bpy.app.version_string,
               'preview': str(art.SCRATCH / (opts.asset + '_preview.png')), 'status': 'native_candidate_not_integrated',
               'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest()}
    receipt.mkdir(parents=True, exist_ok=True)
    (receipt / (opts.asset + '_candidate.json')).write_text(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
