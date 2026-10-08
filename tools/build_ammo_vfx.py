"""Render the image-derived ammo atlas with Blender in an isolated background run."""
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
SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent
REFERENCE = ROOT/'source/art/references/ammo-vfx-reference-01.png'
REFERENCE_SHA = '53de35208610843cf81fa358de5eef50d43a0fb9517e5c65c973c89122c67cf3'
HELPER_SHA = '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581'
FAMILIES = ('amber_muzzle', 'copper_casing', 'marrow_vent', 'broken_pressure_ring')
PALETTE = {'copper': '#9d6546', 'burgundy': '#713d48', 'ivory': '#d1ba8f',
           'amber': '#e9a347', 'hot_core': '#ffe9b1', 'cyan': '#99e7f4', 'violet': '#965dca'}


def pinned(path, expected):
    info = path.lstat()
    if path.resolve() != path or not stat.S_ISREG(info.st_mode) or getattr(info, 'st_flags', 0) & stat.SF_DATALESS:
        raise ValueError('Input must be an exact resident file')
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError('Source/reference drift')


def muzzle(art, phase):
    scale = (0.45, 1.0, 0.62, 0.12)[phase]
    art.tube('Pressure lance', [(-.32, 0, 0), (0, 0, 0), (.40*scale, .03, 0)],
             [.03, .12*scale, .002], 'amber', 6)
    art.egg('Incandescent throat', (-.12, 0, 0), (.10*scale, .08*scale, .04), 'hot_core', 8, 4)
    for index, reach in enumerate((.21, .31, .18, .26, .34, .16)):
        angle = math.tau*index/6+.13*phase
        art.tube('Unequal flame tongue '+str(index), [(-.12, 0, 0),
                 (-.12+math.cos(angle)*reach*scale, math.sin(angle)*reach*scale, .015)],
                 [.028*scale, .001], 'amber', 5)


def casing(art, phase):
    # Ten separate staves leave an actual open bore; there is no black end cap.
    for index in range(10):
        angle = math.tau*index/10
        obj = art.box('Hollow casing stave '+str(index),
                      (.12*math.cos(angle), .12*math.sin(angle), 0), (.065, .024, .40), 'black')
        obj.rotation_euler.z = angle+math.pi/2
    art.ring('Copper mouth', (0, 0, .20), .12, .018, 'copper', segments=12)
    art.ring('Copper primer collar', (0, 0, -.20), .12, .020, 'copper', segments=12)
    for index in range(3):
        art.box('Sparse pale scrape '+str(index), (.125, .025*index-.025, .025),
                (.005, .009, .10+.02*index), 'bone')


def marrow(art, phase):
    art.egg('Segmented pressure organ', (0, 0, 0), (.24, .115, .115), 'burgundy', 10, 6)
    spread = (.0, .025, .055, .09)[phase]
    for index in range(6):
        angle = math.tau*index/6
        radius = .15+spread
        y, z = radius*math.cos(angle), radius*math.sin(angle)
        art.tube('Separate restraint rib '+str(index), [(-.26, y*.3, z*.3),
                 (-.12, y, z), (.13, y, z), (.29, y*.22, z*.22)], .017, 'bone', 6)
    for x in (-.14, .12):
        art.ring('Copper ligature '+str(x), (x, 0, 0), .14, .015, 'copper', 'YZ', 10)
    for y in (-.055, .055):
        art.egg('Amber pressure window '+str(y), (-.13, y, .115), (.055, .025, .02), 'amber', 8, 4)
    for index in range(3):
        art.tube('Venting tendon '+str(index), [(-.23, (index-1)*.035, 0),
                 (-.35, (index-1)*.065, .025)], [.02, .001], 'burgundy', 5)


def pressure_ring(art, phase):
    thickness_scalar = 2.5
    growth = (.42, .72, 1.0, 1.08)[phase]
    for radius, material, kept in ((.26, 'cyan', (0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14)),
                                  (.34, 'violet', (1, 2, 3, 6, 7, 10, 11, 12, 14))):
        for index in kept:
            angles = (math.tau*index/16, math.tau*(index+.72)/16)
            art.tube(material+' fractured arc '+str(index),
                     [(radius*growth*math.cos(a), radius*growth*math.sin(a), 0) for a in angles],
                     (.012 if material == 'cyan' else .008)*thickness_scalar, material, 5)
    if phase < 3:
        art.egg('Cold core', (0, 0, .025), ((.07, .055, .025)[phase],)*3, 'cyan', 8, 4)
    for index in range(4):
        angle = math.tau*index/4+.08
        art.tube('Uneven cardinal fracture '+str(index),
                 [(.22*growth*math.cos(angle), .22*growth*math.sin(angle), .01),
                  (.40*growth*math.cos(angle), .40*growth*math.sin(angle), .01)],
                 [.009, .001], 'violet', 5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    output = args.output_root.absolute()
    if any(p.is_symlink() for p in (output, *output.parents)) or output.exists():
        raise ValueError('Use a fresh, real output directory')
    pinned(REFERENCE, REFERENCE_SHA)
    helper = SOURCE/'build_art.py'
    pinned(helper, HELPER_SHA)
    import bpy
    if not bpy.app.background:
        raise RuntimeError('Blender background CLI only')
    output.mkdir(parents=True)
    from mathutils import Matrix, Vector
    spec = importlib.util.spec_from_file_location('retained_art', helper)
    art = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(art)
    art.ART, art.OUT, art.SCRATCH = output/'source/art', output/'game/assets/art', output/'previews'
    art.setup()
    scene = bpy.context.scene
    scene.view_settings.exposure = -1.5
    user_paths = {}
    for kind in ('CONFIG','DATAFILES','SCRIPTS','EXTENSIONS'):
        env_key = 'BLENDER_USER_'+kind
        expected = Path(os.environ[env_key])
        actual = Path(bpy.utils.user_resource(kind, create=False))
        if actual != expected or actual.resolve() != actual or not actual.is_dir():
            raise ValueError('Blender user resource ownership mismatch: '+kind)
        for ancestor in (actual,*actual.parents):
            info = ancestor.lstat()
            if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode) or getattr(info,'st_flags',0)&stat.SF_DATALESS:
                raise ValueError('Blender user resource ancestry is unsafe')
        user_paths[env_key] = str(actual)
    expected_base = Path(os.environ['BLENDER_USER_RESOURCES'])
    if Path(bpy.utils.resource_path('USER')).resolve() != expected_base:
        raise ValueError('Blender base user resources escaped binding')
    user_paths['BLENDER_USER_RESOURCES'] = str(expected_base)
    temporary = Path(bpy.app.tempdir).resolve()
    temporary_root = Path(os.environ['TMPDIR'])
    if not temporary.is_relative_to(temporary_root):
        raise ValueError('Blender temporary path escaped owned root')
    (output/'USER-RESOURCE-OWNERSHIP.json').write_text(json.dumps(
        {'owned_user_paths':user_paths,'temporary_path':str(temporary),'temporary_root_owned':True},indent=2)+'\n')
    for name, color in PALETTE.items():
        art.M[name] = art.material(name, color, metal=.7 if name == 'copper' else 0,
                                  emission=.8 if name in ('amber', 'hot_core', 'cyan', 'violet') else 0)
    builders = (muzzle, casing, marrow, pressure_ring)
    poses = []
    for row, (family, build) in enumerate(zip(FAMILIES, builders)):
        for column in range(4):
            before = set(scene.objects)
            build(art, column)
            bpy.context.view_layer.update()
            collection = bpy.data.collections.new(family+'_'+str(column))
            scene.collection.children.link(collection)
            transform = Matrix.Identity(4)
            if family == 'copper_casing':
                transform = Matrix.Rotation(math.radians((45, 72, 115, 148)[column]), 4, 'Y')
            center = Vector((-1.5+column, 1.5-row, 0))
            for obj in set(scene.objects)-before:
                obj.matrix_world = Matrix.Translation(center) @ transform @ obj.matrix_world
                for old in list(obj.users_collection):
                    old.objects.unlink(obj)
                collection.objects.link(obj)
            poses.append(collection.name)
    triangles = 0
    for obj in scene.objects:
        if obj.type == 'MESH':
            obj.data.calc_loop_triangles()
            triangles += len(obj.data.loop_triangles)
    assert 0 < triangles <= 40000, 'Source geometry budget exceeded'
    art.camera(scene, (0, 0, 8), (0, 0, 0), 4.0, 256, 256)
    scene['selected_reference_sha256'] = REFERENCE_SHA
    scene['pose_order'] = json.dumps(poses)
    blend = art.target(art.ART/'ammo_vfx.blend')
    atlas = art.target(art.OUT/'effects/ammo_vfx.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=False)
    pixels = art.pixels_render(scene, 'ammo-vfx-native', 256, 256)
    art.png(atlas, 256, 256, pixels)
    assert len(pixels) == 256*256*4, 'Wrong native atlas dimensions'
    frame_alpha = []
    for row in range(4):
        for column in range(4):
            occupied = []
            for y in range(64):
                for x in range(64):
                    alpha = pixels[(row*64+y)*256*4+(column*64+x)*4+3]
                    if alpha:
                        occupied.append((x, y))
            assert occupied and all(4 <= x < 60 and 4 <= y < 60 for x, y in occupied), 'Empty/clipped frame or gutter bleed'
            frame_alpha.append(len(occupied))
    assert all(alpha >= minimum for alpha, minimum in zip(frame_alpha[12:], (133, 152, 169, 185))), 'Ring coverage below native03 improvement floor'
    assert atlas.stat().st_size <= 512*1024 and blend.stat().st_size <= 8*1024*1024
    receipt = {'reference_sha256': REFERENCE_SHA, 'helper_sha256': HELPER_SHA, 'poses': poses,
               'triangles': triangles, 'atlas_size': [256, 256], 'RGBA_base_bytes': 262144,
               'clear_border': 4, 'frame_alpha_pixels': frame_alpha,
               'artifacts': {str(p.relative_to(output)): {'sha256': art.sha(p), 'logical': p.stat().st_size,
                                                        'allocated': p.stat().st_blocks*512} for p in
                             (blend, atlas, art.SCRATCH/'frames/ammo-vfx-native.png')},
               'not_claimed': ['visual fidelity approval', 'game wiring', 'native import', 'performance gains']}
    (output/'ARTIFACT.json').write_text(json.dumps(receipt, indent=2)+'\n')


if __name__ == '__main__':
    main()
