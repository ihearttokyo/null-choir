"""Original image-derived cathedral kit; background Blender, CPU/two threads only."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
import zlib

sys.dont_write_bytecode = True
REFERENCE_SHA = '67f9ecf5ee5dd1d7b54f05acc211a53beafa1eae5ca86b6acb2f014ae9fd9fb3'
KINDS = ('stone', 'bone', 'dark', 'brass', 'blue', 'amber', 'red', 'iron')
IDS = ('cathedral_vault_6m', 'cathedral_vault_9m', 'cathedral_cluster_pier',
       'cathedral_lancet_bay', 'cathedral_corner_rib', 'cathedral_skeletal_dado',
       'cathedral_brass_lamp', 'cathedral_inlay_tile')


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def isolated_output(root, project):
    root,project=Path(root).absolute(),Path(project).resolve()
    if '..' in root.parts or any(p.is_symlink() for p in (root,*root.parents)) or root.is_relative_to(project) or project.is_relative_to(root):
        raise ValueError('Candidate must not alias or overlap the production project')
    return root


def fresh(root, relative):
    root = Path(root).absolute()
    relative = Path(relative)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError('Output must be relative and contained')
    p = root / relative
    if any(x.is_symlink() for x in (p, *p.parents)):
        raise ValueError('Output root and ancestors must not be aliases')
    if p.exists():
        raise FileExistsError('Refuse to overwrite existing output: ' + str(p))
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def vault_parameters(ceiling):
    if ceiling not in (6, 9):
        raise ValueError('Only authored 6m and9m ceilings are supported')
    return ceiling - 2.5, ceiling - .35


def pointed(width, spring, peak, steps=24):
    # Two genuine circular arcs meet at a cusp, rather than stretching a round arch.
    rise = peak - spring
    c = (rise * rise - width * width) / (2 * width)
    radius = width + c
    angle = math.acos(c / radius)
    right = [(-c + radius * math.cos(angle * i / steps),
              spring + radius * math.sin(angle * i / steps)) for i in range(steps + 1)]
    return [(-x, z) for x, z in right] + list(reversed(right[:-1]))


def atlas(path):
    rng = random.Random(241010)
    colors = ((99,100,106),(174,162,133),(28,31,39),(147,104,49),
              (34,88,166),(255,157,45),(83,32,38),(64,70,75))
    pixels = bytearray()
    for y in range(512):
        for x in range(512):
            k = (y // 256) * 4 + x // 128
            xx, yy = x % 128, y % 256
            grain = rng.randrange(-9,10)
            warp = math.sin(xx*.032+yy*.041)*2.4 + math.sin(xx*.074-yy*.018)*1.8
            wave = math.sin(xx*.11+yy*.019+warp)
            crack = abs(math.sin(xx*.041+yy*.012+warp*.7)) > .997
            seam = k == 0 and ((yy % 64 < 2) or (xx + (yy // 64 % 2) * 32) % 64 < 2)
            vein = k in (1,2) and wave > .976
            d = grain - (36 if crack or seam else 0) + (22 if vein else 0)
            if k == 3: d += int(15 * math.sin(xx*.051+yy*.034+warp))
            if k == 4: d += 25 if (xx + yy) % 31 < 2 else 0
            pixels.extend((*[max(0,min(255,v+d)) for v in colors[k]],255))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw = b''.join(b'\0' + pixels[y*512*4:(y+1)*512*4] for y in range(512))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR',struct.pack('>IIBBBBB',512,512,8,6,0,0,0)) + chunk(b'IDAT',zlib.compress(raw,9)) + chunk(b'IEND',b''))


def tagged(obj, kind):
    obj['atlas_kind'] = kind
    return obj


def box(name, p, size, kind='stone', bevel=.015):
    return tagged(art.box(name,p,size,kind,bevel),kind)


def egg(name,p,scale,kind='bone',segments=12,rings=7):
    return tagged(art.egg(name,p,scale,kind,segments,rings),kind)


def tube(name,pts,radius,kind='stone',sides=8):
    return tagged(art.tube(name,pts,radius,kind,sides),kind)


def ring(name,p,r,t,kind='brass',plane='XY',segments=20):
    cx,cy,cz=p
    pts=[]
    for i in range(segments+1):
        a=i*math.tau/segments; u,v=r*math.cos(a),r*math.sin(a)
        pts.append((cx+u,cy+v,cz) if plane=='XY' else (cx+u,cy,cz+v) if plane=='XZ' else (cx,cy+u,cz+v))
    return tube(name,pts,t,kind,6)


def arch(name,width,spring,peak,y,radius=.06,kind='stone',steps=24):
    return tube(name,[(x,y,z) for x,z in pointed(width,spring,peak,steps)],radius,kind,6)


def skull(name,x,y,z,s=.15):
    egg(name+' cranial dome',(x,y,z),(s,s*.65,s*1.18),'bone',12,7)
    for side in (-1,1):
        egg(name+f' recessed eye {side}',(x+side*s*.43,y-s*.60,z+s*.13),(s*.32,s*.16,s*.34),'dark',10,5)
        tube(name+f' orbital brow {side}',[(x+side*s*.10,y-s*.65,z+s*.30),(x+side*s*.42,y-s*.73,z+s*.48),(x+side*s*.78,y-s*.61,z+s*.24)],s*.10,'bone',7)
        tube(name+f' cheek and jaw {side}',[(x+side*s*.76,y-s*.55,z-s*.09),(x+side*s*.56,y-s*.56,z-s*.68),(x,y-s*.58,z-s*.80)],s*.14,'bone',7)
    egg(name+' nasal cavity',(x,y-s*.70,z-s*.18),(s*.14,s*.09,s*.21),'dark',8,4)
    for i in range(6):
        box(name+f' tooth {i}',(x+(i-2.5)*s*.14,y-s*.72,z-s*.51),(s*.11,s*.16,s*.24),'bone',.004)


def skeleton(name,x,y,bottom,scale=1):
    z = bottom + 1.18*scale
    skull(name,x,y,z,.15*scale)
    for i in range(8):
        egg(name+f' vertebra {i}',(x,y,bottom+(.39+i*.09)*scale),(.048*scale,.07*scale,.045*scale),'bone',8,5)
    tube(name+' sternum',[(x,y-.09*scale,bottom+.59*scale),(x,y-.10*scale,bottom+1.00*scale)],.028*scale,'bone',7)
    for side in (-1,1):
        for i in range(6):
            h = bottom+(.60+i*.065)*scale
            w = (.17+math.sin(i/5*math.pi)*.08)*scale
            tube(name+f' curved raised rib {side} {i}',[(x,y,h+.04*scale),(x+side*w,y-.015*scale,h+.10*scale),(x+side*w*.93,y-.10*scale,h),(x+side*.045*scale,y-.13*scale,h-.045*scale)],.019*scale,'bone',7)
        tube(name+f' clavicle {side}',[(x,y-.06*scale,bottom+1.00*scale),(x+side*.29*scale,y,bottom+.96*scale)],.03*scale,'bone',8)
        tube(name+f' articulated arm {side}',[(x+side*.27*scale,y,bottom+.97*scale),(x+side*.36*scale,y-.03*scale,bottom+.62*scale),(x+side*.24*scale,y-.12*scale,bottom+.40*scale)], [.043*scale,.025*scale,.02*scale],'bone',8)
        ring(name+f' hip lobe {side}',(x+side*.075*scale,y,bottom+.40*scale),.10*scale,.023*scale,'bone','XZ',12)
        tube(name+f' femur and shin {side}',[(x+side*.10*scale,y,bottom+.36*scale),(x+side*.19*scale,y-.045*scale,bottom+.17*scale),(x+side*.23*scale,y-.06*scale,bottom+.04*scale)], [.037*scale,.026*scale,.023*scale],'bone',8)
        egg(name+f' kneecap {side}',(x+side*.19*scale,y-.05*scale,bottom+.17*scale),(.045*scale,.038*scale,.047*scale),'bone',8,5)
        tube(name+f' foot {side}',[(x+side*.23*scale,y,bottom+.04*scale),(x+side*.27*scale,y-.13*scale,bottom+.025*scale)],.033*scale,'bone',7)
        for digit in range(3):
            tube(name+f' finger {side} {digit}',[(x+side*(.22+digit*.025)*scale,y-.13*scale,bottom+.42*scale),(x+side*(.24+digit*.025)*scale,y-.16*scale,bottom+.33*scale)],.01*scale,'bone',5)


def vault(ceiling):
    spring, peak = vault_parameters(ceiling)
    for side in (-1,1):
        x = side*1.83
        box('Portal terraced plinth',(x,0,.12),(.46,.72,.24),'dark',.025)
        for j in range(4):
            xx, yy = x+side*(j%2)*.11, -.20+(j//2)*.22
            tube(f'Portal bundled jamb {side} {j}',[(xx,yy,.23),(xx,yy,spring-.16)],.076 if j%2 else .095,'stone',10)
            for z in (.29,spring-.23,spring-.06):
                ring('Jamb carved ring',(xx,yy,z),.092,.021,'bone',segments=12)
        skull('Portal capital mask',x,-.32,spring-.20,.09)
    for j in range(4):
        arch(f'Portal layered pointed rib {j}',1.65+j*.077,spring,peak+j*.036,-.28+j*.18,.07 if j%2 else .10,'stone',24)
    path = pointed(1.93,spring,peak+.10,24)
    for i in range(0,len(path)-1,2):
        x,z = path[i]
        egg('Individual weathered voussoir',(x,.20,z),(.115,.17,.13),'bone',8,5)
    for side in (-1,1):
        for i in range(7):
            x = side*(.24+i*.19)
            z = peak-.14-i*.20
            tube('Crochet ossified tip',[(x,-.25,z),(x+side*.07,-.32,z+.12),(x+side*.03,-.28,z+.23)], [.035,.031,.009],'bone',6)
    ring('Cusp restrained brass seal',(0,-.30,peak-.19),.13,.024,'brass','XZ',16)


def pier():
    box('Pier lower spreading foot',(0,0,.13),(1.03,.87,.26),'dark',.035)
    box('Pier worn stepped plinth',(0,0,.34),(.87,.76,.17),'stone',.025)
    tube('Octagonal structural core',[(0,0,.40),(0,0,5.18)],.23,'stone',12)
    for i in range(8):
        a = i*math.tau/8
        x,y = .30*math.cos(a),.30*math.sin(a)
        tube(f'Cluster shaft {i}',[(x,y,.40),(x,y,5.14)],.084,'bone' if i%3==0 else 'stone',10)
        for z in (.48,2.01,4.25,5.09):
            ring('Carved shaft collar',(x,y,z),.103,.022,'brass' if z==2.01 else 'bone',segments=14)
        tube('Capital unfurling cartilage',[(x,y,4.88),(x*1.5,y*1.5,5.20),(x*1.60,y*1.60,5.38)], [.062,.08,.019],'bone',8)
    for z in (1.91,4.19,5.21):
        ring('Pier octagonal binding band',(0,0,z),.41,.048,'stone',segments=8)
    skull('Pier mounted memento',(0),-.39,2.63,.16)
    for side in (-1,1):
        tube('Long anatomical capital relief',[(side*.12,-.32,2.32),(side*.22,-.37,3.10),(side*.16,-.34,3.91)], [.036,.051,.018],'bone',8)
        for i in range(6):
            z=2.50+i*.20
            tube('Pier rib volute',[(0,-.35,z),(side*.22,-.41,z+.11),(side*.27,-.34,z+.27)],.027,'bone',6)


def lancet():
    for side in (-1,1):
        box('Stone lateral wall mass',(side*1.68,.17,2.80),(.62,.54,5.60),'stone',.03)
        for z in (.18,1.0,5.46):
            box('Projecting sill and cornice',(0,-.01,z),(4,.75,.21),'stone',.026)
        for j in range(3):
            tube('Recessed fluted wall jamb',[(side*(1.22+j*.09),-.20+j*.09,1.1),(side*(1.22+j*.09),-.20+j*.09,3.75)],.062,'bone',8)
    # Real recessed panes sit behind the projecting tracery; no concept-image plane.
    path = pointed(1.13,3.60,5.24,24)
    vertices = [(-1.13,.30,1.13),(1.13,.30,1.13)] + [(x,.30,z) for x,z in reversed(path)]
    tagged(art.mesh('Recessed cold lancet glazing',vertices,[tuple(range(len(vertices)))],'blue'),'blue')
    for j in range(3):
        arch('Deep lancet reveal molding',1.15+j*.09,3.60,5.24+j*.07,-.19+j*.13,.074,'stone',20)
    for x in (-.58,0,.58):
        tube('Independent window mullion',[(x,-.03,1.16),(x,-.03,3.51)],.035,'stone',7)
    for side in (-1,1):
        arch('Secondary split lancet',.55,3.15,4.15,-.04,.037,'bone',18).location.x=side*.58
    ring('Tracery rose outer',(0,-.04,4.48),.40,.049,'stone','XZ',24)
    for i in range(5):
        a=i*math.tau/5
        ring('Tracery cinquefoil petal',(.22*math.sin(a),-.07,4.48+.22*math.cos(a)),.135,.025,'bone','XZ',14)
    for i in range(6):
        x=-1.55+i*.62
        arch('Blind lower arcade',.24,.32,.78,-.41,.035,'bone',12).location.x=x
    for side in (-1,1):
        skull('Wall corbel witness',side*1.68,-.20,3.36,.13)
        for i in range(5):
            box('Wall dressed quoin',(side*1.73,-.16,1.25+i*.62),(.44,.10,.11),'bone',.008)


def corner():
    box('Corner mounting base',(0,.10,.18),(.80,.73,.36),'stone',.03)
    for x in (-.20,0,.20):
        tube('Corner clustered stem',[(x,.04,.32),(x,.04,1.80)],.075,'stone',10)
    box('Corbel abacus',(0,.02,1.78),(1.02,.78,.22),'bone',.025)
    for side in (-1,1):
        for j in range(3):
            tube('Bifurcated vault spring',[(side*.09,.0+j*.15,1.92),(side*.31,.0+j*.15,2.40),(side*.65,.0+j*.15,2.91),(side*1.35,.0+j*.15,3.34)], [.10,.11,.083,.041],'stone' if j else 'bone',10)
        skull('Corner undercroft mask',side*.26,-.32,1.52,.13)
    for i in range(5):
        tube('Corner carved pendant flute',[(0,-.28,.50+i*.16),(.12,-.33,.60+i*.16),(0,-.31,.71+i*.16)],.026,'bone',7)


def dado():
    for z,size in ((.09,(4,.70,.18)),(.26,(3.82,.55,.15)),(1.90,(4,.67,.19)),(2.05,(3.88,.56,.12))):
        box('Dado stepped molding',(0,.05,z),size,'stone',.022)
    box('Relief deep backing',(0,.22,1.06),(3.83,.20,1.59),'dark',.025)
    for x in (-1.28,0,1.28):
        skeleton('Raised captive skeletal relief',x,-.10,.37,1.04)
        arch('Dado ogival niche surround',.49,1.32,1.82,-.18,.051,'stone',16).location.x=x
        for side in (-1,1):
            tube('Dado paired niche pilaster',[(x+side*.53,-.11,.32),(x+side*.53,-.11,1.34)],.061,'bone',8)
        for i in range(4):
            egg('Carved niche rim bud',(x+(-.35+i*.23),-.21,1.84),(.045,.043,.053),'bone',8,5)
    for x in (-1.87,-.64,.64,1.87):
        skull('Dado spandrel mask',x,-.15,1.75,.07)


def lamp():
    box('Lamp wall mounting plate',(0,.14,1.45),(.28,.14,1.15),'iron',.04)
    tube('Lamp swept brass bracket',[(0,.06,1.80),(0,-.25,2.16),(0,-.74,2.25),(0,-1.04,2.04)], [.055,.043,.040,.03],'brass',8)
    for i in range(6):
        ring('Articulated hanging chain',(0,-1.04,2.00-i*.10),.071,.014,'brass','XZ' if i%2 else 'YZ',12)
    center=(0,-1.04,.99)
    for z,r,t in ((.40,.23,.036),(.56,.31,.045),(1.22,.31,.04),(1.38,.23,.035)):
        ring('Lantern raised cage flange',(0,-1.04,z),r,t,'brass',segments=24)
    egg('Enclosed amber lamp chamber',center,(.20,.20,.35),'amber',16,10)
    for i in range(8):
        a=i*math.tau/8
        x,dy=.275*math.cos(a),.275*math.sin(a)
        tube('Lantern individually curled stave',[(x*.80,-1.04+dy*.80,.42),(x,-1.04+dy,.62),(x,-1.04+dy,1.17),(x*.62,-1.04+dy*.62,1.42)], [.029,.025,.025,.013],'brass',8)
        egg('Lantern finial rivet',(x,-1.04+dy,.57),(.040,.040,.040),'brass',8,5)
    for z,s in ((.29,(.09,.09,.18)),(1.48,(.12,.12,.12))):
        egg('Lamp pointed finial',(0,-1.04,z),s,'brass',10,7)
    skull('Bracket suspended ivory seal',0,-.40,1.76,.075)
    for side in (-1,1):
        tube('Bracket filigree curl',[(0,-.15,1.75),(side*.18,-.35,1.94),(side*.13,-.58,2.05),(0,-.69,2.04)],.025,'brass',7)


def tile():
    box('Inlay dark carved stone slab',(0,0,.035),(4,4,.07),'dark',.018)
    for x in (-1.95,0,1.95):
        box('Floor real recessed brass straight inlay',(x,0,.074),(.025,3.91,.010),'brass',.001)
        box('Floor orthogonal inlay',(0,x,.074),(3.91,.025,.010),'brass',.001)
    ring('Floor restraint sigil outer',(0,0,.077),1.12,.018,'brass',segments=48)
    ring('Floor restraint sigil inner',(0,0,.077),.41,.020,'brass',segments=32)
    for i in range(8):
        a=i*math.tau/8
        tube('Floor engraved radial',[(math.cos(a)*.42,math.sin(a)*.42,.079),(math.cos(a)*1.10,math.sin(a)*1.10,.079)],.014,'brass',5)
        for j in range(3):
            r=1.44+j*.18
            egg('Edge rivet recessed in stone',(r*math.cos(a),r*math.sin(a),.08),(.024,.024,.008),'brass',8,4)


def uv_map(obj):
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Authored 512px kit atlas')
    for layer in list(obj.data.uv_layers):
        if layer != uv: obj.data.uv_layers.remove(layer)
    uv.name='Authored 512px kit atlas'
    obj.data.uv_layers.active_index=0
    uv.active_render=True
    k=KINDS.index(obj['atlas_kind']); col,row=k%4,k//4
    for face in obj.data.polygons:
        n=face.normal
        axes=(0,1) if abs(n.z)>.7 else (0,2) if abs(n.y)>.7 else (1,2)
        for li in face.loop_indices:
            p=obj.data.vertices[obj.data.loops[li].vertex_index].co
            u,v=(p[axes[0]]*.65%1),(p[axes[1]]*.65%1)
            uv.data[li].uv=((col+(2+u*124)/128)/4,1-(row+(2+v*252)/256)/2)


def main():
    global bpy, art
    import bpy
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    from share_cathedral_atlas import externalize_atlas
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root',type=Path,required=True)
    parser.add_argument('--helper-root',type=Path,required=True)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if sha(args.reference)!=REFERENCE_SHA: raise ValueError('Selected reference changed')
    root=isolated_output(args.output_root,args.helper_root)
    # Reuse original geometry/export conventions without invoking any canonical writer.
    sys.path.insert(0,str(args.helper_root/'tools'))
    import build_art as art
    art.ROOT=root; art.ART=root/'source/art'; art.OUT=root/'game/assets/art'; art.SCRATCH=root/'previews'
    source=fresh(root,Path('source/art/cathedral_kit.blend'))
    texpath=fresh(root,Path('game/assets/art/textures/cathedral_kit_atlas.png'))
    manifestpath=fresh(root,Path('manifest.patch.json'))
    outputs={asset:fresh(root,Path('game/assets/art/world')/(asset+'.glb')) for asset in IDS}
    raw_exports={asset:fresh(root,Path('previews/raw_exports')/(asset+'.glb')) for asset in IDS}
    scene=art.setup(); scene.render.threads=2; scene.cycles.samples=8
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.05,.07,.11,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    atlas(texpath)
    image=bpy.data.images.load(str(texpath)); image.pack()
    mats=[]
    for name,metal,emission in (('Cathedral carved atlas',0,0),('Cathedral brass atlas',.72,0),('Cathedral light atlas',0,.55)):
        mat=art.material(name,'#ffffff',metal=metal,rough=.68 if not metal else .40,image=image)
        shader=mat.node_tree.nodes.get('Principled BSDF')
        if emission:
            texture=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE')
            mat.node_tree.links.new(texture.outputs['Color'],shader.inputs['Emission Color'])
            shader.inputs['Emission Strength'].default_value=emission
        mats.append(mat)
    art.M.clear(); art.M.update({k:mats[1 if k=='brass' else 2 if k in ('blue','amber') else 0] for k in KINDS})
    records=[]; collections=[]
    builders=(lambda:vault(6),lambda:vault(9),pier,lancet,corner,dado,lamp,tile)
    offsets=((-6,0,0),(0,0,0),(6,0,0),(-6,-5,0),(0,-5,0),(6,-5,0),(-6,-9,0),(1,-10,0))
    for asset,builder,offset in zip(IDS,builders,offsets):
        before=set(scene.objects); builder(); bpy.context.view_layer.update()
        objects=[o for o in scene.objects if o not in before and o.type=='MESH']
        bounds=art.bounds(objects); triangles=sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)
        assert triangles>500,asset
        for obj in objects: uv_map(obj)
        collection=bpy.data.collections.new(asset); scene.collection.children.link(collection)
        for obj in objects:
            for old in list(obj.users_collection): old.objects.unlink(obj)
            collection.objects.link(obj)
        collections.append(collection)
        temporary=[]
        for mat in mats:
            group=[o for o in objects if o.data.materials[0]==mat]
            if not group: continue
            bpy.ops.object.select_all(action='DESELECT')
            copies=[]
            for obj in group:
                c=obj.copy(); c.data=obj.data.copy(); scene.collection.objects.link(c); c.select_set(True); copies.append(c)
            bpy.context.view_layer.objects.active=copies[0]; bpy.ops.object.join()
            merged=bpy.context.object; merged.name=asset+'_'+str(len(temporary)); temporary.append(merged)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in temporary: obj.select_set(True)
        bpy.context.view_layer.objects.active=temporary[0]
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        bpy.ops.export_scene.gltf(filepath=str(raw_exports[asset]),export_format='GLB',use_selection=True,
            export_apply=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,
            export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True)
        raw=raw_exports[asset].read_bytes()
        packed=externalize_atlas(raw,texpath.read_bytes())
        with outputs[asset].open('xb') as output: output.write(packed)
        for obj in temporary: bpy.data.objects.remove(obj,do_unlink=True)
        anchor=bpy.data.objects.new(asset+' authored origin',None); collection.objects.link(anchor); anchor.location=offset
        for obj in objects: obj.parent=anchor
        records.append(dict(id=asset,source='source/art/cathedral_kit.blend',source_collection=asset,
            outputs=[dict(path=str(outputs[asset].relative_to(root)),sha256=sha(outputs[asset]),bytes=outputs[asset].stat().st_size)],
            packaging=dict(raw_export=str(raw_exports[asset].relative_to(root)),raw_sha256=sha(raw_exports[asset]),raw_bytes=len(raw),
                packed_sha256=sha(outputs[asset]),packed_bytes=len(packed),atlas_sha256=sha(texpath),atlas_uri='../textures/cathedral_kit_atlas.png',
                method='Identical PNG externalized; all non-image buffer view bytes preserved'),
            triangles=triangles,runtime_mesh_nodes=len(temporary),material_count=len(temporary),physical_bounds_m=bounds,
            bay_width_m=4,front='Blender -Y -> Godot +Z; Blender Z up -> Godot Y up',
            origin='Ground centered; Blender Z=0 mounts to existing floor unless mount specifies otherwise',
            mounting=dict(surface='floor' if asset in IDS[:3] or asset==IDS[-1] else 'boundary wall',
                backing_axis='Blender +Y; Godot -Z',
                recommended_origin_height_m='ceiling minus3.55' if asset=='cathedral_corner_rib' else '2.65' if asset=='cathedral_brass_lamp' else '0',
                collision='Visual only; preserve existing native floor and wall collisions'),
            safe_clearance=dict(central_passage_width_m=3.0,central_passage_height_m=2.7) if asset.startswith('cathedral_vault') else
                dict(rule='Keep outside traversable aisle; mount backing against boundary; use native bounds to check player capsule'),
            ceiling_m=6 if asset.endswith('6m') else 9 if asset.endswith('9m') else None,
            provenance=dict(method='Original modeled geometry and deterministic authored texture atlas',authoring_script='tools/build_cathedral_kit.py',imports=[],license='Original NULL CHOIR project art',reference_sha256=REFERENCE_SHA)))
        print('KIT_ASSET',asset,'triangles',triangles,'bytes',outputs[asset].stat().st_size,flush=True)
    bpy.context.view_layer.update()
    art.camera(scene,(18,-32,23),(0,-3,3.0),25,1280,800)
    scene.render.film_transparent=False
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=False,check_existing=False)
    for record in records: record['source_sha256']=sha(source); record['recipe_sha256']=sha(__file__)
    total=sum(r['outputs'][0]['bytes'] for r in records)+texpath.stat().st_size
    assert total<=5_000_000,('runtime byte cap',total)
    manifestpath.write_text(json.dumps(dict(schema_version=1,operation='append_assets_only',assets=records,
        shared_texture=dict(path=str(texpath.relative_to(root)),sha256=sha(texpath),bytes=texpath.stat().st_size,dimensions=[512,512]),
        recipe_sha256=sha(__file__),packing_sha256=sha(Path(__file__).with_name('share_cathedral_atlas.py')),helper_sha256=sha(args.helper_root/'tools/build_art.py'),
        triangles=sum(r['triangles'] for r in records),runtime_total_bytes=total,
        reference_sha256=REFERENCE_SHA,source_layout='Collection parent offsets are presentation only; GLBs export local authored origins before layout'),indent=2)+'\n')
    if args.render:
        scene.render.filepath=str(fresh(root,Path('previews/cathedral_kit_source.png')))
        bpy.ops.render.render(write_still=True)
        scene.render.resolution_x=640; scene.render.resolution_y=360
        scene.render.filepath=str(fresh(root,Path('previews/cathedral_kit_640.png')))
        bpy.ops.render.render(write_still=True)
    print('KIT_COMPLETE',total,flush=True)

if __name__=='__main__': main()
