import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bell', ROOT / 'tools/build_skin_bell_v2.py')
bell = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = bell
spec.loader.exec_module(bell)


def png_fixture():
    """Opaque fixture for GLB parser checks, never a production atlas."""
    import zlib
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=(b'\0'+b'\x20\x20\x20\xff'*512)*512
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',512,512,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')


class BellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts = bell.build_scene()

    def test_only_amber_gets_standard_emission(self):
        import ast
        self.assertEqual(bell.GROUPS['amber'],'amber')
        self.assertEqual(set(bell.GROUPS.values()),{'brass','ivory','tissue','amber'})
        settings={group:(metal,rough,emission) for group,metal,rough,emission in bell.MATERIALS}
        self.assertEqual(settings['amber'],(0,.43,(.38,.16,.035)))
        self.assertTrue(all(settings[group][2]==(0,0,0) for group in ('brass','ivory','tissue')))
        self.assertEqual([p.kind for p in self.parts if bell.GROUPS[p.kind]=='amber'],['amber']*8)
        tree=ast.parse((ROOT/'tools/build_skin_bell_v2.py').read_text())
        assignments=[n for n in ast.walk(tree) if isinstance(n,ast.Assign)]
        strength=next(n for n in assignments if "shader.inputs['Emission Strength'].default_value" in ast.unparse(n))
        self.assertEqual(ast.literal_eval(strength.value),1)
        color=next(n for n in assignments if "shader.inputs['Emission Color'].default_value" in ast.unparse(n))
        self.assertEqual(ast.unparse(color.value),'(*emission, 1)')

    def test_radial_foot_fit_and_four_ground_contacts(self):
        low_vertices=[v for p in self.parts for v in p.vertices if v[2]<=1.8]
        self.assertLessEqual(max(math.hypot(v[0],v[1]) for v in low_vertices),3.3)
        self.assertLessEqual(bell.low_geometry_radius(self.parts),3.3)
        for i in range(4):
            foot=next(p for p in self.parts if p.name==f'Pier {i} stepped foundation')
            self.assertEqual(min(v[2] for v in foot.vertices),0)
            self.assertGreater(max(v[0] for v in foot.vertices)-min(v[0] for v in foot.vertices),1)
        upper=[v for p in self.parts for v in p.vertices if v[2]>3.5]
        self.assertGreater(max(math.hypot(v[0],v[1]) for v in upper),3.3)

    def test_material_input_and_blender_native_copy_contract(self):
        import ast
        self.assertEqual(bell.MATERIAL_SHA,'eed15e41ba0bf85de489dbe4e25364324e8ead8e33a333182edeca89077b6ac7')
        path=(ROOT/'source/art/references/skin-bell-material-v3.png').absolute()
        self.assertTrue(path.is_relative_to(ROOT/'source/art/references'))
        self.assertEqual(bell.material_reference(path),path)
        tree=ast.parse((ROOT/'tools/build_skin_bell_v2.py').read_text())
        native=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='build_material_atlas')
        methods=[n.func.attr for n in ast.walk(native) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute)]
        self.assertTrue(all(m in methods for m in ('copy','scale','pack','save')))
        self.assertFalse(any(isinstance(n,ast.FunctionDef) and n.name=='atlas_png' for n in tree.body))
        scale=next(n for n in ast.walk(native) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=='scale')
        self.assertEqual([n.value for n in scale.args],[512,512])
        alpha = next(n for n in ast.walk(native) if isinstance(n,ast.Assign)
                     and any(isinstance(t,ast.Attribute) and isinstance(t.value,ast.Name)
                             and t.value.id=='image' and t.attr=='alpha_mode' for t in n.targets))
        saves = [n for n in ast.walk(native) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute)
                 and isinstance(n.func.value,ast.Name) and n.func.value.id=='image']
        pack = next(n for n in saves if n.func.attr=='pack')
        save = next(n for n in saves if n.func.attr=='save')
        position = lambda n: (n.lineno, n.col_offset)
        self.assertLess(position(alpha),position(scale))
        self.assertLess(position(scale),position(pack))
        self.assertLess(position(pack),position(save))
        self.assertIn("original.use_fake_user=True",ast.get_source_segment((ROOT/'tools/build_skin_bell_v2.py').read_text(),native))

    def test_vertebral_bodies_have_varied_profiles_and_beveled_sockets(self):
        bones=[p for p in self.parts if p.name.startswith('Pier 0 vertebra')]
        self.assertEqual(len(bones),8)
        self.assertTrue(all(len(p.vertices)==72 for p in bones))
        widths=[max(v[0] for v in p.vertices)-min(v[0] for v in p.vertices) for p in bones]
        self.assertGreater(max(widths)-min(widths),.10)
        self.assertTrue(all(bell.edge_counts(p)=={2} and bell.signed_volume(p)>0 for p in bones))
        self.assertEqual(sum(p.role=='corpus' for p in self.parts),8)
        self.assertEqual(sum(p.role=='inner_ligament' for p in self.parts),4)

    def test_sculpted_socket_keeps_a_real_center_aperture(self):
        p=bell.vertebral_body('eye',4,4)
        for face in p.faces:
            for i in range(1,len(face)-1):
                a,b,c=[p.vertices[k] for k in (face[0],face[i],face[i+1])]
                ux,uz=b[0]-a[0],b[2]-a[2]; vx,vz=c[0]-a[0],c[2]-a[2]
                determinant=ux*vz-uz*vx
                if abs(determinant)<1e-12: continue
                dx,dz=-a[0],4-a[2]
                s=(dx*vz-dz*vx)/determinant; t=(ux*dz-uz*dx)/determinant
                self.assertFalse(s>=0 and t>=0 and s+t<=1,'A triangle closes the eye opening')

    def test_low_radius_checks_crossing_faces_not_only_vertices(self):
        p=bell.Part('crossing',[(3.0,0,1.0),(4.0,0,2.0),(3.0,1,2.0)],[(0,1,2)],'ivory','fixture')
        self.assertGreater(bell.low_geometry_radius([p]),3.3)

    def test_material_input_rejects_changed_reference(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp).resolve()/'material.png'; path.write_bytes(b'wrong')
            with self.assertRaises(ValueError): bell.material_reference(path)

    def test_regeneration_pins_preserve_sources_not_replaced_runtime(self):
        self.assertEqual(set(bell.BASELINE_PINS), {'source/art/skin_bell.blend', 'tools/build_art.py'})

    def test_export_is_limited_to_the_active_scene(self):
        import ast
        tree = ast.parse((ROOT / 'tools/build_skin_bell_v2.py').read_text())
        exports = [n for n in ast.walk(tree) if isinstance(n, ast.Call)
                   and isinstance(n.func, ast.Attribute) and n.func.attr == 'gltf']
        self.assertEqual(len(exports), 1)
        flags = {k.arg: k.value for k in exports[0].keywords}
        self.assertIn('use_active_scene', flags)
        self.assertIsInstance(flags['use_active_scene'], ast.Constant)
        self.assertIs(flags['use_active_scene'].value, True)

    def test_manifest_uses_measured_dimensions_and_rejects_size_laundering(self):
        import runpy
        check=runpy.run_path(str(ROOT/'tests/test_art.py'))['check_skin_bell_dimensions']
        check([6.322,6.322,8.18],[6.322,6.322,8.18])
        for declared,measured in [([6.4,6.4,8.0],[6.8,6.8,8.6]),
                                  ([6.0,6.3,8.18],[6.3,6.3,8.18]),
                                  ([True,6.3,8.18],[1.0,6.3,8.18]),
                                  ([6.3,6.3,float('nan')],[6.3,6.3,8.18])]:
            with self.subTest(declared=declared,measured=measured):
                with self.assertRaises(AssertionError):check(declared,measured)

    def test_saved_source_uses_portable_raw_blend_header(self):
        import ast
        tree=ast.parse((ROOT/'tools/build_skin_bell_v2.py').read_text())
        saves=[n for n in ast.walk(tree) if isinstance(n,ast.Call)
               and isinstance(n.func,ast.Attribute) and n.func.attr=='save_as_mainfile']
        self.assertEqual(len(saves),1)
        flags={k.arg:k.value for k in saves[0].keywords}
        self.assertIn('compress',flags)
        self.assertIsInstance(flags['compress'],ast.Constant)
        self.assertIs(flags['compress'].value,False)

    def test_recipe_has_no_deletion_calls(self):
        import ast
        source = (ROOT / 'tools/build_skin_bell_v2.py').read_text()
        tree = ast.parse(source)
        forbidden = {'rmtree', 'remove', 'delete', 'unlink'}
        self.assertFalse([n.func.attr for n in ast.walk(tree) if isinstance(n, ast.Call)
                          and isinstance(n.func, ast.Attribute) and n.func.attr in forbidden])

    def test_finite_ground_centered_envelope(self):
        low, high = bell.bounds(self.parts)
        self.assertEqual(low[2], 0)
        for i in range(2):
            self.assertAlmostEqual(low[i], -high[i], places=6)
            self.assertLessEqual(high[i], 3.24)
        self.assertLessEqual(high[2], 8.2)
        self.assertGreater(high[2], 7.8)
        for part in self.parts:
            self.assertTrue(all(math.isfinite(c) for v in part.vertices for c in v))
            self.assertTrue(all(0 <= i < len(part.vertices) for f in part.faces for i in f))
            for face in part.faces:
                self.assertGreater(bell.face_area(part, face), 1e-9, part.name)

    def test_shell_cavity_normals_and_real_lip(self):
        shell = next(p for p in self.parts if p.name == 'Double wall membrane')
        n, rows = bell.SECTORS, len(bell.BELL_PROFILE)
        self.assertEqual(len(shell.vertices), n * rows * 2)
        self.assertEqual(bell.edge_counts(shell), {2})
        self.assertGreater(bell.signed_volume(shell), 0)
        outer = shell.faces[0]
        inner = shell.faces[(rows - 1) * n]
        self.assertGreater(bell.face_normal(shell, outer)[0], 0)
        self.assertLess(bell.face_normal(shell, inner)[0], 0)
        self.assertGreater(bell.BELL_PROFILE[-1][0] - bell.BELL_PROFILE[0][0], 3)
        self.assertGreater(bell.BELL_PROFILE[0][1], 2.4)
        self.assertGreater(min(math.hypot(*v[:2]) for v in shell.vertices), .65)
        lip = [p for p in self.parts if p.role == 'lip']
        self.assertGreaterEqual(len(lip), 2)
        self.assertTrue(all(bell.signed_volume(p) > 0 for p in lip))

    def test_four_substantial_piers_and_real_sockets(self):
        for i in range(4):
            core = next(p for p in self.parts if p.name == f'Pier {i} fluted core')
            low, high = bell.bounds([core])
            self.assertGreater(high[2] - low[2], 5)
            self.assertGreater(max(high[j] - low[j] for j in (0, 1)), .6)
            sockets = [p for p in self.parts if p.name.startswith(f'Pier {i} vertebra')]
            self.assertGreaterEqual(len(sockets), 8)
            self.assertTrue(all(bell.edge_counts(p) == {2} for p in sockets))
            self.assertTrue(all(bell.signed_volume(p) > 0 for p in sockets))
        self.assertEqual(sum(p.role == 'niche_frame' for p in self.parts), 8)
        self.assertEqual(sum(p.role == 'niche_back' for p in self.parts), 8)
        self.assertGreater(bell.NICHE_DEPTH, .2)

    def test_clapper_suspension_and_negative_spaces(self):
        tongue = [p for p in self.parts if p.role == 'clapper']
        low, high = bell.bounds(tongue)
        self.assertGreater(low[2], 1)
        self.assertGreater(high[2], 6)
        self.assertLess(max(high[0], high[1]), .7)
        self.assertEqual(sum(p.role == 'clapper_segment' for p in self.parts), 7)
        self.assertGreater(bell.BELL_PROFILE[0][1] - .7, 1.5)
        apertures = [p for p in self.parts if p.role == 'clapper_cage']
        self.assertEqual(len(apertures), 6)
        self.assertTrue(all(bell.edge_counts(p) == {2} for p in apertures))

    def test_material_partition_uv_padding_and_budget(self):
        self.assertEqual(set(bell.GROUPS.values()), {'brass', 'ivory', 'tissue', 'amber'})
        self.assertTrue(all(p.kind in bell.KINDS for p in self.parts))
        self.assertLess(bell.triangles(self.parts), 21312)
        self.assertGreater(bell.triangles(self.parts), 8000)
        for kind in bell.KINDS:
            u0, v0, u1, v1 = bell.uv_rect(kind)
            self.assertTrue(0 < u0 < u1 < 1 and 0 < v0 < v1 < 1)
            self.assertGreaterEqual(u1 - u0, .20)
        self.assertNotIn('bpy', sys.modules)

    def test_closed_outward_solids(self):
        for part in self.parts:
            self.assertEqual(bell.edge_counts(part), {2}, part.name)
            self.assertGreater(bell.signed_volume(part), 0, part.name)

    def test_glb_fixture_is_deterministic_opaque_png_and_uv_tiles(self):
        data = png_fixture()
        self.assertEqual(data, png_fixture())
        self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II', data[16:24]), (512, 512))
        self.assertLess(len(data), 300000)
        import zlib
        offset=8; encoded=bytearray()
        while offset<len(data):
            size=struct.unpack_from('>I',data,offset)[0]
            if data[offset+4:offset+8]==b'IDAT': encoded.extend(data[offset+8:offset+8+size])
            offset+=12+size
        raw=zlib.decompress(encoded)
        for y in range(512):
            row=raw[y*2049+1:(y+1)*2049]
            self.assertEqual(set(row[3::4]),{255})
        for k,kind in enumerate(bell.KINDS):
            u0,v0,u1,v1=bell.uv_rect(kind)
            x=int((u0+u1)*256); y=int((1-(v0+v1)/2)*512)
            self.assertEqual((y//256)*4+x//128,k)

    def test_output_is_fresh_and_does_not_overlap_inputs(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            project = root / 'project'; project.mkdir()
            target = root / 'fresh'
            self.assertEqual(bell.validate_output(target, [project]), target)
            for bad in (project, root, project / 'child', root / 'existing'):
                if bad.name == 'existing': bad.mkdir()
                with self.assertRaises((ValueError, FileExistsError)):
                    bell.validate_output(bad, [project])
            link = root / 'alias'; link.symlink_to(project, target_is_directory=True)
            with self.assertRaises(ValueError): bell.validate_output(link / 'fresh', [project])
            with self.assertRaises(ValueError): bell.validate_output(str(root) + '/x/../fresh', [project])
            with self.assertRaises(ValueError): bell.validate_output('relative-output', [project])
            with self.assertRaises(ValueError): bell.validate_output(str(root)+'/./fresh', [project])
            with self.assertRaises(ValueError): bell.validate_output(str(root)+'//fresh', [project])

    def test_exclusive_write_never_overwrites(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'output'
            bell.write_new(p,b'first')
            with self.assertRaises(FileExistsError): bell.write_new(p,b'second')
            self.assertEqual(p.read_bytes(),b'first')

    def test_real_niche_depth_is_not_blocked_by_core(self):
        frame=next(p for p in self.parts if p.name=='Pier 0 niche frame 1')
        back=next(p for p in self.parts if p.name=='Pier 0 recessed niche back 1')
        core=next(p for p in self.parts if p.name=='Pier 0 fluted core')
        angle=math.atan2(-2.38,-2.38)+math.pi/2
        def local_y(v):
            center=bell.pier_center(v[2])
            return -(v[0]+center)*math.sin(angle)+(v[1]+center)*math.cos(angle)
        front=min(map(local_y,frame.vertices)); rear=min(map(local_y,back.vertices))
        core_front=min(local_y(v) for v in core.vertices if 1.55<=v[2]<=3.7)
        self.assertGreater(rear-front,.3)
        self.assertGreater(core_front,rear)

    def test_nearest_normalization_preserves_binary_and_inspects_valid_fixture(self):
        png=png_fixture(); png+=b'\0'*(-len(png)%4)
        positions=struct.pack('<9f',0,0,0,1,0,0,0,1,0)
        normals=struct.pack('<9f',*(0,0,1)*3); uv=struct.pack('<6f',0,0,1,0,0,1)
        indices=struct.pack('<3H',0,1,2)+b'\0\0'
        binary=png+positions+normals+uv+indices
        views=[{'buffer':0,'byteOffset':o,'byteLength':n} for o,n in ((0,len(png)),(len(png),36),(len(png)+36,36),(len(png)+72,24),(len(png)+96,6))]
        doc={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(binary)}],'bufferViews':views,
             'images':[{'bufferView':0,'mimeType':'image/png'}],'samplers':[{'magFilter':9728,'minFilter':9984}],
             'textures':[{'source':0,'sampler':0}], 'materials':[{'name':'skin_bell_'+group,'pbrMetallicRoughness':{'baseColorTexture':{'index':0}}} for group in ('brass','ivory','tissue','amber')],
             'accessors':[{'bufferView':1,'componentType':5126,'count':3,'type':'VEC3','min':[0,0,0],'max':[1,1,0]},
                          {'bufferView':2,'componentType':5126,'count':3,'type':'VEC3'},
                          {'bufferView':3,'componentType':5126,'count':3,'type':'VEC2'},
                          {'bufferView':4,'componentType':5123,'count':3,'type':'SCALAR'}],
             'meshes':[{'primitives':[{'indices':3,'material':i,'attributes':{'POSITION':0,'NORMAL':1,'TEXCOORD_0':2}}]} for i in range(4)],
             'nodes':[{'mesh':i} for i in range(4)],'scenes':[{'nodes':[0,1,2,3]}],'scene':0}
        doc['materials'][3]['emissiveFactor']=[.38,.16,.035]
        body=json.dumps(doc).encode(); body+=b' '*(-len(body)%4)
        original=struct.pack('<III',0x46546c67,2,28+len(body)+len(binary))+struct.pack('<II',len(body),0x4e4f534a)+body+struct.pack('<II',len(binary),0x004e4942)+binary
        with self.assertRaises(ValueError): bell.inspect_glb(original)
        duplicated = json.loads(json.dumps(doc))
        duplicated['textures'] = [{'source':0, 'sampler':0} for _ in range(4)]
        for i, mat in enumerate(duplicated['materials']): mat['pbrMetallicRoughness']['baseColorTexture']['index'] = i
        raw = json.dumps(duplicated).encode(); raw += b' ' * (-len(raw) % 4)
        duplicated_glb = struct.pack('<III',0x46546c67,2,28+len(raw)+len(binary))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(binary),0x004e4942)+binary
        invalid_bindings = [(key, value) for key in ('source','sampler') for value in (False,0.0)]
        for key, value in invalid_bindings:
            bad = json.loads(json.dumps(duplicated)); bad['textures'][0][key] = value
            raw_bad = json.dumps(bad).encode(); raw_bad += b' ' * (-len(raw_bad) % 4)
            blob_bad = struct.pack('<III',0x46546c67,2,28+len(raw_bad)+len(binary))+struct.pack('<II',len(raw_bad),0x4e4f534a)+raw_bad+struct.pack('<II',len(binary),0x004e4942)+binary
            with self.subTest(binding=key,value=value), self.assertRaises(ValueError): bell.nearest_glb(blob_bad)
        bad = json.loads(json.dumps(duplicated))
        bad['materials'][0]['extensions'] = {'KHR_materials_clearcoat':{'clearcoatTexture':{'index':2}}}
        raw_bad = json.dumps(bad).encode(); raw_bad += b' ' * (-len(raw_bad) % 4)
        blob_bad = struct.pack('<III',0x46546c67,2,28+len(raw_bad)+len(binary))+struct.pack('<II',len(raw_bad),0x4e4f534a)+raw_bad+struct.pack('<II',len(binary),0x004e4942)+binary
        with self.assertRaises(ValueError): bell.nearest_glb(blob_bad)
        shared = bell.nearest_glb(duplicated_glb)
        self.assertEqual(bell.inspect_glb(shared)['material_count'],4)
        n = struct.unpack_from('<I',shared,12)[0]; collapsed = json.loads(shared[20:20+n])
        self.assertEqual(collapsed['textures'],[{'source':0,'sampler':0}])
        self.assertTrue(all(m['pbrMetallicRoughness']['baseColorTexture']['index']==0 for m in collapsed['materials']))
        self.assertEqual(shared[20+n:],duplicated_glb[20+len(raw):])
        valid = json.loads(json.dumps(doc)); valid['samplers'][0]['minFilter'] = 9728
        mutations = (
            lambda g: g.update(textures=[]),
            lambda g: g['textures'][0].update(source=999),
            lambda g: g['textures'][0].update(sampler=999),
            lambda g: g['scenes'][0].update(nodes=[]),
            lambda g: g.update(scene=True),
            lambda g: g['nodes'][0].update(mesh=999),
            lambda g: g['accessors'][1].update(count=0),
            lambda g: g['accessors'][1].update(count=4),
            lambda g: g['accessors'][1].update(componentType=5121),
            lambda g: g['accessors'][1].update(bufferView=999),
            lambda g: g['bufferViews'][2].update(byteLength=8),
            lambda g: g['bufferViews'][2].update(byteOffset=len(binary)),
            lambda g: g['bufferViews'][3].update(byteStride=4),
            lambda g: g['bufferViews'][2].update(byteOffset=-1),
            lambda g: g['buffers'][0].update(byteLength=len(binary)-8),
            lambda g: g['meshes'][0]['primitives'][0].update(material=999),
            lambda g: g['images'][0].update(mimeType='image/jpeg'),
            lambda g: g['materials'][3].pop('emissiveFactor'),
            lambda g: g['materials'][2].update(emissiveFactor=[.38,.16,.035]),
            lambda g: g['materials'][3].update(emissiveFactor=[1.1,.16,.035]),
            lambda g: g['materials'][3].update(emissiveFactor=[True,.16,.035]),
            lambda g: g['materials'][3].update(emissiveFactor=[.38,.16]),
            lambda g: g['materials'][3].update(emissiveFactor=[float('nan'),.16,.035]),
            lambda g: g['materials'][3].update(emissiveTexture={'index':0}),
            lambda g: g['materials'][3].update(extensions={'KHR_materials_emissive_strength':{'emissiveStrength':2}}),
            lambda g: g.update(extensionsUsed=['unknown']),
            lambda g: g['meshes'][0]['primitives'][0].update(material=3),
            lambda g: g['materials'][3].update(name=[]),
            lambda g: g['materials'][3].update(name='skin_bell_tissue'),
            lambda g: g.update(extensionsRequired=['unknown']),
            lambda g: g['materials'][3].update(normalTexture={'index':0}),
            lambda g: g['materials'][3]['pbrMetallicRoughness'].update(metallicRoughnessTexture={'index':0}),
        )
        for i, mutate in enumerate(mutations):
            broken = json.loads(json.dumps(valid)); mutate(broken)
            raw = json.dumps(broken).encode(); raw += b' ' * (-len(raw) % 4)
            blob = struct.pack('<III',0x46546c67,2,28+len(raw)+len(binary))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(binary),0x004e4942)+binary
            with self.subTest(invalid_export=i), self.assertRaises(ValueError): bell.inspect_glb(blob)
        changed=bell.nearest_glb(original)
        record=bell.inspect_glb(changed)
        self.assertEqual(record['triangles'],4)
        self.assertEqual(record['runtime_mesh_nodes'],4)
        size=struct.unpack_from('<I',changed,12)[0]
        self.assertEqual(changed[28+size:],binary)

    def test_pin_rejects_changed_symlink_and_nonlocal_input(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp).resolve() / 'file'; p.write_bytes(b'original')
            digest = bell.sha(p)
            self.assertEqual(bell.pinned_file(p, digest), p)
            p.write_bytes(b'changed')
            with self.assertRaises(ValueError): bell.pinned_file(p, digest)
            link = p.parent / 'alias'; link.symlink_to(p)
            with self.assertRaises(ValueError): bell.pinned_file(link, bell.sha(p))
            with self.assertRaises(ValueError): bell.pinned_file('https://example.org/art.png', digest)

    def test_glb_inspector_rejects_invalid_and_external_resources(self):
        def glb(document):
            body = json.dumps(document).encode(); body += b' ' * (-len(body) % 4)
            binary = b'\0' * 12
            return struct.pack('<III', 0x46546c67, 2, 28 + len(body) + len(binary)) + struct.pack('<II', len(body), 0x4e4f534a) + body + struct.pack('<II', len(binary), 0x004e4942) + binary
        with self.assertRaises(ValueError): bell.inspect_glb(b'invalid')
        with self.assertRaises(ValueError): bell.inspect_glb(glb({'asset':{'version':'2.0'}, 'images':[{'uri':'escape.png'}]}))


if __name__ == '__main__':
    unittest.main()
