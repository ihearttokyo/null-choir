"""Image-derived ceiling apparatus; parent owns native builds and world placement."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import sys

sys.dont_write_bytecode = True
SOURCE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE_ROOT / 'tools'))
import build_religious_art as intake

IDS = ('nursery_growth_vault', 'ossuary_sorting_vault', 'inversion_cosmic_membrane', 'heart_arterial_vault')
REFERENCE = 'source/art/references/world-polish-late-01.png'
ATLAS = 'game/assets/art/textures/surface_atlas.png'
RECIPE = 'tools/build_world_atmosphere_art.py'
REFERENCE_SHA = 'f779257d54a32b0d702193b79beceee63df0d96b54f2988a5899e457670dc9a7'
REFERENCES = {asset: {REFERENCE: REFERENCE_SHA} for asset in IDS}
REFERENCES['inversion_cosmic_membrane'] = {
    'source/art/references/inversion-cavity-02.png': '8f3363b3643660733b13e4b76ee9029ccdfa088a97191a106c68248ce7da125e',
}
DEPENDENCIES = ('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_religious_art.py')
CAPS, TRIANGLE_CAP, MESH_CAP = (12, 12, 4.2), 22000, 5
ASSET_BYTE_CAP, GROUP_BYTE_CAP = 2 * 1024 * 1024, 6 * 1024 * 1024
PURPOSES = dict(zip(IDS, (
    'Peripheral growth vessels hang from branching umbilical feeds around an unchanged gestation hero',
    'Suspended hollow bone bundles travel under sorting tracks outside the open rib-bridge passage',
    'Nested inky cavity and violet incisions behind fractured translucent restraints and backward ribs beneath a solid roof',
    'Grown capillary webs and layered bone rib connections frame the unchanged restrained mouth',
)))
STATS = {}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def preflight(asset, output_root, receipt_root, project_root):
    if asset not in IDS:
        raise ValueError('Select one exact atmosphere module ID')
    for root in (Path(project_root).absolute(), Path(output_root).absolute(), Path(receipt_root).absolute()):
        if any(p.is_symlink() for p in (root, *root.parents)):
            raise ValueError('Project/output/receipt roots must not be symlink paths')
    project = Path(project_root).resolve()
    output, receipt = intake.candidate_roots(output_root, receipt_root, project)
    intake.candidate_roots(output, receipt, SOURCE_ROOT)
    inputs = [project / path for path in (*REFERENCES[asset], RECIPE, 'source/art/manifest.json', ATLAS, *DEPENDENCIES)]
    for path in inputs:
        if any(p.is_symlink() for p in (path, *path.parents) if p.is_relative_to(project)) or not path.is_file():
            raise ValueError('Required frozen project input is missing or symlinked: ' + str(path))
    if any(sha(project / path) != digest for path, digest in REFERENCES[asset].items()):
        raise ValueError('Selected atmosphere reference changed')
    manifest = json.loads((project / 'source/art/manifest.json').read_bytes())
    if sha(project / DEPENDENCIES[0]) != manifest['build']['script_sha256']:
        raise ValueError('Shared core helper/manifest drift')
    atlas_record = next(o for a in manifest['assets'] for o in a['outputs'] if o['path'] == ATLAS)
    if sha(project / ATLAS) != atlas_record['sha256']:
        raise ValueError('Shared atlas/manifest drift')
    if sha(project / RECIPE) != sha(__file__):
        raise ValueError('Executed recipe and frozen project recipe must match')
    if sha(project / 'tools/build_religious_art.py') != sha(intake.__file__):
        raise ValueError('Frozen isolated-root helper must match the imported source helper')
    for folder in ('source/art', 'game/assets/art/world', 'game/assets/art/textures', 'previews/frames'):
        if any(p.is_symlink() for p in (output / folder, *(output / folder).parents) if p.is_relative_to(output)):
            raise ValueError('Candidate directories must not be symlinks')
    targets = (output / 'source/art' / (asset + '.blend'), output / 'game/assets/art/world' / (asset + '.glb'),
               output / 'previews' / (asset + '_preview.png'), output / 'previews/frames' / (asset + '_hero.png'),
               receipt / (asset + '_candidate.json'))
    if any((output / 'game/assets/art/world' / (name + '.glb')).is_symlink() for name in IDS):
        raise ValueError('Module export candidates must not be symlinks')
    if any(path.exists() or path.is_symlink() for path in targets):
        raise FileExistsError('Candidate exists; choose fresh roots')
    candidate_atlas = output / ATLAS
    if candidate_atlas.is_symlink() or (candidate_atlas.exists() and sha(candidate_atlas) != atlas_record['sha256']):
        raise ValueError('Candidate atlas is symlinked or changed')
    return output, receipt, project


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--project-root', type=Path, default=SOURCE_ROOT)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--receipt-root', type=Path, required=True)
    return parser.parse_args(argv)


# Repeated physical components use the native shell/bend/mesh helpers.
def growth_vessel(name, x, y, bottom, height):
    r, h = .34, height
    shell(name + ' thick transparent double wall', [(r * .72, 0), (r, .15), (r, h - .16), (r * .68, h),
          (r * .57, h), (r * .88, h - .16), (r * .88, .15), (r * .61, 0), (r * .72, 0)],
          'black', center=(x, y, bottom), steps=16)
    for z in (bottom, bottom + h):
        art.ring(name + f' thick retaining flange {z}', (x, y, z), r * .75, .055, 'iron', segments=16)
    art.egg(name + ' developing red nucleus', (x, y, bottom + h * .43), (.14, .13, h * .19), 'skin', 12, 6)
    art.egg(name + ' incomplete ivory head volume', (x + .06, y - .025, bottom + h * .63), (.12, .1, .14), 'bone', 10, 5)
    for side in (-1, 1):
        bend(name + f' developing curled body edge {side}', [(x, y, bottom + h * .65),
             (x + side * .27, y - .08, bottom + h * .51), (x + side * .19, y - .05, bottom + h * .24),
             (x + side * .04, y, bottom + h * .17)], (.045, .015), 'bone', 5, 8)
        art.tube(name + f' external viewing stave {side}', [(x + side * .35, y, bottom + .15),
                 (x + side * .35, y, bottom + h - .16)], .021, 'bone', 5)
    art.egg(name + ' small amber sampling window', (x, y - .27, bottom + .20), (.044, .03, .06), 'amber', 8, 4)


def nursery_growth_vault():
    with assembly('Growth vault two curved suspension rails and eight carriers'):
        for side in (-1, 1):
            bend(f'Growth vault curved side suspension rail {side}', [(side * 4.91, -5.20, 3.55),
                 (side * 4.71, -1.56, 3.98), (side * 4.72, 2.45, 3.93), (side * 4.91, 5.20, 3.54)], .105, 'iron', 8, 18)
            for i in range(4):
                y = -4.05 + i * 2.70
                art.box(f'Growth vault movable carrier saddle {side} {i}', (side * 4.72, y, 3.74), (.62, .28, .18), 'bone', .02)
                art.tube(f'Growth vault thin independent hanger {side} {i}', [(side * 4.40, y, 2.0 + .15 * (i % 2)),
                         (side * 4.72, y, 3.73)], .038, 'iron', 6)
    with assembly('Eight clear growth vessels and independently modeled developing cores'):
        for side in (-1, 1):
            for i in range(4):
                bottom = .055 + .14 * (i % 2)
                growth_vessel(f'Growth vault suspended vessel {side} {i}', side * 4.40, -4.05 + i * 2.70, bottom, 1.78 + .15 * (i % 2))
    with assembly('Upper branching umbilical manifold and split peripheral returns'):
        for side in (-1, 1):
            bend(f'Growth vault long umbilical arterial main {side}', [(side * 4.49, -5.1, 3.20),
                 (side * 3.67, -1.70, 3.61), (side * 3.82, 2.10, 3.64), (side * 4.52, 5.1, 3.18)], .105, 'skin', 8, 16)
            for i in range(4):
                y = -4.05 + i * 2.7
                bend(f'Growth vault branched umbilical feed {side} {i}', [(side * 3.98, y, 3.43),
                     (side * 4.10, y + .41, 3.11), (side * 4.58, y + .14, 2.45), (side * 4.40, y, 1.83 + .29 * (i % 2))], .055, 'skin', 6, 10)
        for y in (-4.89, 4.89):
            bend(f'Growth vault overhead bifurcated restraint {y}', [(-4.52, y, 3.20), (-2.03, y, 4.00),
                 (2.03, y, 4.00), (4.52, y, 3.20)], .065, 'bone', 6, 14)
    with assembly('Articulated cold glass roots and small observation taps'):
        for side in (-1, 1):
            for i in range(4):
                y = -4.05 + i * 2.70
                bend(f'Growth vault glass root and ivory restraint {side} {i}', [(side * 4.40, y, .15),
                     (side * 4.75, y + .35, .48), (side * 5.10, y + .23, 1.40), (side * 5.13, y, 2.35)], .049, 'black', 6, 10)
                art.box(f'Growth vault root observation tap {side} {i}', (side * 5.13, y, 2.4), (.15, .22, .21), 'iron', .016)
                art.egg(f'Growth vault root amber control {side} {i}', (side * 5.13, y - .14, 2.41), (.043, .03, .05), 'amber', 8, 4)


def ossuary_sorting_vault():
    with assembly('Sorting vault paired bone-transfer tracks and segmented carriers'):
        for side in (-1, 1):
            for offset in (-.18, .18):
                art.tube(f'Sorting vault outer longitudinal track {side} {offset}', [(side * 4.37 + offset, -5.18, 3.63),
                         (side * 4.37 + offset, 5.18, 3.63)], .065, 'iron', 6)
            for i in range(4):
                y = -4.05 + i * 2.7
                art.box(f'Sorting vault articulated rolling carrier {side} {i}', (side * 4.37, y, 3.53), (.73, .32, .17), 'iron', .018)
                for dy in (-.13, .13):
                    art.ring(f'Sorting vault carrier wheel {side} {i} {dy}', (side * 4.37, y + dy, 3.63), .19, .045, 'bone', 'XZ', 12)
    with assembly('Eight suspended open hollow-bone sorting bundles'):
        for side in (-1, 1):
            for i in range(4):
                x, y = side * 4.13, -4.05 + i * 2.70
                bottom = .13 * (i % 2)
                for j in range(6):
                    a = j * math.tau / 6
                    xx, yy = x + .29 * math.cos(a), y + .29 * math.sin(a)
                    h = 1.46 + .10 * (j % 3)
                    shell(f'Sorting vault hollow recovered bone {side} {i} {j}', [(.11, 0), (.14, .11), (.065, .36), (.061, h - .32),
                          (.14, h - .10), (.12, h), (.075, h), (.037, h - .32), (.038, .36), (.065, 0), (.11, 0)],
                          'bone', center=(xx, yy, bottom), steps=10)
                for z in (bottom + .24, bottom + 1.31):
                    art.ring(f'Sorting vault open bundle restraint {side} {i} {z}', (x, y, z), .48, .058, 'iron', segments=16)
                art.tube(f'Sorting vault bundle suspension stem {side} {i}', [(x, y, bottom + 1.55), (side * 4.37, y, 3.50)], .052, 'iron', 6)
    with assembly('Irregular overhead skeletal lattice and open central vault span'):
        for y in (-4.84, -.88, 3.73):
            for side in (-1, 1):
                bend(f'Sorting vault corbelled exterior rib {side} {y}', [(side * 5.10, y, 2.01),
                     (side * 4.20, y, 3.61), (side * 2.75, y, 3.90), (side * 1.62, y, 3.71)], .105, 'bone', 8, 12)
                art.tube(f'Sorting vault diagonal exterior bone lattice {side} {y}', [(side * 4.50, y - .11, 3.40),
                         (side * 3.11, y + 1.22, 3.74)], .05, 'bone', 6)
        art.tube('Sorting vault high axial restraint over clear passage', [(0, -5.09, 3.90), (0, 5.09, 3.90)], .05, 'iron', 6)
    with assembly('Marrow sorting taps and branched exterior return anatomy'):
        for side in (-1, 1):
            bend(f'Sorting vault exterior marrow collector {side}', [(side * 5.28, -5.12, 2.52),
                 (side * 5.40, -1.62, 2.94), (side * 5.19, 2.41, 2.93), (side * 5.31, 5.12, 2.52)], .065, 'skin', 6, 16)
            for i in range(4):
                y = -4.05 + i * 2.7
                art.egg(f'Sorting vault amber inspection stop {side} {i}', (side * 4.37, y - .23, 3.39), (.045, .035, .06), 'amber', 8, 4)
                art.tube(f'Sorting vault recovered marrow branch {side} {i}', [(side * 4.13, y, .39),
                         (side * 4.81, y + .22, 1.30), (side * 5.29, y, 2.66)], [.041, .031, .027], 'skin', 5)


def inversion_cosmic_membrane():
    with assembly('Three separated faceted cosmic-depth layers with actual broken openings'):
        depth = [shell('Cosmic restraint recessed inky cavity core', [(.04, 3.87), (.74, 3.84), (1.46, 3.74),
                       (2.08, 3.61), (2.08, 3.65), (1.46, 3.78), (.74, 3.88), (.04, 3.91), (.04, 3.87)],
                       'black', steps=32)]
        # Rise inward beneath the unchanged roof; retain the original outer footprint.
        for row, (r, z) in enumerate([(5.22, 2.37), (4.11, 2.99), (2.96, 3.39)]):
            for i in range(8):
                a = i * math.tau / 8
                for part, arc in enumerate(((a + .10, a + .63), (a + .63, a + math.tau / 8 + .08))):
                    # Stagger genuine fractures; recessed bridges replace the old wide roof gaps.
                    if part and i == row * 2 + 1:
                        continue
                    radius = r - (.12 if part or (row + i) % 5 == 0 else 0)
                    shard = shell(f'Cosmic restraint thick depth shard {row} {i} {part}',
                                  [(radius, z), (radius * .82, z + .18), (radius * .66, z + .46),
                                   (radius * .66, z + .50), (radius * .82, z + .22), (radius, z + .04), (radius, z)],
                                  'black', arc=arc, steps=8)
                    for j, vertex in enumerate(shard.data.vertices):
                        if j // 9 in (1, 2, 3, 4):
                            angle = math.atan2(vertex.co.y, vertex.co.x)
                            cut = math.sin(angle * 19 + row * 2.3)
                            vertex.co.x *= .98 + .02 * cut
                            vertex.co.y *= .98 + .02 * cut
                            vertex.co.z += .045 * cut
                    shard.data.update()
                    depth.append(shard)
                    rim = [tuple(v.co) for v in shard.data.vertices[18:27]]
                    art.tube(f'Cosmic restraint violet incised cavity lip {row} {i} {part}', rim, .035, 'amber', 5)
                    if not part and i % 3 == row % 3:
                        art.tube(f'Cosmic restraint short radial incision {row} {i}',
                                 [tuple(shard.data.vertices[j].co) for j in (9, 18)], .024, 'amber', 5)
        for shard in depth:
            uv = shard.data.uv_layers.new(name='Original compact cosmic pixel field')
            for loop in shard.data.loops:
                p = shard.data.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = ((p.x + 5.5) / 11, (p.y + 5.5) / 11)
    with assembly('Fractured translucent restrained membranes and separate incision rims'):
        for i in range(7):
            a = i * math.tau / 7
            r = 4.67
            verts = [(r * math.cos(a), r * math.sin(a), 2.57),
                     (r * math.cos(a + .39), r * math.sin(a + .39), 2.84),
                     (3.75 * math.cos(a + .28), 3.75 * math.sin(a + .28), 2.61),
                     (3.89 * math.cos(a + .04), 3.89 * math.sin(a + .04), 2.25)]
            # A closed thin folded slab retains independent broken edges and modeled thickness.
            slab = verts + [(x, y, z - .04) for x, y, z in verts]
            faces = [(0, 1, 2), (0, 2, 3), (6, 5, 4), (7, 6, 4)]
            faces += [(j, (j + 1) % 4, (j + 1) % 4 + 4, j + 4) for j in range(4)]
            art.mesh(f'Cosmic restraint translucent folded fracture {i}', slab, faces, 'skin')
            for edge in ((0, 1), (1, 2), (2, 3)):
                art.tube(f'Cosmic restraint separate incision border {i} {edge}', [verts[edge[0]], verts[edge[1]]], .024, 'amber', 5)
    with assembly('Upside-down articulated surgical ribs and pointed peripheral hooks'):
        for side in (-1, 1):
            for i in range(5):
                y = -4.58 + i * 2.22
                bend(f'Cosmic restraint inverted suspended rib {side} {i}', [(side * 4.89, y, 3.85),
                     (side * 3.68, y + .10, 3.14), (side * 3.62, y + .10, 1.04), (side * 4.18, y, .061)], (.11, .061), 'bone', 8, 14)
                art.tube(f'Cosmic restraint inverted rib joint {side} {i}', [(side * 4.58, y, 3.83), (side * 4.04, y, 2.89)], .063, 'iron', 6)
    with assembly('Thin multi-depth suspension ties and small violet orientation controls'):
        for i in range(12):
            a = i * math.tau / 12
            bend(f'Cosmic restraint fine suspension tie {i}', [(5.14 * math.cos(a), 5.14 * math.sin(a), 3.80),
                 (4.63 * math.cos(a), 4.63 * math.sin(a), 3.23), (3.93 * math.cos(a), 3.93 * math.sin(a), 2.84),
                 (3.16 * math.cos(a), 3.16 * math.sin(a), 2.52)], .026, 'iron', 5, 11)
            art.egg(f'Cosmic restraint small violet latch {i}', (4.63 * math.cos(a), 4.63 * math.sin(a), 3.21), (.042, .042, .06), 'amber', 8, 4)


def heart_arterial_vault():
    with assembly('Four layered overhead rib spans and peripheral load tendons'):
        for y in (-4.78, -1.62, 1.83, 4.77):
            for side in (-1, 1):
                bend(f'Arterial vault separated thick costal connection {side} {y}', [(side * 5.14, y, .10),
                     (side * 4.72, y, 2.82), (side * 2.38, y, 3.85), (side * .82, y, 3.72)], (.10, .065), 'bone', 8, 14)
                bend(f'Arterial vault second inset rib layer {side} {y}', [(side * 4.80, y + .30, 1.02),
                     (side * 4.21, y + .30, 2.84), (side * 2.91, y + .27, 3.38), (side * 1.58, y + .21, 3.40)], .062, 'bone', 6, 12)
    with assembly('Grown deep-red arterial mains with split branching capillary trees'):
        for side in (-1, 1):
            bend(f'Arterial vault long grown peripheral artery {side}', [(side * 4.28, -5.15, 2.82),
                 (side * 3.73, -1.50, 3.60), (side * 4.05, 2.50, 3.43), (side * 4.35, 5.13, 2.85)], .15, 'skin', 8, 18)
            for i in range(6):
                y = -4.25 + i * 1.68
                bend(f'Arterial vault smaller feeder branch {side} {i}', [(side * 4.17, y, 3.21),
                     (side * 3.61, y + .31, 3.17), (side * 2.73, y + .63, 3.26), (side * 1.70, y + .47, 3.42)], (.072, .019), 'skin', 6, 12)
                bend(f'Arterial vault descending exterior capillary {side} {i}', [(side * 4.17, y, 3.19),
                     (side * 4.89, y + .41, 2.46), (side * 5.23, y + .32, 1.39), (side * 5.13, y, .11)], (.063, .02), 'skin', 6, 12)
    with assembly('Layered peripheral capillary web and deep recessed tissue pockets'):
        for side in (-1, 1):
            for i in range(5):
                y = -3.92 + i * 1.74
                for j in range(3):
                    z = .75 + j * .66
                    bend(f'Arterial vault diagonal grown web strand {side} {i} {j}', [(side * 5.03, y, z),
                         (side * 4.98, y + .45, z + .43), (side * 4.85, y + 1.23, z + .48), (side * 5.0, y + 1.65, z + .54)],
                         (.037, .015), 'skin', 5, 8)
                shell(f'Arterial vault concave tissue pocket {side} {i}', [(.29, .96), (.34, 1.23), (.25, 1.69),
                      (.13, 1.74), (.09, 1.68), (.17, 1.23), (.20, .96), (.29, .96)], 'skin',
                      center=(side * 5.09, y + .76, 0), arc=(.12, math.pi - .12), steps=10)
    with assembly('Independent bone artery clamps and narrow amber observation nodes'):
        for side in (-1, 1):
            for i in range(6):
                y = -4.25 + i * 1.68
                art.ring(f'Arterial vault main artery cartilage clamp {side} {i}', (side * 4.15, y, 3.22), .20, .035, 'bone', 'XZ', 12)
                art.box(f'Arterial vault overhead fastening collar {side} {i}', (side * 4.15, y, 3.71), (.33, .21, .12), 'iron', .01)
                art.egg(f'Arterial vault amber sampling node {side} {i}', (side * 4.15, y - .15, 3.58), (.037, .031, .045), 'amber', 8, 4)

def export_details(data):
    """Measure the actual GLB container and embedded PNGs, not scene claims."""
    if len(data) < 28 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise ValueError('Invalid GLB container')
    n, kind = struct.unpack_from('<I4s', data, 12)
    if kind != b'JSON' or 28 + n > len(data):
        raise ValueError('Missing GLB JSON chunk')
    gltf = json.loads(data[20:20 + n])
    size, kind = struct.unpack_from('<I4s', data, 20 + n)
    if kind != b'BIN\0' or 28 + n + size != len(data):
        raise ValueError('Invalid embedded GLB binary chunk')
    binary, textures = data[28 + n:], []
    assert len(gltf['buffers']) == 1 and 'uri' not in gltf['buffers'][0]
    assert 0 <= len(binary) - gltf['buffers'][0]['byteLength'] <= 3
    assert gltf.get('images')
    for im in gltf['images']:
        assert 'bufferView' in im and 'uri' not in im and im['mimeType'] == 'image/png'
        view = gltf['bufferViews'][im['bufferView']]
        offset, length = view.get('byteOffset', 0), view['byteLength']
        assert offset >= 0 and length >= 24 and offset + length <= len(binary)
        png = binary[offset:offset + length]
        assert png[:8] == b'\x89PNG\r\n\x1a\n' and png[12:16] == b'IHDR'
        w, h = struct.unpack_from('>II', png, 16)
        assert 0 < w <= 192 and 0 < h <= 64, (im, w, h)
        textures.append({'name': im.get('name', ''), 'bytes': length, 'dimensions': [w, h],
                         'sha256': hashlib.sha256(png).hexdigest()})
    return gltf, binary, textures


def setup():
    scene = original_setup()
    if current_asset != 'inversion_cosmic_membrane':
        foundry.skin_texture()
    art.M.pop('steel')
    art.M.pop('scar')
    art.M['bone'].diffuse_color = art.rgba('#b7ae96')
    art.M['bone'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = art.rgba('#b7ae96')
    image = bpy.data.images.load(str(art.OUT / 'textures/surface_atlas.png'), check_existing=True)
    image.pack()
    nodes = art.M['iron'].node_tree
    tex = nodes.nodes.new('ShaderNodeTexImage')
    tex.image, tex.interpolation = image, 'Closest'
    nodes.links.new(tex.outputs['Color'], nodes.nodes.get('Principled BSDF').inputs['Base Color'])
    if current_asset == 'nursery_growth_vault':
        art.M['black'] = art.material('Cold growth-vessel viewing glass', '#85c2cf', rough=.18)
        mat = art.M['black']
        mat.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .18
        mat.surface_render_method = 'DITHERED'
    if current_asset == 'inversion_cosmic_membrane':
        # Original native pixel field; the retained GPT reference is never pasted or edited.
        image = bpy.data.images.new('Original restrained cosmic depth', width=128, height=64, alpha=True)
        pixels = []
        for y in range(64):
            for x in range(128):
                vein = (x + round(12 * math.sin(y * .17))) % 47
                shade = .003 + .005 * (1 + math.sin(x * .13 + y * .07))
                color = (shade * .49, shade * .19, shade)
                if vein < 2:
                    color = (.018, .006, .035)
                if (x * 43 + y * 71 + x * y * 7) % 97 == 0:
                    color = (.48, .39, .68)
                pixels.extend((*color, 1))
        image.pixels.foreach_set(pixels)
        image.pack()
        art.M['black'] = art.material('Broken black violet cosmic depth', '#0d0619', rough=.95, image=image)
        nodes = art.M['black'].node_tree
        tex = next(n for n in nodes.nodes if n.type == 'TEX_IMAGE')
        shader = nodes.nodes.get('Principled BSDF')
        nodes.links.new(tex.outputs['Color'], shader.inputs['Emission Color'])
        shader.inputs['Emission Strength'].default_value = .5
        art.M['skin'] = art.material('Translucent fractured violet restraint', '#4a2c73', rough=.35)
        art.M['skin'].node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .28
        art.M['skin'].surface_render_method = 'DITHERED'
        shader = art.M['amber'].node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = art.rgba('#9c52e6')
        shader.inputs['Emission Color'].default_value = art.rgba('#9c52e6')
        shader.inputs['Emission Strength'].default_value = 1.1
    return scene


def build_scene(name):
    globals()[name]()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Set the real vertex origin to ground-centred, not a rounded metadata approximation.
    points = [v.co for obj in meshes for v in obj.data.vertices]
    assert all(max(p[i] for p in points) - min(p[i] for p in points) <= cap for i, cap in enumerate(CAPS)), name
    shift = [(min(p[i] for p in points) + max(p[i] for p in points)) / 2 for i in (0, 1)]
    shift.append(min(p.z for p in points))
    for obj in meshes:
        for vertex in obj.data.vertices:
            vertex.co -= art.Vector(shift)
        obj.data.update()
        # The dark floor tile feeds iron, not the pale wall tile used by older monuments.
        if obj.data.materials[0] == art.M['iron']:
            uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Compact dark iron tile')
            for loop in obj.data.loops:
                p = obj.data.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = ((p.x * .19 % 1) / 3, p.y * .19 % 1)
    bpy.context.view_layer.update()
    extent = art.bounds(meshes)
    counts = [{'name': o.name, 'vertices': len(o.data.vertices),
               'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'bounds_m': art.bounds([o])} for o in meshes]
    triangles = sum(o['triangles'] for o in counts)
    assert triangles <= TRIANGLE_CAP and abs(extent['min'][2]) <= .001, (name, triangles, extent)
    assert all(v <= cap for v, cap in zip(extent['size'], CAPS)), (name, extent)
    groups = [c.name for c in bpy.context.scene.collection.children if c.objects]
    assert len(groups) >= 4
    STATS[name] = {'source_mesh_count': len(meshes), 'triangles': triangles, 'physical_bounds_m': extent,
                   'source_hierarchy_groups': len(groups), 'assembly_names': groups, 'source_meshes': counts}
    scene = bpy.context.scene
    scene['asset_id'], scene['authoring_recipe'], scene['recipe_sha256'] = name, RECIPE, sha(__file__)
    scene['reference_images'] = json.dumps(REFERENCES[name])
    scene['machine_purpose'] = PURPOSES[name]
    scene['source_root'], scene['project_root'] = 'authoring repository root', 'dependency snapshot root'
    scene['recipe_dependencies'] = json.dumps({path: sha(current_project / path) for path in DEPENDENCIES}, sort_keys=True)


def main():
    global bpy, art, foundry, assembly, bend, shell, original_setup, current_asset, current_project
    opts = arguments(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    output, receipt, project = preflight(opts.asset, opts.output_root, opts.receipt_root, opts.project_root)
    sys.path.insert(0, str(project / 'tools'))
    import bpy
    import build_art as art
    import build_foundry_art as foundry
    assert all(Path(m.__file__).resolve().parent == project / 'tools' for m in (art, foundry)), 'Native helpers must come from the caller project'
    intake.bpy, intake.art = bpy, art
    assembly, bend, shell = intake.assembly, foundry.bend, foundry.shell
    current_asset, current_project, original_setup = opts.asset, project, art.setup
    manifest_data = (project / 'source/art/manifest.json').read_bytes()
    dependencies = {path: sha(project / path) for path in DEPENDENCIES}
    atlas_digest = sha(project / ATLAS)
    manifest = json.loads(manifest_data)
    assert dependencies['tools/build_art.py'] == manifest['build']['script_sha256']
    assert any(o['path'] == ATLAS and o['sha256'] == atlas_digest for a in manifest['assets'] for o in a['outputs'])
    art.ROOT, art.ART, art.OUT, art.SCRATCH = output, output / 'source/art', output / 'game/assets/art', output / 'previews'
    art.setup, art.scenery = setup, build_scene
    atlas_copy = art.target(output / ATLAS)
    if not atlas_copy.exists():
        shutil.copyfile(project / ATLAS, atlas_copy)
    print('ART_START ' + opts.asset, flush=True)
    entry = art.world_export(opts.asset)
    entry.update({key: STATS[opts.asset][key] for key in ('source_mesh_count', 'source_hierarchy_groups', 'assembly_names')})
    entry.update(recipe_sha256=sha(__file__), recipe_dependencies=dependencies,
                 reference_images=[{'path': path, 'sha256': digest} for path, digest in REFERENCES[opts.asset].items()], level_id=opts.asset.split('_', 1)[0],
                 machine_purpose=PURPOSES[opts.asset], texture_dependencies={ATLAS: atlas_digest},
                 facing='front Blender -Y; exported Godot +Z', collision='none; parent mounts under existing ceilings')
    entry['provenance']['authoring_script'] = RECIPE
    data = (output / entry['outputs'][0]['path']).read_bytes()
    _, _, textures = export_details(data)
    assert entry['loop_id'] is None and entry['runtime_mesh_nodes'] <= MESH_CAP
    assert entry['material_count'] <= MESH_CAP and entry['triangles'] == STATS[opts.asset]['triangles']
    assert len(data) < ASSET_BYTE_CAP
    total = sum(p.stat().st_size for name in IDS if (p := output / 'game/assets/art/world' / (name + '.glb')).is_file())
    assert total < GROUP_BYTE_CAP, total
    payload = {**STATS[opts.asset], 'asset': entry, 'output_root': str(output), 'source_root': str(SOURCE_ROOT),
               'project_root': str(project), 'blender_version': bpy.app.version_string, 'embedded_textures': textures,
               'embedded_texture_bytes': sum(t['bytes'] for t in textures), 'four_module_bytes_after_export': total,
               'preview': str(art.SCRATCH / (opts.asset + '_preview.png')),
               'preview_sha256': sha(art.SCRATCH / (opts.asset + '_preview.png')),
               'manifest_sha256_read': hashlib.sha256(manifest_data).hexdigest(), 'status': 'native_candidate_not_integrated'}
    receipt.mkdir(parents=True, exist_ok=True)
    with (receipt / (opts.asset + '_candidate.json')).open('x') as file:
        file.write(json.dumps(payload, indent=2) + '\n')
    print(f'ART_DONE {opts.asset} {entry["outputs"][0]["sha256"]}', flush=True)


if __name__ == '__main__':
    main()
