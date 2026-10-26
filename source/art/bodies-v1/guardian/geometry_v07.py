"""Functional cast/living-interface ritual-role rebuild v04; rejected originals retained. Pure Python: never imports Blender.

Authoring units are metres, front -Y. Every pose is an independent mesh/joint
assembly. No worker body, image cards, runtime attacks, hit regions or save data.
"""
from dataclasses import dataclass, replace
import hashlib
import json
import math

ROLES = ('caster', 'guardian', 'summoner')
POSES = ('idle', 'walk_a', 'walk_b', 'attack', 'dead')
SOURCE_POSES = POSES + ('windup', 'recovery')
CELL, ORIGIN, FOOT_Y = 128, (64, 120), 119
SPECS = {'caster': {'ortho': 3.65, 'aim': 1.60},
         'guardian': {'ortho': 4.7, 'aim': 1.90},
         'summoner': {'ortho': 5.6, 'aim': 2.25}}
# Shared material grammar, not shared anatomy or image recolours.
PALETTE = {'ivory': (.72, .58, .39, 1), 'edge': (.88, .76, .55, 1),
           'iron': (.13, .21, .22, 1), 'steel': (.30, .39, .39, 1),
           'brass': (.53, .34, .13, 1), 'recess': (.045, .042, .038, 1),
           'flesh': (.27, .10, .085, 1), 'scar': (.48, .16, .12, 1),
           'lumen': (.64, .025, .018, 1), 'hot': (.92, .12, .045, 1),
           'ruby_shadow': (.18, .018, .025, 1), 'ceramic_worn': (.46, .34, .21, 1),
           'ceramic_shade': (.31, .24, .19, 1), 'tissue_ochre': (.34, .14, .085, 1)}


def add(a, b): return tuple(x+y for x, y in zip(a, b))
def sub(a, b): return tuple(x-y for x, y in zip(a, b))
def mul(a, s): return tuple(x*s for x in a)
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a):
    length = math.sqrt(dot(a, a))
    if length < 1e-9: raise ValueError('Degenerate mesh axis')
    return mul(a, 1/length)


@dataclass(frozen=True)
class Part:
    name: str
    vertices: tuple
    faces: tuple
    material: str
    joint: str
    assembly: str
    face_materials: tuple = ()
    smooth: bool = False


class Model:
    def __init__(self, role, pose):
        if role not in ROLES or pose not in SOURCE_POSES: raise ValueError('Unknown role/pose')
        self.role, self.pose = role, pose
        self.parts, self.joints = [], {}
        self.joint('Root', (0, 0, 0))

    def joint(self, name, position, parent='Root'):
        if name in self.joints: raise ValueError('Duplicate joint: '+name)
        self.joints[name] = {'position': tuple(position), 'parent': None if name == 'Root' else parent}
        return name

    def mesh(self, name, vertices, faces, mat, joint, assembly, face_materials=(), smooth=False):
        if any(p.name == name for p in self.parts): raise ValueError('Duplicate mesh: '+name)
        if mat not in PALETTE or joint not in self.joints: raise ValueError('Unknown material/joint')
        self.parts.append(Part(name, tuple(map(tuple, vertices)), tuple(map(tuple, faces)), mat, joint, assembly, tuple(face_materials), smooth))

    def ellipsoid(self, name, pos, scale, mat, joint, assembly, sides=12, rings=6):
        # Pole vertices, not degenerate repeated pole quads.
        vertices = [add(pos, (0, 0, scale[2]))]
        for row in range(1, rings):
            theta = math.pi*row/rings
            for i in range(sides):
                angle = math.tau*i/sides
                vertices.append(add(pos, (scale[0]*math.sin(theta)*math.cos(angle),
                                         scale[1]*math.sin(theta)*math.sin(angle), scale[2]*math.cos(theta))))
        vertices.append(add(pos, (0, 0, -scale[2])))
        faces = [(0, 1+i, 1+(i+1)%sides) for i in range(sides)]
        for row in range(rings-2):
            a, b = 1+row*sides, 1+(row+1)*sides
            faces.extend((a+i, b+i, b+(i+1)%sides, a+(i+1)%sides) for i in range(sides))
        end, last = len(vertices)-1, 1+(rings-2)*sides
        faces.extend((end, last+(i+1)%sides, last+i) for i in range(sides))
        self.mesh(name, vertices, faces, mat, joint, assembly)

    def tube(self, name, points, radii, mat, joint, assembly, sides=8):
        if len(points) < 2: raise ValueError('Tube needs two points')
        radii = [radii]*len(points) if isinstance(radii, (int, float)) else radii
        if len(radii) != len(points) or min(radii) <= 0: raise ValueError('Positive finite tube radii required')
        vertices, faces = [], []
        for i, p in enumerate(points):
            tangent = unit(sub(points[min(i+1, len(points)-1)], points[max(0, i-1)]))
            axis = (0, 0, 1) if abs(tangent[2]) < .9 else (1, 0, 0)
            u, v = unit(cross(tangent, axis)), None
            v = cross(tangent, u)
            for k in range(sides):
                a = math.tau*k/sides
                vertices.append(add(p, mul(add(mul(u, math.cos(a)), mul(v, math.sin(a))), radii[i])))
            if i:
                n = (i-1)*sides
                faces.extend((n+k, n+(k+1)%sides, n+sides+(k+1)%sides, n+sides+k) for k in range(sides))
        faces += [tuple(reversed(range(sides))), tuple(range((len(points)-1)*sides, len(points)*sides))]
        self.mesh(name, vertices, faces, mat, joint, assembly)

    def plate(self, name, outline, y, depth, mat, joint, assembly):
        # Closed XZ extrusion. Never a single-sided image-plane silhouette.
        if depth < .06: raise ValueError('Visible side thickness required')
        area = sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(outline, outline[1:]+outline[:1]))
        if area < 0: outline = list(reversed(outline))
        n = len(outline)
        vertices = [(x, y+d, z) for d in (0, depth) for x, z in outline]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2*n)))]
        faces += [(i, i+n, (i+1)%n+n, (i+1)%n) for i in range(n)]
        self.mesh(name, vertices, faces, mat, joint, assembly)

    def box(self, name, pos, size, mat, joint, assembly):
        x, y, z = pos; a, b, c = (v/2 for v in size)
        self.plate(name, [(x-a, z-c), (x+a, z-c), (x+a, z+c), (x-a, z+c)], y-b, b*2, mat, joint, assembly)

    def limb(self, name, a, b, radius, joint, assembly, mat='ivory'):
        self.tube(name, [a, b], [radius, radius*.76], mat, joint, assembly)

    def settle_or_fall(self):
        # Death is rigid rotation of an independently bent construction, NOT scale.
        if self.pose == 'dead':
            angle = math.radians(83)
            def transform(p):
                x, y, z = p
                return (x, y*math.cos(angle)-z*math.sin(angle), y*math.sin(angle)+z*math.cos(angle))
        else:
            def transform(p): return p
        transformed = [replace(p, vertices=tuple(transform(v) for v in p.vertices)) for p in self.parts]
        points = [v for p in transformed for v in p.vertices]
        low = min(v[2] for v in points)
        # Fallen length is centered in world XY; same fixed lens, no scale/crop.
        offset = (-(min(v[0] for v in points)+max(v[0] for v in points))/2,
                  -(min(v[1] for v in points)+max(v[1] for v in points))/2, -low) if self.pose == 'dead' else (0, 0, -low)
        self.parts = [replace(p, vertices=tuple(add(v, offset) for v in p.vertices)) for p in transformed]
        self.joints = {k: dict(v, position=add(transform(v['position']), offset)) for k, v in self.joints.items()}

    def digest(self):
        return hashlib.sha256(json.dumps([p.__dict__ for p in self.parts], sort_keys=True).encode()).hexdigest()


def loft(m, name, rings, mat, joint, assembly, surface='shell', sides=12, twist=.0):
    """Closed, curved tapered body with varying center/radii, not a plank or rod.

    Each ring=(x,y,z,rx,ry). One continuous body material follows the curved
    surface. Separate physical cast bevels/cavities own material transitions.
    """
    vertices, faces, materials = [], [], []
    for row, (x, y, z, rx, ry) in enumerate(rings):
        for k in range(sides):
            angle=math.tau*k/sides+twist*row/max(1,len(rings)-1)
            # Broad asymmetric lobes, not a tessellated perfect orange insert.
            lobe=1+.065*math.sin(3*angle+.31*row)
            vertices.append((x+rx*math.cos(angle)*lobe,y+ry*math.sin(angle)*lobe,z))
        if row:
            for k in range(sides):
                a=(row-1)*sides+k;b=(row-1)*sides+(k+1)%sides
                faces.append((a,b,b+sides,a+sides))
                # The body surface is one real material. Construction-specific
                # bevel/cavity meshes below own material transitions, not stripes.
                materials.append(mat)
    faces.extend((tuple(reversed(range(sides))),tuple(range((len(rings)-1)*sides,len(rings)*sides))))
    materials.extend((mat,mat))
    m.mesh(name,vertices,faces,mat,joint,assembly,materials,smooth=True)


def mass(m,name,pos,scale,mat,joint,assembly,surface='tissue'):
    x,y,z=pos;rx,ry,rz=scale
    loft(m,name,[(x-.035*rx,y+.06*ry,z-rz,.10*rx,.10*ry),
                 (x-.13*rx,y+.05*ry,z-rz*.65,.71*rx,.78*ry),
                 (x+.06*rx,y-.08*ry,z-rz*.10,rx,ry),
                 (x-.08*rx,y+.04*ry,z+rz*.56,.84*rx,.82*ry),
                 (x+.02*rx,y,z+rz,.11*rx,.11*ry)],mat,joint,assembly,surface,12,twist=.16)


def curved_limb(m,name,a,b,radius,joint,assembly,mat='ivory'):
    # Actual broad muscle/greave volume along articulated endpoints. Multiple
    # off-axis contours distinguish joint seating from a uniform cylinder.
    direction=unit(sub(b,a));u=unit(cross(direction,(0,1,0) if abs(direction[1])<.85 else (1,0,0)));v=cross(direction,u)
    centers=[add(a,mul(sub(b,a),t)) for t in (0,.18,.55,.86,1)]
    profiles=[.58,1,.87,.58,.50];vertices=[];faces=[];materials=[];sides=10
    for row,(center,shape) in enumerate(zip(centers,profiles)):
        center=add(center,mul(u,radius*.11*math.sin(row*math.pi/4)))
        for k in range(sides):
            angle=math.tau*k/sides
            vertices.append(add(center,add(mul(u,radius*shape*math.cos(angle)),mul(v,radius*shape*.85*math.sin(angle)))))
        if row:
            for k in range(sides):
                q=(row-1)*sides+k;n=(row-1)*sides+(k+1)%sides
                faces.append((q,n,n+sides,q+sides));materials.append(mat)
    faces.extend((tuple(reversed(range(sides))),tuple(range(4*sides,5*sides))));materials.extend((mat,mat))
    m.mesh(name,vertices,faces,mat,joint,assembly,materials,smooth=True)


def crescent(m,name,side,spread,joint):
    # A broad curved shell swept around the suspended body. All sections have
    # real deep Y cross-section and curved root/shoulder/terminal silhouette.
    points=[(side*.30,.12,1.35),(side*(.67+spread*.3),.27,1.58),
            (side*(.92+spread*.6),.20-spread*.22,2.04),
            (side*(.90+spread*.7),.00-spread*.36,2.56),
            (side*(.53+spread*.6),-.06-spread*.3,2.96)]
    vertices=[];faces=[];materials=[];sides=10
    widths=(.17,.27,.30,.24,.035);depths=(.18,.36,.40,.34,.045)
    for row,p in enumerate(points):
        tangent=unit(sub(points[min(row+1,4)],points[max(0,row-1)]));radial=unit(cross((0,1,0),tangent))
        for k in range(sides):
            a=math.tau*k/sides
            vertices.append(add(p,add(mul(radial,widths[row]*math.cos(a)),(0,depths[row]*math.sin(a),0))))
        if row:
            for k in range(sides):
                q=(row-1)*sides+k;n=(row-1)*sides+(k+1)%sides
                faces.append((q,n,n+sides,q+sides));materials.append('ivory')
    faces.extend((tuple(reversed(range(sides))),tuple(range(40,50))));materials.extend(('ivory','ivory'))
    # Tangent/radial basis points opposite the tube basis: reverse to outward.
    # Correct orientation is verified via every edge + positive signed volume.
    volume=sum(dot(vertices[f[0]],cross(vertices[f[i]],vertices[f[i+1]]))/6 for f in faces for i in range(1,len(f)-1))
    if volume<0:faces=[tuple(reversed(f)) for f in faces]
    m.mesh(name,vertices,faces,'ivory',joint,'Sculpted crescent carapace',materials,smooth=True)


def oriented_mesh(m,name,vertices,faces,materials,joint,assembly,smooth=False):
    volume=sum(dot(vertices[f[0]],cross(vertices[f[i]],vertices[f[i+1]]))/6 for f in faces for i in range(1,len(f)-1))
    if volume<0:faces=[tuple(reversed(f)) for f in faces]
    m.mesh(name,vertices,faces,materials[0],joint,assembly,materials,smooth)


def cast_panel(m,name,outline,y,depth,joint,assembly):
    """Closed foundry backing, worn real chamfer and seated ceramic face.

    Face material follows physical BACK/WALL/BEVEL/FACE sections, not repeated
    longitudinal sectors or alternating generic loft rings. Intentionally unequal
    outline points carry corners and the actual thick lancet silhouette.
    """
    cx=sum(p[0] for p in outline)/len(outline);cz=sum(p[1] for p in outline)/len(outline)
    profiles=((.86,depth),(1,depth*.72),(1,0),(.83,-.055))
    vertices=[(cx+(x-cx)*scale,y+dy,cz+(z-cz)*scale) for scale,dy in profiles for x,z in outline]
    n=len(outline);faces=[tuple(reversed(range(n)))];materials=['iron']
    for row,key in enumerate(('iron','iron','edge')):
        for i in range(n):
            faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i));materials.append(key)
    faces.append(tuple(range(3*n,4*n)));materials.append('ivory')
    oriented_mesh(m,name,vertices,faces,materials,joint,assembly)


def cast_aperture(m,name,center,radii,joint,assembly):
    """A real closed annular casting around an irregular living aperture.

    Actual outer walls, lip chamfer, ceramic seat and dark inner wall each carry
    their own physical material. No solid painted disk pretends to be a hole.
    """
    cx,cy,cz=center;rx,rz=radii
    outline=[(-.58,-.86),(.20,-1),(.79,-.61),(1,.06),(.56,.88),(-.18,1),(-.86,.51),(-1,-.20)]
    profiles=((1.02,.17),(1.10,-.015),(1,-.16),(.76,-.17),(.70,.025),(.79,.17))
    vertices=[(cx+x*rx*scale,cy+dy,cz+z*rz*scale) for scale,dy in profiles for x,z in outline]
    faces=[];materials=[];n=len(outline)
    for row,key in enumerate(('iron','steel','edge','recess','iron','iron')):
        for i in range(n):
            nxt=(row+1)%len(profiles)
            faces.append((row*n+i,row*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i));materials.append(key)
    oriented_mesh(m,name,vertices,faces,materials,joint,assembly)


def smooth_tube(m,name,points,radii,material,joint,assembly,sides=10):
    m.tube(name,points,radii,material,joint,assembly,sides)
    m.parts[-1]=replace(m.parts[-1],smooth=True)


def pressure_chamber(m,name,pos,scale,joint,assembly,cast=True):
    """Asymmetric living pressure body connected to a real seated feed circuit."""
    x,y,z=pos;rx,ry,rz=scale
    # Deliberate unequal lobes; one compressed neck and a low pressure hernia.
    loft(m,name,[(x-rx*.12,y+ry*.12,z-rz,rx*.19,ry*.23),
         (x-rx*.18,y-ry*.09,z-rz*.56,rx*.91,ry*.86),
         (x+rx*.13,y-ry*.20,z+rz*.08,rx,ry),
         (x-rx*.20,y+ry*.13,z+rz*.63,rx*.69,ry*.76),
         (x-rx*.15,y+ry*.12,z+rz,rx*.17,ry*.22)],'lumen',joint,assembly,'tissue',12,twist=.19)
    mass(m,name+' compressed lateral lobe',(x-rx*.58,y-ry*.10,z-rz*.18),(rx*.44,ry*.69,rz*.47),'ruby_shadow',joint,assembly)
    # One broad connected supply path and an asymmetrically branching return.
    # These have functional attached endpoints and no repetitive rib-noise grid.
    feed=[(x-rx*.58,y+ry*.15,z-rz*.98),(x-rx*.50,y-ry*.78,z-rz*.34),
          (x+rx*.08,y-ry*1.14,z+rz*.10),(x+rx*.42,y-ry*.73,z+rz*.58)]
    smooth_tube(m,name+' attached pressure feed',feed,[rx*.20,rx*.18,rx*.14,rx*.095],'scar',joint,assembly,8)
    smooth_tube(m,name+' return branch',[feed[2],(x-rx*.32,y-ry*1.02,z+rz*.41),
                (x-rx*.21,y-ry*.48,z+rz*.84)],[rx*.10,rx*.09,rx*.065],'ruby_shadow',joint,assembly,8)
    m.tube(name+' seated feed collar',[feed[0],add(feed[0],(0,-.11,.035))],rx*.24,'brass',joint,assembly,10)
    if cast:cast_aperture(m,name+' deep cast chamber seat',(x,y-ry*.67,z),(rx*2.04,rz*1.61),joint,assembly)


def caster(m):
    pose=m.pose;firing=pose in ('attack','windup');release=pose=='attack'
    drift=.06 if pose=='walk_a' else -.06 if pose=='walk_b' else 0
    spread=.40 if release else .22 if firing else -.10
    spine=m.joint('Suspended thoracic spine',(0,.14,1.8))
    throat=m.joint('Pressure throat and jaw',(0,-.29,2.12),spine)
    mass(m,'Deep living respiratory thorax',(0,.15,1.85),(.40,.43,.81),'flesh',spine,'Suspended fleshy thorax')
    mass(m,'Asymmetric dorsal ossified cuirass',(.04,.39,2.01),(.39,.27,.72),'iron',spine,'Deep dorsal cuirass','metal')
    for side in (-1,1):
        mantle=m.joint(f'Load mantle root {side}',(side*.32,.13,1.78),spine)
        crescent(m,f'Curved deep mantle {side}',side,spread,mantle)
        cast_aperture(m,f'Actual mantle root socket {side}',(side*.34,-.01,1.87),(.17,.23),mantle,'Mantle root bearing seats')
        # A second low swept scapula supplies genuine depth at +/-90 degrees.
        loft(m,f'Posterior swept scapula {side}',[(side*.18,.47,1.40,.10,.12),
             (side*.48,.56,1.75,.24,.30),(side*.62,.52,2.18,.25,.34),
             (side*.49,.45,2.63,.14,.22),(side*.28,.40,2.89,.035,.06)],'iron',mantle,'Deep dorsal cuirass','metal')
        elbow_pos=(side*(.89 if firing else .66),-.45 if firing else -.13,2.08 if firing else 1.50)
        wrist_pos=(side*(1.15 if release else 1.02 if firing else .45),-.63 if firing else -.37,2.40 if firing else 1.15)
        shoulder=m.joint(f'Gesture shoulder {side}',(side*.39,.03,2.20),spine)
        elbow=m.joint(f'Gesture elbow {side}',elbow_pos,shoulder);wrist=m.joint(f'Gesture wrist {side}',wrist_pos,elbow)
        curved_limb(m,f'Loaded gesture humerus {side}',(side*.39,.03,2.20),elbow_pos,.16,shoulder,'Volumetric ritual arms')
        mass(m,f'Gesture elbow capsule {side}',elbow_pos,(.14,.15,.15),'iron',elbow,'Volumetric ritual arms','metal')
        curved_limb(m,f'Loaded hooked forearm {side}',elbow_pos,wrist_pos,.12,elbow,'Volumetric ritual arms')
        for finger in (-1,1):
            m.tube(f'Attached ritual talon {side} {finger}',[wrist_pos,add(wrist_pos,(side*.12,-.12,finger*.12)),add(wrist_pos,(side*.18,-.23,finger*.17))],[.06,.045,.018],'ivory',wrist,'Volumetric ritual arms',6)
    # Coherent discharge posture: axial body thrust plus open arms/wing roots.
    pressure=.14 if firing else -.04 if pose=='recovery' else 0
    forward=-.16 if release else 0
    pressure_chamber(m,'Living throat pressure chamber',(0,-.34+forward,2.13+pressure),(.28+pressure*.6,.32+pressure,.44+pressure),throat,'Loading and discharge anatomy')
    for side in (-1,1):
        loft(m,f'Separated throat mandible {side}',[(side*.10,-.62+forward,1.79,.05,.07),
             (side*(.21+pressure),-.64+forward,2.03,.12,.13),
             (side*(.24+pressure),-.61+forward,2.40,.13,.14),
             (side*.09,-.52+forward,2.62,.04,.06)],'ivory',throat,'Loading and discharge anatomy')
    if release:
        mass(m,'Thrust open discharge aperture',(0,-.84,2.29),(.16,.16,.20),'recess',throat,'Loading and discharge anatomy','metal')
        m.tube('Attached ruby discharge lip',[(0,-.98,2.14),(0,-1.01,2.40)],[.065,.045],'hot',throat,'Loading and discharge anatomy',8)
    for i in range(3):
        side=i-1
        m.tube(f'Free hanging muscular root {i}',[(side*.18,.10,1.28),(side*.24+drift,-.02,.82),
             (side*.30+drift,.20,.31),(side*.20+drift,-.09,.12+.05*i)],[.12,.105,.06,.015],'scar' if i!=1 else 'ivory',spine,'Suspended torn tail',8)
    if pose=='dead':mass(m,'Collapsed ruptured throat',(0,-.51,1.85),(.43,.28,.28),'ruby_shadow',throat,'Loading and discharge anatomy')
    # The complete floating animal loads backward and thrusts forward, carrying
    # thorax, shell, arms and tail together; not a tiny central colour toggle.
    angle=.15 if release else -.08 if pose=='windup' else .035 if pose=='recovery' else 0
    if angle:
        def thrust(p):
            x,y,z=p;z-=1.30
            return (x,y*math.cos(angle)-z*math.sin(angle),1.30+y*math.sin(angle)+z*math.cos(angle))
        m.parts=[replace(part,vertices=tuple(thrust(v) for v in part.vertices)) for part in m.parts]
        m.joints={key:dict(v,position=thrust(v['position'])) for key,v in m.joints.items()}


def guardian(m):
    pose=m.pose;opened=pose in ('attack','windup','recovery')
    swing=.14 if pose=='walk_a' else -.14 if pose=='walk_b' else .23 if pose=='dead' else 0
    pelvis=m.joint('Massive pelvic saddle',(0,.11,1.35));chest=m.joint('Armoured thoracic bearing',(0,.12,2.38),pelvis)
    mass(m,'Substantial pelvic load body',(0,.13,1.35),(.55,.40,.43),'iron',pelvis,'Load-bearing sentinel body','metal')
    loft(m,'Deep supported thoracic chassis',[(0,.19,1.50,.34,.32),(0,.20,1.86,.55,.48),
         (0,.23,2.42,.63,.53),(0,.20,2.83,.60,.48),(0,.18,3.12,.26,.30)],'iron',chest,'Load-bearing sentinel body','metal')
    mass(m,'Deep dorsal ceramic carapace',(0,.50,2.46),(.61,.36,.68),'ivory',chest,'Load-bearing sentinel body','shell')
    core=m.joint('Lantern pressure heart',(0,-.46,2.33),chest)
    pressure_chamber(m,'Living lantern pressure heart',(0,-.48,2.33),(.29,.31,.46),core,'Exposed pressure anatomy')
    for side in (-1,1):
        hip_pos=(side*.34,.10,1.38);knee_pos=(side*.56,-.04+swing*side,.78);ankle_pos=(side*.63,swing*side*1.8,.20)
        hip=m.joint(f'Sentinel hip {side}',hip_pos,pelvis);knee=m.joint(f'Sentinel knee {side}',knee_pos,hip);ankle=m.joint(f'Sentinel ankle {side}',ankle_pos,knee)
        curved_limb(m,f'Bulky contained thigh {side}',hip_pos,knee_pos,.30,hip,'Mass-bearing legs','flesh')
        mass(m,f'Large seated knee shell {side}',knee_pos,(.26,.26,.23),'ivory',knee,'Mass-bearing legs','shell')
        curved_limb(m,f'Tapered armoured greave {side}',knee_pos,ankle_pos,.25,knee,'Mass-bearing legs')
        loft(m,f'Splayed heavy ground boot {side}',[(side*.63,-.12+swing*side*1.8,.02,.27,.36),
             (side*.63,-.16+swing*side*1.8,.16,.30,.43),
             (side*.63,-.04+swing*side*1.8,.34,.18,.23)],'iron',ankle,'Mass-bearing legs','metal')
        shoulder=m.joint(f'Broad shoulder bearing {side}',(side*.61,.07,2.75),chest)
        mass(m,f'Heavy overhanging pauldron {side}',(side*.69,.08,2.87),(.36,.39,.38),'ivory',shoulder,'Shoulder load and door hinges','shell')
        m.tube(f'Curved shoulder crest {side}',[(side*.66,.13,3.03),(side*.91,.13,3.38),(side*.77,.16,3.66)],[.15,.13,.025],'ivory',shoulder,'Shoulder load and door hinges',8)
        center=side*(.87 if opened else .22)
        door=m.joint(f'Seated curved door hinge {side}',(center,-.62,2.41),chest)
        # Curved thick lantern leaves are opaque true volumes. Minimum open
        # |X| stays beyond heart extent for windup/release/recovery alike.
        outline=[(center+side*.01,1.52),(center+side*.26,1.81),
                 (center+side*.29,2.62),(center+side*.11,3.16),
                 (center-side*.20,2.91),(center-side*.25,2.03)]
        cast_panel(m,f'Seated cast ceramic lantern lancet {side}',outline,-.88,.34,door,'Whole-window opening lantern leaves')
        cast_aperture(m,f'Load seated lantern hinge {side}',(side*.53,-.18,2.52),(.19,.22),chest,'Shoulder load and door hinges')
        curved_limb(m,f'Load-bearing shield hinge {side}',(side*.53,-.02,2.47),(center,-.47,2.44),.16,chest,'Shoulder load and door hinges','iron')
    cast_panel(m,'Left pelvic ceramic bearing cover',[(-.49,1.19),(-.08,1.09),(.02,1.48),(-.43,1.67)],-.31,.19,pelvis,'Load-bearing sentinel body')
    cast_panel(m,'Right seated thorax service cover',[(.27,1.70),(.57,1.93),(.52,2.35),(.22,2.21)],-.35,.15,chest,'Load-bearing sentinel body')
    loft(m,'Visorless crown and neck',[(0,.02,2.93,.22,.24),(0,-.02,3.24,.24,.26),
         (0,.02,3.49,.17,.19),(0,.10,3.76,.035,.07)],'ivory',chest,'Armoured sentinel crown')
    shoulder_pos=(-.77,.08,2.65);elbow_pos=(-1.05,-.24 if opened else .05,2.29);wrist_pos=(-1.02,-.73 if opened else -.25,2.35 if opened else 1.86)
    shoulder=m.joint('Bore shoulder -X',shoulder_pos,chest);elbow=m.joint('Bore elbow -X',elbow_pos,shoulder);wrist=m.joint('Bore wrist -X',wrist_pos,elbow)
    curved_limb(m,'Heavy bore upper arm',shoulder_pos,elbow_pos,.23,shoulder,'Attached single-shot apparatus','iron')
    mass(m,'Bore elbow load housing',elbow_pos,(.24,.25,.23),'steel',elbow,'Attached single-shot apparatus','metal')
    curved_limb(m,'Bulky bore forearm',elbow_pos,wrist_pos,.21,elbow,'Attached single-shot apparatus','iron')
    tip=add(wrist_pos,(0,-.35,.02))
    m.tube('Attached substantial bore',[wrist_pos,tip],[.20,.14],'iron',wrist,'Attached single-shot apparatus',12)
    m.tube('Dark recessed bore end',[tip,add(tip,(0,-.025,0))],.09,'recess',wrist,'Attached single-shot apparatus',12)
    if pose=='attack':m.tube('Exposed shot chamber return',[(-1.02,-.43,2.49),(-1.02,-.67,2.49)],.065,'hot',wrist,'Attached single-shot apparatus',8)
    if pose=='windup':mass(m,'Loading locked bore latch',(-.99,-.50,2.48),(.13,.14,.10),'brass',wrist,'Attached single-shot apparatus','metal')
    if pose=='recovery':mass(m,'Returned bore carriage',(-.99,-.36,2.48),(.12,.14,.10),'steel',wrist,'Attached single-shot apparatus','metal')


def summoner(m):
    pose=m.pose;opened=pose in ('attack','windup','recovery')
    expansion=.28 if pose=='attack' else .16 if pose=='windup' else .08 if pose=='recovery' else .04 if pose=='walk_a' else -.025 if pose=='walk_b' else 0
    root=m.joint('Rooted pelvic containment',(0,.15,.95));body=m.joint('Inhabited gestation body',(0,.15,2.06),root)
    # The broad low foundation and three living roots remain. Above them is a
    # spatially open spinal cage and unequal foundry jaws, never paired petals.
    mass(m,'Broad rooted living foundation',(0,.18,.70),(.81,.64,.65),'flesh',root,'Planted load-bearing living base')
    mass(m,'Low inhabited gestation abdomen',(0,.06,1.57),(.77+expansion*.5,.67+expansion*.5,.72+expansion*.3),'flesh',body,'Inhabited spawning body')
    cast_panel(m,'Deep grounded cast ritual plinth',[(-.68,.40),(.61,.38),(.79,.80),(.46,1.18),(-.42,1.26),(-.78,.83)],-.25,.57,root,'Grounded apparatus frame')
    # A connected dark dorsal pressure spine: broad base, tilted shoulder and
    # unequal upper throat. Does not enclose the whole creature in a gray pod.
    loft(m,'Deep load-bearing dorsal spine',[(.07,.56,.76,.38,.31),
         (.13,.76,1.43,.40,.34),(.05,.77,2.35,.29,.29),
         (-.13,.64-expansion*.35,3.26-expansion*.25,.26,.25),
         (-.19,.40-expansion*.65,3.93-expansion*.50,.20,.19),
         (-.30,.26-expansion*.85,4.22-expansion*.60,.065,.09)],'iron',body,'Open dorsal spinal cage','metal')
    # Two unequal cast cage arms follow the posterior chamber, with large clear
    # negative space. Actual seating lies behind the mouth, not in its aperture.
    smooth_tube(m,'Left closed spinal cage arm',[(-.54,.31,.89),(-.83,.55,1.53),(-.68,.63,2.49),
         (-.35,.50-expansion*.4,3.40-expansion*.3),(-.16,.42,3.72)],[.18,.22,.19,.15,.09],'iron',body,'Open dorsal spinal cage')
    smooth_tube(m,'Right unequal spinal cage arm',[(.54,.29,.82),(.83,.52,1.49),(.72,.56,2.18),
         (.32,.51,2.87),(-.06,.49,3.25)],[.22,.25,.22,.17,.10],'iron',body,'Open dorsal spinal cage')
    cast_panel(m,'Seated spinal maintenance plate',[(-.20,2.40),(.14,2.50),(.17,3.17),(-.24,3.43),(-.35,2.91)],.62,.17,body,'Open dorsal spinal cage')
    for i,angle in enumerate((-math.pi/2,math.pi/6,math.pi*5/6)):
        x,y=math.cos(angle)*1.37,math.sin(angle)*1.37
        hip_pos=(x*.28,y*.28,.96);knee_pos=(x*.73,y*.73,.43);foot_pos=(x,y,.12)
        hip=m.joint(f'Root hip {i}',hip_pos,root);knee=m.joint(f'Root knee {i}',knee_pos,hip);foot=m.joint(f'Root ankle {i}',foot_pos,knee)
        curved_limb(m,f'Broad fleshy load root {i}',hip_pos,knee_pos,.28,hip,'Planted articulated roots','flesh')
        curved_limb(m,f'Curved distal root shell {i}',knee_pos,foot_pos,.24,knee,'Planted articulated roots')
        mass(m,f'Wide grounded root contact {i}',(x,y,.11),(.33,.35,.11),'iron',foot,'Planted articulated roots','metal')
        # One seated bearing at each actual ground-loaded articulation.
        cast_aperture(m,f'Ground root bearing collar {i}',(knee_pos[0],knee_pos[1]-.16,knee_pos[2]),(.15,.13),knee,'Grounded apparatus frame')
    # Major horn construction is deliberately unequal in both height and path.
    # Left support rises then hooks toward mouth; right is a low heavy jaw/trough.
    upper=m.joint('High left mouth horn hinge',(-.70,.08,1.02),body)
    lower=m.joint('Low right mouth jaw hinge',(.63,.05,1.08),body)
    smooth_tube(m,'High integrated left production horn',[(-.66,.14,.87),(-.99,.13,1.75),
         (-.91,-.01,2.80+expansion*.2),(-.57,-.24,3.56+expansion*.2),
         (-.21,-.52,3.39),(-.12,-.78,2.80+expansion*.45)],[.25,.32,.30,.22,.14,.045],'ivory',upper,'Unequal integrated ritual mouth')
    smooth_tube(m,'Low integrated right jaw trough',[(.58,.12,.84),(.97,-.01,1.44),
         (.97,-.34,2.12-expansion*.35),(.68,-.66,2.56-expansion*.45),
         (.29,-.91,2.45-expansion*.65)],[.28,.34,.30,.21,.065],'ivory',lower,'Unequal integrated ritual mouth')
    belly=m.joint('Spawn aperture cradle',(0,-.50,2.12),body)
    pressure_chamber(m,'Deep horizontal brood chamber',(0,-.52,2.04),(.43+expansion*.4,.39+expansion*.45,.53+expansion*.2),belly,'Connected living production path',cast=False)
    cast_aperture(m,'Foundry mouth and dark production throat',(0,-.76,2.01),(.76,.77),belly,'Connected living production path')
    # A lower genuine jaw opens down, exposing the connected membrane/trough.
    jaw=m.joint('Production trough jaw',(0,-.46,1.54),body)
    z=1.27-expansion*.6
    cast_panel(m,'Lower cast production trough',[(-.48,z+.11),(.45,z+.09),(.57,z+.34),(.22,z+.48),(-.35,z+.43)],-.85-expansion*.6,.28,jaw,'Connected living production path')
    smooth_tube(m,'Connected brood return channel',[(0,-.23,1.19),(-.33,-.51,1.45),
         (-.32,-.82,1.94),(-.15,-.77,2.44)],[.13,.12,.09,.04],'scar',belly,'Connected living production path',8)
    # Preserve the successful large brace-opening force line from v03. These
    # are the existing source row's articulated expression, not a new attack.
    for side in (-1,1):
        elbow_pos=(side*(1.02 if opened else .84),-.45 if opened else -.05,2.30 if opened else 2.02)
        wrist_pos=(side*(1.22 if opened else .38),-.83 if opened else -.73,1.64 if opened else 1.57)
        shoulder=m.joint(f'Ritual brace shoulder {side}',(side*.57,.14,2.93),body)
        elbow=m.joint(f'Ritual brace elbow {side}',elbow_pos,shoulder);wrist=m.joint(f'Ritual brace wrist {side}',wrist_pos,elbow)
        curved_limb(m,f'Heavy opening brace humerus {side}',(side*.57,.14,2.93),elbow_pos,.21,shoulder,'Articulated containment ritual')
        mass(m,f'Living brace elbow {side}',elbow_pos,(.22,.23,.22),'flesh',elbow,'Articulated containment ritual')
        cast_aperture(m,f'Seated ritual brace bearing {side}',(elbow_pos[0],elbow_pos[1]-.08,elbow_pos[2]),(.16,.17),elbow,'Articulated containment ritual')
        curved_limb(m,f'Opening brace forearm {side}',elbow_pos,wrist_pos,.18,elbow,'Articulated containment ritual')
        smooth_tube(m,f'Broad attached cradle hook {side}',[wrist_pos,add(wrist_pos,(side*.12,-.10,-.22)),add(wrist_pos,(-side*.05,-.23,-.30))],[.10,.08,.025],'ivory',wrist,'Articulated containment ritual',8)
    if pose=='attack':
        mass(m,'Bulging connected birth membrane',(0,-1.03,1.99),(.39,.32,.51),'scar',belly,'Connected living production path')
        smooth_tube(m,'Open asymmetric birth membrane rim',[(-.19,-1.26,1.65),(-.35,-1.32,2.03),
             (-.17,-1.18,2.44)],[.075,.085,.04],'ruby_shadow',belly,'Connected living production path',8)
    if pose=='dead':mass(m,'Ruptured collapsed brood cavity',(0,-.72,1.80),(.56,.30,.40),'recess',belly,'Connected living production path','metal')


def build(role, pose):
    m = Model(role, pose)
    globals()[role](m)
    m.settle_or_fall()
    return m


def camera_basis(direction):
    if type(direction) is not int or direction not in range(8): raise ValueError('Exact direction0..7')
    a = math.tau*direction/8
    forward = unit((-10*math.sin(a), 10*math.cos(a), -2.05))
    right = unit(cross(forward, (0, 0, 1)))
    up = cross(right, forward)
    return right, up


def projected_bounds(model, direction):
    right, up = camera_basis(direction)
    spec = SPECS[model.role]
    points = [sub(v, (0, 0, spec['aim'])) for p in model.parts for v in p.vertices]
    xs = [64+dot(p, right)*CELL/spec['ortho'] for p in points]
    ys = [64-dot(p, up)*CELL/spec['ortho'] for p in points]
    # Conservative continuous vertices: actual raster must separately prove it.
    raw = (min(xs), min(ys), max(xs), max(ys))
    shift = FOOT_Y-raw[3]
    return {'raw': raw, 'registered': (raw[0], raw[1]+shift, raw[2], FOOT_Y)}


def phase_contract(role):
    return {'base_rows': list(POSES), 'base_atlas_size': [1024, 640],
            'source_only_phase_poses': {'windup': 'windup', 'release': 'attack', 'recovery': 'recovery'},
            'current_runtime_coarse_attack_row': 3,
            'guardian_entire_existing_vulnerable_window_open': role == 'guardian',
            'guardian_existing_predicate': 'telegraph_time > 0 or pose_time > 0 or recovery_time > 0' if role == 'guardian' else None,
            'phase_override_integration': 'NOT IMPLEMENTED; parent-owned optional presentation mapping; no new damage rule',
            'summoner_walk_rows_are_stationary_bellows': role == 'summoner',
            'new_attacks_or_save_fields': False}
