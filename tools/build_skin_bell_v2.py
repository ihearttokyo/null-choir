"""Original hollow membrane bell; pure geometry first, parent-owned Blender execution."""
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
REFERENCE_SHA = '93a7a08843e1cf8414c93513892f5ac621c4469095fd0a86f468adb0987d43be'
MATERIAL_SHA = 'eed15e41ba0bf85de489dbe4e25364324e8ead8e33a333182edeca89077b6ac7'
HELPER_SHA = '32af173a8db24be0068ba3043990e3cc950de546bc1079dc635dc1af0cedcbf6'
BASELINE_PINS = {
    'source/art/skin_bell.blend': 'b044b449d4ebfeed02f17793a75347f1fdb696adbf627155e3387cfd148d557d',
    'tools/build_art.py': '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581',
}
SECTORS = 48
BELL_PROFILE = ((3.48, 2.52), (3.60, 2.58), (3.82, 2.43), (4.12, 2.24),
                (4.52, 2.00), (4.96, 1.77), (5.40, 1.55), (5.85, 1.36),
                (6.25, 1.21), (6.60, 1.08), (6.86, .99), (6.98, .91))
KINDS = ('bronze', 'black', 'ivory', 'membrane', 'inner', 'amber', 'scar', 'edge')
GROUPS = {k: 'brass' if k in ('bronze', 'black', 'edge') else 'ivory' if k == 'ivory' else 'amber' if k=='amber' else 'tissue' for k in KINDS}
AMBER_EMISSION = (.38,.16,.035)
MATERIALS = (('brass',.62,.72,(0,0,0)),('ivory',0,.67,(0,0,0)),
             ('tissue',0,.43,(0,0,0)),('amber',0,.43,AMBER_EMISSION))
NICHE_DEPTH = .30
FILENAMES = ('skin_bell_v2.blend', 'skin_bell.glb', 'skin_bell_atlas.png',
             'skin_bell.export.glb', 'skin_bell_hero.png', 'skin_bell_cavity.png', 'manifest.patch.json', 'build-record.json')


@dataclass
class Part:
    name: str
    vertices: list
    faces: list
    kind: str
    role: str


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def unit(a):
    length = math.sqrt(dot(a, a))
    if length < 1e-10:
        raise ValueError('Degenerate geometry direction')
    return tuple(x/length for x in a)


def face_normal(part, face):
    a = part.vertices[face[0]]
    result = (0., 0., 0.)
    for i in range(1, len(face)-1):
        n = cross(sub(part.vertices[face[i]], a), sub(part.vertices[face[i+1]], a))
        result = tuple(x+y for x, y in zip(result, n))
    return result


def face_area(part, face):
    n = face_normal(part, face)
    return math.sqrt(dot(n, n)) / 2


def signed_volume(part):
    return sum(dot(part.vertices[f[0]], cross(part.vertices[f[i]], part.vertices[f[i+1]]))/6
               for f in part.faces for i in range(1, len(f)-1))


def edge_counts(part):
    counts = Counter(tuple(sorted((a, b))) for f in part.faces for a, b in zip(f, f[1:]+f[:1]))
    return set(counts.values())


def bounds(parts):
    vertices = [v for p in parts for v in p.vertices]
    return ([min(v[i] for v in vertices) for i in range(3)],
            [max(v[i] for v in vertices) for i in range(3)])


def triangles(parts):
    return sum(len(f)-2 for p in parts for f in p.faces)


def low_geometry_radius(parts):
    samples=[]
    for p in parts:
        samples.extend(math.hypot(x,y) for x,y,z in p.vertices if z<=1.8)
        for face in p.faces:
            for ia,ib in zip(face,face[1:]+face[:1]):
                a,b=p.vertices[ia],p.vertices[ib]
                if min(a[2],b[2])<1.8<max(a[2],b[2]):
                    t=(1.8-a[2])/(b[2]-a[2])
                    samples.append(math.hypot(a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
    return max(samples)


def loft(name, profile, kind, role, sectors=12, center=(0, 0), modulation=0):
    verts = []
    for z, radius in profile:
        for i in range(sectors):
            a = math.tau*i/sectors
            r = radius * (1 + modulation*math.cos(a*4))
            verts.append((center[0]+r*math.cos(a), center[1]+r*math.sin(a), z))
    faces = [(j*sectors+i, j*sectors+(i+1)%sectors,
              (j+1)*sectors+(i+1)%sectors, (j+1)*sectors+i)
             for j in range(len(profile)-1) for i in range(sectors)]
    faces += [tuple(reversed(range(sectors))), tuple(range((len(profile)-1)*sectors, len(verts)))]
    return Part(name, verts, faces, kind, role)


def tube(name, points, radii, kind, role, sides=6):
    if isinstance(radii, (float, int)):
        radii = [radii] * len(points)
    if len(points) != len(radii) or len(points) < 2 or min(radii) <= 0:
        raise ValueError('Tube requires positive radius at each point')
    verts = []
    for i, (p, r) in enumerate(zip(points, radii)):
        tangent = unit(sub(points[min(i+1, len(points)-1)], points[max(0, i-1)]))
        ref = (0, 1, 0) if abs(tangent[1]) < .9 else (1, 0, 0)
        u = unit(cross(ref, tangent)); v = cross(tangent, u)
        for j in range(sides):
            a = math.tau*j/sides
            verts.append(tuple(p[k]+r*(u[k]*math.cos(a)+v[k]*math.sin(a)) for k in range(3)))
    faces = [(j*sides+i, j*sides+(i+1)%sides, (j+1)*sides+(i+1)%sides, (j+1)*sides+i)
             for j in range(len(points)-1) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range((len(points)-1)*sides, len(verts)))]
    return Part(name, verts, faces, kind, role)


def ring(name, z, radius, thickness, kind, role, sectors=48, center=(0, 0)):
    verts = []
    for i in range(sectors):
        a = math.tau*i/sectors
        for j in range(6):
            b = math.tau*j/6
            r = radius + thickness*math.cos(b)
            verts.append((center[0]+r*math.cos(a), center[1]+r*math.sin(a), z+thickness*math.sin(b)))
    faces = [(i*6+j, ((i+1)%sectors)*6+j, ((i+1)%sectors)*6+(j+1)%6, i*6+(j+1)%6)
             for i in range(sectors) for j in range(6)]
    return Part(name, verts, faces, kind, role)


def aperture(name, outer, inner, depth, kind, role, y=0):
    if len(outer) != len(inner):
        raise ValueError('Aperture contours must correspond')
    n = len(outer)
    verts = [(x, y+d, z) for d in (-depth/2, depth/2) for contour in (outer, inner) for x, z in contour]
    faces = []
    for i in range(n):
        j = (i+1)%n
        faces += [(i, j, n+j, n+i), (2*n+j, 2*n+i, 3*n+i, 3*n+j),
                  (i, 2*n+i, 2*n+j, j), (n+j, 3*n+j, 3*n+i, n+i)]
    return Part(name, verts, faces, kind, role)


def arch_contour(width, bottom, spring, peak, steps=12):
    return [(-width, bottom), (width, bottom)] + [
        (width*math.cos(math.pi*i/steps), spring+(peak-spring)*math.sin(math.pi*i/steps)**.78)
        for i in range(steps+1)]


def plate(name, contour, y, depth, kind, role):
    n = len(contour)
    verts = [(x, y+d, z) for d in (-depth/2, depth/2) for x, z in contour]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2*n)))]
    faces += [(i, n+i, n+(i+1)%n, (i+1)%n) for i in range(n)]
    return Part(name, verts, faces, kind, role)


def transform(part, center, angle):
    c, s = math.cos(angle), math.sin(angle)
    part.vertices = [(center[0]+c*x-s*y, center[1]+s*x+c*y, z) for x, y, z in part.vertices]
    return part


def pier_center(z):
    t=max(0,min(1,(z-1.8)/1.9))
    return 1.64+.74*t*t*(3-2*t)


def place_pier(part,center,angle):
    transform(part,center,angle)
    part.vertices=[(x-center[0]*(1-pier_center(z)/2.38),
                    y-center[1]*(1-pier_center(z)/2.38),z) for x,y,z in part.vertices]
    return part


def vertebral_body(name,z,index,role='vertebra'):
    """Six sculpted contour bands make a bulging body and a recessed open socket."""
    n=12; width=.38+.075*math.cos(index*1.73); height=.31+.09*math.sin(index*1.29)
    hole_width=.12+.035*math.sin(index*.91)**2; hole_height=.12+.045*math.cos(index*.83)**2
    if index==4:
        width*=1.12; height*=1.75; hole_width*=1.45; hole_height*=1.6
    verts=[]
    for outer,scale,depth in ((True,.94,.045),(True,1.04,.16),(True,.82,.31),
                              (False,1.16,.31),(False,.84,.17),(False,1.08,0)):
        for k in range(n):
            a=math.tau*k/n
            wave=1+.12*math.cos(a*3+index*.47)+.035*math.sin(a*5) if outer else 1
            x=scale*(width if outer else hole_width)*math.cos(a)*wave
            zz=z+scale*(height if outer else hole_height)*math.sin(a)*wave
            yy=-.57+depth+.024*math.sin(a*2+index*.6)
            verts.append((x,yy,zz))
    faces=[(band*n+k,((band+1)%6)*n+k,((band+1)%6)*n+(k+1)%n,band*n+(k+1)%n)
           for band in range(6) for k in range(n)]
    return Part(name,verts,faces,'ivory',role)


def membrane():
    n, rows = SECTORS, len(BELL_PROFILE)
    verts = []
    for inner in (False, True):
        for row, (z, radius) in enumerate(BELL_PROFILE):
            for i in range(n):
                a = math.tau*i/n
                r = radius + .035*math.cos(a*8+row*.17) - (.115 if inner else 0)
                zz = z + .026*math.sin(a*8)*(1-row/(rows-1))
                verts.append((r*math.cos(a), r*math.sin(a), zz))
    faces = []
    for inner in (False, True):
        off = int(inner)*n*rows
        for row in range(rows-1):
            for i in range(n):
                a, b = off+row*n+i, off+row*n+(i+1)%n
                f = (a, b, b+n, a+n)
                faces.append(tuple(reversed(f)) if inner else f)
    for i in range(n):
        j = (i+1)%n
        faces.append((i, rows*n+i, rows*n+j, j))
        a, b = (rows-1)*n+i, (rows-1)*n+j
        faces.append((a, b, b+rows*n, a+rows*n))
    return Part('Double wall membrane', verts, faces, 'membrane', 'shell')


def build_scene():
    parts = [membrane(), ring('Broad ivory mouth', 3.54, 2.54, .145, 'ivory', 'lip'),
             ring('Black brass mouth binding', 3.64, 2.55, .045, 'edge', 'lip'),
             ring('Crown pressure collar', 6.99, .95, .10, 'bronze', 'crown', 24),
             loft('Crown hanging hub', ((6.90,.42),(7.25,.40),(7.48,.22),(7.57,.17)), 'black', 'crown', 16)]
    mouth=parts[1]
    mouth.vertices=[(x*(1+.023*math.cos(math.atan2(y,x)*12)),
                     y*(1+.023*math.cos(math.atan2(y,x)*12)),
                     z+.025*math.sin(math.atan2(y,x)*12)) for x,y,z in mouth.vertices]
    for i, (cx, cy) in enumerate(((-2.38,-2.38),(2.38,-2.38),(2.38,2.38),(-2.38,2.38))):
        angle = math.atan2(cy,cx)+math.pi/2
        local = [loft(f'Pier {i} stepped foundation', ((0,.76),(.17,.76),(.18,.65),(.36,.65),(.40,.43),(1.10,.41),(1.32,.43)), 'black', 'base', 8),
                 loft(f'Pier {i} fluted core', ((1.24,.43),(1.65,.35),(3.50,.34),(4.2,.31),(5.2,.30),(6.5,.35),(7.15,.39),(7.62,.23)), 'bronze', 'pier_core', 12, modulation=.15)]
        for level, (bottom, spring, peak, width) in enumerate(((.42,1.12,1.36,.39),(1.55,3.18,3.70,.31))):
            outer = arch_contour(width,bottom,spring,peak)
            inner = arch_contour(width-.09,bottom+.10,spring-.03,peak-.13)
            local.append(aperture(f'Pier {i} niche frame {level}',outer,inner,NICHE_DEPTH,'edge','niche_frame',y=-.65))
            local.append(plate(f'Pier {i} recessed niche back {level}',inner,-.45,.045,'black','niche_back'))
            local.append(tube(f'Pier {i} niche relief {level}',[(0,-.55,bottom+.19),(0,-.55,spring-.03),(0,-.56,peak-.23)],[.055,.08,.035],'ivory','niche_relief',7))
        for j in range(8):
            z = 3.38+j*.50
            local.append(vertebral_body(f'Pier {i} vertebra {j}',z,j))
            if j%2 == 0:
                for side in (-1,1):
                    contour=[(.22,z-.08),(.47,z+.015),(.57,z+.24),(.44,z+.40),(.38,z+.17),(.21,z+.13)]
                    if side<0: contour=list(reversed([(-x,h) for x,h in contour]))
                    local.append(plate(f'Pier {i} hooked spur {j} {side}',contour,-.46,.15,'ivory','spur'))
        for side in (-1,1):
            points=[(side*w,-.39,z) for z,w in ((1.22,.26),(1.7,.32),(2.5,.24),(3.4,.26),(4.3,.20),(5.3,.25),(6.4,.19),(7.12,.24))]
            local.append(tube(f'Pier {i} fused bony corpus {side}',points,[.10,.14,.10,.14,.11,.13,.095,.12],'ivory','corpus',6))
        for z,r in ((.18,.70),(.37,.58),(1.34,.43),(3.70,.36),(7.16,.38)):
            local.append(loft(f'Pier {i} carved brass girdle {z}',((z-.035,r*.96),(z,r+.025),(z+.035,r*.96)),'edge','girdle',8))
        parts.extend(place_pier(p,(cx,cy),angle) for p in local)
        direction=unit((cx,cy,0))
        points=[(cx,cy,7.1),(cx*.76,cy*.76,7.28),(direction[0]*1.3,direction[1]*1.3,7.50),(direction[0]*.55,direction[1]*.55,7.53)]
        parts.append(tube(f'Pier {i} articulated suspension',points,[.32,.30,.27,.22],'bronze','shoulder',10))
        parts.append(tube(f'Pier {i} shoulder ivory crest',[(x,y,z+.23) for x,y,z in points],[.13,.15,.12,.09],'ivory','shoulder_crest',7))
    for i in range(8):
        a = math.tau*i/8
        points=[((r+.08)*math.cos(a),(r+.08)*math.sin(a),z+.02) for z,r in BELL_PROFILE]
        parts.append(tube(f'Raised membrane tendon {i}',points,[.085-.003*j for j in range(len(points))],'ivory','tendon',6))
        for j in (2,5,8):
            z,r = BELL_PROFILE[j]
            arc = [((r+.035)*math.cos(a+.12+k*.117), (r+.035)*math.sin(a+.12+k*.117), z-.12*math.sin(k*math.pi/5)) for k in range(6)]
            parts.append(tube(f'Membrane tension stitch {i} {j}',arc,.026,'scar','suture',4))
    for i in range(4):
        a=math.tau*(i+.5)/4
        points=[((r-.18)*math.cos(a),(r-.18)*math.sin(a),z) for z,r in BELL_PROFILE]
        parts.append(tube(f'Inner living cavity ligament {i}',points,.045,'inner','inner_ligament',5))
    parts.append(loft('Clapper suspended tendon',((2.16,.13),(2.80,.15),(3.7,.13),(4.7,.12),(5.8,.10),(6.92,.11)),'inner','clapper',12))
    for j in range(7):
        z=2.50+j*.39
        parts.append(loft(f'Clapper amber segment {j}',((z-.13,.16),(z-.08,.23),(z+.09,.23),(z+.14,.16)),'amber','clapper_segment',12))
        parts.append(loft(f'Clapper vertebral collar {j}',((z-.055,.19),(z,.28+.025*math.sin(j)),(z+.075,.21)),'ivory','clapper',10))
    parts.append(loft('Clapper amber resonator',((1.34,.09),(1.43,.27),(1.64,.43),(1.92,.47),(2.15,.36),(2.30,.15)),'amber','clapper',20))
    for i in range(6):
        a=math.tau*i/6
        points=[(r*math.cos(a),r*math.sin(a),z) for z,r in ((1.34,.15),(1.48,.36),(1.80,.53),(2.09,.43),(2.30,.19))]
        parts.append(tube(f'Open clapper resonator rib {i}',points,[.034,.047,.048,.043,.03],'edge','clapper_cage',6))
    parts.append(ring('Clapper heel binding',1.48,.34,.025,'ivory','clapper',24))
    for p in parts:
        if p.role in ('clapper','clapper_segment','clapper_cage'):
            p.vertices=[(x+.025*math.sin(z*3),y-.16,z) for x,y,z in p.vertices]
    outer=[(.68*math.cos(math.tau*i/32),7.50+.68*math.sin(math.tau*i/32)) for i in range(32)]
    inner=[(.50*math.cos(math.tau*i/32),7.50+.50*math.sin(math.tau*i/32)) for i in range(32)]
    parts.append(aperture('Pierced crown seal',outer,inner,.12,'edge','seal',y=-.12))
    for i in range(12):
        a=math.tau*i/12
        parts.append(tube(f'Crown radial inscription {i}',[(.18*math.cos(a),-.14,7.50+.18*math.sin(a)),(.46*math.cos(a),-.14,7.50+.46*math.sin(a))],.018,'bronze','seal_relief',5))
    return parts


def uv_rect(kind):
    k=KINDS.index(kind); col,row=k%4,k//4
    # PNG rows run top-down; Blender UV runs bottom-up.
    return ((col*128+8)/512,1-(row*256+248)/512,(col*128+120)/512,1-(row*256+8)/512)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def local_path(path):
    raw=str(path)
    if not raw.startswith('/') or any(x in ('.','..','') for x in raw.split('/')[1:]) or '://' in raw or '\\' in raw:
        raise ValueError('Require an absolute local path without traversal')
    p=Path(raw)
    if any(q.is_symlink() for q in (p,*p.parents)):
        raise ValueError('Symlinked path or ancestor: '+raw)
    return p


def pinned_file(path,digest):
    p=local_path(path)
    if not p.is_file() or sha(p)!=digest:
        raise ValueError('Missing or changed pinned input: '+str(p))
    return p


def material_reference(path):
    p=pinned_file(path,MATERIAL_SHA)
    data=p.read_bytes()
    if data[:8]!=b'\x89PNG\r\n\x1a\n' or struct.unpack('>IIBBBBB',data[16:29])!=(1254,1254,8,2,0,0,0):
        raise ValueError('Require the pinned opaque RGB 4x2 material grid')
    return p


def build_material_atlas(bpy,reference,path):
    """Keep the exact full input and create the runtime working copy through Blender."""
    reference=material_reference(reference); path=local_path(path)
    if path.exists(): raise FileExistsError(path)
    original=bpy.data.images.load(str(reference),check_existing=False)
    original.name='Skin bell immutable material reference v3'; original.use_fake_user=True
    original['reference_sha256']=MATERIAL_SHA; original.pack()
    image=original.copy(); image.name='Skin bell image-derived 512 atlas'
    image.alpha_mode='NONE'; image.file_format='PNG'; image.filepath_raw=str(path)
    image.scale(512,512); image.pack(); image.save()
    assert tuple(image.size)==(512,512)
    material_reference(reference)
    return image,original


def validate_output(path,protected):
    root=local_path(path)
    for item in protected:
        other=local_path(item)
        if root.is_relative_to(other) or other.is_relative_to(root):
            raise ValueError('Output overlaps protected input: '+str(other))
    if root.exists():
        raise FileExistsError('Refuse existing output directory: '+str(root))
    return root


def validate_materials(materials):
    if type(materials) is not list or len(materials)!=len(MATERIALS) or any(type(m) is not dict or type(m.get('name')) is not str for m in materials) or {m['name'] for m in materials}!={'skin_bell_'+g for g,_,_,_ in MATERIALS}:
        raise ValueError('Require four distinct named material groups')
    for material in materials:
        pbr=material.get('pbrMetallicRoughness',{})
        if material.get('alphaMode','OPAQUE')!='OPAQUE' or material.get('extensions') or any(k in material for k in ('normalTexture','emissiveTexture','occlusionTexture')) or 'metallicRoughnessTexture' in pbr:
            raise ValueError('Require standard opaque lit atlas materials without extra textures/extensions')
        factor=material.get('emissiveFactor',[0,0,0])
        expected=AMBER_EMISSION if material['name']=='skin_bell_amber' else (0,0,0)
        if type(factor) is not list or len(factor)!=3 or any(type(v) not in (int,float) or not math.isfinite(v) or not 0<=v<=1 for v in factor) or any(abs(v-e)>1e-6 for v,e in zip(factor,expected)):
            raise ValueError('Require restrained standard emission on amber only')


def inspect_glb(data):
    if len(data)<20 or struct.unpack_from('<III',data)!=(0x46546c67,2,len(data)):
        raise ValueError('Invalid GLB2 header')
    size,kind=struct.unpack_from('<II',data,12)
    if kind!=0x4e4f534a or size%4 or 20+size>len(data):
        raise ValueError('Invalid GLB JSON chunk')
    doc=json.loads(data[20:20+size])
    if doc.get('asset',{}).get('version')!='2.0':
        raise ValueError('Not glTF2')
    if any(doc.get(k) for k in ('extensions','extensionsUsed','extensionsRequired')):
        raise ValueError('Require standard glTF without extensions')
    if any('uri' in x for key in ('images','buffers') for x in doc.get(key,[])):
        raise ValueError('GLB must be self-contained')
    nodes=doc.get('nodes',[])
    group_count=len(MATERIALS)
    if len(nodes)!=group_count or type(doc.get('scene')) is not int or doc['scene']!=0 or len(doc.get('scenes',[]))!=1:
        raise ValueError('Require one active four-mesh scene')
    roots=doc['scenes'][0].get('nodes',[])
    if any(type(n) is not int for n in roots) or sorted(roots)!=list(range(group_count)) or any(n.get('children') for n in nodes):
        raise ValueError('Require four reachable root meshes')
    if any(type(n.get('mesh')) is not int for n in nodes) or sorted(n['mesh'] for n in nodes)!=list(range(group_count)):
        raise ValueError('Require each runtime mesh exactly once')
    textures=doc.get('textures',[])
    if len(textures)!=1 or any(type(textures[0].get(k)) is not int or textures[0][k]!=0 for k in ('source','sampler')):
        raise ValueError('Require the shared atlas texture and sampler')
    for node in doc.get('nodes',[]):
        if 'camera' in node or node.get('extensions') or any(t in node for t in ('translation','rotation','scale','matrix')):
            raise ValueError('Unexpected runtime node or transform')
    validate_materials(doc.get('materials',[]))
    offset=20+size
    if offset+8>len(data): raise ValueError('Missing GLB binary chunk')
    binary_size,binary_kind=struct.unpack_from('<II',data,offset)
    if binary_kind!=0x004e4942 or offset+8+binary_size!=len(data):
        raise ValueError('Invalid GLB binary chunk')
    buffers=doc.get('buffers',[])
    if len(buffers)!=1 or type(buffers[0].get('byteLength')) is not int or not 0<buffers[0]['byteLength']<=binary_size:
        raise ValueError('Invalid declared buffer span')
    views=doc.get('bufferViews',[])
    def view_at(index):
        if type(index) is not int or not 0<=index<len(views): raise ValueError('Invalid buffer view reference')
        view=views[index]; start=view.get('byteOffset',0); length=view.get('byteLength')
        if type(view.get('buffer')) is not int or view['buffer']!=0 or type(start) is not int or type(length) is not int or start<0 or length<=0 or start+length>buffers[0]['byteLength']:
            raise ValueError('Invalid buffer view span')
        return view
    accessors=doc.get('accessors',[]); total=0; positions=[]; used_materials=[]
    def accessor_at(index,kind,components,types):
        if type(index) is not int or not 0<=index<len(accessors): raise ValueError('Invalid accessor reference')
        a=accessors[index]; count=a.get('count'); component=a.get('componentType')
        if a.get('type')!=kind or type(component) is not int or component not in types or type(count) is not int or count<=0 or 'sparse' in a or a.get('normalized',False):
            raise ValueError('Invalid referenced accessor layout')
        view=view_at(a.get('bufferView')); unit={5126:4,5123:2,5125:4}[component]
        width=components*unit; start=a.get('byteOffset',0); stride=view.get('byteStride',width)
        if type(start) is not int or type(stride) is not int or start<0 or stride<width or stride%unit or (start+view.get('byteOffset',0))%unit or start+(count-1)*stride+width>view['byteLength']:
            raise ValueError('Invalid referenced accessor span')
        return a
    for mesh in doc.get('meshes',[]):
        if len(mesh.get('primitives',[]))!=1: raise ValueError('Require one surface per runtime group')
        for primitive in mesh.get('primitives',[]):
            if primitive.get('mode',4)!=4 or 'indices' not in primitive or 'NORMAL' not in primitive.get('attributes',{}) or 'TEXCOORD_0' not in primitive.get('attributes',{}):
                raise ValueError('Require indexed triangles, normals, and UV')
            if type(primitive.get('material')) is not int or not 0<=primitive['material']<group_count:
                raise ValueError('Invalid group material reference')
            used_materials.append(primitive['material'])
            attrs=primitive['attributes']
            position=accessor_at(attrs.get('POSITION'),'VEC3',3,(5126,))
            normal=accessor_at(attrs.get('NORMAL'),'VEC3',3,(5126,))
            uv=accessor_at(attrs.get('TEXCOORD_0'),'VEC2',2,(5126,))
            if position['count']<3 or normal['count']!=position['count'] or uv['count']!=position['count']:
                raise ValueError('Mismatched vertex attribute counts')
            if any(type(position.get(k)) is not list or len(position[k])!=3 or any(type(v) not in (int,float) or not math.isfinite(v) for v in position[k]) for k in ('min','max')):
                raise ValueError('Invalid position bounds')
            count=accessor_at(primitive['indices'],'SCALAR',1,(5123,5125))['count']
            if count%3: raise ValueError('Incomplete triangle')
            total+=count//3
            positions.append(position)
    if not positions or len(doc.get('meshes',[]))!=group_count or sorted(used_materials)!=list(range(group_count)):
        raise ValueError('Require exactly four distinct runtime mesh/material groups')
    if len(doc.get('images',[]))!=1 or doc['images'][0].get('mimeType')!='image/png' or 'bufferView' not in doc['images'][0]:
        raise ValueError('Require one embedded atlas')
    offset=20+size
    if offset+8>len(data): raise ValueError('Missing GLB binary chunk')
    binary_size,binary_kind=struct.unpack_from('<II',data,offset)
    if binary_kind!=0x004e4942 or offset+8+binary_size!=len(data):
        raise ValueError('Invalid GLB binary chunk')
    binary=data[offset+8:]
    view=view_at(doc['images'][0]['bufferView'])
    start=view.get('byteOffset',0); end=start+view['byteLength']
    png=binary[start:end]
    if end>len(binary) or png[:8]!=b'\x89PNG\r\n\x1a\n' or len(png)<24 or struct.unpack('>II',png[16:24])!=(512,512):
        raise ValueError('Require embedded 512px PNG atlas')
    if any(m.get('pbrMetallicRoughness',{}).get('baseColorTexture',{}).get('index')!=0 for m in doc['materials']):
        raise ValueError('Every group must use the shared atlas')
    if not doc.get('samplers') or any(s.get('magFilter')!=9728 or s.get('minFilter')!=9728 for s in doc['samplers']):
        raise ValueError('Require nearest atlas sampling without mip bleed')
    low=[min(p['min'][i] for p in positions) for i in range(3)]
    high=[max(p['max'][i] for p in positions) for i in range(3)]
    return {'triangles':total,'runtime_mesh_nodes':sum('mesh' in n for n in doc.get('nodes',[])),
            'material_count':len(doc['materials']),'glb_bounds_min':low,'glb_bounds_max':high,
            'embedded_images':len(doc['images']),'bytes':len(data)}


def nearest_glb(data):
    """Blender exports Closest with mipmaps; omit them to prevent atlas color bleed."""
    size,kind=struct.unpack_from('<II',data,12)
    if kind!=0x4e4f534a: raise ValueError('Missing JSON chunk')
    doc=json.loads(data[20:20+size])
    if any(doc.get(k) for k in ('extensions','extensionsUsed','extensionsRequired')):
        raise ValueError('Require standard glTF without extensions')
    validate_materials(doc.get('materials',[]))
    textures=doc.get('textures',[])
    if not 1<=len(textures)<=len(MATERIALS) or any(t!={'source':0,'sampler':0} or any(type(t.get(k)) is not int for k in ('source','sampler')) for t in textures):
        raise ValueError('Unexpected atlas texture bindings')
    for material in doc.get('materials',[]):
        pbr=material.get('pbrMetallicRoughness',{})
        texture=pbr.get('baseColorTexture',{})
        if type(texture.get('index')) is not int or not 0<=texture['index']<len(textures):
            raise ValueError('Unexpected material texture binding')
        texture['index']=0
    # Blender can emit one identical texture record per material; keep one atlas binding.
    doc['textures']=[{'source':0,'sampler':0}]
    for sampler in doc.get('samplers',[]):
        if sampler.get('magFilter')!=9728: raise ValueError('Unexpected non-nearest export')
        sampler['minFilter']=9728
    body=json.dumps(doc,separators=(',',':')).encode(); body+=b' '*(-len(body)%4)
    tail=data[20+size:]
    return struct.pack('<III',0x46546c67,2,20+len(body)+len(tail))+struct.pack('<II',len(body),kind)+body+tail


def write_new(path,data):
    with Path(path).open('xb') as stream:
        stream.write(data)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True)
    parser.add_argument('--project',required=True)
    parser.add_argument('--reference',required=True)
    parser.add_argument('--material-reference',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    project=local_path(args.project)
    reference=pinned_file(args.reference,REFERENCE_SHA)
    material=material_reference(args.material_reference)
    helper=pinned_file(project/'tools/art_recipe.py',HELPER_SHA)
    for logical,digest in BASELINE_PINS.items(): pinned_file(project/logical,digest)
    root=validate_output(args.output,[project,reference.parent,material.parent,Path(__file__).resolve().parent.parent])
    parts=build_scene()
    low,high=bounds(parts)
    assert low[2]==0 and high[2]<=8.2 and all(-3.24<=low[i]<=high[i]<=3.24 for i in (0,1))
    assert triangles(parts)<21312
    assert low_geometry_radius(parts)<=3.3
    for part in parts:
        assert edge_counts(part)=={2} and signed_volume(part)>0,part.name
    sys.path.insert(0,str(helper.parent))
    from art_recipe import resolve_recipe
    assert resolve_recipe(project,'tools/art_recipe.py',HELPER_SHA)==helper
    import bpy
    from mathutils import Vector
    root.mkdir(parents=True,exist_ok=False)
    atlas=root/'skin_bell_atlas.png'
    # A new scene leaves any caller-owned Blender scene and objects intact.
    scene=bpy.data.scenes.new('Original skin bell v2'); bpy.context.window.scene=scene
    scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=64
    scene.cycles.use_denoising=True; scene.cycles.time_limit=75
    scene.render.threads_mode='FIXED'; scene.render.threads=2
    scene.render.resolution_x=896; scene.render.resolution_y=1024; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=False; scene.view_settings.view_transform='AgX'
    scene.world=bpy.data.worlds.new('Skin bell preview world'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.027,.033,.045,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.30
    image,original_material=build_material_atlas(bpy,material,atlas)
    scene['material_reference_image']=original_material.name
    scene['material_reference_sha256']=MATERIAL_SHA
    materials={}
    for group,metal,rough,emission in MATERIALS:
        mat=bpy.data.materials.new('skin_bell_'+group); mat.use_nodes=True
        mat.use_backface_culling=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Metallic'].default_value=metal; shader.inputs['Roughness'].default_value=rough
        shader.inputs['Emission Color'].default_value=(*emission,1)
        shader.inputs['Emission Strength'].default_value=1
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
        tex.extension='EXTEND'; mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        materials[group]=mat
    source=bpy.data.collections.new('Editable skin bell v2'); scene.collection.children.link(source)
    objects=[]
    for part in parts:
        mesh=bpy.data.meshes.new(part.name); mesh.from_pydata(part.vertices,[],part.faces); mesh.update()
        obj=bpy.data.objects.new(part.name,mesh); source.objects.link(obj)
        obj['structure_role']=part.role; obj['atlas_kind']=part.kind
        mesh.materials.append(materials[GROUPS[part.kind]])
        uv=mesh.uv_layers.new(name='Authored 512 atlas')
        minimum,maximum=bounds([part])
        for face in mesh.polygons:
            kind='inner' if part.role=='shell' and (len(BELL_PROFILE)-1)*SECTORS <= face.index < 2*(len(BELL_PROFILE)-1)*SECTORS else part.kind
            u0,v0,u1,v1=uv_rect(kind)
            n=face.normal; axes=(0,1) if abs(n.z)>.7 else (0,2) if abs(n.y)>.7 else (1,2)
            mins=[minimum[a] for a in axes]
            spans=[maximum[a]-minimum[a] for a in axes]
            for li in face.loop_indices:
                p=mesh.vertices[mesh.loops[li].vertex_index].co
                s=(p[axes[0]]-mins[0])/max(spans[0],1e-6); t=(p[axes[1]]-mins[1])/max(spans[1],1e-6)
                if part.role=='shell' and face.index<2*(len(BELL_PROFILE)-1)*SECTORS:
                    sector=face.index%SECTORS; vertex=mesh.loops[li].vertex_index
                    s=(sector+(vertex%SECTORS-sector)%SECTORS)/SECTORS
                    t=((vertex%(SECTORS*len(BELL_PROFILE)))//SECTORS)/(len(BELL_PROFILE)-1)
                uv.data[li].uv=(u0+s*(u1-u0),v0+t*(v1-v0))
            face.use_smooth=part.role not in ('niche_frame','niche_back','base','seal')
        objects.append(obj)
    preview=bpy.data.collections.new('Authoring preview only - not exported'); scene.collection.children.link(preview)
    for name,position,power,color,size in (('Key',(4,-6,10),1250,(1,.84,.68),5),
                                         ('Cool fill',(-5,-2,6),650,(.58,.71,1),5),
                                         ('Rim',(2,5,9),1400,(1,.60,.30),4)):
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=color; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(name,data); preview.objects.link(obj); obj.location=position
        obj.rotation_euler=(Vector((0,0,4.5))-obj.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new('Authoring camera'); camera=bpy.data.objects.new('Authoring camera',data)
    preview.objects.link(camera); scene.camera=camera; data.lens=47
    def pose_camera(position,target):
        camera.location=position; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    pose_camera((3,-16,4.4),(0,0,4))
    blend=root/'skin_bell_v2.blend'
    if blend.exists(): raise FileExistsError(blend)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=False)
    runtime=bpy.data.collections.new('Temporary runtime groups'); scene.collection.children.link(runtime)
    temporary=[]
    for group,mat in materials.items():
        bpy.ops.object.select_all(action='DESELECT'); copies=[]
        for obj in objects:
            if obj.data.materials[0]!=mat: continue
            copy=obj.copy(); copy.data=obj.data.copy(); runtime.objects.link(copy); copy.select_set(True); copies.append(copy)
        bpy.context.view_layer.update()
        bpy.context.view_layer.objects.active=copies[0]; bpy.ops.object.join()
        merged=bpy.context.object; merged.name='skin_bell_'+group; temporary.append(merged)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in temporary: obj.select_set(True)
    bpy.context.view_layer.objects.active=temporary[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    raw_glb=root/'skin_bell.export.glb'
    if raw_glb.exists(): raise FileExistsError(raw_glb)
    bpy.ops.export_scene.gltf(filepath=str(raw_glb),export_format='GLB',use_selection=True,use_active_scene=True,
        export_apply=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,
        export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True)
    glb=root/'skin_bell.glb'; write_new(glb,nearest_glb(raw_glb.read_bytes()))
    actual=inspect_glb(glb.read_bytes())
    assert actual['triangles']==triangles(parts)
    assert actual['runtime_mesh_nodes']==len(MATERIALS) and actual['bytes']<1675504
    expected_low=[low[0],low[2],-high[1]]; expected_high=[high[0],high[2],-low[1]]
    assert all(abs(a-b)<1e-5 for a,b in zip(actual['glb_bounds_min']+actual['glb_bounds_max'],expected_low+expected_high))
    runtime.hide_render=True; runtime.hide_viewport=True
    for name,position,target in (('skin_bell_hero.png',(3,-16,4.4),(0,0,4)),
                                 ('skin_bell_cavity.png',(1.5,-11,1.7),(0,0,4.35))):
        pose_camera(position,target); path=root/name
        if path.exists(): raise FileExistsError(path)
        scene.render.filepath=str(path); bpy.ops.render.render(write_still=True)
    def output_record(name):
        p=root/name
        return {'path':name,'sha256':sha(p),'bytes':p.stat().st_size}
    record={'id':'skin_bell','source':'source/art/skin_bell_v2.blend','source_sha256':sha(blend),
            'recipe_sha256':sha(__file__),'recipe_dependencies':{'tools/art_recipe.py':HELPER_SHA},
            'outputs':[dict(output_record('skin_bell.glb'),path='game/assets/art/world/skin_bell.glb')],
            'physical_bounds_m':{'min':low,'max':high,'size':[b-a for a,b in zip(low,high)],'axes':'Blender XYZ, Z up; GLB/Godot Y up'},
            'origin':'ground-centered at Blender (0,0,0); GLB Y up','loop_id':'intake_loop_bell',
            'triangles':actual['triangles'],'runtime_mesh_nodes':actual['runtime_mesh_nodes'],'material_count':actual['material_count'],
            'provenance':{'method':'original image-derived editable geometry and authored opaque pixel atlas',
                          'authoring_script':'tools/build_skin_bell_v2.py','imports':[],
                          'license':'Original NULL CHOIR project art',
                          'reference_sha256':REFERENCE_SHA,'reference_is_not_runtime_texture':True,
                          'material_reference_sha256':MATERIAL_SHA,
                          'atlas_method':'Blender Image.copy/scale to 512; exact full material input separately packed'}}
    write_new(root/'manifest.patch.json',(json.dumps(record,indent=2)+'\n').encode())
    for logical,digest in BASELINE_PINS.items(): pinned_file(project/logical,digest)
    pinned_file(reference,REFERENCE_SHA); material_reference(material)
    receipt={'native_outputs':[output_record(n) for n in FILENAMES if n!='build-record.json'],
             'structure':[{'name':p.name,'role':p.role,'kind':p.kind,'vertices':len(p.vertices),'triangles':triangles([p])} for p in parts],
             'actual_glb':actual,'source_meshes':len(objects),'reference_sha256':REFERENCE_SHA,
             'helper_sha256':HELPER_SHA,'recipe_sha256':sha(__file__),
             'round_base_fit':{'radius_m':3.3,'clearance_m':1.8,'actual_source_max_radius_m':low_geometry_radius(parts),
                               'includes_edge_intersections_at_clearance':True,'collider_unchanged':True},
             'material_reference_sha256':MATERIAL_SHA,
             'amber_emissive_factor':AMBER_EMISSION,
             'atlas':{'sha256':sha(atlas),'bytes':atlas.stat().st_size,'dimensions':[512,512],
                      'method':'Blender-native copied/scaled image; full-resolution input packed separately'},
             'preview':{'engine':'Cycles','device':'CPU','threads':2,'samples':64,'time_limit_seconds_each':75},
             'baseline_preserved':BASELINE_PINS,
             'runtime_unchanged':'skin_bell, loop_bell, cell 4.5/15.2, existing scene collision/lights/layout; integration not performed'}
    write_new(root/'build-record.json',(json.dumps(receipt,indent=2)+'\n').encode())
    print(json.dumps({'output':str(root),'glb':actual,'source_meshes':len(objects)}))


if __name__=='__main__':
    main()
