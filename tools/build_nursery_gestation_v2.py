"""Original transparent Nursery machine; pure contracts, Blender only in main."""
import argparse
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys

ID = 'nursery_gestation_engine'
REFERENCE_SHA = '3c046b70ff27b05aba6b850a6c7f430af22feeb8028f010b6f2241af14235144'
MATERIAL_SHA = '4afbb96396d0de2006fc420746d58e1fcf7e47cc39418a3f6a6656ee13fae781'
PINS = {
    'tools/build_art.py': '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581',
    'tools/art_recipe.py': '32af173a8db24be0068ba3043990e3cc950de546bc1079dc635dc1af0cedcbf6',
    'tools/build_religious_late_art.py': 'f1fa327818fd7b2cfc45ba2aeebb45d8bcd65265b91bf0e97fb5cd6659e20331',
    'source/art/nursery_gestation_engine.blend': 'e042b254881ae86118d5bf3243fde4093f584d602fa602a63bcb0a66cbcad6e0',
}
ROLLBACK_COMMIT = '84d27115f178a25c38dab0c6c98bafdd7ed918b8'
ROLLBACK_PINS = {
    'game/assets/art/world/nursery_gestation_engine.glb': '5d7921f949b3898d4293ec9c019f08dcd9df21a22bcb7e8977cc4c9c1a42502f',
    'source/art/manifest.json': 'e33eef0912d9b4b3aeb41996dbe475b8b2537468c62d3970328a4c5c225b1556',
}
MATERIALS = {
    'brass': dict(color=(1,1,1,1),metallic=.68,roughness=.54,alpha='OPAQUE',tile=0),
    'bone': dict(color=(1,1,1,1),metallic=0,roughness=.72,alpha='OPAQUE',tile=2),
    'tissue': dict(color=(1,1,1,1),metallic=0,roughness=.61,alpha='OPAQUE',tile=4),
    'amber': dict(color=(1,1,1,1),metallic=0,roughness=.38,alpha='OPAQUE',tile=5,emission=(.38,.16,.035)),
    'shell': dict(color=(.10,.10,.10,.18),metallic=0,roughness=.18,alpha='BLEND',tile=None),
}


@dataclass
class Part:
    name: str
    material: str
    assembly: str
    vertices: list
    faces: list


def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def unit(a):
    length=math.sqrt(dot(a,a))
    if length<1e-12: raise ValueError('Degenerate normal')
    return tuple(x/length for x in a)


def triangles(part):
    for f in part.faces:
        for j in range(1,len(f)-1):yield f[0],f[j],f[j+1]


def loft(name,material,assembly,profile,center=(0,0,0),aspect=(1,1),segments=16):
    vertices,rows,faces=[],[],[]
    for z,r in profile:
        row=[]
        for i in range(1 if r==0 else segments):
            a=2*math.pi*i/segments
            row.append(len(vertices));vertices.append((center[0]+aspect[0]*r*math.cos(a),center[1]+aspect[1]*r*math.sin(a),center[2]+z))
        rows.append(row)
    for low,high in zip(rows,rows[1:]):
        for i in range(segments):
            j=(i+1)%segments
            if len(low)==1:faces.append((low[0],high[j],high[i]))
            elif len(high)==1:faces.append((low[i],low[j],high[0]))
            else:faces.append((low[i],low[j],high[j],high[i]))
    return Part(name,material,assembly,vertices,faces)


def egg(name,material,assembly,center,scale,segments=12,rings=8):
    profile=[(-scale[2]*math.cos(math.pi*i/rings),0 if i in (0,rings) else math.sin(math.pi*i/rings)) for i in range(rings+1)]
    return loft(name,material,assembly,profile,center,scale[:2],segments)


def tube(name,material,assembly,points,radii,sides=8):
    vertices,faces=[],[];u=None
    for i,p in enumerate(points):
        tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
        if u is None:
            axis=(0,0,1) if abs(tangent[2])<.9 else (0,1,0)
            u=unit(cross(axis,tangent))
        else:
            # Transport the prior radial axis instead of flipping the frame at an axis threshold.
            u=unit(tuple(u[k]-tangent[k]*dot(u,tangent) for k in range(3)))
        v=cross(tangent,u)
        r=radii[i] if isinstance(radii,(tuple,list)) else radii
        for j in range(sides):
            a=2*math.pi*j/sides
            vertices.append(tuple(p[k]+r*(u[k]*math.cos(a)+v[k]*math.sin(a)) for k in range(3)))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    return Part(name,material,assembly,vertices,faces)


def niche(name,center,width,height,depth,material='brass',assembly='architecture'):
    # A through-arch with deep inner walls, not a shaded decal or solid block.
    contour=[(-1,0),(1,0),(1,.65),(.55,.87),(0,1),(-.55,.87),(-1,.65)]
    verts=[]
    for y in (-depth/2,depth/2):
        for inner in (False,True):
            for x,z in contour:
                verts.append((center[0]+x*width/2*(.64 if inner else 1),center[1]+y,center[2]+(.13*height+z*.72*height if inner else z*height)))
    n=len(contour);faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),
                      (j,i,2*n+i,2*n+j),(n+i,n+j,3*n+j,3*n+i)])
    return Part(name,material,assembly,verts,faces)


def ossified_socket(name,center,width,height,depth,phase):
    """Fractured vertebral body with a deep continuous foraminal opening."""
    vertices=[];sides=12
    for back in (False,True):
        for inner in (False,True):
            for i in range(sides):
                a=2*math.pi*i/sides
                r=(.48+.06*math.sin(3*a+phase)) if inner else (1+.13*math.sin(3*a+phase)+.07*math.cos(5*a-phase))
                vertices.append((center[0]+width*.5*r*math.cos(a),center[1]+(depth*.5 if back else -depth*.5),
                                 center[2]+height*.5*r*math.sin(a)+.025*math.cos(a+phase)))
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces.extend([(i,j,sides+j,sides+i),(2*sides+j,2*sides+i,3*sides+i,3*sides+j),
                      (j,i,2*sides+i,2*sides+j),(sides+i,sides+j,3*sides+j,3*sides+i)])
    return Part(name,'bone','architecture',vertices,faces)


def cranial_vault():
    outer=egg('suspended elongated alien cranium vault','bone','anatomy',(0,.055,6.48),(.41,.365,.77),32,16)
    # A full posterior vault narrows continuously into the hanging face, not a flat mask.
    outer.vertices=[(x*(.68+.32*min(1,max(0,(z-5.88)/.57)))+.015*math.sin(4*z),
                     y+.09*(z-6.48),z) for x,y,z in outer.vertices]
    faces=[]
    for f in outer.faces:
        x,y,z=[sum(outer.vertices[i][k] for i in f)/len(f) for k in range(3)]
        # Two slanted orbital apertures retain the central bridge and curved cheek walls.
        if y<-.04 and all(abs(outer.vertices[i][0])>.035 for i in f) and any(((x-cx+.16*(z-cz))/.14)**2+((z-cz)/.225)**2<1
                         for cx,cz in [(-.18,6.28),(.18,6.37)]):continue
        faces.append(f)
    n=len(outer.vertices)
    inner=[(x*.82,.055+(y-.055)*.78,6.48+(z-6.48)*.87) for x,y,z in outer.vertices]
    edges={}
    for f in faces:
        for a,b in zip(f,f[1:]+f[:1]):edges.setdefault((min(a,b),max(a,b)),[]).append((a,b))
    walls=[(b,a,a+n,b+n) for pair in edges.values() if len(pair)==1 for a,b in pair]
    return Part(outer.name,'bone','anatomy',outer.vertices+inner,faces+[tuple(i+n for i in reversed(f)) for f in faces]+walls)


def pleural_web():
    parts=[]
    # Authored fascia fans follow membrane-wrap-reference-v1.png (bd32fcb9...), not bone socket proportions.
    for name,center,width,height,phase,lean,radius,aperture,wrap in [
        ('superior',(-.30,-.17,4.97),.61,.95,.7,.12,
         [1.05,1.12,1.35,1.65,1.55,1.15,.95,.88,1.05,1.15,.92,.90],
         [.70,.82,.58,.30,.55,.83,.62,.72,.82,.70,.42,.30],
         [-.03,-.13,-.16,.20,.23,.12,.015,-.04,-.015,.02,-.04,-.10]),
        ('inferior',(.22,-.16,3.73),.58,.87,2.2,-.10,
         [1.05,1.23,1.25,1.05,1.15,1.28,1.10,.90,1.18,1.35,1.10,.82],
         [.72,.78,.65,.45,.30,.46,.75,.80,.38,.28,.65,.78],
         [-.01,.08,.16,.11,-.09,-.17,-.20,-.12,.02,.08,.06,-.03])]:
        p=ossified_socket('pleural web '+name+' fenestrated lobe',center,width,height,.115,phase)
        p.material='tissue';p.assembly='anatomy'
        vertices=[]
        for back in (False,True):
            for inner in (False,True):
                for i in range(12):
                    a=2*math.pi*i/12;fraction=aperture[i] if inner else 1
                    r=radius[i]*fraction;x=width*.5*r*math.cos(a);z=height*.5*r*math.sin(a)
                    # Ordered radial sectors stay disjoint; paired skins bound one single-valued depth fold.
                    vertices.append((center[0]+x+lean*z,
                                     center[1]+wrap[i]*fraction+(.0575 if back else -.0575),center[2]+z))
        p.vertices=vertices
        parts.append(p)
    parts.append(tube('pleural web axial stem','tissue','anatomy',
        [(0,-.07,3.16),(.11,-.10,3.54),(-.02,-.015,4.50),(-.035,-.12,4.85),(-.20,-.04,5.40),(-.30,.02,5.78)],
        [.10,.115,.12,.10,.09,.05],8))
    parts.append(tube('pleural web costal tension branch','tissue','anatomy',
        [(.49,-.13,3.74),(.56,-.12,3.91),(.58,.07,4.0)],[.065,.042,.035],7))
    return parts


def build_parts():
    parts=[]
    shell=loft('pointed transparent continuous vessel','shell','vessel',
        [(1.25,0),(1.45,.5),(2,1.04),(3,1.2),(5.8,1.15),(6.8,.83),(7.5,.42),(7.95,0)],aspect=(1,.65),segments=32)
    parts.append(shell)
    for side in (-1,1):
        for fore in (-1,1):
            x,y=side*1.42,fore*1.03
            tag=f'{side} {fore}'
            parts.append(loft('grounded foot '+tag,'brass','architecture',[(0,.45),(.12,.45),(.3,.34),(.62,.24),(.7,0)],(x,y,0),aspect=((1.925-1.42)/.45,(1.575-1.03)/.45),segments=12))
            # Close the grounded underside without changing the authored footprint.
            parts[-1].faces.append(tuple(reversed(range(12))))
            parts.append(tube('curving pier corpus '+tag,'brass','architecture',[(x,y,.3),(x,y,1.3),(side*1.31,fore*.96,2.5),(side*1.44,fore*.88,4.1),(side*1.18,fore*.88,6.3),(side*.84,fore*.56,7.6)], [.23,.26,.225,.245,.20,.14]))
            parts.append(niche('deep carved lower niche '+tag,(x,y-fore*.05,.42),.55,1.1,.34))
            parts.append(tube('rooted flying buttress '+tag,'brass','architecture',
                [(x,y,.4),(side*1.68,fore*1.11,1.7),(side*1.73,fore*1.05,2.6),(side*1.67,fore*.98,3.45),(side*1.44,fore*.88,4.1)],
                [.14,.14,.12,.105,.14],8))
            for j,(cx,cy,z) in enumerate([(x,y,1.25),(side*1.44,fore*.88,4.1),(side*1.18,fore*.88,6.3)]):
                parts.append(loft(f'layered pier corbel {tag} {j}','brass','architecture',
                    [(-.18,0),(-.18,.25),(-.09,.33),(.02,.34),(.08,.27),(.16,.24),(.16,0)],(cx,cy,z),(.95,1),12))
            frame=[(side*1.18,fore*.88,6.3),(side*1.10,fore*.82,6.65),(side*.85,fore*.65,7.16),(side*.46,fore*.38,7.73),(0,fore*.02,8.14)]
            parts.append(tube('vessel framing arch '+tag,'brass','architecture',frame,[.18,.17,.15,.12,.10],8))
            parts.append(tube('vessel framing ivory arris '+tag,'bone','architecture',
                [(px,py-fore*.14,pz-.04) for px,py,pz in frame],[.065,.062,.054,.04,.025],6))
            for i in range(9):
                z=1.78+i*.51+.07*math.sin(i*1.9+fore);px=side*(1.37-.024*i+.045*math.sin(i*1.6));py=fore*(.96-.012*i)
                parts.append(ossified_socket(f'vertebral open socket {tag} {i}',(px,py-fore*.07,z),.51+.055*math.sin(i+fore),.49+.065*math.cos(i*1.7),.24,i*1.3+side))
                parts.append(tube(f'vertebral lateral process {tag} {i}','bone','architecture',[(px+side*.12,py,z),(px+side*.25,py+fore*.02,z+.13),(px+side*.32,py-fore*.05,z+.29)], [.092,.064,.022],6))
                if i%2==0:
                    parts.append(tube(f'blackened mechanical vertebral brace {tag} {i}','brass','architecture',[(px-side*.17,py+fore*.09,z-.13),(px-side*.24,py+fore*.04,z+.08),(px-side*.18,py,z+.3)],[.053,.04,.026],6))
            parts.append(tube('gothic upper pointed finial '+tag,'brass','controls',[(side*1.12,fore*.8,6.6),(side*1.04,fore*.66,7.55),(side*.95,fore*.58,8.28)],[.09,.06,.01],8))
    parts.append(cranial_vault())
    parts.append(egg('cranium deep orbital tissue backing','tissue','anatomy',(0,.08,6.27),(.28,.17,.40),16,10))
    parts.append(tube('cranial facial keel','bone','anatomy',[(.018,-.285,6.58),(-.018,-.345,6.32),(.01,-.295,6.08),(-.02,-.20,5.91)],[.047,.038,.027,.018],8))
    parts.append(tube('cranial pointed mandible','tissue','anatomy',[(0,-.10,6.08),(.035,-.24,5.91),(-.025,-.17,5.76),(-.04,-.09,5.65)],[.12,.095,.057,.023]))
    for side in (-1,1):
        lift=.055 if side==1 else -.035
        parts.append(tube('cranial fractured zygomatic ridge '+str(side),'bone','anatomy',
            [(side*.34,-.115,6.48+lift),(side*.355,-.205,6.28+lift),(side*.27,-.255,6.08+lift),(side*.14,-.25,5.92),(side*.025,-.205,5.83)],
            [.068,.065,.049,.033,.017],8))
        parts.append(tube('cranium supraorbital arch '+str(side),'bone','anatomy',
            [(side*.035,-.29,6.53+lift),(side*.12,-.29,6.60+lift),(side*.24,-.255,6.61+lift),(side*.33,-.17,6.51+lift)],
            [.038,.049,.058,.052],8))
        parts.append(tube('cranium cheek to cervical tendon '+str(side),'tissue','anatomy',
            [(side*.27,-.255,6.08+lift),(side*.20,-.10,5.90),(side*.11,.015,5.68),(side*.06,.04,5.48)],
            [.052,.049,.043,.031],7))
        parts.append(tube('cranial bifurcate restraint '+str(side),'tissue','anatomy',[(side*.12,.02,6.04),(side*.43,.12,5.72),(side*.74,.12,5.65)],[.07,.043,.027]))
        parts.append(tube('clavicular wishbone '+str(side),'bone','anatomy',
            [(0,.07,5.52),(side*.30,.02,5.78),(side*.61,.08,5.58),(side*.74,.12,5.65)],[.07,.085,.06,.04],8))
        parts.append(egg('scapular growing blade '+str(side),'tissue','anatomy',(side*.53,.10,5.30),(.17,.14,.31),12,8))
        parts.append(tube('iliac growing wing '+str(side),'bone','anatomy',
            [(.03,.08,3.25),(side*.28,-.05,3.35),(side*.50,-.10,3.06),(side*.45,.05,2.84),(side*.12,.10,2.98)],[.10,.11,.09,.055,.05],8))
        parts.append(tube('cranial pressure restraint '+str(side),'brass','anatomy',
            [(side*.22,.03,6.94),(side*.29,.10,7.13),(side*.21,.12,7.31),(0,.13,7.4)],[.04,.045,.035,.025],8))
    parts.append(egg('pelvic forming pressure organ','tissue','anatomy',(0,-.07,3.16),(.18,.13,.30),12,8))
    for i in range(12):
        z=2.25+i*.275+.023*math.sin(1.8*i);w=.115+.065*math.sin(math.pi*i/11);sx=.037*math.sin(i*1.2)
        parts.append(egg(f'forming spinal centrum {i}','bone','anatomy',(sx,.11,z),(w,.105+.018*math.cos(i),.105+.025*math.sin(i+1)),10,6))
        parts.append(tube(f'dorsal vertebral process {i}','tissue','anatomy',[(0,.12,z),(0,.28,z+.045),(0,.31,z+.16)],[.055,.047,.016],6))
        if i>=2:
            for side in (-1,1):
                spread=.43+.18*math.sin(math.pi*(i-2)/9)+.025*math.sin(i*1.7+side);dz=.06*math.sin(i*1.4+side)
                if i>=9:
                    dz+=side*.055*math.sin(i*.8)
                    parts.append(tube(f'open costal branch {side} {i}','bone','anatomy',
                        [(sx+side*.06,.08,z),(side*spread*.63,.13,z+.045+dz),(side*(spread+.04),.015,z+.17+dz),
                         (side*(spread+.12),-.15,z+.27+dz),(side*(spread-.02),-.30,z+.31+dz),(side*(spread-.21),-.26,z+.23+dz)],
                        [.044+.009*math.sin(i),.055,.060,.043,.028,.012],7))
                else:
                    parts.append(tube(f'open costal branch {side} {i}','bone','anatomy',[(sx+side*.06,.08,z),(side*spread,.07,z+.12+dz),(side*(spread+.12),-.12,z+.28+dz),(side*(spread-.06),-.25,z+.41+dz)],[.044+.009*math.sin(i),.061,.035,.013],7))
    parts.append(tube('suspended living axial cord','tissue','anatomy',[(0,.08,2.06),(0,.07,3.2),(0,.03,4.5),(0,.04,5.74)],[.065,.07,.09,.11]))
    for side in (-1,1):
        parts.append(tube('living lateral suspensory tendon '+str(side),'tissue','anatomy',[(side*.07,.14,2.7),(side*.28,-.12,3.45),(side*.22,-.18,4.28),(side*.37,-.03,5.06),(side*.12,.02,5.73)],[.04,.035,.033,.031,.025],7))
        parts.append(tube('lower growing limb '+str(side),'tissue','anatomy',[(side*.05,.03,3.15),(side*.31,-.03,2.75),(side*.4,-.09,2.28),(side*.25,-.06,2.02)],[.072,.08,.041,.016]))
        parts.append(tube('external nutrient conduit '+str(side),'brass','controls',[(side*1.37,-.88,.65),(side*1.02,-.67,1.4),(side*1.27,-.67,3.0),(side*1.24,-.55,5.9)],[.09,.075,.065,.045]))
        for i in range(3):
            parts.append(niche(f'base lancet control {side} {i}',(side*(.32+i*.39),-.78,.35),.28,.82,.2))
    for i in range(5):
        a=2*math.pi*i/5
        parts.append(egg(f'amber growing basal organ {i}','amber','anatomy',(.19*math.cos(a),.14*math.sin(a),1.97),(.115,.1,.14),10,6))
    parts.append(tube('crown central living suspension','brass','controls',[(0,0,7.91),(0,0,8.18),(0,0,8.43)],[.13,.09,.005],8))
    # The pressure circuit intersects each foot and each lancet, rather than floating below the vessel.
    for fore in (-1,1):
        parts.append(tube('basal transverse pressure beam '+str(fore),'brass','architecture',
            [(-1.42,fore*1.03,.32),(1.42,fore*1.03,.32)],.17,8))
    for side in (-1,1):
        parts.append(tube('basal longitudinal pressure beam '+str(side),'brass','architecture',
            [(side*1.42,-1.03,.32),(side*1.42,1.03,.32)],.17,8))
        parts.append(tube('basal lancet jamb '+str(side),'brass','architecture',
            [(side*1.3,-.78,.32),(side*1.3,-.78,1.14)],.13,8))
    parts.append(tube('basal central manifold tie','brass','architecture',[(0,-1.03,.32),(0,1.03,.32)],.18,8))
    for z,r,label in [(.32,.17,'sill'),(1.14,.13,'lintel')]:
        parts.append(tube('basal lancet '+label,'brass','architecture',[(-1.42,-.78,z),(1.42,-.78,z)],r,8))
    parts.append(loft('basal pressure organ manifold','brass','architecture',
        [(.14,0),(.14,.49),(.28,.58),(.38,.55),(.78,.55),(.91,.60),(1.10,.50),(1.22,0)],segments=16))
    parts.extend(pleural_web())
    return parts


def validate_part(p):
    if p.material not in MATERIALS or not p.vertices or not p.faces:raise ValueError('Part inventory')
    if any(len(v)!=3 or not all(math.isfinite(x) for x in v) for v in p.vertices):raise ValueError('Nonfinite vertices')
    for f in p.faces:
        if len(f)<3 or any(type(i) is not int or not 0<=i<len(p.vertices) for i in f):raise ValueError('Face indices')
    for a,b,c in triangles(p):unit(cross(sub(p.vertices[b],p.vertices[a]),sub(p.vertices[c],p.vertices[a])))


def signed_volume(p):return sum(dot(p.vertices[a],cross(p.vertices[b],p.vertices[c]))/6 for a,b,c in triangles(p))


def low_vertices(p,height):
    out=[v for v in p.vertices if v[2]<=height]
    for face in p.faces:
        for a,b in zip(face,face[1:]+face[:1]):
            v,w=p.vertices[a],p.vertices[b]
            if (v[2]-height)*(w[2]-height)<0:
                t=(height-v[2])/(w[2]-v[2]);out.append(tuple(v[i]+t*(w[i]-v[i]) for i in range(3)))
    return out


def shell_planes(p):
    return [(n,dot(n,p.vertices[a])) for a,b,c in triangles(p) for n in [unit(cross(sub(p.vertices[b],p.vertices[a]),sub(p.vertices[c],p.vertices[a])))]]


def front_hits(parts,origin,name):
    direction=(0,1,0)
    for p in parts:
        if name not in p.name:continue
        for ia,ib,ic in triangles(p):
            a,b,c=[p.vertices[i] for i in (ia,ib,ic)];e1,e2=sub(b,a),sub(c,a)
            h=cross(direction,e2);det=dot(e1,h)
            if abs(det)<1e-9:continue
            s=sub(origin,a);u=dot(s,h)/det;q=cross(s,e1);v=dot(direction,q)/det;t=dot(e2,q)/det
            if 0<=u<=1 and 0<=v and u+v<=1 and t>0:return True
    return False


def geometry_report(parts):
    if len({p.name for p in parts})!=len(parts) or {p.material for p in parts}!=set(MATERIALS) or sum(p.material=='shell' for p in parts)!=1:raise ValueError('Unique geometry/material inventory')
    verts=[v for p in parts for v in p.vertices]
    for p in parts:
        validate_part(p)
        if signed_volume(p)<=0:raise ValueError('Inward part '+p.name)
        if any(abs(x)>1.925+1e-7 or abs(y)>1.575+1e-7 for x,y,z in low_vertices(p,1.8)):raise ValueError('Low collision BOX escape '+p.name)
    low=[min(v[i] for v in verts) for i in range(3)];high=[max(v[i] for v in verts) for i in range(3)]
    count=sum(len(list(triangles(p))) for p in parts)
    if count>20000 or low[2]!=0 or high[2]>8.43+1e-7 or max(abs(low[0]),abs(high[0]))>1.925 or max(abs(low[1]),abs(high[1]))>1.575:raise ValueError('Geometry envelope/budget')
    shell=next(p for p in parts if p.material=='shell');planes=shell_planes(shell)
    if any(dot(n,v)-d>1e-7 for v in shell.vertices for n,d in planes):raise ValueError('Shell must remain convex without self-overlap')
    for p in parts:
        if p.assembly=='anatomy' and any(dot(n,v)-d>-.08+1e-6 for v in p.vertices for n,d in planes):raise ValueError('Anatomy shell clearance '+p.name)
    return dict(bounds=[low,high],triangles=count,editable_meshes=len(parts),groups=5,
                contacts=[p.name for p in parts if p.name.startswith('grounded foot')],shell_triangles=len(list(triangles(shell))))


def plain_path(value):
    p=Path(value)
    if '..' in p.parts or '~' in p.parts:raise ValueError('Path traversal/alias')
    p=p.absolute()
    if any(q.is_symlink() for q in (p,*p.parents)):raise ValueError('Symlink path '+str(p))
    return p


def pinned(path,digest):
    p=plain_path(path)
    if not p.is_file() or p.stat().st_nlink!=1 or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise ValueError('Missing, aliased or modified pinned input '+str(p))
    return p


def output_path(value,inputs):
    p=plain_path(value)
    if not p.parent.is_dir() or p.exists():raise ValueError('Output must be fresh with existing parent')
    for item in inputs:
        q=plain_path(item)
        if p==q or p in q.parents or q in p.parents:raise ValueError('Output/input alias')
    return p


def png_size(data):
    if len(data)<33 or data[:8]!=b'\x89PNG\r\n\x1a\n' or data[12:16]!=b'IHDR':raise ValueError('Expected PNG header')
    w,h=struct.unpack('>II',data[16:24])
    if not w or not h:raise ValueError('PNG dimensions')
    return w,h


def pack_glb(doc,binary):
    raw=json.dumps(doc,separators=(',',':'),allow_nan=False).encode();raw+=b' '*((-len(raw))%4)
    binary+=b'\0'*((-len(binary))%4)
    return struct.pack('<4sII',b'glTF',2,28+len(raw)+len(binary))+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(binary),b'BIN\0')+binary


def unpack_glb(blob):
    if len(blob)<28 or len(blob)>2097152:raise ValueError('GLB size')
    magic,version,length=struct.unpack_from('<4sII',blob)
    if magic!=b'glTF' or version!=2 or length!=len(blob):raise ValueError('GLB2 header')
    n,kind=struct.unpack_from('<I4s',blob,12)
    if kind!=b'JSON' or n%4 or 20+n+8>len(blob):raise ValueError('JSON chunk')
    try:doc=json.loads(blob[20:20+n],parse_constant=lambda x: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))
    except (UnicodeError,json.JSONDecodeError) as e:raise ValueError('GLB JSON') from e
    size,kind=struct.unpack_from('<I4s',blob,20+n)
    if kind!=b'BIN\0' or size%4 or 28+n+size!=len(blob):raise ValueError('BIN chunk')
    return doc,blob[28+n:]


def integer(x):return type(x) is int and x>=0


def reject_external_extensions(x):
    if isinstance(x,dict):
        if any(k in x for k in ('extensions','extensionsUsed','extensionsRequired','uri')):raise ValueError('External/extension forbidden')
        for v in x.values():reject_external_extensions(v)
    elif isinstance(x,list):
        for v in x:reject_external_extensions(v)


def inspect_glb(blob,expected_bounds=None):
    doc,binary=unpack_glb(blob)
    try:return _inspect(doc,binary,expected_bounds)
    except (KeyError,IndexError,TypeError,struct.error,OverflowError) as e:raise ValueError('Malformed typed GLB field') from e


def _inspect(d,binary,expected_bounds):
    reject_external_extensions(d)
    if d['asset']['version']!='2.0' or len(d['buffers'])!=1 or not integer(d['buffers'][0]['byteLength']) or not 0<=len(binary)-d['buffers'][0]['byteLength']<=3:raise ValueError('Buffer inventory')
    declared=d['buffers'][0]['byteLength']
    views=d['bufferViews'];accessors=d['accessors']
    def view(index):
        if not integer(index):raise ValueError('Typed view index')
        v=views[index];offset=v.get('byteOffset',0);length=v['byteLength']
        if type(v['buffer']) is not int or v['buffer']!=0 or not integer(offset) or not integer(length) or offset+length>declared:raise ValueError('BIN view span')
        return offset,length,v
    for j in range(len(views)):view(j)
    def accessor(index,kind,component):
        if not integer(index):raise ValueError('Accessor index')
        a=accessors[index]
        if a['type']!=kind or not integer(a['componentType']) or a['componentType'] not in component or 'sparse' in a or type(a.get('normalized',False)) is not bool or a.get('normalized',False) or not integer(a['count']) or a['count']==0:raise ValueError('Accessor type/count')
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];width={'VEC3':3,'VEC2':2,'SCALAR':1}[kind];size=struct.calcsize(fmt)*width
        off,length,v=view(a['bufferView']);start=a.get('byteOffset',0);stride=v.get('byteStride',size)
        if not integer(start) or not integer(stride) or stride<size or stride%struct.calcsize(fmt) or start%struct.calcsize(fmt) or start+(a['count']-1)*stride+size>length:raise ValueError('Accessor BIN span')
        rows=[struct.unpack_from('<'+fmt*width,binary,off+start+i*stride) for i in range(a['count'])]
        if any(not all(math.isfinite(x) for x in r) for r in rows):raise ValueError('Nonfinite accessor')
        return rows,a
    if len(d['materials'])!=5 or len(d['meshes'])!=5 or len(d['nodes'])!=5 or len(d['scenes'])!=1 or not integer(d['scene']) or d['scene']!=0 or any(not integer(i) for i in d['scenes'][0]['nodes']) or sorted(d['scenes'][0]['nodes'])!=list(range(5)):raise ValueError('Active five-group inventory')
    if len(d['images'])!=1 or len(d['textures'])!=1 or len(d['samplers'])!=1:raise ValueError('Atlas inventory')
    im=d['images'][0];off,size,v=view(im['bufferView'])
    if im['mimeType']!='image/png' or png_size(binary[off:off+size])!=(512,512):raise ValueError('512 embedded PNG')
    if d['textures'][0]!={'source':0,'sampler':0} or any(not integer(x) for x in d['textures'][0].values()) or any(not integer(x) for x in d['samplers'][0].values()) or d['samplers'][0]!={'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}:raise ValueError('Nearest no-mip atlas sampler')
    used=[];vertices=[];tri_count=0
    for node in d['nodes']:
        if any(k in node for k in ('camera','skin','children','translation','rotation','scale','matrix')) or not integer(node['mesh']):raise ValueError('Unexpected node/transform')
        used.append(node['mesh'])
    if sorted(used)!=list(range(5)):raise ValueError('Mesh alias')
    materials_seen=[]
    for mesh in d['meshes']:
        if len(mesh['primitives'])!=1:raise ValueError('Primitive inventory')
        p=mesh['primitives'][0];mat=p['material']
        if not integer(mat) or not integer(p.get('mode',4)) or p.get('mode',4)!=4 or 'targets' in p:raise ValueError('Primitive binding')
        materials_seen.append(mat);m=d['materials'][mat];name=m['name'].removeprefix('nursery_v2_')
        if name not in MATERIALS or m['name']!='nursery_v2_'+name:raise ValueError('Material name')
        spec=MATERIALS[name];pbr=m['pbrMetallicRoughness']
        emission=m.get('emissiveFactor',[0,0,0]);expected_emission=spec.get('emission',(0,0,0))
        if type(emission) is not list or len(emission)!=3 or any(type(x) not in (int,float) or not math.isfinite(x) or (abs(x-y)>1e-6 if y else x!=0) for x,y in zip(emission,expected_emission)):raise ValueError('Controlled amber-only emission')
        if any('Texture' in k for k in m) or any('Texture' in k and k!='baseColorTexture' for k in pbr):raise ValueError('Only the opaque base-color atlas is supported')
        if m.get('alphaMode','OPAQUE')!=spec['alpha'] or type(m.get('doubleSided',False)) is not bool or m.get('doubleSided',False):raise ValueError('Alpha/double-layer contract')
        color=pbr.get('baseColorFactor',[1,1,1,1])
        if len(color)!=4 or any(type(x) not in (float,int) or not math.isfinite(x) or abs(x-y)>1e-5 for x,y in zip(color,spec['color'])):raise ValueError('PBR base color')
        for key,value in [('metallicFactor',spec['metallic']),('roughnessFactor',spec['roughness'])]:
            if type(pbr.get(key)) not in (int,float) or not math.isfinite(pbr[key]) or abs(pbr[key]-value)>1e-5:raise ValueError('PBR factor')
        if name=='shell':
            if any('Texture' in k for k in pbr) or any('Texture' in k for k in m):raise ValueError('Shell texture forbidden')
        elif pbr.get('baseColorTexture')!={'index':0} or not integer(pbr['baseColorTexture']['index']):raise ValueError('Shared opaque atlas binding')
        pos,a=accessor(p['attributes']['POSITION'],'VEC3',{5126});norm,_=accessor(p['attributes']['NORMAL'],'VEC3',{5126})
        if len(norm)!=len(pos) or any(abs(dot(n,n)-1)>.005 for n in norm):raise ValueError('Unit normals')
        low=[min(v[i] for v in pos) for i in range(3)];high=[max(v[i] for v in pos) for i in range(3)]
        if len(a['min'])!=3 or len(a['max'])!=3 or any(abs(x-y)>1e-5 for x,y in zip(a['min']+a['max'],low+high)):raise ValueError('Declared/computed bounds parity')
        if name!='shell':
            uv,_=accessor(p['attributes']['TEXCOORD_0'],'VEC2',{5126})
            tile=spec['tile'];col=tile%4;row=1-tile//4
            if len(uv)!=len(pos) or any(not (col+.06)/4<=u<=(col+.94)/4 or not 1-(row+.97)/2<=v<=1-(row+.03)/2 for u,v in uv):raise ValueError('Exported UV image-panel gutters')
        indices,_=accessor(p['indices'],'SCALAR',{5121,5123,5125})
        if len(indices)%3 or any(i[0]>=len(pos) for i in indices):raise ValueError('Triangle indices')
        for k in range(0,len(indices),3):
            ids=[indices[j][0] for j in (k,k+1,k+2)];a,b,c=[pos[j] for j in ids];face=unit(cross(sub(b,a),sub(c,a)))
            average=tuple(sum(norm[j][axis] for j in ids) for axis in range(3))
            if dot(face,average)<=0:raise ValueError('Winding/normal mismatch')
        vertices.extend(pos);tri_count+=len(indices)//3
    if sorted(materials_seen)!=list(range(5)) or len({m['name'] for m in d['materials']})!=5 or tri_count>20000:raise ValueError('Material partition/budget')
    bounds=[[min(v[i] for v in vertices) for i in range(3)],[max(v[i] for v in vertices) for i in range(3)]]
    if expected_bounds and any(abs(x-y)>2e-5 for row,target in zip(bounds,expected_bounds) for x,y in zip(row,target)):raise ValueError('Export/source actual bounds parity')
    return dict(groups=5,materials=5,triangles=tri_count,bounds=bounds,atlas=[512,512],alphaMode='BLEND',alpha=.18,bytes=len(pack_glb(d,binary)))


def nearest_glb(blob):
    d,b=unpack_glb(blob)
    reject_external_extensions(d)
    # Exporter may duplicate texture descriptors per material; coalesce identical image use only.
    if len(d.get('images',[]))!=1:raise ValueError('One atlas required before normalization')
    for t in d['textures']:
        if set(t)-{'source','sampler'} or type(t.get('source')) is not int or t['source']!=0 or not integer(t.get('sampler',0)) or t.get('sampler',0)>=len(d['samplers']):raise ValueError('Texture inventory before normalization')
    for s in d['samplers']:
        if set(s)-{'magFilter','minFilter','wrapS','wrapT'} or any(type(x) is not int for x in s.values()):raise ValueError('Sampler type before normalization')
        allowed={'magFilter':{9728,9729},'minFilter':{9728,9729,9984,9985,9986,9987},'wrapS':{33071,33648,10497},'wrapT':{33071,33648,10497}}
        if any(value not in allowed[key] for key,value in s.items()):raise ValueError('Invalid sampler enum before normalization')
    for m in d['materials']:
        p=m['pbrMetallicRoughness']
        if 'baseColorTexture' in p:
            t=p['baseColorTexture'];idx=t['index']
            if set(t)-{'index','texCoord'} or type(t.get('texCoord',0)) is not int or t.get('texCoord',0)!=0 or not integer(idx) or idx>=len(d['textures']):raise ValueError('Unsafe texture normalization')
            t.clear();t['index']=0
    d['textures']=[{'source':0,'sampler':0}]
    d['samplers']=[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]
    out=pack_glb(d,b);inspect_glb(out);return out


def load_module(path,name):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    sys.modules[name]=module;spec.loader.exec_module(module);return module


def _portable_path(owner, name, value):
    # RNA fixed-size strings retain bytes after NUL; overwrite the full field first.
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


def main(argv=None):
    sys.dont_write_bytecode=True
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root',required=True);parser.add_argument('--reference',required=True)
    parser.add_argument('--material-reference',required=True);parser.add_argument('--output',required=True)
    args=parser.parse_args(argv)
    root=plain_path(args.source_root);reference=pinned(args.reference,REFERENCE_SHA);material_input=pinned(args.material_reference,MATERIAL_SHA)
    for logical,digest in PINS.items():pinned(root/logical,digest)
    if png_size(material_input.read_bytes())!=(1254,1254):raise ValueError('Material input must be original 1254 PNG')
    resolver=load_module(root/'tools/art_recipe.py','nursery_art_recipe')
    helper_path=resolver.resolve_recipe(root,'tools/build_art.py',PINS['tools/build_art.py'])
    output=output_path(args.output,[root,reference,material_input,Path(__file__)])
    parts=build_parts();report=geometry_report(parts)
    # Fresh directory reservation is exclusive; a failed build is retained, never overwritten.
    output.mkdir()
    for folder in ['source/art','game/assets/art/world','game/assets/art/textures','render']:(output/folder).mkdir(parents=True,exist_ok=True)
    import bpy
    from mathutils import Vector
    scene=bpy.data.scenes.new('Nursery v2 source');bpy.context.window.scene=scene
    helper=load_module(helper_path,'nursery_geometry_helper')
    full_path=output/'source/art/nursery-material-atlas-v2.png'
    with full_path.open('xb') as f:f.write(material_input.read_bytes())
    ref_path=output/'source/art/nursery-transparent-reference-v2.png'
    with ref_path.open('xb') as f:f.write(reference.read_bytes())
    reference_full=bpy.data.images.load(str(full_path),check_existing=False)
    reference_full.name='Pinned full 1254 Nursery material atlas v2';reference_full.use_fake_user=True
    reference_full.alpha_mode='NONE';reference_full.file_format='PNG';reference_full.filepath=str(full_path)
    reference_full.pack()
    production_sheet=bpy.data.images.load(str(ref_path),check_existing=False);production_sheet.use_fake_user=True;production_sheet.pack()
    atlas=reference_full.copy();atlas.name='Nursery image-derived 512 opaque atlas';atlas.use_fake_user=True
    atlas_path=output/'game/assets/art/textures/nursery_gestation_atlas.png'
    atlas.alpha_mode='NONE';atlas.file_format='PNG';atlas.filepath_raw=str(atlas_path)
    atlas.scale(512,512);atlas.pack();atlas.save()
    native_materials={}
    for name,spec in MATERIALS.items():
        m=bpy.data.materials.new('nursery_v2_'+name);m.use_nodes=True;m.use_backface_culling=True
        bsdf=m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value=spec['color'];bsdf.inputs['Alpha'].default_value=spec['color'][3]
        bsdf.inputs['Metallic'].default_value=spec['metallic'];bsdf.inputs['Roughness'].default_value=spec['roughness']
        bsdf.inputs['Emission Color'].default_value=(*spec.get('emission',(0,0,0)),1)
        bsdf.inputs['Emission Strength'].default_value=1 if name=='amber' else 0
        # Default IOR/specular can emit KHR extensions; use the core glTF defaults explicitly.
        bsdf.inputs['IOR'].default_value=1.5;bsdf.inputs['Specular IOR Level'].default_value=.5
        if name!='shell':
            tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest';tex.extension='EXTEND'
            m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        else:
            m.surface_render_method='DITHERED'
        native_materials[name]=m
    helper.M.update(native_materials)
    collections={}
    for name in ['architecture','vessel','anatomy','controls']:
        c=bpy.data.collections.new('Editable '+name);scene.collection.children.link(c);collections[name]=c
    objects=[]
    for p in parts:
        obj=helper.mesh(p.name,p.vertices,p.faces,p.material)
        collections[p.assembly].objects.link(obj)
        # Keep the default root link; source meshes stay directly editable without destructive unlink.
        obj['assembly']=p.assembly;obj['reference_sha256']=REFERENCE_SHA
        for poly in obj.data.polygons:poly.use_smooth=p.material=='shell' or ('cranium' in p.name)
        if p.material!='shell':
            uv=obj.data.uv_layers.new(name='Image panel gutters')
            tile=MATERIALS[p.material]['tile'];col=tile%4;row=1-tile//4
            low=[min(v[i] for v in p.vertices) for i in range(3)];high=[max(v[i] for v in p.vertices) for i in range(3)]
            for poly in obj.data.polygons:
                axis=max(range(3),key=lambda k:abs(poly.normal[k]));dims=[k for k in range(3) if k!=axis]
                for index in poly.loop_indices:
                    v=p.vertices[obj.data.loops[index].vertex_index]
                    q=[(v[k]-low[k])/max(high[k]-low[k],1e-8) for k in dims]
                    uv.data[index].uv=((col+.07+.86*q[0])/4,(row+.04+.92*q[1])/2)
        objects.append(obj)
    scene.world=bpy.data.worlds.new('Neutral Nursery preview world');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.15,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    camera_data=bpy.data.cameras.new('Authoring preview camera');camera=bpy.data.objects.new('Authoring preview camera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
    camera_data.type='ORTHO';camera_data.ortho_scale=10
    for j,(loc,power,size) in enumerate([((-5,-7,10),1500,6),((4,-3,6),1000,4),((0,5,8),1300,4)]):
        data=bpy.data.lights.new('Authoring softbox '+str(j),'AREA');data.energy=power;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(data.name,data);scene.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,4))-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=2
    scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    camera.location=(9,-14,8);camera.rotation_euler=(Vector((0,0,4.2))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene['production_reference_sha256']=REFERENCE_SHA;scene['material_reference_sha256']=MATERIAL_SHA
    scene['geometry_report']=json.dumps(report);scene['placement_contract']='cell5.5/10.5 yaw0 BOX3.85/.55/3.15 blood nursery_loop_gestation'
    blend=output/'source/art/nursery_gestation_engine_v2.blend'
    sanitize_source_paths(bpy)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=False)
    if blend.read_bytes()[:7]!=b'BLENDER':raise ValueError('Editable source must be raw BLENDER, not compressed')
    for label,loc in [('front',(0,-17,5)),('hero',(9,-14,8)),('rear',(-8,14,7))]:
        camera.location=loc;camera.rotation_euler=(Vector((0,0,4.2))-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(output/'render'/('nursery_'+label+'.png'));bpy.ops.render.render(write_still=True)
    runtime=[]
    for name in MATERIALS:
        clones=[]
        for ob,p in zip(objects,parts):
            if p.material==name:
                clone=ob.copy();clone.data=ob.data.copy();scene.collection.objects.link(clone);clones.append(clone)
        for ob in scene.objects:ob.select_set(False)
        for ob in clones:ob.select_set(True)
        bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join()
        joined=bpy.context.view_layer.objects.active;joined.name='Runtime nursery '+name;runtime.append(joined)
    for ob in objects:ob.hide_set(True)
    for ob in scene.objects:ob.select_set(False)
    for ob in runtime:ob.select_set(True)
    bpy.context.view_layer.objects.active=runtime[0]
    glb=output/'game/assets/art/world/nursery_gestation_engine.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
                              export_cameras=False,export_lights=False,export_yup=True,export_image_format='AUTO',export_extras=False)
    blob=nearest_glb(glb.read_bytes())
    # Export uses Blender Z-up -> glTF Y-up: x,y,z becomes x,z,-y.
    b=report['bounds'];expected=[[b[0][0],b[0][2],-b[1][1]],[b[1][0],b[1][2],-b[0][1]]]
    runtime_report=inspect_glb(blob,expected);glb.write_bytes(blob)
    if len(blob)>=1813732:raise ValueError('Candidate GLB must remain strictly below 1813732 bytes')
    if png_size(atlas_path.read_bytes())!=(512,512):raise ValueError('Native atlas PNG must remain 512')
    for logical,digest in PINS.items():pinned(root/logical,digest)
    pinned(reference,REFERENCE_SHA);pinned(material_input,MATERIAL_SHA);pinned(full_path,MATERIAL_SHA)
    manifest=json.loads(plain_path(root/'source/art/manifest.json').read_text())
    assets=manifest['assets']
    entries=assets.values() if isinstance(assets,dict) else assets
    nursery_ids=[e['id'] for e in entries if e.get('level_id')=='nursery' and e.get('tradition_aesthetic')]
    if len(nursery_ids)!=7 or len(set(nursery_ids))!=7 or ID not in nursery_ids:raise ValueError('Manifest must identify seven Nursery religious assets')
    others=sum((root/'game/assets/art/world'/(i+'.glb')).stat().st_size for i in nursery_ids if i!=ID)
    if others+len(blob)>=8388608:raise ValueError('Actual seven-piece Nursery budget')
    receipt=dict(id=ID,source=report,runtime=runtime_report,level_seven_piece_bytes=others+len(blob),nursery_seven_ids=nursery_ids,
                 reference_sha256=REFERENCE_SHA,material_sha256=MATERIAL_SHA,recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                 recipe_dependencies={k:PINS[k] for k in ('tools/build_art.py','tools/art_recipe.py')},
                 original_pins=PINS,rollback_baseline_commit=ROLLBACK_COMMIT,rollback_baseline_pins=ROLLBACK_PINS,files={str(p.relative_to(output)):dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in output.rglob('*') if p.is_file()},
                 native_quality_accepted=False,game_alpha_sorting_accepted=False)
    (output/'candidate.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    (output/'manifest.patch.json').write_text(json.dumps({'id':ID,'proposal_only':True,'source':'source/art/nursery_gestation_engine_v2.blend','runtime':'game/assets/art/world/nursery_gestation_engine.glb','receipt':receipt},indent=2)+'\n')
    print(json.dumps(receipt,sort_keys=True))


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    main(args)
