"""NULL CHOIR deterministic, editable descent scene recipe."""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
import random
import struct
import sys

ROOT = Path(__file__).absolute().parent
sys.path.insert(0,str(ROOT))
import maw47
NAMES = ('intake', 'foundry', 'processional', 'reliquary', 'nursery', 'ossuary', 'inversion', 'heart')
HEROES = ('skin_bell', 'vertebral_furnace', 'walking_bone_organ', 'reliquary_face_halo',
          'nursery_gestation_engine', 'ossuary_rib_bridge', 'inversion_surgical_cradle', 'heart_mouth_restraint')
ANCHORS = ((-42,8,61), (-9,15,46), (28,8,31), (47,23,16), (9,-2,1), (-28,10,-14), (-10,25,-32), (31,7,-51))
RENDER = dict(width=7680,height=4320,percent=100,pixel_aspect=(1,1),engine='CYCLES',device='CPU',threads=2,samples=64)
PALETTE = {
    'stone': ((.31,.28,.23,1), .08,.87,0), 'bone': ((.66,.54,.36,1), .05,.73,0),
    'iron': ((.035,.045,.055,1), .8,.48,0), 'brass': ((.36,.19,.065,1), .77,.4,0),
    'vein': ((.19,.009,.025,1), .13,.32,0), 'amber': ((1,.26,.025,1), .1,.4,5),
    'violet': ((.24,.07,.7,1), .1,.4,3), 'runoff': ((.27,.45,.025,1), .1,.24,1.5),
    'glass': ((.3,.45,.38,1), .1,.18,0),
    'socket': ((.004,.006,.01,1), .05,.92,0),
    'haze': ((.17,.2,.26,0), 0,1,0),
    'eclipse_edge': ((1,.19,.035,1), .2,.55,1.6),
    'heart_flesh': ((.24,.027,.045,1),0,.38,0),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def add(a,b): return [a[i]+b[i] for i in range(3)]
def sub(a,b): return [a[i]-b[i] for i in range(3)]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def unit(a):
    n=math.sqrt(dot(a,a)); require(n>1e-9,'Zero direction'); return [v/n for v in a]


def box(name,ch,center,size,material='stone'):
    return dict(name=name,chapter=ch,material=material,
        vertices=[[center[i]+s[i]*size[i]/2 for i in range(3)] for s in itertools.product((-1,1),repeat=3)],
        faces=[[2,6,4,0],[5,7,3,1],[4,5,1,0],[3,7,6,2],[1,3,2,0],[6,7,5,4]])


def tube(name,ch,points,radius,material='bone',sides=6):
    vertices,faces=[],[]
    for i,point in enumerate(points):
        tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
        u=unit(cross(tangent,(0,0,1) if abs(tangent[2])<.9 else (0,1,0))); v=cross(tangent,u)
        for j in range(sides):
            a=j*math.tau/sides
            vertices.append([point[k]+radius*(u[k]*math.cos(a)+v[k]*math.sin(a)) for k in range(3)])
        if i:
            for j in range(sides):
                a,b=(i-1)*sides+j,(i-1)*sides+(j+1)%sides; faces.append([a,b,b+sides,a+sides])
    faces.extend([list(reversed(range(sides))),list(range(len(vertices)-sides,len(vertices)))])
    return dict(name=name,chapter=ch,material=material,vertices=vertices,faces=faces)


def arc(center,radius,start=0,end=math.tau,steps=32,vertical=True):
    return [add(center,(radius*math.cos(a),0 if vertical else radius*math.sin(a),radius*math.sin(a) if vertical else 0))
            for a in [start+(end-start)*i/steps for i in range(steps+1)]]


def island(name,ch,center,rx,ry,rng):
    points=[(math.cos(i*math.tau/12)*rx*rng.uniform(.87,1.06),math.sin(i*math.tau/12)*ry*rng.uniform(.87,1.06)) for i in range(12)]
    return dict(name=name,chapter=ch,material='stone',vertices=[add(center,(x,y,z)) for z in (-3,0) for x,y in points],
        faces=[list(reversed(range(12))),list(range(12,24))]+[[i,(i+1)%12,(i+1)%12+12,i+12] for i in range(12)])


def camera(position,target,scale):
    return dict(position=list(position),target=list(target),scale=scale,near=.1,far=700)


def baseline_plan():
    inventory=json.loads((ROOT/'inputs.json').read_text()); rng=random.Random(731904)
    plan=dict(seed=731904,render=dict(RENDER),chapters=[],meshes=[],assets=[],lights=[],cameras={},routes=[],
              reveals=[list(range(1,n+1)) for n in range(1,9)])
    def put(mesh): plan['meshes'].append(mesh)
    def pillar(ch,name,p,height,inverted=False):
        sign=-1 if inverted else 1
        for j,(w,h) in enumerate(((2.5,.6),(1.65,height),(2.2,.5))):
            z=.3 if j==0 else height/2+.6 if j==1 else height+1
            put(box(name+f' pier {j}',ch,add(p,(0,0,sign*z)),(w,w*.72,h)))
        tip=add(p,(0,0,sign*(height+1.5)))
        put(tube(name+' finial',ch,[tip,add(tip,(0,0,sign*2))],.23,'brass'))
        for x in (-.68,.68):
            put(tube(name+f' fluted edge {x}',ch,[add(p,(x,-.65,sign*.8)),add(p,(x,-.65,sign*(height+.5)))],.12,'bone'))
        for row in range(2):
            z=height*(.25+row*.43)
            lancet=[(-.55,-.7,z),(-.55,-.7,z+2), (0,-.7,z+3),(.55,-.7,z+2),(.55,-.7,z)]
            put(tube(name+f' lancet archivolt {row}',ch,[add(p,(x,y,sign*h)) for x,y,h in lancet],.11,'brass'))
    def bridge(ch,name,a,b,width=2.4):
        direction=unit(sub(b,a)); side=unit(cross(direction,(0,0,1))); count=max(2,math.ceil(math.dist(a,b)/.8))
        for j in range(count):
            c=[a[k]+(b[k]-a[k])*(j+.5)/count for k in range(3)]
            tread=box(name+f' tread {j}',ch,add(c,(0,0,-.18)),(width,.85,.36))
            for v in tread['vertices']:
                x,y=v[0]-c[0],v[1]-c[1]
                v[0]=c[0]+x*side[0]+y*direction[0]; v[1]=c[1]+x*side[1]+y*direction[1]
            put(tread)
        for sign in (-1,1):
            pts=[add(p,[side[k]*sign*width*.48+(1.05 if k==2 else 0) for k in range(3)]) for p in (a,b)]
            put(tube(name+f' handrail {sign}',ch,pts,.09,'iron'))
            for j in range(0,count+1,4):
                p=[a[k]+(b[k]-a[k])*j/count+side[k]*sign*width*.48 for k in range(3)]
                put(tube(name+f' post {sign} {j}',ch,[p,add(p,(0,0,1.05))],.085,'brass'))
        mid=[(a[k]+b[k])/2 for k in range(3)]
        put(tube(name+' underbrace',ch,[add(a,(0,0,-2)),add(mid,(0,0,-4)),add(b,(0,0,-2))],.22))
    for ch,(name,origin,hero) in enumerate(zip(NAMES,ANCHORS,HEROES),1):
        o=list(origin); plan['chapters'].append(dict(id=ch,name=name,anchor=o,hero=hero))
        put(island(name+' fractured terrace',ch,o,12 if ch!=7 else 8,9,rng))
        scale=[1.9]*3 if ch in (3,8) else [1.6]*3
        location=add(o,(0,4,7) if ch==3 else (0,2,0))
        plan['assets'].append(dict(id=hero,chapter=ch,location=location,scale=scale,bounds=inventory['assets'][hero]['bounds']))
        if ch==1:
            for x,y in itertools.product((-10,10),(-3,5)):
                pillar(ch,f'intake buttress {x} {y}',add(o,(x,y,0)),14)
            for x in (-9,0,9):
                put(tube(f'intake breached ogive {x}',ch,arc(add(o,(x,6,8)),6,0,math.pi),.55))
            for x in (-5,5):
                put(tube(f'intake exposed artery {x}',ch,[add(o,(x,-8,-3)),add(o,(x+1,-1,-5)),add(o,(x-2,8,-3))],.6,'vein'))
        elif ch==2:
            for x,y,h in ((-9,3,20),(9,5,25),(-7,-5,14),(7,-4,17)):
                pillar(ch,f'foundry hanging stack {x}',add(o,(x,y,0)),h)
                put(tube(f'foundry falling metal {x}',ch,[add(o,(x,y,h-1)),add(o,(x,y,-7))],.46,'amber'))
            bridge(ch,'foundry furnace crossing',add(o,(-11,-4,5)),add(o,(10,-4,8)))
            for z in (3,8,13):
                put(tube(f'foundry pressure main {z}',ch,[add(o,(-10,6,z)),add(o,(0,7,z+2)),add(o,(10,6,z))],.42,'iron'))
        elif ch==3:
            bridge(ch,'processional monumental stair',add(o,(0,-9,0)),add(o,(0,5,7)),6)
            for x,y in itertools.product((-9,9),(-5,1,7)):
                pillar(ch,f'processional colonnade {x} {y}',add(o,(x,y,0)),12+(y+5)*.35)
                put(box(f'processional pinned banner {x} {y}',ch,add(o,(x,y-.9,8)),(1.2,.08,6),'vein'))
        elif ch==4:
            for z,r in ((1,11),(7,9),(13,7)):
                put(tube(f'reliquary circular gallery {z}',ch,arc(add(o,(0,1,z)),r,0,math.tau,48,False),.65,'stone'))
            for j,(start,end) in enumerate(((-.42,1.12),(2.02,3.56))):
                put(tube(f'reliquary split crescent {j}',ch,arc(add(o,(0,5,10)),12,start,end),1.15))
            for angle in range(0,360,45):
                a=math.radians(angle); pillar(ch,f'reliquary radial buttress {angle}',add(o,(10*math.cos(a),10*math.sin(a),0)),12)
        elif ch==5:
            put(tube('nursery runoff perimeter',ch,arc(add(o,(0,0,-2)),10,0,math.tau,40,False),.8,'runoff'))
            for j,(x,y) in enumerate(((-8,3),(8,4),(-6,-5),(7,-5))):
                c=add(o,(x,y,6+j%2*2))
                for z in (-3,3):
                    put(tube(f'nursery vessel rim {j} {z}',ch,arc(add(c,(0,0,z)),1.6,0,math.tau,24,False),.18,'brass'))
                for a in (0,math.pi/2,math.pi,math.pi*1.5):
                    p=add(c,(1.6*math.cos(a),1.6*math.sin(a),0))
                    put(tube(f'nursery cage {j} {a}',ch,[add(p,(0,0,-3)),add(p,(0,0,3))],.1,'brass'))
                put(tube(f'nursery translucent vessel {j}',ch,[add(c,(0,0,-2.8)),add(c,(0,0,2.8))],1.45,'glass',16))
                put(tube(f'nursery branching tissue {j}',ch,[add(c,(-.4,0,-2)),add(c,(.4,0,0)),add(c,(-.2,0,2))],.42,'vein'))
                put(tube(f'nursery suspended feed {j}',ch,[add(c,(0,0,3)),add(c,(2,1,9)),add(o,(0,8,20))],.2,'vein'))
        elif ch==6:
            spiral=[add(o,(10*math.cos(a),8*math.sin(a),a*1.7)) for a in [i*math.tau/64 for i in range(65)]]
            for j in range(0,64,2): bridge(ch,f'ossuary spiral stair {j}',spiral[j],spiral[j+2],2)
            for j in range(14): put(tube(f'ossuary exposed rib {j}',ch,arc(add(o,(0,-6+j,3+j*.42)),7,0,math.pi,16),.32))
            put(tube('ossuary wrapping muscle',ch,[add(o,(-9,-3,0)),add(o,(-7,4,7)),add(o,(2,8,13)),add(o,(8,0,16))],.65,'vein'))
        elif ch==7:
            for j,(x,y,z) in enumerate(((-10,5,23),(9,7,27),(-7,-5,18),(11,-3,20))):
                pillar(ch,f'inversion suspended inverted tower {j}',add(o,(x,y,z)),11+j,True)
                put(island(f'inversion detached cap {j}',ch,add(o,(x,y,z)),3,3,rng))
            put(tube('inversion eclipse rim',ch,arc(add(o,(0,8,13)),6),.18,'violet'))
            bridge(ch,'inversion broken diagonal',add(o,(-9,-7,0)),add(o,(9,2,7)))
        else:
            for j in range(9):
                a=j*math.tau/9; x,y=14*math.cos(a),10*math.sin(a)
                put(tube(f'heart radial restraint {j}',ch,[add(o,(x,y,-8)),add(o,(x*.8,y*.8,6)),add(o,(x*.45,y*.45,17))],.7,'vein'))
                put(tube(f'heart ivory hook {j}',ch,[add(o,(x,y,-2)),add(o,(x*.6,y*.6,13)),add(o,(x*.3,y*.3,18))],.5))
            put(tube('heart severed crown',ch,arc(add(o,(0,4,12)),15,.18,math.tau-.35,48),.7,'brass'))
            put(tube('heart pulse throat',ch,[add(o,(0,2,-12)),add(o,(0,2,-1))],1.15,'amber'))
        for j in range(7):
            p=add(o,(-10+j*3.3,-7,.7)); put(tube(name+f' route lantern {j}',ch,[p,add(p,(0,0,.7))],.12,'amber'))
        color=(.95,.32,.09) if ch<5 else (.65,.75,.22) if ch==5 else (.64,.45,.26) if ch==6 else (.35,.16,1) if ch==7 else (1,.05,.08)
        plan['lights'].append(dict(name=name+' local key',chapter=ch,position=add(o,(-9,-10,20)),target=add(o,(0,2,6)),color=list(color),power=6500,size=9))
        shot=(((-29,-46,27),(0,2,8),42),((34,-48,30),(0,1,10),48),
              ((-20,-52,18),(0,3,10),42),((32,-48,27),(0,2,9),44),
              ((-28,-43,21),(0,2,8),42),((33,-42,31),(0,1,7),43),
              ((-30,-50,25),(0,3,11),48),((-17,-56,19),(0,3,8),48))[ch-1]
        plan['cameras'][name]=camera(add(o,shot[0]),add(o,shot[1]),shot[2])
        marker=tube(name+' earned pulse',ch,arc(add(o,(0,-8,2)),1.1,0,math.tau,24,False),.12,'amber'); marker['pulse']=True; put(marker)
    for i in range(7):
        a=add(ANCHORS[i],(4,-5,0)); b=add(ANCHORS[i+1],(-4,-5,0))
        plan['routes'].append(dict(chapter=i+2,start=a,end=b,from_id=i+1,to_id=i+2))
        bridge(i+2,f'descent {i+1} to {i+2}',a,b,2.8)
    t=(0,110,0)
    put(island('title foreground fracture',0,add(t,(-12,-15,0)),14,8,rng))
    bridge(0,'title breached causeway',add(t,(-4,-12,0)),add(t,(10,4,7)),4)
    for j,(start,end) in enumerate(((.25,1.33),(1.83,2.9),(3.32,4.5),(4.93,6.02))):
        put(tube(f'title split restraint quadrant {j}',0,arc(add(t,(10,9,17)),17,start,end,24),1.3))
        put(tube(f'title brass binding {j}',0,arc(add(t,(10,8,17)),18,start,end,24),.28,'brass'))
        for k in range(7):
            a=start+(end-start)*(k+.5)/7; c=add(t,(10+17*math.cos(a),8,17+17*math.sin(a)))
            plate=box(f'title restraint radial plate {j} {k}',0,c,(3.4,1.5,1.1),'brass')
            for v in plate['vertices']:
                x,z=v[0]-c[0],v[2]-c[2]
                v[0]=c[0]+x*math.cos(a)-z*math.sin(a); v[2]=c[2]+x*math.sin(a)+z*math.cos(a)
            put(plate)
    for x in (-13,31):
        for y,h in ((12,27),(24,35)): pillar(0,f'title cathedral {x} {y}',add(t,(x,y,0)),h)
    for j in range(12):
        a=j*math.tau/12
        put(tube(f'title tension artery {j}',0,[add(t,(10+18*math.cos(a),9,17+18*math.sin(a))),add(t,(10+23*math.cos(a),15,8+10*math.sin(a))),add(t,(10+28*math.cos(a),24,-10))],.25,'vein'))
    p=add(t,(-14,-17,.3))
    put(tube('title technician patched coat',0,[add(p,(0,0,.8)),add(p,(0,0,2.5))],.65,'iron',8))
    put(tube('title technician helmet',0,[add(p,(0,0,2.6)),add(p,(0,0,3.05))],.36,'brass',8))
    for sign in (-1,1):
        put(tube(f'title technician leg {sign}',0,[add(p,(sign*.3,0,0)),add(p,(sign*.26,0,1.3))],.19,'iron'))
        put(tube(f'title technician arm {sign}',0,[add(p,(sign*.55,0,2.2)),add(p,(sign*.8,-.2,1.1))],.17,'iron'))
    put(tube('title handheld recovery lamp',0,[add(p,(.85,-.2,.6)),add(p,(.85,-.2,1.1))],.15,'amber'))
    put(tube('title eclipse',0,arc(add(t,(10,14,18)),5),.13,'violet'))
    plan['lights'].extend([dict(name='title amber',chapter=0,position=add(t,(-20,-15,25)),target=add(t,(10,8,10)),color=[1,.38,.12],power=12000,size=12),
        dict(name='title cold rim',chapter=0,position=add(t,(14,28,30)),target=add(t,(10,8,15)),color=[.23,.3,1],power=18000,size=10)])
    plan['cameras']['title']=camera(add(t,(-32,-58,24)),add(t,(4,7,16)),54)
    plan['cameras']['overview']=camera((120,-225,145),(2,10,7),158)
    return plan


def foundation(name,ch,center,rx,ry,depth,rng):
    mesh=island(name,ch,center,rx,ry,rng)
    # Preserve the authored top polygon and face index used by landing witnesses.
    for j,v in enumerate(mesh['vertices'][:12]):
        v[0]=center[0]+(v[0]-center[0])*rng.uniform(.72,1.12)
        v[1]=center[1]+(v[1]-center[1])*rng.uniform(.7,1.12)
        v[2]=center[2]-depth*rng.uniform(.86,1.12)
    return mesh


def opening(name,ch,center,width,spring,peak,thickness=.45,depth=1.6):
    """Extruded arch band with a real open centre and continuous jambs."""
    def contour(span,top):
        left=[(span/2+span*math.cos(a),spring+math.sin(a)*(top-spring)/math.sin(2*math.pi/3))
              for a in [math.pi-i*math.pi/18 for i in range(7)]]
        return [(-span/2,0)]+left+[(-x,z) for x,z in reversed(left[:-1])]+[(span/2,0)]
    inner=contour(width,peak);outer=contour(width+2*thickness,peak+thickness)
    n=len(inner); vertices=[add(center,(x,y,z)) for y in (-depth/2,depth/2) for contour in (inner,outer) for x,z in contour]; faces=[]
    for j in range(n-1):
        faces.extend([[j,j+1,n+j+1,n+j],[2*n+j,3*n+j,3*n+j+1,2*n+j+1],
                      [j,2*n+j,2*n+j+1,j+1],[n+j,n+j+1,3*n+j+1,3*n+j]])
    faces.extend([[0,n,3*n,2*n],[n-1,3*n-1,4*n-1,2*n-1]])
    return dict(name=name,chapter=ch,material='stone',vertices=vertices,faces=faces)


def annulus(name,ch,c,inner,outer,start,end,depth,steps=48):
    vertices=[add(c,(r*math.cos(a),y,r*math.sin(a))) for y in (-depth/2,depth/2) for r in (inner,outer)
              for a in [start+(end-start)*j/steps for j in range(steps+1)]]
    n=steps+1;faces=[]
    for j in range(steps):
        faces.extend([[j,n+j,n+j+1,j+1],[2*n+j,2*n+j+1,3*n+j+1,3*n+j],
                      [j,j+1,2*n+j+1,2*n+j],[n+j,3*n+j,3*n+j+1,n+j+1]])
    faces.extend([[0,2*n,3*n,n],[n-1,2*n-1,4*n-1,3*n-1]])
    return dict(name=name,chapter=ch,material='bone',vertices=vertices,faces=faces)


def architectural_plan():
    plan=baseline_plan(); inventory=json.loads((ROOT/'inputs.json').read_text());rng=random.Random(plan['seed']+404)
    # Replace the rejected title dressing; retain its separately authored technician.
    plan['meshes']=[m for m in plan['meshes'] if (m['chapter']!=0 or m['name'].startswith(('title technician','title handheld','title breached causeway')))
                    and not any(s in m['name'] for s in (' pier ',' fluted edge ',' finial',' lancet archivolt '))]
    plan['kit']=[]
    def put(m):plan['meshes'].append(m)
    def kit(identity,ch,location,scale=(1,1,1),yaw=0):
        plan['kit'].append(dict(id=identity,chapter=ch,location=list(location),scale=list(scale),yaw=yaw,bounds=inventory['assets'][identity]['bounds']))
    def gallery(ch,name,o,centers,levels,width=4.8):
        for floor in levels:
            for j,x in enumerate(centers):
                put(opening(name+f' arcade opening {floor} {j}',ch,add(o,(x,0,floor)),width,3.2,6.5,.5,2))
            middle=(min(centers)+max(centers))/2;span=max(centers)-min(centers)+width+1
            put(box(name+f' occupied gallery {floor}',ch,add(o,(middle,-.3,floor+7)),(span,3.8,.9),'stone'))
            for y in (-2,1.4):
                put(tube(name+f' gallery railing {floor} {y}',ch,[add(o,(min(centers)-width/2,y,floor+8.3)),add(o,(max(centers)+width/2,y,floor+8.3))],.12,'iron'))
    for ch,o in enumerate(ANCHORS,1):
        name=NAMES[ch-1]
        terrace=next(m for m in plan['meshes'] if m['name']==name+' fractured terrace')
        replacement=foundation(terrace['name'],ch,o,12 if ch!=7 else 8,9,17+ch*.4,rng)
        # The retained top footprint preserves all fourteen tested landings exactly.
        replacement['vertices'][12:24]=terrace['vertices'][12:24];terrace.update(replacement)
        for sign in (-1,1):
            put(foundation(name+f' cliff abutment {sign}',ch,add(o,(sign*11,7,4+ch%3)),4.4,5.5,23,rng))
        gallery(ch,name,add(o,(0,8.5,0)),(-4.8,4.8),(0,8.3))
        kit('arch',ch,add(o,(0,8.2,0)),(1.35,1.5,1.6))
        if ch not in (4,7):kit('ribbed_wall',ch,add(o,((-10 if ch%2 else 10),6,1)),(1.7,2.2,2.5))
        if ch!=8:kit('lumen_sconce',ch,add(o,(-7,6,5)),(1.3,1.4,1.5))
        if ch in (1,4):kit('cathedral_corner_rib',ch,add(o,(8,6,3)),(1.2,1.4,2))
        if ch==5:kit('containment_capsule',ch,add(o,(8,1,0)),(1.1,1.1,1.25))
        if ch==7:
            for j,(x,y,z) in enumerate(((-10,5,23),(9,7,27),(-7,-5,18),(11,-3,20))):
                put(foundation(f'inversion hanging masonry {j}',ch,add(o,(x,y,z)),2,2,11+j,rng))
        put(box(name+' lower haze',ch,add(o,(0,3,-4)),(24,16,4),'haze'))
        for j,(x,y,z) in enumerate(((-7,3,4),(7,9,12))):
            plan['lights'].append(dict(name=name+f' gallery lamp {j}',chapter=ch,position=add(o,(x,y-2,z)),target=add(o,(x,y+3,z-3)),color=[1,.36,.11],power=650,size=1.1))
    t=(0,110,0)
    put(foundation('title foreground fracture',0,add(t,(-12,-15,0)),42,20,23,rng))
    for j,(x,y,rx,ry) in enumerate(((-19,12,15,9),(39,15,12,10))):
        put(foundation(f'title canyon foundation {j}',0,add(t,(x,y,-1)),rx,ry,28,rng))
    gallery(0,'title west',add(t,(0,9,0)),(-25,-17,-9),(0,10),5.8)
    gallery(0,'title east',add(t,(0,15,0)),(31,39,47),(0,10),5.8)
    gallery(0,'title far west',add(t,(0,20,0)),(-49,-41,-33),(0,10),5.8)
    gallery(0,'title far east',add(t,(0,25,0)),(53,61),(0,),5.8)
    for j,(x,y,rx) in enumerate(((-41,20,17),(57,25,11))):
        put(foundation(f'title canyon continuation {j}',0,add(t,(x,y,-1)),rx,9,27,rng))
    gallery(0,'title central bridge',add(t,(0,6,-4)),(0,8,16),(0,),6)
    for j,(x,y,z) in enumerate(((-30,10,16),(48,17,20),(-20,32,29),(37,36,33))):
        put(foundation(f'title distant buttress {j}',0,add(t,(x,y,z)),3.4,4,40,rng))
        put(opening(f'title distant arcade opening {j}',0,add(t,(x,y-3,z)),4,4,9,.65,2))
    for j,(a,b) in enumerate(((.15,1.4),(1.77,3.04),(3.24,4.56),(4.9,6.1))):
        put(annulus(f'title layered restraint {j}',0,add(t,(10,10,17)),14.5,18.2,a,b,3.8))
        # Thin layered bands read as fastenings rather than rectangular beads.
        for radius,y in ((14.8,7.9),(17.8,7.9),(16.3,12.1)):
            put(tube(f'title restraint seam {j} {radius}',0,arc(add(t,(10,y,17)),radius,a,b,40),.16,'brass',8))
        for k in range(5):
            angle=a+(b-a)*(k+.5)/5;c=add(t,(10+16.3*math.cos(angle),7.85,17+16.3*math.sin(angle)))
            put(tube(f'title curved clamp {j} {k}',0,[add(c,(-1.2*math.cos(angle),-.25,-1.2*math.sin(angle))),add(c,(0,-.65,0)),add(c,(1.2*math.cos(angle),-.25,1.2*math.sin(angle)))],.22,'brass',8))
    for j in range(8):
        a=j*math.tau/8;start=add(t,(10+18*math.cos(a),11,17+18*math.sin(a)))
        end=add(t,(-23 if math.cos(a)<0 else 42,18,-3+j%3*5))
        points=[start,add(start,(math.cos(a)*2,1,-2)),[(start[k]+end[k])/2+(3 if k==1 else -3 if k==2 else 0) for k in range(3)],add(end,(2,0,4)),end]
        put(tube(f'title articulated artery {j}',0,points,.32+j%2*.11,'vein',8))
    # A recessed faceted black sphere replaces the flat purple circle.
    sphere=[];faces=[];segments=32;rings=16
    for row in range(1,rings):
        a=row*math.pi/rings
        for j in range(segments):
            b=j*math.tau/segments;sphere.append(add(t,(10+5.7*math.sin(a)*math.cos(b),19+2*math.sin(a)*math.sin(b),17+5.7*math.cos(a))))
    for row in range(rings-2):
        for j in range(segments):faces.append([(row+1)*segments+j,(row+1)*segments+(j+1)%segments,row*segments+(j+1)%segments,row*segments+j])
    sphere.extend([add(t,(10,19,22.7)),add(t,(10,19,11.3))])
    for j in range(segments):faces.extend([[len(sphere)-2,j,(j+1)%segments],[len(sphere)-1,(rings-2)*segments+(j+1)%segments,(rings-2)*segments+j]])
    put(dict(name='title recessed eclipse volume',chapter=0,material='socket',vertices=sphere,faces=faces))
    put(tube('title eclipse heated rim',0,arc(add(t,(10,18.7,17)),5.85,.1,math.tau-.15,64),.24,'eclipse_edge',8))
    kit('cathedral_cluster_pier',0,add(t,(-27,7,0)),(3.3,3.3,4.5))
    kit('ribbed_wall',0,add(t,(38,13,3)),(2,2.5,3))
    for x in (-25,31):kit('arch',0,add(t,(x,8 if x<0 else 14,10)),(1.25,1.7,1.5))
    for x in (-29,44):kit('cathedral_corner_rib',0,add(t,(x,8,8)),(2,2,3))
    kit('witness_relief',0,add(t,(-14,7.5,10)),(1.6,2,2))
    kit('conduit',0,add(t,(-18,-19,.2)),(2.2,3,2),math.pi/2)
    for x in (-21,36):kit('lumen_sconce',0,add(t,(x,6,9)),(2,2,2))
    for j in range(12):
        x=-42+j*7.8;y=-20+rng.uniform(-3,2)
        put(foundation(f'title foreground broken masonry {j}',0,add(t,(x,y,.4+rng.random())),1.1,1,1.6,rng))
    pivot=add(t,(-14,-17,.3))
    for m in plan['meshes']:
        if m['name'].startswith(('title technician','title handheld')):
            m['vertices']=[add(pivot,[(v[k]-pivot[k])*2.1 for k in range(3)]) for v in m['vertices']]
    put(tube('title technician recovery hose',0,[add(t,(-14,-16,5)),add(t,(-16,-16,4)),add(t,(-15,-16,2)),add(t,(-13,-16,2.5))],.16,'brass',8))
    put(box('title chasm atmosphere',0,add(t,(10,18,-6)),(62,36,10),'haze'))
    for j,(x,y,z) in enumerate(((-24,5,4),(-9,7,12),(31,11,4),(45,12,16),(9,7,8),(10,18,16))):
        plan['lights'].append(dict(name=f'title local lantern {j}',chapter=0,position=add(t,(x,y,z)),target=add(t,(x,y+4,z-3)),color=[1,.31,.08],power=1200 if j!=5 else 2500,size=1.8))
    for ch,name in enumerate(NAMES,1):
        record=plan['cameras'][name];record['position'][2]-=9;record['target'][2]-=9
        record['scale']=(48,50,51,50,50,50,58,58)[ch-1]
    plan['cameras']['title']=camera(add(t,(-25,-70,24)),add(t,(8,10,8)),88)
    plan['cameras']['overview']['position'][2]-=7;plan['cameras']['overview']['target'][2]-=7
    plan['cameras']['overview']['scale']=180
    return plan


def cut_mass(name,ch,a,b,width,depth):
    """A closed, stratified escarpment; its ends overlap the adjacent terraces."""
    side=unit(cross(sub(b,a),(0,0,1)));vertices=[];faces=[]
    profile=((-1,0),(1,0),(1.12,-.27),(.93,-.58),(1.05,-1),(-1.08,-1),(-.9,-.6),(-1.1,-.25))
    for j in range(9):
        t=j/8;c=[a[k]+t*(b[k]-a[k]) for k in range(3)]
        for n,(l,z) in enumerate(profile):
            jitter=1+.075*math.sin(j*2.7+n*4.1)
            vertices.append([c[k]+side[k]*l*width*.5*jitter+(z*depth if k==2 else 0) for k in range(3)])
        if j:
            for n in range(8):
                u=(j-1)*8+n;v=(j-1)*8+(n+1)%8
                faces.append([u,v,v+8,u+8])
    faces.extend([list(reversed(range(8))),list(range(64,72))])
    return dict(name=name,chapter=ch,material='stone',vertices=vertices,faces=faces)


def joined(name,ch,parts):
    vertices=[];faces=[]
    for m in parts:
        offset=len(vertices);vertices.extend(m['vertices']);faces.extend([[offset+i for i in face] for face in m['faces']])
    return dict(name=name,chapter=ch,material='stone',vertices=vertices,faces=faces)


def turned(mesh,origin,yaw):
    c,s=math.cos(yaw),math.sin(yaw)
    mesh['vertices']=[add(origin,(v[0]*c-v[1]*s,v[0]*s+v[1]*c,v[2])) for v in mesh['vertices']]
    return mesh


def open_section_plan():
    plan=architectural_plan();rng=random.Random(plan['seed']+808)
    # The07 wall/ribbon is deliberately not used: continuity comes from pierced aqueducts.
    plan['meshes']=[m for m in plan['meshes'] if not any(k in m['name'] for k in ('cliff abutment','title restraint seam','title distant buttress','title canyon foundation','title canyon continuation'))]
    plan['kit']=[a for a in plan['kit'] if not (a['chapter']==0 and a['id']=='witness_relief')]
    # Frame each original machine with its local vocabulary, not bars across its silhouette.
    for m in plan['meshes']:
        n=m['name'];delta=None
        if n.startswith('foundry furnace crossing'):delta=(0,-7,-2)
        elif n.startswith('processional pinned banner'):delta=(0,11,0)
        elif n.startswith('reliquary circular gallery'):delta=(0,6,-22)
        elif n.startswith(('nursery cage','nursery vessel rim','nursery translucent vessel','nursery branching tissue')):delta=(5,7,0)
        elif n.startswith('ossuary exposed rib'):delta=(0,14,0)
        elif n.startswith('inversion broken diagonal'):delta=(-12,0,-5)
        elif n.startswith(('heart radial restraint','heart ivory hook')):delta=(0,24,0)
        if delta:m['vertices']=[add(v,delta) for v in m['vertices']]
    for ch,o in enumerate(ANCHORS,1):
        name=NAMES[ch-1];terrace=next(m for m in plan['meshes'] if m['name']==name+' fractured terrace')
        # Irregular occupied ledge, not a round button; retain all endpoint tread contact.
        outline=((16,-2),(17,5),(12,12),(2,13),(-9,12),(-16,7),(-18,0),(-15,-7),(-8,-10),(1,-9),(10,-10),(14,-6))
        for i,(x,y) in enumerate(outline):
            terrace['vertices'][i+12]=add(o,(x*(.72 if ch==5 else .6 if ch==6 else 1),y,0))
            terrace['vertices'][i]=add(terrace['vertices'][i+12],(0,0,-1.1))
        flank=foundation('lateral native cliff',ch,add(o,(-12,7,-1)),3.1,4.5,28,rng)
        terrace.update(joined(terrace['name'],ch,[terrace,flank]));terrace['depth_plane']='hero'
        for tier in (-16,17):
            for j,x in enumerate((-12,-4,4,12)):
                m=opening(f'{name} pierced distant arcade opening {tier} {j}',ch,add(o,(x,23,tier)),6.8,7,13,.8,3)
                m['depth_plane']='distant';plan['meshes'].append(m)
            plan['meshes'].append(box(f'{name} distant occupied deck {tier}',ch,add(o,(0,23,tier+13.8)),(36,5,1.2)))
        m=cut_mass(name+' foreground cliff side',ch,add(o,(-24,-2,-1)),add(o,(-19,12,-4)),5,34);m['depth_plane']='foreground';plan['meshes'].append(m)
        # Upper/lower side landings attach to the same open section, not round room buttons.
        for tier in (-12,8):
            plan['meshes'].append(box(f'{name} side landing {tier}',ch,add(o,(-14,8,tier)),(10,7,1.2)))
        plan['lights'].append(dict(name=name+' lower gallery amber',chapter=ch,position=add(o,(-8,17,-8)),target=add(o,(0,23,-6)),color=[1,.31,.09],power=1600,size=5))
    for i,route in enumerate(plan['routes']):
        a,b=route['start'],route['end']
        parts=[];yaw=math.atan2(b[1]-a[1],b[0]-a[0]);length=math.dist(a[:2],b[:2])
        for j in range(3):
            t=(j+.5)/3;origin=[a[k]+t*(b[k]-a[k]) for k in range(3)];origin[2]-=18
            parts.append(turned(opening('pierced span',i+2,(0,0,0),length/3-.7,10,17,.9,3),origin,yaw))
        m=joined(f'excavated spine {i+1}',i+2,parts);m['pierced']=True;plan['meshes'].append(m)
    for m in plan['meshes']:
        if m['name'].startswith(('nursery foreground cliff side','nursery side landing')):m['vertices']=[add(v,(38,0,0)) for v in m['vertices']]
    plan['meshes']=[m for m in plan['meshes'] if m['name']!='nursery foreground cliff side']
    next(m for m in plan['meshes'] if m['name']=='nursery runoff perimeter')['depth_plane']='foreground'
    t=(0,110,0)
    ground=next(m for m in plan['meshes'] if m['name']=='title foreground fracture')
    ground.update(cut_mass(ground['name'],0,add(t,(-100,-14,0)),add(t,(90,-8,-2)),16,23));ground['depth_plane']='foreground'
    # Side cliffs frame an open centre. Nothing seals the eclipse's far shaft.
    for sign in (-1,1):
        m=cut_mass('title lateral cavern '+str(sign),0,add(t,(sign*69,-4,20)),add(t,(sign*58,65,24)),13,70);m['depth_plane']='foreground';plan['meshes'].append(m)
    for depth,z,span in ((43,-10,82),(68,7,94),(92,22,110)):
        for j in range(9):
            shaft=10+(depth-19)*34/105
            x=shaft-span/2+j*span/8
            # The central shaft is a genuine opening from the eclipse into distant depth.
            if abs(x-shaft)<12:continue
            m=opening(f'title receding arcade opening {depth} {j}',0,add(t,(x,depth,z)),span/9-1,10,19,1,4);m['depth_plane']='distant';plan['meshes'].append(m)
        for sign in (-1,1):
            plan['meshes'].append(box(f'title distant gallery deck {depth} {sign}',0,add(t,(10+(depth-19)*34/105+sign*29,depth,z+20)),(34,6,1.5)))
        plan['lights'].append(dict(name=f'title far amber depth {depth}',chapter=0,position=add(t,(-24,depth-6,z+12)),target=add(t,(-20,depth,z+8)),color=[1,.29,.08],power=2400,size=6))
    coat=next(m for m in plan['meshes'] if m['name']=='title technician patched coat')
    origin=add(t,(-14,-17,.3))
    garment=tube(coat['name'],0,[add(origin,(0,0,z)) for z in (1.3,2.1,4.4,5.1)],1.15,'iron',12)
    for i,v in enumerate(garment['vertices']):
        factor=(1.18,.9,.83,.53)[i//12]
        for k in (0,1):v[k]=origin[k]+(v[k]-origin[k])*factor
    coat.update(garment)
    for m in plan['meshes']:
        if m['name'].startswith('title layered restraint'):m['depth_plane']='hero'
    # Keep original camera projection and full hero/route bounds; frame opens in depth instead.
    plan['cameras']['title']=camera(add(t,(-29,-94,38)),add(t,(5,11,14)),59)
    plan['cameras']['overview']=camera((0,-201,287),(0,12,4),155)
    for ch,name in enumerate(NAMES,1):
        plan['cameras'][name]['scale']=(37,43,42,44,42,43,49,50)[ch-1]
        plan['cameras'][name]['target'][2]+=6;plan['cameras'][name]['position'][2]+=6
    # Clear local hero sightlines without moving or hiding any context.
    for name,position in {'ossuary': [-1.4238742570542016, -40.04325212887891, 4.223078169047344], 'inversion': [-23.832433462619555, -25.441804674329497, 5.285445150330506], 'heart': [-0.6910627079628924, -42.58969998431216, -35.0]}.items():
        plan['cameras'][name]['position']=position
    return plan


def gallery_layout():
    return [(ch,name+' inhabited gallery',[o[0],55,o[2]],add(o,(24 if ch==5 else -14,8,-12)))
            for ch,(name,o) in enumerate(zip(NAMES,ANCHORS),1)]+[
            (0,'title west inhabited gallery',[-35,170,0],[-25,119,7]),
            (0,'title east inhabited gallery',[65,205,0],[39,125,7])]


def raked_deck(name,ch,a,b,width):
    length=math.dist(a[:2],b[:2]);mesh=box(name,ch,(0,0,0),(width,length,.9))
    for v in mesh['vertices']:v[2]+=v[1]*(b[2]-a[2])/length
    return turned(mesh,[(a[k]+b[k])/2 for k in range(3)],math.atan2(b[1]-a[1],b[0]-a[0])-math.pi/2)


def masonry_gallery(plan,ch,name,o,attachment):
    put=plan['meshes'].append;rng=random.Random(plan['seed']+ch*17+int(o[0]))
    for x in (-14,0,14):
        pier=box(name+' bearing pier '+str(x//14+1),ch,add(o,(x,0,0)),(3.2,8,40))
        pier['depth_plane']='distant';put(pier)
    for floor in (-18,2):
        for j,x in enumerate((-7,7)):
            put(opening(name+f' pierced bay {floor} {j}',ch,add(o,(x,0,floor)),10.5,8,14.5,1.6,6))
    for label,z,height in (('foundation floor',-19,2),('occupied middle floor',-.25,4.5),('bearing roof',18.8,2.5)):
        put(box(name+' '+label,ch,add(o,(0,0,z)),(33,10,height)))
    for j,x in enumerate((-11,0,11)):
        put(foundation(name+f' fractured roof {j}',ch,add(o,(x,.5,22+(j%2)*1.4)),5.7,5,4.7,rng))
    for sign in (-1,1):
        put(foundation(name+f' rock footing {sign}',ch,add(o,(sign*14,0,-20)),3.1,5,19,rng))
        put(tube(name+f' forged iron tie {sign}',ch,[add(o,(sign*14,-4.15,-19)),add(o,(sign*13,-4.7,0)),add(o,(sign*14,-4.2,20))],.2,'iron',6))
    # A physical side gallery joins the original occupied ledge to the bearing wall.
    end=add(o,(14 if ch==5 else -14,-4,-18));put(raked_deck(name+' attachment',ch,attachment,end,4))
    for sign in (-1,1):
        put(tube(name+f' attachment iron rail {sign}',ch,[add(attachment,(sign*1.8,0,1.3)),add(end,(sign*1.8,0,1.3))],.12,'iron',6))
    put(tube(name+' exposed artery',ch,[add(o,(-14,-4.5,-17)),add(o,(-12,-4.8,-4)),add(o,(-15,-4.8,4)),add(o,(-13,-4.5,21))],.34,'vein',6))
    for label,point,target,color,power in (
            ('recess amber',(-7,-7,-9),(-7,0,-7),(1,.32,.09),2400),
            ('upper shaft', (8,-6,12),(8,0,10),(.25,.22,.65),1800)):
        plan['lights'].append(dict(name=name+' '+label,chapter=ch,position=add(o,point),target=add(o,target),color=list(color),power=power,size=5))


def heart_interior(plan):
    plan['meshes']=[m for m in plan['meshes'] if m['name']!='heart severed crown']
    put=plan['meshes'].append
    def block(name,center,size):put(box('heart interior '+name,8,center,size))
    block('continuous raft',(37,31,-64),(58,78,20))
    block('foreground landing',(37,16,-52.5),(58,48,3))
    block('deep rear masonry',(37,68,-28),(58,4,92))
    for i,x in enumerate((14,38,62)):
        block('rear pier '+str(i),(x,36,-32),(6,10,44))
    for i,y in enumerate((-2,17,36)):
        block('right pier '+str(i),(62,y,-32),(6,6,44))
    block('left vault pier',(14,17,-32),(6,6,44))
    block('foreground pier',(10,0,-34),(4,6,40))
    for z in (-54,-32):
        for x in (26,50):put(opening(f'heart interior rear bay {z} {x}',8,(x,36,z),18,12,20,2.5,8))
        for y in (7.5,26.5):put(turned(opening(f'heart interior right bay {z} {y}',8,(0,0,0),13,12,20,2.5,6),(62,y,z),math.pi/2))
    for z in (-32,-10):
        block('rear occupied bond '+str(z),(38,36,z),(54,10,2))
        block('right occupied bond '+str(z),(62,17,z),(10,44,2))
    for x in (14,62):block('vault spring bond '+str(x),(x,26.5,-10),(6,25,3))
    for y in (17,36):
        for side,a,b in (('right',0,1.2),('left',1.45,math.pi)):
            m=annulus(f'heart interior vault {y} {side}',8,(38,y,-10),24,27,a,b,4,8)
            m['material']='stone';put(m)
    for i in range(4):block('foreground stair '+str(i),(13,-6+i*2,-51+(i+1)*.35),(8,2.1,(i+1)*.7))


def heart_interior_contract(plan):
    from collections import Counter
    parts={m['name'].removeprefix('heart interior '):m for m in plan['meshes'] if m['name'].startswith('heart interior ')}
    require('continuous raft' in parts,'Heart interior connected chamber missing')
    for m in parts.values():
        edges=Counter(tuple(sorted((a,b))) for face in m['faces'] for a,b in zip(face,face[1:]+face[:1]))
        volume=sum(dot(m['vertices'][face[0]],cross(m['vertices'][b],m['vertices'][c]))/6 for face in m['faces'] for b,c in zip(face[1:-1],face[2:]))
        require(edges and all(n==2 for n in edges.values()) and volume>0,'Heart interior closed positive volume')
    def contact(part,support):
        # Room supports are convex boxes; certify referenced vertices or edge/face intersections.
        planes=[]
        for face in support['faces']:
            a,b,c=[support['vertices'][i] for i in face[:3]];planes.append((a,unit(cross(sub(b,a),sub(c,a)))))
        if not planes:return False
        inside=lambda v:all(dot(sub(v,a),n)<=1e-6 for a,n in planes)
        for face in part['faces']:
            vertices=[part['vertices'][i] for i in face]
            if any(inside(v) for v in vertices):return True
            for u,v in zip(vertices,vertices[1:]+vertices[:1]):
                for a,n in planes:
                    start=dot(sub(u,a),n);end=dot(sub(v,a),n)
                    if abs(start-end)<1e-10:continue
                    t=start/(start-end)
                    if 0<=t<=1 and inside(add(u,[t*x for x in sub(v,u)])):return True
        return False
    raft=parts['continuous raft'];landing=parts['foreground landing']
    terrace=next(m for m in plan['meshes'] if m['name']=='heart fractured terrace')
    require(contact(terrace,raft) and contact(terrace,landing),'Heart interior original terrace contact')
    for key in ('foreground landing','deep rear masonry','left vault pier','foreground pier',*[f'rear pier {i}' for i in range(3)],*[f'right pier {i}' for i in range(3)]):
        require(key in parts and contact(parts[key],raft),'Heart interior foundation contact '+key)
    for z in (-32,-10):
        for side in ('rear','right'):
            bond=parts[f'{side} occupied bond {z}']
            require(all(contact(parts[f'{side} pier {i}'],bond) for i in range(3)),'Heart interior occupied bond contact')
    for z in (-54,-32):
        for side,positions in (('rear',(26,50)),('right',(7.5,26.5))):
            floor=raft if z==-54 else parts[f'{side} occupied bond -32']
            roof=parts[f'{side} occupied bond {-32 if z==-54 else -10}']
            require(all(contact(parts[f'{side} bay {z} {position}'],floor) and contact(parts[f'{side} bay {z} {position}'],roof) for position in positions),'Heart interior bay bearing contact')
    for x,piers in ((14,('left vault pier','rear pier 0')),(62,('right pier 1','rear pier 2'))):
        require(all(contact(parts[pier],parts[f'vault spring bond {x}']) for pier in piers),'Heart interior vault spring contact')
    for y in (17,36):
        for side,pier in (('left','left vault pier' if y==17 else 'rear pier 0'),('right','right pier 1' if y==17 else 'rear pier 2')):
            require(contact(parts[f'vault {y} {side}'],parts[pier]),'Heart interior vault contact')
    for i in range(4):require(contact(parts[f'foreground stair {i}'],landing),'Heart interior stair contact')
    cam=plan['cameras']['heart'];forward=unit(sub(cam['target'],cam['position']));right=unit(cross(forward,(0,0,1)));up=cross(right,forward)
    blockers=projected_blockers(cam,list(parts.values()));ratio=cam['sensor_width']/cam['lens']
    for x,y in ((.9,.6),(.8,.9),(.5,.95),(.1,.8),(.5,.5)):
        point=add(cam['position'],[200*(forward[k]+(x-.5)*ratio*right[k]+(y-.5)*ratio/(16/9)*up[k]) for k in range(3)])
        require(first_blocker(projected(cam,point),blockers,cam['near'],True) is not None,'Heart interior eye-ray enclosure')


def heart_lighting(plan):
    updates={
        'heart local key':dict(color=[1,.84,.68],power=4600,position=[24,-3,-28],target=[31,9,-43],size=5),
        'heart gallery lamp 0':dict(color=[1,.55,.25],power=800,target=[31,9,-43],size=1.5),
        'heart gallery lamp 1':dict(color=[1,.64,.38],power=950,position=[39,6,-40],target=[31,9,-43],size=1.5),
        'heart lower gallery amber':dict(color=[1,.40,.16],power=1200),
        'heart inhabited gallery recess amber':dict(color=[1,.45,.22],power=1800),
        'heart inhabited gallery upper shaft':dict(color=[.60,.70,.86],power=3800,position=[50,26,-20],target=[62,24,-37],size=7),
    }
    for light in plan['lights']:
        if light['chapter']==8:light.update(updates[light['name']])


def heart_lighting_contract(plan):
    lights={l['name']:l for l in plan['lights'] if l['chapter']==8}
    require(len(lights)==6 and sum(l['chapter']==8 for l in plan['lights'])==6,'Heart lighting existing six sources')
    for light in lights.values():
        require(all(len(light[k])==3 and all(math.isfinite(x) and abs(x)<=200 for x in light[k]) for k in ('position','target')) and math.dist(light['position'],light['target'])>1,'Heart lighting finite aim')
        require(len(light['color'])==3 and all(math.isfinite(x) and 0<=x<=1 for x in light['color']) and
                math.isfinite(light['power']) and 100<=light['power']<=6500 and math.isfinite(light['size']) and .5<=light['size']<=9,'Heart lighting finite bounded source')
    key=lights['heart local key'];cool=lights['heart inhabited gallery upper shaft']
    require(all(l['color'][0]>l['color'][1]>l['color'][2] for l in lights.values() if l is not key and l is not cool),'Heart lighting amber practical hierarchy')
    require(key['color'][0]>=key['color'][1]>=key['color'][2]>=.5 and key['color'][1]>=.7*key['color'][0] and
            cool['color'][2]>cool['color'][1]>cool['color'][0]>=.4 and cool['color'][2]<=1.8*cool['color'][0] and
            key['power']>cool['power']>=2000 and sum(l['power'] for l in lights.values())<=16000,'Heart lighting warm focal/cool stone hierarchy')


def heart_skin_geometry(plan):
    from glb_inputs import node_point
    asset=next(a for a in plan['assets'] if a['id']=='heart_mouth_restraint')
    pin=json.loads((ROOT/'inputs.json').read_text())['assets'][asset['id']]
    root=plain_path(ROOT.parent/'intro-architecture-inputs02');path=plain_path(root/pin['path'])
    require(path.is_relative_to(root) and path.is_file() and path.stat().st_nlink==1,'Relief18 source boundary')
    raw=path.read_bytes()
    require(hashlib.sha256(raw).hexdigest()==pin['sha256'],'Relief18 changed source skin')
    length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
    node=next(n for n in doc['nodes'] if n['name']=='heart_mouth_restraint_bruised')
    primitive=doc['meshes'][node['mesh']]['primitives'][0]
    def read(index,fmt):
        a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']];offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt,binary,offset+i*view.get('byteStride',struct.calcsize('<'+fmt))) for i in range(a['count'])]
    raw_points=read(primitive['attributes']['POSITION'],'3f')
    index=primitive['indices'];fmt={5121:'B',5123:'H',5125:'I'}[doc['accessors'][index]['componentType']]
    indices=[i[0] for i in read(index,fmt)];vertices=[];lookup={};remap=[]
    for point in raw_points:
        if point not in lookup:
            lookup[point]=len(vertices);x,y,z=node_point(node,point);vertices.append(placed((x,-z,y),asset))
        remap.append(lookup[point])
    faces=[[remap[i] for i in indices[j:j+3]] for j in range(0,len(indices),3)]
    adjacency=[set() for _ in vertices]
    for face in faces:
        for i in face:adjacency[i].update(face)
    remaining=set(range(len(vertices)));components=[]
    while remaining:
        component={remaining.pop()};todo=list(component)
        while todo:
            for i in adjacency[todo.pop()]-component:component.add(i);remaining.discard(i);todo.append(i)
        components.append(component)
    component=max(components,key=len);mapping={i:j for j,i in enumerate(sorted(component))}
    vertices=[vertices[i] for i in sorted(component)];faces=[[mapping[i] for i in face] for face in faces if all(i in component for i in face)]
    lo,hi=bounds(vertices);require(hi[1]-lo[1]<min(hi[0]-lo[0],hi[2]-lo[2]),'Relief18 actual skin axial plane')
    cx,cz=(lo[0]+hi[0])/2,(lo[2]+hi[2])/2
    radial=lambda v:math.hypot(v[0]-cx,v[2]-cz)
    front=min((v for v in vertices if abs(v[1]-lo[1])<1e-5),key=radial)
    back=min((v for v in vertices if abs(v[1]-hi[1])<1e-5),key=radial)
    middle=min((v for v in vertices if lo[1]+1e-4<v[1]<hi[1]-1e-4),key=radial)
    return dict(vertices=vertices,faces=faces,center=[cx,cz],profile=[(radial(v),v[1]) for v in (front,middle,back)],phase=math.atan2(front[2]-cz,front[0]-cx),source_sha256=pin['sha256'])


def heart_relief(plan):
    skin=heart_skin_geometry(plan);cx,cz=skin['center'];front,middle,back=skin['profile']
    stations=[front,tuple((a+b)/2 for a,b in zip(front,middle)),middle,(back[0]+.12,back[1]-.1)]
    for j in range(24):
        angle=skin['phase']+(j+.5)*math.tau/24
        points=[[cx+(r+.04)*math.cos(angle+crimp),y,cz+(r+.04)*math.sin(angle+crimp)] for (r,y),crimp in zip(stations,(0,.028,-.024,.01))]
        plan['meshes'].append(tube(f'heart relief18 pleat {j}',8,points,.17+.035*(j%3),'heart_flesh',4))
    cuff=annulus('heart relief18 throat cuff',8,(cx,back[1]+.12,cz),back[0]-.3,back[0]+.4,0,math.tau,.8,16)
    cuff['material']='heart_flesh';plan['meshes'].append(cuff)


def skin_contains(skin,point):
    lo,hi=bounds(skin['vertices'])
    if not all(lo[k]<point[k]<hi[k] for k in range(3)):return False
    angle=0
    for face in skin['faces']:
        a,b,c=[sub(skin['vertices'][i],point) for i in face];la,lb,lc=[math.sqrt(dot(v,v)) for v in (a,b,c)]
        if min(la,lb,lc)<1e-9:return False
        angle+=2*math.atan2(dot(a,cross(b,c)),la*lb*lc+dot(a,b)*lc+dot(b,c)*la+dot(c,a)*lb)
    return abs(angle)>2*math.pi


def heart_relief_contract(plan):
    from collections import Counter
    ancestor=dict(plan,meshes=[m for m in plan['meshes'] if not m['name'].startswith('heart relief18 ')])
    require(hashlib.sha256(json.dumps(ancestor,sort_keys=True,separators=(',',':')).encode()).hexdigest()=='2f44c9aa9590ae3132768a028a531bf98767a231823da218b6f1180297cb761a','Relief18 original17 ancestry changed')
    skin=heart_skin_geometry(plan);parts=[m for m in plan['meshes'] if m['name'].startswith('heart relief18 ')]
    skin_edges=Counter(tuple(sorted((a,b))) for face in skin['faces'] for a,b in zip(face,face[1:]+face[:1]))
    require(all(n==2 for n in skin_edges.values()),'Relief18 original skin must be closed for winding contact')
    require(len(parts)==25,'Relief18 coherent 24 pleats and throat cuff required')
    triangles=sum(len(face)-2 for m in parts for face in m['faces']);require(triangles==804,'Relief18 804-triangle allowance')
    contacts=[]
    for m in parts:
        require(m['chapter']==8 and m['material']=='heart_flesh' and not m.get('pulse'),'Relief18 ownership/material')
        require(all(len(v)==3 and all(math.isfinite(x) for x in v) for v in m['vertices']),'Relief18 finite geometry')
        bounds(m['vertices'])
        require(min(math.hypot(v[0]-skin['center'][0],v[2]-skin['center'][1]) for v in m['vertices'])>=skin['profile'][-1][0]-.5,'Relief18 intentional central negative space')
        edges=Counter(tuple(sorted((a,b))) for face in m['faces'] for a,b in zip(face,face[1:]+face[:1]))
        volume=sum(dot(m['vertices'][face[0]],cross(m['vertices'][b],m['vertices'][c]))/6 for face in m['faces'] for b,c in zip(face[1:-1],face[2:]))
        require(edges and all(n==2 for n in edges.values()) and volume>.001,'Relief18 closed positive thickness')
        referenced={i for face in m['faces'] for i in face}
        count=sum(skin_contains(skin,m['vertices'][i]) for i in referenced)
        require(count>=2,'Relief18 referenced buried skin attachment');contacts.append(count)
    return dict(triangles=triangles,skin_vertices=len(skin['vertices']),buried_referenced_vertices=contacts)


GOTHIC20_NAMES = (
    {f'heart gothic20 gallery {side} {z} {part}' for side in ('rear','right') for z in (-32,-10) for part in ('stone','iron')}
    | {f'heart gothic20 cluster {side} {i} {part}' for side in ('rear','right') for i in range(3) for part in ('stone','binding')}
    | {f'heart gothic20 {part} {side} {z} {i}' for part in ('splay','tracery') for side in ('rear','right') for z in (-54,-32) for i in range(2)}
    | {f'heart gothic20 breach {i}' for i in range(4)} | {f'heart gothic20 rubble {i}' for i in range(28)}
    | {f'heart gothic20 hanging {i} {part}' for i in range(4) for part in ('chain','cage','cloth')})


def heart_gothic20(plan):
    """Layer connected lacework and broken near-field stone around the retained mouth."""
    put=plan['meshes'].append;rng=random.Random(732020)
    def assembly(name,parts,material='stone'):
        m=joined('heart gothic20 '+name,8,parts);m['material']=material;put(m)
    def place(m,side,center):return turned(m,center,0 if side=='rear' else math.pi/2)
    for side,span,count,center in (('rear',48,24,(38,30.9,0)),('right',42,21,(56.9,17,0))):
        for z in (-32,-10):
            stone=[];iron=[]
            for h,r in ((1.03,.24),(3.17,.22)):
                stone.append(tube('',8,[(-span/2,0,z+h),(span/2,0,z+h)],r,'stone',8))
            for i in range(count):
                x=-span/2+(i+.5)*2
                stone.append(opening('',8,(x,0,z+1.08),1.66,.86,1.87,.13,.42))
                iron.append(annulus('',8,(x,-.13,z+2.23),.22,.28,0,math.tau,.12,10))
                iron.append(tube('',8,[(x,-.13,z+2.47),(x,-.13,z+3.17)],.045,'iron',5))
                for dx in (-.95,.95):
                    iron.append(tube('',8,[(x+dx,-.05,z+1.1),(x+dx,-.05,z+3.18)],.045,'iron',5))
            assembly(f'gallery {side} {z} stone',[place(m,side,center) for m in stone])
            assembly(f'gallery {side} {z} iron',[place(m,side,center) for m in iron],'iron')
        for i,c in enumerate(((14,31.1,0),(38,31.1,0),(62,31.1,0)) if side=='rear' else ((58.9,-2,0),(58.9,17,0),(58.9,36,0))):
            stone=[];bindings=[]
            for j in range(7):
                a=j*math.pi/6;dx=.86*math.cos(a);dy=-.86*math.sin(a)
                stone.append(tube('',8,[(dx,dy,-54.1),(dx,dy,-9)],.26,'stone',10))
                for z in (-53.4,-32,-10):
                    stone.append(tube('',8,[(dx,dy,z-.4),(dx,dy,z+.4)],.39,'stone',8))
            for z in (-48,-39,-26,-16):
                bindings.append(tube('',8,[(-1.3,-.3,z),(0,-1.02,z-.18),(1.3,-.3,z)],.095,'brass',6))
            assembly(f'cluster {side} {i} stone',[place(m,side,c) for m in stone])
            assembly(f'cluster {side} {i} binding',[place(m,side,c) for m in bindings],'brass')
        for z in (-54,-32):
            for i,c in enumerate(((26,32.3,z),(50,32.3,z)) if side=='rear' else ((58.8,7.5,z),(58.8,26.5,z))):
                width=18 if side=='rear' else 13
                # Nested offsets splay toward the camera, not a flat applied facade.
                frames=[opening('',8,(0,-j*.28,0),width-.42*j,12,20-.24*j,.26,.65) for j in range(3)]
                assembly(f'splay {side} {z} {i}',[place(m,side,c) for m in frames])
                lace=[];w=(width-2.4)/3
                for j in (-1,0,1):lace.append(opening('',8,(j*w,-.9,11.7),w-.3,2.1,4.8,.18,.5))
                lace.append(tube('',8,[(-width/2+.25,-.9,11.75),(width/2-.25,-.9,11.75)],.22,'stone',8))
                lace.append(annulus('',8,(0,-.9,17.7),.78,1.06,0,math.tau,.5,20))
                for a in (0,math.pi/2,math.pi,math.pi*1.5):
                    lace.append(annulus('',8,(.44*math.cos(a),-.92,17.7+.44*math.sin(a)),.27,.38,0,math.tau,.36,10))
                assembly(f'tracery {side} {z} {i}',[place(m,side,c) for m in lace])
    # Flank the foreground steps; never bridge the existing loop/hero silhouette.
    for i,(a,b) in enumerate((((17.2,-7,-49.9),(17.2,-3,-48.9)),((17.2,-2.5,-48.9),(17.2,1.5,-47.8)),
                              ((23,-4.8,-50.8),(26,-4.8,-51)),((44,-4,-51),(50,-2,-50.8)))):
        m=cut_mass('heart gothic20 breach '+str(i),8,a,b,1.1,1.25)
        for j,v in enumerate(m['vertices']):
            if j%8 in (0,1):v[2]-=.18*(1+math.sin(j*1.8))
        put(m)
    for i in range(28):
        side=i%3
        x,y=(rng.uniform(17.7,19.6),rng.uniform(-5,2)) if side==0 else (rng.uniform(23,27),rng.uniform(-5.5,-4.2)) if side==1 else (rng.uniform(44,50),rng.uniform(-3,1))
        rx,ry=rng.uniform(.18,.62),rng.uniform(.18,.52);height=rng.uniform(.14,.48)
        put(foundation('heart gothic20 rubble '+str(i),8,(x,y,-50.96+height),rx,ry,height+.09,rng))
    for i,(x,y,top,bottom) in enumerate(((18,31.05,-31,-43),(46,31.05,-31,-40),(57.2,4,-31,-42),(57.2,29,-31,-39))):
        chain=[];cage=[]
        for j in range(14):
            z=top+(bottom+.8-top)*j/13
            link=annulus('',8,(0,0,0),.16,.205,0,math.tau,.07,8)
            for v in link['vertices']:v[2]*=2.8
            if j%2:
                link['vertices']=[[v[1],v[0],v[2]] for v in link['vertices']]
                link['faces']=[list(reversed(f)) for f in link['faces']]
            link['vertices']=[add(v,(x,y,z)) for v in link['vertices']];chain.append(link)
        for dz,r in ((0,.62),(.65,.75),(1.2,.26)):
            cage.append(tube('',8,arc((x,y,bottom+dz),r,0,math.tau,12,False),.065,'brass',6))
        for j in range(6):
            a=j*math.tau/6
            cage.append(tube('',8,[(x+.62*math.cos(a),y+.62*math.sin(a),bottom),
                                  (x+.75*math.cos(a),y+.75*math.sin(a),bottom+.65),(x+.26*math.cos(a),y+.26*math.sin(a),bottom+1.2)],.06,'brass',6))
        cage.append(tube('',8,[(x,y+.14,bottom+1.2),(x,y+.26,bottom+1.2)],.065,'brass',6))
        assembly(f'hanging {i} chain',chain,'iron');assembly(f'hanging {i} cage',cage,'brass')
        # Thick torn drapes, with no invented writing.
        outline=[(-1.15,0),(1.15,0),(1.05,-4.5),(.6,-4.05),(.23,-5),(-.1,-4.2),(-.55,-4.65),(-1.05,-3.9)]
        verts=[[x+dx,y+.9+dy,top+dz] for dy in (-.055,.055) for dx,dz in outline];n=len(outline)
        faces=[list(reversed(range(n))),list(range(n,2*n))]+[[j,(j+1)%n,(j+1)%n+n,j+n] for j in range(n)]
        put(dict(name=f'heart gothic20 hanging {i} cloth',chapter=8,material='vein',vertices=verts,faces=faces))


def solid_contact(mesh,support):
    """A referenced face centroid buried in the other solid proves contact."""
    solid=dict(vertices=support['vertices'],faces=[[f[0],b,c] for f in support['faces'] for b,c in zip(f[1:-1],f[2:])])
    return any(skin_contains(solid,[sum(mesh['vertices'][i][k] for i in face)/len(face) for k in range(3)])
               for face in mesh['faces'])


def heart_gothic20_contract(plan):
    parts=[m for m in plan['meshes'] if m['name'] in GOTHIC20_NAMES]
    require(len(parts)==len(GOTHIC20_NAMES) and {m['name'] for m in parts}==GOTHIC20_NAMES,'Gothic20 exact additions')
    require(all(m['chapter']==8 and not m.get('pulse') for m in parts),'Gothic20 chapter8 only')
    triangles=sum(len(f)-2 for m in parts for f in m['faces'])
    require(15000<triangles<=50000,'Gothic20 private authoring triangle allowance')
    ancestor=dict(plan,meshes=[m for m in plan['meshes'] if m['name'] not in GOTHIC20_NAMES])
    require(hashlib.sha256(json.dumps(ancestor,sort_keys=True,separators=(',',':')).encode()).hexdigest()==
            '800071f403a6088c68c1301587b6375bb84a4dc5f521ce1582d14470851cabe0','Gothic20 exact19 ancestry changed')
    by={m['name']:m for m in parts}
    for i in range(4):
        require(solid_contact(by[f'heart gothic20 hanging {i} cage'],by[f'heart gothic20 hanging {i} chain']),
                'Gothic20 cage/chain contact '+str(i))
    return ancestor


DEPTH22_NAMES = (
    {f'heart depth22 {side} room {z} {i} {part}' for side in ('rear','right') for z in (-54,-32)
     for i in range(2) for part in ('floor','backing','return -1','return 1','soffit','inner arch')}
    | {f'heart depth22 {side} {part}' for side in ('rear','right') for part in ('mezzanine','parapet','stair bearer')}
    | {f'heart depth22 {side} support {i}' for side in ('rear','right') for i in range(3)}
    | {f'heart depth22 {side} stair {i}' for side in ('rear','right') for i in range(16)}
    | {'heart depth22 right foundation'}
    | {f'heart depth22 foreground {part} {i}' for part in ('breach','fallen') for i in range(8)})


DEPTH22_SUPPORTS = (
    {'heart depth22 right foundation':('heart interior continuous raft',)}
    | {f'heart depth22 {side} room {z} {i} floor':
       (f'heart interior {side} occupied bond -32' if z==-32 else
        'heart interior continuous raft' if side=='rear' else 'heart depth22 right foundation',)
       for side in ('rear','right') for z in (-54,-32) for i in range(2)}
    | {f'heart depth22 {side} room {z} {i} {part}':
       (f'heart depth22 {side} room {z} {i} '+('backing' if part=='soffit' else 'floor'),)
       for side in ('rear','right') for z in (-54,-32) for i in range(2)
       for part in ('backing','return -1','return 1','soffit','inner arch')}
    | {f'heart depth22 {side} mezzanine':tuple(f'heart depth22 {side} support {i}' for i in range(3))
       for side in ('rear','right')}
    | {f'heart depth22 {side} support {i}':
       ('heart interior continuous raft' if side=='rear' else 'heart depth22 right foundation',)
       for side in ('rear','right') for i in range(3)}
    | {f'heart depth22 {side} stair bearer':
       (f'heart interior {side} occupied bond '+('-32' if side=='rear' else '-10'),f'heart depth22 {side} mezzanine')
       for side in ('rear','right')}
    | {f'heart depth22 {side} stair {i}':(f'heart depth22 {side} stair bearer',)
       for side in ('rear','right') for i in range(16)}
    | {f'heart depth22 {side} parapet':(f'heart depth22 {side} mezzanine',) for side in ('rear','right')}
    | {f'heart depth22 foreground {part} {i}':('heart interior foreground landing',)
       for part in ('breach','fallen') for i in range(8)})


def heart_depth22(plan):
    """Deep return chambers, staggered supported galleries and a broken near-field edge."""
    def put(mesh,supports):
        mesh['name']='heart depth22 '+mesh['name'];mesh['depth_supports']=list(supports)
        mesh['faces']=[[f[0],b,c] for f in mesh['faces'] for b,c in zip(f[1:-1],f[2:])]
        plan['meshes'].append(mesh)
    put(box('right foundation',8,(73,17,-64),(18,48,20)),['heart interior continuous raft'])
    for side in ('rear','right'):
        for z in (-54,-32):
            for i,x in enumerate((26,50) if side=='rear' else (-7.5,-26.5)):
                name=f'{side} room {z} {i} '
                # Right chambers rotate local depth into the outward positive X direction.
                transform=lambda m: m if side=='rear' else turned(m,(0,0,0),-math.pi/2)
                y=52 if side=='rear' else 74;width=18 if side=='rear' else 14
                depth=30 if side=='rear' else 26
                host='heart interior continuous raft' if side=='rear' else 'heart depth22 right foundation'
                if z==-32:host=f'heart interior {side} occupied bond -32'
                put(transform(box(name+'floor',8,(x,y,z),(width,depth,1))),[host])
                for part,c,size in (
                        ('backing',(x,y+depth/2-1,z+10),(width,1.2,20.6)),
                        ('return -1',(x-width/2+.4,y,z+10),(.9,depth,21)),
                        ('return 1',(x+width/2-.4,y,z+10),(.9,depth,21)),
                        ('soffit',(x,y,z+20),(width,depth,1.2))):
                    put(transform(box(name+part,8,c,size)),['heart depth22 '+name+('backing' if part=='soffit' else 'floor')])
                arch=opening(name+'inner arch',8,(x,y-5 if side=='rear' else y+7,z),width-3.2,9,16,.7,1.6)
                put(transform(arch),['heart depth22 '+name+'floor'])
        # Staggered floors descend from the old bonds on actual supported stair flights.
        if side=='rear':
            deck=box(side+' mezzanine',8,(38,52,-43),(44,4,1.4));piers=[(18,52),(38,52),(58,52)]
            a,b=(60,39,-32),(60,52,-43);host='heart interior rear occupied bond -32'
        else:
            deck=box(side+' mezzanine',8,(74,17,-21),(4,40,1.4));piers=[(74,-1),(74,17),(74,35)]
            a,b=(64,36,-10),(75.5,36,-21);host='heart interior right occupied bond -10'
        foundation='heart interior continuous raft' if side=='rear' else 'heart depth22 right foundation'
        for i,(x,y) in enumerate(piers):
            top=-43 if side=='rear' else -21
            put(box(f'{side} support {i}',8,(x,y,(-54+top)/2),(1.6,2,top+54+1)),[foundation])
        put(deck,[f'heart depth22 {side} support {i}' for i in range(3)])
        put(raked_deck(side+' stair bearer',8,a,b,3.2),[host,'heart depth22 '+side+' mezzanine'])
        for i in range(16):
            c=[a[k]+(b[k]-a[k])*(i+.5)/16 for k in range(3)]
            size=(3.4,1.05,1.4) if side=='rear' else (1.05,3.4,1.4)
            put(box(f'{side} stair {i}',8,c,size),['heart depth22 '+side+' stair bearer'])
        rail=box(side+' parapet',8,(38,53.6,-41.9) if side=='rear' else (75.6,17,-19.9),
                 (44,.65,1.3) if side=='rear' else (.65,40,1.3))
        put(rail,['heart depth22 '+side+' mezzanine'])
    # Ragged ends frame a breach without spanning the existing stair or mouth sightline.
    for i,(x,y) in enumerate(((18,-5),(18,-3),(18,-1),(18,1),(40,-2),(42,-2),(44,-2),(46,-2))):
        height=1.5+(i%3)*.55
        block=box(f'foreground breach {i}',8,(x,y,-51+height/2-.08),(1.7,2.15,height))
        for v in block['vertices']:
            if v[2]>-51:v[2]+=(v[0]-x)*(.35 if i%2 else -.3)
        put(block,['heart interior foreground landing'])
        fallen=turned(box(f'foreground fallen {i}',8,(0,0,0),(2.7,1.7,.8)),(x+.3,y+2.1,-50.73),.22*(i%3-1))
        put(fallen,['heart interior foreground landing'])


def heart_depth22_contract(plan):
    from collections import Counter
    parts=[m for m in plan['meshes'] if m['name'] in DEPTH22_NAMES]
    require(len(parts)==len(DEPTH22_NAMES) and {m['name'] for m in parts}==DEPTH22_NAMES,'Depth22 exact additions')
    ancestor=dict(plan,meshes=[m for m in plan['meshes'] if m['name'] not in DEPTH22_NAMES])
    require(hashlib.sha256(json.dumps(ancestor,sort_keys=True,separators=(',',':')).encode()).hexdigest()==
            'fa5b4159b6471c40711f2310b3e418493a653b3e2bb5cadd71f92fa7e0d3d9ba','Depth22 exact21 ancestry changed')
    require(1000<sum(len(m['faces']) for m in parts)<=3400,'Depth22 triangle allowance')
    by={m['name']:m for m in plan['meshes']}
    for m in parts:
        require(m['chapter']==8 and m['material'] in ('stone','iron') and not m.get('pulse'),'Depth22 geometry-only ownership')
        require(m.get('depth_supports')==list(DEPTH22_SUPPORTS[m['name']]),'Depth22 canonical supports '+m['name'])
        bounds(m['vertices'])
        require(all(len(f)==3 and all(isinstance(i,int) and 0<=i<len(m['vertices']) for i in f) for f in m['faces']),
                'Depth22 triangle topology')
        require({i for f in m['faces'] for i in f}==set(range(len(m['vertices']))),'Depth22 referenced vertices')
        edges=Counter((a,b) for f in m['faces'] for a,b in zip(f,f[1:]+f[:1]))
        volume=sum(dot(m['vertices'][f[0]],cross(m['vertices'][f[1]],m['vertices'][f[2]]))/6 for f in m['faces'])
        require(edges and all(n==1 and edges[b,a]==1 for (a,b),n in edges.items()) and volume>1e-5,'Depth22 closed outward thickness')
        owners={(a,b):i for i,f in enumerate(m['faces']) for a,b in zip(f,f[1:]+f[:1])}
        reached={0};pending=[0]
        while pending:
            face=m['faces'][pending.pop()]
            for a,b in zip(face,face[1:]+face[:1]):
                neighbor=owners[b,a]
                if neighbor not in reached:reached.add(neighbor);pending.append(neighbor)
        require(len(reached)==len(m['faces']),'Depth22 single face-edge shell '+m['name'])
        for f in m['faces']:
            a,b,c=[m['vertices'][i] for i in f];normal=cross(sub(b,a),sub(c,a))
            require(dot(normal,normal)>1e-12,'Depth22 finite nonzero normals')
        require(all(s in by and (solid_contact(m,by[s]) or solid_contact(by[s],m)) for s in DEPTH22_SUPPORTS[m['name']]),
                'Depth22 solid structural attachment '+m['name'])
    return ancestor


def heart_lighting24_recipe():
    """Heart-only side key, grazing rim, warm occupied depth and cool high windows."""
    def light(name,position,target,color,power,size):
        return dict(name=name,chapter=8,type='AREA',position=position,target=target,color=color,power=power,size=size)
    return dict(generation=24,world_strength=.35,overrides=[
        light('heart local key',[24,-3,-28],[31,9,-43],[1,.78,.58],3000,4.5),
        light('heart gallery lamp 0',[24,8,-47],[31,9,-43],[1,.40,.13],500,1.5),
        light('heart gallery lamp 1',[39,6,-40],[31,9,-43],[1,.63,.36],400,2),
        light('heart lower gallery amber',[35,28,-49],[41,36,-38],[1,.39,.12],900,3),
        light('heart inhabited gallery recess amber',[26,43,-50],[26,63,-44],[1,.43,.18],800,3),
        light('heart inhabited gallery upper shaft',[50,29,-15],[60,26,-32],[.50,.58,.80],1300,6),
    ],added=[
        light('heart lighting24 mouth rim',[42,13,-30],[31,9,-40],[1,.60,.36],2400,3),
        light('heart lighting24 mouth uplight',[25,3,-49],[31,9,-39],[1,.28,.09],950,2.5),
        light('heart lighting24 distant windows',[58,24,-12],[38,25,-31],[.43,.48,.82],2100,7),
        light('heart lighting24 rear lower chamber',[26,51,-48],[26,65,-44],[1,.34,.10],1300,3),
        light('heart lighting24 rear upper chamber',[50,51,-26],[50,65,-21],[1,.46,.20],1000,3),
        light('heart lighting24 right lower chamber',[73,8,-49],[83,8,-43],[1,.32,.09],1100,3),
        light('heart lighting24 right upper chamber',[73,26,-27],[83,26,-20],[1,.48,.22],850,3),
        light('heart lighting24 near bounce',[15,-12,-39],[31,9,-43],[.66,.72,.85],350,12),
    ])


def heart_lighting24_contract(plan):
    """Project only the validated generation24 extension; never repair baseline inputs."""
    recipe=plan.get('heart_lighting24')
    require(isinstance(recipe,dict) and set(recipe)=={'generation','world_strength','overrides','added'},'Lighting24 recipe fields')
    require(type(recipe['generation']) is int and recipe['generation']==24,'Lighting24 generation')
    def number(value,lo,hi):
        return type(value) in (int,float) and lo<=value<=hi and math.isfinite(value)
    require(number(recipe['world_strength'],.05,.7),'Lighting24 world strength')
    require(isinstance(recipe['overrides'],list) and len(recipe['overrides'])==6 and
            isinstance(recipe['added'],list) and 1<=len(recipe['added'])<=8,'Lighting24 source counts')
    records=recipe['overrides']+recipe['added'];names=[]
    fields={'name','chapter','type','position','target','color','power','size'}
    for r in records:
        require(isinstance(r,dict) and set(r)==fields,'Lighting24 source fields')
        require(isinstance(r['name'],str) and r['name'] not in names and type(r['chapter']) is int and r['chapter']==8 and r['type']=='AREA','Lighting24 source identity/type')
        names.append(r['name'])
        for key in ('position','target','color'):
            lo,hi=(0,1) if key=='color' else (-200,200)
            require(isinstance(r[key],list) and len(r[key])==3 and all(number(v,lo,hi) for v in r[key]),'Lighting24 finite bounded '+key)
        require(math.dist(r['position'],r['target'])>1 and number(r['power'],50,6500) and number(r['size'],.5,16),'Lighting24 finite bounded aim/power/size')
    expected={'heart local key','heart gallery lamp 0','heart gallery lamp 1','heart lower gallery amber',
              'heart inhabited gallery recess amber','heart inhabited gallery upper shaft'}
    allowed={'heart lighting24 '+suffix for suffix in ('mouth rim','mouth uplight','distant windows','rear lower chamber',
             'rear upper chamber','right lower chamber','right upper chamber','near bounce')}
    require({r['name'] for r in recipe['overrides']}==expected and {r['name'] for r in recipe['added']}<=allowed,'Lighting24 owned source IDs')
    require(sum(r['power'] for r in records)<=24000,'Lighting24 total power budget')
    baseline={k:v for k,v in plan.items() if k!='heart_lighting24'}
    require(hashlib.sha256(json.dumps(baseline,sort_keys=True,separators=(',',':')).encode()).hexdigest()==
            'f210f123565f98e3df64e37416c7bbd441819a1fca3b16fe6bf0bfb76461ab8b','Lighting24 exact23 baseline changed')
    return baseline


def apply_light_record(obj,record):
    from mathutils import Vector
    obj.data.type=record.get('type','AREA')
    obj.data.energy=record['power'];obj.data.color=record['color'];obj.data.shape='DISK';obj.data.size=record['size']
    obj.location=record['position']
    obj.rotation_euler=(Vector(record['target'])-obj.location).to_track_quat('-Z','Y').to_euler()


def heart_props25_meshes():
    """Small closed wax/flame/bracket shells and folded, torn hanging cloth."""
    parts=[]
    for i in range(7):
        x=21+i*3.3;z=-50.3;height=.52+.025*(i%3)
        wax=tube(f'heart route lantern {i}',8,[(x,0,z),(x,0,z+height*.68),(x,0,z+height)],.115,'bone',8)
        for j,v in enumerate(wax['vertices']):
            ring=j//8;scale=(1,.92,.73)[ring]
            v[0]=x+(v[0]-x)*scale;v[1]*=scale
            if ring==2:v[2]+=.018*math.sin(j*2.3+i)
        drips=[tube('',8,[(x+dx,-.075,z+height-.06),(x+dx,-.08,z+height-drop)],.026,'bone',5)
               for dx,drop in ((-.055,.28),(.045,.19))]
        wax=joined(wax['name'],8,[wax,*drips]);wax['material']='bone';parts.append(wax)
        name=f'heart props25 candle {i} '
        base=z+height
        parts.append(tube(name+'wick',8,[(x,0,base-.025),(x+.012,-.006,base+.075)],.014,'iron',4))
        flame=tube(name+'flame',8,[(x,0,base+.025),(x+.018,0,base+.135),(x+.055,0,base+.40)],.085,'amber',6)
        centers=((x,0),(x+.018,0),(x+.055,0))
        for j,v in enumerate(flame['vertices']):
            ring=j//6;cx,cy=centers[ring];scale=(.48,1,.035)[ring]
            v[0]=cx+(v[0]-cx)*scale;v[1]=cy+(v[1]-cy)*scale
        parts.append(flame)
        parts.append(tube(name+'bracket',8,[(x,.10,-51.04),(x,.10,z-.055),(x,-.015,z-.035)],.10,'iron',6))
    for i,(x,y,top) in enumerate(((18,31.05,-31),(46,31.05,-31),(57.2,4,-31),(57.2,29,-31))):
        vertices=[];faces=[];cols=7;rows=4
        hem=(3.9,4.65,4.2,5,4.05,4.5,4.2)
        for side in (-1,1):
            for row in range(rows):
                t=row/(rows-1)
                for col in range(cols):
                    dx=-1.15+2.3*col/(cols-1)
                    fold=.38*math.sin(col*2.05+i*.47)*(.35+.65*t)+.12*math.sin(t*math.pi+col)
                    vertices.append([x+dx*(1-.06*t)+.09*math.sin(t*3+i),y+.9+fold+side*.045,top-t*hem[col]])
        n=cols*rows
        for row in range(rows-1):
            for col in range(cols-1):
                a=row*cols+col;b=a+1;c=b+cols;d=a+cols
                faces.extend(([a,c,b],[a,d,c],[a+n,b+n,c+n],[a+n,c+n,d+n]))
        edge=list(range(cols))+[r*cols+cols-1 for r in range(1,rows)]+list(range(n-2,n-cols-1,-1))+[r*cols for r in range(rows-2,0,-1)]
        for a,b in zip(edge,edge[1:]+edge[:1]):faces.extend(([a,b,b+n],[a,b+n,a+n]))
        parts.append(dict(name=f'heart gothic20 hanging {i} cloth',chapter=8,material='vein',vertices=vertices,faces=faces))
    for m in parts:m['faces']=[[f[0],b,c] for f in m['faces'] for b,c in zip(f[1:-1],f[2:])]
    return parts


def heart_props25_originals():
    """Exact24 records used only for checked ancestry projection, never export."""
    parts=[]
    for i in range(7):
        p=add(ANCHORS[7],(-10+i*3.3,-7,.7))
        parts.append(tube(f'heart route lantern {i}',8,[p,add(p,(0,0,.7))],.12,'amber'))
    outline=[(-1.15,0),(1.15,0),(1.05,-4.5),(.6,-4.05),(.23,-5),(-.1,-4.2),(-.55,-4.65),(-1.05,-3.9)]
    for i,(x,y) in enumerate(((18,31.05),(46,31.05),(57.2,4),(57.2,29))):
        vertices=[[x+dx,y+.9+dy,-31+dz] for dy in (-.055,.055) for dx,dz in outline];n=len(outline)
        faces=[list(reversed(range(n))),list(range(n,2*n))]+[[j,(j+1)%n,(j+1)%n+n,j+n] for j in range(n)]
        parts.append(dict(name=f'heart gothic20 hanging {i} cloth',chapter=8,material='vein',vertices=vertices,faces=faces))
    return {m['name']:m for m in parts}


def heart_props25_contract(plan):
    """Certify exact owned shells, then expose the untouched exact24 ancestor."""
    from collections import Counter
    expected={m['name']:m for m in heart_props25_meshes()};originals=heart_props25_originals()
    parts=[m for m in plan['meshes'] if m['name'] in expected]
    require(len(parts)==len(expected) and {m['name']:m for m in parts}==expected,'Props25 exact authored objects')
    for m in parts:
        bounds(m['vertices'])
        edges=Counter((a,b) for f in m['faces'] for a,b in zip(f,f[1:]+f[:1]))
        volume=sum(dot(m['vertices'][f[0]],cross(m['vertices'][f[1]],m['vertices'][f[2]]))/6 for f in m['faces'])
        require(all(n==1 and edges[b,a]==1 for (a,b),n in edges.items()) and volume>1e-7,'Props25 closed outward shells '+m['name'])
        for f in m['faces']:
            a,b,c=[m['vertices'][i] for i in f];normal=cross(sub(b,a),sub(c,a))
            require(dot(normal,normal)>1e-14,'Props25 nondegenerate triangle '+m['name'])
    ancestor=dict(plan,meshes=[originals.get(m['name'],m) for m in plan['meshes'] if m['name'] not in expected or m['name'] in originals])
    require(hashlib.sha256(json.dumps(ancestor,sort_keys=True,separators=(',',':')).encode()).hexdigest()==
            'bf1319a1907fe668e22dac71cdeff9865ced157f5c9ac56681e41099c1d16d5e','Props25 exact24 ancestry changed')
    cam=plan['cameras']['heart'];forward=unit(sub(cam['target'],cam['position']))
    require(all(cam['near']<dot(sub(v,cam['position']),forward)<cam['far'] for m in parts for v in m['vertices']),
            'Props25 authored environment depth safety')
    delta=sum(len(f)-2 for m in parts for f in m['faces'])-sum(len(f)-2 for m in originals.values() for f in m['faces'])
    require(0<delta<=1382,'Props25 full-count triangle allowance')
    return ancestor


def heart_atmosphere26_recipe():
    """One thin violet scattering region; foreground candles stay outside the air box."""
    return dict(generation=26,name='heart atmosphere26 bounded air',chapter=8,
                material='heart_atmosphere26',visible_views=['heart','overview-8'],
                center=[48,36,-17.5],size=[80,64,67],
                shader='ShaderNodeVolumeScatter',density=.004,color=[.62,.52,.78,1],anisotropy=.25)


def heart_atmosphere26_mesh(recipe):
    return box(recipe['name'],recipe['chapter'],recipe['center'],recipe['size'],recipe['material'])


def heart_atmosphere26_contract(plan):
    """Validate the single extension, then expose exact25 without modifying it."""
    r=plan.get('heart_atmosphere26');expected=heart_atmosphere26_recipe()
    require(isinstance(r,dict) and set(r)==set(expected),'Atmosphere26 requested bounded air feature missing/fields')
    def number(v,lo,hi):return type(v) in (int,float) and lo<=v<=hi and math.isfinite(v)
    require(all(r[k]==expected[k] for k in expected if k not in ('density','color','anisotropy')),
            'Atmosphere26 exact ownership/visibility/bounds/shader')
    require(number(r['density'],.001,.008) and number(r['anisotropy'],0,.5),'Atmosphere26 bounded density/anisotropy')
    require(isinstance(r['color'],list) and len(r['color'])==4 and all(number(v,0,1) for v in r['color']) and
            r['color'][3]==1 and r['color'][2]>r['color'][0]>r['color'][1]>=.3,'Atmosphere26 bounded violet tint')
    parts=[m for m in plan['meshes'] if m['name']==r['name'] or m['material']==r['material']]
    require(parts==[heart_atmosphere26_mesh(r)],'Atmosphere26 single exact editable box')
    require(sum(len(f)-2 for f in parts[0]['faces'])==12,'Atmosphere26 twelve triangle ceiling')
    views=['title',*NAMES,*('overview-'+str(i) for i in range(1,9)),*('pulse-'+str(i) for i in range(1,9))]
    require([v for v in views if rendered(plan,v,r['chapter'],False,r['name'])]==r['visible_views'],
            'Atmosphere26 earned all25 view visibility')
    ancestor={k:v for k,v in plan.items() if k!='heart_atmosphere26'}
    ancestor['meshes']=[m for m in plan['meshes'] if m['name']!=r['name']]
    require(hashlib.sha256(json.dumps(ancestor,sort_keys=True,separators=(',',':')).encode()).hexdigest()==
            '25618efc1784c4e5d599326d6a8051cf4e91afde61482aef846dceefdec79be1','Atmosphere26 exact25 baseline changed')
    return ancestor


def make_plan():
    plan=open_section_plan()
    plan['meshes']=[m for m in plan['meshes'] if not any(s in m['name'] for s in
                    ('pierced distant arcade','distant occupied deck','receding arcade','title distant gallery deck'))]
    for ch,name,o,attachment in gallery_layout():masonry_gallery(plan,ch,name,o,attachment)
    plan['cameras']['heart']=dict(camera((13,-22,-48),(31,9,-43),50),type='PERSP',lens=30,sensor_width=36)
    heart_interior(plan)
    heart_lighting(plan)
    heart_relief(plan)
    heart_gothic20(plan)
    heart_depth22(plan)
    plan['heart_lighting24']=heart_lighting24_recipe()
    props={m['name']:m for m in heart_props25_meshes()}
    plan['meshes']=[props.pop(m['name'],m) for m in plan['meshes']]
    plan['meshes'].extend(props.values())
    plan['heart_atmosphere26']=heart_atmosphere26_recipe()
    plan['meshes'].append(heart_atmosphere26_mesh(plan['heart_atmosphere26']))
    return maw47.apply(plan)


def density_contract(plan):
    for ch,name,o,attachment in gallery_layout():
        piers=[m for m in plan['meshes'] if m['name'].startswith(name+' bearing pier ')]
        require(len(piers)==3,'Bearing gallery requires three actual masonry piers')
        floor=next((m for m in plan['meshes'] if m['name']==name+' foundation floor'),None)
        roof=next((m for m in plan['meshes'] if m['name']==name+' bearing roof'),None)
        require(floor is not None and roof is not None,'Bearing gallery floor/roof missing')
        flo,fhi=bounds(floor['vertices']);rlo,rhi=bounds(roof['vertices'])
        for pier in piers:
            lo,hi=bounds(pier['vertices'])
            require(pier['chapter']==ch and hi[2]-lo[2]>=40 and hi[1]-lo[1]>=8 and
                    lo[2]<=fhi[2] and hi[2]>=rlo[2] and
                    all(lo[k]<=fhi[k] and hi[k]>=flo[k] and lo[k]<=rhi[k] and hi[k]>=rlo[k] for k in (0,1)),
                    'Bearing gallery pier/floor/roof contact')
        deck=next((m for m in plan['meshes'] if m['name']==name+' attachment'),None)
        require(deck is not None,'Bearing gallery attachment contact')
        host_name=NAMES[ch-1]+' side landing -12' if ch else ('title west occupied gallery 0' if 'west' in name else 'title east occupied gallery 0')
        host=next(m for m in plan['meshes'] if m['name']==host_name)
        for indices,support in (((0,1,4,5),host),((2,3,6,7),floor)):
            points=[deck['vertices'][i] for i in indices];lo,hi=bounds(points);slo,shi=bounds(support['vertices'])
            require(all(slo[k]-.001<=v[k]<=shi[k]+.001 for v in points for k in (0,1)) and lo[2]<=shi[2] and hi[2]>=slo[2],
                    'Bearing gallery attachment contact')
        caps=[m for m in plan['meshes'] if m['name'].startswith(name+' fractured roof ')]
        roof_planes=[]
        for face in roof['faces']:
            a,b,c=[roof['vertices'][i] for i in face[:3]]
            roof_planes.append((a,unit(cross(sub(b,a),sub(c,a)))))
        # shortcut: edge-only contacts are not certified, extend if future cap generation needs them.
        contact=[]
        for cap in caps:
            points=[cap['vertices'][i] for face in cap['faces'] for i in face]
            contact.append(any(all(dot(sub(v,a),normal)<=1e-6 for a,normal in roof_planes) for v in points))
        require(len(caps)==3 and roof_planes and all(contact),'Bearing gallery broken roof contact')
        lamps=[l for l in plan['lights'] if l['name'].startswith(name+' ')]
        require(len(lamps)==2 and all(l['chapter']==ch and l['power']>0 for l in lamps) and lamps[0]['color'][0]>lamps[0]['color'][2] and lamps[1]['color'][2]>lamps[1]['color'][0],
                'Bearing gallery warm/cool owned recess lights')
        cam=camera(add(o,(0,-10,0)),add(o,(0,10,0)),50)
        blockers=projected_blockers(cam,[m for m in plan['meshes'] if m['chapter']==ch and not m.get('pulse')])
        for z in (-10,10):
            for x in (-7,7):
                require(first_blocker(projected(cam,add(o,(x,9,z))),blockers,cam['near']) is None,'Bearing gallery aperture must remain open')


def projected(cam,point):
    forward=unit(sub(cam['target'],cam['position']));right=unit(cross(forward,(0,0,1)));up=cross(right,forward)
    delta=sub(point,cam['position'])
    return [dot(delta,right),dot(delta,up),dot(delta,forward)]


def camera_valid(cam):
    require(cam.get('type','ORTHO') in ('ORTHO','PERSP'),'Unsupported camera type')
    values=cam['position']+cam['target']+[cam['scale'],cam['near'],cam['far']]
    require(all(math.isfinite(x) for x in values) and cam['scale']>0 and 0<cam['near']<cam['far'],'Finite camera bounds')
    require(math.dist(cam['position'],cam['target'])>1e-8 and math.hypot(*sub(cam['target'],cam['position'])[:2])>1e-8,'Finite camera orientation')
    if cam.get('type')=='PERSP':
        require(all(math.isfinite(cam[k]) and cam[k]>0 for k in ('lens','sensor_width')),'Finite perspective camera lens/sensor')
        ratio=cam['sensor_width']/cam['lens']
        require(math.isfinite(cam['far']*ratio) and cam['near']*ratio>0 and math.isfinite(1/(cam['near']*ratio)),'Finite perspective camera frustum')


def camera_ndc(cam,point,aspect=16/9):
    camera_valid(cam);require(math.isfinite(aspect) and aspect>0,'Finite camera aspect')
    x,y,depth=projected(cam,point)
    if cam.get('type')=='PERSP':
        if depth==0:return [.5,.5,0]
        width=depth*(cam['sensor_width']/cam['lens']);height=width/aspect
    else:height=cam['scale'];width=height*aspect
    return [.5+x/width,.5+y/height,depth]


def projected_blockers(cam,meshes):
    result=[]
    for m in meshes:
        if m['material'] in ('haze','glass','heart_atmosphere26'):continue
        vertices=[projected(cam,v) for v in m['vertices']];lo,hi=bounds(vertices)
        result.append((m['name'],lo,hi,vertices,m['faces']))
    return result


def first_blocker(sample,blockers,near=.1,perspective=False):
    if perspective:
        # Camera-space ray starts at the eye, not the orthographic near plane.
        for name,lo,hi,vertices,faces in blockers:
            if lo[2]>=sample[2]-.04 or hi[2]<=near:continue
            for face in faces:
                a=vertices[face[0]]
                for ib,ic in zip(face[1:-1],face[2:]):
                    e1=sub(vertices[ib],a);e2=sub(vertices[ic],a);h=cross(sample,e2);det=dot(e1,h)
                    if abs(det)<1e-10:continue
                    origin=sub((0,0,0),a);u=dot(origin,h)/det;q=cross(origin,e1);v=dot(sample,q)/det
                    depth=dot(e2,q)/det*sample[2]
                    if min(u,v,1-u-v)>=-1e-7 and near<depth<sample[2]-.04:return name
        return None
    x,y,depth=sample
    for name,lo,hi,vertices,faces in blockers:
        if not (lo[0]-1e-6<=x<=hi[0]+1e-6 and lo[1]-1e-6<=y<=hi[1]+1e-6 and lo[2]<depth-.04):continue
        for face in faces:
            a=vertices[face[0]]
            for ib,ic in zip(face[1:-1],face[2:]):
                b,c=vertices[ib],vertices[ic];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
                if abs(den)<1e-10:continue
                u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
                v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den;w=1-u-v
                if min(u,v,w)>=-1e-7 and near<u*a[2]+v*b[2]+w*c[2]<depth-.04:return name
    return None


def hero_visibility(plan,view='overview-8'):
    from glb_inputs import facts
    inventory=json.loads((ROOT/'inputs.json').read_text());visible(plan,view)
    cam=plan['cameras']['overview' if view.startswith(('overview-','pulse-')) else view];records=[]
    base=projected_blockers(cam,[m for m in plan['meshes'] if rendered(plan,view,m['chapter'],m.get('pulse',False),m['name'])])
    # Up to nine projected sectors, chosen from actual transformed GLB surface vertices.
    for asset in plan['assets']:
        if not rendered(plan,view,asset['chapter']):continue
        rec=inventory['assets'][asset['id']]
        points=facts(ROOT.parent/'intro-architecture-inputs02'/rec['path'],ROOT.parent/'intro-architecture-inputs02',points=True)['points']
        vertices=[projected(cam,placed(v,asset)) for v in points];chosen={}
        screen=[camera_ndc(cam,placed(v,asset)) for v in points] if cam.get('type')=='PERSP' else vertices
        lo,hi=bounds(screen)
        for v,pixel in zip(vertices,screen):
            cell=tuple(min(2,int(3*(pixel[k]-lo[k])/max(hi[k]-lo[k],1e-8))) for k in range(2))
            if cell not in chosen or v[2]<chosen[cell][2]:chosen[cell]=v
        meshes=[]
        # Conservative imported bounds also protect against supporting kit/another hero.
        for other in plan['assets']+plan['kit']:
            if other is asset or not rendered(plan,view,other['chapter']):continue
            l,h=bounds(asset_vertices(other));meshes.append(box('import '+other['id'],other['chapter'],[(l[k]+h[k])/2 for k in range(3)],[h[k]-l[k] for k in range(3)]))
        blockers=base+projected_blockers(cam,meshes);blocked=[first_blocker(v,blockers,cam['near'],cam.get('type')=='PERSP') for v in chosen.values()]
        records.append(dict(hero=asset['id'],chapter=asset['chapter'],samples=len(chosen),clear=sum(x is None for x in blocked),blockers=sorted(set(x for x in blocked if x))))
    return records


def span_open(mesh,route):
    side=unit(cross(sub(route['end'],route['start']),(0,0,1)))
    for t in (1/6,.5,5/6):
        point=[route['start'][k]+t*(route['end'][k]-route['start'][k])-(10 if k==2 else 0) for k in range(3)]
        cam=camera(add(point,[v*25 for v in side]),point,30)
        if first_blocker(projected(cam,point),projected_blockers(cam,[mesh]),cam['near']):return False
    return True


def title_gap_clear(plan):
    # Rays continue well behind the symbolic eclipse, excluding the intended eclipse itself.
    cam=plan['cameras']['title'];forward=unit(sub(cam['target'],cam['position']))
    meshes=[m for m in plan['meshes'] if m['chapter']==0 and not m['name'].startswith(('title eclipse','title recessed eclipse volume'))]
    blockers=projected_blockers(cam,meshes)
    return all(first_blocker(projected(cam,add((10,129,17),add((x,0,z),[v*90 for v in forward]))),blockers,cam['near']) is None for x,z in ((0,0),(-2,0),(2,0),(0,2),(0,-2)))


def bounds(vertices):
    require(vertices and all(len(v)==3 and all(math.isfinite(x) for x in v) for v in vertices),'Invalid finite vertices')
    return [[min(v[k] for v in vertices) for k in range(3)],[max(v[k] for v in vertices) for k in range(3)]]


def asset_vertices(a):
    return [placed(v,a) for v in itertools.product(*zip(*a['bounds']))]


def placed(vertex,asset):
    x,y,z=[vertex[k]*asset['scale'][k] for k in range(3)];a=asset.get('yaw',0)
    return add(asset['location'],(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a),z))


def mesh_uvs(part):
    """World-scale planar UVs; native atlas nodes wrap inside one material swatch."""
    uv=[]
    for face in part['faces']:
        a,b,c=[part['vertices'][i] for i in face[:3]];normal=cross(sub(b,a),sub(c,a))
        axis=max(range(3),key=lambda k:abs(normal[k]));axes=[k for k in range(3) if k!=axis]
        uv.extend([(part['vertices'][i][axes[0]]*.23,part['vertices'][i][axes[1]]*.23) for i in face])
    return uv


def framed(cam,vertices):
    camera_valid(cam)
    if cam.get('type')=='PERSP':
        return all(all(math.isfinite(x) for x in v) and cam['near']<projected(cam,v)[2]<cam['far'] and
                   all(.01<x<.99 for x in camera_ndc(cam,v)[:2]) for v in vertices)
    f=unit(sub(cam['target'],cam['position'])); right=unit(cross(f,(0,0,1))); up=cross(right,f)
    return all(cam['near']<dot(sub(v,cam['position']),f)<cam['far'] and
        abs(dot(sub(v,cam['position']),up))<cam['scale']*.49 and
        abs(dot(sub(v,cam['position']),right))<cam['scale']*16/9*.49 for v in vertices)


def tread_lands(tread,terrace):
    x,y=[sum(v[k] for v in tread['vertices'])/len(tread['vertices']) for k in range(2)]
    polygon=[terrace['vertices'][j] for j in terrace['faces'][1]]
    inside=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: inside=not inside
    component=set(terrace['faces'][1])
    while True:
        connected=set().union(*(set(face) for face in terrace['faces'] if component.intersection(face)))
        if connected==component:break
        component=connected
    low,high=bounds(tread['vertices']);bottom,top=bounds([terrace['vertices'][i] for i in component])
    return inside and low[2]<=top[2] and high[2]>=bottom[2]


def architecture_contract(plan):
    for ch in range(9):
        name='title foreground fracture' if ch==0 else NAMES[ch-1]+' fractured terrace'
        ground=next(m for m in plan['meshes'] if m['name']==name);lo,hi=bounds(ground['vertices'])
        require(hi[2]-lo[2]>=14,'Substantial cliff foundation required')
        require(any(a['chapter']==ch for a in plan['kit']),'Detailed original kit required per stage')
        openings=[m for m in plan['meshes'] if m['chapter']==ch and 'arcade opening' in m['name']]
        require(len(openings)>=(12 if ch==0 else 4),'Open structural enclosure required')
        require(len({round(min(v[2] for v in m['vertices'])) for m in openings})>=2,'Separate gallery elevations required')


def validate(plan):
    candidate47=plan
    plan=maw47.project(plan)
    authored=plan
    plan=heart_lighting24_contract(heart_props25_contract(heart_atmosphere26_contract(plan)))
    heart_surface_contract(HEART_SURFACE)
    require(plan['render']==RENDER,'Render settings')
    require([c['name'] for c in plan['chapters']]==list(NAMES),'Eight chapter identities')
    require(set(plan['cameras'])=={'overview','title',*NAMES},'Ten cameras')
    require(plan['reveals']==[list(range(1,n+1)) for n in range(1,9)],'Earned reveal privacy')
    require(len({m['name'] for m in plan['meshes']})==len(plan['meshes']),'Unique editable mesh names')
    require([(a['chapter'],a['id']) for a in plan['assets']]==list(enumerate(HEROES,1)),'Eight pinned heroes')
    require(all(plan['chapters'][i]['anchor'][2]>plan['chapters'][i+1]['anchor'][2] for i in range(7)),'Descending geography')
    signatures=[]; all_vertices=[]; triangles=0
    for mesh in plan['meshes']:
        require(mesh['material'] in PALETTE,'Material inventory'); bounds(mesh['vertices'])
        require(all(len(f)>=3 and all(isinstance(i,int) and 0<=i<len(mesh['vertices']) for i in f) for f in mesh['faces']),'Mesh topology')
        triangles+=sum(len(f)-2 for f in mesh['faces'])
    require(len(plan['routes'])==7,'Seven connections')
    for i,r in enumerate(plan['routes']):
        require(r==dict(chapter=i+2,start=add(ANCHORS[i],(4,-5,0)),end=add(ANCHORS[i+1],(-4,-5,0)),from_id=i+1,to_id=i+2),'Disconnected route')
        require(any(m['name']==f'descent {i+1} to {i+2} tread 0' for m in plan['meshes']),'Missing route geometry')
        treads=[m for m in plan['meshes'] if m['name'].startswith(f'descent {i+1} to {i+2} tread ')]
        centers=[[sum(v[k] for v in m['vertices'])/len(m['vertices'])+(.18 if k==2 else 0) for k in range(3)] for m in treads]
        for tread,ch in [(treads[0],i+1),(treads[-1],i+2)]:
            terrace=next((m for m in plan['meshes'] if m['name']==NAMES[ch-1]+' fractured terrace'),None)
            require(terrace is not None,'Missing landing contact terrace')
            require(tread_lands(tread,terrace),'Missing endpoint tread/terrace landing contact: '+tread['name'])
        require(math.dist(centers[0],r['start'])<=.41 and math.dist(centers[-1],r['end'])<=.41 and
                all(math.dist(a,b)<=.81 for a,b in zip(centers,centers[1:])),'Disconnected physical route treads')
    for ch in range(1,9):
        owned=[m for m in plan['meshes'] if m['chapter']==ch and not m.get('pulse')]
        require(len(owned)>12,'Distinct chapter geometry')
        signature=sorted((m['material'],len(m['vertices']),len(m['faces'])) for m in owned if not m['name'].startswith('descent '))
        require(signature not in signatures,'Repeated chamber silhouette'); signatures.append(signature)
        vertices=[v for m in owned for v in m['vertices']]
        local=[v for m in owned if not m['name'].startswith('descent ') for v in m['vertices']]
        for a in plan['assets']+plan.get('kit',[]):
            if a['chapter']==ch: local.extend(asset_vertices(a)); vertices.extend(asset_vertices(a))
        require(framed(plan['cameras'][NAMES[ch-1]],[v for a in plan['assets'] if a['chapter']==ch for v in asset_vertices(a)]),'Chapter camera framing '+NAMES[ch-1]); all_vertices.extend(vertices)
    require(framed(plan['cameras']['overview'],[v for a in plan['assets'] for v in asset_vertices(a)]+[v for m in plan['meshes'] if m['name'].startswith('descent ') for v in m['vertices']]),'Overview key subject framing')
    require(framed(plan['cameras']['title'],[v for m in plan['meshes'] if m['name'].startswith(('title technician','title handheld','title eclipse','title layered restraint','title breached causeway')) for v in m['vertices']]),'Title framing')
    inventory=json.loads((ROOT/'inputs.json').read_text())
    placements=plan['assets']+plan.get('kit',[])
    require(all(a['id'] in inventory['assets'] and 0<=a['chapter']<=8 and len(a['scale'])==3 and
                all(math.isfinite(v) and v>0 for v in a['scale']) and all(math.isfinite(v) for v in a['location']) and
                math.isfinite(a.get('yaw',0)) and abs(a.get('yaw',0)/(math.pi/2)-round(a.get('yaw',0)/(math.pi/2)))<1e-8
                for a in placements),'Finite quarter-turn import placements')
    triangles+=sum(inventory['assets'][a['id']]['triangles'] for a in placements); require(triangles<=300000,'Full scene triangle budget')
    for light in plan['lights']:
        require(all(math.isfinite(x) for x in light['position']+light['target']+light['color']+[light['power'],light['size']]),'Finite lights')
    for cam in plan['cameras'].values():
        camera_valid(cam)
    for ch in range(9):
        cam=plan['cameras']['title' if ch==0 else NAMES[ch-1]];forward=unit(sub(cam['target'],cam['position']))
        require(all(cam['near']<dot(sub(v,cam['position']),forward)<cam['far'] for m in plan['meshes'] if m['chapter']==ch for v in m['vertices']),'Environment depth safety')
    for i in range(7):
        spine=next((m for m in plan['meshes'] if m['name']==f'excavated spine {i+1}' and m['chapter']==i+2),None)
        require(spine is not None,'Continuous excavation spine required')
        lo,hi=bounds(spine['vertices'])
        require(spine.get('pierced') and hi[2]-lo[2]>20,'Continuous excavation must be pierced')
        require(all(lo[k]<=o[k]<=hi[k] for o in (plan['routes'][i]['start'],plan['routes'][i]['end']) for k in range(2)),'Continuous excavation endpoint coverage')
        require(span_open(spine,plan['routes'][i]),'Pierced span aperture')
    architecture_contract(plan)
    density_contract(plan)
    heart_interior_contract(plan)
    for view in ('overview-8',*NAMES):
        visibility=hero_visibility(plan,view)
        require(all(r['clear']==r['samples'] for r in visibility),'Hero occlusion '+view+': '+str([r for r in visibility if r['clear']!=r['samples']]))
    require(title_gap_clear(plan),'Open title eclipse gap')
    heart_lighting_contract(plan)
    heart_relief_contract(heart_gothic20_contract(heart_depth22_contract(plan)))
    triangles+=sum(len(f)-2 for m in authored['meshes'] for f in m['faces'])-sum(len(f)-2 for m in plan['meshes'] for f in m['faces'])
    require(triangles<=300000,'Atmosphere26 full scene triangle budget')
    for view in ('overview-8','heart'):
        require(all(r['clear']==r['samples'] for r in hero_visibility(authored,view)),'Props25 authored hero occlusion '+view)
    triangles+=4640-maw47.REMOVED
    require(triangles<=300000,'Maw47 full scene budget')
    return dict(triangles=triangles,editable_meshes=len(candidate47['meshes']),cameras=len(plan['cameras']),bounds=bounds(all_vertices+[v for m in authored['meshes'] for v in m['vertices']]),kit_placements=len(plan.get('kit',[])),
                imported_glb_bytes_per_placement=sum(inventory['assets'][a['id']]['bytes'] for a in placements),
                imported_image_payload_bytes_per_placement=sum(i['bytes'] for a in placements for i in inventory['assets'][a['id']].get('images',[])),
                decoded_rgba_bytes_per_placement=sum(i['decoded_rgba_bytes'] for a in placements for i in inventory['assets'][a['id']].get('images',[])))


def plain_path(value):
    path=Path(value); require('..' not in path.parts and '~' not in path.parts,'Path traversal/alias'); path=path.absolute()
    require(not any(p.is_symlink() for p in (path,*path.parents)),'Symlinked path'); return path


def fresh_output(path,input_root):
    path=plain_path(path); source=plain_path(input_root)
    require(not path.exists() and path.parent.is_dir(),'Fresh output required')
    require(path!=source and path not in source.parents and source not in path.parents,'Input/output overlap'); return path


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_inputs(input_root):
    from glb_inputs import facts
    root=plain_path(input_root); pins=json.loads((ROOT/'inputs.json').read_text())
    for rec in pins['assets'].values():
        path=plain_path(root/rec['path'])
        require(path.is_file() and path.stat().st_nlink==1 and sha(path)==rec['sha256'],'Changed asset '+rec['path'])
        actual=facts(path,root)
        require(actual['triangles']==rec['triangles'] and actual['materials']==rec['materials'] and actual['uv0_count']==rec['uv0_count'] and
                all(abs(actual['bounds'][i][k]-rec['bounds'][i][k])<1e-4 for i in range(2) for k in range(3)),'Pinned GLB geometry/material/UV facts changed')
        for image in rec.get('images',[]):
            if image.get('relative_path'):
                p=plain_path(root/image['relative_path']);require(p.is_file() and p.stat().st_nlink==1 and sha(p)==image['sha256'],'Changed pinned kit texture')
    return root,pins


def visible(plan,view):
    if view=='title': return {0},False
    for prefix,pulse in (('overview-',False),('pulse-',True)):
        if view.startswith(prefix):
            n=int(view[len(prefix):]); require(1<=n<=8,'Earned state')
            return ({n} if pulse else set(plan['reveals'][n-1])),pulse
    require(view in NAMES,'Unknown view'); return {NAMES.index(view)+1},False


def rendered(plan,view,chapter,pulse=False,name=''):
    chapters,show_pulse=visible(plan,view)
    return chapter in chapters and bool(pulse)==show_pulse and not (view in NAMES and name.startswith('descent '))


def set_view(scene,plan,view):
    heart_lighting24_contract(heart_props25_contract(heart_atmosphere26_contract(maw47.project(plan))))
    _,pulse=visible(plan,view); scene.render.film_transparent=pulse
    scene.camera=scene.objects['overview' if view.startswith(('overview-','pulse-')) else view]
    recipe=plan['heart_lighting24']
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=recipe['world_strength'] if view=='heart' else .7
    for record in plan['lights']:
        apply_light_record(scene.objects[record['name']],record)
    if view=='heart':
        for record in recipe['overrides']+recipe['added']:
            apply_light_record(scene.objects[record['name']],record)
    for obj in scene.objects:
        if obj.type!='CAMERA':
            obj.hide_render=(view!='heart') if obj.get('lighting24') else not rendered(plan,view,obj.get('chapter',-1),obj.get('pulse',False),obj.name)


def _portable_path(owner, name, value):
    # From pinned nursery-dependency-repair01 portable_path pattern; RNA retains NUL-tail bytes.
    limit = owner.bl_rna.properties[name].length_max
    if limit > 1:
        setattr(owner, name, (b'/' if isinstance(value, bytes) else '/') * (limit - 1))
    setattr(owner, name, value)


def sanitize_source_paths(bpy):
    for image in bpy.data.images:
        if not image.packed_file:
            continue
        relative = '//' + bpy.path.basename(image.filepath)
        _portable_path(image, 'filepath_raw', relative)
        for packed in image.packed_files:
            _portable_path(packed, 'filepath', relative)
    for scene in bpy.data.scenes:
        _portable_path(scene.render, 'filepath', '//')
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type == 'FILE_BROWSER' and space.params:
                    _portable_path(space.params, 'directory', b'//')


def verify_packed_paths(bpy):
    for image in bpy.data.images:
        if image.type=='IMAGE':
            require(image.packed_file and image.filepath.startswith('//'),'Packed relative image required')
            require(image.packed_files and all(item.filepath.startswith('//') for item in image.packed_files),'Every packed filepath must be relative')
    require(all(scene.render.filepath.startswith('//') for scene in bpy.data.scenes),'Portable render filepath required')


def source_privacy_evidence(bpy,scene,directory):
    verify_packed_paths(bpy)
    raw=plain_path(directory/'privacy-uncompressed.blend');require(not raw.exists(),'Fresh raw privacy copy required')
    # Verification only: reserialize reopened dependencies without changing the compressed source.
    bpy.data.libraries.write(str(raw),{scene},fake_user=True,compress=False)
    data=raw.read_bytes();require(data.startswith(b'BLENDER'),'Expected uncompressed Blender verification copy')
    markers=(b'/Users/',b'/home/',b'/private/',b'file://',b'\\Users\\',b'C:\\',b'C:/')
    require(not any(marker in data for marker in markers),'Private marker in uncompressed verification copy')
    return dict(raw_copy=raw.name,raw_sha256=sha(raw),raw_bytes=len(data),scope='reopened scene/dependencies reserialized uncompressed; not a scan of the compressed source stream')


HEART_SURFACE=dict(dark=(.205,.21,.215,1),light=(.32,.31,.285,1),mortar=(.045,.048,.05,1),
                   roughness=(.72,.98),coarse_scale=.45,grain_scale=12,bump_strength=.28,bump_distance=.018,
                   block_width=1.5,course_height=.6,mortar_size=.012,mortar_smooth=.008,
                   seam_warp=.012,mortar_strength=.65,mortar_distance=.035)


def heart_surface_contract(spec):
    for key in ('dark','light','mortar'):
        rgba=spec[key]
        require(len(rgba)==4 and all(math.isfinite(x) and 0<=x<=1 for x in rgba) and rgba[3]==1 and max(rgba[:3])-min(rgba[:3])<=.06,'Heart surface opaque low-chroma colour')
    require(all(math.isfinite(x) and .65<=x<=1 for x in spec['roughness']) and len(spec['roughness'])==2 and spec['roughness'][0]<spec['roughness'][1],'Heart surface roughness range')
    for key,low,high in (('coarse_scale',.05,2),('grain_scale',2,64),('bump_strength',0,1),('bump_distance',0,.15),
                         ('block_width',.6,2.4),('course_height',.25,.9),('mortar_size',.005,.025),
                         ('mortar_smooth',0,.02),('seam_warp',0,.02),('mortar_strength',0,1),('mortar_distance',0,.06)):
        require(math.isfinite(spec[key]) and low<spec[key]<=high,'Heart surface finite bounded '+key)
    require(spec['coarse_scale']<spec['grain_scale'],'Heart surface separate weathering scales')
    require(spec['block_width']>spec['course_height'] and spec['mortar_size']*2/spec['course_height']<=.08,'Heart surface human-scale courses and narrow joints')
    require(spec['seam_warp']<=spec['mortar_size'] and spec['mortar_smooth']<=spec['mortar_size'],'Heart surface subtle seam irregularity')


def authored_material_key(part):
    if part['chapter']!=8 or part.get('pulse',False):return part['material']
    if part.get('name','').endswith(' cloth'):return 'heart_cloth'
    return {'stone':'heart_weathered_stone','bone':'heart_bone','iron':'heart_iron',
            'brass':'heart_brass','vein':'heart_vein'}.get(part['material'],part['material'])


def heart_colour_ramp(nodes,name,stops):
    node=nodes.new('ShaderNodeValToRGB');node.name=name
    ramp=node.color_ramp;ramp.interpolation='EASE'
    for i,(position,colour) in enumerate(stops):
        element=ramp.elements[i] if i<2 else ramp.elements.new(position)
        element.position=position;element.color=colour
    return node


def heart_stone_material(bpy):
    spec=HEART_SURFACE;heart_surface_contract(spec)
    mat=bpy.data.materials.new('descent heart weathered stone');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF')
    shader.inputs['Metallic'].default_value=0;shader.inputs['Emission Strength'].default_value=0;shader.inputs['Alpha'].default_value=1
    coordinates=nodes.new('ShaderNodeNewGeometry');coordinates.name='Heart world units'
    coarse=nodes.new('ShaderNodeTexNoise');coarse.name='Heart mineral drift'
    grain=nodes.new('ShaderNodeTexNoise');grain.name='Heart aggregate'
    for noise,scale in ((coarse,spec['coarse_scale']),(grain,spec['grain_scale'])):
        noise.noise_dimensions='3D';noise.inputs['Scale'].default_value=scale
        noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.7
        links.new(coordinates.outputs['Position'],noise.inputs['Vector'])
    centered=nodes.new('ShaderNodeVectorMath');centered.operation='SUBTRACT';centered.inputs[1].default_value=(.5,.5,.5)
    warp=nodes.new('ShaderNodeVectorMath');warp.name='Heart seam irregularity';warp.operation='SCALE';warp.inputs['Scale'].default_value=spec['seam_warp']
    position=nodes.new('ShaderNodeVectorMath');position.operation='ADD'
    links.new(grain.outputs['Color'],centered.inputs[0]);links.new(centered.outputs['Vector'],warp.inputs[0])
    links.new(coordinates.outputs['Position'],position.inputs[0]);links.new(warp.outputs['Vector'],position.inputs[1])
    xyz=nodes.new('ShaderNodeSeparateXYZ');links.new(position.outputs['Vector'],xyz.inputs['Vector'])
    absolute=nodes.new('ShaderNodeVectorMath');absolute.operation='ABSOLUTE'
    normal=nodes.new('ShaderNodeSeparateXYZ')
    links.new(coordinates.outputs['True Normal'],absolute.inputs[0]);links.new(absolute.outputs['Vector'],normal.inputs['Vector'])
    x_wall=nodes.new('ShaderNodeMath');x_wall.operation='GREATER_THAN'
    maximum=nodes.new('ShaderNodeMath');maximum.operation='MAXIMUM'
    for node in (x_wall,maximum):
        links.new(normal.outputs['X'],node.inputs[0]);links.new(normal.outputs['Y'],node.inputs[1])
    floor=nodes.new('ShaderNodeMath');floor.operation='GREATER_THAN'
    links.new(normal.outputs['Z'],floor.inputs[0]);links.new(maximum.outputs[0],floor.inputs[1])
    projections=[]
    for a,b in (('X','Z'),('Y','Z'),('X','Y')):
        uv=nodes.new('ShaderNodeCombineXYZ');uv.name='Heart projection '+a+b
        links.new(xyz.outputs[a],uv.inputs['X']);links.new(xyz.outputs[b],uv.inputs['Y']);projections.append(uv)
    walls=nodes.new('ShaderNodeMix');walls.data_type='VECTOR';walls.name='Heart wall projection'
    mapped=nodes.new('ShaderNodeMix');mapped.data_type='VECTOR';mapped.name='Heart dominant projection'
    # Mix VECTOR uses scalar factor 0, vector A/B 4/5, and vector result 1.
    links.new(x_wall.outputs[0],walls.inputs[0]);links.new(projections[0].outputs['Vector'],walls.inputs[4]);links.new(projections[1].outputs['Vector'],walls.inputs[5])
    links.new(floor.outputs[0],mapped.inputs[0]);links.new(walls.outputs[1],mapped.inputs[4]);links.new(projections[2].outputs['Vector'],mapped.inputs[5])
    # shortcut: dominant-axis joins may break across oblique facets; upgrade only after native pixel review.
    brick=nodes.new('ShaderNodeTexBrick');brick.name='Heart ashlar courses';brick.offset=.5;brick.offset_frequency=2;brick.squash=1;brick.squash_frequency=2
    for socket,value in (('Scale',1),('Color1',spec['dark']),('Color2',spec['light']),('Mortar',spec['mortar']),
                         ('Brick Width',spec['block_width']),('Row Height',spec['course_height']),
                         ('Mortar Size',spec['mortar_size']),('Mortar Smooth',spec['mortar_smooth']),('Bias',0)):
        brick.inputs[socket].default_value=value
    links.new(mapped.outputs[1],brick.inputs['Vector']);links.new(brick.outputs['Color'],shader.inputs['Base Color'])
    rough=nodes.new('ShaderNodeValToRGB');rough.name='Heart pore roughness'
    for element,value in zip(rough.color_ramp.elements,spec['roughness']):element.color=(value,value,value,1)
    joints=nodes.new('ShaderNodeMixRGB');joints.name='Heart joint roughness';joints.blend_type='MIX'
    joints.inputs[2].default_value=(spec['roughness'][1],)*3+(1,)
    links.new(coarse.outputs['Fac'],rough.inputs['Fac']);links.new(rough.outputs['Color'],joints.inputs[1])
    links.new(brick.outputs['Fac'],joints.inputs[0]);links.new(joints.outputs['Color'],shader.inputs['Roughness'])
    bump=nodes.new('ShaderNodeBump');bump.name='Heart eroded normal'
    bump.inputs['Strength'].default_value=spec['bump_strength'];bump.inputs['Distance'].default_value=spec['bump_distance']
    mortar=nodes.new('ShaderNodeBump');mortar.name='Heart recessed mortar';mortar.invert=True
    mortar.inputs['Strength'].default_value=spec['mortar_strength'];mortar.inputs['Distance'].default_value=spec['mortar_distance']
    links.new(grain.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],mortar.inputs['Normal'])
    links.new(brick.outputs['Fac'],mortar.inputs['Height']);links.new(mortar.outputs['Normal'],shader.inputs['Normal'])
    mineral=heart_colour_ramp(nodes,'Heart soot and mineral',(
        (.22,(.027,.024,.021,1)),(.78,(.29,.265,.225,1)),(.5,(.115,.105,.09,1))))
    links.new(coarse.outputs['Fac'],mineral.inputs['Fac'])
    aggregate=heart_colour_ramp(nodes,'Heart exposed aggregate',((.2,(.62,.59,.55,1)),(.8,(1,1,1,1))))
    links.new(grain.outputs['Fac'],aggregate.inputs['Fac'])
    mottled=nodes.new('ShaderNodeMixRGB');mottled.name='Heart mineral face';mottled.blend_type='MULTIPLY';mottled.inputs[0].default_value=1
    links.new(mineral.outputs['Color'],mottled.inputs[1]);links.new(aggregate.outputs['Color'],mottled.inputs[2])
    dark=nodes.new('ShaderNodeMixRGB');dark.name='Heart darker course';dark.blend_type='MULTIPLY';dark.inputs[0].default_value=1
    dark.inputs[2].default_value=(.74,.72,.68,1);links.new(mottled.outputs['Color'],dark.inputs[1])
    links.new(mottled.outputs['Color'],brick.inputs['Color1']);links.new(dark.outputs['Color'],brick.inputs['Color2'])
    fractures=nodes.new('ShaderNodeTexVoronoi');fractures.name='Heart fracture pockets';fractures.feature='DISTANCE_TO_EDGE'
    fractures.inputs['Scale'].default_value=9;links.new(coordinates.outputs['Position'],fractures.inputs['Vector'])
    fissures=heart_colour_ramp(nodes,'Heart chipped mineral seams',((0,(.02,.02,.02,1)),(.055,(1,1,1,1))))
    links.new(fractures.outputs['Distance'],fissures.inputs['Fac'])
    weather=heart_colour_ramp(nodes,'Heart weathered pockets',((.42,(0,0,0,1)),(.68,(.8,.8,.8,1))))
    links.new(coarse.outputs['Fac'],weather.inputs['Fac'])
    erosion=nodes.new('ShaderNodeMixRGB');erosion.name='Heart selective spalling'
    links.new(weather.outputs['Color'],erosion.inputs[0]);links.new(grain.outputs['Fac'],erosion.inputs[1])
    links.new(fissures.outputs['Color'],erosion.inputs[2]);links.new(erosion.outputs['Color'],bump.inputs['Height'])
    return mat


# World-unit scales separate runoff/laminae from pores; no generated-coordinate stretching per mesh.
HEART_MATERIAL23={
    'heart_flesh':dict(colours=((.028,.0015,.004,1),(.12,.009,.018,1),(.31,.036,.046,1)),rough=(.2,.43),stretch=(1,1,.24),scale=3.2,pores=38,bump=.022),
    'heart_vein':dict(colours=((.018,.001,.003,1),(.085,.004,.011,1),(.22,.019,.032,1)),rough=(.18,.4),stretch=(1,1,.18),scale=4,pores=45,bump=.018),
    'heart_cloth':dict(colours=((.009,.002,.003,1),(.045,.006,.009,1),(.13,.023,.024,1)),rough=(.83,.98),stretch=(1,1,.12),scale=.9,pores=95,bump=.009),
    'heart_bone':dict(colours=((.105,.052,.019,1),(.34,.25,.135,1),(.63,.52,.335,1)),rough=(.46,.78),stretch=(1,1,.1),scale=4.5,pores=32,bump=.012),
    'heart_iron':dict(colours=((.072,.023,.009,1),(.013,.026,.024,1),(.065,.073,.078,1)),rough=(.78,.34),stretch=(1,1,.28),scale=1.6,pores=48,bump=.018),
    'heart_brass':dict(colours=((.014,.036,.029,1),(.085,.045,.014,1),(.38,.205,.062,1)),rough=(.79,.36),stretch=(1,1,.3),scale=1.8,pores=55,bump=.014),
}


def heart_surface_material(bpy,name):
    spec=HEART_MATERIAL23[name];organic=name in ('heart_flesh','heart_vein');metal=name in ('heart_iron','heart_brass')
    mat=bpy.data.materials.new('descent '+name+' surface23');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF')
    shader.inputs['Alpha'].default_value=1;shader.inputs['Emission Strength'].default_value=0
    coordinates=nodes.new('ShaderNodeNewGeometry');coordinates.name='Heart23 world units'
    stretched=nodes.new('ShaderNodeVectorMath');stretched.operation='MULTIPLY';stretched.inputs[1].default_value=spec['stretch']
    links.new(coordinates.outputs['Position'],stretched.inputs[0])
    strata=nodes.new('ShaderNodeTexNoise');strata.name='Heart23 directional strata'
    strata.inputs['Scale'].default_value=spec['scale'];strata.inputs['Detail'].default_value=3;strata.inputs['Roughness'].default_value=.7
    links.new(stretched.outputs['Vector'],strata.inputs['Vector'])
    pores=nodes.new('ShaderNodeTexNoise');pores.name='Heart23 pores'
    pores.inputs['Scale'].default_value=spec['pores'];pores.inputs['Detail'].default_value=2;pores.inputs['Roughness'].default_value=.7
    links.new(coordinates.outputs['Position'],pores.inputs['Vector'])
    surface=strata.outputs['Fac']
    if organic or name=='heart_cloth':
        layers=nodes.new('ShaderNodeTexWave');layers.name='Heart23 laminae' if organic else 'Heart23 cloth fibres'
        layers.wave_type='BANDS';layers.bands_direction='Z' if organic else 'X'
        for key,value in (('Scale',5 if organic else 85),('Distortion',6 if organic else .7),('Detail',2),('Detail Scale',1.5)):
            layers.inputs[key].default_value=value
        links.new(stretched.outputs['Vector'],layers.inputs['Vector'])
        layered=nodes.new('ShaderNodeMixRGB');layered.name='Heart23 interrupted layers';layered.inputs[0].default_value=.24 if organic else .12
        links.new(surface,layered.inputs[1]);links.new(layers.outputs['Color'],layered.inputs[2]);surface=layered.outputs['Color']
    colours=heart_colour_ramp(nodes,'Heart23 material strata',tuple(zip((.23,.5,.77),spec['colours'])))
    links.new(surface,colours.inputs['Fac']);links.new(colours.outputs['Color'],shader.inputs['Base Color'])
    rough=heart_colour_ramp(nodes,'Heart23 roughness',tuple((x,(v,v,v,1)) for x,v in zip((.25,.75),spec['rough'])))
    links.new(strata.outputs['Fac'],rough.inputs['Fac']);links.new(rough.outputs['Color'],shader.inputs['Roughness'])
    micro=nodes.new('ShaderNodeBump');micro.name='Heart23 pore normal'
    micro.inputs['Strength'].default_value=.2;micro.inputs['Distance'].default_value=.006
    links.new(pores.outputs['Fac'],micro.inputs['Height'])
    relief=nodes.new('ShaderNodeBump');relief.name='Heart23 layered surface'
    relief.inputs['Strength'].default_value=.28 if organic else .34;relief.inputs['Distance'].default_value=spec['bump']
    links.new(surface,relief.inputs['Height']);links.new(micro.outputs['Normal'],relief.inputs['Normal']);links.new(relief.outputs['Normal'],shader.inputs['Normal'])
    if metal:
        oxide=heart_colour_ramp(nodes,'Heart23 exposed metal',((.32,(.18,.18,.18,1)),(.68,(.88,.88,.88,1))))
        links.new(strata.outputs['Fac'],oxide.inputs['Fac']);links.new(oxide.outputs['Color'],shader.inputs['Metallic'])
    if organic:
        shader.inputs['Subsurface Weight'].default_value=.045;shader.inputs['Subsurface Radius'].default_value=(1,.22,.12)
        shader.inputs['Subsurface Scale'].default_value=.08;shader.inputs['Coat Weight'].default_value=.18;shader.inputs['Coat Roughness'].default_value=.16
    return mat


def heart_import_materials(obj,chapter,materials):
    if chapter!=8:return
    replacements={'Bruised burgundy membrane':'heart_flesh','Warm ivory ossification':'heart_bone',
                  'Suture scar and cartilage':'heart_bone','Petrol industrial iron':'heart_iron','Worn rivet steel':'heart_iron'}
    for slot in obj.material_slots:
        if slot.material:
            name=slot.material.name
            if '.' in name and name.rsplit('.',1)[1].isdigit():name=name.rsplit('.',1)[0]
            if name in replacements:slot.material=materials[replacements[name]]


def heart_atmosphere26_material(bpy,recipe):
    mat=bpy.data.materials.new('descent '+recipe['material']);mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear()
    output=nodes.new('ShaderNodeOutputMaterial');output.name='Heart26 output'
    scatter=nodes.new(recipe['shader']);scatter.name='Heart26 scatter'
    for key in ('density','color','anisotropy'):scatter.inputs[key.title()].default_value=recipe[key]
    mat.node_tree.links.new(scatter.outputs['Volume'],output.inputs['Volume'])
    return mat


def native_build(input_root,bundle):
    import bpy
    from mathutils import Vector, Matrix
    root,pins=verify_inputs(input_root); plan=make_plan(); summary=validate(plan)
    out=fresh_output(ROOT/'native'/bundle,root); out.mkdir()
    scene=bpy.data.scenes.new('NULL CHOIR descent'); bpy.context.window.scene=scene
    scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=RENDER['samples']
    scene.cycles.seed=plan['seed']; scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED'; scene.render.threads=2
    scene.render.resolution_x=7680; scene.render.resolution_y=4320; scene.render.resolution_percentage=100
    scene.render.pixel_aspect_x=scene.render.pixel_aspect_y=1
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'; scene.render.image_settings.color_depth='8'
    scene.render.use_stamp=False; scene.world=bpy.data.worlds.new('Cold empty shaft'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.008,.012,.025,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7; scene.view_settings.view_transform='AgX'
    collections={}
    for ch in range(9):
        coll=bpy.data.collections.new('title' if ch==0 else f'{ch:02d}_{NAMES[ch-1]}'); scene.collection.children.link(coll); collections[ch]=coll
    materials={}
    for name,(rgba,metal,rough,emission) in PALETTE.items():
        mat=bpy.data.materials.new('descent '+name); mat.use_nodes=True; shader=mat.node_tree.nodes.get('Principled BSDF')
        for socket,value in [('Base Color',rgba),('Metallic',metal),('Roughness',rough),('Emission Color',rgba),('Emission Strength',emission)]: shader.inputs[socket].default_value=value
        if name=='glass':
            shader.inputs['Transmission Weight'].default_value=.82; shader.inputs['IOR'].default_value=1.42
        if name=='haze':
            transparent=mat.node_tree.nodes.new('ShaderNodeBsdfTransparent')
            volume=mat.node_tree.nodes.new('ShaderNodeVolumePrincipled');volume.inputs['Density'].default_value=.012
            volume.inputs['Color'].default_value=(.17,.2,.26,1);volume.inputs['Anisotropy'].default_value=.2
            output=mat.node_tree.nodes.get('Material Output')
            mat.node_tree.links.new(transparent.outputs[0],output.inputs['Surface']);mat.node_tree.links.new(volume.outputs['Volume'],output.inputs['Volume'])
        if name in ('stone','bone','iron','vein','brass'):
            noise=mat.node_tree.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=7
            bump=mat.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.23; bump.inputs['Distance'].default_value=.055
            mat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']); mat.node_tree.links.new(bump.outputs['Normal'],shader.inputs['Normal'])
        materials[name]=mat
    materials['heart_weathered_stone']=heart_stone_material(bpy)
    materials.update({name:heart_surface_material(bpy,name) for name in HEART_MATERIAL23})
    materials['heart_atmosphere26']=heart_atmosphere26_material(bpy,plan['heart_atmosphere26'])
    maw47.materials(materials,plan['heart_maw47'])
    for part in plan['meshes']:
        mesh=bpy.data.meshes.new(part['name']); mesh.from_pydata(part['vertices'],[],part['faces']); mesh.update()
        for polygon in mesh.polygons:polygon.use_smooth=part['name'].startswith(('heart relief18 ',maw47.PREFIX))
        obj=bpy.data.objects.new(part['name'],mesh); collections[part['chapter']].objects.link(obj); mesh.materials.append(materials[part['material'] if part['name'].startswith(maw47.PREFIX) else authored_material_key(part)])
        uv=mesh.uv_layers.new(name='Architectural world-scale UV')
        for loop,value in zip(uv.data,mesh_uvs(part)):loop.uv=value
        obj['chapter']=part['chapter']; obj['pulse']=part.get('pulse',False)
    architectural_atlas=None
    for a in plan['assets']+plan['kit']:
        before=set(scene.objects); bpy.ops.import_scene.gltf(filepath=str(root/pins['assets'][a['id']]['path']))
        imported=set(scene.objects)-before; require(imported and all(o.type=='MESH' for o in imported),'Pinned hero must contain editable meshes only')
        placement=Matrix.Translation(a['location']) @ Matrix.Rotation(a.get('yaw',0),4,'Z') @ Matrix.Diagonal((*a['scale'],1))
        for obj in imported:
            obj.matrix_world=placement @ obj.matrix_world
            obj['chapter']=a['chapter']; obj['pulse']=False; obj['source_asset']=a['id']
            heart_import_materials(obj,a['chapter'],materials)
            collections[a['chapter']].objects.link(obj)
            if a['id']=='cathedral_corner_rib':
                architectural_atlas=next(node.image for slot in obj.material_slots for node in slot.material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
        bpy.context.view_layer.update()
        actual_bounds=bounds([list(obj.matrix_world @ Vector(corner)) for obj in imported for corner in obj.bound_box])
        expected=bounds(asset_vertices(a))
        require(all(abs(actual_bounds[i][k]-expected[i][k])<.001 for i in range(2) for k in range(3)),'Native imported bounds parity '+a['id'])
    maw47.replace_imports(scene,plan)
    require(architectural_atlas is not None,'Pinned cathedral atlas consumed')
    swatches={'stone':(0,.5),'bone':(.25,.5),'iron':(.5,.5),'brass':(.75,.5),'vein':(.5,0)}
    for name,(u,v) in swatches.items():
        mat=materials[name];nodes=mat.node_tree.nodes;links=mat.node_tree.links
        coordinates=nodes.new('ShaderNodeTexCoord');fraction=nodes.new('ShaderNodeVectorMath');fraction.operation='FRACTION'
        scaled=nodes.new('ShaderNodeVectorMath');scaled.operation='MULTIPLY';scaled.inputs[1].default_value=(.24,.49,1)
        offset=nodes.new('ShaderNodeVectorMath');offset.operation='ADD';offset.inputs[1].default_value=(u+.005,v+.005,0)
        texture=nodes.new('ShaderNodeTexImage');texture.image=architectural_atlas;texture.interpolation='Closest'
        links.new(coordinates.outputs['UV'],fraction.inputs[0]);links.new(fraction.outputs['Vector'],scaled.inputs[0])
        links.new(scaled.outputs['Vector'],offset.inputs[0]);links.new(offset.outputs['Vector'],texture.inputs['Vector'])
        desaturate=nodes.new('ShaderNodeHueSaturation');desaturate.inputs['Saturation'].default_value=.08 if name=='stone' else .48
        links.new(texture.outputs['Color'],desaturate.inputs['Color']);links.new(desaturate.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    for r in plan['lights']+plan['heart_lighting24']['added']:
        data=bpy.data.lights.new(r['name'],r.get('type','AREA'))
        obj=bpy.data.objects.new(r['name'],data); collections[r['chapter']].objects.link(obj)
        apply_light_record(obj,r);obj['chapter']=r['chapter'];obj['pulse']=False
        if r in plan['heart_lighting24']['added']:obj['lighting24']=True
    for name,r in plan['cameras'].items():
        data=bpy.data.cameras.new(name); data.type=r.get('type','ORTHO')
        # The plan stores vertical span; Blender's landscape ortho scale is horizontal span.
        data.sensor_fit='HORIZONTAL'; data.ortho_scale=r['scale']*16/9
        if data.type=='PERSP':data.lens=r['lens'];data.sensor_width=r['sensor_width'];data.shift_x=0;data.shift_y=0
        data.clip_start=r['near']; data.clip_end=r['far']
        obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=r['position']
        obj.rotation_euler=(Vector(r['target'])-obj.location).to_track_quat('-Z','Y').to_euler()
    for image in bpy.data.images:
        if image.type=='IMAGE':
            image.pack()
    sanitize_source_paths(bpy)
    scene['recipe_sha256']=sha(Path(__file__)); scene['seed']=plan['seed']; set_view(scene,plan,'overview-8'); _portable_path(scene.render,'filepath','//overview-8.png')
    bpy.context.view_layer.update()
    actual=0;depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in scene.objects:
        if obj.type=='MESH':
            evaluated=obj.evaluated_get(depsgraph);mesh=evaluated.to_mesh()
            try:
                mesh.calc_loop_triangles();actual+=len(mesh.loop_triangles)
            finally:
                evaluated.to_mesh_clear()
    require(actual<=300000 and actual==summary['triangles'],'Native/shared-plan triangle budget parity')
    blend=out/'descent.blend'
    # Write only this scene and its dependencies, preserving any startup scene in memory.
    bpy.data.libraries.write(str(blend),{scene},fake_user=True,compress=True)
    require(blend.stat().st_size<=32*1024*1024,'Packed source budget')
    (out/'build.json').write_text(json.dumps(dict(kind='source-native',recipe_sha256=sha(Path(__file__)),inputs_sha256=sha(ROOT/'inputs.json'),inspection_recipe_sha256=sha(ROOT/'glb_inputs.py'),plan=summary,
        heart_lighting24=plan['heart_lighting24'],heart_atmosphere26=plan['heart_atmosphere26'],
        heart_maw47=plan['heart_maw47'],maw47_source_sha256=sha(ROOT/'maw47.py'),maw47_mapping_sha256=sha(ROOT/'inspect_glb.py'),
        ancestor26_sha256=sha(ROOT/'ancestor26.py'),actual_triangles=actual,blend_sha256=sha(blend),blend_bytes=blend.stat().st_size,rendered=False),indent=2)+'\n')


def open_native(bundle):
    import bpy
    directory=plain_path(ROOT/'native'/bundle); blend=plain_path(directory/'descent.blend')
    require(directory.is_dir() and blend.is_file(),'Build first'); receipt=json.loads(plain_path(directory/'build.json').read_text())
    require(sha(blend)==receipt['blend_sha256'] and sha(Path(__file__))==receipt['recipe_sha256'] and sha(ROOT/'inputs.json')==receipt['inputs_sha256'] and sha(ROOT/'glb_inputs.py')==receipt['inspection_recipe_sha256'],'Changed source/recipe/input inventory')
    for name,key in (('maw47.py','maw47_source_sha256'),('inspect_glb.py','maw47_mapping_sha256'),
                     ('ancestor26.py','ancestor26_sha256')):
        require(sha(ROOT/name)==receipt[key],'Changed mouth dependency '+name)
    bpy.ops.wm.open_mainfile(filepath=str(blend)); scene=bpy.data.scenes['NULL CHOIR descent']; bpy.context.window.scene=scene
    return directory,blend,scene


def native_render(bundle,view):
    import bpy
    directory,blend,scene=open_native(bundle)
    target=plain_path(directory/(view+'.png')); receipt_path=plain_path(directory/(view+'.json'))
    require(not target.exists() and not receipt_path.exists(),'Fresh render and receipt required'); set_view(scene,make_plan(),view)
    require(scene.render.resolution_x==7680 and scene.render.resolution_y==4320 and scene.render.resolution_percentage==100,'True master dimensions')
    scene.render.threads_mode='FIXED'; scene.render.threads=2; scene.cycles.device='CPU'; _portable_path(scene.render,'filepath','//'+target.name)
    bpy.ops.render.render(write_still=True,scene=scene.name)
    data=target.read_bytes(); require(data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(7680,4320),'Actual PNG raster dimensions')
    receipt_path.write_text(json.dumps(dict(kind='native-render',view=view,width=7680,height=4320,
        sha256=sha(target),bytes=target.stat().st_size,visual_quality='NOT RUN'),indent=2)+'\n')


def native_props25_parity(scene,edited=False):
    """Check the exported prop geometry, UVs, materials and chapter ownership."""
    from mathutils import Matrix
    for part in heart_props25_meshes():
        obj=scene.objects.get(part['name'])
        require(obj is not None and obj.type=='MESH','Props25 native object '+part['name'])
        require(obj.get('chapter')==8 and not obj.get('pulse') and
                [c.name for c in obj.users_collection]==['08_heart'],'Props25 native chapter ownership')
        require(obj.matrix_world==Matrix.Identity(4) and not obj.modifiers,'Props25 native unmodified editable mesh')
        mesh=obj.data
        require(len(mesh.vertices)==len(part['vertices']) and
                [list(f.vertices) for f in mesh.polygons]==part['faces'],'Props25 native topology parity')
        for i,(vertex,expected) in enumerate(zip(mesh.vertices,part['vertices'])):
            target=add(expected,(.125,0,0)) if edited and i==0 else expected
            require(max(abs(vertex.co[k]-target[k]) for k in range(3))<1e-5,'Props25 native vertex parity '+part['name'])
        material=authored_material_key(part)
        require(len(mesh.materials)==1 and mesh.materials[0].name=='descent '+material+(' surface23' if material in HEART_MATERIAL23 else ''),
                'Props25 native material parity')
        uv=mesh.uv_layers.get('Architectural world-scale UV');expected_uv=mesh_uvs(part)
        require(uv is not None and len(uv.data)==len(expected_uv) and
                all(max(abs(loop.uv[k]-value[k]) for k in range(2))<1e-5 for loop,value in zip(uv.data,expected_uv)),
                'Props25 native UV parity')


def native_props25_verify(bpy,scene,directory,blend):
    """Edit a fresh private copy only; prove persistence and exact restoration."""
    scratch=plain_path(directory/'props25-edit-save-reopen.blend')
    reverted=plain_path(directory/'props25-reverted-save-reopen.blend')
    require(not scratch.exists() and not reverted.exists(),'Fresh Props25 persistent edit copies required')
    original_sha=sha(blend);names=[m['name'] for m in heart_props25_meshes()]
    native_props25_parity(scene)
    for name in names:scene.objects[name].data.vertices[0].co.x+=.125
    bpy.data.libraries.write(str(scratch),{scene},fake_user=True,compress=True)
    require(scratch.stat().st_size<=32*1024*1024,'Props25 edit copy packed size')
    bpy.ops.wm.open_mainfile(filepath=str(scratch));scene=bpy.data.scenes['NULL CHOIR descent'];bpy.context.window.scene=scene
    native_props25_parity(scene,edited=True)
    for name in names:scene.objects[name].data.vertices[0].co.x-=.125
    native_props25_parity(scene)
    bpy.data.libraries.write(str(reverted),{scene},fake_user=True,compress=True)
    require(reverted.stat().st_size<=32*1024*1024,'Props25 reverted copy packed size')
    bpy.ops.wm.open_mainfile(filepath=str(reverted));scene=bpy.data.scenes['NULL CHOIR descent'];bpy.context.window.scene=scene
    native_props25_parity(scene);verify_packed_paths(bpy)
    require({o.name for o in scene.objects if o.type=='CAMERA'}=={'overview','title',*NAMES},'Props25 edit copy ten cameras')
    require(sha(blend)==original_sha,'Props25 persistent verification preserved original source bytes')
    return dict(objects=names,plan_native_parity=True,edit_save_reopen=True,revert_save_reopen=True,
                original_unchanged=True,scratch=scratch.name,scratch_sha256=sha(scratch),
                reverted=reverted.name,reverted_sha256=sha(reverted))


def native_atmosphere26_parity(scene,plan,edited=False):
    """Check actual mesh/material RNA, not a duplicate metadata claim."""
    from mathutils import Matrix
    r=plan['heart_atmosphere26'];part=heart_atmosphere26_mesh(r);obj=scene.objects.get(r['name'])
    require(obj is not None and obj.type=='MESH' and obj.get('chapter')==8 and obj.get('pulse') is False and
            [c.name for c in obj.users_collection]==['08_heart'],'Atmosphere26 native owner')
    require(obj.matrix_world==Matrix.Identity(4) and not obj.modifiers and not obj.constraints and
            obj.animation_data is None,'Atmosphere26 native editable transform')
    mesh=obj.data
    require(len(mesh.vertices)==8 and [list(f.vertices) for f in mesh.polygons]==part['faces'] and
            all(max(abs(v.co[k]-p[k]) for k in range(3))<1e-5 for v,p in zip(mesh.vertices,part['vertices'])),
            'Atmosphere26 native exact box')
    require(len(mesh.materials)==1 and mesh.materials[0].name=='descent '+r['material'] and
            mesh.materials[0].use_nodes,'Atmosphere26 native one volume material')
    mat=mesh.materials[0]
    require([o.name for o in scene.objects if o.type=='MESH' and mat in list(o.data.materials)]==[r['name']],
            'Atmosphere26 native single volume owner')
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    scatter=nodes.get('Heart26 scatter');output=nodes.get('Heart26 output')
    require(len(nodes)==2 and scatter is not None and output is not None and scatter.bl_idname==r['shader'] and
            output.bl_idname=='ShaderNodeOutputMaterial' and output.is_active_output and output.target=='ALL' and
            len(links)==1 and links[0].from_node==scatter and links[0].from_socket.name=='Volume' and
            links[0].to_node==output and links[0].to_socket.name=='Volume' and
            not scatter.mute and not output.mute and mat.node_tree.animation_data is None,
            'Atmosphere26 native exact volume-only shader recipe')
    density=r['density']*1.5 if edited else r['density']
    require(abs(scatter.inputs['Density'].default_value-density)<1e-7 and
            abs(scatter.inputs['Anisotropy'].default_value-r['anisotropy'])<1e-7 and
            all(abs(a-b)<1e-7 for a,b in zip(scatter.inputs['Color'].default_value,r['color'])),
            'Atmosphere26 native density/tint/anisotropy RNA')
    return obj,scatter


def native_atmosphere26_no_touch(scene,plan):
    """Fingerprint every other mesh, camera and light across private edit copies."""
    records={}
    for obj in scene.objects:
        if obj.name==plan['heart_atmosphere26']['name']:continue
        r=dict(type=obj.type,matrix=[list(row) for row in obj.matrix_world],chapter=obj.get('chapter'),
               pulse=obj.get('pulse'),collections=sorted(c.name for c in obj.users_collection),
               hide_render=obj.hide_render,hide_viewport=obj.hide_viewport)
        data=obj.data
        if obj.type=='MESH':
            r.update(vertices=[list(v.co) for v in data.vertices],faces=[list(f.vertices) for f in data.polygons],
                     smooth=[f.use_smooth for f in data.polygons],
                     uv=[(uv.name,[list(v.uv) for v in uv.data]) for uv in data.uv_layers],
                     materials=[m.name if m else None for m in data.materials])
        elif obj.type=='CAMERA':
            r.update({k:getattr(data,k) for k in ('type','lens','sensor_width','sensor_height','sensor_fit','ortho_scale','clip_start','clip_end','shift_x','shift_y')})
        elif obj.type=='LIGHT':
            r.update(type=data.type,energy=data.energy,color=list(data.color),shape=data.shape,size=data.size)
        records[obj.name]=hashlib.sha256(json.dumps(r,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    records['world_strength']=scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value
    records['render']=[scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,
                       scene.render.pixel_aspect_x,scene.render.pixel_aspect_y,scene.render.engine,scene.cycles.samples]
    return records


def native_atmosphere26_view_mask(scene,plan,view):
    checked=0
    for obj in scene.objects:
        if obj.type=='CAMERA':continue
        expected=(view=='heart') if obj.get('lighting24') else rendered(plan,view,obj.get('chapter',-1),obj.get('pulse',False),obj.name)
        require(obj.hide_render==(not expected),'Atmosphere26 actual all25 native view mask '+view+' '+obj.name)
        checked+=1
    obj=scene.objects[plan['heart_atmosphere26']['name']]
    require(obj.hide_render==(view not in plan['heart_atmosphere26']['visible_views']),
            'Atmosphere26 native earned volume visibility '+view)
    return checked


def native_atmosphere26_views(scene,plan):
    views=['title',*NAMES,*('overview-'+str(i) for i in range(1,9)),*('pulse-'+str(i) for i in range(1,9))]
    checked=0
    for view in views:
        set_view(scene,plan,view)
        checked+=native_atmosphere26_view_mask(scene,plan,view)
    set_view(scene,plan,'overview-8')
    return dict(views=views,objects_checked=checked)


def native_atmosphere26_verify(bpy,scene,directory,blend):
    """Parent-only live gate; never overwrite the canonical blend."""
    plan=make_plan();heart_atmosphere26_contract(maw47.project(plan));original_sha=sha(blend)
    scratch=plain_path(directory/'atmosphere26-density-edit.blend');reverted=plain_path(directory/'atmosphere26-reverted.blend')
    require(not scratch.exists() and not reverted.exists(),'Fresh Atmosphere26 private copies required')
    set_view(scene,plan,'overview-8');before=native_atmosphere26_no_touch(scene,plan)
    obj,scatter=native_atmosphere26_parity(scene,plan)
    native_atmosphere26_view_mask(scene,plan,'overview-8')
    # In-memory negative controls must fail before any private copy is saved.
    controls=[]
    def rejected(label,check):
        try:check()
        except ValueError:controls.append(label)
        else:raise ValueError('Atmosphere26 negative control accepted '+label)
    obj['chapter']=7
    try:rejected('owner',lambda:native_atmosphere26_parity(scene,plan))
    finally:obj['chapter']=8
    original=scatter.inputs['Density'].default_value;scatter.inputs['Density'].default_value=0
    try:rejected('density',lambda:native_atmosphere26_parity(scene,plan))
    finally:scatter.inputs['Density'].default_value=original
    nodes=obj.data.materials[0].node_tree.nodes;extra=nodes.new('ShaderNodeVolumeAbsorption')
    try:rejected('node recipe',lambda:native_atmosphere26_parity(scene,plan))
    finally:nodes.remove(extra)
    obj.hide_render=True
    rejected('visibility',lambda:native_atmosphere26_view_mask(scene,plan,'overview-8'))
    obj.hide_render=False;require(not obj.hide_render,'Atmosphere26 native toggle restore')
    views=native_atmosphere26_views(scene,plan)
    require(native_atmosphere26_no_touch(scene,plan)==before,'Atmosphere26 all25 masks restored exact scene')
    native_atmosphere26_parity(scene,plan)
    scatter.inputs['Density'].default_value=plan['heart_atmosphere26']['density']*1.5
    bpy.data.libraries.write(str(scratch),{scene},fake_user=True,compress=True)
    require(scratch.stat().st_size<=32*1024*1024,'Atmosphere26 private edit packed size')
    bpy.ops.wm.open_mainfile(filepath=str(scratch));scene=bpy.data.scenes['NULL CHOIR descent'];bpy.context.window.scene=scene
    obj,scatter=native_atmosphere26_parity(scene,plan,edited=True)
    require(native_atmosphere26_no_touch(scene,plan)==before,'Atmosphere26 persistent edit changed existing mesh/camera/light')
    scatter.inputs['Density'].default_value=plan['heart_atmosphere26']['density']
    bpy.data.libraries.write(str(reverted),{scene},fake_user=True,compress=True)
    require(reverted.stat().st_size<=32*1024*1024,'Atmosphere26 private revert packed size')
    bpy.ops.wm.open_mainfile(filepath=str(reverted));scene=bpy.data.scenes['NULL CHOIR descent'];bpy.context.window.scene=scene
    native_atmosphere26_parity(scene,plan);verify_packed_paths(bpy)
    require(native_atmosphere26_no_touch(scene,plan)==before,'Atmosphere26 persistent revert changed existing mesh/camera/light')
    require(sha(blend)==original_sha,'Atmosphere26 canonical source unchanged')
    return dict(actual_RNA=True,exact_shader=True,controls_rejected=controls,view_masks=views,
                edit_save_reopen=True,revert_save_reopen=True,all_existing_mesh_camera_light_unchanged=True,
                original_unchanged=True,scratch=scratch.name,scratch_sha256=sha(scratch),
                reverted=reverted.name,reverted_sha256=sha(reverted),rendered=False)


def native_verify(bundle):
    import bpy
    directory,blend,scene=open_native(bundle); before=sha(blend)
    target=plain_path(directory/'edit-revert.json'); require(not target.exists(),'Fresh edit/revert receipt required')
    subjects=[scene.objects[name+' fractured terrace'] for name in NAMES]+[scene.objects['title foreground fracture']]
    subjects.extend(next(o for o in scene.objects if o.get('source_asset')==hero) for hero in HEROES)
    for obj in subjects:
        vertex=obj.data.vertices[0]; original=vertex.co.copy(); vertex.co.x+=.125
        require(vertex.co!=original,'Editable source vertex'); vertex.co=original
        require(vertex.co==original,'Exact vertex revert')
    require(sha(blend)==before,'Edit/revert preserved original disk bytes')
    privacy=source_privacy_evidence(bpy,scene,directory)
    require(sha(blend)==before,'Privacy verification preserved original source bytes')
    require({o.name for o in scene.objects if o.type=='CAMERA'}=={'overview','title',*NAMES},'Reopened cameras')
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    projection=[];plan=make_plan()
    require(scene.render.pixel_aspect_x==scene.render.pixel_aspect_y==1 and scene.render.resolution_x/scene.render.resolution_y==16/9,'Native projection render aspect')
    for name,record in plan['cameras'].items():
        obj=scene.objects[name];frame=obj.data.view_frame(scene=scene)
        require(obj.data.type==record.get('type','ORTHO'),'Native camera type parity')
        if obj.data.type=='ORTHO':
            require(abs(max(v.y for v in frame)-min(v.y for v in frame)-record['scale'])<.001,'Native camera vertical span parity')
        else:
            require(obj.data.sensor_fit=='HORIZONTAL' and abs(obj.data.lens-record['lens'])<1e-6 and abs(obj.data.sensor_width-record['sensor_width'])<1e-6 and obj.data.shift_x==obj.data.shift_y==0,'Native perspective camera settings')
        require(abs(obj.data.clip_start-record['near'])<1e-5 and abs(obj.data.clip_end-record['far'])<1e-4,'Native camera clip parity')
        forward=unit(sub(record['target'],record['position']));right=unit(cross(forward,(0,0,1)));up=cross(right,forward)
        samples=[add(record['position'],[right[k]*x+up[k]*y+forward[k]*z for k in range(3)])
                 for x,y,z in ((0,0,.05),(1,2,-2),(0,0,2),(4,3,10),(-5,-2,30),(100,0,10),(0,0,701))]
        samples.extend(v for a in plan['assets'] if NAMES[a['chapter']-1]==name for v in asset_vertices(a))
        error=max(abs(a-b) for point in samples for a,b in zip(camera_ndc(record,point),world_to_camera_view(scene,obj,Vector(point))))
        require(error<.002,'Native world_to_camera_view projection parity '+name)
        projection.append(dict(camera=name,type=obj.data.type,samples=len(samples),max_error=error,aspect=16/9))
        if obj.data.type=='PERSP':
            original=(scene.render.resolution_x,scene.render.resolution_y)
            try:
                scene.render.resolution_x=scene.render.resolution_y=864
                square_error=max(abs(a-b) for point in samples for a,b in zip(camera_ndc(record,point,1),world_to_camera_view(scene,obj,Vector(point))))
                require(square_error<.002,'Native square-aspect perspective parity')
                projection.append(dict(camera=name,type=obj.data.type,samples=len(samples),max_error=square_error,aspect=1))
            finally:scene.render.resolution_x,scene.render.resolution_y=original
    edited_names=[o.name for o in subjects]
    props25=native_props25_verify(bpy,scene,directory,blend)
    _,_,scene=open_native(bundle)
    atmosphere26=native_atmosphere26_verify(bpy,scene,directory,blend)
    _,_,scene=open_native(bundle)
    mouth47=maw47.native_verify(bpy,scene,directory,blend,make_plan(),set_view)
    target.write_text(json.dumps(dict(mouth47=mouth47,kind='source-native',vertex_edit_reverted=True,edited_objects=edited_names,props25=props25,atmosphere26=atmosphere26,
        blend_unchanged=True,packed_relative_images=True,privacy=privacy,camera_projection=projection,edit_revert_scope='legacy subjects in-memory; Props25 geometry and Atmosphere26 density persistent private-copy edit/save/reopen/revert',rendered=False),indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('action',choices=('check','build','render','verify')); parser.add_argument('--input-root')
    parser.add_argument('--bundle',default='build01'); parser.add_argument('--view',default='overview-8'); parser.add_argument('--parent-released',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    require(args.bundle and args.bundle.replace('-','').isalnum(),'Simple bundle name')
    if args.action=='check':
        if args.input_root: verify_inputs(args.input_root)
        print(json.dumps(validate(make_plan()),indent=2)); return
    require(args.parent_released,'Native stage held for independent reviews and explicit parent release')
    if args.action=='build':
        require(args.input_root,'Input root required'); plain_path(ROOT/'native').mkdir(exist_ok=True); native_build(args.input_root,args.bundle)
    elif args.action=='render':
        visible(make_plan(),args.view); native_render(args.bundle,args.view)
    else:
        native_verify(args.bundle)


if __name__=='__main__': main()
