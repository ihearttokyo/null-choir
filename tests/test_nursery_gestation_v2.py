import ast
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest

SOURCE = Path(__file__).parents[1] / 'tools/build_nursery_gestation_v2.py'
spec = importlib.util.spec_from_file_location('nursery_v2', SOURCE)
art = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = art
spec.loader.exec_module(art)


def fixture():
    data = bytearray()
    views, accessors = [], []
    def acc(values, fmt, kind, component, low=None, high=None):
        while len(data) % 4:
            data.append(0)
        offset = len(data)
        for v in values:
            data.extend(struct.pack('<' + fmt, *v))
        views.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(data)-offset})
        a = {'bufferView': len(views)-1, 'componentType': component, 'count': len(values), 'type': kind}
        if low is not None:
            a.update(min=low, max=high)
        accessors.append(a)
        return len(accessors)-1
    p = acc([(0,0,0),(.5,0,0),(0,.5,0)], '3f', 'VEC3', 5126, [0,0,0], [.5,.5,0])
    n = acc([(0,0,1)]*3, '3f', 'VEC3', 5126)
    uv=[]
    for m in list(art.MATERIALS.values())[:4]:
        col=m['tile']%4;row=1-m['tile']//4
        uv.append(acc([((col+.1)/4,1-(row+.1)/2),((col+.8)/4,1-(row+.1)/2),((col+.1)/4,1-(row+.8)/2)], '2f', 'VEC2', 5126))
    i = acc([(0,),(1,),(2,)], 'H', 'SCALAR', 5123)
    while len(data) % 4:
        data.append(0)
    image_offset = len(data)
    # Header fixture proves typed PNG dimensions; native decoder remains a parent gate.
    data.extend(b'\x89PNG\r\n\x1a\n' + struct.pack('>I',13) + b'IHDR' + struct.pack('>II',512,512) + bytes(9))
    views.append({'buffer':0,'byteOffset':image_offset,'byteLength':33})
    mats=[]
    for name, m in art.MATERIALS.items():
        pbr={'baseColorFactor':list(m['color']), 'metallicFactor':m['metallic'], 'roughnessFactor':m['roughness']}
        if name != 'shell':
            pbr['baseColorTexture']={'index':0}
        mats.append({'name':'nursery_v2_'+name,'alphaMode':m['alpha'], 'doubleSided':False,'pbrMetallicRoughness':pbr, 'emissiveFactor':list(m.get('emission',(0,0,0)))})
    doc={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':list(range(5))}],
         'nodes':[{'mesh':j} for j in range(5)],
         'meshes':[{'primitives':[{'attributes':{'POSITION':p,'NORMAL':n,**({'TEXCOORD_0':uv[j]} if j<4 else {})},'indices':i,'material':j,'mode':4}]} for j in range(5)],
         'materials':mats,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':accessors,
         'images':[{'bufferView':len(views)-1,'mimeType':'image/png'}], 'textures':[{'source':0,'sampler':0}],
         'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]}
    return doc,bytes(data)


class Geometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts=art.build_parts()

    def test_transparent_shell_and_separate_opaque_anatomy(self):
        self.assertEqual([m['alpha'] for m in art.MATERIALS.values()], ['OPAQUE']*4+['BLEND'])
        self.assertEqual(art.MATERIALS['shell']['color'][3],.18)
        self.assertEqual(len([p for p in self.parts if p.material=='shell']),1)
        self.assertTrue(any('cranium' in p.name and p.material!='shell' for p in self.parts))

    def test_actual_bounds_box_contacts_and_budget(self):
        r=art.geometry_report(self.parts)
        self.assertLessEqual(r['triangles'],20000)
        self.assertLessEqual(r['bounds'][1][2],8.43)
        self.assertEqual(r['bounds'][0][2],0)
        self.assertEqual(len(r['contacts']),4)
        for p in self.parts:
            for x,y,z in art.low_vertices(p,1.8):
                self.assertLessEqual(abs(x),1.925+1e-7)
                self.assertLessEqual(abs(y),1.575+1e-7)

    def test_shell_convex_manifold_outward_containment(self):
        s=next(p for p in self.parts if p.material=='shell')
        planes=art.shell_planes(s)
        edges={}
        for face in s.faces:
            for a,b in zip(face,face[1:]+face[:1]):
                edges[(min(a,b),max(a,b))]=edges.get((min(a,b),max(a,b)),0)+1
        self.assertEqual(set(edges.values()),{2})
        for v in s.vertices:
            self.assertTrue(all(art.dot(n,v)-d<=1e-7 for n,d in planes))
        for p in self.parts:
            if p.assembly=='anatomy':
                for v in p.vertices:
                    self.assertTrue(all(art.dot(n,v)-d<=-.08+1e-6 for n,d in planes),p.name)

    def test_negative_spaces_and_real_niches(self):
        names=[p.name for p in self.parts]
        self.assertGreaterEqual(sum('costal' in n for n in names),16)
        self.assertGreaterEqual(sum('niche' in n for n in names),4)
        self.assertGreaterEqual(sum('socket' in n for n in names),8)
        self.assertTrue(art.front_hits(self.parts,(0, -3, 6.5),'cranium'))
        self.assertFalse(art.front_hits(self.parts,(.8,-3,4.7),'costal'))

    def test_finite_faces_positive_volume(self):
        for p in self.parts:
            art.validate_part(p)
            self.assertGreater(art.signed_volume(p),0,p.name)

    def test_dorsal_process_frames_do_not_flip_or_reverse_winding(self):
        for p in self.parts:
            if not p.name.startswith('dorsal vertebral process'):
                continue
            centers=[tuple(sum(p.vertices[r*6+j][k] for j in range(6))/6 for k in range(3)) for r in range(3)]
            for r in range(2):
                u=art.unit(art.sub(p.vertices[r*6],centers[r]))
                v=art.unit(art.sub(p.vertices[(r+1)*6],centers[r+1]))
                self.assertGreater(art.dot(u,v),0,p.name)
            for face in p.faces[:-2]:
                for j in range(1,len(face)-1):
                    ids=(face[0],face[j],face[j+1])
                    a,b,c=[p.vertices[i] for i in ids]
                    normal=art.cross(art.sub(b,a),art.sub(c,a))
                    radial=tuple(sum(p.vertices[i][k]-centers[i//6][k] for i in ids)/3 for k in range(3))
                    self.assertGreater(art.dot(normal,radial),0,p.name)

    def test_neutral_shell_reduces_colored_diffuse_without_changing_alpha(self):
        self.assertEqual(art.MATERIALS['shell']['color'],(.10,.10,.10,.18))

    def test_only_basal_amber_has_restrained_emission(self):
        self.assertEqual(art.MATERIALS['amber'].get('emission'),(.38,.16,.035))
        for name,spec in art.MATERIALS.items():
            if name!='amber':
                self.assertEqual(spec.get('emission',(0,0,0)),(0,0,0))

    def test_visual_ground_footprint_matches_unchanged_authored_base(self):
        bounds=art.geometry_report(self.parts)['bounds']
        self.assertAlmostEqual(bounds[1][0]-bounds[0][0],3.85,places=6)
        self.assertAlmostEqual(bounds[1][1]-bounds[0][1],3.15,places=6)

    def test_low_plane_intersection_is_checked(self):
        p=art.Part('cross','brass','architecture',[(0,0,1),(4,0,2),(0,1,2)],[(0,1,2)])
        self.assertTrue(any(x>1.925 for x,y,z in art.low_vertices(p,1.8)))

    def test_cranium_and_perforated_piers_have_closed_paired_edges(self):
        head=next(p for p in self.parts if p.material=='bone' and 'cranium' in p.name)
        sockets=[p for p in self.parts if p.name.startswith('vertebral open socket')]
        self.assertEqual(len(sockets),36)
        for p in [head]+sockets:
            edges={}
            for face in p.faces:
                for a,b in zip(face,face[1:]+face[:1]):
                    edges.setdefault((min(a,b),max(a,b)),[]).append((a,b))
            for uses in edges.values():
                self.assertEqual(len(uses),2,p.name)
                self.assertEqual(uses[0],tuple(reversed(uses[1])),p.name)

    def test_cranium_has_deep_unequal_orbital_excavations(self):
        def hits(material,x,z):
            out=[]
            for p in self.parts:
                if p.material!=material or 'cranium' not in p.name:continue
                for ia,ib,ic in art.triangles(p):
                    a,b,c=[p.vertices[i] for i in (ia,ib,ic)]
                    e1,e2=art.sub(b,a),art.sub(c,a);direction=(0,1,0)
                    h=art.cross(direction,e2);det=art.dot(e1,h)
                    if abs(det)<1e-9:continue
                    s=art.sub((x,-3,z),a);u=art.dot(s,h)/det;q=art.cross(s,e1);v=art.dot(direction,q)/det;t=art.dot(e2,q)/det
                    if 0<=u<=1 and 0<=v and u+v<=1 and t>0:out.append(-3+t)
            return sorted(out)
        for x,z in [(-.145,6.28),(.14,6.38)]:
            bone=hits('bone',x,z);dark=hits('tissue',x,z)
            self.assertTrue(bone and dark,'true bony aperture and inset opaque tissue required')
            self.assertGreater(bone[0],.02,'white superficial eye arch or solid cranium still blocks the cavity')
            self.assertLess(dark[0],bone[0]-.08,'orbital dark backing must sit inside the excavation')
        head=next(p for p in self.parts if p.material=='bone' and 'cranium' in p.name)
        self.assertGreater(max(v[2] for v in head.vertices)-min(v[2] for v in head.vertices),1.4)


class Form(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts=art.build_parts()

    @staticmethod
    def overlap(a,b,tolerance=1e-7):
        return all(min(max(v[k] for v in a.vertices),max(v[k] for v in b.vertices))-
                   max(min(v[k] for v in a.vertices),min(v[k] for v in b.vertices))>=-tolerance for k in range(3))

    @staticmethod
    def closed(part):
        edges={}
        for face in part.faces:
            for a,b in zip(face,face[1:]+face[:1]):edges.setdefault((min(a,b),max(a,b)),[]).append((a,b))
        return bool(edges) and all(len(uses)==2 and uses[0]==tuple(reversed(uses[1])) for uses in edges.values())

    @classmethod
    def contains(cls,part,point,tolerance=1e-7):
        if not cls.closed(part):raise ValueError('Containment requires an oriented closed target')
        angle=0
        for ids in art.triangles(part):
            a,b,c=[part.vertices[i] for i in ids]
            normal=art.unit(art.cross(art.sub(b,a),art.sub(c,a)))
            if abs(art.dot(art.sub(point,a),normal))<=tolerance and all(
                art.dot(art.cross(art.sub(v,u),art.sub(point,u)),normal)>=
                -tolerance*math.sqrt(art.dot(art.sub(v,u),art.sub(v,u)))
                for u,v in ((a,b),(b,c),(c,a))):
                return True
            va,vb,vc=[art.sub(v,point) for v in (a,b,c)]
            la,lb,lc=[math.sqrt(art.dot(v,v)) for v in (va,vb,vc)]
            angle+=2*math.atan2(art.dot(va,art.cross(vb,vc)),
                               la*lb*lc+art.dot(va,vb)*lc+art.dot(vb,vc)*la+art.dot(vc,va)*lb)
        return abs(angle)>2*math.pi

    @classmethod
    def contact(cls,a,b):
        if not cls.overlap(a,b):return False
        # shortcut: vertex containment proves these joints; add edge/triangle checks for future crossing-only joints.
        return any(cls.closed(target) and any(cls.contains(target,v) for v in subject.vertices)
                   for target,subject in ((b,a),(a,b)))

    def test_empty_aperture_box_overlap_is_not_contact(self):
        lancet=next(p for p in self.parts if p.name=='base lancet control 1 0')
        probe=art.egg('in-memory aperture probe','brass','architecture',(.32,-.78,.65),(.025,.025,.025))
        self.assertTrue(self.overlap(probe,lancet))
        self.assertGreater(art.signed_volume(probe),0)
        self.assertFalse(self.contact(probe,lancet))
        embedded=art.egg('in-memory solid-wall probe','brass','architecture',(.44,-.78,.65),(.005,.005,.005))
        self.assertTrue(self.contact(embedded,lancet))

    def test_detached_curved_arch_box_overlap_is_not_contact(self):
        arch=copy.deepcopy(next(p for p in self.parts if p.name=='vessel framing arch -1 1'))
        arch.vertices=[(x,y-.7,z) for x,y,z in arch.vertices]
        crown=next(p for p in self.parts if p.name=='crown central living suspension')
        self.assertTrue(self.overlap(arch,crown))
        self.assertGreater(art.signed_volume(arch),0)
        self.assertFalse(self.contact(arch,crown))

    def test_contact_containment_boundary_tolerance_and_outside(self):
        box=art.Part('closed boundary fixture','brass','architecture',
            [(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)],
            [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        self.assertGreater(art.signed_volume(box),0)
        tolerance=1e-7
        for point in [(.5,.5,.5),(1,.5,.5),(1+tolerance/2,.5,.5)]:
            self.assertTrue(self.contains(box,point))
        self.assertFalse(self.contains(box,(1+tolerance*4,.5,.5)))
        inside=art.egg('contained fixture','brass','architecture',(.5,.5,.5),(.025,.025,.025))
        self.assertTrue(self.contact(box,inside));self.assertTrue(self.contact(inside,box))
        for gap,expected in [(0,True),(tolerance/2,True),(tolerance*4,False),(.2,False)]:
            shifted=copy.deepcopy(box);shifted.vertices=[(x+1+gap,y,z) for x,y,z in shifted.vertices]
            with self.subTest(gap=gap):self.assertEqual(self.contact(box,shifted),expected)
        open_box=copy.deepcopy(box);open_box.faces=open_box.faces[1:]
        self.assertFalse(self.closed(open_box))
        with self.assertRaises(ValueError):self.contains(open_box,(.5,.5,.5))

    def test_basal_machine_connects_feet_and_all_six_lancets(self):
        basal=[p for p in self.parts if p.name.startswith('basal ')]
        feet=[p for p in self.parts if p.name.startswith('grounded foot')]
        lancets=[p for p in self.parts if p.name.startswith('base lancet control')]
        self.assertGreaterEqual(len(basal),8,'closed grounded manifold/crossbeams are absent')
        self.assertEqual(len(feet),4);self.assertEqual(len(lancets),6)
        nodes=basal+feet+lancets;seen={0}
        while True:
            added={j for j,p in enumerate(nodes) if any(self.contact(p,nodes[i]) for i in seen)}
            if added<=seen:break
            seen|=added
        self.assertEqual(len(seen),len(nodes),'a basal part, foot or lancet physically floats')
        for p in basal:
            self.assertLessEqual(max(v[2] for v in p.vertices),1.8)
            self.assertGreater(art.signed_volume(p),0)

    def test_layered_gothic_frame_attaches_and_keeps_views_open(self):
        frames=[p for p in self.parts if p.name.startswith('vessel framing arch')]
        corbels=[p for p in self.parts if p.name.startswith('layered pier corbel')]
        buttresses=[p for p in self.parts if p.name.startswith('rooted flying buttress')]
        piers=[p for p in self.parts if p.name.startswith('curving pier corpus')]
        crown=next(p for p in self.parts if p.name=='crown central living suspension')
        self.assertEqual(len(frames),4);self.assertGreaterEqual(len(corbels),12);self.assertEqual(len(buttresses),4)
        for p in frames:
            self.assertLess(min(v[2] for v in p.vertices),6.5)
            self.assertGreater(max(v[2] for v in p.vertices),8)
            self.assertTrue(any(self.contact(p,q) for q in piers))
            self.assertTrue(self.contact(p,crown))
        for p in corbels+buttresses:self.assertTrue(any(self.contact(p,q) for q in piers),p.name)
        for z in (2,3.7,5.8,6.6):
            self.assertFalse(art.front_hits(frames+corbels+buttresses,(0,-3,z),''),'framing closes the body view')

    def test_differentiated_body_restraints_have_volume_and_clearance(self):
        shoulders=[p for p in self.parts if p.name.startswith('clavicular wishbone')]
        pelvis=[p for p in self.parts if p.name.startswith('iliac growing wing')]
        crown=[p for p in self.parts if p.name.startswith('cranial pressure restraint')]
        self.assertEqual(len(shoulders),2);self.assertEqual(len(pelvis),2);self.assertEqual(len(crown),2)
        for group,width in [(shoulders,1.3),(pelvis,.9)]:
            xs=[v[0] for p in group for v in p.vertices]
            self.assertGreater(max(xs)-min(xs),width)
        planes=art.shell_planes(next(p for p in self.parts if p.material=='shell'))
        for p in shoulders+pelvis+crown:
            self.assertEqual(p.assembly,'anatomy');self.assertGreater(art.signed_volume(p),0)
            self.assertTrue(all(art.dot(n,v)-d<=-.08+1e-6 for v in p.vertices for n,d in planes),p.name)

    def test_new_forms_are_closed_and_tube_faces_point_outward(self):
        prefixes=('basal ','rooted flying buttress','layered pier corbel','vessel framing ',
                  'clavicular wishbone','scapular growing blade','iliac growing wing','cranial pressure restraint','pelvic forming pressure organ',
                  'grounded foot','base lancet control','curving pier corpus','crown central living suspension')
        for p in self.parts:
            if not p.name.startswith(prefixes):continue
            edges={}
            for face in p.faces:
                for a,b in zip(face,face[1:]+face[:1]):edges.setdefault((min(a,b),max(a,b)),[]).append((a,b))
            for uses in edges.values():
                self.assertEqual(len(uses),2,p.name)
                self.assertEqual(uses[0],tuple(reversed(uses[1])),p.name)
            if 'corbel' in p.name or 'organ' in p.name or 'blade' in p.name or p.name.startswith(('grounded foot','base lancet control')):continue
            sides=6 if 'ivory arris' in p.name else 8
            centers=[tuple(sum(p.vertices[r*sides+j][k] for j in range(sides))/sides for k in range(3)) for r in range(len(p.vertices)//sides)]
            for face in p.faces[:-2]:
                for j in range(1,len(face)-1):
                    ids=(face[0],face[j],face[j+1]);a,b,c=[p.vertices[i] for i in ids]
                    radial=tuple(sum(p.vertices[i][k]-centers[i//sides][k] for i in ids)/3 for k in range(3))
                    self.assertGreater(art.dot(art.cross(art.sub(b,a),art.sub(c,a)),radial),0,p.name)


class Tissue(unittest.TestCase):
    def test_lobes_taper_and_wrap_without_changing_other_parts_or_crossing(self):
        parts=art.build_parts();lobes=[p for p in parts if 'fenestrated lobe' in p.name]
        kept=[(p.name,p.material,p.assembly,p.vertices,p.faces) for p in parts if p not in lobes]
        self.assertEqual(hashlib.sha256(json.dumps(kept,separators=(',',':')).encode()).hexdigest(),
                         '25d246e6a6c6678747948b91e26953e9f405455b37d9932442fc4c9192884a97')
        self.assertEqual(len(lobes),2)
        self.assertEqual(sum(len(list(art.triangles(p))) for p in parts),17574)
        def orient(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
        def crossing(a,b,c,d):
            return orient(a,b,c)*orient(a,b,d)<-1e-12 and orient(c,d,a)*orient(c,d,b)<-1e-12
        self.assertTrue(crossing((0,0),(1,1),(0,1),(1,0)))
        self.assertFalse(crossing((0,0),(1,0),(0,1),(1,1)))
        for p in lobes:
            self.assertEqual(len(p.vertices),48)
            widths=[math.sqrt(sum((p.vertices[i][k]-p.vertices[i+12][k])**2 for k in (0,2))) for i in range(12)]
            self.assertGreater(max(widths)/min(widths),2.8,'uniform-width annular plate remains')
            self.assertGreater(min(widths),.025,'taper collapses a membrane rim')
            middle=[(p.vertices[i][1]+p.vertices[i+24][1])/2 for i in range(24)]
            self.assertGreater(max(middle)-min(middle),.23,'membrane does not wrap into anatomical depth')
            self.assertTrue(Form.closed(p));self.assertGreater(art.signed_volume(p),0)
            # Disjoint angular sectors plus positive projected skin triangles prove a single-valued folded shell.
            outer=[(p.vertices[i][0],p.vertices[i][2]) for i in range(12)]
            inner=[(p.vertices[i+12][0],p.vertices[i+12][2]) for i in range(12)]
            edges=[(loop[i],loop[(i+1)%12]) for loop in (outer,inner) for i in range(12)]
            edges += [(outer[i],inner[i]) for i in range(12)]
            for i,(a,b) in enumerate(edges):
                for c,d in edges[i+1:]:
                    if any(x==y for x in (a,b) for y in (c,d)):continue
                    self.assertFalse(crossing(a,b,c,d),'projected membrane edges cross')

    def test_coherent_fenestrated_web_preserves_originals_and_real_joints(self):
        parts=art.build_parts();web=[p for p in parts if p.name.startswith('pleural web ')]
        self.assertEqual(len(web),4,'coherent tissue topology absent')
        original=[p for p in parts if p not in web]
        fields=[(p.name,p.assembly,p.vertices,p.faces) for p in original]
        self.assertEqual(hashlib.sha256(json.dumps(fields,separators=(',',':')).encode()).hexdigest(),
                         '6683d9ceba51764fb68b427264ec8aeaaf6e9ae0c3edc3dc523e425538ab6a38')
        self.assertEqual(len(original),227)
        full=[(p.name,p.material,p.assembly,p.vertices,p.faces) for p in original]
        self.assertEqual(hashlib.sha256(json.dumps(full,separators=(',',':')).encode()).hexdigest(),
                         '2f8e0e9361eeeedba5668d836ca2e81345b32769efc41f3c3f969a22aa5209cc')
        self.assertTrue(all(p.material=='bone' for p in original if p.name.startswith(('open costal branch','clavicular wishbone','iliac growing wing'))))
        lookup={p.name:p for p in parts};stem=lookup['pleural web axial stem']
        lobes=[lookup['pleural web superior fenestrated lobe'],lookup['pleural web inferior fenestrated lobe']]
        branch=lookup['pleural web costal tension branch']
        for p in lobes:self.assertTrue(Form.contact(p,stem),p.name)
        self.assertTrue(Form.contact(branch,lobes[1]))
        self.assertTrue(Form.contact(branch,lookup['open costal branch 1 6']))
        for name in ['clavicular wishbone -1','pelvic forming pressure organ','forming spinal centrum 8']:
            self.assertTrue(Form.contact(stem,lookup[name]),name)
        self.assertLessEqual(sum(len(list(art.triangles(p))) for p in web),1500)
        planes=art.shell_planes(next(p for p in parts if p.material=='shell'))
        for p in web:
            self.assertEqual((p.material,p.assembly),('tissue','anatomy'))
            self.assertTrue(Form.closed(p));art.validate_part(p);self.assertGreater(art.signed_volume(p),0)
            self.assertTrue(all(art.dot(n,v)-d<=-.08+1e-6 for v in p.vertices for n,d in planes),p.name)
        for p,(x,z) in zip(lobes,[(-.30,4.97),(.22,3.73)]):
            self.assertFalse(art.front_hits([p],(x,-3,z),''),'aperture is filled')
            self.assertTrue(art.front_hits([p],(x,-3,z+.38),''),'real fleshy aperture rim absent')
            vertices=len(p.vertices);edges=len({tuple(sorted((a,b))) for f in p.faces for a,b in zip(f,f[1:]+f[:1])})
            self.assertEqual(vertices-edges+len(p.faces),0,'closed lobe must have a through-hole')
        self.assertFalse(art.front_hits(web,(.65,-3,4.5),''),'web becomes a torso-wide curtain')
        for p in lobes:
            for i in range(24):
                self.assertEqual((p.vertices[i][0],p.vertices[i][2]),(p.vertices[i+24][0],p.vertices[i+24][2]))
                self.assertAlmostEqual(p.vertices[i+24][1]-p.vertices[i][1],.115)
            for i in range(12):
                for offset,sign in [(0,-1),(1,1)]:
                    f=p.faces[4*i+offset]
                    for j in (1,2):
                        a,b,c=[p.vertices[k] for k in (f[0],f[j],f[j+1])]
                        self.assertGreater(sign*art.cross(art.sub(b,a),art.sub(c,a))[1],0,'folded membrane reverses its projected skin')
        for p,sides in [(stem,8),(branch,7)]:
            centers=[tuple(sum(p.vertices[r*sides+j][k] for j in range(sides))/sides for k in range(3)) for r in range(len(p.vertices)//sides)]
            for f in p.faces[:-2]:
                for j in (1,2):
                    ids=(f[0],f[j],f[j+1]);a,b,c=[p.vertices[k] for k in ids]
                    radial=tuple(sum(p.vertices[k][axis]-centers[k//sides][axis] for k in ids)/3 for axis in range(3))
                    self.assertGreater(art.dot(art.cross(art.sub(b,a),art.sub(c,a)),radial),0,p.name)
            spans=[(min(v[2] for v in p.vertices[i*sides:(i+2)*sides]),max(v[2] for v in p.vertices[i*sides:(i+2)*sides])) for i in range(len(centers)-1)]
            self.assertTrue(all(a[1]<b[0] for i,a in enumerate(spans) for b in spans[i+2:]),'nonadjacent tissue tube segments overlap')


class Paths(unittest.TestCase):
    def test_nursery_atlas_input_has_exact_pin_and_honest_source_copy_label(self):
        self.assertEqual(art.MATERIAL_SHA,'4afbb96396d0de2006fc420746d58e1fcf7e47cc39418a3f6a6656ee13fae781')
        self.assertNotEqual(art.MATERIAL_SHA,'eed15e41ba0bf85de489dbe4e25364324e8ead8e33a333182edeca89077b6ac7')
        source=SOURCE.read_text();tree=ast.parse(source)
        copies=[n.value for n in ast.walk(tree) if isinstance(n,ast.Assign) and
                any(isinstance(t,ast.Name) and t.id=='full_path' for t in n.targets)]
        self.assertEqual(len(copies),1)
        self.assertIsInstance(copies[0],ast.BinOp)
        self.assertEqual(copies[0].right.value,'source/art/nursery-material-atlas-v2.png')
        self.assertIn('material_input=pinned(args.material_reference,MATERIAL_SHA)',source)
        self.assertIn("reference_full.name='Pinned full 1254 Nursery material atlas v2'",source)
        with tempfile.TemporaryDirectory(dir='/private/tmp') as t:
            p=Path(t)/'mismatched.png';p.write_bytes(b'unapproved material input')
            with self.assertRaises(ValueError):art.pinned(p,art.MATERIAL_SHA)

    def test_output_fresh_and_alias_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as t:
            root=Path(t); inp=root/'input';inp.mkdir()
            self.assertEqual(art.output_path(root/'fresh',[inp]),root/'fresh')
            for bad in [inp,inp/'child',root/'..'/'escape']:
                with self.subTest(bad=bad),self.assertRaises(ValueError):art.output_path(bad,[inp])
            link=root/'link';link.symlink_to(inp,target_is_directory=True)
            with self.assertRaises(ValueError):art.output_path(link/'fresh',[inp])

    def test_replaceable_outputs_do_not_block_regeneration(self):
        self.assertNotIn('game/assets/art/world/nursery_gestation_engine.glb',art.PINS)
        self.assertNotIn('source/art/manifest.json',art.PINS)

    def test_pin_and_png_contract(self):
        with tempfile.TemporaryDirectory(dir='/private/tmp') as t:
            p=Path(t)/'a.png';p.write_bytes(b'wrong')
            with self.assertRaises(ValueError):art.pinned(p,'0'*64)
            self.assertEqual(art.pinned(p,hashlib.sha256(b'wrong').hexdigest()),p)
            with self.assertRaises(ValueError):art.png_size(p.read_bytes())

    def test_hardlink_input_alias_rejected(self):
        import os
        with tempfile.TemporaryDirectory(dir='/private/tmp') as t:
            p=Path(t)/'source';p.write_bytes(b'original');q=Path(t)/'alias';os.link(p,q)
            with self.assertRaises(ValueError):art.pinned(q,hashlib.sha256(b'original').hexdigest())


class GLB(unittest.TestCase):
    def test_typed_alpha_valid_and_normalizer_preserves_bin(self):
        d,b=fixture();blob=art.pack_glb(d,b)
        self.assertEqual(art.inspect_glb(blob)['groups'],5)
        normalized=art.nearest_glb(blob)
        self.assertEqual(art.unpack_glb(normalized)[1],art.unpack_glb(blob)[1])
        self.assertEqual(art.inspect_glb(normalized)['triangles'],5)

    def test_malformed_boundary_cases(self):
        mutations={
          'opaque_shell':lambda d:d['materials'][4].update(alphaMode='OPAQUE'),
          'glowing_alpha_body':lambda d:d['materials'][0].update(alphaMode='BLEND'),
          'duplicate_layer':lambda d:d['materials'][4].update(doubleSided=True),
          'wrong_alpha':lambda d:d['materials'][4]['pbrMetallicRoughness'].update(baseColorFactor=[.55,.74,.77,1]),
          'transmission':lambda d:d.update(extensionsUsed=['KHR_materials_transmission']),
          'unknown_extension':lambda d:d['materials'][0].update(extensions={'custom':{}}),
          'external_buffer':lambda d:d['buffers'][0].update(uri='file.bin'),
          'external_image':lambda d:d['images'][0].update(uri='image.png'),
          'extra_texture':lambda d:d['textures'].append({'source':0,'sampler':0}),
          'shell_texture':lambda d:d['materials'][4]['pbrMetallicRoughness'].update(baseColorTexture={'index':0}),
          'mips':lambda d:d['samplers'][0].update(minFilter=9987),
          'span':lambda d:d['bufferViews'][0].update(byteLength=1),
          'count':lambda d:d['accessors'][0].update(count=True),
          'bounds_lie':lambda d:d['accessors'][0].update(max=[20,20,20]),
          'wrong_component':lambda d:d['accessors'][0].update(componentType=5123),
          'camera':lambda d:d['nodes'][0].update(camera=0),
          'group_alias':lambda d:d['meshes'][4]['primitives'][0].update(material=0),
          'inactive_scene':lambda d:d['scenes'][0].update(nodes=[0]),
          'bool_buffer':lambda d:d['bufferViews'][0].update(buffer=False),
          'bool_source':lambda d:d['textures'][0].update(source=False),
          'bool_double_sided':lambda d:d['materials'][4].update(doubleSided=0),
          'extra_map':lambda d:d['materials'][0].update(normalTexture={'index':0}),
        }
        for name,mutate in mutations.items():
            d,b=fixture();mutate(d)
            with self.subTest(name=name),self.assertRaises(ValueError):art.inspect_glb(art.pack_glb(d,b))

    def test_strict_indices_enums_and_emission(self):
        mutations={
          'bool_scene':lambda d:d.update(scene=False),
          'float_scene':lambda d:d.update(scene=0.0),
          'bool_root':lambda d:d['scenes'][0]['nodes'].__setitem__(0,False),
          'float_root':lambda d:d['scenes'][0]['nodes'].__setitem__(0,0.0),
          'float_component':lambda d:d['accessors'][0].update(componentType=5126.0),
          'bool_texture':lambda d:d['materials'][0]['pbrMetallicRoughness']['baseColorTexture'].update(index=False),
          'float_texture':lambda d:d['materials'][0]['pbrMetallicRoughness']['baseColorTexture'].update(index=0.0),
          'float_sampler':lambda d:d['samplers'][0].update(magFilter=9728.0),
          'wrong_emission':lambda d:d['materials'][0].update(emissiveFactor=[1,0,0]),
          'missing_amber_emission':lambda d:d['materials'][3].update(emissiveFactor=[0,0,0]),
          'bool_emission':lambda d:d['materials'][0].update(emissiveFactor=[False,0,0]),
          'short_emission':lambda d:d['materials'][0].update(emissiveFactor=[0]),
          'nan_emission':lambda d:d['materials'][0].update(emissiveFactor=[float('nan'),0,0]),
        }
        for name,mutate in mutations.items():
            for route in (art.inspect_glb,art.nearest_glb):
                d,b=fixture();mutate(d)
                with self.subTest(name=name,route=route.__name__),self.assertRaises(ValueError):
                    route(art.pack_glb(d,b))

    def test_binary_nan_bad_normal_index_and_png(self):
        for case in ['nan','normal','inverted_normal','index','png']:
            d,b=fixture();data=bytearray(b)
            p=d['meshes'][0]['primitives'][0]
            index={'nan':p['attributes']['POSITION'],'normal':p['attributes']['NORMAL'],'inverted_normal':p['attributes']['NORMAL'],'index':p['indices']}.get(case)
            offset=d['bufferViews'][d['accessors'][index]['bufferView']]['byteOffset'] if index is not None else d['bufferViews'][d['images'][0]['bufferView']]['byteOffset']
            if case=='normal':
                data[36:48]=bytes(12)
            elif case=='nan':struct.pack_into('<f',data,offset,float('nan'))
            elif case=='inverted_normal':
                for i in range(3):struct.pack_into('<3f',data,offset+i*12,0,0,-1)
            elif case=='index':struct.pack_into('<H',data,offset,8)
            else:struct.pack_into('<I',data,offset,0)
            with self.subTest(case=case),self.assertRaises(ValueError):art.inspect_glb(art.pack_glb(d,bytes(data)))

    def test_normalizer_does_not_launder_unknown_extensions_or_bool_aliases(self):
        for case in ['sampler_extension','texture_extension','bool_source','bool_index','bad_span']:
            d,b=fixture()
            if case=='sampler_extension':d['samplers'][0]['extensions']={'custom':{}}
            elif case=='texture_extension':d['textures'][0]['extensions']={'custom':{}}
            elif case=='bool_source':d['textures'][0]['source']=False
            elif case=='bool_index':d['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']=False
            else:d['bufferViews'][0]['byteLength']=1
            with self.subTest(case=case),self.assertRaises(ValueError):art.nearest_glb(art.pack_glb(d,b))

    def test_duplicate_identical_atlas_binding_coalesces_only_descriptors(self):
        d,b=fixture();d['textures'].append(copy.deepcopy(d['textures'][0]))
        d['materials'][1]['pbrMetallicRoughness']['baseColorTexture']['index']=1
        raw=art.pack_glb(d,b);out=art.nearest_glb(raw)
        self.assertEqual(art.unpack_glb(raw)[1],art.unpack_glb(out)[1])
        self.assertEqual(art.inspect_glb(out)['groups'],5)

    def test_normalizer_rejects_nonstandard_sampler_enums(self):
        for field in ['minFilter','magFilter','wrapS','wrapT']:
            d,b=fixture();d['samplers'][0][field]=123
            with self.subTest(field=field),self.assertRaises(ValueError):art.nearest_glb(art.pack_glb(d,b))

    def test_glb_header_and_chunk_integrity(self):
        d,b=fixture();blob=art.pack_glb(d,b)
        for malformed in [b'wrong',blob[:-1],blob+b'junk']:
            with self.assertRaises(ValueError):art.inspect_glb(malformed)


class Source(unittest.TestCase):
    def test_python311_native_editable_and_no_destruction(self):
        source=SOURCE.read_text();tree=ast.parse(source,feature_version=(3,11))
        calls=[n for n in ast.walk(tree) if isinstance(n,ast.Call)]
        saves=[n for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr=='save_as_mainfile']
        self.assertTrue(saves)
        self.assertTrue(all(any(k.arg=='compress' and isinstance(k.value,ast.Constant) and k.value.value is False for k in n.keywords) for n in saves))
        for n in calls:
            if isinstance(n.func,ast.Attribute):self.assertNotIn(n.func.attr,['delete','remove','unlink','rmtree','read_factory_settings'])
        self.assertNotIn('import build_skin_bell',source)
        self.assertIn('use_active_scene=True',source)
        self.assertIn('reference_full.pack()',source)
        main=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='main')
        self.assertTrue(any(isinstance(n,ast.Import) and any(a.name=='bpy' for a in n.names) for n in ast.walk(main)))
        self.assertFalse(any(isinstance(n,(ast.Import,ast.ImportFrom)) and any(a.name=='bpy' for a in n.names) for n in tree.body))
        self.assertLess(source.index('atlas.alpha_mode='),source.index('atlas.scale('))
        self.assertLess(source.index('save_as_mainfile('),source.index('clone=ob.copy()'))


if __name__=='__main__':unittest.main()
