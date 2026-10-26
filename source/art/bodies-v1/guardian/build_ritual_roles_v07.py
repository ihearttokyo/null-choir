"""One original ritual role per fresh source/proof folder; NEVER runs on import.

Prepared source only. Parent must explicitly grant each native execution lane.
Generic fixed-lens orbit / binary coverage / baseline registration contract follows
Bodies' existing exporter, but imports NO Worker recipe or Worker anatomy.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zlib

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import geometry_v07 as geo
import paint_ritual_roles_v07 as paint

OWNED = Path(__file__).resolve().parent
REFERENCE_SHA = 'c2a9b71f2b6c005be50e1797e428138e2872e2708c886b79aca96148ccd5e6ca'


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def parse_cells(value):
    cells = []
    try:
        for token in value.split(','):
            pose, index = token.split(':')
            if pose not in geo.SOURCE_POSES or index not in tuple(map(str, range(8))): raise ValueError()
            cells.append((pose, int(index)))
        if not 1 <= len(cells) <= 4 or len(cells) != len(set(cells)): raise ValueError()
    except ValueError:
        raise argparse.ArgumentTypeError('Use 1–4 unique exact pose:direction cells (direction 0..7)') from None
    return cells


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role', choices=geo.ROLES, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--mode', choices=('source', 'selected', 'atlas'), default='source')
    parser.add_argument('--cells', type=parse_cells, default=parse_cells('idle:0,idle:2,attack:0'))
    parser.add_argument('--approved-directional-matrix', action='store_true')
    args = parser.parse_args(argv)
    # Check unresolved components BEFORE resolve: symlinks must never redirect work.
    raw = args.output.absolute()
    if any(p.is_symlink() for p in (raw, *raw.parents)): parser.error('No symlink output components')
    args.output = raw.resolve()
    if not args.output.is_relative_to(OWNED) or args.output == OWNED: parser.error('Fresh owned subfolder required')
    if args.output.exists(): parser.error('Output exists; preserve it and choose fresh folder')
    if args.mode == 'atlas' and not args.approved_directional_matrix: parser.error('Full40 matrix requires explicit parent grant')
    if sha(args.reference) != REFERENCE_SHA: parser.error('Wrong selected reference bytes')
    return args


def selected_cells(args):
    return [(p, d) for p in geo.POSES for d in range(8)] if args.mode == 'atlas' else args.cells if args.mode == 'selected' else []


def png(path, width, height, pixels):
    if len(pixels) != width*height*4: raise ValueError('Wrong RGBA byte count')
    def chunk(kind, data):
        return struct.pack('>I', len(data))+kind+data+struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
    raw = b''.join(b'\0'+pixels[y*width*4:(y+1)*width*4] for y in range(height))
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))+chunk(b'IDAT', zlib.compress(raw, 9))+chunk(b'IEND', b''))


def register_pixels(raw):
    """Exact existing strict coverage/baseline rule, never rescale/crop/mirror."""
    if len(raw) != geo.CELL*geo.CELL*4: raise ValueError('Wrong128-cell byte count')
    if not all(raw[i] in (0, 255) for i in range(3, len(raw), 4)): raise ValueError('Nonbinary alpha')
    points = [(x, y) for y in range(128) for x in range(128) if raw[(y*128+x)*4+3]]
    if not points: raise ValueError('Empty proof')
    bbox = [min(x for x, y in points), min(y for x, y in points), max(x for x, y in points), max(y for x, y in points)]
    if not (bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 127 and bbox[3] < 127):
        raise ValueError('FRAME_FAILED_NO_CROP_OR_RESCALE raw border '+repr(bbox))
    shift = geo.FOOT_Y-bbox[3]
    final = bytearray(len(raw))
    for x, y in points:
        dest = y+shift
        if not 0 < dest < 127: raise ValueError('FRAME_FAILED_NO_CROP_OR_RESCALE registered border')
        src, dst = (y*128+x)*4, (dest*128+x)*4
        final[dst:dst+4] = raw[src:src+4]
    final_bbox = [bbox[0], bbox[1]+shift, bbox[2], bbox[3]+shift]
    assert final_bbox[3] == 119
    return final, {'raw_occupied_bbox': bbox, 'registered_occupied_bbox': final_bbox,
                   'vertical_registration_shift': shift, 'origin_px': [64, 120],
                   'occupied_bottom': 119, 'clipped_pixels': 0, 'binary_alpha': True}


def check_projection(model):
    checks = []
    for direction in range(8):
        bounds = geo.projected_bounds(model, direction)
        for state, b in bounds.items():
            if not (1 < b[0] < b[2] < 126 and 1 < b[1] < b[3] < 126):
                raise ValueError(f'Source volume exceeds fixed cell: {model.role}/{model.pose}/{direction}/{state}/{b}')
        checks.append({'direction': direction, **bounds})
    return checks


class NativeExporter:
    def __init__(self, bpy, Vector, role):
        self.bpy, self.Vector, self.role = bpy, Vector, role
        self.collections = {}
        self.surface = paint.UVPaintAtlas(geo, role)
        self.paint_records = []

    def setup(self):
        bpy = self.bpy
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0
        scene = bpy.context.scene
        scene.render.engine = 'BLENDER_WORKBENCH'
        scene.render.threads_mode, scene.render.threads = 'FIXED', 2
        scene.render.film_transparent = True
        scene.render.resolution_x = scene.render.resolution_y = 128
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.display.render_aa = 'OFF'
        shading = scene.display.shading
        shading.light, shading.studio_light, shading.color_type = 'STUDIO', 'paint.sl', 'TEXTURE'
        shading.show_shadows, shading.show_cavity = True, True
        shading.cavity_type = 'BOTH'
        shading.curvature_ridge_factor = shading.cavity_ridge_factor = 1.0
        shading.curvature_valley_factor = shading.cavity_valley_factor = .65
        shading.show_specular_highlight = True
        scene.view_settings.view_transform, scene.view_settings.look = 'Standard', 'None'
        scene.world = bpy.data.worlds.new('Transparent source studio')
        scene.world.color = (.15, .15, .15)
        self.scene, self.materials = scene, {}
        # One genuine packed editable paint image, shared by the role's native
        # local UV charts. No actor-view image or screen-space stamp is loaded.
        self.paint_image = bpy.data.images.new(self.role+' local surface paint', width=self.surface.width,
                                               height=self.surface.height, alpha=True, float_buffer=False)
        self.paint_image.colorspace_settings.name = 'Non-Color'
        self.paint_image.pixels.foreach_set([channel/255 for channel in self.surface.pixels])
        observed = [0.0]*len(self.surface.pixels)
        self.paint_image.pixels.foreach_get(observed)
        assert bytes(round(channel*255) for channel in observed) == bytes(self.surface.pixels)
        self.paint_image.filepath_raw = '//'+self.role+'-surface-paint.png'
        self.paint_image.pack()
        assert self.paint_image.packed_file is not None
        packed = bytes(self.paint_image.packed_file.data)
        packed_size, packed_rgba = paint.decode_png(packed)
        assert packed_size == (self.surface.width, self.surface.height)
        assert packed_rgba == bytes(self.surface.pixels), 'Packed native paint changed authored RGBA'
        self.packed_paint_sha256 = hashlib.sha256(packed).hexdigest()
        for key, color in geo.PALETTE.items():
            mat = bpy.data.materials.new('Ritual grammar / '+key)
            mat.diffuse_color = color
            # Blender5.2 already creates the full node graph. Avoid its
            # deprecated redundant setter; preserve legacy enablement only.
            if mat.node_tree is None:
                mat.use_nodes = True
            assert mat.node_tree is not None, 'Material node tree unavailable'
            node = mat.node_tree.nodes.get('Principled BSDF')
            assert node is not None, 'Principled material shader unavailable'
            node.inputs['Base Color'].default_value = color
            uv_node = mat.node_tree.nodes.new('ShaderNodeUVMap')
            uv_node.uv_map = paint.ATTRIBUTE
            texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
            texture.image = self.paint_image
            texture.interpolation, texture.extension = 'Closest', 'EXTEND'
            mat.node_tree.links.new(uv_node.outputs['UV'], texture.inputs['Vector'])
            mat.node_tree.links.new(texture.outputs['Color'], node.inputs['Base Color'])
            mat.node_tree.nodes.active = texture
            assert mat.node_tree.nodes.active.image == self.paint_image
            assert any(link.from_node == texture for link in node.inputs['Base Color'].links)
            node.inputs['Roughness'].default_value = .76
            node.inputs['Metallic'].default_value = .35 if key in ('iron', 'steel', 'brass') else 0
            self.materials[key] = mat
        for filename in ('geometry_v07.py', 'paint_ritual_roles_v07.py', Path(__file__).name):
            bpy.data.texts.new(filename).write((OWNED/filename).read_text())
        scene['original_volume_recipe'] = True
        scene['reference_sha256'] = REFERENCE_SHA
        scene['runtime_mechanics_changed'] = False
        scene['phase_contract'] = json.dumps(geo.phase_contract(self.role), sort_keys=True)

    def add_model(self, model):
        bpy = self.bpy
        coll = bpy.data.collections.new('Pose / '+model.pose)
        self.scene.collection.children.link(coll)
        coll['base_atlas_row'] = geo.POSES.index(model.pose) if model.pose in geo.POSES else -1
        coll['phase_only_not_current_runtime'] = model.pose not in geo.POSES
        self.collections[model.pose] = coll
        joints, assemblies = {}, {}
        for name, joint in model.joints.items():
            obj = bpy.data.objects.new(model.pose+' / '+name, None)
            coll.objects.link(obj)
            obj.empty_display_type, obj.empty_display_size = 'SPHERE', .07
            obj.location = joint['position']
            obj['editable_joint'] = True
            if joint['parent']:
                parent = joints[joint['parent']]
                obj.parent = parent
                obj.matrix_parent_inverse = parent.matrix_world.inverted()
            joints[name] = obj
            bpy.context.view_layer.update()
        for part in model.parts:
            if part.assembly not in assemblies:
                assembly = bpy.data.collections.new(model.pose+' / '+part.assembly)
                coll.children.link(assembly)
                assemblies[part.assembly] = assembly
            mesh = bpy.data.meshes.new(part.name)
            mesh.from_pydata(part.vertices, [], part.faces)
            mesh.update()
            obj = bpy.data.objects.new(model.pose+' / '+part.name, mesh)
            assemblies[part.assembly].objects.link(obj)
            # Broad authored material planes are native face assignments, not
            # external images, a lighting boost or a recoloured old body.
            materials = part.face_materials or (part.material,)*len(part.faces)
            assert len(materials) == len(part.faces)
            slots = list(dict.fromkeys(materials))
            for key in slots:
                mesh.materials.append(self.materials[key])
            for polygon, key in zip(mesh.polygons, materials):
                polygon.material_index = slots.index(key)
                polygon.use_smooth = part.smooth
            values, info = self.surface.uvs(part)
            assert len(values) == len(mesh.loops)
            layer = mesh.uv_layers.new(name=paint.ATTRIBUTE)
            flat_uv = [component for uv in values for component in uv]
            layer.uv.foreach_set('vector', flat_uv)
            observed_uv = [0.0]*len(flat_uv)
            layer.uv.foreach_get('vector', observed_uv)
            assert max(abs(a-b) for a,b in zip(observed_uv, flat_uv)) < 1e-6
            assert mesh.uv_layers.active.name == paint.ATTRIBUTE
            obj['surface_uv_attribute'] = paint.ATTRIBUTE
            obj['surface_paint_anchoring'] = info['anchor']
            self.paint_records.append(dict(info, pose=model.pose))
            obj['assembly'], obj['material_group'] = part.assembly, part.material
            obj.parent = joints[part.joint]
            obj.matrix_parent_inverse = joints[part.joint].matrix_world.inverted()
        bpy.context.view_layer.update()
        # Actual Blender transforms must retain the authored original world vertices.
        for part in model.parts:
            obj = bpy.data.objects[model.pose+' / '+part.name]
            for actual, expected in zip(obj.data.vertices, part.vertices):
                if (obj.matrix_world@actual.co-self.Vector(expected)).length > 1e-5:
                    raise ValueError('Native parenting changed original volume')

    def camera(self):
        data = self.bpy.data.cameras.new('Fixed 128px native orthographic camera')
        self.cam = self.bpy.data.objects.new('Eight-direction registered camera', data)
        self.scene.collection.objects.link(self.cam)
        data.type, data.ortho_scale = 'ORTHO', geo.SPECS[self.role]['ortho']
        self.scene.camera = self.cam
        self.direction(0)

    def direction(self, index):
        angle, aim = math.tau*index/8, geo.SPECS[self.role]['aim']
        self.cam.location = (10*math.sin(angle), -10*math.cos(angle), aim+2.05)
        self.cam.rotation_euler = (self.Vector((0, 0, aim))-self.cam.location).to_track_quat('-Z', 'Y').to_euler()
        self.bpy.context.view_layer.update()

    def select(self, pose):
        for name, coll in self.collections.items():
            coll.hide_render, coll.hide_viewport = name != pose, name != pose
        self.bpy.context.view_layer.update()

    def render(self, path):
        self.scene.render.filepath = str(path)
        self.bpy.ops.render.render(write_still=True)
        image = self.bpy.data.images.load(str(path), check_existing=False)
        values = list(image.pixels[:])
        self.bpy.data.images.remove(image)
        raw = bytearray(128*128*4)
        for y in range(128):
            for x in range(128):
                src, dst = ((127-y)*128+x)*4, (y*128+x)*4
                if values[src+3] >= .5:
                    raw[dst:dst+4] = bytes([min(255, round(values[src+k]*31)*8) for k in range(3)]+[255])
        return register_pixels(raw)


def main(argv=None):
    args = arguments(sys.argv[sys.argv.index('--')+1:] if argv is None and '--' in sys.argv else argv or [])
    models = {p: geo.build(args.role, p) for p in geo.SOURCE_POSES}
    projected = {p: check_projection(m) for p, m in models.items()}
    # Blender is imported only after all pure/read-only argument/geometry checks.
    import bpy
    from mathutils import Vector
    args.output.mkdir(parents=True, exist_ok=False)
    report = {'status': 'NATIVE_ATTEMPT_STARTED', 'role': args.role, 'mode': args.mode,
              'reference_sha256': REFERENCE_SHA, 'recipe_sha256': sha(__file__),
              'geometry_sha256': sha(OWNED/'geometry_v07.py'), 'models': {},
              'projected_vertices_all_8_directions': projected,
              'phase_contract': geo.phase_contract(args.role), 'frames': [],
              'cell_size': [128, 128], 'origin_px': [64, 120], 'occupied_bottom': 119,
              'ortho': geo.SPECS[args.role]['ortho'], 'native_execution_does_not_approve_art': True}
    receipt = args.output/'manifest.json'
    try:
        ex = NativeExporter(bpy, Vector, args.role)
        ex.setup()
        for pose, model in models.items():
            ex.add_model(model)
            report['models'][pose] = {'geometry_sha256': model.digest(), 'meshes': len(model.parts),
                'joints': len(model.joints), 'triangles': sum(sum(len(f)-2 for f in p.faces) for p in model.parts)}
        report['surface_paint'] = {'route': 'PACKED_LOCAL_UV_PAINT', 'attribute': paint.ATTRIBUTE,
            'paint_recipe_sha256': sha(OWNED/'paint_ritual_roles_v07.py'),
            'all_meshes_populated': len(ex.paint_records) == sum(len(m.parts) for m in models.values()),
            'source_and_Workbench_same_active_image': True, 'records': ex.paint_records,
            'image': ex.surface.summary(), 'packed_png_sha256': ex.packed_paint_sha256,
            'native_image_and_packed_RGBA_readback_exact': True}
        assert report['surface_paint']['all_meshes_populated']
        paint_path = args.output/(args.role+'-surface-paint.png')
        paint_path.write_bytes(paint.png_bytes(ex.surface.width, ex.surface.height, bytes(ex.surface.pixels)))
        report['surface_paint']['editable_png'] = {'file': paint_path.name, 'bytes': paint_path.stat().st_size, 'sha256': sha(paint_path)}
        ex.camera(); ex.select('idle')
        ex.scene['recipe_sha256'] = report['recipe_sha256']
        ex.scene['geometry_sha256'] = report['geometry_sha256']
        # Remove host paths from saved scene; no external bitmap dependencies exist.
        ex.scene.render.filepath = '//'
        blend = args.output/(args.role+'-ritual-roles.blend')
        bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
        report['editable_source'] = {'file': blend.name, 'bytes': blend.stat().st_size, 'sha256': sha(blend)}
        cells = selected_cells(args)
        atlas = bytearray(1024*640*4) if args.mode == 'atlas' else None
        for pose, direction in cells:
            report['attempting_cell'] = [pose, direction]
            receipt.write_text(json.dumps(report, indent=2)+'\n')
            ex.select(pose); ex.direction(direction)
            pixels, bounds = ex.render(args.output/f'raw-{args.role}-{pose}-{direction:02}.png')
            path = args.output/f'{args.role}-{pose}-{direction:02}.png'
            png(path, 128, 128, pixels)
            report['frames'].append({'pose': pose, 'direction': direction, 'file': path.name,
                                     'sha256': sha(path), 'rgba_sha256': hashlib.sha256(pixels).hexdigest(), **bounds})
            if atlas is not None:
                row = geo.POSES.index(pose)
                for y in range(128):
                    start = ((row*128+y)*1024+direction*128)*4
                    atlas[start:start+512] = pixels[y*512:(y+1)*512]
        if atlas is not None:
            if len(report['frames']) != 40 or len({f['rgba_sha256'] for f in report['frames']}) != 40:
                raise ValueError('All40 actual native frames must be populated and distinct')
            path = args.output/(args.role+'.png')
            png(path, 1024, 640, atlas)
            if path.stat().st_size > 512*1024: raise ValueError('Runtime PNG exceeds fixed512KiB budget')
            report['atlas'] = {'file': path.name, 'sha256': sha(path), 'bytes': path.stat().st_size, 'size': [1024, 640]}
        report.pop('attempting_cell', None)
        report['status'] = 'GENERATED_NOT_VISUALLY_APPROVED'
    except Exception as error:
        report['status'], report['error'] = 'STRICT_FAIL', repr(error)
        raise
    finally:
        receipt.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
