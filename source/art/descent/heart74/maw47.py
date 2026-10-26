"""Mouth-only replacement: pinned component ownership, finite editable geometry."""
import copy
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
import ancestor26 as base
from inspect_glb import components

PREFIX='heart maw47 '
OWNED={'heart_mouth_restraint_bruised':{0},'heart_mouth_restraint_suture':{0},
       'heart_mouth_restraint_warm':set(range(20,53))}
REMOVED=4744

def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()

def recipe():
    return dict(generation=47,chapter=8,fold_depth=.12,tooth_curve=.34,wet_roughness=.27,
                sectors=64,teeth=24,removed_triangles=REMOVED,original_glb_sha256='32c16a0cc222b57b4464553b0ae722cf27e4f98f0035d6446d1a9ed03a38c55d')

def schema(r):
    expected=recipe();base.require(type(r) is dict and set(r)==set(expected),'Maw47 recipe fields')
    for k,lo,hi in [('fold_depth',.08,.18),('tooth_curve',.25,.45),('wet_roughness',.22,.36)]:
        v=r[k];base.require(type(v) in (int,float) and lo<=v<=hi and math.isfinite(v),'Maw47 finite bounded '+k)
    base.require(all(type(r[k]) is type(expected[k]) and r[k]==expected[k] for k in expected if k not in ('fold_depth','tooth_curve','wet_roughness')),'Maw47 fixed ownership/budget/schema')

def selected(c):return c['component'] in OWNED.get(c['node'],set())

def mapping(plan):
    cs=components(plan);owned=[c for c in cs if selected(c)]
    base.require(len(owned)==35 and sum(len(c['faces']) for c in owned)==3940,'Maw47 exact pinned owned components')
    base.require(sum(len(c['faces']) for c in cs)==9824,'Maw47 actual GLB triangle accounting')
    return cs

def sculpt(plan,r):
    schema(r);skin=base.heart_skin_geometry(plan);cx,cz=skin['center'];n=r['sectors'];out=[]
    def grid(name,rings,mat,closed=False):
        vertices=[v for ring in rings for v in ring];faces=[];rows=len(rings)
        for j in range(rows if closed else rows-1):
            for i in range(n):
                # Radial cross-section runs front-to-inside-to-back: outward winding.
                face=[j*n+i,j*n+(i+1)%n,((j+1)%rows)*n+(i+1)%n,((j+1)%rows)*n+i]
                faces.append(list(reversed(face)) if closed else face)
        out.append(dict(name=PREFIX+name,chapter=8,material=mat,vertices=vertices,faces=faces))
    # Twelve rounded cross-section stations carry asymmetric overlapping radial lobes.
    rings=[]
    for j in range(12):
        b=math.tau*j/12;ring=[]
        for i in range(n):
            a=math.tau*i/n;fold=r['fold_depth']*(.5+.5*math.cos(18*a+.8*math.sin(3*a)))
            radius=3.48+(.69+fold)*math.cos(b)
            y=7.55+(1.02+.12*math.sin(5*a))*math.sin(b)-fold*(1-math.sin(b))
            angle=a+.025*math.sin(b)*math.sin(7*a)
            ring.append([cx+radius*math.cos(angle),y,cz+radius*math.sin(angle)])
        rings.append(ring)
    grid('muscle cuff',rings,'maw47_flesh',True)
    rings=[]
    for j in range(4):
        b=math.tau*j/4;ring=[]
        for i in range(n):
            a=math.tau*i/n;chip=.06*max(0,math.sin(13*a+.3))**6
            radius=4.12+(.15-chip)*math.cos(b)+.035*math.sin(9*a)
            ring.append([cx+radius*math.cos(a),6.88+.17*math.sin(b)+.06*math.sin(7*a),cz+radius*math.sin(a)])
        rings.append(ring)
    grid('chipped lip',rings,'maw47_bone',True)
    rings=[]
    for radius,y in [(3.33,7.85),(2.78,8.95),(skin['profile'][-1][0],10.159000027179719),(skin['profile'][-1][0],11.15)]:
        rings.append([[cx+radius*math.cos(a),y,cz+radius*math.sin(a)] for a in [math.tau*i/n for i in range(n)]])
    grid('open dark throat',rings,'maw47_throat')
    for tooth in range(r['teeth']):
        angle=math.tau*(tooth+.13*math.sin(tooth*2.3))/r['teeth'];length=1.0+.30*(.5+.5*math.sin(tooth*2.17))
        vertices=[];faces=[]
        for j in range(6):
            t=j/5;radius=3.7-length*t;turn=r['tooth_curve']*math.sin(t*math.pi/2)*(1 if tooth%3 else -.65)
            a=angle+turn;thickness=1.6*(.23+.04*math.sin(tooth))*((1-t)**.7)+.012
            center=[cx+radius*math.cos(a),6.61+.12*math.sin(tooth*1.7)-.25*math.sin(math.pi*t)+.48*t*t,cz+radius*math.sin(a)]
            for k in range(8):
                b=math.tau*k/8;vertices.append([center[0]-thickness*math.sin(a)*math.cos(b),center[1]+thickness*.85*math.sin(b),center[2]+thickness*math.cos(a)*math.cos(b)])
            if j:
                for k in range(8):
                    a0=(j-1)*8+k;a1=(j-1)*8+(k+1)%8;faces.append([a0,a1,a1+8,a0+8])
        faces.extend([list(reversed(range(8))),list(range(40,48))])
        out.append(dict(name=PREFIX+f'tooth {tooth:02d}',chapter=8,material='maw47_bone',vertices=vertices,faces=faces))
    return out

def apply(plan):
    r=recipe();plan['heart_maw47']=r
    plan['meshes']=[m for m in plan['meshes'] if not m['name'].startswith('heart relief18 ')]+sculpt(plan,r)
    return plan

def project(plan):
    schema(plan.get('heart_maw47'));ancestor=base.make_plan();expected=sculpt(ancestor,plan['heart_maw47'])
    parts=[m for m in plan['meshes'] if m['name'].startswith(PREFIX)]
    base.require(digest(parts)==digest(expected),'Maw47 exact new geometry/material/ownership')
    actual={k:v for k,v in plan.items() if k!='heart_maw47'}
    actual['meshes']=[m for m in plan['meshes'] if not m['name'].startswith(PREFIX)]
    untouched=dict(ancestor,meshes=[m for m in ancestor['meshes'] if not m['name'].startswith('heart relief18 ')])
    base.require(digest(actual)==digest(untouched),'Maw47 exact no-touch26 plan fingerprint')
    count=sum(len(f)-2 for m in parts for f in m['faces'])
    base.require(count==4640 and count<=REMOVED,'Maw47 actual replacement triangle budget')
    return ancestor

def materials(materials,r):
    schema(r)
    for name,source in [('maw47_flesh','heart_flesh'),('maw47_bone','heart_bone'),('maw47_throat','heart_flesh')]:
        mat=materials[source].copy();mat.name='descent '+name
        rough=mat.node_tree.nodes['Heart23 roughness'].color_ramp
        values=(r['wet_roughness']-.05,r['wet_roughness']+.08) if name!='maw47_bone' else (.32,.58)
        for e,v in zip(rough.elements,values):e.color=(v,v,v,1)
        if name=='maw47_throat':
            for e in mat.node_tree.nodes['Heart23 material strata'].color_ramp.elements:
                e.color=tuple(v*.065 for v in e.color[:3])+(1,)
        materials[name]=mat

def face_points(vertices,face):return sorted(tuple(vertices[i]) for i in face)

def owned_native_faces(obj,cs):
    """Match actual world-space imported triangles, never guessed polygon indices."""
    from mathutils import Vector
    expected=[face_points(c['vertices'],f) for c in cs if selected(c) and c['node']==obj.name for f in c['faces']]
    bins=defaultdict(list)
    def key(v):return tuple(math.floor(sum(p[k] for p in v)/3/.01) for k in range(3))
    for i,v in enumerate(expected):bins[key(v)].append(i)
    matched=set();remove=set();world=[list(obj.matrix_world @ v.co) for v in obj.data.vertices]
    for face in obj.data.polygons:
        v=face_points(world,list(face.vertices));base.require(len(v)==3,'Maw47 imported triangles only');cell=key(v)
        hits=[]
        for delta in __import__('itertools').product((-1,0,1),repeat=3):
            for i in bins.get(tuple(cell[k]+delta[k] for k in range(3)),[]):
                if all(abs(a-b)<3e-5 for u,w in zip(v,expected[i]) for a,b in zip(u,w)):hits.append(i)
        base.require(len(hits)<=1,'Maw47 ambiguous native component')
        if hits:matched.add(hits[0]);remove.add(face.index)
    base.require(len(matched)==len(expected)==len(remove),'Maw47 actual native component coverage')
    return remove

def residual(mesh,keep):
    edges={tuple(sorted((a,b))) for f in mesh.polygons if f.index in keep for a,b in zip(list(f.vertices),list(f.vertices)[1:]+list(f.vertices)[:1])}
    return dict(vertices=[list(v.co) for v in mesh.vertices],faces=[list(f.vertices) for f in mesh.polygons if f.index in keep],
                smooth=[f.use_smooth for f in mesh.polygons if f.index in keep],materials=[m.name for m in mesh.materials],
                material_indices=[f.material_index for f in mesh.polygons if f.index in keep],
                uv=[(uv.name,[list(uv.data[i].uv) for f in mesh.polygons if f.index in keep for i in f.loop_indices]) for uv in mesh.uv_layers],
                uv_active=(mesh.uv_layers.active_index,[uv.active_render for uv in mesh.uv_layers]),
                custom_normals=mesh.has_custom_normals,
                normals=[list(mesh.corner_normals[i].vector) for f in mesh.polygons if f.index in keep for i in f.loop_indices],
                sharp_edges=sorted((tuple(sorted(e.vertices)),e.use_edge_sharp) for e in mesh.edges if tuple(sorted(e.vertices)) in edges))

def residual_parity(before,after):
    base.require({k:v for k,v in before.items() if k!='normals'}=={k:v for k,v in after.items() if k!='normals'},'Maw47 residual exact geometry/UV/material/edge parity')
    base.require(len(before['normals'])==len(after['normals']),'Maw47 residual normal count')
    error=max((abs(a-b) for v,w in zip(before['normals'],after['normals']) for a,b in zip(v,w)),default=0)
    base.require(error<1e-6,'Maw47 residual split-normal parity')
    return error

def replace_imports(scene,plan):
    cs=mapping(project(plan));receipt={}
    for name in OWNED:
        obj=scene.objects.get(name);base.require(obj is not None and obj.get('source_asset')=='heart_mouth_restraint','Maw47 native exact imported owner')
        old=obj.data;remove=owned_native_faces(obj,cs);keep=set(range(len(old.polygons)))-remove;before=residual(old,keep)
        # Copy raw custom data; setting decoded normals re-quantizes them.
        import bmesh
        mesh=old.copy();bm=bmesh.new()
        try:
            bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm,geom=[bm.faces[i] for i in sorted(remove)],context='FACES_ONLY')
            bm.to_mesh(mesh)
        finally:bm.free()
        mesh.update()
        error=residual_parity(before,residual(mesh,set(range(len(mesh.polygons)))))
        obj.data=mesh;receipt[name]=dict(removed=len(remove),residual_sha256=digest({k:v for k,v in before.items() if k!='normals'}),max_split_normal_error=error)
    base.require(sum(v['removed'] for v in receipt.values())==3940,'Maw47 actual removed imported triangle accounting')
    scene['maw47_residual_receipt']=json.dumps(receipt,sort_keys=True)
    return receipt

def material_record(mat):
    def value(v):
        if isinstance(v,(int,float,bool,str)):return round(v,6) if isinstance(v,float) else v
        try:return [round(x,6) for x in v]
        except TypeError:return str(type(v).__name__)
    nodes={}
    for n in mat.node_tree.nodes:
        r=dict(type=n.bl_idname,inputs={s.identifier:value(s.default_value) for s in n.inputs if hasattr(s,'default_value')})
        for k in ('operation','blend_type','noise_dimensions','normalize','distribution'):
            if hasattr(n,k):r[k]=getattr(n,k)
        if hasattr(n,'color_ramp'):r['ramp']=[(round(e.position,6),value(e.color)) for e in n.color_ramp.elements]
        nodes[n.name]=r
    return dict(nodes=nodes,links=sorted((l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier) for l in mat.node_tree.links))

def native_parity(scene,plan,edited=False):
    from mathutils import Matrix
    project(plan);parts=[m for m in plan['meshes'] if m['name'].startswith(PREFIX)]
    base.require({o.name for o in scene.objects if o.name.startswith(PREFIX)}=={m['name'] for m in parts},'Maw47 native mesh inventory')
    for part in parts:
        obj=scene.objects[part['name']];mesh=obj.data
        base.require(obj.type=='MESH' and obj.get('chapter')==8 and obj.get('pulse')==False and
                     sorted(c.name for c in obj.users_collection)==['08_heart'] and obj.matrix_world==Matrix.Identity(4) and
                     not obj.modifiers and obj.animation_data is None,'Maw47 native owner/editable transform')
        base.require(len(mesh.vertices)==len(part['vertices']) and [list(f.vertices) for f in mesh.polygons]==part['faces'] and
                     all(f.use_smooth for f in mesh.polygons),'Maw47 native topology/smoothing')
        for i,(v,w) in enumerate(zip(mesh.vertices,part['vertices'])):
            target=list(w)
            if edited and part['name']==PREFIX+'tooth 00' and i==0:target[0]+=.125
            base.require(max(abs(v.co[k]-target[k]) for k in range(3))<1e-5,'Maw47 actual changed mesh vertices')
        base.require(len(mesh.materials)==1 and mesh.materials[0].name=='descent '+part['material'],'Maw47 native owned material source')
        base.require(len(mesh.uv_layers)==1 and all(max(abs(a-b) for a,b in zip(uv.uv,w))<2e-5
                     for uv,w in zip(mesh.uv_layers[0].data,base.mesh_uvs(part))),'Maw47 native UV parity')
    for name,source in [('maw47_flesh','heart_flesh'),('maw47_bone','heart_bone'),('maw47_throat','heart_flesh')]:
        actual=next(m for o in scene.objects if o.type=='MESH' for m in o.data.materials if m and m.name=='descent '+name)
        source_mat=next(m for o in scene.objects if o.type=='MESH' for m in o.data.materials if m and m.name=='descent '+source+' surface23')
        expected=material_record(source_mat);rough=expected['nodes']['Heart23 roughness']['ramp']
        values=(plan['heart_maw47']['wet_roughness']-.05,plan['heart_maw47']['wet_roughness']+.08) if name!='maw47_bone' else (.32,.58)
        expected['nodes']['Heart23 roughness']['ramp']=[(p,[round(v+(.02 if edited and name=='maw47_flesh' else 0),6)]*3+[1.0]) for (p,_),v in zip(rough,values)]
        if name=='maw47_throat':
            ramp=source_mat.node_tree.nodes['Heart23 material strata'].color_ramp
            expected['nodes']['Heart23 material strata']['ramp']=[(round(e.position,6),[round(v*.065,6) for v in e.color[:3]]+[1.0]) for e in ramp.elements]
        base.require(material_record(actual)==expected,'Maw47 exact cloned material recipe '+name)
        base.require(all(o.name.startswith(PREFIX) for o in scene.objects if o.type=='MESH' and actual in list(o.data.materials)),'Maw47 no shared outside material users')
    return scene.objects[PREFIX+'tooth 00']

def no_touch(scene,plan):
    records=base.native_atmosphere26_no_touch(scene,plan)
    records={k:v for k,v in records.items() if not k.startswith(PREFIX)}
    air=scene.objects[plan['heart_atmosphere26']['name']]
    records['maw47_exact_air']=digest(dict(matrix=[list(r) for r in air.matrix_world],mesh=residual(air.data,set(range(len(air.data.polygons)))),hide=air.hide_render,
        shader=material_record(air.data.materials[0]),chapter=air.get('chapter'),collections=sorted(c.name for c in air.users_collection)))
    mats={m.name:material_record(m) for o in scene.objects if o.type=='MESH' for m in o.data.materials if m and not m.name.startswith('descent maw47_')}
    records['maw47_unchanged_shaders']=digest(mats)
    records['maw47_imported_residues']=scene.get('maw47_residual_receipt')
    for name in OWNED:
        obj=scene.objects.get(name)
        base.require(obj is not None,'Maw47 persistent imported owner')
        records['maw47_normals:'+name]=[list(n.vector) for n in obj.data.corner_normals]
    return records

def native_verify(bpy,scene,directory,blend,plan,set_view):
    """Actual persisted edit/revert gate. Run only by parent; no render or subprocess."""
    original=base.sha(blend);set_view(scene,plan,'overview-8');obj=native_parity(scene,plan);before=no_touch(scene,plan)
    copies=[base.plain_path(directory/name) for name in ('maw47-vertex-material-edit.blend','maw47-reverted.blend')]
    base.require(not any(p.exists() for p in copies),'Maw47 fresh private copies')
    controls=[]
    def reject(label,fn):
        try:fn()
        except ValueError:controls.append(label)
        else:raise ValueError('Maw47 negative control accepted '+label)
    obj['chapter']=7
    try:reject('owner',lambda:native_parity(scene,plan))
    finally:obj['chapter']=8
    obj.data.vertices[0].co.x+=.125
    try:reject('actual vertex',lambda:native_parity(scene,plan))
    finally:obj.data.vertices[0].co.x=next(m for m in plan['meshes'] if m['name']==obj.name)['vertices'][0][0]
    bone=obj.data.materials[0];obj.data.materials[0]=next(m for o in scene.objects if o.type=='MESH' for m in o.data.materials if m and m.name=='descent heart_bone surface23')
    try:reject('material source',lambda:native_parity(scene,plan))
    finally:obj.data.materials[0]=bone
    flesh=scene.objects[PREFIX+'muscle cuff'].data.materials[0]
    ramp=flesh.node_tree.nodes['Heart23 roughness'].color_ramp;old=[tuple(e.color) for e in ramp.elements]
    ramp.elements[0].color=(.9,.9,.9,1)
    try:reject('material recipe',lambda:native_parity(scene,plan))
    finally:
        for e,v in zip(ramp.elements,old):e.color=v
    views=['title',*base.NAMES,*('overview-'+str(i) for i in range(1,9)),*('pulse-'+str(i) for i in range(1,9))];checked=0
    for view in views:
        set_view(scene,plan,view);checked+=base.native_atmosphere26_view_mask(scene,plan,view)
    set_view(scene,plan,'overview-8');obj=native_parity(scene,plan)
    obj.hide_render=True
    try:reject('view mask',lambda:base.native_atmosphere26_view_mask(scene,plan,'overview-8'))
    finally:obj.hide_render=False
    native_compare_ancestor_records(before,no_touch(scene,plan))
    receipt={}
    try:
        obj.data.vertices[0].co.x+=.125
        for e,v in zip(ramp.elements,old):e.color=tuple(c+.02 for c in v[:3])+(1,)
        for path,edited in zip(copies,(True,False)):
            bpy.data.libraries.write(str(path),{scene},fake_user=True,compress=True)
            base.require(path.stat().st_size<=32*1024*1024,'Maw47 private packed size')
            bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.data.scenes['NULL CHOIR descent'];bpy.context.window.scene=scene
            obj=native_parity(scene,plan,edited=edited);base.verify_packed_paths(bpy)
            native_compare_ancestor_records(before,no_touch(scene,plan))
            receipt[path.name]=base.sha(path)
            if edited:
                obj.data.vertices[0].co.x=next(m for m in plan['meshes'] if m['name']==obj.name)['vertices'][0][0]
                ramp=scene.objects[PREFIX+'muscle cuff'].data.materials[0].node_tree.nodes['Heart23 roughness'].color_ramp
                for e,v in zip(ramp.elements,old):e.color=v
        base.require(base.sha(blend)==original,'Maw47 exact original native byte preservation')
        return dict(actual_mesh=True,cloned_materials=True,edit_save_reopen_revert=True,original_unchanged=True,
                    no_touch_records=len(before),view_masks=dict(views=views,objects_checked=checked),controls_rejected=controls,
                    private_copy_hashes=receipt,private_copies_cleaned=True,rendered=False)
    finally:
        for path in copies:
            if path.is_file():path.unlink()

def native_ancestor_records(scene):
    """Parent captures26 and47 in separate opens and requires exact equality here."""
    plan=base.make_plan();records=no_touch(scene,plan)
    records={k:v for k,v in records.items() if not k.startswith('heart relief18 ') and k not in OWNED and k!='maw47_imported_residues'}
    cs=mapping(plan)
    for name in OWNED:
        obj=scene.objects[name];all_count=sum(len(c['faces']) for c in cs if c['node']==name)
        owned_count=sum(len(c['faces']) for c in cs if c['node']==name and selected(c))
        if len(obj.data.polygons)==all_count:remove=owned_native_faces(obj,cs)
        else:
            base.require(len(obj.data.polygons)==all_count-owned_count,'Maw47 parent residual actual triangle count');remove=set()
        record=residual(obj.data,set(range(len(obj.data.polygons)))-remove)
        record.update(matrix=[list(r) for r in obj.matrix_world],chapter=obj.get('chapter'),pulse=obj.get('pulse'),
                      collections=sorted(c.name for c in obj.users_collection),hide=obj.hide_render,hide_viewport=obj.hide_viewport)
        records['maw47_normals:'+name]=record.pop('normals')
        records[name]=digest(record)
    return records


def native_compare_ancestor_records(before,after):
    keys={k for k in before if not k.startswith('maw47_normals:')}
    base.require(set(before)==set(after) and all(before[k]==after[k] for k in keys),'Maw47 native26/47 no-touch fingerprints')
    error=0
    for k in set(before)-keys:
        base.require(len(before[k])==len(after[k]),'Maw47 native26/47 split-normal count')
        error=max(error,max((abs(a-b) for v,w in zip(before[k],after[k]) for a,b in zip(v,w)),default=0))
    base.require(error<1e-6,'Maw47 native26/47 split normals')
    return dict(exact_fingerprints=len(keys),max_split_normal_error=error)
