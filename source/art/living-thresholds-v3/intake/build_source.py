"""Intake production source author/export/reopen. NO render/bake/simulation/GPU.
Coordinates authored X horizontal, Y height, Z front; converted to Blender Z-up.
Only writes this source folder and explicitly supplied fresh task-local candidate.
"""
import bpy, math, json, hashlib, sys, importlib.util
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
images={a['file']:bpy.data.images.load(str(BASE/'raw'/a['file']),check_existing=True) for a in manifest['assets']}
for image in images.values():image.pack()
SWATCHES={'steel':(.02,.52,.48,.98),'bronze':(.52,.52,.98,.98),'ivory':(.02,.02,.48,.48),'hose':(.52,.02,.98,.48)}
M={}
for name,rough,metal in [('steel',.56,.68),('bronze',.44,.76),('ivory',.69,.02),('hose',.83,0),('tissue',.53,0)]:
 m=bpy.data.materials.new('IntakeV3_'+name);m.use_nodes=True;m.diffuse_color=(.45,.44,.40,1);nodes=m.node_tree.nodes;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=rough;bsdf.inputs['Metallic'].default_value=metal
 tex=nodes.new('ShaderNodeTexImage');tex.image=images['intake_membrane_pigment_v3.png' if name=='tissue' else 'hardware_pigments_v3.png'];tex.interpolation='Closest';m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);M[name]=m

def xyz(v):return (v[0],-v[2],v[1])
def logical(v):return (v[0],v[2],-v[1])
def root(name,parent=None,p=(0,0,0)):
 obj=bpy.data.objects.new(name,None);scene.collection.objects.link(obj);obj.parent=parent;obj.location=xyz(p);return obj
ROOT_OBJ=root('IntakeThresholdV3');FRAME=root('StationaryFrame',ROOT_OBJ);LEAF=root('MovingLeaf',ROOT_OBJ);BLOOD=root('BloodLatch',FRAME,(-3.22,1.72,0));IVORY=root('IvoryLatch',FRAME,(3.22,3.23,0))
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

# Manual surface registration: hub and curved seams follow the ACTUAL delivered pigment.
HUB=(.622,.540)
SEAMS=[[(.622,.540),(.595,.72),(.575,.89),(.58,1)],[(.622,.540),(.43,.70),(.30,.77),(.20,1)],[(.622,.540),(.36,.61),(.14,.57),(0,.54)],[(.622,.540),(.38,.43),(.16,.29),(0,.13)],[(.622,.540),(.58,.31),(.54,.12),(.51,0)],[(.622,.540),(.77,.30),(.90,.17),(1,.08)],[(.622,.540),(.81,.51),(.94,.52),(1,.62)],[(.622,.540),(.79,.69),(.91,.83),(1,1)]]
def distance_segment(p,a,b):
 p=Vector(p);a=Vector(a);b=Vector(b);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-(a+t*d)).length
seam_world=[[(u*8.2,v*5) for u,v in path] for path in SEAMS]
def relief(u,v):
 point=(u*8.2,v*5);d=min(distance_segment(point,path[i],path[i+1]) for path in seam_world for i in range(len(path)-1));height=.075+.225*(1-math.exp(-(d/.27)**2))
 # Hand-specified slight asymmetry; it changes real geometry, not fake shader normals.
 height-=.018*math.exp(-(((u-.622)*8.2/.22)**2+((v-.540)*5/.18)**2))
 # Real compressed receiver beds keep actual lock shoes visible INSIDE blocker depth.
 for cx,cy in [(.88,1.72),(7.32,3.23)]:height-=.18*math.exp(-((u*8.2-cx)/1.15)**4-((v*5-cy)/.50)**4)
 return min(.3,max(.052,height))
NX,NY=64,40;verts=[];uv=[]
for side in [1,-1]:
 for j in range(NY+1):
  for i in range(NX+1):
   u=i/NX;v=j/NY;z=relief(u if side==1 else 1-u,v)
   verts.append(((u-.5)*8.2,v*5,side*z));uv.append((u if side==1 else 1-u,v))
layer=(NX+1)*(NY+1);faces=[]
for side_index in [0,1]:
 for j in range(NY):
  for i in range(NX):
   a=side_index*layer+j*(NX+1)+i;q=(a,a+1,a+NX+2,a+NX+1);faces.append(q if side_index==0 else tuple(reversed(q)))
edge=list(range(NX+1))+[j*(NX+1)+NX for j in range(1,NY+1)]+[NY*(NX+1)+i for i in range(NX-1,-1,-1)]+[j*(NX+1) for j in range(NY-1,0,-1)]
for i,a in enumerate(edge):b=edge[(i+1)%len(edge)];faces.append((a,b,b+layer,a+layer))
# Exact z envelope has actual geometry witnesses at broad interior lobe vertices, not bounds metadata.
for u,v in [(.38,.55),(.78,.78)]:
 i=round(u*NX);j=round(v*NY);index=j*(NX+1)+i;x,y,z=verts[index];verts[index]=(x,y,.3)
 index+=layer;x,y,z=verts[index];verts[index]=(x,y,-.3)
leaf=mesh('Opaque unequal pressure lobes and stitched perimeter',verts,faces,'tissue',LEAF,uv,smooth=True)
leaf['hub_uv_from_bottom']=list(HUB);leaf['back_paint']='Same original tissue painting, mirrored UV; not separately generated'

# Thick socketed jambs, inset channels and crown. No decorative spokes across tissue.
for side in [-1,1]:
 x=side*4.48
 block('Wall seated foundation shoe',(side*4.52,.20,0),(.90,.40,1.02),'steel',FRAME,.075)
 block('Jamb structural shell',(x,2.65,0),(.62,4.90,.86),'steel',FRAME,.055)
 # Real wall returns are at localX±4m with .28m thickness; bridges seat in them.
 for y in [.75,2.55,4.45]:block('Wall return seated structural anchor',(side*4.14,y,0),(.28,.58,.78),'steel',FRAME,.035)
 # Three substantial overlapping carved cheek segments form a recessed vertical channel.
 for j in range(3):
  y=.45+j*1.53
  outline=[(x-side*.34,y),(x+side*.28,y+.06),(x+side*.36,y+1.25),(x+side*.20,y+1.43),(x-side*.26,y+1.40),(x-side*.36,y+.23)]
  extrude('Nested mineral jamb cheek',outline,.26,.47,'ivory',FRAME,.035)
  block('Inset bronze channel socket',(x-side*.10,y+.70,.49),(.18,1.08,.13),'bronze',FRAME,.025)
  for yy in [y+.16,y+1.22]:
   annulus('Recessed fastening washer',(x,yy,.48),.09,.035,.045,'bronze',FRAME,12)
   tube('Solid fastening pin',[(x,yy,.43),(x,yy,.53)],.031,'steel',FRAME,8)
 # Negative cavity between outer rail and inner lip is real mesh spacing.
 block('Inner containment gasket lip',(side*4.15,2.51,.18),(.13,4.96,.21),'hose',FRAME,.035)
 # Front and back pressure cylinders are connected to supported mounting collars.
 for front in [-1,1]:
  z=front*.30
  tube('Wall reservoir pressure body',[(x,3.65,z),(x,4.54,z)],[.20,.20],'steel',FRAME,16)
  for y in [3.66,4.53]:tube('Reservoir bronze collar',[(x,y-.055,z),(x,y+.055,z)],.235,'bronze',FRAME,16)
  block('Reservoir mounting saddle',(x,4.10,front*.16),(.47,.26,.32),'steel',FRAME,.03)
  tube('Connected oxblood pressure feed',[(x,3.64,z),(side*4.82,3.25,z),(side*4.84,2.35,z),(side*4.45,1.98,z)],.052,'hose',FRAME,12)
  for y in [2.6,3.10]:block('Hose wall retention clip',(side*4.84,y,z),(.18,.10,.18),'bronze',FRAME,.02)
 # Fixed recessed horizontal bearing housing overlaps moving pressure rod across full stroke.
 latch_y=1.72 if side<0 else 3.23
 block('Fixed carriage bearing socket',(side*4.54,latch_y,.04),(.60,.73,.68),'steel',FRAME,.065)
 for front in [-1,1]:annulus('Bearing front inspection recess',(side*4.54,latch_y,front*.40),.21,.11,.09,'bronze',FRAME,16)
# Low-wide crown formed by layered extruded shaped solids, not a thin tube arch.
for front in [-1,1]:
 outline=[(-4.79,4.85),(-4.13,4.99),(-2.5,5.25),(0,5.48),(2.5,5.25),(4.13,4.99),(4.79,4.85),(4.65,5.12),(2.55,5.43),(0,5.50),(-2.55,5.43),(-4.65,5.12)]
 z0,z1=(.16,.45) if front>0 else(-.45,-.16);extrude('Low wide carved pressure crown',outline,z0,z1,'steel',FRAME,.025)
 # Individual broad relief bosses emphasize nested mass and native parallax.
 for x in [-3.55,-1.8,0,1.8,3.55]:
  y=5.06+.28*(1-abs(x)/4.1);block('Crown relief saddle',(x,y,front*.40),(.49,.22,.17),'bronze',FRAME,.035)

# Scoped crown/vault fit repair ONLY: translate positive-front crown components back .185m.
# Forward crown maximum .485 becomes .300; X/Y/topology/UV/material and rear crown unchanged.
for component in objects:
 if component.parent==FRAME and (component.name.startswith('Low wide carved pressure crown') or component.name.startswith('Crown relief saddle')):
  if min(-vertex.co.y for vertex in component.data.vertices)>0:
   component.location.y+=.185
   component['scoped_forward_recess_m']=.185
  # Native ANY-depth role audit proved mirrored rear outer saddles had the same12.44mm intrusion.
  # Both faces now receive the same exact .015m raise; front transform is unchanged from prior05.
  if component.name.startswith('Crown relief saddle') and abs(abs(sum(v.co.x for v in component.data.vertices)/len(component.data.vertices))-3.55)<.0001:
   component.location.z+=.015
   component['aperture_top_clearance_raise_m']=.015

# Substantial asymmetric lock shoes, sockets and captive rods; all in movable roots.
for side,parent in [(-1,BLOOD),(1,IVORY)]:
 for front in [-1,1]:
  sign=side;z=front*.16
  # Inner toe points toward the membrane, outer heel remains in the bearing track.
  outline=[(-sign*.95,-.27),(-sign*.96,.27),(sign*.60,.47),(sign*.91,.29),(sign*.91,-.29),(sign*.55,-.40)]
  z0,z1=(.12,.42) if front>0 else(-.42,-.12)
  extrude('Heavy tapered pressure lock shoe',outline,z0,z1,'steel',parent,.045)
  liner=[(-sign*.84,-.20),(-sign*.84,.20),(sign*.40,.32),(sign*.65,.18),(sign*.65,-.19),(sign*.36,-.28)]
  z0,z1=(.42,.49) if front>0 else(-.49,-.42);extrude('Inset lock shield relief',liner,z0,z1,'bronze' if side<0 else 'ivory',parent,.025)
  for xx in [-sign*.62,sign*.39]:
   annulus('Captive clamp hinge washer',(xx,0,front*.50),.13,.045,.07,'bronze',parent,16)
   tube('Real clamp hinge axle',[(xx,0,-.54),(xx,0,.54)],.045,'steel',parent,10)
  # Solid thick piston barrel/captive slide, not a disconnected hairline.
  tube('Captive sliding pressure piston',[(sign*.56,0,z),(sign*1.25,0,z)],.11,'bronze',parent,12)
  if side<0:
   tube('Pressure reservoir connecting neck',[(sign*.10,.20,z),(sign*.30,.36,z)],.105,'steel',parent,12)
   tube('Latch pressure accumulator',[(sign*.22,.16,z),(sign*.22,.60,z)],.17,'bronze',parent,16)
  else:
   for y in [-.20,0,.20]:block('Independent restraint collar tooth',(-sign*.80,y,front*.45),(.27,.12,.15),'ivory',parent,.025)
  # Leaf receiver sockets remain with the leaf; moving shoes physically seat between them.
  px=side*3.22-side*.89;py=1.72 if side<0 else 3.23
  for dy in [-.34,.34]:block('Leaf mounted lock receiver socket',(px,py+dy,front*.25),(.44,.18,.10),'bronze',LEAF,.025)
# Honest rear restraint architecture: broad molded backing returns, no duplicate frontal painting claim.
for side in [-1,1]:
 for y in [1.15,4.0]:
  outline=[(side*4.05,y-.28),(side*4.05,y+.28),(side*3.58,y+.40),(side*3.46,y-.32)]
  extrude('Rear membrane perimeter restraint',outline,-.30,-.22,'ivory',LEAF,.018)

# Moving opaque aperture parts remain within existing native blocker±.3m front/back.
for obj in objects:
 if obj.parent in [BLOOD,IVORY]:
  for vertex in obj.data.vertices:vertex.co.y*=.3/.555
  obj.data.update()
# SOURCE05: physical pressure take-up story. Frozen intact leaf remains UNMODIFIED.
# Receiver and every released vertex sit above old blockerY5; no new opaque aperture occupancy.
RELEASED=root('ReleasedClosure',FRAME)
RELEASED['presentation_initial_visible']=False
RELEASED['presentation_role']='Authored pressure-deflated gathered membrane; show only open/removed, no simulation/timer'
released_start=len(objects)
RX,RY=42,20;released_verts=[];released_uv=[];released_faces=[]
for side in [1,-1]:
 for j in range(RY+1):
  for i in range(RX+1):
   u=i/RX;v=j/RY
   # Original colour coordinates retained over a thin, closed, four-fold accordion volume.
   y=5.065+.330*v+.005*math.sin(u*math.tau*3)*math.sin(v*math.pi)
   fold=.205*math.sin(v*math.tau*4+.10*math.sin(u*math.tau*2))
   released_verts.append(((u-.5)*7.80,y,fold+side*.012))
   released_uv.append((u if side==1 else 1-u,v))
rlayer=(RX+1)*(RY+1)
for side_index in [0,1]:
 for j in range(RY):
  for i in range(RX):
   a=side_index*rlayer+j*(RX+1)+i;quad=(a,a+1,a+RX+2,a+RX+1);released_faces.append(quad if side_index==0 else tuple(reversed(quad)))
redge=list(range(RX+1))+[j*(RX+1)+RX for j in range(1,RY+1)]+[RY*(RX+1)+i for i in range(RX-1,-1,-1)]+[j*(RX+1) for j in range(RY-1,0,-1)]
for i,a in enumerate(redge):
 b=redge[(i+1)%len(redge)];released_faces.append((a,b,b+rlayer,a+rlayer))
gathered=mesh('Gathered pressure deflated membrane',released_verts,released_faces,'tissue',RELEASED,released_uv,smooth=True)
gathered['configuration']='Thin authored collapsed skin, not a resculpt/repaint of frozen intact leaf'
# Hollow receiving mouth: material at lips/endcaps only, both faces expose real gathered volume.
block('Take up receiving lower sill',(0,5.055,0),(8.02,.050,.56),'steel',FRAME,.012)
block('Take up receiving top shell',(0,5.425,0),(8.02,.050,.56),'steel',FRAME,.012)
for side in [-1,1]:
 block('Take up end bearing housing',(side*4.04,5.24,0),(.18,.42,.56),'steel',FRAME,.025)
 # Connected reservoir feed follows OUTBOARD masonry until it is above the old aperture.
 for face in [-1,1]:
  tube('Reservoir to receiver pressure feed',[(side*4.48,4.53,face*.20),(side*4.48,4.85,face*.20),(side*4.30,5.10,face*.20),(side*3.97,5.27,face*.20)],.036,'hose',FRAME,12)
  tube('Receiver feed union',[(side*3.97,5.27,face*.20),(side*3.80,5.27,face*.20)],.060,'bronze',FRAME,12)
 # Positive receiver engagement into existing supported jamb, not an unsupported floating bank.
 block('Receiver anchored return shoulder',(side*4.14,5.27,0),(.34,.32,.50),'bronze',FRAME,.022)
# Four actual transverse compression drum bays and supported axle races inside the receiving mouth.
for x in [-3.25,-1.10,1.10,3.25]:
 tube('Captive take up compression drum',[(x-.20,5.255,0),(x+.20,5.255,0)],.115,'bronze',FRAME,16)
 for dx in [-.235,.235]:
  block('Compression drum bearing saddle',(x+dx,5.255,0),(.07,.30,.40),'steel',FRAME,.018)
  tube('Visible compression axle',[(x+dx-.05,5.255,0),(x+dx+.05,5.255,0)],.044,'bronze',FRAME,10)
# Coherent clamp connection upgrade: substantial captive sleeve and keyed pressure shoe, no long thin links.
for side,parent in [(-1,BLOOD),(1,IVORY)]:
 tube('Telescoping latch pressure sleeve',[(side*.20,0,0),(side*1.05,0,0)],.18,'steel',parent,16)
 for x in [.24,.94]:tube('Pressure sleeve retaining collar',[(side*(x-.055),0,0),(side*(x+.055),0,0)],.205,'bronze',parent,16)
 for face in [-1,1]:
  outline=[(-side*.92,-.20),(-side*.92,.20),(-side*.56,.27),(-side*.43,.13),(-side*.43,-.14),(-side*.65,-.26)]
  z0,z1=(.215,.285) if face>0 else(-.285,-.215)
  extrude('Keyed clamp pressure saddle',outline,z0,z1,'bronze' if side<0 else 'ivory',parent,.020)
  for y in [-.12,.12]:
   tube('Captive saddle fastening pin',[(-side*.68,y,face*.22),(-side*.68,y,face*.295)],.028,'steel',parent,8)
released_objects=[o for o in objects if o.parent==RELEASED]

# Named editable source collections and neutral pose identity.
source=bpy.data.collections.new('Editable_Intake_Source');scene.collection.children.link(source)
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
# Sanitize actual saved source RNA buffers, including packed-image/browser/render fields.
helpers.sanitize_source_paths(bpy)
scene['provenance']='Original editable Blender mesh + builtin-image-generator pigment inputs; no Blender render/bake/simulation'
scene['reference_sha256']=manifest['reference_sha256'];scene['production_membrane_sha256']=manifest['assets'][0]['sha256'];scene['appearance_qualification']='Pending actual imported native views and independent review'
sourcefile=BASE/'intake_threshold.blend';bpy.ops.wm.save_as_mainfile(filepath=str(sourcefile),compress=True,check_existing=False)
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
exroot=export_root('IntakeThresholdV3');exframe=export_root('StationaryFrame',exroot);exleaf=export_root('MovingLeaf',exroot);exblood=export_root('BloodLatch',exframe,BLOOD.matrix_local.copy());exivory=export_root('IvoryLatch',exframe,IVORY.matrix_local.copy());exreleased=export_root('ReleasedClosure',exframe,RELEASED.matrix_local.copy())
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
 obj=bpy.data.objects.new(new.name+'_Visual',data);export_coll.objects.link(obj);obj.parent=new;data.calc_loop_triangles();counts[new.name]={'triangles':len(data.loop_triangles),'vertices':len(data.vertices),'surfaces':len(materials)}
# Export selected derived meshes/controllers only; no cameras/lights/animation/physics.
bpy.ops.object.select_all(action='DESELECT')
for o in export_coll.objects:o.select_set(True)
glb=CANDIDATE/'intake_threshold.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=False,export_yup=True,export_tangents=True,export_image_format='AUTO',export_materials='EXPORT',export_extras=True)
# Reopen EXACT source and validate actual packed images, UV/material use, hierarchy, edit/revert and privacy.
source_hash=sha(sourcefile);bpy.ops.wm.open_mainfile(filepath=str(sourcefile));bpy.context.view_layer.update();scene=bpy.context.scene
assert bpy.data.objects['BloodLatch'].parent.name=='StationaryFrame' and bpy.data.objects['IvoryLatch'].parent.name=='StationaryFrame'
assert bpy.data.objects['MovingLeaf'].parent.name=='IntakeThresholdV3'
assert bpy.data.objects['ReleasedClosure'].parent.name=='StationaryFrame'
assert bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_render and bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_viewport
leaf=bpy.data.objects['Opaque unequal pressure lobes and stitched perimeter'];before=tuple(leaf.data.vertices[100].co);leaf.data.vertices[100].co.x+=.001;assert tuple(leaf.data.vertices[100].co)!=before;leaf.data.vertices[100].co=before
assert tuple(leaf.data.vertices[100].co)==before and sha(sourcefile)==source_hash
images_out=[]
for image in bpy.data.images:
 assert image.packed_file is not None and image.filepath.startswith('//')
 images_out.append({'name':image.name,'filepath':image.filepath,'packed_bytes':len(image.packed_file.data),'packed_sha256':hashlib.sha256(image.packed_file.data).hexdigest()})
assert {a['packed_sha256'] for a in images_out}=={a['sha256'] for a in manifest['assets']}
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
proof={'schema':1,'released_configuration_bounds':released_bounds,'released_aperture_clearance_m':released_bounds['min'][1]-5.0,'released_root':'StationaryFrame/ReleasedClosure','released_neutral_source_hidden':True,'release_story':'Authored thin gathered skin in fixed receiving mouth, no fluid simulation/newtimer/opaque aperture geometry','actual_closed_assembly_bounds':neutral_bounds,'actual_both_seal_assembly_bounds':open_bounds,'carriage_origins_godot':{'BloodLatch':[-3.22,1.72,0],'IvoryLatch':[3.22,3.23,0]},'motion_witnesses':[],'scope':'Source-only original editable Blender model, actual GLB export and actual saved-source reopen. Native normal import, visual matching and mounting acceptance pending.','source':'intake_threshold.blend','source_sha256':source_hash,'recipe':'build_source.py','recipe_sha256':sha(Path(__file__)),'candidate_glb_sha256':sha(glb),'candidate_glb_bytes':glb.stat().st_size,'actual_shell_bounds':leaf_bounds,'actual_assembly_bounds':bounds([o for o in scene.objects if o.type=='MESH']),'actual_export_parts':counts,'actual_triangles':sum(x['triangles'] for x in counts.values()),'actual_export_surfaces':sum(x['surfaces'] for x in counts.values()),'editable_source_meshes':len([o for o in scene.objects if o.type=='MESH']),'packed_images':images_out,'privacy':{'actual_rna_paths_checked':len(paths),'custom_string_properties_checked':len(strings),'private_absolute_paths':0,'paths':paths,'sanitizer':'tools/build_art.py:sanitize_source_paths','helper_sha256':sha(ROOT/'tools/build_art.py')},'actual_vertex_edit_revert':True,'source_unchanged_after_reopen':sha(sourcefile)==source_hash,'native8K':False,'normal_roughness_images':False,'rendered_baked_simulated':False}
(BASE/'source-proof.json').write_text(json.dumps(proof,indent=2));(CANDIDATE/'source-proof.json').write_text(json.dumps(proof,indent=2));print('PASS sourceIntake editable/UV/packedimages/export/reopen/privacy; nativeappearance UNQUALIFIED',json.dumps({'triangles':proof['actual_triangles'],'surfaces':proof['actual_export_surfaces']}),flush=True)
