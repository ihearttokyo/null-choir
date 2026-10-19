"""Unadopted glyph candidate: background Blender CPU4, explicit fresh external roots."""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import stat
import sys

sys.dont_write_bytecode = True
SOURCE_ROOT = Path(__file__).resolve().parents[1]
REFERENCE = 'source/art/references/marker-identities-v2.png'
REFERENCE_SHA = '061ac88b9d4ff2ae70da4b1996cc1f6d4cda92bf05a698d5887159a8fb2475f0'
HELPER_SHA = {'tools/build_art.py': '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581',
              'tools/build_hud_art.py': 'c224381a98b316b7d41d5c77d0f95f9f3bbea061a99eaa3d56d6bdce6ad25a26'}
NAMES = ('ammo', 'health', 'armor', 'key', 'weapon', 'story', 'checkpoint', 'exit',
         'seal_blood', 'seal_ivory', 'impact_tool', 'rivet_pistol', 'scattergun',
         'sawtooth_repeater', 'marrow_launcher', 'choir_disruptor')
IVORY_RGBA = (232, 221, 196, 255)
CONTRACTS = {'purposes': {k: k for k in NAMES[:8]},
             'seals': {'blood': 'seal_blood', 'ivory': 'seal_ivory'},
             'weapons': list(NAMES[10:]),
             'hud': {'heart': 'health', 'shield': 'armor', 'ammo': 'ammo',
                     **{k: k for k in NAMES[8:]}},
             'survey': {k: k for k in ('key', 'story', 'checkpoint', 'exit')}}
ISOLATION_DIRS = {'BLENDER_USER_CONFIG': 'config', 'BLENDER_USER_DATAFILES': 'datafiles',
                  'BLENDER_USER_SCRIPTS': 'scripts', 'BLENDER_USER_EXTENSIONS': 'extensions',
                  'BLENDER_USER_RESOURCES': 'resources', 'TMPDIR': 'tmp'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_inputs(recipe_sha):
    pins = {**HELPER_SHA, REFERENCE: REFERENCE_SHA, 'tools/build_marker_glyphs.py': recipe_sha}
    for relative, digest in pins.items():
        path = SOURCE_ROOT / relative
        if (path.resolve() != path or not path.is_file() or
                getattr(path.stat(), 'st_flags', 0) & getattr(stat, 'SF_DATALESS', 0) or
                sha(path) != digest):
            raise ValueError('missing, aliased, nonresident or drifted input: ' + relative)


def external_root(root):
    root = Path(root)
    if not root.is_absolute() or root.resolve() != root or any(p.is_symlink() for p in (root, *root.parents)):
        raise ValueError('root must be absolute, canonical and symlink-free')
    if root == SOURCE_ROOT or root in SOURCE_ROOT.parents or SOURCE_ROOT in root.parents:
        raise ValueError('root must be outside original project')
    for ancestor in (root, *root.parents):
        if (ancestor / 'game/project.godot').exists() or (ancestor / 'tools/build_art.py').exists():
            raise ValueError('root must not be within any original project')
    return root


def prepare_paths(root):
    root = external_root(root)
    if root.exists():
        raise ValueError('refusing existing or partial candidate root')
    return {'blend': root / 'source/art/marker_glyphs.blend',
            'atlas': root / 'game/assets/art/hud/marker_glyphs.png',
            'metadata': root / 'game/assets/art/hud/marker_glyphs.json',
            'receipt': root / 'NATIVE-GLYPH-RECEIPT.json'}


def check_isolation(root, env):
    root = external_root(root)
    if not root.is_dir():
        raise ValueError('isolation root must already exist')
    paths = {}
    for variable, child in ISOLATION_DIRS.items():
        path = root / child
        if env.get(variable) != str(path) or path.resolve() != path or not path.is_dir():
            raise ValueError('missing or unowned isolation path: ' + variable)
        paths[variable] = str(path)
    return paths


def arc(cx, cy, outer, inner, start, end, steps=12):
    angles = [math.radians(start + (end - start) * i / steps) for i in range(steps + 1)]
    return ([(cx + outer * math.cos(a), cy + outer * math.sin(a)) for a in angles] +
            [(cx + inner * math.cos(a), cy + inner * math.sin(a)) for a in reversed(angles)])


def disk(cx, cy, radius):
    return [(cx + radius * math.cos(i * math.tau / 20),
             cy + radius * math.sin(i * math.tau / 20)) for i in range(20)]


def geometry(name):
    """Independent extruded outlines, no dark hole decals or reduced 3D props."""
    parts = []
    def add(label, polygon):
        if sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(polygon, polygon[1:]+polygon[:1])) < 0:
            polygon = list(reversed(polygon))
        parts.append((label, polygon))
    def bar(label, x, y, width, height):
        add(label, [(x-width/2, y-height/2), (x+width/2, y-height/2),
                    (x+width/2, y+height/2), (x-width/2, y+height/2)])
    def spear(label, x, bottom, top, width):
        add(label, [(x, top), (x+width/2, top-.13), (x+width*.27, top-.13),
                    (x+width*.27, bottom+.12), (x, bottom),
                    (x-width*.27, bottom+.12), (x-width*.27, top-.13), (x-width/2, top-.13)])
    def split_ring(label, cx, cy, outer, inner, gap=18):
        add(label+' right', arc(cx, cy, outer, inner, -90+gap, 90-gap))
        add(label+' left', arc(cx, cy, outer, inner, 90+gap, 270-gap))
    def diamond(label, cx, cy, width, height, inset):
        outer = [(cx, cy+height), (cx+width, cy), (cx, cy-height), (cx-width, cy)]
        inner = [(cx, cy+height-inset), (cx+width-inset, cy),
                 (cx, cy-height+inset), (cx-width+inset, cy)]
        for i in range(4):
            j = (i+1) % 4
            add(label+' side '+str(i), [outer[i], outer[j], inner[j], inner[i]])
    def fork(label, bottom, top, width):
        add(label, [(-width, top-.05), (-width+.055, top), (-width+.055, bottom+.15),
                    (-.07, bottom+.09), (.07, bottom+.09), (width-.055, bottom+.15),
                    (width-.055, top), (width, top-.05), (width, bottom+.11),
                    (.07, bottom), (-.07, bottom), (-width, bottom+.11)])
    if name == 'ammo':
        for i, x in enumerate((-.25, 0, .25)):
            spear('cartridge '+str(i), x, -.34, .40 if i == 1 else .25, .17)
    elif name == 'health':
        add('isolated droplet', [(0,.40),(.09,.22),(.08,.14),(0,.10),(-.08,.14),(-.09,.22)])
        add('cupped vessel', [(-.36,.08),(-.28,.12),(-.23,.02),(-.12,-.02),(.12,-.02),
                             (.23,.02),(.28,.12),(.36,.08),(.35,-.12),(.22,-.27),
                             (0,-.36),(-.22,-.27),(-.35,-.12)])
    elif name == 'armor':
        split_ring('open protective crescents', 0, .01, .37, .25, 30)
        add('protected core', disk(0,.03,.145))
        bar('lower plate stem', 0, -.28, .09, .24)
    elif name == 'key':
        fork('open key fork', -.02, .40, .19)
        add('key stem', [(-.055,-.01),(.055,-.01),(.055,-.28),(0,-.40),(-.055,-.28)])
    elif name == 'weapon':
        for side in (-1,1):
            add('horizontal cradle '+str(side), [(side*.15,-.055),(side*.40,-.055),
                (side*.40,.11),(side*.34,.11),(side*.34,.015),(side*.15,.015)])
        split_ring('central bearing', 0, .015, .13, .07, 0)
    elif name == 'story':
        for side in (-1,1):
            add('open page '+str(side), [(side*.045,-.31),(side*.30,-.22),
                (side*.30,.31),(side*.18,.30),(side*.045,.23)])
            add('separate page cover '+str(side), [(side*.045,-.40),(side*.38,-.27),
                (side*.38,.31),(side*.34,.31),(side*.34,-.24),(side*.045,-.36)])
    elif name == 'checkpoint':
        add('recovery head', disk(0,.29,.12))
        for side in (-1,1):
            add('splayed recovery leg '+str(side), [(side*.05,.11),(side*.16,.14),
                (side*.39,-.36),(side*.29,-.36),(side*.11,.035)])
        add('central recovery spine', [(-.045,.04),(.045,.04),(.025,-.26),(0,-.33),(-.025,-.26)])
    elif name == 'exit':
        for i, (top, width) in enumerate(((.32,.40),(.07,.27),(-.18,.14))):
            add('descent wedge '+str(i), [(-width,top),(width,top),(width-.085,top-.14),(-width+.085,top-.14)])
    elif name == 'seal_blood':
        fork('blood fork', .10, .41, .23)
        split_ring('blood lower handle', 0, -.30, .12, .06, 0)
        add('isolated blood droplet', [(0,.04),(.075,-.065),(.05,-.10),(0,-.12),(-.05,-.10),(-.075,-.065)])
    elif name == 'seal_ivory':
        spear('central antler', 0, .15, .42, .09)
        for side in (-1,1):
            add('lateral antler '+str(side), [(side*.09,.13),(side*.24,.20),
                (side*.30,.38),(side*.24,.42),(side*.22,.26),(side*.09,.21)])
        diamond('open ivory lozenge', 0, .04, .13, .17, .06)
        split_ring('slit ivory handle', 0, -.30, .12, .06, 22)
    elif name == 'impact_tool':
        split_ring('split impact ring', 0, 0, .28, .20, 18)
        add('impact center', disk(0,0,.14))
        for side in (-1,1):
            add('impact axial point '+str(side), [(-.06,side*.24),(0,side*.41),(.06,side*.24)])
    elif name == 'rivet_pistol':
        spear('single rivet lance', 0, -.41, .41, .27)
    elif name == 'scattergun':
        spear('central scatter lance', 0, -.40, .41, .17)
        for side in (-1,1):
            add('splayed scatter lance '+str(side), [(side*.11,-.30),(side*.32,.16),
                (side*.24,.22),(side*.18,.12)])
    elif name == 'sawtooth_repeater':
        for i, width in enumerate((.78,.60,.42)):
            bar('repeater bar '+str(i), 0, .23-i*.23, width, .12)
    elif name == 'marrow_launcher':
        diamond('hollow marrow lance', 0, 0, .15, .42, .075)
    elif name == 'choir_disruptor':
        split_ring('split choir resonator', 0, 0, .30, .20, 26)
        add('isolated choir spine', [(0,.42),(.045,.30),(.045,-.30),(0,-.42),(-.045,-.30),(-.045,.30)])
    else:
        raise ValueError('unknown glyph: '+name)
    return parts


def metadata(pixels, counts, recipe_sha):
    if len(pixels) != 256*256*4 or set(counts) != set(NAMES):
        raise ValueError('invalid atlas dimensions or glyph counts')
    if any(type(v) is not int or v <= 0 for v in counts.values()) or sum(counts.values()) >= 10000:
        raise ValueError('native triangle budget')
    sprites = {}
    for index, name in enumerate(NAMES):
        x, y = index%4*64, index//4*64
        occupied = []
        for cy in range(64):
            for cx in range(64):
                offset = ((y+cy)*256+x+cx)*4
                color = tuple(pixels[offset:offset+4])
                if color not in ((0,0,0,0), IVORY_RGBA):
                    raise ValueError('fixed ivory palette and binary alpha required')
                if color[3]:
                    if not (4 <= cx < 60 and 4 <= cy < 60):
                        raise ValueError('gutter bleed: '+name)
                    occupied.append((cx,cy))
        if not occupied:
            raise ValueError('empty glyph: '+name)
        low = [min(p[i] for p in occupied) for i in (0,1)]
        high = [max(p[i] for p in occupied) for i in (0,1)]
        sprites[name] = {'region':[x,y,64,64], 'content_rect':low+[high[i]-low[i]+1 for i in (0,1)],
                         'alpha_pixels':len(occupied), 'triangles':counts[name]}
    return {'atlas':'res://assets/art/hud/marker_glyphs.png', 'dimensions':[256,256],
            'cell_size':[64,64], 'columns':4, 'clear_border':4, 'filter':'nearest',
            'palette':{'ivory':'#e8ddc4'}, 'binary_alpha':True, 'sprites':sprites,
            'contracts':CONTRACTS, 'scene_collection_names':list(NAMES),
            'reference_sha256':REFERENCE_SHA, 'recipe_sha256':recipe_sha,
            'recipe_dependencies':HELPER_SHA, 'native_render':True,
            'render_engine':'CYCLES', 'render_device':'CPU', 'render_threads':4,
            'recognition_sizes':[16,24,32], 'recognition_validated':False}


def check_sizes(runtime_bytes, source_bytes):
    if not (0 < runtime_bytes < 128*1024 and 0 < source_bytes < 8*1024*1024):
        raise ValueError('runtime/source byte budget exceeded')


def load_helper(name, relative):
    spec = importlib.util.spec_from_file_location(name, SOURCE_ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build(output, isolation, recipe_sha):
    paths = prepare_paths(output)
    user_paths = check_isolation(isolation, os.environ)
    output, isolation = Path(output), Path(isolation)
    if output == isolation or output in isolation.parents or isolation in output.parents:
        raise ValueError('candidate and isolation roots must be disjoint')
    check_inputs(recipe_sha)
    import bpy
    from mathutils import Vector
    if not bpy.app.background:
        raise ValueError('background Blender only')
    for kind in ('CONFIG','DATAFILES','SCRIPTS','EXTENSIONS'):
        if Path(bpy.utils.user_resource(kind, create=False)) != Path(user_paths['BLENDER_USER_'+kind]):
            raise ValueError('Blender ignored isolated user path: '+kind)
    if Path(bpy.utils.resource_path('USER')).resolve() != Path(user_paths['BLENDER_USER_RESOURCES']):
        raise ValueError('Blender ignored isolated resource root')
    if not Path(bpy.app.tempdir).resolve().is_relative_to(Path(user_paths['TMPDIR'])):
        raise ValueError('Blender ignored isolated temporary root')
    output.mkdir(parents=True, exist_ok=False)
    art = load_helper('glyph_art', 'tools/build_art.py')
    hud = load_helper('glyph_hud', 'tools/build_hud_art.py')
    art.ART, art.OUT, art.SCRATCH = output/'source/art', output/'game/assets/art', output/'previews'
    scene = art.setup()
    scene.render.threads, scene.cycles.samples = 4, 8
    scene.cycles.use_adaptive_sampling = False
    art.M.clear()
    art.M['ivory'] = art.material('Fixed flat ivory glyph', '#e8ddc4', rough=1, emission=1)
    # Emission alone prevents lighting from encoding identity or shading the flat palette.
    material = art.M['ivory']
    material.node_tree.nodes.clear()
    shader = material.node_tree.nodes.new('ShaderNodeEmission')
    shader.inputs['Color'].default_value = art.rgba('#e8ddc4')
    surface = material.node_tree.nodes.new('ShaderNodeOutputMaterial')
    material.node_tree.links.new(shader.outputs[0], surface.inputs['Surface'])
    counts = {}
    for index, name in enumerate(NAMES):
        collection = bpy.data.collections.new(name)
        scene.collection.children.link(collection)
        count = 0
        for label, polygon in geometry(name):
            obj = hud.plate(art, name+' / '+label, polygon, 'ivory', depth=.025)
            obj.location = Vector((index%4-1.5, 1.5-index//4, 0))
            for old in list(obj.users_collection):
                old.objects.unlink(obj)
            collection.objects.link(obj)
            obj.data.calc_loop_triangles()
            count += len(obj.data.loop_triangles)
        counts[name] = count
    if sum(counts.values()) >= 10000:
        raise ValueError('native triangle budget')
    art.camera(scene, (0,0,10), (0,0,0), 4, 256, 256)
    for obj in list(scene.objects):
        if obj.type == 'LIGHT':
            bpy.data.objects.remove(obj, do_unlink=True)
    scene['reference_sha256'], scene['recipe_sha256'] = REFERENCE_SHA, recipe_sha
    scene['recipe_dependencies'] = json.dumps(HELPER_SHA, sort_keys=True)
    scene['glyph_collection_order'] = json.dumps(NAMES)
    scene['glyph_contracts'] = json.dumps(CONTRACTS, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(art.target(paths['blend'])), compress=False)
    pixels = art.pixels_render(scene, 'marker-glyphs-native', 256, 256)
    for offset in range(0, len(pixels), 4):
        pixels[offset:offset+4] = bytes(IVORY_RGBA if pixels[offset+3] else (0,0,0,0))
    meta = metadata(pixels, counts, recipe_sha)
    meta['blender_version'] = bpy.app.version_string
    art.png(paths['atlas'], 256, 256, pixels)
    art.target(paths['metadata']).write_text(json.dumps(meta, indent=2)+'\n')
    runtime_bytes = paths['atlas'].stat().st_size+paths['metadata'].stat().st_size
    check_sizes(runtime_bytes, paths['blend'].stat().st_size)
    receipt = {'candidate_only':True, 'native_source_saved_before_runtime':True,
               'reference_sha256':REFERENCE_SHA, 'recipe_sha256':recipe_sha, 'recipe_dependencies':HELPER_SHA,
               'source_triangles':sum(counts.values()), 'runtime_bytes':runtime_bytes,
               'source_bytes':paths['blend'].stat().st_size, 'user_paths':user_paths,
               'render_engine':'CYCLES', 'device':'CPU', 'threads':4, 'samples':8,
               'blender_version':bpy.app.version_string,
               'artifacts':{str(p.relative_to(output)):sha(p) for k,p in paths.items() if k != 'receipt'},
               'visual_recognition_validation':'pending parent 16/24/32px inspection'}
    paths['receipt'].write_text(json.dumps(receipt, indent=2)+'\n')
    print('PASS candidate marker glyph source and native atlas; unadopted', flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', required=True, type=Path)
    parser.add_argument('--isolation-root', required=True, type=Path)
    parser.add_argument('--recipe-sha256', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    build(args.output_root, args.isolation_root, args.recipe_sha256)


if __name__ == '__main__':
    main()
