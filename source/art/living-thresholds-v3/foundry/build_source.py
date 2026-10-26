"""Foundry production source author/export/reopen. NO render/bake/simulation/GPU.
Coordinates authored X horizontal, Y height, Z front; converted to Blender Z-up.
Only writes this source folder and explicitly supplied fresh task-local candidate.
"""
import bpy, bmesh, math, json, hashlib, sys, importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3]
CANDIDATE=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert CANDIDATE.is_dir() and not any(CANDIDATE.iterdir()),'Explicit empty candidate required'
assert not CANDIDATE.is_relative_to(ROOT/'game')
manifest=json.loads((BASE/'raw/production-inputs.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for asset in manifest['assets']:assert sha(BASE/'raw'/asset['file'])==asset['sha256']
spec=importlib.util.spec_from_file_location('source_art_helpers',ROOT/'tools/build_art.py');helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;bpy.context.preferences.filepaths.save_version=0
# Use geometry and source pixels, never a reference-image plane or unsupported procedural bake shader.
three_lobe_inputs=json.loads((BASE/'raw/three-lobe-production-inputs-v6.json').read_text())
for item in three_lobe_inputs:assert sha(BASE/'raw'/item['file'])==item['sha256']
leaf_input=next(a for a in three_lobe_inputs if a['kind']=='leaf-albedo')
used_assets=[next(a for a in manifest['assets'] if a['kind']=='sharedhardwarealbedo'),leaf_input]
images={a['file']:bpy.data.images.load(str(BASE/'raw'/a['file']),check_existing=True) for a in used_assets}
for image in images.values():image.pack()
SWATCHES={'steel':(.02,.52,.48,.98),'bronze':(.52,.52,.98,.98),'ivory':(.02,.02,.48,.48),'hose':(.52,.02,.98,.48)}
M={}
for name,rough,metal in [('steel',.56,.68),('bronze',.44,.76),('ivory',.69,.02),('hose',.83,0),('tissue',.82,.05)]:
 m=bpy.data.materials.new('FoundryV3_'+name);m.use_nodes=True;m.diffuse_color=(.45,.44,.40,1);nodes=m.node_tree.nodes;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=rough;bsdf.inputs['Metallic'].default_value=metal
 tex=nodes.new('ShaderNodeTexImage');tex.image=images[leaf_input['file'] if name=='tissue' else 'hardware_pigments_v3.png'];tex.interpolation='Closest';m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);M[name]=m

def xyz(v):return (v[0],-v[2],v[1])
def logical(v):return (v[0],v[2],-v[1])
def root(name,parent=None,p=(0,0,0)):
 obj=bpy.data.objects.new(name,None);scene.collection.objects.link(obj);obj.parent=parent;obj.location=xyz(p);return obj
ROOT_OBJ=root('FoundryThresholdV3');FRAME=root('StationaryFrame',ROOT_OBJ);LEAF=root('MovingLeaf',ROOT_OBJ);BLOOD=root('BloodLatch',FRAME,(-2.40,1.72,0));IVORY=root('IvoryLatch',FRAME,(2.40,3.23,0))
BLOOD['retraction_local_x']=-1.35;IVORY['retraction_local_x']=1.35
ROOT_OBJ['contract']='8.2x5x0.6 opaque blocker visual; art adds no collision/unlock/save owner'
LEAF['opaque_dimensions_m']=[8.2,5,.6];FRAME['mounting']='Requires actual wall/roof audit; no fabricated floor support'
objects=[]
def mesh(name,verts,faces,mat,parent,uvs=None,smooth=False):
 data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in verts],[],faces);data.update();obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.parent=parent;data.materials.append(M[mat])
 uv=data.uv_layers.new(name='PaintRegistration')
 if uvs is not None:
  for poly in data.polygons:
   for loopid in poly.loop_indices:uv.data[loopid].uv=uvs[data.loops[loopid].vertex_index]
 else:
  lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)];rect=SWATCHES[mat]
  for poly in data.polygons:
   ps=[verts[i] for i in poly.vertices];normal=Vector(ps[1])-Vector(ps[0]);normal=normal.cross(Vector(ps[2])-Vector(ps[0]));axis=max(range(3),key=lambda i:abs(normal[i]));a,b=[i for i in range(3) if i!=axis]
   for loopid in poly.loop_indices:
    v=verts[data.loops[loopid].vertex_index];u=(v[a]-lo[a])/max(hi[a]-lo[a],.0001);q=(v[b]-lo[b])/max(hi[b]-lo[b],.0001);uv.data[loopid].uv=(rect[0]+u*(rect[2]-rect[0]),rect[1]+q*(rect[3]-rect[1]))
 for poly in data.polygons:poly.use_smooth=smooth
 objects.append(obj);return obj

def block(name,c,size,mat,parent,bevel=.025):
 v=[(c[0]+x*size[0]/2,c[1]+y*size[1]/2,c[2]+z*size[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 o=mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,parent)
 if bevel:
  b=o.modifiers.new('Editable machined edge radius','BEVEL');b.width=bevel;b.segments=2
 return o

def tube(name,pts,radius,mat,parent,n=12,cap=True):
 verts=[]
 for j,p in enumerate(pts):
  tangent=(Vector(pts[min(j+1,len(pts)-1)])-Vector(pts[max(j-1,0)])).normalized();u=tangent.cross(Vector((0,0,1)))
  if u.length<.01:u=tangent.cross(Vector((0,1,0)))
  u.normalize();v=tangent.cross(u);r=radius[j] if isinstance(radius,(tuple,list)) else radius
  for i in range(n):verts.append(tuple(Vector(p)+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))))
 faces=[]
 for j in range(len(pts)-1):
  for i in range(n):a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 if cap:faces += [tuple(reversed(range(n))),tuple(range((len(pts)-1)*n,len(pts)*n))]
 return mesh(name,verts,faces,mat,parent,smooth=True)

def annulus(name,c,outer,inner,depth,mat,parent,n=24):
 v=[]
 for z,r in [(c[2]-depth/2,outer),(c[2]+depth/2,outer),(c[2]-depth/2,inner),(c[2]+depth/2,inner)]:v += [(c[0]+r*math.cos(i*math.tau/n),c[1]+r*math.sin(i*math.tau/n),z) for i in range(n)]
 f=[]
 for a,b in [(0,1),(2,0),(1,3),(3,2)]:
  for i in range(n):j=(i+1)%n;f.append((a*n+i,a*n+j,b*n+j,b*n+i))
 return mesh(name,v,f,mat,parent)

def extrude(name,outline,z0,z1,mat,parent,bevel=.02):
 n=len(outline);v=[(x,y,z) for z in [z0,z1] for x,y in outline];f=[tuple(reversed(range(n))),tuple(range(n,n*2))]
 for i in range(n):j=(i+1)%n;f.append((i,j,j+n,i+n))
 o=mesh(name,v,f,mat,parent)
 if bevel:b=o.modifiers.new('Editable relief edge bevel','BEVEL');b.width=bevel;b.segments=2
 return o

# Three unequal pressure lobes, registered to the ACTUAL whole-leaf painting.
# Two manually traced cubicBezier S trajectories (normalized XY, bottom-origin).
# These are physical channels in a continuous opaque shell, not painted strip masks.
CHANNELS=[[(0,.965),(.29,.86),(.14,.24),(.93,.005)],[(.20,1),(.65,.96),(.62,.39),(1,.16)]]
def bezier(control,t):
 a,b,c,d=control;q=1-t
 return (q*q*q*a[0]+3*q*q*t*b[0]+3*q*t*t*c[0]+t*t*t*d[0],q*q*q*a[1]+3*q*q*t*b[1]+3*q*t*t*c[1]+t*t*t*d[1])
channel_samples=[[(bezier(c,i/80)[0]*8.2,bezier(c,i/80)[1]*5) for i in range(81)] for c in CHANNELS]
def segment_distance(x,y,a,b):
 dx=b[0]-a[0];dy=b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)))
 return math.hypot(x-a[0]-t*dx,y-a[1]-t*dy)
def relief(u,v):
 d=min(segment_distance(u*8.2,v*5,path[i],path[i+1]) for path in channel_samples for i in range(80))
 # Deep scar, strong rolled bearing shoulder, broad protected mineral lobe.
 z=.17+.10*(1-math.exp(-(d/.65)**2))-.09*math.exp(-(d/.075)**2)+.10*math.exp(-((d-.16)/.08)**2)
 edge=min(u*8.2,(1-u)*8.2,v*5,(1-v)*5);rim=math.exp(-(edge/.055)**2)
 z=.30*rim+z*(1-rim)
 # Frozen receiver bed function/origins: neutral clamps remain fully exposed.
 x=(u-.5)*8.2;y=v*5
 bed=max(math.exp(-(((x+2.4)/1.15)**8+((y-1.72)/.70)**8)),math.exp(-(((x-2.4)/1.15)**8+((y-3.23)/.70)**8)))
 return z*(1-bed)+.065*bed
NX=96;NY=56;verts=[];uv=[];faces=[]
for side in [1,-1]:
 for j in range(NY+1):
  v=j/NY
  for i in range(NX+1):
   u=i/NX;verts.append(((u-.5)*8.2,v*5,relief(u,v)*side));uv.append((u,v))
layer=(NX+1)*(NY+1)
for face in range(2):
 offset=face*layer
 for j in range(NY):
  for i in range(NX):
   a=offset+j*(NX+1)+i;b=a+1;c=b+NX+1;d=a+NX+1;faces.append((a,b,c,d) if face==0 else(d,c,b,a))
perimeter=list(range(NX+1))+[j*(NX+1)+NX for j in range(1,NY+1)]+[NY*(NX+1)+i for i in range(NX-1,-1,-1)]+[j*(NX+1) for j in range(NY-1,0,-1)]
for i,a in enumerate(perimeter):
 b=perimeter[(i+1)%len(perimeter)];faces.append((a,a+layer,b+layer,b))
leaf=mesh('Continuous three lobe mineral pressure closure',verts,faces,'tissue',LEAF,uv,smooth=True)
# Fixed compression housings seat wholly beyond actual usable x+-3.86.
for side in [-1,1]:
 x=side*4.48
 block('Wall seated heavy compression foot',(side*4.58,.22,0),(1.10,.44,1.14),'steel',FRAME,.055)
 block('Load bearing vertebral housing',(x,2.73,0),(.72,4.95,.92),'steel',FRAME,.055)
 # Alternating short thermal shields read as a cast vertebral housing, not leaf bars.
 for k in range(6):
  y=.65+k*.78
  outline=[(side*4.02,y-.23),(side*4.02,y+.23),(side*4.78,y+.31),(side*4.86,y-.25)]
  for z0,z1 in [(.32,.54),(-.54,-.32)]:extrude('Socketed refractory housing shield',outline,z0,z1,'steel',FRAME,.035)
  for face in [-1,1]:
   tube('Housing captive crosspin',[(side*4.10,y,face*.52),(side*4.67,y,face*.52)],.045,'bronze',FRAME,8)
 # Distinct connected exterior manifold: no tube enters the clear XY aperture.
 for face in [-1,1]:
  z=face*.46
  tube('Return manifold header',[(side*4.74,.60,z),(side*4.96,1.2,z),(side*4.96,3.5,z),(side*4.62,4.6,z)],.10,'bronze',FRAME,12)
  for y in [1.2,2.7,4.15]:
   tube('Pressure manifold branch',[(side*4.96,y,z),(side*4.53,y,z)],.075,'steel',FRAME,10)
  block('Fixed carriage socket',(side*4.42,1.72 if side<0 else 3.23,face*.12),(.68,.84,.38),'steel',FRAME,.04)
# Straight heavy refractory head, entirely ABOVE old 5m aperture, both-side UVs.
block('Thermal receiver lower beam',(0,5.06,0),(8.92,.08,.92),'steel',FRAME,.025)
for i in range(7):
 x=(i-3)*1.25
 block('Interlocked thermal lintel casting',(x,5.31,0),(1.22,.38,.96),'steel',FRAME,.035)
 for face in [-1,1]:block('Lintel expansion joint retaining key',(x+.50,5.32,face*.48),(.13,.29,.10),'bronze',FRAME,.02)
# BLOOD pressure slide and IVORY wedge have asymmetric substantial constructions.
for side,parent in [(-1,BLOOD),(1,IVORY)]:
 for face in [-1,1]:
  z=face*.20
  if side<0:
   outline=[(-.96,-.36),(-.96,.36),(.72,.23),(.94,-.22)]
   extrude('Pressure carriage forged connecting shoe',outline,z-.075,z+.075,'steel',parent,.035)
   tube('Pressure ram barrel',[(-.1,-.35,face*.14),(-.1,.40,face*.14)],.14,'hose',parent,16)
   for y in [-.29,.31]:annulus('Pressure ram seal collar',(-.1,y,face*.14),.19,.14,.07,'bronze',parent,16)
   block('Pressure carriage ivory engagement tooth',(.78,0,z),(.34,.59,.16),'ivory',parent,.03)
  else:
   outline=[(-.98,-.32),(-.98,.32),(.90,.53),(.90,-.45)]
   extrude('Forged asymmetric locking wedge',outline,z-.075,z+.075,'ivory',parent,.03)
   extrude('Wedge socket wear liner',[(-.72,-.17),(-.72,.17),(.72,.33),(.72,-.27)],z-.085,z+.085,'steel',parent,.02)
   for x in [-.45,.28]:annulus('Wedge captive bearing washer',(x,0,z),.15,.065,.09,'bronze',parent,12)
 for face in [-1,1]:
  # Entire crossing linkage belongs to the same carriage/Cover, never Frame.
  tube('Captive telescoping carriage feed',[(side*.80,0,face*.12),(side*2.03,0,face*.12)],.10,'bronze',parent,12)
  block('Sliding feed guide shoe',(side*1.60,0,face*.12),(.54,.30,.24),'steel',parent,.025)
 if side<0:
  for face in [-1,1]:
   extrude('Pressure carriage protective ceramic facing',[(-.78,-.25),(-.78,.25),(.46,.16),(.64,-.15)],face*.275-.012,face*.275+.012,'ivory',parent,.018)
 # Root orientation/lift untouched; outward +-1.35m state is owned by runtime presentation.
# Released closure is actual compressed fourfold refractory material, not a disappearing asset.
RELEASED=root('ReleasedClosure',FRAME)
rv=[];ruv=[];rf=[]
for side in [1,-1]:
 for j in range(17):
  v=j/16
  for i in range(65):
   u=i/64;z=side*(.10+.10*(relief(u,v)-.06)/.24)
   rv.append(((u-.5)*7.75,5.075+v*.32,z));ruv.append((u,v))
rl=65*17
for face in range(2):
 for j in range(16):
  for i in range(64):
   a=face*rl+j*65+i;b=a+1;c=b+65;d=a+65;rf.append((a,b,c,d) if face==0 else(d,c,b,a))
released_mesh=mesh('Actual compressed three lobe refractory return',rv,rf,'tissue',RELEASED,ruv,smooth=True)
released_objects=[released_mesh]
# Named editable source collections and neutral pose identity.
source=bpy.data.collections.new('Editable_Foundry_Source');scene.collection.children.link(source)
for obj in [ROOT_OBJ,FRAME,LEAF,BLOOD,IVORY,RELEASED]+objects:
 for coll in list(obj.users_collection):coll.objects.unlink(obj)
 source.objects.link(obj)
# Closed neutral source pose hides released-only meshes in a dedicated editable collection.
released_collection=bpy.data.collections.new('ReleasedConfiguration_SOURCE_HIDDEN');scene.collection.children.link(released_collection)
for obj in [RELEASED]+released_objects:
 for coll in list(obj.users_collection):coll.objects.unlink(obj)
 released_collection.objects.link(obj)
released_collection.hide_render=True;released_collection.hide_viewport=True
bpy.context.view_layer.update()

def bounds(objs):
 points=[o.matrix_world@v.co for o in objs if o.type=='MESH' for v in o.data.vertices]
 points=[logical(v) for v in points];lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];return {'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]}
released_bounds=bounds(released_objects);assert released_bounds['min'][1]>=5.03 and released_bounds['max'][1]<=5.45 and released_bounds['min'][2]>=-.28 and released_bounds['max'][2]<=.28
leaf_bounds=bounds([leaf]);assert all(abs(a-b)<.00001 for a,b in zip(leaf_bounds['size'],[8.2,5,.6]))
assert max(v[1] for v in [logical(o.matrix_world@v.co) for o in objects for v in o.data.vertices])<=5.500001
for part in [LEAF,BLOOD,IVORY]:
 envelope=bounds([o for o in objects if o.parent==part]);assert envelope['min'][2]>=-.300001 and envelope['max'][2]<=.300001, 'Moving aperture art outside sole blocker depth'
# Independent source role audit: positive projected triangle area inside actual usable
# run8m less .28m walls, y0..5 is forbidden on every stationary part at ANY depth.
def clip_xy(poly,axis,bound,minimum):
 out=[]
 if not poly:return out
 previous=poly[-1];was_inside=previous[axis]>=bound if minimum else previous[axis]<=bound
 for current in poly:
  inside=current[axis]>=bound if minimum else current[axis]<=bound
  if inside!=was_inside:
   f=(bound-previous[axis])/(current[axis]-previous[axis]);out.append(tuple(previous[j]+f*(current[j]-previous[j]) for j in range(2)))
  if inside:out.append(current)
  previous=current;was_inside=inside
 return out
role_intrusions=[]
for obj in objects:
 if obj.parent not in [FRAME,RELEASED]:continue
 obj.data.calc_loop_triangles()
 for tri in obj.data.loop_triangles:
  polygon=[logical(obj.matrix_world@obj.data.vertices[i].co)[:2] for i in tri.vertices]
  for axis,bound,minimum in [(0,-3.86,True),(0,3.86,False),(1,0,True),(1,5,False)]:polygon=clip_xy(polygon,axis,bound,minimum)
  area=abs(sum(polygon[i][0]*polygon[(i+1)%len(polygon)][1]-polygon[(i+1)%len(polygon)][0]*polygon[i][1] for i in range(len(polygon))))*.5
  if area>1e-7:role_intrusions.append({'object':obj.name,'triangle':tri.index,'area':area})
assert not role_intrusions,role_intrusions[:10]
# Sanitize actual saved source RNA buffers, including packed-image/browser/render fields.
helpers.sanitize_source_paths(bpy)
scene['provenance']='Original editable Blender mesh + builtin-image-generator pigment inputs; no Blender render/bake/simulation'
scene['reference_sha256']=three_lobe_inputs[0]['sha256'];scene['production_membrane_sha256']=leaf_input['sha256'];scene['appearance_qualification']='Pending actual imported native views and independent review'
sourcefile=BASE/'foundry_threshold.blend';bpy.ops.wm.save_as_mainfile(filepath=str(sourcefile),compress=True,check_existing=False)
# Unhide only in-memory DERIVATION after cold neutral source was frozen.
released_collection.hide_render=False;released_collection.hide_viewport=False;bpy.context.view_layer.update()
# Evaluated export duplicates merge geometry only within stable controller roots; source stays separate/editable.
deps=bpy.context.evaluated_depsgraph_get();export_coll=bpy.data.collections.new('DERIVED_EXPORT_ONLY');scene.collection.children.link(export_coll)
def export_root(name,parent=None,transform=None):
 o=bpy.data.objects.new(name,None);export_coll.objects.link(o);o.parent=parent
 if transform is not None:o.matrix_local=transform
 return o
# Free only temporary in-memory source names AFTER saved source was frozen.
for obj in [ROOT_OBJ,FRAME,LEAF,BLOOD,IVORY,RELEASED]:obj.name=obj.name+'_AUTHORING_ONLY'
exroot=export_root('FoundryThresholdV3');exframe=export_root('StationaryFrame',exroot);exleaf=export_root('MovingLeaf',exroot);exblood=export_root('BloodLatch',exframe,BLOOD.matrix_local.copy());exivory=export_root('IvoryLatch',exframe,IVORY.matrix_local.copy());exreleased=export_root('ReleasedClosure',exframe,RELEASED.matrix_local.copy())
counts={};source_uv={}
for old,new in [(FRAME,exframe),(LEAF,exleaf),(BLOOD,exblood),(IVORY,exivory),(RELEASED,exreleased)]:
 verts=[];faces=[];uvs=[];poly_material=[];poly_smooth=[];materials=[]
 for obj in objects:
  if obj.parent!=old:continue
  ev=obj.evaluated_get(deps);temp=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps);transform=old.matrix_world.inverted()@obj.matrix_world;offset=len(verts);verts.extend([tuple(transform@v.co) for v in temp.vertices]);mapping=[]
  for material in temp.materials:
   if material not in materials:materials.append(material)
   mapping.append(materials.index(material))
  for poly in temp.polygons:
   faces.append(tuple(offset+i for i in poly.vertices));poly_material.append(mapping[poly.material_index]);poly_smooth.append(poly.use_smooth);uvs.append([tuple(temp.uv_layers.active.data[i].uv) for i in poly.loop_indices])
  bpy.data.meshes.remove(temp)
 data=bpy.data.meshes.new(new.name+'_evaluated_mesh');data.from_pydata(verts,[],faces);data.update()
 for m in materials:data.materials.append(m)
 layer=data.uv_layers.new(name='PaintRegistration')
 for poly,m,smooth,uvrow in zip(data.polygons,poly_material,poly_smooth,uvs):
  poly.material_index=m;poly.use_smooth=smooth
  for li,uvpair in zip(poly.loop_indices,uvrow):layer.data[li].uv=uvpair
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.update()
 obj=bpy.data.objects.new(new.name+'_Visual',data);export_coll.objects.link(obj);obj.parent=new;data.calc_loop_triangles();counts[new.name]={'triangles':len(data.loop_triangles),'vertices':len(data.vertices),'surfaces':len(materials)}
# Export selected derived meshes/controllers only; no cameras/lights/animation/physics.
bpy.ops.object.select_all(action='DESELECT')
for o in export_coll.objects:o.select_set(True)
glb=CANDIDATE/'foundry_threshold.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=False,export_yup=True,export_tangents=True,export_image_format='AUTO',export_materials='EXPORT',export_extras=True)
# Reopen EXACT source and validate actual packed images, UV/material use, hierarchy, edit/revert and privacy.
source_hash=sha(sourcefile);bpy.ops.wm.open_mainfile(filepath=str(sourcefile));bpy.context.view_layer.update();scene=bpy.context.scene
assert bpy.data.objects['BloodLatch'].parent.name=='StationaryFrame' and bpy.data.objects['IvoryLatch'].parent.name=='StationaryFrame'
assert bpy.data.objects['MovingLeaf'].parent.name=='FoundryThresholdV3'
assert bpy.data.objects['ReleasedClosure'].parent.name=='StationaryFrame'
assert bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_render and bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_viewport
leaf=bpy.data.objects['Continuous three lobe mineral pressure closure'];before=tuple(leaf.data.vertices[100].co);leaf.data.vertices[100].co.x+=.001;assert tuple(leaf.data.vertices[100].co)!=before;leaf.data.vertices[100].co=before
assert tuple(leaf.data.vertices[100].co)==before and sha(sourcefile)==source_hash
images_out=[]
for image in bpy.data.images:
 assert image.packed_file is not None and image.filepath.startswith('//')
 images_out.append({'name':image.name,'filepath':image.filepath,'packed_bytes':len(image.packed_file.data),'packed_sha256':hashlib.sha256(image.packed_file.data).hexdigest()})
assert {a['packed_sha256'] for a in images_out}=={a['sha256'] for a in used_assets}
paths=[im.filepath for im in bpy.data.images]
for im in bpy.data.images:paths.extend([p.filepath for p in im.packed_files])
for sc in bpy.data.scenes:paths.append(sc.render.filepath)
for screen in bpy.data.screens:
 for area in screen.areas:
  for space in area.spaces:
   if space.type=='FILE_BROWSER' and space.params:paths.append(bytes(space.params.directory).decode(errors='replace'))
strings=[]
for blocks in [bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.collections,bpy.data.scenes,bpy.data.images]:
 for block in blocks:
  strings.extend([block[key] for key in block.keys() if isinstance(block[key],str)])
assert not any(any(mark in v for mark in ['/Users/','/private/','/tmp/']) for v in paths+strings)
for obj in scene.objects:
 if obj.type=='MESH':assert obj.data.uv_layers.active is not None and len(obj.data.materials)>0
assert not any(o.type in ['LIGHT','CAMERA'] for o in scene.objects)
neutral_bounds=bounds([o for o in scene.objects if o.type=='MESH'])
for name,dx in [('BloodLatch',-1.35),('IvoryLatch',1.35)]:bpy.data.objects[name].location.x+=dx
bpy.context.view_layer.update();open_bounds=bounds([o for o in scene.objects if o.type=='MESH'])
for name,dx in [('BloodLatch',-1.35),('IvoryLatch',1.35)]:bpy.data.objects[name].location.x-=dx
bpy.context.view_layer.update()
proof={'schema':1,'surface_topology':{'method':'continuous three unequal mineral lobes with two real Bezier S channels/rolled bearing rims','channels_normalized_bottom_origin':CHANNELS,'global_XY_UV':True,'leaf_albedo_sha256':leaf_input['sha256'],'no_four_band_atlas':True},'source_stationary_triangle_aperture_intrusions':role_intrusions,'source_usable_run_m':8.0,'source_wall_thickness_m':.28,'released_configuration_bounds':released_bounds,'released_aperture_clearance_m':released_bounds['min'][1]-5.0,'released_root':'StationaryFrame/ReleasedClosure','released_neutral_source_hidden':True,'release_story':'Authored compressed three-lobe refractory material in fixed thermal receiver; no simulation/new timer/aperture geometry','actual_closed_assembly_bounds':neutral_bounds,'actual_both_seal_assembly_bounds':open_bounds,'carriage_origins_godot':{'BloodLatch':[-2.40,1.72,0],'IvoryLatch':[2.40,3.23,0]},'motion_witnesses':[],'scope':'Source-only original editable Blender model, actual GLB export and actual saved-source reopen. Native normal import, visual matching and mounting acceptance pending.','source':'foundry_threshold.blend','source_sha256':source_hash,'recipe':'build_source.py','recipe_sha256':sha(Path(__file__)),'candidate_glb_sha256':sha(glb),'candidate_glb_bytes':glb.stat().st_size,'actual_shell_bounds':leaf_bounds,'actual_assembly_bounds':bounds([o for o in scene.objects if o.type=='MESH']),'actual_export_parts':counts,'actual_triangles':sum(x['triangles'] for x in counts.values()),'actual_export_surfaces':sum(x['surfaces'] for x in counts.values()),'editable_source_meshes':len([o for o in scene.objects if o.type=='MESH']),'packed_images':images_out,'privacy':{'actual_rna_paths_checked':len(paths),'custom_string_properties_checked':len(strings),'private_absolute_paths':0,'paths':paths,'sanitizer':'tools/build_art.py:sanitize_source_paths','helper_sha256':sha(ROOT/'tools/build_art.py')},'actual_vertex_edit_revert':True,'source_unchanged_after_reopen':sha(sourcefile)==source_hash,'native8K':False,'normal_roughness_images':False,'rendered_baked_simulated':False}
(BASE/'source-proof.json').write_text(json.dumps(proof,indent=2));(CANDIDATE/'source-proof.json').write_text(json.dumps(proof,indent=2));print('PASS sourceFoundry editable/UV/packedimages/export/reopen/privacy; nativeappearance UNQUALIFIED',json.dumps({'triangles':proof['actual_triangles'],'surfaces':proof['actual_export_surfaces']}),flush=True)
