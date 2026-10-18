"""SIMULATED design-derived GLB boundary controls; never native asset evidence."""
import ast
import copy
import json
from pathlib import Path
import runpy
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]


def fixture_png(size=256):
    assert size in (256,512), 'density boundary fixture only'
    def chunk(kind,body):
        return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
    row=bytes((i%160+40 for i in range(size*3)))
    raw=(b'\0'+row)*size
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')


def fixture():
    h = runpy.run_path(str(ROOT / 'tools/build_ossuary_buttress.py'))
    doc = {'asset': {'version': '2.0', 'generator': 'SIMULATED actual-design boundary fixture'},
           'scene': 0, 'scenes': [{'nodes': [0, 2, 3, 4]}], 'buffers': [{}],
           'bufferViews': [], 'accessors': [], 'materials': [], 'meshes': [], 'nodes': [],
           'animations': []}
    binary = bytearray()

    def add(values, fmt, kind, component):
        binary.extend(b'\0' * (-len(binary) % 4))
        offset = len(binary)
        for value in values:
            binary.extend(struct.pack('<' + fmt, *value))
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary) - offset})
        doc['accessors'].append({'bufferView': len(doc['bufferViews']) - 1, 'componentType': component,
            'type': kind, 'count': len(values), 'min': [min(v[i] for v in values) for i in range(len(values[0]))],
            'max': [max(v[i] for v in values) for i in range(len(values[0]))]})
        return len(doc['accessors']) - 1

    triangles = 0
    parts = h['design']()
    for key in h['PALETTE']:
        vertices, indices, uvs = [], [], []
        for p in parts:
            if p['material'] != key:
                continue
            uv=h['material_uvs'](p);loop=0
            for face in p['faces']:
                offset=len(vertices)
                for j in face:
                    x,y,z=p['vertices'][j]
                    vertices.append((x,z-(1.7 if key=='muscle' else 0),-y))
                    u,v=uv[loop];uvs.append((u,1-v));loop+=1
                for i in range(1,len(face)-1):
                    indices.extend((offset+j,) for j in (0,i,i+1));triangles+=1
        positions = add(vertices, '3f', 'VEC3', 5126)
        faces = add(indices, 'H', 'SCALAR', 5123)
        field = add(uvs, '2f', 'VEC2', 5126)
        material = len(doc['materials'])
        doc['materials'].append({'name':key,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'baseColorTexture':{'index':0}}})
        doc['meshes'].append({'primitives': [{'attributes': {'POSITION': positions, 'TEXCOORD_0': field},
                            'indices': faces, 'material': material, 'mode': 4}]})
        doc['nodes'].append({'name': 'buttress_' + key, 'mesh': material})
    doc['nodes'].append({'name': 'Muscle_Pulse', 'translation': [0, 1.7, 0], 'children': [1]})
    times = add([(i / 25,) for i in range(61)], 'f', 'SCALAR', 5126)
    scales = add([(s[0], s[2], s[1]) for s in (h['pulse_scale'](i) for i in range(61))],
                 '3f', 'VEC3', 5126)
    doc['animations'].append({'name': 'Pulse', 'channels': [{'sampler': 0, 'target': {'node': 4, 'path': 'scale'}}],
                              'samplers': [{'input': times, 'output': scales, 'interpolation': 'LINEAR'}]})
    binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);image=fixture_png();binary.extend(image)
    doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(image)})
    doc['images']=[{'bufferView':len(doc['bufferViews'])-1,'mimeType':'image/png'}]
    doc['textures']=[{'source':0,'sampler':0}]
    doc['samplers']=[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]
    doc['buffers'][0]['byteLength'] = len(binary)
    return doc, binary, triangles


def glb(doc, binary):
    doc['buffers'][0]['byteLength'] = len(binary)
    raw = json.dumps(doc, separators=(',', ':')).encode()
    raw += b' ' * (-len(raw) % 4)
    payload = bytes(binary) + b'\0' * (-len(binary) % 4)
    return (struct.pack('<4sII', b'glTF', 2, 28 + len(raw) + len(payload)) +
            struct.pack('<I4s', len(raw), b'JSON') + raw +
            struct.pack('<I4s', len(payload), b'BIN\0') + payload)


def control(name, doc, binary):
    if name == 'zero_indices':
        for mesh in doc['meshes']:
            a = doc['accessors'][mesh['primitives'][0]['indices']]
            view = doc['bufferViews'][a['bufferView']]
            start = view['byteOffset']
            binary[start:start + view['byteLength']] = b'\0' * view['byteLength']
    elif name == 'out_of_range_index':
        primitive = doc['meshes'][0]['primitives'][0]
        view = doc['bufferViews'][doc['accessors'][primitive['indices']]['bufferView']]
        count = doc['accessors'][primitive['attributes']['POSITION']]['count']
        struct.pack_into('<H', binary, view['byteOffset'], count)
    elif name == 'zero_area_triangle':
        primitive = doc['meshes'][0]['primitives'][0]
        view = doc['bufferViews'][doc['accessors'][primitive['indices']]['bufferView']]
        a, b = struct.unpack_from('<2H', binary, view['byteOffset'])
        start = doc['bufferViews'][doc['accessors'][primitive['attributes']['POSITION']]['bufferView']]['byteOffset']
        binary[start + b * 12:start + (b + 1) * 12] = binary[start + a * 12:start + (a + 1) * 12]
    elif name == 'duplicate_active_node':
        doc['scenes'][0]['nodes'].append(0)
    elif name == 'connected_offset_sampler':
        binary.extend(b'\0' * (-len(binary) % 4))
        offset = len(binary)
        binary.extend(struct.pack('<61f', *(i / 25 + .04 for i in range(61))))
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': 61 * 4})
        doc['accessors'].append({'bufferView': len(doc['bufferViews']) - 1, 'componentType': 5126, 'type': 'SCALAR', 'count': 61})
        animation = doc['animations'][0]
        animation['samplers'].append(dict(animation['samplers'][0], input=len(doc['accessors']) - 1))
        animation['channels'][0]['sampler'] = 1
    elif name == 'neutral_connected_scale':
        a = doc['accessors'][doc['animations'][0]['samplers'][0]['output']]
        start = doc['bufferViews'][a['bufferView']]['byteOffset']
        for i in range(a['count']):
            struct.pack_into('<3f', binary, start + i * 12, 1, 1, 1)
    elif name in ('overlarge_connected_scale', 'overlarge_depth_scale'):
        a = doc['accessors'][doc['animations'][0]['samplers'][0]['output']]
        start = doc['bufferViews'][a['bufferView']]['byteOffset']
        struct.pack_into('<3f', binary, start + 17 * 12,
                         1.5 if name == 'overlarge_connected_scale' else 1, 1, 1.5)
    elif name in ('compensated_pulse_pivot', 'compensated_transverse_pivot',
                  'compensated_depth_pivot', 'shifted_muscle_child', 'shifted_depth_child'):
        if name == 'compensated_pulse_pivot':
            doc['nodes'][4]['translation'][1] += 10
            doc['nodes'][1]['translation'] = [0, -10, 0]
        elif name == 'compensated_transverse_pivot':
            doc['nodes'][4]['translation'][0] += 10
            doc['nodes'][1]['translation'] = [-10, 0, 0]
        elif name == 'compensated_depth_pivot':
            doc['nodes'][4]['translation'][2] += 10
            doc['nodes'][1]['translation'] = [0, 0, -10]
        else:
            axis, shift = (0, 1) if name == 'shifted_muscle_child' else (2, -1)
            doc['nodes'][1]['translation'] = [shift if i == axis else 0 for i in range(3)]
            a = doc['accessors'][doc['meshes'][1]['primitives'][0]['attributes']['POSITION']]
            start = doc['bufferViews'][a['bufferView']]['byteOffset']
            for i in range(a['count']):
                offset = start + i * 12 + axis * 4
                value = struct.unpack_from('<f', binary, offset)[0]
                struct.pack_into('<f', binary, offset, value - shift)
    elif name=='missing_uv':
        del doc['meshes'][0]['primitives'][0]['attributes']['TEXCOORD_0']
    elif name in ('wrong_quadrant','truncated_uv','collapsed_uv'):
        a=doc['accessors'][doc['meshes'][0]['primitives'][0]['attributes']['TEXCOORD_0']]
        view=doc['bufferViews'][a['bufferView']];start=view['byteOffset']
        if name=='truncated_uv':view['byteLength']-=1
        elif name=='wrong_quadrant':struct.pack_into('<2f',binary,start,.75,.75)
        else:
            for i in range(a['count']):struct.pack_into('<2f',binary,start+i*8,.25,.25)
    elif name=='external_image':doc['images'][0]['uri']='outside.png'
    elif name=='mip_filter':doc['samplers'][0]['minFilter']=9984
    elif name=='unknown_extension':doc['materials'][0]['extensions']={'unsupported':{}}
    elif name=='bad_image_span':doc['bufferViews'][doc['images'][0]['bufferView']]['byteLength']+=100
    elif name=='bad_png_crc':
        start=doc['bufferViews'][doc['images'][0]['bufferView']]['byteOffset'];binary[start+29]^=1
    elif name=='double_pigment':doc['materials'][0]['pbrMetallicRoughness']['baseColorFactor']=[.5,.5,.5,1]
    elif name=='vertex_pigment':doc['meshes'][0]['primitives'][0]['attributes']['COLOR_0']=0
    elif name=='normalized_triangle_indices':doc['accessors'][doc['meshes'][0]['primitives'][0]['indices']]['normalized']=True
    elif name == 'empty_active_scene':
        doc['scenes'][0]['nodes'] = []
    elif name == 'raised_10m':
        for index in doc['scenes'][0]['nodes']:
            node = doc['nodes'][index]
            node['translation'] = [a + b for a, b in zip(node.get('translation', [0, 0, 0]), (0, 10, 0))]
    elif name == 'bone_under_pulse':
        doc['scenes'][0]['nodes'].remove(0)
        doc['nodes'][4]['children'].append(0)
        doc['nodes'][0]['translation'] = [0, -1.7, 0]
    elif name == 'offset_timeline':
        a = doc['accessors'][doc['animations'][0]['samplers'][0]['input']]
        start = doc['bufferViews'][a['bufferView']]['byteOffset']
        for i in range(a['count']):
            struct.pack_into('<f', binary, start + i * 4, struct.unpack_from('<f', binary, start + i * 4)[0] + .04)
    elif name=='uv_half_density':
        for mesh in doc['meshes']:
            primitive=mesh['primitives'][0]
            material=doc['materials'][primitive['material']]['name']
            col,row={'bone':(0,0),'muscle':(1,0),'bronze':(0,1),'charcoal':(1,1)}[material]
            a=doc['accessors'][primitive['attributes']['TEXCOORD_0']]
            view=doc['bufferViews'][a['bufferView']];start=view['byteOffset']
            for i in range(a['count']):
                u,v=struct.unpack_from('<2f',binary,start+i*8)
                struct.pack_into('<2f',binary,start+i*8,(col/2+.25)+(u-(col/2+.25))*.5,(row/2+.25)+(v-(row/2+.25))*.5)
    else:
        raise AssertionError('Unknown one-variable control')


def check_boundary():
    h = runpy.run_path(str(ROOT / 'tools/ossuary_buttress_contract.py'))
    validate = h['validate_glb']
    for component, fmt in ((5121, 'B'), (5123, 'H'), (5125, 'I')):
        packed = struct.pack('<' + fmt * 3, 0, 1, 2)
        meta = {'buffers': [{'byteLength': len(packed)}],
                'bufferViews': [{'buffer': 0, 'byteLength': len(packed)}],
                'accessors': [{'bufferView': 0, 'componentType': component, 'type': 'SCALAR', 'count': 3}]}
        assert h['accessor'](meta, packed, 0) == [(0,), (1,), (2,)]
        meta['bufferViews'][0]['byteLength'] -= 1
        try:
            h['accessor'](meta, packed, 0)
        except (AssertionError,ValueError,KeyError) as exc:
            assert str(exc) == 'accessor byte bounds'
        else:
            raise AssertionError('truncated unsigned index accessor accepted')
    print('SIMULATED_UNSIGNED_GREEN uint8/16/32 decode and truncation rejection')
    doc, binary, triangles = fixture()
    assert validate(glb(doc, binary), triangles) == 1656
    print('SIMULATED_VALID_GREEN triangles=1656')
    wrong_density=copy.deepcopy(doc);payload=bytearray(binary)
    view=wrong_density['bufferViews'][wrong_density['images'][0]['bufferView']]
    png=fixture_png(512);payload[view['byteOffset']:]=png;view['byteLength']=len(png)
    try:
        validate(glb(wrong_density,payload),triangles)
    except ValueError as exc:
        assert str(exc)=='PNG geometry/profile'
    else:
        raise AssertionError('512 atlas accepted by256 density contract')
    print('SIMULATED_DENSITY_GREEN complete256 RGB8 accepted; complete512 RGB8 rejected')
    producer=runpy.run_path(str(ROOT/'tools/build_ossuary_buttress.py'))
    rawdoc,payload,count=fixture();rawdoc['samplers'][0]['minFilter']=9984
    rawdoc['textures'].append({'source':0,'sampler':0});rawdoc['materials'][1]['pbrMetallicRoughness']['baseColorTexture']['index']=1
    normalized=producer['nearest_glb'](glb(rawdoc,payload))
    assert validate(normalized,count)==1656
    rawlen=struct.unpack_from('<I',normalized,12)[0]
    assert normalized[28+rawlen:]==bytes(payload)+b'\0'*(-len(payload)%4)
    print('SIMULATED_NEAREST_GREEN duplicate descriptors coalesced; BIN unchanged')
    failed = []
    for channel in ('normalTexture','occlusionTexture','emissiveTexture','metallicRoughnessTexture'):
        altered=copy.deepcopy(rawdoc)
        material=altered['materials'][0]
        target=material['pbrMetallicRoughness'] if channel=='metallicRoughnessTexture' else material
        target[channel]={'index':1}
        try:
            producer['nearest_glb'](glb(altered,payload))
        except (AssertionError,ValueError,KeyError):
            print('SIMULATED_REJECT unsupported material channel: '+channel)
        else:
            failed.append('normalizer_'+channel)
    for name in ('zero_indices','empty_active_scene','raised_10m','bone_under_pulse','offset_timeline',
                 'out_of_range_index','zero_area_triangle','duplicate_active_node','connected_offset_sampler','neutral_connected_scale',
                 'missing_uv','wrong_quadrant','truncated_uv','collapsed_uv','external_image','mip_filter','unknown_extension',
                 'bad_image_span','bad_png_crc','double_pigment','vertex_pigment','normalized_triangle_indices'):
        altered, payload = copy.deepcopy(doc), bytearray(binary)
        control(name, altered, payload)
        try:
            validate(glb(altered, payload), triangles)
        except (AssertionError,ValueError,KeyError) as exc:
            print('SIMULATED_REJECT ' + name + ': ' + str(exc))
        else:
            print('SIMULATED_FALSE_ACCEPT ' + name)
            failed.append(name)
    altered,payload=copy.deepcopy(doc),bytearray(binary)
    control('uv_half_density',altered,payload)
    try:
        validate(glb(altered,payload),triangles)
    except AssertionError as exc:
        assert str(exc)=='UV world density', 'density fault rejected for unrelated reason: '+str(exc)
        print('SIMULATED_REJECT uv_half_density: UV world density')
    else:
        raise AssertionError('compressed UV density accepted')
    for name, reason in (('overlarge_connected_scale', 'transverse Pulse scale limits'),
                         ('overlarge_depth_scale', 'transverse Pulse scale limits'),
                         ('compensated_pulse_pivot', 'fixed Pulse pivot'),
                         ('compensated_transverse_pivot', 'fixed Pulse pivot'),
                         ('compensated_depth_pivot', 'animated Pulse envelope')):
        altered, payload = copy.deepcopy(doc), bytearray(binary)
        control(name, altered, payload)
        try:
            validate(glb(altered, payload), triangles)
        except AssertionError as exc:
            assert str(exc) == reason, name + ': ' + str(exc)
            print('SIMULATED_REJECT ' + name + ': ' + reason)
        else:
            raise AssertionError(name + ' accepted')
    # Equivalent mesh-local rebasing exercises child translation in every posed sample.
    for name in ('shifted_muscle_child', 'shifted_depth_child'):
        altered, payload = copy.deepcopy(doc), bytearray(binary)
        control(name, altered, payload)
        assert validate(glb(altered, payload), triangles) == triangles
    print('SIMULATED_PULSE_GREEN all61 connected samples; X/depth child-local rebasing preserved')
    source = ast.parse((ROOT / 'tools/build_ossuary_buttress.py').read_text())
    call = next(n for n in ast.walk(source) if isinstance(n, ast.Call) and
                isinstance(n.func, ast.Attribute) and n.func.attr == 'gltf')
    enabled = any(k.arg == 'export_anim_slide_to_zero' and isinstance(k.value, ast.Constant) and
                  k.value.value is True for k in call.keywords)
    if not enabled:
        print('SOURCE_FALSE_ACCEPT export_anim_slide_to_zero unset')
        failed.append('export_anim_slide_to_zero')
    assert not failed, 'review regressions: ' + ', '.join(failed)
    print('SIMULATED_BOUNDARY_GREEN 22 prior negatives plus4 unsupported-channel controls; zero-based export option')


"""Independent08 depth-only Pulse contract; source poses are not native/render evidence."""
import math
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]


def check_pulse():
    h = runpy.run_path(str(ROOT / 'tools/build_ossuary_buttress.py'))
    scales = [h['pulse_scale'](frame) for frame in range(61)]
    failures = []
    if scales[30] != (1.0, 1.30, 1.0):
        failures.append('Pulse peak must be (1.0,1.30,1.0): ' + str(scales[30]))
    if scales[0] != scales[-1] or scales[0] != (1, 1, 1):
        failures.append('identity Pulse endpoints')
    if not all(s[0] == s[2] == 1 for s in scales):
        failures.append('constant X and longitudinal Z')
    assert not failures, '; '.join(failures)
    assert all(len(s) == 3 and all(math.isfinite(v) for v in s) for s in scales)
    assert all(1 <= s[1] <= 1.30 for s in scales)
    assert scales == scales[::-1], 'symmetric source loop'
    parts = h['design']()
    posed, muscle = [], []
    for scale in scales:
        for p in parts:
            for vertex in p['vertices']:
                point = tuple((0, 0, 1.7)[i] + scale[i] * (vertex[i] - (0, 0, 1.7)[i])
                              for i in range(3)) if p['material'] == 'muscle' else vertex
                assert all(lo - 1e-9 <= v <= hi + 1e-9 for v, lo, hi in
                           zip(point, (-.6, -.45, 0), (.6, .45, 3.4))), 'source posed envelope'
                posed.append(point)
                if p['material'] == 'muscle':
                    muscle.append(point)
    bounds = lambda points: [[fn(v[i] for v in points) for i in range(3)] for fn in (min, max)]
    print('SOURCE_PULSE_GREEN samples=61 peak=(1.0,1.30,1.0) endpoints=identity X/Z=fixed '
          f'posed_vertices={len(posed)} bounds={bounds(posed)} muscle_bounds={bounds(muscle)}')



"""Actual-source UV pairs; bounded approximation, never exact nonplanar isometry."""
import itertools
import math
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]


def check_uv():
    h=runpy.run_path(str(ROOT/'tools/build_ossuary_buttress.py'))
    ratios=[];minimum_gutter=math.inf;faces=0
    for p in h['design']():
        uv=h['material_uvs'](p)
        assert len(uv)==sum(len(face) for face in p['faces'])
        assert all(math.isfinite(c) for point in uv for c in point)
        col,row={'bone':(0,0),'muscle':(1,0),'bronze':(0,1),'charcoal':(1,1)}[p['material']]
        points=[(u,1-v) for u,v in uv];offset=0
        for face in p['faces']:
            face_uv=points[offset:offset+len(face)];faces+=1
            for u,v in face_uv:
                gutter=min(u-col/2,(col+1)/2-u,v-row/2,(row+1)/2-v)*256
                assert gutter>=4, 'four actual pixel gutters'
                minimum_gutter=min(minimum_gutter,gutter)
            for i,j in itertools.combinations(range(len(face)),2):
                a,b=[p['vertices'][face[k]] for k in (i,j)]
                assert all(math.isfinite(c) for point in (a,b) for c in point)
                distance=math.dist(a,b);assert distance>1e-12, 'distinct source face vertices'
                ratio=math.dist(face_uv[i],face_uv[j])/(.25*distance)
                assert .98<=ratio<=1.02, 'source UV world density: '+p['name']+' '+str((face[i],face[j]))+' ratio='+repr(ratio)
                ratios.append(ratio)
            assert abs((min(u for u,v in face_uv)+max(u for u,v in face_uv))/2-(col/2+.25))<1e-12, 'face centered U'
            assert abs((min(v for u,v in face_uv)+max(v for u,v in face_uv))/2-(row/2+.25))<1e-12, 'face centered V'
            offset+=len(face)
    assert h['UV_PER_M']==.25
    assert len(ratios)==5022
    print('UV_DENSITY_GREEN faces='+str(faces)+' pairs='+str(len(ratios))+' min='+repr(min(ratios))+' max='+repr(max(ratios))+' gutter_px='+repr(minimum_gutter))
    return {'faces':faces,'pairs':len(ratios),'minimum_ratio':min(ratios),'maximum_ratio':max(ratios),'minimum_gutter_px':minimum_gutter}


import runpy,struct,zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
EXIF=bytes.fromhex('4d4d002a00000018000000480000000100000048000000010002011a00050000000100000008011b0005000000010000001000000000')
OFFSET=bytes(9)
def chunk(kind,body):
 return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
def check_png():
 h=runpy.run_path(str(ROOT/'tools/build_ossuary_buttress.py'))
 assert 'canonical_atlas_png' in h, 'native PNG metadata compatibility missing'
 canonical=h['canonical_atlas_png'];core=fixture_png();head=core[:33];tail=core[33:]
 native=head+chunk(b'eXIf',EXIF)+chunk(b'oFFs',OFFSET)+tail
 assert canonical(core)==core and canonical(native)==core, 'retain exact IHDR/IDAT bytes'
 badcrc=bytearray(native);badcrc[45]^=1
 bad=[core[:8]+chunk(b'eXIf',EXIF)+core[8:],bytes(badcrc),native[:-1],head+chunk(b'eXIf',EXIF[:-1]+b'1')+tail,head+chunk(b'oFFs',bytes(8)+b'1')+tail,head+chunk(b'eXIf',EXIF)*2+tail,head+chunk(b'tEXt',b'unknown')+tail,core[:-12]+chunk(b'eXIf',EXIF)+core[-12:],fixture_png(512),b'X'+native[1:],b'0'*(256*1024+1)]
 for index,data in enumerate(bad):
  try:canonical(data)
  except (AssertionError,ValueError):pass
  else:raise AssertionError('invalid PNG accepted '+str(index))
 print('PNG_CANONICAL_GREEN exact native metadata only; unchanged image bytes;11 boundary rejects')

"""Texture and metadata contracts; all engine evidence remains a separate gate."""
import ast
from pathlib import Path
import runpy
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]


def check_texture():
    h = runpy.run_path(str(ROOT / 'tools/build_ossuary_buttress.py'))
    assert 'material_uvs' in h, 'atlas UVs absent from flat-pigment baseline'
    assert h['tile_bounds']('bone')==(4/256,.5-4/256,4/256,.5-4/256), 'four actual pixels at256 density'
    for p in h['design']():
        uvs = h['material_uvs'](p)
        assert len(uvs) == sum(len(f) for f in p['faces'])
        u0,u1,v0,v1 = h['tile_bounds'](p['material'])
        assert all(u0 <= u <= u1 and v0 <= 1-v <= v1 for u,v in uvs)
    source = ast.parse((ROOT / 'tools/build_ossuary_buttress.py').read_text())
    build = next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='build')
    calls = [n for n in ast.walk(build) if isinstance(n,ast.Call)]
    clean = next(n.lineno for n in calls if isinstance(n.func,ast.Name) and n.func.id=='sanitize_source_paths')
    save = next(n.lineno for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr=='save_as_mainfile')
    assert clean < save, 'sanitize before first source save'
    assert 'ShaderNodeVertexColor' not in (ROOT / 'tools/build_ossuary_buttress.py').read_text()
    assert 'color_attributes.new' not in (ROOT / 'tools/build_ossuary_buttress.py').read_text()
    h['assert_clean_source'](b'BLENDER\0//ossuary_atlas.png\0')
    for marker in h['PRIVATE_MARKERS']:
        try:
            h['assert_clean_source'](b'BLENDER\0' + marker)
        except AssertionError:
            pass
        else:
            raise AssertionError('private binary marker accepted')
    # SIMULATED fixed RNA buffer: shorter assignments leave old trailing bytes.
    class Buffer:
        bl_rna = SimpleNamespace(properties={'filepath':SimpleNamespace(length_max=128)})
        def __init__(self):
            self.raw=bytearray(128)
        def __setattr__(self,name,value):
            if name=='filepath':
                encoded=value.encode()+b'\0';self.raw[:len(encoded)]=encoded
            else:
                object.__setattr__(self,name,value)
    owner=Buffer();owner.filepath='/Users/example/.codex/tasks/worker-private.png';owner.filepath='//atlas.png'
    assert b'.codex/tasks/' in owner.raw
    h['_portable_path'](owner,'filepath','//atlas.png')
    h['assert_clean_source'](bytes(owner.raw))
    print('TEXTURE_SOURCE_GREEN quadrant gutters and fixed-buffer/privacy controls; SIMULATED RNA')



def check_structure():
    h = runpy.run_path(str(ROOT / 'tools/build_ossuary_buttress.py'))
    parts = h['design']()
    assert parts == h['design'](), 'deterministic geometry'
    assert len({p['name'] for p in parts}) == len(parts), 'editable named parts'
    assert {p['material'] for p in parts} == {'bone', 'muscle', 'bronze', 'charcoal'}
    points = [v for p in parts for v in p['vertices']]
    assert all(len(v) == 3 and all(math.isfinite(c) for c in v) for v in points)
    triangles = 0
    for p in parts:
        for face in p['faces']:
            assert len(face) >= 3 and len(face) == len(set(face))
            assert all(0 <= i < len(p['vertices']) for i in face)
            triangles += len(face) - 2
        volume = 0.0
        for face in p['faces']:
            a = p['vertices'][face[0]]
            for i in range(1, len(face) - 1):
                b, c = p['vertices'][face[i]], p['vertices'][face[i + 1]]
                volume += sum(a[j] * (b[(j + 1) % 3] * c[(j + 2) % 3] -
                              b[(j + 2) % 3] * c[(j + 1) % 3]) for j in range(3)) / 6
        assert volume > 0, 'outward winding: ' + p['name']
    assert 0 < triangles <= 2000, 'unchanged triangle ceiling'
    lo = [min(v[i] for v in points) for i in range(3)]
    hi = [max(v[i] for v in points) for i in range(3)]
    assert all(abs(hi[i] - lo[i] - n) < .002 for i, n in enumerate((1.2, .9, 3.4)))
    assert lo[2] == 0 and all(abs(lo[i] + hi[i]) < .002 for i in (0, 1))
    pores = [p for p in parts if p['name'].startswith('Open bone aperture')]
    assert len(pores) == 4
    # Closed annular solids have a genuine tunnel rather than a dark painted disk.
    for p in pores:
        n = len(p['vertices']) // 4
        assert n == 12 and len(p['faces']) == n * 4
        assert all(len(face) == 4 for face in p['faces'])
    assert h['pulse_scale'](0) == h['pulse_scale'](60) == (1, 1, 1)
    assert h['pulse_scale'](30) == (1.0, 1.30, 1.0)
    print(f'STATIC_GREEN parts={len(parts)} triangles={triangles} bounds=1.2x0.9x3.4 groups=4')


def check_controls():
    check_structure()
    check_pulse()
    check_uv()
    check_texture()
    check_png()
    check_boundary()
