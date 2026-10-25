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


def make_plan():
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


def projected(cam,point):
    forward=unit(sub(cam['target'],cam['position']));right=unit(cross(forward,(0,0,1)));up=cross(right,forward)
    delta=sub(point,cam['position'])
    return [dot(delta,right),dot(delta,up),dot(delta,forward)]


def projected_blockers(cam,meshes):
    result=[]
    for m in meshes:
        if m['material'] in ('haze','glass'):continue
        vertices=[projected(cam,v) for v in m['vertices']];lo,hi=bounds(vertices)
        result.append((m['name'],lo,hi,vertices,m['faces']))
    return result


def first_blocker(sample,blockers,near=.1):
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
        vertices=[projected(cam,placed(v,asset)) for v in points];lo,hi=bounds(vertices);chosen={}
        for v in vertices:
            cell=tuple(min(2,int(3*(v[k]-lo[k])/max(hi[k]-lo[k],1e-8))) for k in range(2))
            if cell not in chosen or v[2]<chosen[cell][2]:chosen[cell]=v
        meshes=[]
        # Conservative imported bounds also protect against supporting kit/another hero.
        for other in plan['assets']+plan['kit']:
            if other is asset or not rendered(plan,view,other['chapter']):continue
            l,h=bounds(asset_vertices(other));meshes.append(box('import '+other['id'],other['chapter'],[(l[k]+h[k])/2 for k in range(3)],[h[k]-l[k] for k in range(3)]))
        blockers=base+projected_blockers(cam,meshes);blocked=[first_blocker(v,blockers,cam['near']) for v in chosen.values()]
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
    triangles+=sum(inventory['assets'][a['id']]['triangles'] for a in placements); require(triangles<=250000,'Full scene triangle budget')
    for light in plan['lights']:
        require(all(math.isfinite(x) for x in light['position']+light['target']+light['color']+[light['power'],light['size']]),'Finite lights')
    for cam in plan['cameras'].values():
        require(all(math.isfinite(x) for x in cam['position']+cam['target']+[cam['scale'],cam['near'],cam['far']]) and cam['scale']>0 and 0<cam['near']<cam['far'],'Finite camera bounds')
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
    for view in ('overview-8',*NAMES):
        visibility=hero_visibility(plan,view)
        require(all(r['clear']==r['samples'] for r in visibility),'Hero occlusion '+view+': '+str([r for r in visibility if r['clear']!=r['samples']]))
    require(title_gap_clear(plan),'Open title eclipse gap')
    return dict(triangles=triangles,editable_meshes=len(plan['meshes']),cameras=len(plan['cameras']),bounds=bounds(all_vertices),kit_placements=len(plan.get('kit',[])),
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
    _,pulse=visible(plan,view); scene.render.film_transparent=pulse
    scene.camera=scene.objects['overview' if view.startswith(('overview-','pulse-')) else view]
    for obj in scene.objects:
        if obj.type!='CAMERA':
            obj.hide_render=not rendered(plan,view,obj.get('chapter',-1),obj.get('pulse',False),obj.name)


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
    for part in plan['meshes']:
        mesh=bpy.data.meshes.new(part['name']); mesh.from_pydata(part['vertices'],[],part['faces']); mesh.update()
        obj=bpy.data.objects.new(part['name'],mesh); collections[part['chapter']].objects.link(obj); mesh.materials.append(materials[part['material']])
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
            collections[a['chapter']].objects.link(obj)
            if a['id']=='cathedral_corner_rib':
                architectural_atlas=next(node.image for slot in obj.material_slots for node in slot.material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
        bpy.context.view_layer.update()
        actual_bounds=bounds([list(obj.matrix_world @ Vector(corner)) for obj in imported for corner in obj.bound_box])
        expected=bounds(asset_vertices(a))
        require(all(abs(actual_bounds[i][k]-expected[i][k])<.001 for i in range(2) for k in range(3)),'Native imported bounds parity '+a['id'])
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
    for r in plan['lights']:
        data=bpy.data.lights.new(r['name'],'AREA'); data.energy=r['power']; data.color=r['color']; data.shape='DISK'; data.size=r['size']
        obj=bpy.data.objects.new(r['name'],data); collections[r['chapter']].objects.link(obj); obj.location=r['position']
        obj.rotation_euler=(Vector(r['target'])-obj.location).to_track_quat('-Z','Y').to_euler(); obj['chapter']=r['chapter']; obj['pulse']=False
    for name,r in plan['cameras'].items():
        data=bpy.data.cameras.new(name); data.type='ORTHO'
        # The plan stores vertical span; Blender's landscape ortho scale is horizontal span.
        data.sensor_fit='HORIZONTAL'; data.ortho_scale=r['scale']*16/9; data.clip_start=r['near']; data.clip_end=r['far']
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
    require(actual<=250000 and actual==summary['triangles'],'Native/shared-plan triangle budget parity')
    blend=out/'descent.blend'
    # Write only this scene and its dependencies, preserving any startup scene in memory.
    bpy.data.libraries.write(str(blend),{scene},fake_user=True,compress=True)
    require(blend.stat().st_size<=32*1024*1024,'Packed source budget')
    (out/'build.json').write_text(json.dumps(dict(kind='source-native',recipe_sha256=sha(Path(__file__)),inputs_sha256=sha(ROOT/'inputs.json'),inspection_recipe_sha256=sha(ROOT/'glb_inputs.py'),plan=summary,
        actual_triangles=actual,blend_sha256=sha(blend),blend_bytes=blend.stat().st_size,rendered=False),indent=2)+'\n')


def open_native(bundle):
    import bpy
    directory=plain_path(ROOT/'native'/bundle); blend=plain_path(directory/'descent.blend')
    require(directory.is_dir() and blend.is_file(),'Build first'); receipt=json.loads(plain_path(directory/'build.json').read_text())
    require(sha(blend)==receipt['blend_sha256'] and sha(Path(__file__))==receipt['recipe_sha256'] and sha(ROOT/'inputs.json')==receipt['inputs_sha256'] and sha(ROOT/'glb_inputs.py')==receipt['inspection_recipe_sha256'],'Changed source/recipe/input inventory')
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
    for name,record in make_plan()['cameras'].items():
        frame=scene.objects[name].data.view_frame(scene=scene)
        require(abs(max(v.y for v in frame)-min(v.y for v in frame)-record['scale'])<.001,'Native camera vertical span parity')
    target.write_text(json.dumps(dict(kind='source-native',vertex_edit_reverted=True,edited_objects=[o.name for o in subjects],
        blend_unchanged=True,packed_relative_images=True,privacy=privacy,edit_revert_scope='in-memory only; persistent edit/save/reopen/revert NOT RUN',rendered=False),indent=2)+'\n')


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
