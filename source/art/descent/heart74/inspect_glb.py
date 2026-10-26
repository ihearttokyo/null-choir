"""Pinned GLB component inspection; no engine or resource mutation."""
import json, struct, hashlib
from pathlib import Path
import ancestor26 as p
from glb_inputs import node_point

def components(plan):
    asset=next(a for a in plan['assets'] if a['id']=='heart_mouth_restraint')
    pin=json.loads((p.ROOT/'inputs.json').read_text())['assets'][asset['id']]
    path=p.ROOT.parent/'intro-architecture-inputs02'/pin['path']
    raw=path.read_bytes();p.require(hashlib.sha256(raw).hexdigest()==pin['sha256'],'Pinned mouth GLB')
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
    def read(i,fmt):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt,binary,start+j*v.get('byteStride',struct.calcsize('<'+fmt))) for j in range(a['count'])]
    result=[]
    for node in doc['nodes']:
        for pi,prim in enumerate(doc['meshes'][node['mesh']]['primitives']):
            rawv=read(prim['attributes']['POSITION'],'3f');lookup={};verts=[];remap=[]
            for v in rawv:
                if v not in lookup:
                    lookup[v]=len(verts);x,y,z=node_point(node,v);verts.append(p.placed((x,-z,y),asset))
                remap.append(lookup[v])
            idx=prim['indices'];fmt={5121:'B',5123:'H',5125:'I'}[doc['accessors'][idx]['componentType']]
            ids=[i[0] for i in read(idx,fmt)];faces=[[remap[i] for i in ids[j:j+3]] for j in range(0,len(ids),3)]
            adj=[set() for _ in verts]
            for f in faces:
                for i in f:adj[i].update(f)
            remaining=set(range(len(verts)));groups=[]
            while remaining:
                group={min(remaining)};remaining-=group;todo=list(group)
                while todo:
                    for i in adj[todo.pop()]-group:group.add(i);remaining.discard(i);todo.append(i)
                groups.append(group)
            for ci,g in enumerate(groups):
                order=sorted(g);mapping={v:i for i,v in enumerate(order)}
                vs=[verts[i] for i in order];fs=[[mapping[i] for i in f] for f in faces if f[0] in g]
                result.append(dict(node=node['name'],primitive=pi,component=ci,vertices=vs,faces=fs,
                    source_indices=[j for j,f in enumerate(faces) if f[0] in g],bounds=p.bounds(vs),
                    projection=p.bounds([p.camera_ndc(plan['cameras']['heart'],v) for v in vs])))
    return result

if __name__=='__main__':
    c=components(p.make_plan())
    for x in c:print(x['node'],x['component'],len(x['vertices']),len(x['faces']),x['bounds'],x['projection'][:])
    Path('component-map47.json').write_text(json.dumps([{k:v for k,v in x.items() if k not in ('vertices','faces','source_indices')}|dict(vertices=len(x['vertices']),triangles=len(x['faces'])) for x in c],indent=2)+'\n')
