"""Lossless shared-atlas GLB packaging for the isolated cathedral kit."""
import json
import struct
import zlib

ATLAS_URI = '../textures/cathedral_kit_atlas.png'


def require(ok, message):
    if not ok: raise ValueError(message)


def index(i, values):
    require(type(i) is int and 0 <= i < len(values), 'Invalid glTF reference')
    return values[i]


def pairs(items):
    result = {}
    for k, v in items:
        require(k not in result, 'Duplicate JSON property')
        result[k] = v
    return result


def constant(value):
    raise ValueError('Nonfinite JSON value: ' + value)


def png_check(data):
    require(data[:8] == b'\x89PNG\r\n\x1a\n', 'Require unchanged PNG atlas')
    offset = 8; kinds = []
    while offset < len(data):
        require(offset + 12 <= len(data), 'Truncated PNG chunk')
        length, kind = struct.unpack_from('>I4s', data, offset)
        end = offset + 12 + length
        require(end <= len(data), 'Invalid PNG chunk range')
        require(zlib.crc32(data[offset+4:end-4]) & 0xffffffff == struct.unpack_from('>I', data, end-4)[0], 'PNG CRC mismatch')
        kinds.append(kind)
        if kind == b'IHDR':
            require(length == 13, 'Invalid PNG header')
            w,h,depth,color,compression,filtering,interlace = struct.unpack_from('>IIBBBBB',data,offset+8)
            require(0 < w <= 1024 and 0 < h <= 1024 and (depth,color,compression,filtering,interlace) == (8,6,0,0,0), 'Require authored RGBA8 atlas')
        offset = end
    require(kinds.count(b'IHDR')==1 and kinds.count(b'IEND')==1 and kinds[0:1] == [b'IHDR'] and kinds[-1:] == [b'IEND'] and b'IDAT' in kinds, 'Incomplete PNG')


def externalize_atlas(data, atlas):
    """Remove only the identical embedded PNG view; retain every mesh stream byte."""
    try:
        return _externalize(data, atlas)
    except (KeyError, IndexError, TypeError, struct.error, UnicodeDecodeError) as error:
        raise ValueError('Malformed or unsupported cathedral GLB') from error


def _externalize(data, atlas):
    require(28 <= len(data) <= 16*1024*1024, 'GLB outside candidate size limit')
    require(struct.unpack_from('<4sII', data) == (b'glTF',2,len(data)), 'Invalid GLB header')
    n,kind = struct.unpack_from('<I4s',data,12)
    require(kind == b'JSON' and n % 4 == 0 and 20+n+8 <= len(data), 'Invalid JSON chunk')
    bn,kind = struct.unpack_from('<I4s',data,20+n)
    require(kind == b'BIN\0' and bn % 4 == 0 and 28+n+bn == len(data), 'Require exactly JSON and BIN chunks')
    doc = json.loads(data[20:20+n],object_pairs_hook=pairs,parse_constant=constant)
    allowed = {'asset','scene','scenes','nodes','materials','meshes','accessors','bufferViews','buffers','textures','samplers','images','extensionsUsed'}
    require(isinstance(doc,dict) and not doc.keys()-allowed and doc['asset']['version']=='2.0', 'Unsupported static glTF profile')
    require(set(doc.get('extensionsUsed',[])) <= {'KHR_materials_emissive_strength'}, 'Unsupported binary extension')
    require(len(doc['buffers']) == 1 and set(doc['buffers'][0]) == {'byteLength'}, 'Require one embedded buffer')
    binary = data[28+n:]; size = doc['buffers'][0]['byteLength']
    require(type(size) is int and 0 < size <= bn and bn-size < 4 and binary[size:] == b'\0'*(bn-size), 'Invalid embedded buffer length/padding')
    views = doc['bufferViews']; spans = []
    for view in views:
        require(not view.keys()-{'buffer','byteOffset','byteLength','byteStride','target','name'}, 'Unsupported view property')
        start,length = view.get('byteOffset',0),view['byteLength']
        require(type(view['buffer']) is int and view['buffer']==0 and type(start) is int and type(length) is int and start>=0 and start%4==0 and length>0 and start+length<=size, 'Invalid buffer view range/alignment')
        spans.append((start,start+length))
    ordered = sorted(spans)
    require(all(a[1] <= b[0] for a,b in zip(ordered,ordered[1:])), 'Overlapping buffer views')
    require(len(doc['images'])==1, 'Require one shared atlas image')
    image = doc['images'][0]
    require(not image.keys()-{'name','mimeType','bufferView'} and image['mimeType']=='image/png', 'Require embedded PNG image')
    removed = image['bufferView']; view = index(removed,views); start = view.get('byteOffset',0)
    require(binary[start:start+view['byteLength']] == atlas, 'Embedded atlas must match shared PNG byte-for-byte')
    png_check(atlas)
    for a in doc['accessors']:
        require(not a.keys()-{'bufferView','byteOffset','componentType','count','type','min','max','normalized','name'}, 'Unsupported accessor property')
        view=index(a['bufferView'],views); require(a['bufferView'] != removed, 'Image view is referenced by accessor')
        width={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}.get(a['componentType'])
        components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}.get(a['type'])
        count,offset=a['count'],a.get('byteOffset',0)
        require(width and components and type(count) is int and count>0 and type(offset) is int and offset>=0 and offset%width==0, 'Invalid accessor layout')
        stride=view.get('byteStride',width*components)
        require(type(stride) is int and stride>=width*components and stride%width==0 and offset+(count-1)*stride+width*components<=view['byteLength'], 'Accessor exceeds view')
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            require(not p.keys()-{'attributes','indices','material','mode'}, 'Unsupported primitive reference')
            for a in p['attributes'].values():index(a,doc['accessors'])
            if 'indices' in p:index(p['indices'],doc['accessors'])
            if 'material' in p:index(p['material'],doc['materials'])
    for texture in doc['textures']:
        require(not texture.keys()-{'sampler','source','name'}, 'Unsupported texture extension')
        index(texture['source'],doc['images'])
        if 'sampler' in texture:index(texture['sampler'],doc.get('samplers',[]))
    known_refs={id(image),*(id(a) for a in doc['accessors'])}
    def check_references(value):
        if isinstance(value,dict):
            require('bufferView' not in value or id(value) in known_refs, 'Unrecognized buffer view reference')
            for child in value.values():check_references(child)
        elif isinstance(value,list):
            for child in value:check_references(child)
    check_references(doc)
    packed = bytearray(); kept = []; mapping = {}
    for old,view in enumerate(views):
        if old == removed:continue
        packed.extend(b'\0'*(-len(packed)%4)); new = dict(view); new['byteOffset']=len(packed)
        start=view.get('byteOffset',0); packed.extend(binary[start:start+view['byteLength']])
        mapping[old]=len(kept); kept.append(new)
    for a in doc['accessors']:a['bufferView']=mapping[a['bufferView']]
    image.pop('bufferView'); image['uri']=ATLAS_URI
    doc['bufferViews']=kept; doc['buffers'][0]['byteLength']=len(packed)
    encoded=json.dumps(doc,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode(); encoded+=b' '*(-len(encoded)%4)
    packed.extend(b'\0'*(-len(packed)%4))
    result=(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(packed))+
            struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(packed),b'BIN\0')+packed)
    require(len(result)<len(data), 'Shared-atlas candidate did not reduce bytes')
    return result
