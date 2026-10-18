"""Bounded buttress PNG/GLB contract, independent of Blender and gameplay."""
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import zlib

MAX_CAPTURE_BYTES = 8 * 1024 * 1024
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'

def validate_png(data, width, height):
    """Bounded static 8-bit PNG profile. Does not certify pixels or native origin."""
    if type(width) is not int or type(height) is not int or not 1 <= width <= 1280 or not 1 <= height <= 720:
        raise ValueError('Bounded PNG dimensions')
    if type(data) is not bytes or not 8 < len(data) <= MAX_CAPTURE_BYTES or not data.startswith(PNG_SIGNATURE):
        raise ValueError('Bounded PNG required')
    offset, chunks = 8, 0
    raw = bytearray()
    decoder = zlib.decompressobj()
    stride = expected = None
    idat = ended_idat = ended = False
    ancillary = {b'sRGB': 1, b'gAMA': 4, b'cHRM': 32, b'pHYs': 9}
    try:
        while offset < len(data):
            chunks += 1
            if chunks > 1024 or len(data)-offset < 12:
                raise ValueError('PNG chunk cap/truncation')
            size = struct.unpack_from('>I', data, offset)[0]
            kind = data[offset+4:offset+8]
            end = offset+12+size
            if end > len(data):
                raise ValueError('PNG truncation')
            body = memoryview(data)[offset+8:end-4]
            if zlib.crc32(body, zlib.crc32(kind))&0xffffffff != struct.unpack_from('>I', data, end-4)[0]:
                raise ValueError('PNG CRC')
            if chunks == 1:
                if kind != b'IHDR' or size != 13:
                    raise ValueError('PNG header')
                w, h, bits, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', body)
                channels = {0:1, 2:3, 4:2, 6:4}.get(color)
                if (w != width or h != height or bits != 8 or channels is None
                        or (compression, filtering, interlace) != (0,0,0)):
                    raise ValueError('PNG geometry/profile')
                stride = 1+width*channels
                expected = height*stride
            elif kind == b'IDAT':
                if ended_idat:
                    raise ValueError('Nonconsecutive PNG image data')
                idat = True
                output = decoder.decompress(body, expected-len(raw)+1)
                if len(raw)+len(output) > expected or decoder.unconsumed_tail or decoder.unused_data:
                    raise ValueError('PNG expansion cap/extra stream')
                raw.extend(output)
            elif kind == b'IEND':
                if size or not idat or end != len(data):
                    raise ValueError('PNG end')
                ended = True
            else:
                # No animation, compressed text/profile or unknown decode allocation.
                if kind not in ancillary or size != ancillary[kind]:
                    raise ValueError('Unsupported PNG chunk')
                ended_idat = idat
            offset = end
        if not ended or not decoder.eof or len(raw) != expected or any(raw[i] > 4 for i in range(0,len(raw),stride)):
            raise ValueError('PNG stream/scanlines')
    except (struct.error, zlib.error, TypeError):
        raise ValueError('Invalid bounded PNG.') from None


def accessor(doc, binary, index):
    assert type(index) is int and 0 <= index < len(doc['accessors']), 'accessor index'
    a = doc['accessors'][index]
    formats = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
    assert a['componentType'] in formats and a['type'] in ('SCALAR', 'VEC2', 'VEC3'), 'accessor format'
    assert type(a['componentType']) is int and not a.get('sparse') and not a.get('normalized',False), 'explicit accessor normalization'
    fmt, size = formats[a['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
    assert a['componentType'] == 5126 or width == 1, 'unsigned scalar indices'
    count, view_index = a['count'], a['bufferView']
    assert type(count) is int and count > 0, 'accessor count'
    assert type(view_index) is int and 0 <= view_index < len(doc['bufferViews']), 'buffer view index'
    view = doc['bufferViews'][view_index]
    assert type(view['buffer']) is int and view['buffer'] == 0, 'embedded buffer'
    offset, length = view.get('byteOffset', 0), view['byteLength']
    local, stride = a.get('byteOffset', 0), view.get('byteStride', size * width)
    assert all(type(v) is int and v >= 0 for v in (offset, length, local, stride)), 'byte bounds'
    assert stride >= size * width and stride % size == 0 and (offset + local) % size == 0, 'accessor stride/alignment'
    assert offset + length <= doc['buffers'][0]['byteLength'] <= len(binary), 'buffer view bounds'
    assert local + (count - 1) * stride + size * width <= length, 'accessor byte bounds'
    values = [struct.unpack_from('<' + fmt * width, binary, offset + local + i * stride) for i in range(count)]
    assert all(math.isfinite(v) for row in values for v in row), 'finite accessor values'
    return values


def validate_glb(data, triangles, exported=False):
    assert len(data) >= 28 and struct.unpack_from('<4sII', data) == (b'glTF', 2, len(data)), 'GLB header'
    length, kind = struct.unpack_from('<I4s', data, 12)
    assert kind == b'JSON' and length % 4 == 0 and 20 + length + 8 <= len(data), 'JSON chunk bounds'
    doc = json.loads(data[20:20 + length])
    offset = 20 + length
    length, kind = struct.unpack_from('<I4s', data, offset)
    assert kind == b'BIN\0' and length % 4 == 0 and offset + 8 + length == len(data), 'BIN chunk bounds'
    binary = data[offset + 8:]
    assert len(doc['buffers']) == 1 and 'uri' not in doc['buffers'][0]
    assert type(doc['buffers'][0]['byteLength']) is int and len(binary) - 3 <= doc['buffers'][0]['byteLength'] <= len(binary)
    assert not doc.get('cameras') and not doc.get('skins')
    assert len(data)<=512*1024, 'compact runtime GLB budget'
    def standard(value):
        if isinstance(value,dict):
            assert not any(value.get(k) for k in ('extensions','extensionsUsed','extensionsRequired')), 'unsupported extension'
            for child in value.values():standard(child)
        elif isinstance(value,list):
            for child in value:standard(child)
    standard(doc)
    assert len(doc.get('images',[]))==len(doc.get('samplers',[]))==1, 'one embedded atlas/sampler'
    textures=doc.get('textures',[])
    assert len(textures)==1 or (exported and 1<=len(textures)<=4), 'one runtime atlas binding'
    assert all(t=={'source':0,'sampler':0} and all(type(t[k]) is int for k in t) for t in textures)
    sampler=doc['samplers'][0]
    assert set(sampler)<= {'magFilter','minFilter','wrapS','wrapT'}
    assert all(type(v) is int for v in sampler.values())
    assert sampler.get('magFilter')==9728 and sampler.get('minFilter') in ((9728,9984,9986) if exported else (9728,)), 'nearest no-mip atlas'
    assert sampler.get('wrapS')==sampler.get('wrapT')==33071, 'clamped atlas'
    image=doc['images'][0]
    assert set(image)<= {'bufferView','mimeType','name'} and image.get('mimeType')=='image/png'
    image_index=image['bufferView']
    assert type(image_index) is int and 0<=image_index<len(doc['bufferViews'])
    view=doc['bufferViews'][image_index];start=view.get('byteOffset',0);length=view['byteLength']
    assert type(view['buffer']) is int and view['buffer']==0
    assert type(start) is int and type(length) is int and start>=0 and length>0 and start+length<=doc['buffers'][0]['byteLength'], 'atlas byte bounds'
    png=binary[start:start+length]
    validate_png(png,256,256)
    assert png[25]==2, 'opaque RGB atlas'

    assert len(doc['materials']) == len(doc['meshes']) == 4
    assert {m['name'] for m in doc['materials']} == {'bone', 'muscle', 'bronze', 'charcoal'}
    assert '/Users/' not in json.dumps(doc) and '/private/' not in json.dumps(doc)
    nodes = doc['nodes']
    assert all(not any(word in n.get('name', '').lower() for word in ('collider', 'collision', 'camera', 'light')) for n in nodes)
    pulse = [i for i, n in enumerate(nodes) if n.get('name') == 'Muscle_Pulse']
    assert len(pulse) == 1 and 'mesh' not in nodes[pulse[0]], 'one muscle pulse parent'
    pulse = pulse[0]
    scene = doc.get('scene', 0)
    assert type(scene) is int and 0 <= scene < len(doc['scenes']), 'active scene index'
    seen, parents, mesh_nodes, meshes, groups, exported = set(), {}, set(), set(), set(), []
    measured = 0
    pulse_local_vertices = []

    def walk(index, parent, shift):
        nonlocal measured
        assert type(index) is int and 0 <= index < len(nodes) and index not in seen, 'active node exactly once'
        seen.add(index)
        parents[index] = parent
        node = nodes[index]
        assert 'matrix' not in node and node.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
        assert node.get('scale', [1, 1, 1]) == [1, 1, 1]
        translation = node.get('translation', [0, 0, 0])
        assert len(translation) == 3 and all(type(v) in (int, float) and math.isfinite(v) for v in translation)
        shift = tuple(shift[i] + translation[i] for i in range(3))
        if 'mesh' in node:
            mesh_index = node['mesh']
            assert type(mesh_index) is int and 0 <= mesh_index < 4 and mesh_index not in meshes, 'four distinct active meshes'
            mesh_nodes.add(index)
            meshes.add(mesh_index)
            assert not node.get('children'), 'mesh leaves'
            primitives = doc['meshes'][mesh_index]['primitives']
            assert len(primitives) == 1
            primitive = primitives[0]
            assert primitive.get('mode', 4) == 4, 'triangle primitive mode'
            material = primitive['material']
            assert type(material) is int and 0 <= material < 4 and material not in groups, 'four distinct material groups'
            groups.add(material)
            name = doc['materials'][material]['name']
            assert node['name'] == 'buttress_' + name, 'material/mesh identity'
            assert parent == (pulse if name == 'muscle' else None), 'only muscle beneath Pulse'
            position, indices = primitive['attributes']['POSITION'], primitive['indices']
            assert doc['accessors'][position]['componentType'] == 5126 and doc['accessors'][position]['type'] == 'VEC3'
            local_vertices = accessor(doc, binary, position)
            vertices = [tuple(v[i] + shift[i] for i in range(3)) for v in local_vertices]
            assert not any(k.startswith('COLOR_') for k in primitive['attributes']), 'unused vertex pigment'
            material_spec=doc['materials'][material]
            assert not any(k.endswith('Texture') for k in material_spec), 'unsupported material texture channel'
            pbr=material_spec['pbrMetallicRoughness']
            assert not any(k.endswith('Texture') and k!='baseColorTexture' for k in pbr), 'unsupported PBR texture channel'
            assert pbr.get('baseColorFactor',[1,1,1,1])==[1,1,1,1], 'untinted atlas'
            binding=pbr['baseColorTexture']
            assert set(binding)<= {'index','texCoord'} and binding.get('texCoord',0)==0
            assert type(binding['index']) is int and 0<=binding['index']<len(textures)
            assert doc['materials'][material].get('alphaMode','OPAQUE')=='OPAQUE'
            uv_index=primitive['attributes']['TEXCOORD_0']
            assert doc['accessors'][uv_index]['componentType']==5126 and doc['accessors'][uv_index]['type']=='VEC2'
            uvs=accessor(doc,binary,uv_index)
            assert len(uvs)==len(vertices)
            col,row={'bone':(0,0),'muscle':(1,0),'bronze':(0,1),'charcoal':(1,1)}[name]
            pad=4/256
            assert all(col/2+pad-1e-7<=u<=(col+1)/2-pad+1e-7 and row/2+pad-1e-7<=v<=(row+1)/2-pad+1e-7 for u,v in uvs), 'UV quadrant gutters'
            assert doc['accessors'][indices]['componentType'] in (5121, 5123, 5125) and doc['accessors'][indices]['type'] == 'SCALAR'
            indices = [row[0] for row in accessor(doc, binary, indices)]
            assert len(indices) % 3 == 0, 'complete triangle indices'
            for start in range(0, len(indices), 3):
                face = indices[start:start + 3]
                assert len(set(face)) == 3, 'repeated triangle indices'
                assert all(i < len(vertices) for i in face), 'triangle index out of range'
                a, b, c = (vertices[i] for i in face)
                u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
                cross = [u[(i + 1) % 3] * v[(i + 2) % 3] - u[(i + 2) % 3] * v[(i + 1) % 3] for i in range(3)]
                assert sum(n * n for n in cross) > 1e-20, 'zero-area triangle'
                t0,t1,t2=[uvs[i] for i in face]
                assert abs((t1[0]-t0[0])*(t2[1]-t0[1])-(t1[1]-t0[1])*(t2[0]-t0[0]))>1e-12, 'collapsed atlas UV triangle'
                for i,j in ((0,1),(1,2),(2,0)):
                    ratio=math.dist((t0,t1,t2)[i],(t0,t1,t2)[j])/(.25*math.dist((a,b,c)[i],(a,b,c)[j]))
                    assert .98<=ratio<=1.02, 'UV world density'
                exported.extend((a, b, c))
            measured += len(indices) // 3
            if name == 'muscle':
                pulse_local_vertices.extend(tuple(local_vertices[j][i] + translation[i] for i in range(3))
                                            for j in sorted(set(indices)))
        for child in node.get('children', []):
            walk(child, index, shift)

    for root in doc['scenes'][scene].get('nodes', []):
        walk(root, None, (0, 0, 0))
    assert len(mesh_nodes) == 4 and mesh_nodes == {i for i, n in enumerate(nodes) if 'mesh' in n}, 'four active mesh nodes'
    assert pulse in seen and parents[pulse] is None and len(nodes[pulse].get('children', [])) == 1, 'muscle-only pulse hierarchy'
    assert measured == triangles and 0 < measured <= 2000 and len(groups) == 4
    lo, hi = [[fn(v[i] for v in exported) for i in range(3)] for fn in (min, max)]
    assert abs(lo[1]) < .002 and all(abs(lo[i] + hi[i]) < .002 for i in (0, 2)), 'ground-centered referenced geometry'
    assert all(abs(hi[i] - lo[i] - n) < .002 for i, n in enumerate((1.2, 3.4, .9)))
    assert len(doc['animations']) == 1 and doc['animations'][0]['name'] == 'Pulse'
    animation = doc['animations'][0]
    assert len(animation['channels']) == 1, 'one connected scale channel'
    channel = animation['channels'][0]
    assert channel['target'] == {'node': pulse, 'path': 'scale'}, 'muscle-only scale target'
    sampler_index = channel['sampler']
    assert type(sampler_index) is int and 0 <= sampler_index < len(animation['samplers']), 'connected sampler index'
    sampler = animation['samplers'][sampler_index]
    assert sampler.get('interpolation', 'LINEAR') == 'LINEAR', 'sampled scale interpolation'
    assert doc['accessors'][sampler['input']]['componentType'] == 5126 and doc['accessors'][sampler['input']]['type'] == 'SCALAR'
    assert doc['accessors'][sampler['output']]['componentType'] == 5126 and doc['accessors'][sampler['output']]['type'] == 'VEC3'
    times = [row[0] for row in accessor(doc, binary, sampler['input'])]
    values = accessor(doc, binary, sampler['output'])
    assert len(times) == len(values) and len(times) >= 3, 'matching connected scale samples'
    assert len(times) == 61 and all(abs(t - i / 25) < .000001 for i, t in enumerate(times)), '61 connected Pulse samples'
    assert all(a < b for a, b in zip(times, times[1:])), 'ordered connected timestamps'
    assert abs(times[0]) < .000001 and abs(times[-1] - 2.4) < .001, 'zero-to-2.4 connected timeline'
    assert abs(times[-1] - times[0] - 2.4) < .001
    assert all(abs(a - b) < .000001 for a, b in zip(values[0], values[-1]))
    assert all(abs(v - 1) < .000001 for v in values[0]), 'neutral loop endpoints'
    assert all(abs(v[1] - 1) < .000001 for v in values), 'longitudinal Pulse scale'
    assert all(abs(v[0] - 1) < .000001 and
               1 - .000001 <= v[2] <= 1.30 + .000001 for v in values), 'transverse Pulse scale limits'
    assert all(abs(v - peak) < .000001 for v, peak in zip(values[30], (1.0, 1.0, 1.30))), 'connected Pulse peak'
    pivot = nodes[pulse].get('translation', [0, 0, 0])
    assert pulse_local_vertices
    for scale in values:
        for vertex in pulse_local_vertices:
            posed = tuple(pivot[i] + scale[i] * vertex[i] for i in range(3))
            assert all(low - .002 <= p <= high + .002 for p, low, high in
                       zip(posed, (-.6, 0, -.45), (.6, 3.4, .45))), 'animated Pulse envelope'
    assert all(abs(v - expected) < .000001 for v, expected in zip(pivot, (0, 1.7, 0))), 'fixed Pulse pivot'
    return measured



def validate_entry(root, entry):
    """Certify catalog identity and shipped bytes, not staging or playback policy."""
    from tools.art_recipe import validate_recipe
    from tools.build_ossuary_buttress import DEPENDENCIES, REFERENCES, ATLAS_REFERENCE, ATLAS_SHA, assert_clean_source
    root = Path(root)
    assert entry['id'] == 'ossuary_living_buttress'
    assert 'level_id' not in entry and 'tradition_aesthetic' not in entry
    validate_recipe(root, entry, 'tools/build_ossuary_buttress.py', DEPENDENCIES)
    assert entry['recipe_dependencies'] == DEPENDENCIES
    assert entry['source'] == 'source/art/ossuary_living_buttress_v1.blend'
    assert len(entry['outputs']) == 1
    output = entry['outputs'][0]
    assert output['path'] == 'game/assets/art/world/ossuary_living_buttress.glb'
    assert entry['atlas']['path'] == 'source/art/ossuary_atlas.png'
    references = dict(REFERENCES, **{ATLAS_REFERENCE: ATLAS_SHA})
    assert entry['provenance']['references'] == [{'path': path, 'sha256': pin} for path, pin in references.items()]
    assert entry['provenance']['method'] == 'original Blender geometry and authored pixel textures'
    assert entry['provenance']['imports'] == []
    assert entry['animation'] == {'name': 'Pulse', 'seconds': 2.4, 'samples': 61,
                                  'pivot_blender': [0, 0, 1.7], 'peak_scale_blender': [1, 1.30, 1],
                                  'production_autoplay_configured': False}
    assert entry['collision'] == 'none; decorative catalog asset, not placed in gameplay'
    assert entry['triangles'] == 1656 and entry['source_mesh_count'] == 33
    assert entry['runtime_mesh_nodes'] == entry['material_count'] == 4
    assert entry['physical_bounds_m'] == {'min': [-.6, -.45, 0], 'max': [.6, .45, 3.4], 'size': [1.2, .9, 3.4]}
    def owned(relative):
        path = root / relative
        assert not any(p.is_symlink() for p in (path, *path.parents)), 'symlinked art input'
        assert path.is_file() and path.stat().st_nlink == 1, 'missing or aliased art input'
        return path.read_bytes()
    source = owned(entry['source'])
    assert source.startswith(b'BLENDER')
    assert hashlib.sha256(source).hexdigest() == entry['source_sha256']
    assert_clean_source(source)
    blob, atlas = owned(output['path']), owned(entry['atlas']['path'])
    for data, record in ((blob, output), (atlas, entry['atlas'])):
        assert len(data) == record['bytes'] and hashlib.sha256(data).hexdigest() == record['sha256']
        assert_clean_source(data)
    assert len(source) + len(blob) + len(atlas) <= 2 * 1024 * 1024
    validate_png(atlas, 256, 256)
    assert validate_glb(blob, 1656) == 1656
    length = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20 + length])
    image = doc['bufferViews'][doc['images'][0]['bufferView']]
    start = 28 + length + image.get('byteOffset', 0)
    assert blob[start:start + image['byteLength']] == atlas, 'shipped embedded/adjacent atlas parity'
    for relative, pin in references.items():
        data = owned(relative)
        assert hashlib.sha256(data).hexdigest() == pin
        assert_clean_source(data)
