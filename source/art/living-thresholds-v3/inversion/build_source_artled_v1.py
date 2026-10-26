"""Inversion ART-LED v1 production source author/export/reopen. NO render/bake/simulation/GPU.
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
manifest=json.loads((BASE/'raw/production-inputs.json').read_text());artled=json.loads((BASE/'raw/artled-production-input-v1.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(BASE/'raw'/artled['file'])==artled['sha256']
manifest['assets']=[a for a in manifest['assets'] if a['kind'] in ['construction-reference-only','shared-hardware-albedo']]+[dict(artled,kind='leaf-albedo')]
for asset in manifest['assets']:assert sha(BASE/'raw'/asset['file'])==asset['sha256']
spec=importlib.util.spec_from_file_location('source_art_helpers',ROOT/'tools/build_art.py');helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;bpy.context.preferences.filepaths.save_version=0
# Use geometry and source pixels, never a reference-image plane or unsupported procedural bake shader.
used_assets=[a for a in manifest['assets'] if a['file'] in ['inversion_integrated_construction_v1.png','hardware_pigments_v3.png']]
assert len(used_assets)==2
images={a['file']:bpy.data.images.load(str(BASE/'raw'/a['file']),check_existing=True) for a in used_assets}
for image in images.values():image.pack()
SWATCHES={'steel':(.02,.52,.48,.98),'bronze':(.52,.52,.98,.98),'ivory':(.02,.02,.48,.48),'hose':(.52,.02,.98,.48)}
M={}
for name,rough,metal in [('steel',.56,.68),('bronze',.44,.76),('ivory',.69,.02),('hose',.83,0),('tissue',.53,0)]:
 m=bpy.data.materials.new('InversionV3_'+name);m.use_nodes=True;m.diffuse_color=(.45,.44,.40,1);nodes=m.node_tree.nodes;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=rough;bsdf.inputs['Metallic'].default_value=metal
 tex=nodes.new('ShaderNodeTexImage');tex.image=images['inversion_integrated_construction_v1.png' if name=='tissue' else 'hardware_pigments_v3.png'];tex.interpolation='Closest';m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);M[name]=m

def xyz(v):return (v[0],-v[2],v[1])
def logical(v):return (v[0],v[2],-v[1])
def root(name,parent=None,p=(0,0,0)):
 obj=bpy.data.objects.new(name,None);scene.collection.objects.link(obj);obj.parent=parent;obj.location=xyz(p);return obj
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
 area=sum(x*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*y for i,(x,y) in enumerate(outline))
 if area<0:outline=list(reversed(outline))
 n=len(outline);v=[(x,y,z) for z in [z0,z1] for x,y in outline];f=[tuple(reversed(range(n))),tuple(range(n,n*2))]
 for i in range(n):j=(i+1)%n;f.append((i,j,j+n,i+n))
 o=mesh(name,v,f,mat,parent)
 if bevel:b=o.modifiers.new('Editable relief edge bevel','BEVEL');b.width=bevel;b.segments=2
 return o


WIDTH=12.2; HALF=WIDTH/2; WALL=5.86; ORIGINS=[[-3.5, 1.4, 0], [3.75, 3.35, 0]]
ROOT_OBJ=root('InversionThresholdV3');FRAME=root('StationaryFrame',ROOT_OBJ);LEAF=root('MovingLeaf',ROOT_OBJ)
BLOOD=root('BloodLatch',FRAME,ORIGINS[0]);IVORY=root('IvoryLatch',FRAME,ORIGINS[1]);RELEASED=root('ReleasedClosure',FRAME)
BLOOD['retraction_local_x']=-1.35;IVORY['retraction_local_x']=1.35
ROOT_OBJ['contract']='Original opaque leaf envelope; visual source adds no physics or timer'

# Global UV is the selected full-bleed painting, not construction-reference pixels.
# Two continuous curved surfaces joined around the perimeter make a genuine closed volume.
NX,NY=160,72
# Registered by direct inspection of the ACTUAL selected 1935x812 painting.
# These are the large upper-right/lower-left opposed S returns, not chamber pillows,
# prior diagonal seams, luminance-displacement, separate bars, or floating rings.
def bezier(c,t):
 a,b,c1,d=c;q=1-t
 return (q*q*q*a[0]+3*q*q*t*b[0]+3*q*t*t*c1[0]+t*t*t*d[0],q*q*q*a[1]+3*q*q*t*b[1]+3*q*t*t*c1[1]+t*t*t*d[1])
def curves(segments,steps=24):
 return [bezier(c,i/steps) for c in segments for i in range(steps)]+[segments[-1][-1]]
# Connected outlines deliberately reach the original envelope. Coordinates U right/V up.
LOWER_RETURN=curves([
 [(0.035,.85),(.05,.58),(.10,.40),(.24,.34)],
 [(.24,.34),(.40,.28),(.51,.31),(.53,.43)],
 [(.53,.43),(.55,.53),(.52,.58),(.53,.61)],
 [(.53,.61),(.59,.58),(.59,.41),(.55,.29)],
 [(.55,.29),(.52,.16),(.51,.05),(.49,0)],
 [(.49,0),(.34,0),(.16,0),(.055,0)],
 [(.055,0),(.08,.14),(.20,.23),(.33,.28)],
 [(.33,.28),(.17,.30),(.06,.38),(.035,.61)],
 [(.035,.61),(.03,.72),(.03,.80),(.035,.85)]])
UPPER_RETURN=curves([
 [(.50,1),(.48,.87),(.42,.77),(.43,.61)],
 [(.43,.61),(.44,.55),(.46,.53),(.47,.58)],
 [(.47,.58),(.48,.69),(.57,.71),(.66,.66)],
 [(.66,.66),(.82,.58),(.93,.49),(.96,.08)],
 [(.96,.08),(.97,.29),(.93,.54),(.86,.62)],
 [(.86,.62),(.80,.70),(.73,.73),(.69,.74)],
 [(.69,.74),(.81,.75),(.92,.88),(.93,1)],
 [(.93,1),(.80,1),(.63,1),(.50,1)]])
PALE_FIELDS=[LOWER_RETURN,UPPER_RETURN]
# Distinct continuous cast load rails roll along the membrane margins, in the shell itself.
CAST_ROLLS=[curves([
 [(0.04,.83),(.08,.46),(.27,.34),(.45,.35)],
 [(.45,.35),(.55,.35),(.59,.62),(.50,.65)],
 [(.50,.65),(.41,.68),(.39,.87),(.49,1)]]),curves([
 [(.055,0),(.10,.20),(.38,.29),(.49,.32)],
 [(.49,.32),(.56,.34),(.57,.53),(.53,.58)],
 [(.53,.58),(.49,.65),(.51,.72),(.65,.69)],
 [(.65,.69),(.80,.61),(.92,.57),(.96,.12)]]),curves([
 [(.47,.61),(.45,.78),(.66,.62),(.77,.75)],
 [(.77,.75),(.86,.83),(.91,.92),(.92,1)]])]
COUNTER_SEAMS=[curves([
 [(.11,.96),(.29,.99),(.38,.78),(.38,.68)],
 [(.38,.68),(.27,.87),(.21,.57),(.13,.65)]]),curves([
 [(.58,.51),(.69,.42),(.83,.25),(.87,.24)],
 [(.87,.24),(.74,.18),(.66,.37),(.60,.41)]]),curves([
 [(.50,.035),(.61,.06),(.62,.31),(.58,.43)]])]
_PATH_SEGMENTS={}
def distance_path(u,v,path,closed=False):
 key=(id(path),closed)
 if key not in _PATH_SEGMENTS:
  pairs=list(zip(path,path[1:]))+([(path[-1],path[0])] if closed else [])
  _PATH_SEGMENTS[key]=[(a[0]*WIDTH,a[1]*5,(b[0]-a[0])*WIDTH,(b[1]-a[1])*5) for a,b in pairs if (a[0]-b[0])**2+(a[1]-b[1])**2>1e-18]
 px=u*WIDTH;py=v*5;best=10000
 for ax,ay,dx,dy in _PATH_SEGMENTS[key]:
  t=max(0,min(1,((px-ax)*dx+(py-ay)*dy)/(dx*dx+dy*dy)))
  best=min(best,(px-ax-t*dx)**2+(py-ay-t*dy)**2)
 return math.sqrt(best)
def contains(u,v,path):
 inside=False;j=len(path)-1
 for i in range(len(path)):
  a,b=path[i],path[j]
  if (a[1]>v)!=(b[1]>v) and u<(b[0]-a[0])*(v-a[1])/(b[1]-a[1])+a[0]:inside=not inside
  j=i
 return inside
def surface(u,v):
 # Lower dark counterfields remain broad and quiet. Pale membranes are real broad bowing.
 z=.112
 for path in PALE_FIELDS:
  d=distance_path(u,v,path,True)
  if contains(u,v,path):z=max(z,.185+.080*(1-math.exp(-(d/.40)**2)))
  z=max(z,.115+.139*math.exp(-((d-.055)/.090)**2))
 for path in CAST_ROLLS:
  d=distance_path(u,v,path);z=max(z,.116+.171*math.exp(-(d/.105)**2))
 for path in COUNTER_SEAMS:
  d=distance_path(u,v,path);z+=.025*math.exp(-((d-.065)/.045)**2)-.020*math.exp(-(d/.035)**2)
 # Three actual painted empty pivot pockets: recessed backing inside broad integral rolled returns.
 # Left/right art pockets are NOT the fixed gameplay roots: retain both honestly.
 for cx,cy,rx,ry in [(.094,.224,.047,.094),(.499,.505,.036,.090),(.912,.710,.037,.088)]:
  r=math.sqrt(((u-cx)/rx)**2+((v-cy)/ry)**2)
  z=z*(1-math.exp(-r**8*1.8))+.052*math.exp(-r**8*1.8)
  z=max(z,.064+.210*math.exp(-((r-1.20)/.20)**2))
 # Authored connected perimeter roll gives exact +/- .3 without an arbitrary isolated spike.
 edge=min(u*WIDTH,(1-u)*WIDTH,v*5,(1-v)*5)
 z=z*(1-math.exp(-(edge/.035)**2))+.3*math.exp(-(edge/.035)**2)
 return max(.045,min(.3,z))
# Whole closed->retracted mechanism swept paths have actual continuous shallow support lands.
# The shortened slide is enclosed by leaf width even at the existing +/-1.35 m stroke.
SUPPORT_LANDS=[(-5.60,-2.35,1.4),(2.79,6.04,3.35)]
def receiver_depth(u,v,z):
 xx=(u-.5)*WIDTH
 for left,right,y in SUPPORT_LANDS:
  dx=max(left-xx,0,xx-right);dy=max(abs(v*5-y)-.72,0)
  w=math.exp(-((dx/.065)**4+(dy/.080)**4))
  z=z*(1-w)+.058*w
 return max(.045,min(.3,z))
verts=[];uv=[]
for side in [1,-1]:
 for j in range(NY+1):
  for i in range(NX+1):
   u=i/NX;v=j/NY;q=u
   verts.append(((u-.5)*WIDTH,v*5,side*receiver_depth(u,v,surface(q,v))));uv.append((q,v))
layer=(NX+1)*(NY+1);faces=[]
for s in [0,1]:
 for j in range(NY):
  for i in range(NX):
   a=s*layer+j*(NX+1)+i;q=(a,a+1,a+NX+2,a+NX+1);faces.append(q if s==0 else tuple(reversed(q)))
edge=list(range(NX+1))+[j*(NX+1)+NX for j in range(1,NY+1)]+[NY*(NX+1)+i for i in range(NX-1,-1,-1)]+[j*(NX+1) for j in range(NY-1,0,-1)]
for i,a in enumerate(edge):b=edge[(i+1)%len(edge)];faces.append((b,a,a+layer,b+layer))
leaf=mesh('MovingLeaf_Visual',verts,faces,'tissue',LEAF,uv,True)
# True load-bearing sidewall bridges and channel housings, outside the entire usable XY prism.
for sign in [-1,1]:
 x=sign*(WALL+.38)
 block('Deep side carrier housing',(x,2.55,0),(.65,4.90,.58),'steel',FRAME,.05)
 for y in [.65,2.55,4.45]:
  block('Masonry seated anchor',(sign*(WALL+.20),y,0),(.28,.50,.58),'bronze',FRAME,.025)
 for face in [-1,1]:
  extrude('Curved shoulder carrier',[(sign*(WALL+.02),4.75),(sign*(WALL+.65),4.40),(sign*(WALL+.65),5.35),(sign*(WALL+.02),5.40)],face*.16-.08,face*.16+.08,'ivory',FRAME,.025)
  tube('Supported receiver pressure feed',[(x,3.1,face*.20),(x,5.18,face*.20),(sign*(WALL-.25),5.25,face*.20)],.045,'hose',FRAME)
# Header is shallow, hollow-fronted, and entirely ABOVE original aperture, including bevels.
for y in [5.075,5.425]:block('Receiving beam flange',(0,y,0),(WIDTH+.12,.06,.56),'steel',FRAME,.012)
for sign in [-1,1]:block('Receiving beam end bearing',(sign*(HALF+.04),5.25,0),(.20,.40,.56),'bronze',FRAME,.02)
# Localized junction integration only: continuous registered relief and global art stay identical.
# Real broad keyed pressure faces engage substantial open receivers, not floating tabs/ring overlays.
mechanism_pairs=[]
for sign,parent,origin in [(-1,BLOOD,ORIGINS[0]),(1,IVORY,ORIGINS[1])]:
 label='Blood' if sign<0 else 'Ivory';center_x=.33 if sign<0 else -.14
 def key_outline(points,stationary=False):
  outline=[(center_x+sign*t+(origin[0] if stationary else 0),y+(origin[1] if stationary else 0)) for t,y in points]
  area=sum(x*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*y for i,(x,y) in enumerate(outline))
  return outline if area>0 else list(reversed(outline))
 pad=[(-.74,-.20),(-.66,-.48),(-.40,-.65),(.04,-.66),(.62,-.47),(.68,.40),(.28,.62),(-.35,.67),(-.66,.43)]
 jaw=[(.55,.52),(-.20,.66),(-.58,.43),(-.72,0),(-.56,-.45),(-.15,-.62),(.55,-.50),(.55,-.30),(-.16,-.30),(-.34,-.16),(-.34,.17),(-.15,.30),(.55,.30)]
 shoe=[(-.34,-.16),(-.16,-.30),(.25,-.30),(.49,-.20),(.77,-.20),(.77,.22),(.47,.22),(.25,.30),(-.15,.30),(-.34,.17)]
 bearing=[(-.22,-.12),(-.08,-.23),(.22,-.23),(.48,-.14),(.58,-.14),(.58,.15),(.35,.15),(.21,.23),(-.07,.23),(-.22,.12)]
 for face in [-1,1]:
  def slab(name,outline,lo,hi,mat,parent,stationary=False,bevel=0):
   return extrude(label+' '+name+(' front' if face>0 else ' back'),key_outline(outline,stationary),min(face*lo,face*hi),max(face*lo,face*hi),mat,parent,bevel)
  # Broad dark bed is seated into the unchanged flattened substrate, with a visible vacant socket on release.
  slab('junction socket foundation',pad,.050,.135,'steel',LEAF,True,.016)
  receiver=slab('substantial keyed receiver jaws',jaw,.135,.255,'bronze' if sign<0 else 'steel',LEAF,True)
  pressure=slab('keyed pressure body',shoe,.145,.255,'bronze' if sign<0 else 'steel',parent)
  # Broad continuous bone bearing gives Blood a light contact cue; Ivory retains a distinct pale protected shield.
  slab('bone pressure bearing',bearing,.255,.294,'ivory',parent,False,.012)
  if sign<0:
   slab('crimson pressure inset',[(.04,-.13),(.26,-.13),(.42,-.07),(.42,.09),(.24,.14),(.04,.14)],.294,.299,'hose',parent)
   # Light fixed bearing shoulders remain behind when the light moving shoe withdraws.
   for y in [-1,1]:slab('bone receiver shoulder',[(.05,y*.32),(.50,y*.32),(.50,y*.45),(.02,y*.50),(-.19,y*.42)],.255,.285,'ivory',LEAF,True,.010)
  else:
   # Asymmetric ivory shield, with dark steel protected rim and a separate broad fixed pale lower saddle.
   slab('pale fixed socket saddle',[(-.51,-.35),(-.16,-.52),(.43,-.44),(.43,-.34),(-.16,-.34),(-.33,-.20)],.255,.287,'ivory',LEAF,True,.010)
   slab('protected shield spine',[(-.12,-.18),(.00,-.18),(.00,.18),(-.12,.18)],.294,.299,'bronze',parent)
  tube(label+' supported pressure slide',[(center_x+sign*.64,0,face*.19),(center_x+sign*.95,0,face*.19)],.065,'bronze' if sign<0 else 'steel',parent,12)
  mechanism_pairs.append({'label':label,'face':face,'receiver':receiver,'pressure':pressure,'root':parent,'origin':origin,'center_x':center_x,'sign':sign})
# Authored deflated form with full-paint UV retained; open state is not simply absent material.
rv=[];ru=[];RX,RY=64,12
for side in [1,-1]:
 for j in range(RY+1):
  for i in range(RX+1):
   u=i/RX;v=j/RY;y=5.13+.24*v+.025*math.sin(u*math.tau*3)*math.sin(math.pi*v)
   z=side*(.055+.12*math.sin(math.pi*v)**2*(.7+.3*math.sin(u*math.tau*7)**2))
   rv.append(((u-.5)*(WIDTH-.24),y,z));ru.append((u,v))
rl=(RX+1)*(RY+1);rf=[]
for s in [0,1]:
 for j in range(RY):
  for i in range(RX):
   a=s*rl+j*(RX+1)+i;q=(a,a+1,a+RX+2,a+RX+1);rf.append(q if s==0 else tuple(reversed(q)))
re=list(range(RX+1))+[j*(RX+1)+RX for j in range(1,RY+1)]+[RY*(RX+1)+i for i in range(RX-1,-1,-1)]+[j*(RX+1) for j in range(RY-1,0,-1)]
for i,a in enumerate(re):b=re[(i+1)%len(re)];rf.append((b,a,a+rl,b+rl))
released_objects=[mesh('Gathered registered closure',rv,rf,'tissue',RELEASED,ru,True)]

# Named editable source collections and neutral pose identity.
source=bpy.data.collections.new('Editable_Inversion_Source');scene.collection.children.link(source)
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
leaf_bounds=bounds([leaf]);assert all(abs(a-b)<.00001 for a,b in zip(leaf_bounds['size'],[WIDTH,5,.6]))
assert max(v[1] for v in [logical(o.matrix_world@v.co) for o in objects for v in o.data.vertices])<=5.500001
for part in [LEAF,BLOOD,IVORY]:
 envelope=bounds([o for o in objects if o.parent==part]);assert envelope['min'][2]>=-.300001 and envelope['max'][2]<=.300001, 'Moving aperture art outside sole blocker depth'

for obj in objects:
 if obj.parent!=FRAME:continue
 for poly in obj.data.polygons:
  vv=[logical(obj.matrix_world@obj.data.vertices[i].co) for i in poly.vertices]
  assert not (min(v[0] for v in vv)<WALL-1e-6 and max(v[0] for v in vv)>-WALL+1e-6 and min(v[1] for v in vv)<5-1e-6 and max(v[1] for v in vv)>1e-6), ('Stationary aperture intrusion',obj.name)

# Full evaluated leaf, not merely backing: exact existing opaque ABI across all sculptural parts.
leaf_all_bounds=bounds([o for o in objects if o.parent==LEAF])
assert all(abs(a-b)<.00001 for a,b in zip(leaf_all_bounds['min'],[-HALF,0,-.3])), ('Full leaf minimum',leaf_all_bounds)
assert all(abs(a-b)<.00001 for a,b in zip(leaf_all_bounds['max'],[HALF,5,.3])), ('Full leaf maximum',leaf_all_bounds)

# Freeze evaluated physical engagement evidence before saving. Broad opposing jaw contact, not marker proximity.
from mathutils.geometry import closest_point_on_tri
def evaluated_distance(obj,point):
 deps=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(deps);data=bpy.data.meshes.new_from_object(ev,depsgraph=deps);data.calc_loop_triangles();best=100.0
 for tri in data.loop_triangles:
  vv=[obj.matrix_world@data.vertices[i].co for i in tri.vertices];best=min(best,(closest_point_on_tri(point,*vv)-point).length)
 bpy.data.meshes.remove(data);return best
mechanism_contact_proof=[]
for pair in mechanism_pairs:
 row={'mechanism':pair['label'],'face':pair['face'],'receiver_mesh':pair['receiver'].name,'moving_mesh':pair['pressure'].name,'root_z':logical(pair['root'].location)[2],'jaw_contacts':[]}
 assert abs(row['root_z'])<1e-8
 for y in [-.30,.30]:
  p=Vector(xyz((pair['origin'][0]+pair['center_x']+pair['sign']*.05,pair['origin'][1]+y,pair['face']*.20)))
  fixed=evaluated_distance(pair['receiver'],p);moving=evaluated_distance(pair['pressure'],p)
  assert fixed<.00001 and moving<.00001, ('Missing actual broad keyed receiver engagement',pair['label'],fixed,moving)
  pair['root'].location.x+=pair['sign']*1.35;bpy.context.view_layer.update();released=evaluated_distance(pair['pressure'],p);pair['root'].location.x-=pair['sign']*1.35;bpy.context.view_layer.update()
  assert released>.85,('Keyed pressure body still occupies engaged seat after independent full stroke',released)
  row['jaw_contacts'].append({'local_y':y,'evaluated_receiver_distance_m':fixed,'evaluated_pressure_distance_m':moving,'released_pressure_distance_m':released,'contact_depth_m':pair['face']*.20})
 mechanism_contact_proof.append(row)

# Actual closed shell winding/manifold check, including correctly outward sidewall caps.
def mesh_topology_proof(obj):
 data=obj.data;data.calc_loop_triangles();uses={}
 for polygon in data.polygons:
  ids=list(polygon.vertices)
  for a,b in zip(ids,ids[1:]+ids[:1]):
   key=tuple(sorted((a,b)));uses.setdefault(key,[]).append((a,b))
 assert all(len(v)==2 and v[0]==tuple(reversed(v[1])) for v in uses.values()), ('Nonmanifold/winding',obj.name)
 volume=sum(data.vertices[t.vertices[0]].co.dot(data.vertices[t.vertices[1]].co.cross(data.vertices[t.vertices[2]].co))/6 for t in data.loop_triangles)
 assert volume>0,('Inward shell',obj.name,volume)
 return {'mesh':obj.name,'undirected_edges':len(uses),'closed_opposed_edge_winding':True,'signed_volume_m3':volume}
shell_topology=mesh_topology_proof(leaf)
# The support relief is <=.058 m over the WHOLE carriage swept footprint, allowing socket bed seating.
stroke_support_proof=[]
for index,(x,y,_) in enumerate(ORIGINS):
 sign=-1 if index==0 else 1;cx=.33 if index==0 else -.14;worst=0
 for step in range(28):
  dx=sign*1.35*step/27
  for lx in [-.34,-.16,.05,.25,.49,.77]:
   for ly in [-.30,0,.30]:
    xx=x+cx+sign*lx+dx;z=receiver_depth(xx/WIDTH+.5,(y+ly)/5,surface(xx/WIDTH+.5,(y+ly)/5));worst=max(worst,z)
    assert z<=.058001,('Buried moving pressure body',index,xx,y+ly,z)
 stroke_support_proof.append({'mechanism':'Blood' if index==0 else 'Ivory','samples':504,'maximum_support_depth_m':worst,'pressure_body_inner_depth_m':.145,'minimum_pressure_to_substrate_clearance_m':.145-worst})
# Sanitize actual saved source RNA buffers, including packed-image/browser/render fields.
helpers.sanitize_source_paths(bpy)
scene['provenance']='Original editable Blender mesh + builtin-image-generator pigment inputs; no Blender render/bake/simulation'
scene['reference_sha256']=next(a['sha256'] for a in manifest['assets'] if a['kind']=='construction-reference-only');scene['production_membrane_sha256']=next(a['sha256'] for a in used_assets if a['file']==artled['file']);scene['appearance_qualification']='Pending actual imported native views and independent review'
sourcefile=BASE/'inversion_threshold_artled_v1.blend';bpy.ops.wm.save_as_mainfile(filepath=str(sourcefile),compress=True,check_existing=False)
# Unhide only in-memory DERIVATION after cold neutral source was frozen.
released_collection.hide_render=False;released_collection.hide_viewport=False;bpy.context.view_layer.update()
# Evaluated export duplicates merge geometry only within stable controller roots; source stays separate/editable.
deps=bpy.context.evaluated_depsgraph_get();export_coll=bpy.data.collections.new('DERIVED_EXPORT_ONLY');scene.collection.children.link(export_coll)
def export_root(name,parent=None,transform=None):
 o=bpy.data.objects.new(name,None);export_coll.objects.link(o);o.parent=parent
 if transform is not None:o.matrix_local=transform
 return o
# Free only temporary in-memory source names AFTER saved source was frozen.
for obj in [ROOT_OBJ,FRAME,LEAF,BLOOD,IVORY,RELEASED]+objects:obj.name=obj.name+'_AUTHORING_ONLY'
exroot=export_root('InversionThresholdV3');exframe=export_root('StationaryFrame',exroot);exleaf=export_root('MovingLeaf',exroot);exblood=export_root('BloodLatch',exframe,BLOOD.matrix_local.copy());exivory=export_root('IvoryLatch',exframe,IVORY.matrix_local.copy());exreleased=export_root('ReleasedClosure',exframe,RELEASED.matrix_local.copy())
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
glb=CANDIDATE/'inversion_threshold.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=False,export_yup=True,export_tangents=True,export_image_format='AUTO',export_materials='EXPORT',export_extras=True)
# Reopen EXACT source and validate actual packed images, UV/material use, hierarchy, edit/revert and privacy.
source_hash=sha(sourcefile);bpy.ops.wm.open_mainfile(filepath=str(sourcefile));bpy.context.view_layer.update();scene=bpy.context.scene
assert bpy.data.objects['BloodLatch'].parent.name=='StationaryFrame' and bpy.data.objects['IvoryLatch'].parent.name=='StationaryFrame'
assert bpy.data.objects['MovingLeaf'].parent.name=='InversionThresholdV3'
assert bpy.data.objects['ReleasedClosure'].parent.name=='StationaryFrame'
assert bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_render and bpy.data.collections['ReleasedConfiguration_SOURCE_HIDDEN'].hide_viewport
leaf=bpy.data.objects['MovingLeaf_Visual'];before=tuple(leaf.data.vertices[100].co);leaf.data.vertices[100].co.x+=.001;assert tuple(leaf.data.vertices[100].co)!=before;leaf.data.vertices[100].co=before
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
proof={'schema':1,'shell_topology':shell_topology,'stroke_support_proof':stroke_support_proof,'registration_file':'uv-registration-artled-v1.json','method':'Handregistered opposed S-swept broad pale returns, integral cast rolled loadpaths/dark counterfields/backed pivot pockets; no pixel-height sampling, overlay bars or rings','mechanism_contact_proof':mechanism_contact_proof,'released_configuration_bounds':released_bounds,'released_aperture_clearance_m':released_bounds['min'][1]-5.0,'released_root':'StationaryFrame/ReleasedClosure','released_neutral_source_hidden':True,'release_story':'Authored thin gathered counter-tension returns in fixed overhead receiving mouth above Y5 and below existing local roofY9; no fluid simulation/new timer','actual_closed_assembly_bounds':neutral_bounds,'actual_both_seal_assembly_bounds':open_bounds,'carriage_origins_godot':{'BloodLatch':ORIGINS[0],'IvoryLatch':ORIGINS[1]},'motion_witnesses':[],'scope':'Source-only original editable Blender model, actual GLB export and actual saved-source reopen. Native normal import, visual matching and mounting acceptance pending.','source':'inversion_threshold_artled_v1.blend','source_sha256':source_hash,'recipe':'build_source_artled_v1.py','recipe_sha256':sha(Path(__file__)),'candidate_glb_sha256':sha(glb),'candidate_glb_bytes':glb.stat().st_size,'actual_shell_bounds':leaf_bounds,'actual_assembly_bounds':bounds([o for o in scene.objects if o.type=='MESH']),'actual_export_parts':counts,'actual_triangles':sum(x['triangles'] for x in counts.values()),'actual_export_surfaces':sum(x['surfaces'] for x in counts.values()),'editable_source_meshes':len([o for o in scene.objects if o.type=='MESH']),'packed_images':images_out,'privacy':{'actual_rna_paths_checked':len(paths),'custom_string_properties_checked':len(strings),'private_absolute_paths':0,'paths':paths,'sanitizer':'tools/build_art.py:sanitize_source_paths','helper_sha256':sha(ROOT/'tools/build_art.py')},'actual_vertex_edit_revert':True,'source_unchanged_after_reopen':sha(sourcefile)==source_hash,'native8K':False,'normal_roughness_images':False,'rendered_baked_simulated':False}
(BASE/'source-proof-artled-v1.json').write_text(json.dumps(proof,indent=2));(CANDIDATE/'source-proof.json').write_text(json.dumps(proof,indent=2));print('PASS sourceInversion editable/UV/packedimages/export/reopen/privacy; nativeappearance UNQUALIFIED',json.dumps({'triangles':proof['actual_triangles'],'surfaces':proof['actual_export_surfaces']}),flush=True)
