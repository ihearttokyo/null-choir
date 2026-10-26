"""Revision02 original closed-volume Crawler/Brute rigs; fore/aft loaded anatomy. Pure Python; never imports Blender.

Every pose reuses the same local meshes and rigid link lengths. Joint local
transforms change; mesh scale never does. Blender adapter preserves this hierarchy.
Front is -Y, physical hammer/strong scavenging claw remains -X in every view.
"""
from dataclasses import dataclass, asdict
import math

POSES=('idle','walk_a','walk_b','attack','dead')
SPEC={'crawler':{'ortho':3.8,'aim':1.18,'camera_z':3.5},'brute':{'ortho':4.4,'aim':1.7,'camera_z':3.5}}
PALETTE={
 'tendon':(.32,.105,.105,1),'tendon_light':(.49,.21,.18,1),
 'bone':(.72,.61,.43,1),'bone_light':(.89,.80,.61,1),
 'iron':(.105,.17,.19,1),'steel':(.38,.48,.46,1),
 'brass':(.51,.32,.13,1),'socket':(.035,.032,.033,1),
 'amber':(.89,.43,.075,1),
}

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,k):return tuple(x*k for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return math.sqrt(dot(a,a))
def unit(a):
 n=norm(a);assert n>1e-9;return mul(a,1/n)
def identity():return ((1.,0,0,0),(0,1.,0,0),(0,0,1.,0),(0,0,0,1.))
def mm(a,b):return tuple(tuple(sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)) for i in range(4))
def point(m,p):return tuple(sum(m[i][j]*p[j] for j in range(3))+m[i][3] for i in range(3))
def translate(p):
 m=[list(r) for r in identity()]
 for i in range(3):m[i][3]=p[i]
 return tuple(tuple(r) for r in m)
def rx(a):
 c,s=math.cos(a),math.sin(a);return ((1,0,0,0),(0,c,-s,0),(0,s,c,0),(0,0,0,1))
def ry(a):
 c,s=math.cos(a),math.sin(a);return ((c,0,s,0),(0,1,0,0),(-s,0,c,0),(0,0,0,1))
def rz(a):
 c,s=math.cos(a),math.sin(a);return ((c,-s,0,0),(s,c,0,0),(0,0,1,0),(0,0,0,1))
def transform(position=(0,0,0),rotation=(0,0,0)):
 return mm(translate(position),mm(rz(rotation[2]),mm(ry(rotation[1]),rx(rotation[0]))))

@dataclass
class Joint:
 name:str
 parent:str|None
 matrix:tuple
@dataclass
class Mesh:
 name:str
 joint:str
 material:str
 vertices:list
 faces:list
 highlight_material:str|None=None
 highlight_faces:list|None=None

class Rig:
 def __init__(self,role,pose):
  self.role,self.pose=role,pose;self.joints={};self.meshes=[];self.links={};self.ground_shift=0;self.rest_center_shift=(0.,0.)
 def joint(self,name,parent=None,position=(0,0,0),rotation=(0,0,0)):
  assert name not in self.joints and (parent is None or parent in self.joints)
  self.joints[name]=Joint(name,parent,transform(position,rotation));return name
 def mesh(self,name,joint,material,vertices,faces,highlight=None):
  assert joint in self.joints and material in PALETTE
  # All primitives are coherently wound; normalize an entire primitive once.
  # This never drops faces, changes shape, fills a hole or rescales geometry.
  if signed_volume(vertices,faces)<0:faces=[tuple(reversed(f)) for f in faces]
  hi=[i for i,f in enumerate(faces) if sum(vertices[v][2] for v in f)/len(f)>0] if highlight else None
  m=Mesh(name,joint,material,[tuple(v) for v in vertices],[tuple(f) for f in faces],highlight,hi);self.meshes.append(m);return m
 def world(self,name):
  j=self.joints[name];return mm(self.world(j.parent),j.matrix) if j.parent else j.matrix
 def world_vertices(self):
  return [point(self.world(m.joint),v) for m in self.meshes for v in m.vertices]
 def ground(self):
  vertices=self.world_vertices();low=min(v[2] for v in vertices);self.ground_shift=-low
  # Existing late-actor source contract centers a genuinely fallen body in XY.
  # One source-space placement for all8cameras; never image fitting/cropping.
  if self.pose=='dead':self.rest_center_shift=tuple(-(min(v[k] for v in vertices)+max(v[k] for v in vertices))*.5 for k in range(2))
  self.joints['GroundRoot'].matrix=mm(translate((*self.rest_center_shift,-low)),self.joints['GroundRoot'].matrix)
 def box(self,name,joint,pos,size,mat,bevel=.05,highlight=None):
  x,y,z=[v/2 for v in size];b=min(bevel,x*.4,y*.4)
  outline=[(-x+b,-y),(x-b,-y),(x,-y+b),(x,y-b),(x-b,y),(-x+b,y),(-x,y-b),(-x,-y+b)]
  verts=[add((a,b,d),pos) for d in (-z,z) for a,b in outline];n=len(outline)
  faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
  return self.mesh(name,joint,mat,verts,faces,highlight)
 def egg(self,name,joint,pos,axes,mat,sides=12,rings=6,highlight=None):
  verts=[add(pos,(0,0,-axes[2]))]
  for ring in range(1,rings):
   a=-math.pi/2+math.pi*ring/rings
   for side in range(sides):
    t=math.tau*side/sides;verts.append(add(pos,(axes[0]*math.cos(a)*math.cos(t),axes[1]*math.cos(a)*math.sin(t),axes[2]*math.sin(a))))
  top=len(verts);verts.append(add(pos,(0,0,axes[2])))
  faces=[(0,1+(j+1)%sides,1+j) for j in range(sides)]
  for ring in range(rings-2):
   for j in range(sides):
    a=1+ring*sides+j;b=1+ring*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
  last=1+(rings-2)*sides;faces.extend((last+j,last+(j+1)%sides,top) for j in range(sides))
  return self.mesh(name,joint,mat,verts,faces,highlight)
 def tube(self,name,joint,points,radii,mat,sides=8,highlight=None):
  assert len(points)>=2
  radii=[radii]*len(points) if isinstance(radii,(float,int)) else radii
  verts=[];faces=[]
  for i,p in enumerate(points):
   tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]));axis=(0,0,1) if abs(tangent[2])<.9 else (1,0,0)
   u=unit(cross(tangent,axis));v=cross(tangent,u)
   for j in range(sides):
    t=math.tau*j/sides;verts.append(add(p,mul(add(mul(u,math.cos(t)),mul(v,math.sin(t))),radii[i])))
   if i:
    for j in range(sides):
     a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
  faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
  return self.mesh(name,joint,mat,verts,faces,highlight)
 def carapace(self,name,joint,pos,width,length,height,mat,highlight=None):
  # Full fore/aft armored volume: unequal end shoulders, not a camera-facing leaf.
  verts=[];faces=[];sides=8
  for y,w,h in [(-.50,.66,.55),(-.34,.95,.86),(.05,1.,1.),(.38,.78,.72),(.50,.52,.40)]:
   for j in range(sides):
    a=math.tau*j/sides;verts.append(add(pos,(math.cos(a)*width*w,y*length,math.sin(a)*height*h)))
  for ring in range(4):
   for j in range(sides):
    a=ring*sides+j;b=ring*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
  faces.extend([tuple(reversed(range(sides))),tuple(range(32,40))])
  return self.mesh(name,joint,mat,verts,faces,highlight)
 def chain(self,name,parent,mount,azimuth,pitch,bend,lengths,radius,material):
  a=self.joint(name+'/Root',parent,mount,(0,pitch,azimuth));b=self.joint(name+'/Bend',a,(lengths[0],0,0),(0,bend,0));end=self.joint(name+'/End',b,(lengths[1],0,0))
  for label,j,length,r in [('Upper',a,lengths[0],radius),('Lower',b,lengths[1],radius*.72)]:
   self.egg(name+'/'+label+' living solid',j,(length*.5,0,0),(length*.58,r,r),material,highlight='tendon_light' if material=='tendon' else None)
   self.tube(name+'/'+label+' load spar',j,[(0,-r*.6,r*.4),(length,-r*.6,r*.4)],r*.28,'bone',6)
  self.egg(name+'/Joint pin',b,(0,0,0),(radius*.9,)*3,'iron')
  self.links[name]=(a,b,end,tuple(lengths));return a,b,end
 def data(self):return {'role':self.role,'pose':self.pose,'ground_shift_m':self.ground_shift,'death_rest_center_shift_xy':self.rest_center_shift,'joints':{n:asdict(j) for n,j in self.joints.items()},'meshes':[asdict(m) for m in self.meshes],'links':self.links}

def signed_volume(vertices,faces):
 return sum(dot(vertices[f[0]],cross(vertices[f[i]],vertices[f[i+1]]))/6 for f in faces for i in range(1,len(f)-1))

def inverse_rigid(m):
 return tuple(tuple(m[j][i] if j<3 else -sum(m[k][i]*m[k][3] for k in range(3)) for j in range(4)) for i in range(3))+((0,0,0,1),)

def basis_x(vector,pole):
 x=unit(vector);y=unit(sub(pole,mul(x,dot(pole,x))));z=cross(x,y)
 return ((x[0],y[0],z[0],0),(x[1],y[1],z[1],0),(x[2],y[2],z[2],0),(0,0,0,1))

def limb(r,name,parent,mount,target_root,pole_root,lengths,radius,material):
 # Exact analytic two-link IK. Knee pole contains real Y/Z displacement;
 # unlike front-only splay, side-camera knee/ankle silhouettes remain bent.
 parent_world=r.world(parent);target=point(inverse_rigid(parent_world),point(r.world('GroundRoot'),target_root))
 pole=point(inverse_rigid(parent_world),point(r.world('GroundRoot'),pole_root));delta=sub(target,mount);distance=norm(delta);l1,l2=lengths
 assert abs(l1-l2)+1e-5<distance<l1+l2-1e-5,(r.role,r.pose,name,'unreachable fixed-link target',distance,lengths)
 axis=unit(delta);bend_axis=unit(sub(sub(pole,mount),mul(axis,dot(sub(pole,mount),axis))))
 along=(l1*l1-l2*l2+distance*distance)/(2*distance);height=math.sqrt(max(0,l1*l1-along*along))
 knee=add(mount,add(mul(axis,along),mul(bend_axis,height)));upper=basis_x(sub(knee,mount),bend_axis);lower_parent=basis_x(sub(target,knee),bend_axis)
 a=r.joint(name+'/Root',parent,mount);r.joints[a].matrix=mm(translate(mount),upper)
 b=r.joint(name+'/Bend',a,(l1,0,0));r.joints[b].matrix=mm(translate((l1,0,0)),mm(inverse_rigid(upper),lower_parent))
 end=r.joint(name+'/End',b,(l2,0,0))
 for label,j,length,thick in [('Upper',a,l1,radius),('Lower',b,l2,radius*.78)]:
  r.egg(name+'/'+label+' continuous tendon',j,(length*.5,0,0),(length*.60,thick,thick*.92),material,highlight='tendon_light')
  # Substantial chamfered solid casing: broad value planes, not small rods.
  verts=[];faces=[];n=8
  for x,w in [(0,.53),(.16,.88),(.53,1.),(.84,.73),(1.,.48)]:
   for k in range(n):
    angle=math.tau*k/n;verts.append((length*x,math.cos(angle)*thick*.84*w,math.sin(angle)*thick*.72*w+thick*.50))
  for ring in range(4):
   for k in range(n):
    v=ring*n+k;v2=ring*n+(k+1)%n;faces.append((v,v2,v2+n,v+n))
  faces += [tuple(reversed(range(n))),tuple(range(32,40))]
  r.mesh(name+'/'+label+' closed load casing',j,'bone',verts,faces,'bone_light')
 r.egg(name+'/Deep knuckle',b,(0,0,0),(radius*.96,)*3,'iron',highlight='steel')
 # A real orientation-only distal joint, never a mesh scale or view billboard.
 frame=r.joint(name+'/ContactFrame',end);rot=mm(inverse_rigid(r.world(end)),r.world('GroundRoot'))
 r.joints[frame].matrix=tuple(tuple(rot[i][j] if j<3 else (1 if i==3 else 0) for j in range(4)) for i in range(4))
 r.links[name]=(a,b,end,tuple(lengths));return a,b,end,frame

CRAWLER={
 'idle':dict(z=.66,y=0,lean=.045,stride=0,head=-.06,jaw=.14),
 'walk_a':dict(z=.69,y=-.025,lean=.10,stride=.17,head=-.02,jaw=.18),
 'walk_b':dict(z=.62,y=.015,lean=-.025,stride=-.17,head=-.12,jaw=.16),
 'attack':dict(z=.49,y=-.36,lean=.22,stride=0,head=-.12,jaw=.57),
 'dead':dict(z=.27,y=.05,lean=-.08,stride=0,head=-.21,jaw=.70),
}
BRUTE={
 'idle':dict(pelvisz=1.37,y=0,lean=.23,fall=0,twist=0,stride=0,head=.13,jaw=.08),
 'walk_a':dict(pelvisz=1.34,y=-.03,lean=.29,fall=0,twist=.045,stride=.15,head=.09,jaw=.12),
 'walk_b':dict(pelvisz=1.32,y=.015,lean=.20,fall=0,twist=-.045,stride=-.15,head=.17,jaw=.10),
 'attack':dict(pelvisz=1.07,y=-.16,lean=.61,fall=0,twist=-.08,stride=0,head=.34,jaw=.32),
 'dead':dict(pelvisz=1.01,y=.05,lean=.38,fall=1.43,twist=.23,stride=0,head=-.24,jaw=.53),
}

def crawler(pose):
 d=CRAWLER[pose];r=Rig('crawler',pose)
 r.joint('GroundRoot',rotation=(0,.08 if pose=='dead' else 0,.13 if pose=='dead' else 0))
 r.joint('LowThorax','GroundRoot',(0,d['y'],d['z']),(d['lean'],0,0))
 r.egg('Continuous low predatory ventral mass','LowThorax',(0,.07,-.005),(.37,.70,.29),'tendon',highlight='tendon_light')
 r.carapace('Deep arched scavenger shell','LowThorax',(0,.17,.16),.43,1.35,.34,'iron',highlight='steel')
 for i,(y,w,h) in enumerate([(-.39,.36,.17),(.02,.43,.22),(.44,.30,.15)]):
  r.carapace('Sculpted unequal load saddle_%d'%i,'LowThorax',(0,y,.29),w,.48,h,'bone',highlight='bone_light')
 r.joint('RearReservoir','LowThorax',(.05,.65,.09),(0,.10,0))
 r.egg('Rear scavenging reservoir','RearReservoir',(0,.16,0),(.29,.34,.24),'tendon')
 r.carapace('Rear reservoir full shield','RearReservoir',(0,.20,.12),.24,.50,.16,'iron',highlight='steel')
 r.tube('Attached rear siphon return','RearReservoir',[(0,.31,0),(.14,.48,.04),(.22,.56,.16)],[.13,.085,.035],'bone',8)
 for side in (-1,1):
  for i,y in enumerate((-.44,.035,.49)):
   phase=d['stride']*(1 if (i+(side>0))%2 else -1)
   foot_y=[-.91,-.03,.88][i]+(.14 if side>0 else -.06)+phase
   foot_x=side*[.69,.78,.68][i];lift=.07 if phase>0 else 0
   if pose=='attack':foot_y=[-.67,.17,.74][i]+(.13 if side>0 else -.07);foot_x=side*[.74,.77,.65][i]
   if pose=='dead':foot_y=[-.56,.07,.58][i]+side*.08;foot_x=side*.46;lift=.08
   target=(foot_x,foot_y,.075+lift)
   # Front and rear knees oppose each other; near/far contact stagger is real.
   pole=(side*.83,[-1.30,.38,.65][i]+side*.09,[.45,.70,.95][i])
   if pose=='dead':pole=(side*.83,[-1.30,.38,.10][i]+side*.09,.10)
   a,b,end,foot=limb(r,'Scavenging leg_%s_%d'%(side,i),'LowThorax',(side*.29,y,-.07),target,pole,(.48,.55),.115 if i==0 else .105,'tendon')
   r.box('Broad planted scavenger foot_%s_%d'%(side,i),foot,(0,-.035,-.025),(.25,.29,.14),'iron',.035,highlight='steel')
   for toe in (-1,1):r.tube('Grounded hooked toe_%s_%d_%s'%(side,i,toe),foot,[(toe*.065,-.04,0),(toe*.085,-.22,-.035),(toe*.055,-.27,.035)],[.042,.031,.016],'bone',6)
 r.joint('FrontNeck','LowThorax',(0,-.65,.04),(d['head'],0,0))
 r.carapace('Deep carrion snout housing','FrontNeck',(0,-.16,.015),.28,.57,.24,'bone',highlight='bone_light')
 r.box('Mouth deep socket backing','FrontNeck',(0,-.40,-.045),(.32,.11,.19),'socket',.015)
 for side in (-1,1):
  r.tube('Swept load brow_%s'%side,'FrontNeck',[(side*.12,.02,.17),(side*.30,-.16,.31),(side*.31,-.44,.16)],[.10,.085,.055],'bone',8)
  r.egg('Amber scavenging sensor_%s'%side,'FrontNeck',(side*.21,-.40,.10),(.055,.045,.047),'amber',8,4)
  r.joint('ScavengerJaw_%s'%side,'FrontNeck',(side*.19,-.28,-.13),(0,side*d['jaw'],side*.08))
  r.tube('Persistent grasping mandible_%s'%side,'ScavengerJaw_%s'%side,[(0,0,0),(side*.18,-.20,-.04),(side*.15,-.42,.08),(0,-.46,.18)],[.10,.085,.06,.025],'bone',8)
  r.box('Fixed physical shearing shoe_%s'%side,'ScavengerJaw_%s'%side,(side*.14,-.25,-.02),(.18,.22,.16) if side<0 else (.12,.18,.13),'iron',.025,highlight='steel')
 r.ground();return r

def brute(pose):
 d=BRUTE[pose];r=Rig('brute',pose)
 r.joint('GroundRoot',rotation=(.12 if pose=='dead' else d['fall'],1.52 if pose=='dead' else 0,d['twist']))
 r.joint('Pelvis','GroundRoot',(0,d['y']+.08,d['pelvisz']),(0,0,d['twist']*.25))
 r.egg('Deep load bearing pelvic wedge','Pelvis',(0,.10,0),(.51,.48,.32),'tendon',highlight='tendon_light')
 r.carapace('Solid rear pelvic haunch','Pelvis',(0,.28,.06),.47,.68,.27,'iron',highlight='steel')
 r.joint('RamThorax','Pelvis',(0,-.05,.63),(d['lean'],0,0))
 r.egg('Deep pitched continuous thoracic muscle','RamThorax',(0,-.02,.08),(.68,.65,.62),'tendon',highlight='tendon_light')
 r.carapace('Full posterior scapular saddle','RamThorax',(0,.35,.24),.71,.94,.48,'iron',highlight='steel')
 for side in (-1,1):
  r.carapace('Solid forward load shoulder_%s'%side,'RamThorax',(side*.60,-.08,.41),.36 if side<0 else .31,1.02,.31,'bone',highlight='bone_light')
  r.tube('Large thoracic return rib_%s'%side,'RamThorax',[(side*.18,-.49,.49),(side*.56,-.60,.23),(side*.60,-.50,-.19),(side*.23,-.45,-.43)],[.12,.135,.125,.09],'bone',8)
  r.egg('Deep posterior tendon reservoir_%s'%side,'RamThorax',(side*.32,.68,.11),(.24,.29,.43),'tendon')
  r.box('Posterior solid carrier_%s'%side,'RamThorax',(side*.32,.84,.10),(.26,.20,.57),'iron',.045,highlight='steel')
  # Fore/aft split supports are physical, never a view-selected limb swap.
  foot_y=(-.46 if side>0 else .48)+d['stride']*side
  if pose=='attack':foot_y=-.77 if side>0 else .66
  if pose=='dead':foot_y=-.31 if side>0 else .28
  target=(side*.43,foot_y,.13+(.07 if d['stride']*side>0 else 0))
  pole=(side*.53,-.62 if side>0 else .18,.62)
  a,b,end,foot=limb(r,'Braced hindquarter_%s'%side,'Pelvis',(side*.37,.06,-.06),target,pole,(.72,.80),.235,'tendon')
  r.box('Broad planted hoof_%s'%side,foot,(0,-.06,-.035),(.43,.55,.23),'iron',.065,highlight='steel')
  r.box('Hoof ivory load toe_%s'%side,foot,(0,-.15,.045),(.33,.37,.12),'bone',.04,highlight='bone_light')
  hand=(side*.92,-.99 if side<0 else -.58,1.20 if side<0 else 1.30)
  if pose=='attack':hand=(side*.80,-1.30 if side<0 else -.94,.63 if side<0 else 1.57)
  if pose.startswith('walk'):hand=(hand[0],hand[1]+d['stride']*side*.7,hand[2]+d['stride']*side*.3)
  if pose=='dead':hand=(side*.72,-.63,.74 if side<0 else .92)
  elbow=(side*1.15,-.28,1.55 if pose!='attack' else 1.30)
  if pose=='dead':elbow=(side*.30,-1.0,1.25)
  a,b,end,wrist=limb(r,'Ram arm_%s'%side,'RamThorax',(side*.70,-.13,.33),hand,elbow,(.72,.90),.25 if side<0 else .21,'tendon')
  if side<0:
   # Physical -X ownership never changes. Forward volume clears far-side torso.
   r.box('Persistent -X deep hammer body',wrist,(0,-.06,0),(.65,.72,.66),'iron',.085,highlight='steel')
   r.box('Ivory forward hammer striking face',wrist,(0,-.37,.015),(.55,.20,.61),'bone',.06,highlight='bone_light')
   r.box('Attached hammer dorsal knuckle',wrist,(0,.13,.28),(.44,.34,.20),'bone',.055,highlight='bone_light')
  else:
   r.box('Counterhand load palm',wrist,(0,-.03,0),(.30,.29,.26),'iron',.035,highlight='steel')
   for finger in (-1,0,1):r.tube('Counterhand hooked finger_%s'%finger,wrist,[(finger*.09,-.10,-.03),(finger*.12,-.31,-.08),(finger*.10,-.38,.08)],[.055,.044,.025],'bone',6)
 r.joint('RamNeck','RamThorax',(0,-.44,.68),(d['head'],0,0))
 r.carapace('Deep lowered ram head','RamNeck',(0,-.18,0),.34,.76,.28,'bone',highlight='bone_light')
 r.box('Ram face deep recess','RamNeck',(0,-.52,-.045),(.31,.11,.20),'socket',.025)
 r.box('Massive forward iron brow','RamNeck',(0,-.42,.18),(.55,.33,.20),'iron',.05,highlight='steel')
 for side in (-1,1):
  r.tube('Swept solid ram crown_%s'%side,'RamNeck',[(side*.21,.11,.17),(side*.44,.17,.40),(side*.47,-.12,.66),(side*.34,-.43,.51)],[.15,.12,.09,.045],'bone',8)
  r.egg('Deep amber slit_%s'%side,'RamNeck',(side*.16,-.53,.055),(.045,.04,.04),'amber',8,4)
 r.joint('LowerRamJaw','RamNeck',(0,-.36,-.15),(d['jaw'],0,0))
 r.box('Hinged reinforced ram jaw','LowerRamJaw',(0,-.16,-.035),(.40,.42,.19),'bone',.055,highlight='bone_light')
 r.ground();return r

def build(role,pose):
 assert role in SPEC and pose in POSES
 return (crawler if role=='crawler' else brute)(pose)
