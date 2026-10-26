"""Avatar v05 shared raised ritual-casting pose only; accepted Warden v04 frozen.
Pure geometry at import; Blender only in main.

NO native job is authorized by this file. Default source mode renders zero cells.
Proof/selected mode is fixed Workbench studio; legacy_cycles requires a second
explicit heavy-render grant. Neither authoring rig substitutes for Level lighting.
"""
import argparse
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

OWNED = pathlib.Path(__file__).resolve().parent
REFERENCE = OWNED / 'actor-animation-reference-v2.png'
REFERENCE_SHA = 'c2a9b71f2b6c005be50e1797e428138e2872e2708c886b79aca96148ccd5e6ca'
POSES = ('idle', 'walk_a', 'walk_b', 'attack', 'dead')
ASSETS = ('nursery_warden', 'choir_avatar')
CELL, COLUMNS, ROWS = 256, 8, 5
ANCHOR, FOOT_Y = (128, 248), 247
SPECS = {'nursery_warden': {'ortho': 7.3, 'aim': 2.8}, 'choir_avatar': {'ortho': 7.6, 'aim': 2.8}}
PALETTE = {
 'ivory': ('Load-bearing weathered ceramic', (.72,.58,.39,1)),
 'edge': ('Broad worn ivory faces', (.88,.76,.55,1)),
 'iron': ('Petrol cast pressure structure', (.13,.21,.22,1)),
 'steel': ('Worn surgical joint steel', (.30,.39,.39,1)),
 'bronze': ('Restrained aged restraint bronze', (.53,.34,.13,1)),
 'flesh': ('Living burgundy membrane', (.27,.10,.085,1)),
 'scar': ('Taut scar cartilage', (.48,.24,.16,1)),
 'socket': ('Opaque recessed interior', (.045,.042,.038,1)),
 'amber': ('Contained pressure tissue, no emission', (.88,.42,.055,1)),
}
IDENTITY = ((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1))
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return mul(a,1/math.sqrt(dot(a,a)))
def mm(a,b):return tuple(tuple(sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)) for i in range(4))
def translation(p):return ((1,0,0,p[0]),(0,1,0,p[1]),(0,0,1,p[2]),(0,0,0,1))
def rotation(axis,angle):
 c,s=math.cos(angle),math.sin(angle)
 if axis=='X':return ((1,0,0,0),(0,c,-s,0),(0,s,c,0),(0,0,0,1))
 if axis=='Y':return ((c,0,s,0),(0,1,0,0),(-s,0,c,0),(0,0,0,1))
 return ((c,-s,0,0),(s,c,0,0),(0,0,1,0),(0,0,0,1))
def transform(m,p):return tuple(sum(m[i][j]*p[j] for j in range(3))+m[i][3] for i in range(3))
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()

class Model:
 """Editable rigid-joint hierarchy plus original closed mesh components.

 Geometry remains local to named pivots. Poses rotate joints, never scale bodies.
 Static evaluated vertices use exactly the same transforms as Blender parents.
 """
 def __init__(self,asset,pose):
  self.asset,self.pose=asset,pose;self.joints={};self.parts=[]
  self.joint('GroundRoot',(0,0,0))
 def joint(self,name,at,parent='GroundRoot'):
  if name=='GroundRoot':parent=None
  assert name not in self.joints
  offset=sub(at,self.joints[parent]['rest']) if parent else at
  self.joints[name]={'rest':at,'parent':parent,'offset':offset,'angles':(0,0,0)}
  return name
 def turn(self,name,angles):self.joints[name]['angles']=angles
 def matrix(self,name):
  j=self.joints[name];rx,ry,rz=j['angles']
  local=mm(translation(j['offset']),mm(rotation('Z',rz),mm(rotation('Y',ry),rotation('X',rx))))
  return mm(self.matrix(j['parent']),local) if j['parent'] else local
 def mesh(self,name,vertices,faces,material,assembly,joint='GroundRoot'):
  assert material in PALETTE and all(len(f)>=3 for f in faces)
  center=self.joints[joint]['rest']
  self.parts.append({'name':name,'vertices':[sub(v,center) for v in vertices], 'faces':[tuple(f) for f in faces], 'material':material,'assembly':assembly,'joint':joint})
 def box(self,name,p,size,material,assembly,joint='GroundRoot'):
  v=[add(p,(x*size[0]/2,y*size[1]/2,z*size[2]/2)) for x,y,z in ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))]
  self.mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material,assembly,joint)
 def plate(self,name,outline,y,depth,material,assembly,joint='GroundRoot'):
  # Genuine extruded broad load plane, not a camera-facing image card.
  if sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))<0:outline=list(reversed(outline))
  n=len(outline);v=[(x,y+d,z) for d in (0,depth) for x,z in outline]
  faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)]
  self.mesh(name,v,faces,material,assembly,joint)
 def egg(self,name,p,size,material,assembly,joint='GroundRoot',sides=12,rings=6):
  # Closed faceted ellipsoid; unique poles avoid zero-area cap quads.
  v=[add(p,(0,0,-size[2]))]
  for r in range(1,rings):
   lat=-math.pi/2+r*math.pi/rings
   for i in range(sides):
    a=i*math.tau/sides;v.append(add(p,(size[0]*math.cos(lat)*math.cos(a),size[1]*math.cos(lat)*math.sin(a),size[2]*math.sin(lat))))
  top=len(v);v.append(add(p,(0,0,size[2])));f=[]
  for i in range(sides):f.append((0,1+(i+1)%sides,1+i))
  for r in range(rings-2):
   a=1+r*sides;b=a+sides
   for i in range(sides):j=(i+1)%sides;f.append((a+i,a+j,b+j,b+i))
  a=1+(rings-2)*sides
  for i in range(sides):f.append((a+i,a+(i+1)%sides,top))
  self.mesh(name,v,f,material,assembly,joint)
 def tube(self,name,points,radii,material,assembly,joint='GroundRoot',sides=8):
  r=[radii]*len(points) if isinstance(radii,(int,float)) else radii;v=[];f=[]
  for i,p in enumerate(points):
   tangent=norm(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]));u=norm(cross(tangent,(0,0,1) if abs(tangent[2])<.9 else (1,0,0)));w=cross(tangent,u)
   for j in range(sides):
    a=j*math.tau/sides;v.append(add(p,add(mul(u,r[i]*math.cos(a)),mul(w,r[i]*math.sin(a)))))
   if i:
    for j in range(sides):a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides;f.append((a,b,b+sides,a+sides))
  f += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
  self.mesh(name,v,f,material,assembly,joint)
 def mouth(self,name,p,width,height,depth,joint,assembly='Living throat chambers'):
  # Closed annular multi-section shell. Through-recess and rear cavity are real.
  profile=[(1,0),(.94,-.16),(.67,-.22),(.55,.07),(.53,depth),(.83,depth),(1,0)]
  n=16;v=[]
  for scale,y in profile[:-1]:
   for i in range(n):
    a=i*math.tau/n;v.append(add(p,(width*scale*math.cos(a),y,height*scale*math.sin(a))))
  f=[(r*n+i,r*n+(i+1)%n,((r+1)%6)*n+(i+1)%n,((r+1)%6)*n+i) for r in range(6) for i in range(n)]
  self.mesh(name+' thick ossified rim',v,f,'edge',assembly,joint)
  self.egg(name+' deep burgundy living chamber',add(p,(0,depth*.73,0)),(width*.67,depth*.47,height*.67),'flesh',assembly,joint)
  self.egg(name+' opaque throat opening',add(p,(0,depth*.25,0)),(width*.40,.045,height*.48),'socket',assembly,joint)
 def evaluated(self):
  return [(p,[transform(self.matrix(p['joint']),v) for v in p['vertices']]) for p in self.parts]
 def settle(self,grounded=True):
  vertices=[v for p,vs in self.evaluated() for v in vs]
  lo=[min(v[i] for v in vertices) for i in range(3)];hi=[max(v[i] for v in vertices) for i in range(3)]
  # Physical grounded rest, not image crop/camera/scale adjustment.
  delta=(-(lo[0]+hi[0])/2 if self.pose=='dead' else 0,-(lo[1]+hi[1])/2 if self.pose=='dead' else 0,-lo[2]+(0 if grounded else .38))
  self.joints['GroundRoot']['offset']=add(self.joints['GroundRoot']['offset'],delta)
 def bounds(self):
  v=[v for p,vs in self.evaluated() for v in vs]
  return {'min':[min(p[i] for p in v) for i in range(3)],'max':[max(p[i] for p in v) for i in range(3)]}

def cast_link(m,name,a,b,width,depth,material,assembly,joint,curve=(0,0,0)):
 """Closed chamfered cast/organic load volume, not a thin bar or plane."""
 axis=norm(sub(b,a));reference=(0,1,0) if abs(axis[1])<.9 else (0,0,1)
 u=norm(cross(reference,axis));v=cross(axis,u)
 contour=((-0.7,-1),(.7,-1),(1,-.7),(1,.7),(.7,1),(-.7,1),(-1,.7),(-1,-.7))
 vertices=[];faces=[]
 for n,(t,factor) in enumerate(((0,.62),(.18,.94),(.49,1),(.81,.87),(1,.57))):
  center=add(add(a,mul(sub(b,a),t)),mul(curve,math.sin(math.pi*t)))
  for x,y in contour:vertices.append(add(center,add(mul(u,x*width*factor),mul(v,y*depth*factor))))
  if n:
   for i in range(8):j=(i+1)%8;faces.append(((n-1)*8+i,(n-1)*8+j,n*8+j,n*8+i))
 faces += [tuple(reversed(range(8))),tuple(range(32,40))]
 m.mesh(name,vertices,faces,material,assembly,joint)

def throat_chamber(m,name,p,width,height,depth,joint,assembly='Living throat chambers'):
 """A deep asymmetric larynx with a folded open aperture and living cavity.
 Exterior chamber, real recessed passage and inner organ are connected volumes;
 no flat socket disk, smooth circular badge or image plane stands in for anatomy.
 """
 outline=((-0.45,-1),(.36,-.88),(.68,-.25),(.56,.61),(.08,1),(-.51,.78),(-.70,.02),(-.61,-.66))
 profile=((1.10,1.03,depth), (1.16,1.05,0),(.75,.77,-.10),(.57,.65,depth*.74))
 vertices=[add(p,(x*width*sx,y,z*height*sz)) for sx,sz,y in profile for x,z in outline]
 faces=[(r*8+i,r*8+(i+1)%8,((r+1)%4)*8+(i+1)%8,((r+1)%4)*8+i) for r in range(4) for i in range(8)]
 # This closed profile follows the opposite rim travel from the old round mouth.
 m.mesh(name+' folded laryngeal walls',vertices,faces,'scar',assembly,joint)
 m.egg(name+' deep exposed throat tissue',add(p,(0,depth*.56,0)),(width*.48,depth*.16,height*.57),'flesh',assembly,joint)
 m.egg(name+' longitudinal deep throat slit',add(p,(0,depth*.32,0)),(width*.17,.04,height*.41),'socket',assembly,joint)
 # The upper cheek and lower mandible are large cast planes, not a circular ring.
 m.tube(name+' ossified upper cheek', [add(p,(-width*.58,-.03,height*.38)),add(p,(-width*.30,-.06,height*.90)),add(p,(width*.06,-.03,height))],[width*.15,width*.19,width*.12],'ivory',assembly,joint)

def rotation_transpose(m):
 return tuple(tuple(m[j][i] if i<3 and j<3 else 1 if i==j else 0 for j in range(4)) for i in range(4))
def rotation_between(a,b):
 a,b=norm(a),norm(b);v=cross(a,b);c=max(-1,min(1,dot(a,b)))
 if c<-.999999:
  axis=norm(cross(a,(1,0,0) if abs(a[0])<.8 else (0,1,0)))
  r=tuple(tuple(2*axis[i]*axis[j]-(1 if i==j else 0) for j in range(3)) for i in range(3))
 else:
  k=((0,-v[2],v[1]),(v[2],0,-v[0]),(-v[1],v[0],0))
  r=tuple(tuple((1 if i==j else 0)+k[i][j]+sum(k[i][q]*k[q][j] for q in range(3))/(1+c) for j in range(3)) for i in range(3))
 return tuple(tuple(r[i][j] if i<3 and j<3 else 1 if i==j else 0 for j in range(4)) for i in range(4))
def euler_xyz(m):
 ry=math.asin(max(-1,min(1,-m[2][0])))
 if abs(math.cos(ry))<1e-8:return (0,ry,math.atan2(-m[0][1],m[1][1]))
 return (math.atan2(m[2][1],m[2][2]),ry,math.atan2(m[1][0],m[0][0]))
def plant_tripod_leg(m,index,target):
 """Exact rigid two-link IK; body pitches/crouches while all pressure shoes plant.
 The actual rest lengths and joint surfaces are unchanged across live poses.
 """
 h,k,a=('Tripod_hip_%s'%index,'Tripod_knee_%s'%index,'Tripod_ankle_%s'%index)
 hip=transform(m.matrix(h),(0,0,0));upper=sub(m.joints[k]['rest'],m.joints[h]['rest']);lower=sub(m.joints[a]['rest'],m.joints[k]['rest']);l1=math.sqrt(dot(upper,upper));l2=math.sqrt(dot(lower,lower));delta=sub(target,hip);distance=math.sqrt(dot(delta,delta))
 assert abs(l1-l2)+1e-5<distance<l1+l2-1e-5,('Rigid leg target unreachable',index,distance,l1,l2)
 axis=norm(delta);pole=((-.25 if index==0 else .25 if index==1 else 0),-1,.10)
 outward=norm(sub(pole,mul(axis,dot(pole,axis))));along=(l1*l1+distance*distance-l2*l2)/(2*distance);knee=add(hip,add(mul(axis,along),mul(outward,math.sqrt(max(0,l1*l1-along*along)))))
 world_upper=rotation_between(upper,sub(knee,hip));parent_rotation=m.matrix(m.joints[h]['parent']);m.turn(h,euler_xyz(mm(rotation_transpose(parent_rotation),world_upper)))
 world_lower=rotation_between(lower,sub(target,knee));m.turn(k,euler_xyz(mm(rotation_transpose(world_upper),world_lower)));m.turn(a,euler_xyz(rotation_transpose(world_lower)))
 for axis_number in range(3):assert abs(transform(m.matrix(a),(0,0,0))[axis_number]-target[axis_number])<1e-8

def warden(pose):
 m=Model('nursery_warden',pose);body=m.joint('Incubator_gimbal',(0,0,2.35))
 m.egg('Heavy lower pressure cradle',(0,.10,2.40),(1.28,.91,.59),'iron','Pelvic incubation manifold',body)
 m.egg('Low living pelvic pressure saddle',(0,-.03,2.35),(1.19,.88,.60),'flesh','Pelvic incubation manifold',body)
 cast_link(m,'Deep posterior incubation counter-chamber',(0,.73,2.29),(0,.79,4.07),.92,.79,'flesh','Dorsal pressure keel',body,curve=(.09,.12,0))
 for side in (-1,1):
  cast_link(m,'Curved posterior load shell_'+str(side),(side*.74,.99,2.27),(side*.69,1.03,4.17),.29,.48,'iron','Dorsal pressure keel',body,curve=(side*.14,.13,0))
  cast_link(m,'Hip-to-rib curved load buttress_'+str(side),(side*.88,.52,2.19),(side*1.19,.48,3.94),.31,.44,'ivory','Pelvic incubation manifold',body,curve=(side*.16,.16,0))
 m.egg('Deep load-bearing gestational abdomen',(0,.12,3.25),(1.24,1.02,1.29),'flesh','Incubator living cavity',body)
 m.mouth('Deep protected incubation receiver',(0,-.89,3.28),.88,1.03,.78,body,'Incubator living cavity')
 m.plate('Broad sternum receiver',[(-.35,2.75),(.42,2.75),(.51,4.60),(.18,5.08),(-.28,4.76)],.43,.34,'iron','Dorsal pressure keel',body)
 m.egg('Broad contained living gestational organism',(.06,-.86,3.25),(.52,.28,.79),'scar','Incubator living cavity',body)
 m.egg('Recessed organism pressure node',(.12,-1.05,3.30),(.28,.13,.43),'amber','Incubator living cavity',body)
 for side in (-1,1):
  rib=m.joint('Costal_hinge_'+str(side),(side*.63,.32,3.65),body)
  # Broad solid shell leaves carry the chamber load; original ribs are now
  # secondary structural returns, not the primary striped front silhouette.
  m.plate('Deep load-bearing abdominal shell_'+str(side),[(side*.65,2.10),(side*1.20,2.25),(side*1.42,3.10),(side*1.27,4.12),(side*.62,4.56),(side*.72,3.61)],-.55,1.05,'ivory','Articulated rib cradle',rib)
  m.egg('Solid shoulder-to-abdomen pressure haunch_'+str(side),(side*1.06,.17,3.98),(.56,.70,.65),'iron','Unequal shoulder gestation cages',body)
  for i,z in enumerate((2.91,3.34,3.77,4.20,4.61)):
   x=side*(.77 if i in (0,4) else 1.0)
   m.tube('Thick continuous costal arch_%s_%s'%(side,i),[(side*.17,.53,z),(x,.25,z+.12),(x,-.45,z+.05),(side*.49,-.81,z-.12)],[.17,.18,.15,.10],'ivory','Articulated rib cradle',rib,8)
  m.tube('Shoulder cage yoke_'+str(side),[(side*.46,.10,4.37),(side*1.07,.17,4.68),(side*1.38,.13,4.69)],.34,'iron','Unequal shoulder gestation cages',body)
  radius=.68 if side<0 else .52;cz=4.65 if side<0 else 4.46;cx=side*1.39
  m.egg('Unequal enclosed shoulder seed_'+str(side),(cx,.13,cz),(radius*.92,.57,.71),'flesh','Unequal shoulder gestation cages',body)
  for i in range(4):
   a=i*math.pi/2;x=math.cos(a)*radius;y=math.sin(a)*.49
   m.tube('Shoulder cage structural stave_%s_%s'%(side,i),[(cx,.13,cz-.76),(cx+x,.13+y,cz-.42),(cx+x,.13+y,cz+.44),(cx,.13,cz+.77)],.17,'edge','Unequal shoulder gestation cages',body)
  m.plate('Broad shoulder canopy_'+str(side),[(cx-radius,cz+.22),(cx+radius,cz+.23),(cx+radius*.66,cz+.87),(cx-radius*.35,cz+.98)],-.34,.96,'ivory','Unequal shoulder gestation cages',body)
  m.tube('Large posterior return_'+str(side),[(side*.41,.49,4.42),(side*.78,.88,4.09),(side*.74,.94,3.19),(side*.43,.43,2.42)],.17,'flesh','Dorsal pressure keel',body)
 for i,(x,y) in enumerate(((-.78,-.31),(.78,-.31),(.10,.67))):
  hip=(x,y,2.35);knee=(x*1.52,-.82 if i<2 else 1.39,1.25);ankle=(x*1.82,-.18 if i<2 else 1.73,.27)
  h=m.joint('Tripod_hip_%s'%i,hip,body);k=m.joint('Tripod_knee_%s'%i,knee,h);a=m.joint('Tripod_ankle_%s'%i,ankle,k)
  m.egg('Tripod load socket_%s'%i,hip,(.43,.42,.42),'steel','Heavy walking tripod',h)
  cast_link(m,'Curved living load thigh_%s'%i,hip,knee,.43,.42,'flesh','Heavy walking tripod',h,curve=(x*.10,-.16,0))
  m.tube('Broad upper splint_%s'%i,[add(hip,(0,-.19,.02)),add(knee,(0,-.19,.02))],[.34,.31],'ivory','Heavy walking tripod',h)
  m.egg('Large knee drum_%s'%i,knee,(.42,.39,.36),'iron','Heavy walking tripod',k)
  cast_link(m,'Curved solid shin carrier_%s'%i,knee,ankle,.35,.34,'iron','Heavy walking tripod',k,curve=(0,.15,-.06))
  m.tube('Broad shin ceramic_%s'%i,[add(knee,(0,-.20,-.10)),add(ankle,(0,-.20,.12))],[.27,.22],'edge','Heavy walking tripod',k)
  m.box('Planted tripod pressure shoe_%s'%i,add(ankle,(0,-.18,-.13)),(.73,.92,.28),'iron','Heavy walking tripod',a)
  m.box('Surgical toe apron_%s'%i,add(ankle,(0,-.43,-.035)),(.66,.35,.23),'ivory','Heavy walking tripod',a)
 for side in (-1,1):
  shoulder=(side*1.05,.01,3.97);elbow=(side*1.69,-.06,3.15);wrist=(side*1.92,-.39,2.45)
  s=m.joint('Arm_shoulder_'+str(side),shoulder,body);e=m.joint('Arm_elbow_'+str(side),elbow,s);w=m.joint('Tool_wrist_'+str(side),wrist,e)
  m.egg('Arm shoulder pressure bearing_'+str(side),shoulder,(.48,.47,.46),'iron','Asymmetric working arms',s)
  m.tube('Heavy shoulder actuator_'+str(side),[shoulder,elbow],[.43,.38],'flesh','Asymmetric working arms',s)
  m.tube('Broad arm protection_'+str(side),[add(shoulder,(0,-.22,0)),add(elbow,(0,-.22,.05))],[.35,.31],'ivory','Asymmetric working arms',s)
  m.egg('Large elbow bearing_'+str(side),elbow,(.39,.40,.37),'steel','Asymmetric working arms',e)
  m.tube('Clamp ram' if side<0 else 'Root nozzle pressure arm',[elbow,wrist],[.37,.42 if side>0 else .35],'iron','Asymmetric working arms',e)
  if side<0:
   m.egg('Broad pruning clamp receiver',wrist,(.53,.47,.43),'bronze','Pruning clamp',w)
   for jaw in (-1,1):
    j=m.joint('Pruning_jaw_'+str(jaw),add(wrist,(jaw*.22,0,0)),w)
    outline=[(wrist[0]+jaw*.13,2.66),(wrist[0]+jaw*.58,2.23),(wrist[0]+jaw*.50,1.42),(wrist[0]+jaw*.07,1.68),(wrist[0]+jaw*.24,2.14)]
    m.plate('Broad hooked pruning jaw_'+str(jaw),outline,-.79,.66,'edge','Pruning clamp',j)
  else:
   m.mouth('Large attached root-nozzle',wrist,.57,.61,.74,w,'Root nozzle organ')
   for i in (-1,0,1):
    m.tube('Root nozzle living digit_'+str(i),[add(wrist,(i*.15,.15,-.15)),(wrist[0]+i*.23,-.49,1.93),(wrist[0]+i*.26,-.78,1.76+abs(i)*.15)],[.19,.16,.11],'flesh','Root nozzle organ',w)
 m.mouth('Small regulator face',(0,-.36,4.93),.26,.37,.37,body,'Regulator head')
 if pose=='walk_a' or pose=='walk_b':
  sign=1 if pose=='walk_a' else -1
  m.turn(body,(.025,sign*.035,0))
  for i in range(3):m.turn('Tripod_hip_%s'%i,(sign*(.12 if i==0 else -.10 if i==1 else .055),0,0));m.turn('Tripod_knee_%s'%i,(-sign*(.10 if i==0 else -.08),0,0))
  m.turn('Arm_shoulder_-1',(sign*.10,0,-sign*.025));m.turn('Arm_elbow_1',(-sign*.10,0,0))
 if pose=='attack':
  m.turn(body,(.34,0,0));m.joints[body]['offset']=add(m.joints[body]['offset'],(0,-.18,-.32));m.turn('Arm_shoulder_-1',(-.39,0,-.10));m.turn('Arm_elbow_-1',(-.30,0,0));m.turn('Arm_shoulder_1',(-.46,0,.08));m.turn('Arm_elbow_1',(-.28,0,0))
  for side in (-1,1):m.turn('Costal_hinge_'+str(side),(0,0,side*-.11));m.turn('Pruning_jaw_'+str(side),(0,side*-.32,0))
 if pose=='dead':
  m.turn(body,(.12,0,.07))
  for i in range(3):m.turn('Tripod_hip_%s'%i,(.48 if i<2 else -.50,0,(-.25 if i==0 else .25 if i==1 else 0)));m.turn('Tripod_knee_%s'%i,(-.80,0,0))
  m.turn('Arm_shoulder_-1',(.36,0,-.25));m.turn('Arm_elbow_-1',(-.75,0,0));m.turn('Arm_shoulder_1',(.20,0,.22));m.turn('Arm_elbow_1',(-.6,0,0));m.turn('GroundRoot',(1.50,0,.18))
 if pose!='dead':
  # Fore/aft ground reaction is authored in world coordinates, not a Z squash.
  # The heavy chamber moves as one rigid pitched body; two-link legs brace it.
  if pose=='attack':targets=((-1.42,-.94,.27),(1.42,-.56,.27),(.10,1.66,.27))
  elif pose=='walk_a':targets=((-1.42,-.52,.27),(1.42,.10,.34),(.10,1.63,.27))
  elif pose=='walk_b':targets=((-1.42,.10,.34),(1.42,-.52,.27),(.10,1.63,.27))
  else:targets=((-1.42,-.18,.27),(1.42,-.18,.27),(.10,1.73,.27))
  for index,target in enumerate(targets):plant_tripod_leg(m,index,target)
 m.settle();return m

def avatar(pose):
 m=Model('choir_avatar',pose);body=m.joint('Reliquary_suspension',(0,.10,3.10))
 m.egg('Deep living laryngeal trunk',(0,.37,3.15),(.69,.80,1.76),'flesh','Living dorsal trunk',body)
 cast_link(m,'Continuous folded throat-to-crown load chamber',(0,.24,1.48),(0,.29,5.08),.50,.67,'iron','Living dorsal trunk',body,curve=(.10,0,0))
 m.plate('Deep dorsal ossified keel',[(-.27,1.25),(.35,1.38),(.46,4.76),(.13,5.34),(-.32,4.72)],.78,.36,'iron','Living dorsal trunk',body)
 for i,z in enumerate((1.74,2.43,3.12,3.81,4.50)):
  m.plate('Broad posterior vertebral saddle_%s'%i,[(-.47,z-.18),(.49,z-.18),(.57,z+.18),(-.38,z+.29)],.98,.30,'ivory','Living dorsal trunk',body)
 for side in (-1,1):
  j=m.joint('Mantle_hinge_'+str(side),(side*.35,.14,3.65),body)
  # Three separated, deeply folded protective leaves expose the living trunk.
  # Unlike the earlier single broad shield, the mantle has real side returns.
  cast_link(m,'Upper swept mantle shell_'+str(side),(side*.29,.17,5.02),(side*.96,.28,3.61),.31,.45,'ivory','Split reliquary mantle',j,curve=(side*.19,.08,0))
  cast_link(m,'Lower swept mantle shell_'+str(side),(side*.97,.27,3.51),(side*.35,.17,1.09),.29,.48,'edge','Split reliquary mantle',j,curve=(side*.20,.04,0))
  cast_link(m,'Deep posterior mantle return_'+str(side),(side*.44,.71,4.64),(side*.57,.77,1.75),.23,.39,'iron','Split reliquary mantle',j,curve=(side*.15,.12,0))
  cast_link(m,'Exposed mantle pressure muscle_'+str(side),(side*.35,-.20,4.73),(side*.50,-.17,1.65),.20,.26,'flesh','Split reliquary mantle',j,curve=(side*.31,-.08,0))
  m.tube('Connected dorsal pressure return_'+str(side),[(side*.20,.70,4.52),(side*.75,.73,3.65),(side*.65,.76,2.13),(side*.15,.43,1.56)],.14,'flesh','Living dorsal trunk',body)
 # Five physically connected many-throated chambers, not a flat halo of dots.
 for i,(x,z,w,h) in enumerate(((0,4.37,.53,.60),(-.08,3.15,.63,.66),(.04,1.97,.48,.53),(-.91,3.98,.40,.50),(.91,3.98,.40,.50))):
  j=m.joint('Throat_gimbal_%s'%i,(x,.0,z),body)
  cast_link(m,'Substantial living throat supply neck_%s'%i,(x*.43,.39,z-.31),(x,-.38,z),.25,.30,'flesh','Living throat chambers',j,curve=(0,-.10,.11))
  throat_chamber(m,'Independent pressure throat_%s'%i,(x,-.79,z),w,h,.93,j)
  lip=m.joint('Throat_lower_jaw_%s'%i,(x,-.69,z-h*.76),j)
  cast_link(m,'Throat lower articulated mandible_%s'%i,(x-w*.48,-.82,z-h*.63),(x+w*.40,-.82,z-h*.73),.17,.20,'ivory','Living throat chambers',lip,curve=(0,-.08,-.10))
 # Exposed large channels actually bridge the five chambers in front of armor.
 for side in (-1,1):
  cast_link(m,'Branching throat pressure channel_'+str(side),(side*.91,-.25,4.18),(side*.21,-.35,2.40),.19,.26,'scar','Living throat chambers',body,curve=(side*.17,-.13,0))
 for side in (-1,1):
  shoulder=(side*.69,.25,4.35);elbow=(side*1.29,.26,3.76);wrist=(side*1.81,.17,3.61)
  s=m.joint('Cantor_shoulder_'+str(side),shoulder,body);e=m.joint('Cantor_elbow_'+str(side),elbow,s);w=m.joint('Censer_wrist_'+str(side),wrist,e)
  m.egg('Cantor shoulder ball_'+str(side),shoulder,(.43,.46,.42),'bronze','Articulated cantor arms',s)
  cast_link(m,'Cantor muscular pressure shoulder_'+str(side),shoulder,elbow,.33,.36,'flesh','Articulated cantor arms',s,curve=(0,-.10,.10))
  m.tube('Cantor ivory upper rail_'+str(side),[add(shoulder,(0,-.18,0)),add(elbow,(0,-.18,0))],[.23,.19],'ivory','Articulated cantor arms',s)
  m.egg('Cantor elbow bearing_'+str(side),elbow,(.30,.35,.31),'steel','Articulated cantor arms',e)
  cast_link(m,'Cantor deep vocal carrier forearm_'+str(side),elbow,wrist,.32,.39,'iron','Articulated cantor arms',e,curve=(0,-.14,.13))
  m.plate('Solid layered forearm fin_'+str(side),[(side*1.16,3.73),(side*1.84,3.48),(side*1.68,4.22),(side*1.27,4.13)],-.09,.52,'ivory','Articulated cantor arms',e)
  m.tube('Attached suspended censer stem_'+str(side),[wrist,add(wrist,(0,0,-.60))],.20,'bronze','Suspended cantor instruments',w)
  throat_chamber(m,'Connected hanging cantor resonator_'+str(side),add(wrist,(0,-.18,-.72)),.45,.57,.71,w,'Suspended cantor instruments')
  # Stacked tower-spire planes with substantial volume, connected to shoulders.
  m.plate('Upper shoulder buttress_'+str(side),[(side*.34,4.40),(side*1.12,4.43),(side*1.25,4.84),(side*.69,5.17)],-.06,.83,'ivory','Spired reliquary crown',body)
  for i in range(2):
   x=side*(.64+i*.43);z=5.03-i*.18
   m.tube('Crown broad spire_'+str(side)+'_'+str(i),[(x,.28,z-.24),(x,.28,z+.45),(x,.28,z+.94)],[.20,.14,.018],'edge','Spired reliquary crown',body)
 m.tube('Central vertical reliquary spire',[(0,.24,4.85),(0,.24,5.63),(0,.24,6.27)],[.24,.17,.015],'ivory','Spired reliquary crown',body)
 for side in (-1,1):
  m.tube('Connected suspended lower nerve_'+str(side),[(side*.29,.18,2.0),(side*.65,.25,1.39),(side*.41,.28,.64),(side*.22,.27,.24)],[.18,.16,.12,.045],'flesh','Floating suspended lower anatomy',body)
 if pose in ('walk_a','walk_b'):
  sign=1 if pose=='walk_a' else -1;m.turn(body,(sign*.025,0,sign*.035))
  for side in (-1,1):m.turn('Cantor_shoulder_'+str(side),(sign*side*.13,0,sign*side*.06));m.turn('Censer_wrist_'+str(side),(-sign*side*.12,0,0));m.turn('Mantle_hinge_'+str(side),(0,side*sign*.045,0))
 if pose=='attack':
  # Shared ritual casting gesture, not a body charge or a new attack variant.
  # Raised cantor chains lift the physical resonators above the idle throatline;
  # counter-rotated wrists keep those heavy chambers largely hanging upright.
  for side in (-1,1):
   m.turn('Cantor_shoulder_'+str(side),(-.20,-side*1.15,side*.03))
   m.turn('Cantor_elbow_'+str(side),(-.15,side*.24,side*.18))
   m.turn('Censer_wrist_'+str(side),(.10,side*.91,-side*.18))
   m.turn('Mantle_hinge_'+str(side),(0,side*.18,side*.08))
  for i in range(5):m.turn('Throat_lower_jaw_%s'%i,(.95,0,0));m.turn('Throat_gimbal_%s'%i,(-.18,0,0))
 if pose=='dead':
  for side in (-1,1):m.turn('Cantor_shoulder_'+str(side),(.25,0,-side*.52));m.turn('Cantor_elbow_'+str(side),(.70,0,-side*.22));m.turn('Mantle_hinge_'+str(side),(0,-side*.20,0))
  m.turn('GroundRoot',(1.53,0,-.15))
 m.settle(grounded=pose=='dead');return m

def build_model(asset,pose):
 assert asset in ASSETS and pose in POSES
 return warden(pose) if asset=='nursery_warden' else avatar(pose)

def camera_projection(asset,direction,world):
 # Exact existing legacy boss camera orbit and orthographic world size.
 a=math.radians(direction*45);eye=(10*math.sin(a),-10*math.cos(a),3.5);aim=(0,0,SPECS[asset]['aim'])
 back=norm(sub(eye,aim));right=norm(cross((0,0,1),back));up=cross(back,right);relative=sub(world,eye)
 return (128+dot(right,relative)*256/SPECS[asset]['ortho'],128-dot(up,relative)*256/SPECS[asset]['ortho'])

def parse_cells(value):
 out=[]
 for item in value.split(','):
  bits=item.split(':')
  if len(bits)!=2 or bits[0] not in POSES or bits[1] not in tuple(str(i) for i in range(8)):raise argparse.ArgumentTypeError('Exact pose:direction, direction0..7 required')
  cell=(bits[0],int(bits[1]))
  if cell in out:raise argparse.ArgumentTypeError('Duplicate cell')
  out.append(cell)
 if not 1<=len(out)<=4:raise argparse.ArgumentTypeError('Only1..4 explicit selected cells')
 return out

def arguments(argv):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--asset',choices=ASSETS,required=True);p.add_argument('--output',type=pathlib.Path,required=True)
 p.add_argument('--mode',choices=('source','proof','selected','atlas'),default='source');p.add_argument('--cells',type=parse_cells)
 p.add_argument('--approved-directional-matrix',action='store_true');p.add_argument('--renderer',choices=('workbench','legacy_cycles'),default='workbench');p.add_argument('--approved-heavy-render',action='store_true')
 args=p.parse_args(argv);absolute=args.output.absolute()
 if any(x.is_symlink() for x in (absolute,*absolute.parents)):raise ValueError('No symlink output ancestry')
 args.output=absolute.resolve()
 if not args.output.is_relative_to(OWNED) or args.output==OWNED:raise ValueError('Only fresh owned output subfolders')
 if args.output.exists():raise FileExistsError('Never overwrite sources or proofs')
 if args.mode=='selected' and not args.cells:raise ValueError('Selected mode requires explicit1..4 cells')
 if args.mode!='selected' and args.cells:raise ValueError('Cells only valid in selected mode')
 if args.mode=='atlas' and not args.approved_directional_matrix:raise ValueError('Full40cell matrix requires parent approval')
 if args.renderer=='legacy_cycles' and not args.approved_heavy_render:raise ValueError('Cycles held behind separate heavy grant')
 if sha(REFERENCE)!=REFERENCE_SHA:raise ValueError('Selected inspected board drift')
 return args

def png(path,width,height,pixels):
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 raw=b''.join(b'\0'+bytes(pixels[y*width*4:(y+1)*width*4]) for y in range(height))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

def register_pixels(rgba):
 raw=bytearray(CELL*CELL*4)
 for y in range(CELL):
  for x in range(CELL):
   i=((CELL-1-y)*CELL+x)*4;o=(y*CELL+x)*4
   if rgba[i+3]>=.5:raw[o:o+4]=bytes([min(255,round(rgba[i+k]*31)*8) for k in range(3)]+[255])
 occupied=[(x,y) for y in range(CELL) for x in range(CELL) if raw[(y*CELL+x)*4+3]]
 if not occupied:raise ValueError('Empty frame')
 bbox=[min(x for x,y in occupied),min(y for x,y in occupied),max(x for x,y in occupied),max(y for x,y in occupied)]
 if bbox[0]<=0 or bbox[1]<=0 or bbox[2]>=255 or bbox[3]>=255:raise ValueError('Raw border touches/clips; repair geometry, never camera/scale/crop: '+repr(bbox))
 shift=FOOT_Y-bbox[3];aligned=bytearray(len(raw));clipped=0
 for y in range(CELL):
  dest=y+shift
  if 0<=dest<CELL:aligned[dest*CELL*4:(dest+1)*CELL*4]=raw[y*CELL*4:(y+1)*CELL*4]
  else:clipped+=sum(raw[(y*CELL+x)*4+3]>0 for x in range(CELL))
 if clipped or bbox[1]+shift<=0:raise ValueError('Registration clips geometry; never crop/rescale')
 final=[bbox[0],bbox[1]+shift,bbox[2],FOOT_Y]
 return aligned,{'raw_occupied_bbox':bbox,'registered_occupied_bbox':final,'vertical_registration_shift':shift,'origin_px':list(ANCHOR),'occupied_bottom':FOOT_Y,'clipped_pixels':clipped,'all_borders_clear':True}

class Exporter:
 def __init__(self,bpy,Matrix,args):self.bpy,self.Matrix,self.args=bpy,Matrix,args;self.collections={};self.models={}
 def setup(self):
  b=self.bpy;b.ops.wm.read_factory_settings(use_empty=True);b.context.preferences.filepaths.save_version=0;s=b.context.scene;self.scene=s
  s.render.engine='BLENDER_WORKBENCH' if self.args.renderer=='workbench' else 'CYCLES';s.render.threads_mode='FIXED';s.render.threads=2
  s.render.film_transparent=True;s.render.resolution_x=s.render.resolution_y=CELL;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
  s.view_settings.view_transform='Standard';s.view_settings.look='None'
  if self.args.renderer=='workbench':
   s.display.render_aa='OFF';sh=s.display.shading;sh.light='STUDIO';sh.studio_light='paint.sl';sh.color_type='MATERIAL';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.curvature_ridge_factor=1;sh.curvature_valley_factor=.65;sh.cavity_ridge_factor=1;sh.cavity_valley_factor=.65;sh.show_specular_highlight=True
  else:s.cycles.device='CPU';s.cycles.samples=16;s.cycles.use_denoising=False;s.render.filter_size=.1
  s.world=b.data.worlds.new('Petrol ambient');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.18,.2,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
  self.materials={}
  for k,(name,color) in PALETTE.items():
   mat=b.data.materials.new(name);mat.diffuse_color=color;mat.use_nodes=True;n=mat.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=color;n.inputs['Roughness'].default_value=.7;n.inputs['Metallic'].default_value=.35 if k in ('iron','steel','bronze') else 0;self.materials[k]=mat
  data=b.data.cameras.new('Fixed legacy boss camera');self.cam=b.data.objects.new('Fixed legacy boss camera',data);s.collection.objects.link(self.cam);data.type='ORTHO';data.ortho_scale=SPECS[self.args.asset]['ortho'];s.camera=self.cam
  # Unchanged inherited source light rig; never changed by pose or direction.
  from mathutils import Vector
  for name,pos,color,power,size in [('Ivory key',(-3,-5,7),(1,.83,.65),900,4),('Cold surgical rim',(4,2,6),(.36,.68,.72),1150,3),('Amber lower fill',(-3,1,2),(1,.48,.18),350,3)]:
   d=b.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size;o=b.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,2.8))-o.location).to_track_quat('-Z','Y').to_euler()
  s['reference_sha256']=REFERENCE_SHA;s['recipe_sha256']=sha(__file__);s['atlas_contract']='8directions;5poses;256cell;2048x1280;origin128,248;occupiedbottom247';s['construction']='Original closed3D volumetric meshes, rigid editable joints; no image cards';s['mechanics_changed']=False
 def pose(self,model):
  b=self.bpy;coll=b.data.collections.new('Pose_'+model.pose);self.scene.collection.children.link(coll);coll['row']=POSES.index(model.pose);self.collections[model.pose]=coll;self.models[model.pose]=model;objects={};assemblies={};materials={}
  anatomy=b.data.collections.new(model.pose+'/Anatomical assemblies');coll.children.link(anatomy);groups=b.data.collections.new(model.pose+'/Material groups');coll.children.link(groups)
  for name,j in model.joints.items():
   obj=b.data.objects.new(model.pose+'/'+name,None);coll.objects.link(obj);obj.empty_display_type='SPHERE';obj.empty_display_size=.09;obj['editable_joint']=True;objects[name]=obj
   if j['parent']:obj.parent=objects[j['parent']]
   rx,ry,rz=j['angles'];obj.matrix_basis=self.Matrix(mm(translation(j['offset']),mm(rotation('Z',rz),mm(rotation('Y',ry),rotation('X',rx)))))
  for p in model.parts:
   data=b.data.meshes.new(model.pose+'/'+p['name']);data.from_pydata(p['vertices'],[],p['faces']);data.update();obj=b.data.objects.new(model.pose+'/'+p['name'],data)
   for key,parent,destination in ((p['assembly'],anatomy,assemblies),(p['material'],groups,materials)):
    if key not in destination:c=b.data.collections.new(model.pose+'/'+key);parent.children.link(c);destination[key]=c
    destination[key].objects.link(obj)
   obj.parent=objects[p['joint']];obj.data.materials.append(self.materials[p['material']]);obj['assembly']=p['assembly'];obj['rig_joint']=p['joint'];obj['material_group']=p['material']
 def select(self,pose):
  for name,coll in self.collections.items():coll.hide_render=name!=pose;coll.hide_viewport=name!=pose
  self.bpy.context.view_layer.update()
 def direction(self,column):
  from mathutils import Vector
  a=math.radians(column*45);self.cam.location=(10*math.sin(a),-10*math.cos(a),3.5);self.cam.rotation_euler=(Vector((0,0,2.8))-self.cam.location).to_track_quat('-Z','Y').to_euler();self.bpy.context.view_layer.update()
 def actual_extrema(self,pose):
  graph=self.bpy.context.evaluated_depsgraph_get();inv=self.cam.matrix_world.inverted();extrema={};count=0;world_lo=[float('inf')]*3;world_hi=[float('-inf')]*3
  for original in self.collections[pose].all_objects:
   if original.type!='MESH':continue
   obj=original.evaluated_get(graph);mesh=obj.to_mesh()
   try:
    for vertex in mesh.vertices:
     world=obj.matrix_world@vertex.co;camera=inv@world;count+=1
     for i in range(3):world_lo[i]=min(world_lo[i],float(world[i]));world_hi[i]=max(world_hi[i],float(world[i]))
     row={'object':original.name,'world':[float(x) for x in world],'camera':[float(x) for x in camera],'raw_continuous_pixel':[128+camera.x*256/SPECS[self.args.asset]['ortho'],128-camera.y*256/SPECS[self.args.asset]['ortho']]}
     for key,axis,high in [('top',1,True),('bottom',1,False),('left',0,False),('right',0,True)]:
      if key not in extrema or (camera[axis]>extrema[key]['camera'][axis] if high else camera[axis]<extrema[key]['camera'][axis]):extrema[key]=row
   finally:obj.to_mesh_clear()
  expected=self.models[pose].bounds()
  assert count==sum(len(p['vertices']) for p in self.models[pose].parts),'Unexpected evaluated mesh vertex count'
  assert all(abs(world_lo[i]-expected['min'][i])<1e-4 and abs(world_hi[i]-expected['max'][i])<1e-4 for i in range(3)),'Blender actual world bounds diverge from rigid source transforms'
  return {'evaluated_vertex_count':count,'physical_world_bounds':{'min':world_lo,'max':world_hi},'extrema':extrema,'source_transform_parity':True,'scope':'Actual evaluated Blender world/camera vertices before raster and vertical registration'}

def main():
 args=arguments(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);recipe_pin=sha(__file__)
 import bpy
 from mathutils import Matrix
 args.output.mkdir(parents=True);e=Exporter(bpy,Matrix,args);e.setup()
 for pose in POSES:e.pose(build_model(args.asset,pose))
 e.select('idle');e.direction(0);source=args.output/(args.asset+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source),check_existing=False)
 frames=[('idle',0)] if args.mode=='proof' else args.cells if args.mode=='selected' else [(p,c) for p in POSES for c in range(8)] if args.mode=='atlas' else []
 manifest={'status':'GENERATED_SOURCE_NOT_QUALITY_APPROVED','asset':args.asset,'source':{'file':source.name,'sha256':sha(source),'bytes':source.stat().st_size},'recipe_sha256':sha(__file__),'selected_reference':{'path':str(REFERENCE),'sha256':REFERENCE_SHA,'personally_inspected':True},'poses':list(POSES),'rows':ROWS,'columns':COLUMNS,'cell_size':[CELL,CELL],'atlas_size':[2048,1280],'origin_px':list(ANCHOR),'occupied_bottom':FOOT_Y,'camera':{'ortho':SPECS[args.asset]['ortho'],'aim':[0,0,2.8],'orbit_z':3.5,'yaw_degrees':list(range(0,360,45))},'renderer':args.renderer,'native_render_count':0,'frames':[],'pose_geometry':{},'mechanics_changed':False,'variant_presentation':'Single shared attack row ONLY; charge/fan/radial and full windup/release/recovery variants NOT separately encoded','not_evidence_for':['quality acceptance','Level consumer lighting','all-frame clipping until actual40render','FPS','human play','true8K','damage regions','boss weak-point mechanics']}
 for pose,m in e.models.items():manifest['pose_geometry'][pose]={'mesh_count':len(m.parts),'joint_count':len(m.joints),'triangles':sum(len(f)-2 for p in m.parts for f in p['faces']),'physical_bounds':m.bounds()}
 path=args.output/'manifest.json'
 def checkpoint():path.write_text(json.dumps(manifest,indent=2)+'\n')
 checkpoint();cells=[]
 for pose,direction in frames:
  e.select(pose);e.direction(direction);manifest['attempting_cell']={'pose':pose,'direction':direction};checkpoint();raw=args.output/('raw-%s-%02d.png'%(pose,direction));e.scene.render.filepath=str(raw)
  try:
   extrema=e.actual_extrema(pose);manifest['attempting_cell']['actual_source_extrema']=extrema;checkpoint()
   bpy.ops.render.render(write_still=True);img=bpy.data.images.load(str(raw),check_existing=False);rgba=list(img.pixels[:]);bpy.data.images.remove(img);pixels,registration=register_pixels(rgba)
   if pose=='dead' and registration['registered_occupied_bbox'][1]<128:raise ValueError('Death has not physically collapsed below midpoint')
   out=args.output/('%s-%s-%02d.png'%(args.asset,pose,direction));png(out,CELL,CELL,pixels);cells.append(pixels)
   manifest['frames'].append({'file':out.name,'sha256':sha(out),'pose':pose,'row':POSES.index(pose),'direction':direction,'registration':registration,'actual_source_extrema':extrema});manifest['native_render_count']=len(cells);manifest.pop('attempting_cell');checkpoint()
  except BaseException as exc:manifest['status']='FRAME_FAILED_NO_CROP_OR_RESCALE';manifest['failure']={'type':type(exc).__name__,'message':str(exc)};checkpoint();raise
 if args.mode=='atlas':
  assert len(cells)==40 and len({bytes(c) for c in cells})==40,'All40 actual cells must be distinct'
  atlas=bytearray(2048*1280*4)
  for i,cell in enumerate(cells):
   row,col=divmod(i,8)
   for y in range(CELL):dest=((row*CELL+y)*2048+col*CELL)*4;atlas[dest:dest+CELL*4]=cell[y*CELL*4:(y+1)*CELL*4]
  out=args.output/(args.asset+'.png');png(out,2048,1280,atlas);assert out.stat().st_size<=2*1024*1024;manifest['atlas']={'file':out.name,'sha256':sha(out),'bytes':out.stat().st_size}
 assert sha(__file__)==recipe_pin and sha(REFERENCE)==REFERENCE_SHA,'Recipe/reference changed during native generation'
 manifest['blender_version']=bpy.app.version_string
 checkpoint();print('BOSS_BODY_DONE '+json.dumps({'asset':args.asset,'mode':args.mode,'render_count':len(frames),'source':str(source)}),flush=True)
if __name__=='__main__':main()
