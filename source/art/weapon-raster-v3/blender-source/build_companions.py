"""SOURCE ONLY: editable geometry companions to independently generated raster art.
Never renders, bakes, simulates, or writes runtime art. No plane/image geometry.
Run Blender background --threads 1 --python-exit-code 1 --python this_file.
Original model hands are retained; new weapon bodies authored from the six PNG refs.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
import importlib.util
ROOT=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location("original_art_helpers",ROOT/"tools/build_art.py");art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
OUT=Path(__file__).resolve().parent
ART=OUT.parent.parent
IDS=['impact_tool','rivet_pistol','scattergun','sawtooth_repeater','marrow_launcher','choir_disruptor']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
M={};C=None

def material(name,color,metal=0,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.48
 if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=34
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.008;m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
 return m

def mesh(name,v,f,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update();o=bpy.data.objects.new(name,d);C.objects.link(o);o.data.materials.append(M[mat]);return o

def box(name,p,s,mat='iron',bevel=.025):
 v=[(p[0]+x*s[0]/2,p[1]+y*s[1]/2,p[2]+z*s[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 o=mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
 if bevel:b=o.modifiers.new('Editable machined edge bevel','BEVEL');b.width=bevel;b.segments=2
 return o

def tube(name,pts,r=.04,mat='brass',n=12):
 v=[]
 for j,p in enumerate(pts):
  axis=Vector(pts[min(j+1,len(pts)-1)])-Vector(pts[max(j-1,0)]);axis.normalize();u=axis.cross(Vector((0,0,1)))
  if u.length<.01:u=axis.cross(Vector((0,1,0)))
  u.normalize();q=axis.cross(u);radius=r[j] if isinstance(r,(list,tuple)) else r
  for i in range(n):v.append(tuple(Vector(p)+radius*(u*math.cos(i*math.tau/n)+q*math.sin(i*math.tau/n))))
 f=[tuple(reversed(range(n))),tuple(range((len(pts)-1)*n,len(pts)*n))]
 for j in range(len(pts)-1):
  for i in range(n):a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n))
 return mesh(name,v,f,mat)

def collar(name,p,r=.14,width=.04,mat='brass'):
 # Real open annular cylinder along Y, not a capped solid pretending to be a bore.
 v=[];n=24
 for y,rad in [(p[1]-width/2,r),(p[1]+width/2,r),(p[1]-width/2,r*.75),(p[1]+width/2,r*.75)]:
  v.extend([(p[0]+rad*math.cos(i*math.tau/n),y,p[2]+rad*math.sin(i*math.tau/n)) for i in range(n)])
 f=[]
 for a,b in [(0,1),(2,0),(1,3),(3,2)]:
  for i in range(n):k=(i+1)%n;f.append((a*n+i,a*n+k,b*n+k,b*n+i))
 return mesh(name,v,f,mat)

def orb(name,p,s,mat='ivory'):
 v=[];n=16;rows=9
 for j in range(rows):
  a=math.pi*j/(rows-1)
  for i in range(n):b=math.tau*i/n;v.append((p[0]+s[0]*math.sin(a)*math.cos(b),p[1]+s[1]*math.sin(a)*math.sin(b),p[2]+s[2]*math.cos(a)))
 return mesh(name,v,[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(rows-1) for i in range(n)],mat)

def strap(name,x,y,z,wide=.5):
 return tube(name,[(x-wide/2,y,z-.12),(x-wide/2,y,z+.13),(x-wide*.32,y,z+.23),(x+wide*.32,y,z+.23),(x+wide/2,y,z+.13),(x+wide/2,y,z-.12)],.055,'ivory',10)

def screws(x,y,z):
 for side in [-1,1]:tube('Independent brass fastening screw',[(x+side*.22,y,z),(x+side*.22,y,z+.035)],.025,'brass',8)

def body(kind,pose):
 t={'idle':0,'fire':1,'recover':.35}[pose]
 if kind=='impact_tool':
  tube('Ram handle core',[(0,-.9,.32),(0,.45-.18*t,.44)],.13,'brass')
  for y in [-.65,-.4,-.15]:collar('Sliding ram neck collar',(0,y,.38),.18,.09)
  box('Rectangular strike anvil',(0,.7-.18*t,.55),(.56,.47,.48),'iron')
  for s in [-1,1]:
   tube('Curved ivory side jaw',[(s*.24,.37-.18*t,.46),(s*.43,.49-.18*t,.51),(s*.42,.91-.18*t,.66),(s*.30,1.01-.18*t,.69)],.12,'ivory')
   box('Side jaw dark inset',(s*.42,.62-.18*t,.43),(.12,.27,.22),'iron')
   tube('Warm pressure slit',[(s*.28,.34-.18*t,.43),(s*.28,.34-.18*t,.64)],.023,'amber')
   tube('Flexible pressure return hose',[(s*.16,-.58,.22),(s*.24,-.12,.27),(s*.23,.19,.39)],.038,'hose')
  screws(0,.78-.18*t,.80)
 elif kind=='rivet_pistol':
  box('Continuous receiver grip socket',(.14,-.41,.48),(.43,.38,.32),'iron')
  grip=box('Real downward angled pistol grip',(.18,-.65,.25),(.25,.38,.47),'black');grip.rotation_euler.x=-.16
  box('Ivory backstrap into receiver',(.18,-.79,.38),(.26,.09,.30),'ivory')
  tube('Long faceted rivet barrel',[(.14,-.20,.58),(.14,1.18,.58)],.115,'iron')
  for y in [.05,.53,1.13]:collar('Barrel bronze heat collar',(.14,y,.58),.14,.065)
  for y in [-.26,-.08]:strap('Twin ivory receiver strap',.14,y,.57,.48)
  tube('Exposed telescoping bolt',[(.14,-.78-.13*t,.55),(.14,-.3,.55)],.10,'brass')
  collar('Open rear cap',(.14,-.80-.13*t,.55),.15,.07)
  for s in [-1,1]:
   for z in [.45,.66]:tube('Open bolt cage rail',[(.14+s*.14,-.8,.0+z),(.14+s*.14,-.25,z)],.022,'brass')
  tube('Amber bolt chamber',[(.14,-.61,.55),(.14,-.43+.05*t,.55)],.065,'amber')
  tube('Trigger return guard',[(.30,-.65,.40),(.42,-.47,.35),(.36,-.26,.43)],.027,'brass')
 elif kind=='scattergun':
  box('Double receiver lower bridge',(0,-.42,.36),(.70,.55,.45),'iron')
  box('Continuous scatter rear handgrip',(0,-.75,.22),(.39,.38,.36),'black')
  box('Bronze scatter grip junction',(0,-.60,.35),(.44,.16,.23),'brass')
  for s in [-1,1]:
   x=s*.19
   tube('Independent long scatter barrel',[(x,-.08+.14*t,.55),(x,1.22+.14*t,.55)],.145,'iron')
   for y in [0,.36,1.18]:collar('Twin barrel open bronze collar',(x,y+.14*t,.55),.17,.06)
   tube('Exposed translating breech piston',[(x,-.35,.55),(x,.14+.14*t,.55)],.085,'brass')
   tube('Ivory receiver cheek',[(s*.29,-.65,.38),(s*.40,-.36,.47),(s*.35,-.13,.65)],.065,'ivory')
   tube('Red hydraulic hose',[(s*.32,-.75,.32),(s*.44,-.10,.42),(s*.32,.65,.48)],.035,'hose')
  box('Central barrel clasp',(0,.28,.68),(.12,.3,.09),'brass');box('Inset amber pressure gauge',(0,-.48,.61),(.17,.12,.05),'amber');screws(0,.28,.73)
 elif kind=='sawtooth_repeater':
  box('Asymmetric narrow receiver',(0,-.05,.43),(.48,1.12,.39),'iron')
  box('Continuous saw grip and receiver heel',(0,-.69,.24),(.35,.40,.40),'black')
  box('Saw grip backstrap',(0,-.84,.34),(.36,.08,.25),'brass')
  # Separate side strips and crossbars leave actual open slots in the ivory spine.
  for s in [-1,1]:box('Slotted top longitudinal ivory rail',(s*.12,.30,.70),(.07,.94,.06),'ivory')
  for y in [-.12,.14,.40,.66]:box('Ivory spine open-slot crossbar',(0,y,.70),(.22,.08,.06),'ivory')
  for i in range(7):
   y=-.46+i*.14;tube('Right-side exposed pointed cartridge',[(.29,y,.49),(.62,y,.49),(.73,y,.49)],[.055,.055,.006],'brass')
  for s in [-1,1]:box('Exposed action guide rail',(s*.16,-.3,.65),(.035,.52,.04),'brass')
  tube('Visible moving bolt cylinder',[(0,-.50+.18*t,.58),(0,-.25+.18*t,.58)],.10,'brass')
  box('Lower bolt carrier',(0,-.60+.18*t,.54),(.25,.20,.19),'iron')
  for i in range(4):box('Amber side status segment',(-.28,-.25+i*.07,.60),(.04,.04,.05),'amber')
  tube('Repeater long bore',[(0,.6,.50),(0,1.08,.50)],.09,'iron');collar('Repeater forward emission lip',(0,1.08,.50),.12)
 elif kind=='marrow_launcher':
  box('Heavy recoil sled',(0,-.56,.30),(.72,.64,.38),'iron')
  for y in [-.65,-.36]:collar('Rear recoil brass ring',(0,y,.31),.27,.065)
  collar('Actual hollow launch chamber',(0,.12,.50),.30,.35,'brass')
  for s in [-1,1]:
   # Editable curved shell sectors: volume, thickness and hinge, not picture surfaces.
   v=[];n=12;rows=5;spread=.22*t
   for layer in [0,1]:
    for j in range(rows):
     y=.22+j*.19
     for i in range(n):
      a=(-1.35+2.70*i/(n-1))+(0 if s==1 else math.pi);r=.47-.018*j-.055*layer
      v.append((r*math.cos(a)+s*spread,y,.52+r*math.sin(a)))
   f=[];nn=n*rows
   for layer in [0,1]:
    for j in range(rows-1):
     for i in range(n-1):a=layer*nn+j*n+i;f.append((a,a+1,a+n+1,a+n))
   for j in range(rows-1):
    for i in [0,n-1]:a=j*n+i;f.append((a,a+n,a+n+nn,a+nn))
   for j in [0,rows-1]:
    for i in range(n-1):a=j*n+i;f.append((a,a+nn,a+nn+1,a+1))
   petal=mesh('Articulated thick curved ivory cup petal',v,f,'ivory')
   hinge=Vector((s*.34,.22,.52))
   petal.matrix_world=Matrix.Translation(hinge) @ Matrix.Rotation(-s*.36*t,4,'Z') @ Matrix.Translation(-hinge)
   tube('Actual petal hinge pivot',[(s*.34,.18,.48),(s*.34,.29,.48)],.08,'brass')
   tube('Petal hinge actuator',[(s*.30,-.02,.42),(s*(.40+spread),.68,.50)],.045,'brass')
   tube('Marrow return hose',[(s*.39,-.7,.25),(s*.52,-.15,.35),(s*.42,.37,.48)],.04,'hose')
  if pose=='idle':orb('Loaded ivory marrow sphere',(0,.45,.55),(.23,.23,.23))
  tube('Central chamber ejection rod',[(0,.10,.54),(0,.75,.54)],.055,'brass');orb('Amber throat lumen',(0,.12,.54),(.09,.06,.09),'amber')
 elif kind=='choir_disruptor':
  box('Resonator receiver',(0,-.51,.28),(.64,.59,.38),'iron')
  for x in [-.23,0,.23]:
   yy=.10 if x else .30
   for j in range(6):
    y=yy+j*.13;orb('Separate ivory resonator vertebra',(x,y,.49),(.12,.10,.10),'ivory')
   tube('Resonator dark structural spine',[(x,yy-.04,.49),(x,yy+.70,.49)],.055,'black')
  for s in [-1,1]:
   tube('Curved bronze tuning horn',[(s*.38,.10,.48),(s*.50,.49,.66),(s*.49,.82,.83),(s*.36,1.04,.91)],[.09,.085,.055,.005],'brass')
   tube('Diagonal resonator brace',[(s*.18,-.2,.38),(s*.45,.47,.55)],.035,'brass')
   orb('Amber side tuning eye',(s*.43,.44,.58),(.06,.04,.06),'amber')
   tube('Red resonance return cable',[(s*.3,-.8,.23),(s*.55,-.12,.30),(s*.40,.39,.48)],.035,'hose')
  orb('Violet core exposed by compression',(0,-.02+.12*t,.55),(.12+.04*t,.14,.12+.04*t),'violet')
  for j in range(3):collar('Core compressing brass ring',(0,-.04+j*.09+.07*t,.55),.15,.035)
  box('Rear tuning thumb lever',(0,-.48,.54),(.20,.15,.09),'brass')

results=[]
for kind in IDS:
 original=ART/(kind+'.blend');hand_template=ART/'impact_tool.blend';bpy.ops.wm.open_mainfile(filepath=str(hand_template));scene=bpy.context.scene
 # Retain real editable glove/forearm/finger meshes from the original, not old weapon silhouettes.
 keys=('glove','finger','thumb','technician sleeve','cuff')
 keep=[o for o in scene.objects if o.type=='MESH' and any(k in o.name.lower() for k in keys)]
 retained=[o.name for o in keep]
 for o in list(bpy.data.objects):
  if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
 M={key:material(*args) for key,args in {'iron':('V3 worn petrol steel',(.045,.074,.084),.72,0),'brass':('V3 antique bronze',(.36,.19,.065),.8,0),'ivory':('V3 warm ivory ceramic',(.69,.57,.38),.08,0),'black':('V3 charcoal glove',(.025,.029,.032),0,0),'hose':('V3 oxblood hydraulic hose',(.20,.025,.018),.05,0),'amber':('V3 restrained amber chamber',(.9,.27,.012),.15,1),'violet':('V3 violet resonator',(.35,.035,.68),.1,1)}.items()}
 bpy.context.view_layer.update()
 for o in keep:
  o.data=o.data.copy();o.data.materials.clear();o.data.materials.append(M['brass' if 'clamp' in o.name.lower() else 'ivory' if 'cuff suture' in o.name.lower() else 'black'])
  side=-1 if o.name.startswith('-1 ') else 1
  pose=next((c.name for c in o.users_collection if c.name in ['idle','fire','recover']),'idle')
  recoil={'idle':0,'fire':.06,'recover':-.03}[pose]
  target=Vector((side*.15,-.72,.27))
  if kind=='impact_tool':target=Vector((side*.11,-.62 if side<0 else -.83,.34 if side<0 else .30))
  elif kind=='rivet_pistol':target=Vector((.21 if side>0 else -.06,-.75 if side>0 else -.48,.23 if side>0 else .35))
  elif kind=='sawtooth_repeater':target=Vector((side*.13,-.74,.24))
  elif kind=='scattergun':target=Vector((side*.19,-.72,.28))
  target.z+=recoil*.35
  assert o.parent is None, "Original hand transform assumes unparented mesh"
  registered=Matrix.Translation(target) @ Matrix.Rotation(side*.60,4,'Z') @ Matrix.Diagonal((.82,.92,.92,1)) @ Matrix.Translation(Vector((-side*.5,.88,-.28-recoil))) @ o.matrix_basis.copy()
  for vertex in o.data.vertices:vertex.co=registered @ vertex.co
  o.matrix_world=Matrix.Identity(4)
  o['source_hand_template']='source/art/impact_tool.blend'
  o['grip_contact']='New palm-to-grip placement, inward-curled existing editable fingers; no thin link placeholder'
 # Remove all obsolete image materials/resources from original scene, not just used ones.
 for m in list(bpy.data.materials):
  if m not in M.values() and m.users==0:bpy.data.materials.remove(m)
 for im in list(bpy.data.images):bpy.data.images.remove(im)
 for meshdata in list(bpy.data.meshes):
  if meshdata.users==0:bpy.data.meshes.remove(meshdata)
 # Existing source pose collections are retained for lineage; collect new source per named pose.
 groups=[]
 for pose in ['idle','fire','recover']:
  C=bpy.data.collections.new('V3_'+pose);scene.collection.children.link(C);groups.append(C);body(kind,pose)
  for side in [-1,1]:
   target=Vector((side*.15,-.72,.27))
   if kind=='impact_tool':target=Vector((side*.11,-.62 if side<0 else -.83,.34 if side<0 else .30))
   elif kind=='rivet_pistol':target=Vector((.21 if side>0 else -.06,-.75 if side>0 else -.48,.23 if side>0 else .35))
   elif kind=='sawtooth_repeater':target=Vector((side*.13,-.74,.24))
   elif kind=='scattergun':target=Vector((side*.19,-.72,.28))
   rot=Matrix.Rotation(side*.60,3,'Z')
   wrist=target+rot@Vector((0,-.36,-.015));end=target+rot@Vector((0,-1.02,-.05))
   tube('Continuous broad technician forearm sleeve',[tuple(wrist),tuple(end)],[.17,.24],'black',16)
   for i in range(3):
    center=wrist.lerp(end,(i+1)/5)
    cuff=tube('Raised ivory cloth wrist wrap',[tuple(center),tuple(center+rot@Vector((0,-.065,0)))],[.18,.185],'ivory',16)
  C['pose']=pose;C['authorship']='New editable geometry derived from actual production-source-v1.png; not raster generator'
 for col in list(bpy.data.collections):
  if col.name not in ['V3_idle','V3_fire','V3_recover']:
   # Keep hands associated with same original pose; no runtime image textures.
   col.hide_render='idle' not in col.name.lower();col.hide_viewport=col.hide_render
 for col in groups:col.hide_render=col.name!='V3_idle';col.hide_viewport=col.hide_render
 data=bpy.data.cameras.new('Source inspection camera');cam=bpy.data.objects.new('Source inspection camera',data);scene.collection.objects.link(cam);cam.location=(2.0,-3.6,2.5) if kind=='rivet_pistol' else (0,-3.4,2.7);direction=Vector((0,.20,.40))-cam.location;cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=2.65;scene.camera=cam
 scene.render.resolution_x=640;scene.render.resolution_y=400;scene['provenance']='Editable SOURCE COMPANION. Runtime PNGs were independently generated by builtin image_gen and extracted with Godot, NOT rendered from this blend.';scene['qualification']='Structural editability verified; visual equivalence not yet independently reviewed.'
 scene['reference_sha256']=sha(OUT.parent/kind/'production-source-v1.png');scene['original_blend_sha256']=sha(original)
 # Fixed RNA buffer sanitization is the approved repository helper, not plain string assignment.
 art.sanitize_source_paths(bpy)
 for datablocks in [bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.collections,bpy.data.scenes,bpy.data.worlds,bpy.data.cameras]:
  for block in datablocks:
   for key in list(block.keys()):
    value=block[key]
    if isinstance(value,str) and any(part in value for part in ['/Users/','/private/','/tmp/']):del block[key]
 bpy.context.preferences.filepaths.save_version=0
 path=OUT/(kind+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
 results.append({'weapon':kind,'source':path.name,'sha256':sha(path),'original':original.name,'original_sha256':sha(original),'reference_sha256':scene['reference_sha256'],'retained_original_hand_meshes':len(keep),'hand_template':'source/art/impact_tool.blend','hand_template_sha256':sha(hand_template),'new_pose_mesh_counts':{c.name:len(c.objects) for c in groups},'rendered':False})
# Actual reopen validation: 3 nonempty named pose collections, volumetric mesh data, no image planes/textures.
for row in results:
 bpy.ops.wm.open_mainfile(filepath=str(OUT/row['source']));counts={}
 for pose in ['idle','fire','recover']:
  c=bpy.data.collections['V3_'+pose];assert len(c.objects)>10;counts[pose]={'objects':len(c.objects),'vertices':sum(len(o.data.vertices) for o in c.objects if o.type=='MESH')}
  assert counts[pose]['vertices']>500
 used={m for o in bpy.context.scene.objects if o.type=='MESH' for m in o.data.materials if m}
 assert not any(n.type=='TEX_IMAGE' for m in used if m.use_nodes for n in m.node_tree.nodes)
 assert bpy.context.scene['qualification'].startswith('Structural')
 # Actual reopened RNA/path/property validation, not raw compressed-byte regex.
 paths=[]
 for im in bpy.data.images:
  paths.append(im.filepath)
  for packed in im.packed_files:paths.append(packed.filepath)
 for scene in bpy.data.scenes:paths.append(scene.render.filepath)
 for screen in bpy.data.screens:
  for area in screen.areas:
   for space in area.spaces:
    if space.type=='FILE_BROWSER' and space.params:paths.append(bytes(space.params.directory).decode('utf-8',errors='replace'))
 properties=[]
 for blocks in [bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.collections,bpy.data.scenes,bpy.data.worlds,bpy.data.cameras]:
  for block in blocks:
   for key in block.keys():
    if isinstance(block[key],str):properties.append(block[key])
 assert not any(any(mark in value for mark in ['/Users/','/private/','/tmp/']) for value in paths+properties)
 assert len(bpy.data.images)==0
 for col_name in ['idle','fire','recover']:
  for hand in bpy.data.collections[col_name].all_objects:
   if hand.type=='MESH':
    vertices=[hand.matrix_world@v.co for v in hand.data.vertices]
    assert max(max(v[i] for v in vertices)-min(v[i] for v in vertices) for i in range(3))<.85, 'Retained hand component implausibly enlarged'
 row['reopen_validation']=counts;row['no_image_textures']=True;row['reopened_path_privacy']={'checked_actual_rna_fields':len(paths),'custom_string_properties':len(properties),'images':len(bpy.data.images),'private_absolute_paths':0,'render_paths':paths,'helper':'tools/build_art.py:sanitize_source_paths','helper_sha256':sha(ROOT/'tools/build_art.py')}
(OUT/'source-validation.json').write_text(json.dumps({'schema':1,'scope':'CPU-only source authoring and actual Blender reopen, NOT render/appearance acceptance; raster ancestry unchanged','assets':results},indent=2))
print('PASS six substantive editable source companions reopened; appearance UNQUALIFIED',flush=True)
