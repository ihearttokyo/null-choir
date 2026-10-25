"""Read the actual selected GLB geometry, UVs and embedded resource costs offline."""
import hashlib
import base64
import json
import math
from pathlib import Path
import struct


def require(ok,message):
    if not ok: raise ValueError(message)


def node_point(node,p):
    require('children' not in node,'Selected kit must have flat mesh nodes')
    if 'matrix' in node:
        m=node['matrix']; return [sum(m[j*4+i]*p[j] for j in range(3))+m[12+i] for i in range(3)]
    q=node.get('rotation',[0,0,0,1]); s=node.get('scale',[1,1,1]); t=node.get('translation',[0,0,0])
    require(abs(sum(x*x for x in q)-1)<1e-5,'Unit node quaternion')
    x,y,z,w=q; a,b,c=[p[i]*s[i] for i in range(3)]
    return [t[0]+(1-2*y*y-2*z*z)*a+2*(x*y-z*w)*b+2*(x*z+y*w)*c,
            t[1]+2*(x*y+z*w)*a+(1-2*x*x-2*z*z)*b+2*(y*z-x*w)*c,
            t[2]+2*(x*z-y*w)*a+2*(y*z+x*w)*b+(1-2*x*x-2*y*y)*c]


def facts(path,resource_root=None,points=False):
    raw=Path(path).read_bytes(); require(len(raw)>=28,'GLB header')
    magic,version,size=struct.unpack_from('<4sII',raw)
    require((magic,version,size)==(b'glTF',2,len(raw)),'GLB2 length')
    length,kind=struct.unpack_from('<I4s',raw,12); require(kind==b'JSON','GLB JSON')
    d=json.loads(raw[20:20+length]); offset=20+length
    n,kind=struct.unpack_from('<I4s',raw,offset); require(kind==b'BIN\0' and offset+8+n==len(raw),'Embedded GLB binary')
    binary=raw[offset+8:]; require(len(d['buffers'])==1 and 'uri' not in d['buffers'][0],'Self-contained GLB buffer')
    def accessor(index,components):
        a=d['accessors'][index]; v=d['bufferViews'][a['bufferView']]
        require(a['componentType']==5126 and a['type']=={2:'VEC2',3:'VEC3'}[components] and 'sparse' not in a,'Float geometry accessor')
        start=v.get('byteOffset',0)+a.get('byteOffset',0); stride=v.get('byteStride',components*4)
        return [struct.unpack_from('<'+'f'*components,binary,start+i*stride) for i in range(a['count'])]
    vertices=[]; triangles=0; uv_count=0; nodes=[]
    for node in d['nodes']:
        require('mesh' in node and 'skin' not in node,'Selected GLB contains only mesh nodes')
        local=[]
        for primitive in d['meshes'][node['mesh']]['primitives']:
            require(primitive.get('mode',4)==4 and 'targets' not in primitive,'Static triangle mesh')
            positions=accessor(primitive['attributes']['POSITION'],3)
            material=d.get('materials',[])[primitive['material']] if 'material' in primitive else {}
            textured=any('Texture' in k for k in list(material)+list(material.get('pbrMetallicRoughness',{})))
            require(not textured or 'TEXCOORD_0' in primitive['attributes'],'Textured primitive requires UV0')
            uv=accessor(primitive['attributes']['TEXCOORD_0'],2) if 'TEXCOORD_0' in primitive['attributes'] else []
            require(not uv or len(uv)==len(positions),'UV/position parity')
            require(all(math.isfinite(x) for p in positions+uv for x in p),'Finite positions and UVs')
            count=d['accessors'][primitive['indices']]['count'] if 'indices' in primitive else len(positions)
            require(count%3==0,'Triangle indices'); triangles+=count//3; uv_count+=len(uv)
            for p in positions:
                x,y,z=node_point(node,p);require(all(math.isfinite(v) for v in (x,y,z)),'Finite transformed geometry');local.append([x,-z,y])
        require(local,'Nonempty mesh node'); vertices.extend(local)
        nodes.append(dict(name=node.get('name','mesh'),bounds=[[min(p[i] for p in local) for i in range(3)],[max(p[i] for p in local) for i in range(3)]],
                          gltf_transform={k:node[k] for k in ('translation','rotation','scale','matrix') if k in node}))
    images=[]
    for image in d.get('images',[]):
        relative=None
        if 'uri' in image:
            uri=image['uri']
            if uri.startswith('data:image/png;base64,'):
                data=base64.b64decode(uri.split(',',1)[1],validate=True)
            else:
                require(not Path(uri).is_absolute() and not any(c in uri for c in (':','\\','%')),'Local relative image only')
                unresolved=Path(path).absolute().parent/uri
                require(not any(p.is_symlink() for p in (unresolved,*unresolved.parents)),'Symlink image forbidden')
                root=Path(resource_root).absolute() if resource_root else Path(path).absolute().parent.parent
                target=unresolved.resolve();require(target.is_relative_to(root) and target.is_file() and target.stat().st_nlink==1,'Image escapes pinned resource root')
                data=target.read_bytes();relative=target.relative_to(root).as_posix()
        else:
            require('bufferView' in image,'Embedded image required')
            v=d['bufferViews'][image['bufferView']]; start=v.get('byteOffset',0); data=binary[start:start+v['byteLength']]
        require(data[:8]==b'\x89PNG\r\n\x1a\n','Selected images are PNG'); width,height=struct.unpack('>II',data[16:24])
        images.append(dict(name=image.get('name','image'),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),width=width,height=height,decoded_rgba_bytes=width*height*4,relative_path=relative))
    result=dict(sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),triangles=triangles,
                bounds=[[min(p[i] for p in vertices) for i in range(3)],[max(p[i] for p in vertices) for i in range(3)]],
                node_bounds=nodes,uv0_count=uv_count,materials=[m.get('name','material') for m in d.get('materials',[])],images=images,
                embedded=all(i['relative_path'] is None for i in images),import_space='node TRS in glTF Y-up, then Blender XYZ=(x,-z,y)')

    if points:result['points']=vertices
    return result
