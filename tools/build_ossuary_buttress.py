"""Decorative living buttress; background Blender, fresh isolated candidate output only."""
import argparse
import hashlib
import importlib.util
import json
import math
import struct
import zlib
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ID = 'ossuary_living_buttress'
sys.path.insert(0, str(ROOT))
HELPER_SHA = '07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a'
DEPENDENCIES = {'tools/build_art.py': '07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a', 'tools/art_recipe.py': '32af173a8db24be0068ba3043990e3cc950de546bc1079dc635dc1af0cedcbf6', 'tools/ossuary_buttress_contract.py': '24c887287c67c1839c8ab91b3c086ea1390a87c0b1b6ef43c09760d24290ba9f'}
REFERENCES = {
    'source/art/references/ossuary-living-breach-v1.png': '73b49c857cdc51578be8985a7a2d66fa29d7ebec397dbb777ca5d811a430d5ae',
    'source/art/references/ossuary-restraint-reference-v1.png': '992117a8008c631dd461ee8b63e28975488a2592e29620e2b9a24eff18ca8962',
}
PALETTE = {'bone': ('#b9a17b', 0, .68), 'muscle': ('#6d1725', 0, .30),
           'bronze': ('#624a2e', .74, .58), 'charcoal': ('#373630', .18, .87)}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def plain_path(value):
    path = Path(value)
    if '..' in path.parts or '~' in path.parts:
        raise ValueError('Path traversal/alias')
    path = path.absolute()
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Symlinked path')
    return path


def pinned(path, digest):
    path = plain_path(path)
    if not path.is_file() or path.stat().st_nlink != 1 or sha(path) != digest:
        raise ValueError('Missing, aliased or modified pinned input')
    return path


def preflight(root=ROOT):
    root = plain_path(root)
    from tools.art_recipe import resolve_recipe
    for logical, digest in DEPENDENCIES.items():
        resolve_recipe(root, logical, digest)
    pinned(ROOT / 'tools/ossuary_buttress_contract.py', DEPENDENCIES['tools/ossuary_buttress_contract.py'])
    for relative, digest in dict(REFERENCES, **{ATLAS_REFERENCE: ATLAS_SHA}).items():
        pinned(root / relative, digest)
    return resolve_recipe(root, 'tools/build_art.py', HELPER_SHA)


def candidate_output(value, root=ROOT, proof=False):
    path, root = plain_path(value), plain_path(root)
    for item in (root, ROOT):
        if (any(p.exists() and p.samefile(item) for p in (path, *path.parents))
                or path.exists() and any(path.samefile(p) for p in item.parents)):
            raise ValueError('Output/input alias')
    if not path.parent.is_dir() or (not proof and path.exists()):
        raise ValueError('Output must be fresh with existing parent')
    if proof and not path.is_dir():
        raise ValueError('Proof requires an existing isolated candidate')
    return path


def _contract():
    path = pinned(ROOT / 'tools/ossuary_buttress_contract.py', DEPENDENCIES['tools/ossuary_buttress_contract.py'])
    spec = importlib.util.spec_from_file_location('ossuary_bound_contract', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def part(name, material, vertices, faces):
    return {'name': name, 'material': material, 'vertices': vertices, 'faces': faces}


def loft(name, material, centers, radii, sides=6):
    # Vertical editable cross-sections keep this low-poly column's ring order explicit.
    vertices = [(x + r * math.cos(j * math.tau / sides),
                 y + r * math.sin(j * math.tau / sides), z)
                for (x, y, z), r in zip(centers, radii) for j in range(sides)]
    faces = [(i * sides + j, i * sides + (j + 1) % sides,
              (i + 1) * sides + (j + 1) % sides, (i + 1) * sides + j)
             for i in range(len(centers) - 1) for j in range(sides)]
    faces += [tuple(reversed(range(sides))),
              tuple(range((len(centers) - 1) * sides, len(centers) * sides))]
    return part(name, material, vertices, faces)


def annulus(name, material, center, radii, wall, depth, plane, sides):
    vertices = []
    for d in (-depth / 2, depth / 2):
        for inset in (0, wall):
            for j in range(sides):
                a = j * math.tau / sides
                u, v = (radii[0] - inset) * math.cos(a), (radii[1] - inset) * math.sin(a)
                local = (u, d, v) if plane == 'XZ' else (u, v, d)
                vertices.append(tuple(center[i] + local[i] for i in range(3)))
    faces = []
    for j in range(sides):
        k = (j + 1) % sides
        faces += [(j, k, k + sides, j + sides),
                  (j + 2 * sides, j + 3 * sides, k + 3 * sides, k + 2 * sides),
                  (j, j + 2 * sides, k + 2 * sides, k),
                  (j + sides, k + sides, k + 3 * sides, j + 3 * sides)]
    # XY depth runs along +Z; its front annulus needs the opposite winding.
    if plane == 'XY':
        faces = [tuple(reversed(f)) for f in faces]
    return part(name, material, vertices, faces)


def block(name, material, center, size):
    vertices = [tuple(center[i] + s[i] * size[i] / 2 for i in range(3))
                for s in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                          (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))]
    return part(name, material, vertices,
                [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])


def design():
    parts = [block('Charcoal service footing', 'charcoal', (0, 0, .08), (1.2, .9, .16)),
             block('Charcoal load-bearing crown', 'charcoal', (0, 0, 3.33), (1.1, .72, .14))]
    # Taper the existing eight-vertex blocks instead of adding bevel geometry.
    for p in parts:
        p['vertices'] = [(x * (.86 if i >= 4 else 1), y * (.88 if i >= 4 else 1),
                          z - (.018 * (i % 3) if i >= 4 else 0)) for i, (x, y, z) in enumerate(p['vertices'])]
    for side in (-1, 1):
        profile = ((.47, .16), (.29, .44), (.23, .9), (.26, 1.35),
                   (.22, 1.9), (.18, 2.46), (.32, 3.03), (.47, 3.26)) if side == -1 else (
                   (.43, .16), (.31, .44), (.33, .9), (.23, 1.35),
                   (.30, 1.9), (.36, 2.46), (.43, 3.03), (.48, 3.26))
        centers = [(side * x, -.14 + .03 * math.sin(z * 2 + side), z) for x, z in profile]
        parts.append(loft(f'Ivory branching stay {side}', 'bone', centers,
                          (.10, .10, .095, .11, .09, .13, .10, .10)))
        parts.append(loft(f'Ivory posterior fork {side}', 'bone',
                     [(side * x + .035 * math.sin(z * 2), .18, z) for x, z in
                      ((.44, .16), (.31, .65), (.13, 1.18), (.13, 2.07), (.32, 2.72), (.44, 3.26))],
                     (.08, .07, .065, .065, .075, .09)))
        for level, z in enumerate((.42, 1.7, 2.91)):
            x = side * (.32 if level != 1 else .24)
            parts.append(annulus(f'Bronze restraint collar {side} {level}', 'bronze',
                         (x, -.08, z), (.16, .27), .038, .075, 'XY', 8))
            for offset in (-.10, .10):
                parts.append(block(f'Bronze collar fastener {side} {level} {offset}', 'bronze',
                             (x + offset, -.365, z), (.065, .055, .08)))
    for i, (x, z, rx, rz, tilt) in enumerate(((-.06, .66, .24, .27, -.18),
            (.055, 1.37, .21, .35, .11), (-.06, 2.05, .23, .33, -.14), (.04, 2.76, .28, .29, .24))):
        pore = annulus(f'Open bone aperture {i}', 'bone', (x, -.14, z), (rx, rz), .075, .16, 'XZ', 12)
        vertices = []
        for j, (xx, yy, zz) in enumerate(pore['vertices']):
            a = j % 12 * math.tau / 12
            swell = 1 + .07 * math.sin(a * 3 + i) + .035 * math.cos(a * 5 - i)
            u, v = (xx - x) * swell, (zz - z) * swell
            vertices.append((x + u * math.cos(tilt) - v * math.sin(tilt),
                             yy + .012 * math.sin(a * 2 + i),
                             z + u * math.sin(tilt) + v * math.cos(tilt)))
        pore['vertices'] = vertices
        parts.append(pore)
    for strand in range(5):
        centers = [(-.17 + .43 * t + .17 * math.sin(math.tau * t + strand * .14) + (strand - 2) * .11,
                    -.045 + (strand - 2) * .037 - .13 * math.sin(math.pi * t) + .045 * math.sin(math.tau * t),
                    .25 + 2.98 * t) for t in (0, .16, .33, .5, .67, .84, 1)]
        parts.append(loft(f'Oxblood diagonal muscle fascicle {strand}', 'muscle', centers,
                          (.025, .04, .05, .042, .052, .038, .024)))
    return parts


ATLAS_REFERENCE = 'source/art/references/ossuary-material-reference-v1.png'
ATLAS_SHA = 'ee4b81a4fe9cb441832bc1591687cad49d4f5d6e5a458796a0f13daebf01586b'
PRIVATE_MARKERS = (b'/Users/', b'/private/', b'/var/folders/', b'.codex/tasks/', b'playtest-rework01')


def assert_clean_source(data):
    assert all(marker not in data for marker in PRIVATE_MARKERS), 'private source/binary path marker'


def tile_bounds(material):
    col,row = {'bone':(0,0),'muscle':(1,0),'bronze':(0,1),'charcoal':(1,1)}[material]
    pad = 4 / 256
    return col/2+pad,(col+1)/2-pad,row/2+pad,(row+1)/2-pad


UV_PER_M = .25


def material_uvs(part):
    vertices=part['vertices'];u0,u1,v0,v1=tile_bounds(part['material']);result=[]
    for face in part['faces']:
        a,b,c=[vertices[i] for i in face[:3]]
        u,v=[b[i]-a[i] for i in range(3)],[c[i]-a[i] for i in range(3)]
        normal=[u[(i+1)%3]*v[(i+2)%3]-u[(i+2)%3]*v[(i+1)%3] for i in range(3)]
        length=math.sqrt(sum(n*n for n in normal))
        assert math.isfinite(length) and length>1e-12, 'nondegenerate face basis'
        normal=[n/length for n in normal]
        length=math.sqrt(sum(n*n for n in u));tangent=[n/length for n in u]
        bitangent=[normal[(i+1)%3]*tangent[(i+2)%3]-normal[(i+2)%3]*tangent[(i+1)%3] for i in range(3)]
        # Existing nonplanar caps stay unchanged; the pair-distance contract bounds distortion.
        coordinates=[]
        for index in face:
            delta=[vertices[index][i]-a[i] for i in range(3)]
            coordinates.append((sum(delta[i]*tangent[i] for i in range(3)),sum(delta[i]*bitangent[i] for i in range(3))))
        center=[(min(p[i] for p in coordinates)+max(p[i] for p in coordinates))/2 for i in range(2)]
        for x,y in coordinates:
            uv=((u0+u1)/2+(x-center[0])*UV_PER_M,(v0+v1)/2+(y-center[1])*UV_PER_M)
            assert all(math.isfinite(n) for n in uv) and u0<=uv[0]<=u1 and v0<=uv[1]<=v1, 'UV quadrant gutters'
            result.append((uv[0],1-uv[1]))
    return result


def canonical_atlas_png(data):
    validate_png = _contract().validate_png
    assert type(data) is bytes and 8 <= len(data) <= 256*1024, 'bounded atlas PNG'
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'PNG signature'
    # Blender adds fixed resolution/offset metadata unsupported by the bounded loader.
    metadata = {b'eXIf': bytes.fromhex('4d4d002a00000018000000480000000100000048000000010002011a00050000000100000008011b0005000000010000001000000000'), b'oFFs': bytes(9)}
    kept, seen, offset, count, image_started = [data[:8]], set(), 8, 0, False
    while offset < len(data):
        count += 1
        assert count <= 1024 and len(data)-offset >= 12, 'PNG chunk cap/truncation'
        size = struct.unpack_from('>I',data,offset)[0]
        kind = data[offset+4:offset+8]
        assert count != 1 or kind == b'IHDR', 'PNG header first'
        end = offset+12+size
        assert end <= len(data), 'PNG chunk bounds'
        body = data[offset+8:end-4]
        assert zlib.crc32(kind+body)&0xffffffff == struct.unpack_from('>I',data,end-4)[0], 'PNG CRC'
        if kind in metadata:
            assert not image_started and kind not in seen and body == metadata[kind], 'exact native PNG metadata only'
            seen.add(kind)
        else:
            kept.append(data[offset:end])
        image_started = image_started or kind == b'IDAT'
        offset = end
    result = b''.join(kept)
    validate_png(result,256,256)
    return result


def atlas_image(bpy, output, root):
    path = root / ATLAS_REFERENCE
    assert sha(path)==ATLAS_SHA
    original = bpy.data.images.load(str(path),check_existing=False)
    assert tuple(original.size)==(1254,1254)
    assert min(original.pixels[3::4])==1, 'opaque reference required'
    original.scale(256,256)
    scene = bpy.context.scene
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGB'
    scene.render.image_settings.color_depth='8'
    scene.render.image_settings.compression=100
    target = output / 'source/art/ossuary_atlas.png'
    original.save_render(str(target),scene=scene)
    target.write_bytes(canonical_atlas_png(target.read_bytes()))
    bpy.data.images.remove(original)
    image = bpy.data.images.load(str(target),check_existing=False)
    image.name='Ossuary image-derived 256 atlas'
    assert tuple(image.size)==(256,256) and min(image.pixels[3::4])==1
    image.pack()
    assert sha(path)==ATLAS_SHA, 'original material image changed'
    return image


def nearest_glb(data):
    validate_glb = _contract().validate_glb
    validate_glb(data,1656,exported=True)
    size = struct.unpack_from('<I',data,12)[0]
    doc = json.loads(data[20:20+size])
    for material in doc['materials']:
        material['pbrMetallicRoughness']['baseColorTexture']['index']=0
    doc['textures']=[{'source':0,'sampler':0}]
    doc['samplers'][0]['minFilter']=9728
    raw=json.dumps(doc,separators=(',',':')).encode();raw+=b' '*(-len(raw)%4)
    tail=data[20+size:]
    result=struct.pack('<4sII',b'glTF',2,20+len(raw)+len(tail))+struct.pack('<I4s',len(raw),b'JSON')+raw+tail
    validate_glb(result,1656)
    assert result[20+len(raw):]==tail
    return result


def _portable_path(owner, name, value):
    limit = owner.bl_rna.properties[name].length_max
    if limit > 1:
        setattr(owner, name, (b'/' if isinstance(value, bytes) else '/') * (limit - 1))
    setattr(owner, name, value)

def sanitize_source_paths(bpy):
    for image in bpy.data.images:
        if not image.packed_file:
            continue
        relative = '//' + bpy.path.basename(image.filepath)
        _portable_path(image, 'filepath_raw', relative)
        for packed in image.packed_files:
            _portable_path(packed, 'filepath', relative)
    for scene in bpy.data.scenes:
        _portable_path(scene.render, 'filepath', '//')
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type == 'FILE_BROWSER' and space.params:
                    _portable_path(space.params, 'directory', b'//')


def pulse_scale(frame):
    swell = (1 - math.cos(math.tau * frame / 60)) / 2
    return tuple(round(1 + delta * swell, 12) for delta in (0, .30, 0))


def fresh(output, *names):
    for name in names:
        path = output / name
        if path.exists() or path.is_symlink():
            raise FileExistsError('Preserve prior output: ' + name)


def build(bpy, output, root):
    helper = preflight(root)
    spec = importlib.util.spec_from_file_location('ossuary_mesh_helper', helper)
    art = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(art)
    output.mkdir()
    for name in ('source/art', 'game/assets/art/world'):
        (output / name).mkdir(parents=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.render.fps, scene.frame_start, scene.frame_end = 25, 1, 61
    atlas = atlas_image(bpy, output, root)
    art.M.clear()
    for key, (color, metal, rough) in PALETTE.items():
        art.M[key] = art.material(key,'#ffffff',metal,rough,image=atlas)
        texture=next(n for n in art.M[key].node_tree.nodes if n.type=='TEX_IMAGE')
        texture.extension='EXTEND'
    pulse = bpy.data.objects.new('Muscle_Pulse', None)
    scene.collection.objects.link(pulse)
    pulse.location = (0, 0, 1.7)
    for p in design():
        vertices = p['vertices']
        if p['material'] == 'muscle':
            vertices = [(x, y, z - 1.7) for x, y, z in vertices]
        obj = art.mesh(p['name'], vertices, p['faces'], p['material'])
        uv=obj.data.uv_layers.new(name='Ossuary atlas quadrants')
        for datum,coordinate in zip(uv.data,material_uvs(p)):
            datum.uv=coordinate
        if p['material'] == 'muscle':
            obj.parent = pulse
    for frame in (1, 31, 61):
        pulse.scale = pulse_scale(frame - 1)
        pulse.keyframe_insert(data_path='scale', frame=frame)
    pulse.animation_data.action.name = 'Pulse'
    scene.frame_set(1)
    bpy.context.view_layer.update()
    source = output / 'source/art/ossuary_living_buttress_v1.blend'
    sanitize_source_paths(bpy)
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=False, check_existing=False)
    assert_clean_source(source.read_bytes())
    source_hash = sha(source)
    for key in PALETTE:
        group = [o for o in scene.objects if o.type == 'MESH' and o.data.materials[0] == art.M[key]]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        assert bpy.ops.object.join() == {'FINISHED'}
        group[0].name = 'buttress_' + key
    bpy.ops.object.select_all(action='SELECT')
    glb = output / 'game/assets/art/world/ossuary_living_buttress.glb'
    result = bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
        export_yup=True, export_animations=True, export_frame_range=True, export_force_sampling=True,
        export_anim_slide_to_zero=True,
        export_cameras=False, export_lights=False, export_extras=False, export_materials='EXPORT',
        export_vertex_color='NONE', export_all_vertex_colors=False)
    glb.write_bytes(nearest_glb(glb.read_bytes()))
    assert result == {'FINISHED'} and sha(source) == source_hash
    atlas_path = output / 'source/art/ossuary_atlas.png'
    assert sum(p.stat().st_size for p in (source, glb, atlas_path)) <= 2*1024*1024
    preflight(root)
    record = {'id': ID, 'recipe_sha256': sha(__file__),
              'recipe_dependencies': DEPENDENCIES,
              'references': dict(REFERENCES, **{ATLAS_REFERENCE: ATLAS_SHA}),
              'triangles': 1656, 'source_mesh_count': len(design()), 'material_groups': 4,
              'animation': {'name': 'Pulse', 'seconds': 2.4, 'samples': 61,
                            'pivot_blender': [0, 0, 1.7], 'peak_scale_blender': [1, 1.30, 1]},
              'production_autoplay_configured': False, 'gameplay_placement_accepted': False,
              'artifacts': [{'path': p.relative_to(output).as_posix(), 'sha256': sha(p),
                             'bytes': p.stat().st_size} for p in (source, glb, atlas_path)]}
    (output / 'candidate.receipt.json').write_text(json.dumps(record, indent=2) + '\n')


def fingerprint(bpy):
    return hashlib.sha256(json.dumps([(o.name, [list(v.co) for v in o.data.vertices],
            [list(p.vertices) for p in o.data.polygons], [list(row) for row in o.matrix_world])
            for o in sorted(bpy.context.scene.objects, key=lambda x: x.name) if o.type == 'MESH']).encode()).hexdigest()


def proof(bpy, output, root):
    fresh(output, 'proof_edited.blend', 'proof_reverted.blend', 'proof.json')
    record = json.loads((output / 'candidate.receipt.json').read_text())
    assert record['id'] == ID and record['recipe_sha256'] == sha(__file__)
    expected = {'source/art/ossuary_living_buttress_v1.blend',
                'game/assets/art/world/ossuary_living_buttress.glb', 'source/art/ossuary_atlas.png'}
    assert len(record['artifacts']) == 3 and {item['path'] for item in record['artifacts']} == expected, 'Candidate artifact inventory'
    for item in record['artifacts']:
        pinned(output / item['path'], item['sha256'])
    source = output / 'source/art/ossuary_living_buttress_v1.blend'
    disk_hash = sha(source)
    image_hash = sha(root / ATLAS_REFERENCE)
    assert_clean_source(source.read_bytes())
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.view_layer.update()
    original = fingerprint(bpy)
    name = 'Open bone aperture 0'
    obj = bpy.data.objects[name]
    coordinate = tuple(obj.data.vertices[0].co)
    obj.data.vertices[0].co.x += .01
    sanitize_source_paths(bpy)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'proof_edited.blend'), compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(output / 'proof_edited.blend'), load_ui=False, use_scripts=False)
    bpy.context.view_layer.update()
    edited = fingerprint(bpy)
    assert edited != original and abs(bpy.data.objects[name].data.vertices[0].co.x - coordinate[0] - .01) < .000001
    bpy.data.objects['Open bone aperture 0'].data.vertices[0].co = coordinate
    sanitize_source_paths(bpy)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'proof_reverted.blend'), compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(output / 'proof_reverted.blend'), load_ui=False, use_scripts=False)
    bpy.context.view_layer.update()
    assert fingerprint(bpy) == original and sha(source) == disk_hash and sha(root / ATLAS_REFERENCE)==image_hash==ATLAS_SHA
    (output / 'proof.json').write_text(json.dumps({'source_sha256': disk_hash, 'original_geometry': original,
        'edited_geometry': edited, 'reopened_reverted_geometry': fingerprint(bpy),
        'proofs': [{'path': p, 'sha256': sha(output / p)} for p in ('proof_edited.blend', 'proof_reverted.blend')]}, indent=2) + '\n')
    print('EDIT_SAVE_REOPEN_REVERT_GREEN', flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--proof', action='store_true')
    args = parser.parse_args(argv)
    root = plain_path(args.source_root)
    preflight(root)
    output = candidate_output(args.output, root, proof=args.proof)
    import bpy
    assert bpy.app.background, 'Background Blender CLI only'
    if args.proof:
        proof(bpy, output, root)
    else:
        build(bpy, output, root)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
