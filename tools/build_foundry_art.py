"""Original Foundry hero anatomy; reuse Intake's source/render/GLB pipeline.

Run: blender -b -t 4 --python tools/build_foundry_art.py -- --asset ID
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import interpolate_bezier

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_art as art

IDS = ('vertebral_furnace', 'marrow_crucible')
CAPS = {'vertebral_furnace': (8, 6, 9), 'marrow_crucible': (8, 6, 5)}
STATS = {}


def bend(name, controls, radius, mat='bone', sides=8, steps=10):
    """Sample a native Bezier into the existing editable swept-mesh helper."""
    points = interpolate_bezier(*(Vector(p) for p in controls), steps)
    start, end = (radius, radius) if isinstance(radius, (int, float)) else radius
    radii = [(start + (end - start) * i / (steps - 1)) for i in range(steps)]
    return art.tube(name, points, radii, mat, sides)


def shell(name, profile, mat, center=(0, 0, 0), aspect=(1, 1), arc=(-math.pi, math.pi), steps=32):
    """A sectioned annular wall: open firebox, spinal flanges or concave basin."""
    verts, faces = [], []
    cx, cy, cz = center
    for row, (r, z) in enumerate(profile):
        for i in range(steps + 1):
            a = arc[0] + (arc[1] - arc[0]) * i / steps
            verts.append((cx + aspect[0] * r * math.cos(a), cy + aspect[1] * r * math.sin(a), cz + z))
            if row and i:
                k = row * (steps + 1) + i
                faces.append((k - steps - 2, k - steps - 1, k, k - 1))
    return art.mesh(name, verts, faces, mat)


def dial(name, pos, radius=.25):
    x, y, z = pos
    art.egg(name + ' recessed black dial', (x, y + .03, z), (radius * .86, .04, radius * .86), 'black', 12, 6)
    art.ring(name + ' iron machined rim', pos, radius, .045, 'steel', 'XZ', 12)
    art.ring(name + ' ivory calibration bezel', (x, y - .015, z), radius * .84, .018, 'bone', 'XZ', 12)
    for i in range(9):
        a = (.20 + i * .325) * math.pi
        art.tube(name + f' calibration cut {i}', [(x + radius * .59 * math.cos(a), y - .03, z + radius * .59 * math.sin(a)),
                 (x + radius * .75 * math.cos(a), y - .03, z + radius * .75 * math.sin(a))], .009, 'bone', 4)
    art.tube(name + ' amber needle', [(x + .035, y - .05, z - .025), (x - radius * .50, y - .05, z + radius * .36)], .018, 'amber', 5)


def skin_texture():
    # Packed, original pixel incisions; no procedural shader survives into the GLB.
    for key in ('skin', 'scar'):
        image = bpy.data.images.new('Foundry ' + key + ' incised tissue', width=64, height=64, alpha=True)
        color = art.rgba(art.PALETTE['burgundy' if key == 'skin' else 'scar'])
        pixels = []
        for y in range(64):
            for x in range(64):
                seam = (x + round(3 * math.sin(y * .18))) % 21
                noise = ((x * 17 + y * 29 + x * y) % 13 - 6) / 120
                shade = .47 if seam < 2 else 1.20 if seam == 2 else 1 + noise
                pixels.extend([min(1, c * shade) for c in color[:3]] + [1])
        image.pixels.foreach_set(pixels)
        image.pack()
        shader = art.M[key].node_tree.nodes.get('Principled BSDF')
        tex = art.M[key].node_tree.nodes.new('ShaderNodeTexImage')
        tex.image, tex.interpolation = image, 'Closest'
        art.M[key].node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    art.M['amber'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 2.3


def vertebral_furnace():
    art.box('Furnace bolted ground foundation', (0, .12, .16), (4.8, 3.4, .32), 'iron', .065)
    art.box('Furnace recessed ash tray', (0, -.62, .37), (2.8, 1.8, .10), 'black', .035)
    for side in (-1, 1):
        art.box(f'Furnace base chassis rail {side}', (side * 1.86, .08, .45), (.32, 2.85, .26), 'steel', .035)
        for i in range(6):
            art.box(f'Furnace foundation anchor {side} {i}', (side * 2.17, -1.25 + i * .51, .36), (.11, .13, .08), 'bone', .012)
        bend(f'Furnace structural hind strut {side}', [(side * 1.7, .96, .4), (side * 1.9, 1.18, 2.4),
             (side * 1.5, 1.02, 4.4), (side * .72, .55, 5.55)], (.17, .08), 'iron', 10)
        bend(f'Furnace steel hind piston {side}', [(side * 1.83, .87, .5), (side * 1.89, .97, 1.6),
             (side * 1.7, .85, 2.4), (side * 1.45, .69, 3.12)], .065, 'steel', 8)
        art.ring(f'Furnace lower reaction collar {side}', (side * 1.82, .88, 1.25), .22, .055, 'bone', 'XZ', 16)
    # The missing anterior sector is an actual open black firebox, not a dark plaque.
    shell('Open black thoracic firebox', [(1.0, .77), (1.30, 1.55), (1.54, 2.80), (1.34, 4.0),
          (.84, 4.80), (.70, 4.76), (1.16, 4.0), (1.35, 2.80), (1.12, 1.55), (.83, .77)],
          'black', center=(0, .20, 0), aspect=(1, .83), arc=(-.66, math.pi + .66))
    shell('Furnace rear pressure jacket', [(1.08, .82), (1.37, 1.7), (1.59, 2.85), (1.36, 4.02), (.86, 4.75)],
          'iron', center=(0, .30, 0), aspect=(1, .84), arc=(.08, math.pi - .08))
    for side in (-1, 1):
        bend(f'Thoracic anterior ivory load rib {side}', [(side * .62, -.54, .80), (side * 2.45, -1.25, 2.1),
             (side * 2.07, -.84, 4.70), (side * .55, -.32, 5.15)], (.16, .105), steps=18)
        for i in range(10):
            z = 1.20 + i * .335
            width = .78 + .93 * math.sin((i + 1) * math.pi / 12)
            bend(f'Interlocking costal blade {side} {i}', [(side * .19, .98, z + .13), (side * (width + .62), .82, z + .40),
                 (side * (width + .54), -1.02, z + .24), (side * .50, -.93, z - .10 + (i % 2) * .13)],
                 (.10, .038), 'bone', 8, 12)
            art.tube(f'Exposed costal root incision {side} {i}', [(side * 1.04, .64, z), (side * 1.31, .28, z + .11)], [.07, .018], 'scar', 6)
            art.box(f'Rib clamp lock {side} {i}', (side * (width + .12), -.45, z + .19), (.18, .22, .13), 'steel', .022)
        # Flayed tissue follows the sides; the anterior wound remains readable.
        for i in range(5):
            z = 1.38 + i * .55
            art.egg(f'Flayed lateral pleura {side} {i}', (side * 1.30, .11, z), (.30, .59, .40), 'skin', 12, 6)
            bend(f'Split pleural incision {side} {i}', [(side * 1.29, -.45, z - .29), (side * 1.50, -.43, z - .07),
                 (side * 1.40, -.47, z + .17), (side * 1.32, -.45, z + .31)], .019, 'black', 5, 6)
            art.stitches(f'Pleural surgical staple {side} {i}', [(side * 1.37, -.48, z + k * .09) for k in (-2, 0, 2)], (.095, 0, .012))
    # Glowing marrow branches float visibly behind the broken sternum.
    art.egg('Furnace molten marrow chamber', (0, .06, 2.63), (.38, .32, 1.12), 'amber', 16, 10)
    for side in (-1, 1):
        bend(f'Glowing marrow bifurcation {side}', [(0, -.15, 1.35), (side * .81, -.15, 2.25),
             (side * .48, -.11, 3.83), (side * .13, -.03, 4.60)], (.12, .034), 'amber', 8, 16)
        bend(f'Charred marrow lattice {side}', [(side * .1, -.39, 1.37), (side * .73, -.40, 2.20),
             (side * .59, -.37, 3.87), (side * .1, -.22, 4.25)], (.042, .024), 'black', 6, 12)
    for i in range(5):
        art.tube(f'Furnace dripping anterior marrow {i}', [((i - 2) * .18, -.43, 1.70), ((i - 2) * .15, -.73, 1.04),
                 ((i - 2) * .14, -.92, .48)], [.047, .035, .017], 'amber', 6)
    # A segmented hollow spinal chimney with vertebral plates and lateral processes.
    shell('Hollow furnace chimney throat', [(.54, 4.43), (.59, 8.56), (.45, 8.56), (.41, 4.43)],
          'black', center=(0, .31, 0), steps=24)
    for i in range(10):
        z = 4.72 + i * .385
        r = .69 - i * .013
        shell(f'Segmented vertebral flange {i}', [(r * .73, z - .07), (r + .13, z), (r + .15, z + .14),
              (r * .86, z + .25), (r * .67, z + .25), (r * .64, z - .07)],
              'bone', center=(.05 * math.sin(i * .61), .31, 0), aspect=(1, .86), steps=20)
        art.egg(f'Incised intervertebral disc {i}', (0, .31, z + .29), (.56, .45, .058), 'skin', 12, 4)
        for side in (-1, 1):
            bend(f'Spinal transverse process {side} {i}', [(side * .42, .30, z + .12), (side * 1.11, .56, z + .04),
                 (side * 1.25, .06, z + .24), (side * .79, -.31, z + .31)], (.105, .018), 'bone', 6, 8)
        art.box(f'Spinal anterior steel staple {i}', (0, -.36, z + .06), (.27, .10, .12), 'steel', .025)
        art.egg(f'Spinal amber pressure aperture {i}', (.19, -.30, z + .14), (.036, .027, .065), 'amber', 8, 4)
    art.ring('Chimney incised crown', (0, .31, 8.59), .57, .11, 'steel', segments=24)
    for i in range(7):
        a = i * 2 * math.pi / 7
        art.tube(f'Chimney inward crown tooth {i}', [(.62 * math.cos(a), .31 + .62 * math.sin(a), 8.52),
                 (.46 * math.cos(a + .10), .31 + .46 * math.sin(a + .10), 8.87)], [.085, .007], 'bone', 6)
    # An asymmetric maintenance limb, pressure bank and real chassis-fed cables.
    limb = [(-1.87, .81, .47), (-2.55, .80, 2.02), (-2.84, .25, 3.82), (-2.14, -.74, 4.47)]
    art.tube('Left articulated furnace maintenance arm', limb, [.18, .15, .13, .075], 'iron', 10)
    for i, p in enumerate(limb[1:-1]):
        art.egg(f'Maintenance elbow housing {i}', p, (.22, .21, .22), 'steel', 12, 6)
        art.ring(f'Maintenance elbow ivory collar {i}', p, .25, .055, 'bone', 'XZ', 16)
    bend('Maintenance diagonal hydraulic piston', [(-2.04, .68, .76), (-2.52, .63, 1.88),
         (-2.60, .20, 2.72), (-2.76, .09, 3.31)], .055, 'steel', 8)
    for i in range(3):
        bend(f'Maintenance grasping finger {i}', [(-2.15, -.74, 4.47), (-1.85 + i * .13, -1.0, 4.49),
             (-1.42 + i * .10, -1.03, 4.14), (-1.47 + i * .10, -.90, 3.86)], (.057, .013), 'bone', 6, 8)
    art.box('Asymmetric pressure gauge bank', (2.24, -.17, 2.72), (.65, .55, 1.80), 'iron', .09)
    for i in range(3):
        dial(f'Furnace marrow pressure gauge {i}', (2.24, -.48, 2.20 + i * .53), .225)
    bend('Gauge bank rising supply tube', [(1.97, .27, .40), (2.86, .76, 1.53), (2.77, .44, 3.7), (1.38, .54, 4.31)], .092, 'steel', 8, 14)
    art.ring('Furnace release handwheel', (2.84, -.40, 1.44), .43, .053, 'bone', 'XZ', 20)
    for i in range(5):
        a = i * 2 * math.pi / 5
        art.tube(f'Furnace handwheel spoke {i}', [(2.84, -.40, 1.44), (2.84 + .4 * math.cos(a), -.40, 1.44 + .4 * math.sin(a))], .028, 'steel', 6)
    for side in (-1, 1):
        for i in range(3):
            x = side * (1.49 + i * .16)
            bend(f'Ground-fed furnace umbilical {side} {i}', [(x, 1.41, .38), (side * (2.03 + i * .12), 1.71, 2.73),
                 (side * (.87 + i * .09), 1.31, 5.84), (side * .48, .64 + i * .09, 7.57 - i * .48)],
                 (.061, .027), 'skin' if i == 1 else 'steel', 6, 20)
            art.box(f'Umbilical chassis socket {side} {i}', (x, 1.42, .49), (.16, .23, .21), 'bone', .025)
    dial('Furnace front ash regulator', (-1.51, -1.25, .83), .26)


def pelvic_wing(side):
    verts, faces = [], []
    steps, rows = 40, 4
    for layer in range(2):
        for row in range(rows):
            t = row / (rows - 1)
            for i in range(steps):
                a = i * 2 * math.pi / steps
                rx = .62 + t * (.83 + .12 * math.sin(3 * a))
                rz = .84 + t * (.70 + .10 * math.cos(2 * a))
                verts.append((side * (2.05 + rx * math.cos(a)), .38 + .20 * math.sin(a) - .34 * t * t + layer * .16,
                              2.52 + rz * math.sin(a)))
                if row:
                    k, q = layer * rows * steps + (row - 1) * steps + i, layer * rows * steps + (row - 1) * steps + (i + 1) % steps
                    face = (k, q, q + steps, k + steps)
                    faces.append(face if layer else tuple(reversed(face)))
    for row in (0, rows - 1):
        for i in range(steps):
            k, q = row * steps + i, row * steps + (i + 1) % steps
            faces.append((k, q, q + rows * steps, k + rows * steps))
    art.mesh(f'Split iliac lamina with true foramen {side}', verts, faces, 'bone')
    bend(f'Pelvic crest relief {side}', [(side * 1.13, .12, 3.41), (side * 1.25, -.04, 4.35),
         (side * 3.55, -.12, 4.39), (side * 3.39, -.21, 2.45)], (.12, .047), 'bone', 8, 20)
    for i in range(7):
        a = .22 + i * .31
        bend(f'Iliac carved tension stria {side} {i}', [(side * (2.05 + .64 * math.cos(a)), .24, 2.52 + .87 * math.sin(a)),
             (side * (2.05 + .85 * math.cos(a)), .16, 2.52 + 1.10 * math.sin(a)),
             (side * (2.05 + 1.13 * math.cos(a)), .03, 2.52 + 1.34 * math.sin(a)),
             (side * (2.05 + 1.40 * math.cos(a)), -.02, 2.52 + 1.47 * math.sin(a))], (.022, .007), 'scar', 5, 8)
    bend(f'Pelvic inward obturator load bar {side}', [(side * 2.91, .15, 1.55), (side * 2.3, -.2, .73),
         (side * .73, -.23, .62), (side * .30, -.17, 1.48)], (.17, .085), 'bone', 8, 16)


def marrow_crucible():
    art.box('Crucible low split ground chassis', (0, .18, .14), (5.8, 3.3, .28), 'iron', .06)
    art.box('Crucible front receiving ledge', (0, -2.00, .10), (2.5, 1.35, .20), 'steel', .04)
    for side in (-1, 1):
        pelvic_wing(side)
        art.box(f'Crucible side mounting rail {side}', (side * 2.43, .15, .38), (.36, 2.75, .20), 'steel', .035)
        for i in range(6):
            art.box(f'Crucible foundation anchor {side} {i}', (side * 2.72, -1.1 + i * .48, .32), (.13, .13, .08), 'bone', .015)
        for y in (-.83, 1.03):
            foot, knee, shoulder = (side * 2.19, y, .4), (side * 2.70, y, 1.49), (side * 2.05, y * .7, 2.29)
            art.tube(f'Articulated crucible hydraulic support {side} {y}', [foot, knee, shoulder], [.16, .14, .10], 'iron', 10)
            art.tube(f'Crucible visible piston shaft {side} {y}', [(side * 2.08, y - .16, .56), (side * 2.55, y - .16, 1.39)], .070, 'steel', 8)
            art.egg(f'Crucible support knuckle {side} {y}', knee, (.24, .20, .24), 'steel', 12, 6)
            art.ring(f'Crucible ivory hinge bearing {side} {y}', (knee[0], y - .17, knee[2]), .22, .050, 'bone', 'XZ', 16)
            art.egg(f'Crucible hinge pin {side} {y}', (knee[0], y - .23, knee[2]), (.076, .035, .076), 'black', 8, 4)
    # The inner rings descend into a deep concave basin; neither a disc nor a solid bowl.
    shell('Concave crucible inner basin', [(1.82, 1.72), (1.65, 1.84), (1.38, 1.62), (1.0, 1.28),
          (.59, 1.0), (.17, .95), (.17, .78), (.63, .81), (1.11, 1.02), (1.49, 1.37), (1.82, 1.72)],
          'scar', center=(0, -.17, 0), aspect=(1, .82), steps=40)
    shell('Crucible outer iron bowl jacket', [(1.82, 1.68), (1.61, 1.21), (1.14, .67), (.62, .57)],
          'iron', center=(0, -.17, 0), aspect=(1, .82), steps=32)
    art.egg('Recessed crucible amber molten pool', (0, -.17, 1.04), (.75, .57, .045), 'amber', 24, 6)
    for i in range(20):
        a = i * 2 * math.pi / 20
        c, s = math.cos(a), math.sin(a)
        # Alternating tooth lengths leave open sightlines to the suspended specimen.
        bend(f'Radial surgical basin tooth {i}', [(1.76 * c, -.17 + 1.44 * s, 1.71), (1.79 * c, -.17 + 1.46 * s, 2.12),
             (1.44 * c, -.17 + 1.18 * s, 2.31 + (i % 2) * .10), (1.27 * c, -.17 + 1.04 * s, 1.98)], (.075, .006), 'bone', 6, 10)
        art.box(f'Crucible tooth restraint ferrule {i}', (1.80 * c, -.17 + 1.47 * s, 1.67), (.13, .13, .16), 'steel', .020)
    for side in (-1, 1):
        for i in range(4):
            y = -.64 + i * .40
            bend(f'Curved pelvic marrow manifold {side} {i}', [(side * 2.38, y, .47), (side * 3.16, y + .30, 1.48),
                 (side * 2.45, y + .35, 2.71), (side * 1.67, y, 1.73)], (.090, .062), 'steel', 8, 16)
            bend(f'Pelvic vascular manifold insert {side} {i}', [(side * 2.51, y + .10, .43), (side * 2.96, y + .16, 1.7),
                 (side * 2.01, y + .30, 2.60), (side * 1.61, y + .11, 1.79)], (.035, .024), 'skin', 6, 12)
        # A front-open distillation organ, restrained over the bowl, has no Intake heart geometry.
        bend(f'Pelvic suspension crane {side}', [(side * 2.59, .71, 2.35), (side * 2.67, .98, 4.47),
             (side * 1.23, .78, 4.47), (side * .47, .26, 3.81)], (.13, .065), 'iron', 8, 16)
        art.ring(f'Pelvic suspension pivot {side}', (side * 2.36, .67, 3.64), .22, .05, 'steel', 'XZ', 16)
        bend(f'Taut organ upper restraint {side}', [(side * 1.29, .69, 4.13), (side * .76, .46, 4.02),
             (side * .66, -.04, 3.64), (side * .38, -.31, 3.58)], (.037, .027), 'steel', 6, 12)
        bend(f'Living descending restraint {side}', [(side * .41, .05, 3.78), (side * .83, .62, 3.40),
             (side * 1.39, .81, 2.33), (side * 1.58, .69, 1.84)], (.06, .023), 'skin', 6, 12)
    shell('Suspended cut-open fluted distillation organ', [(.19, 2.54), (.36, 2.71), (.54, 3.0),
          (.55, 3.24), (.37, 3.55), (.18, 3.77), (.12, 3.78), (.26, 3.54), (.42, 3.25), (.38, 3.0), (.20, 2.72)],
          'skin', center=(.08, -.03, 0), aspect=(1.32, .69), arc=(-.72, math.pi + .72), steps=24)
    for side in (-1, 1):
        for i in range(4):
            z = 2.78 + i * .21
            bend(f'Organ incised cartilage lamella {side} {i}', [(side * .10, .27, z), (side * .76, .23, z + .1),
                 (side * .74, -.47, z + .13), (side * .25, -.39, z - .04)], (.034, .013), 'scar', 6, 10)
        bend(f'Distillation exposed amber gland {side}', [(side * .11, -.09, 3.59), (side * .37, -.18, 3.30),
             (side * .26, -.15, 2.96), (0, -.03, 2.56)], (.067, .031), 'amber', 8, 14)
        art.stitches(f'Organ anterior incision staples {side}', [(side * .39, -.39, 2.87 + i * .15) for i in range(4)], (.055, 0, .017))
    bend('Descending distilled marrow thread', [(0, -.03, 2.66), (.12, -.17, 2.1), (-.10, -.09, 1.53), (.04, -.17, 1.07)], (.055, .075), 'amber', 8, 16)
    # Split pubic jaws form the pouring spout, with liquid visibly leaving the lip.
    for side in (-1, 1):
        bend(f'Split ivory pouring jaw {side}', [(side * .81, -1.17, 1.77), (side * .67, -1.82, 1.82),
             (side * .42, -2.29, 1.33), (side * .19, -2.36, 1.11)], (.14, .054), 'bone', 8, 16)
        bend(f'Pouring lip retaining rail {side}', [(side * .34, -1.0, 1.45), (side * .52, -1.34, 1.59),
             (side * .26, -2.10, 1.33), (side * .08, -2.31, 1.10)], (.035, .02), 'iron', 6, 12)
    bend('Glowing poured marrow ribbon', [(0, -.75, 1.29), (.02, -1.61, 1.69), (.02, -2.39, 1.22), (.13, -2.27, .26)], (.11, .075), 'amber', 8, 24)
    art.egg('Crucible fresh amber spill', (.13, -2.18, .24), (.63, .43, .032), 'amber', 24, 6)
    for i in range(4):
        art.egg(f'Spill coagulated marrow bead {i}', (-.40 + i * .31, -2.14 + .11 * math.sin(i), .25), (.09, .11, .048), 'scar', 8, 4)
    art.box('Crucible right pressure manifold bank', (2.31, -1.11, .94), (.66, .48, .88), 'iron', .065)
    dial('Crucible right distillation pressure', (2.31, -1.39, 1.11), .23)
    dial('Crucible left drain regulator', (-2.23, -1.18, .75), .22)
    for i in range(4):
        art.box(f'Crucible regulator lever {i}', (2.13 + i * .12, -1.41, .62), (.044, .12, .21), 'bone', .008)
    bend('Crucible posterior vascular return', [(-2.49, 1.26, .42), (-1.47, 2.10, 1.63),
         (1.28, 2.10, 1.89), (2.47, 1.26, .43)], .13, 'skin', 8, 24)
    for i in range(9):
        x = -1.6 + i * .4
        art.ring(f'Posterior return segmented lock {i}', (x, 1.77, 1.49 + .21 * math.cos(x)), .16, .03, 'steel', 'YZ', 12)


def build_scene(name):
    skin_texture()
    (vertebral_furnace if name == 'vertebral_furnace' else marrow_crucible)()
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices),
               'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert triangles <= 30000, (name, triangles)
    assert len(meshes) >= 100, (name, len(meshes))
    assert abs(extent['min'][2]) <= .001 and all(v <= cap for v, cap in zip(extent['size'], CAPS[name])), (name, extent)
    bpy.context.scene['authoring_recipe'] = 'tools/build_foundry_art.py'
    bpy.context.scene['recipe_sha256'] = art.sha(Path(__file__))
    bpy.context.scene['asset_id'] = name
    STATS[name] = {'source_mesh_count': len(meshes), 'vertices': sum(o['vertices'] for o in counts),
                   'triangles': triangles, 'physical_bounds_m': extent, 'source_meshes': counts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS)
    parser.add_argument('--receipt-dir', type=Path, default=art.SCRATCH)
    opts = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    opts.receipt_dir.mkdir(parents=True, exist_ok=True)
    art.SCRATCH = opts.receipt_dir / 'previews'
    art.scenery = build_scene
    path = art.ART / 'manifest.json'
    current = json.loads(path.read_text())
    helper_sha = art.sha(Path(art.__file__))
    assert helper_sha == current['build']['script_sha256'], 'Intake helper drift; do not build'
    for name in ([opts.asset] if opts.asset else IDS):
        print('ART_START ' + name, flush=True)
        entry = art.world_export(name)
        entry['recipe_sha256'] = art.sha(Path(__file__))
        entry['recipe_dependencies'] = {'tools/build_art.py': helper_sha}
        entry['provenance']['authoring_script'] = 'tools/build_foundry_art.py'
        entry['source_mesh_count'] = STATS[name]['source_mesh_count']
        entry['loop_id'] = 'foundry_loop_furnace' if name == 'vertebral_furnace' else 'foundry_loop_crucible'
        entry['facing'] = 'front Blender -Y; exported Godot +Z'
        current['assets'] = [a for a in current['assets'] if a['id'] != name] + [entry]
        assert sum(a['outputs'][0]['bytes'] for a in current['assets'] if a['id'] in IDS) < 4 * 1024 * 1024, 'Foundry GLB budget'
        path.write_text(json.dumps(current, indent=2) + '\n')
        receipt = {**STATS[name], 'asset': entry, 'blender_version': bpy.app.version_string,
                   'render_engine': 'Cycles CPU', 'threads': 4, 'samples': 16,
                   'preview': str(art.SCRATCH / (name + '_preview.png'))}
        (opts.receipt_dir / (name + '_geometry.json')).write_text(json.dumps(receipt, indent=2) + '\n')
        print(f'ART_DONE {name} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
