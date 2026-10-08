"""Export editable source/art/conduit.blend without saving runtime joins over it.

Run: blender -b -t 4 --python-exit-code 1 --python tools/build_art.py -- --asset conduit
"""
import json
from pathlib import Path
import runpy
import struct

REFERENCE_PINS = {
    'conduit-braid05.png': '46bc1fbc1712c7212f7f008432ff2f780a766c97fb4ac7a5436a8d947003b8d1',
    'conduit-material03.png': 'ae17abbb2ef1994bb755d422cbed514db5ed0ebc69cbec2e58e7d2bca498b76d',
}


def without_atlas_mips(data):
    """Set only the owned export's emission texture to standard non-mip linear."""
    if len(data)<28 or struct.unpack_from('<4sII',data)!=(b'glTF',2,len(data)):
        raise ValueError('Invalid owned GLB container')
    length,kind=struct.unpack_from('<I4s',data,12)
    offset=20+length
    if kind!=b'JSON' or offset+8>len(data):
        raise ValueError('Invalid owned JSON chunk')
    binary_length,kind=struct.unpack_from('<I4s',data,offset)
    if kind!=b'BIN\0' or offset+8+binary_length!=len(data):
        raise ValueError('Invalid owned BIN chunk')
    doc=json.loads(data[20:offset])
    textures={m['emissiveTexture']['index'] for m in doc.get('materials',[]) if 'emissiveTexture' in m}
    if len(textures)!=1:
        raise ValueError('Require one owned emission atlas texture')
    texture=doc['textures'][textures.pop()]
    sampler=doc['samplers'][texture['sampler']]
    if sampler.get('minFilter')==9729:
        return data
    doc['samplers'].append(dict(sampler,minFilter=9729))
    texture['sampler']=len(doc['samplers'])-1
    raw=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
    raw+=b' '*((-len(raw))%4)
    total=20+len(raw)+len(data)-offset
    return struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(raw),b'JSON')+raw+data[offset:]


def export_conduit(helpers=None):
    import bpy
    if not bpy.app.background:
        raise RuntimeError('Blender background CLI only')
    h = helpers if helpers is not None else runpy.run_path(str(Path(__file__).with_name('build_art.py')))
    source = h['ART'] / 'conduit.blend'
    if source.is_symlink() or source.resolve() != h['ROOT'].resolve() / 'source/art/conduit.blend':
        raise RuntimeError('Require repository source/art/conduit.blend')
    source_hash = h['sha'](source)
    references = []
    for name, pin in REFERENCE_PINS.items():
        path = h['ART'] / 'references' / name
        if path.is_symlink() or h['sha'](path) != pin:
            raise RuntimeError('Conduit image-first reference pin drift: ' + name)
        references.append({'path': str(path.relative_to(h['ROOT'])), 'sha256': pin})
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    scene = bpy.context.scene
    objects = [o for o in scene.objects if o.type == 'MESH']
    if not objects or any(o.modifiers or not o.data.uv_layers for o in objects):
        raise RuntimeError('Require UV-mapped editable meshes without unapplied modifiers')
    triangles = sum(len(p.vertices) - 2 for o in objects for p in o.data.polygons)
    if not 0 < triangles <= 3000:
        raise RuntimeError('Conduit triangle budget exceeded')
    bpy.context.view_layer.update()
    extent = h['bounds'](objects)
    for i, limit in enumerate((.5, 2.05, .6)):
        if not (-limit - .001 <= extent['min'][i] <= extent['max'][i] <= limit + .001):
            raise RuntimeError('Conduit native bounds exceeded')
    if extent['min'][2] < -.001:
        raise RuntimeError('Conduit must remain ground-centered')
    mats = []
    for obj in objects:
        for mat in obj.data.materials:
            if mat is None:
                raise RuntimeError('Conduit empty material slot')
            if mat not in mats:
                mats.append(mat)
    if len(mats) != 2:
        raise RuntimeError('Require two shared conduit materials')
    images = []
    for mat in mats:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image is not None and node.image not in images:
                images.append(node.image)
    if len(images) != 3 or any(not img.packed_file or not all(0 < n <= 256 for n in img.size) for img in images):
        raise RuntimeError('Require three shared packed textures at most 256px')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if bpy.ops.object.join() != {'FINISHED'}:
        raise RuntimeError('Conduit runtime join cancelled')
    merged = bpy.context.view_layer.objects.active
    merged.name = 'conduit'
    if len(merged.data.materials) != 2 or any(mat not in mats for mat in merged.data.materials):
        raise RuntimeError('Runtime join must retain two shared material slots')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    path = h['target'](h['OUT'] / 'world/conduit.glb')
    status = bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_animations=False, export_cameras=False,
        export_lights=False, export_materials='EXPORT', export_image_format='AUTO',
        export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    if status != {'FINISHED'}:
        raise RuntimeError('Conduit runtime export cancelled')
    path.write_bytes(without_atlas_mips(path.read_bytes()))
    if h['sha'](source) != source_hash:
        raise RuntimeError('Editable conduit source changed during export')
    return h['record']('conduit', source, [(path, None)], physical_bounds_m=extent,
        origin='ground-centered at Blender (0,0,0); GLB Y up', triangles=triangles,
        material_count=2, runtime_mesh_nodes=1, recipe_sha256=h['sha'](Path(__file__)),
        provenance={'method': 'original editable Blender geometry and packed authored PBR textures',
            'authoring_script': 'tools/build_conduit_art.py', 'references': references,
            'imports': [], 'license': 'Original NULL CHOIR project art'})


if __name__ == '__main__':
    export_conduit()
