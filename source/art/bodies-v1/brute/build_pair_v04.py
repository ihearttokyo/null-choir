"""Original editable Crawler/Brute source and guarded128px directional exporter.

GEOMETRY REVISION02 / adapter v04; internal file-load embedding. No new Blender run authorized by this file. Default mode saves source
and renders zero cells; selected proof max4; atlas40cells requires separate grant.
"""
import argparse,hashlib,json,math,pathlib,struct,sys,time,zlib
sys.dont_write_bytecode=True
OWNED=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(OWNED))
from actor_geometry_v02 import build,POSES,SPEC,PALETTE
REFERENCE_SHA='c2a9b71f2b6c005be50e1797e428138e2872e2708c886b79aca96148ccd5e6ca'
CELL=128
ANCHOR=(64,120)
BOTTOM=119

class Progress:
 def __init__(self,output,role):self.output,self.role=output,role;self.started=time.perf_counter();self.rows=[]
 def mark(self,phase,**details):
  row={'phase':phase,'script_elapsed_seconds':round(time.perf_counter()-self.started,6),'role':self.role,**details};self.rows.append(row)
  print('ACTOR_PHASE '+json.dumps(row,separators=(',',':')),flush=True)
  (self.output/'phase-progress.json').write_text(json.dumps({'status':'COMPLETE_NOT_ART_ACCEPTED' if phase=='complete' else 'IN_PROGRESS_NOT_ACCEPTED','last_phase':phase,'phases':self.rows},indent=2)+'\n')

def sha(path):
 with pathlib.Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def cells_arg(value):
 result=[]
 for entry in value.split(','):
  p=entry.split(':')
  if len(p)!=2 or p[0] not in POSES or p[1] not in tuple(str(i) for i in range(8)):raise argparse.ArgumentTypeError('Expected pose:direction with original5poses/direction0–7')
  cell=(p[0],int(p[1]))
  if cell in result:raise argparse.ArgumentTypeError('Duplicate selected cell')
  result.append(cell)
 if not 1<=len(result)<=4:raise argparse.ArgumentTypeError('Selected proof is1–4cells only')
 return result

def arguments(argv):
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--role',required=True,choices=tuple(SPEC));p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--reference',required=True,type=pathlib.Path)
 p.add_argument('--mode',choices=('source','proof','selected','atlas'),default='source');p.add_argument('--cells',type=cells_arg)
 p.add_argument('--approved-directional-matrix',action='store_true');p.add_argument('--export-idle-glb',action='store_true')
 a=p.parse_args(argv);a.output=a.output.resolve()
 assert a.output.is_relative_to(OWNED) and a.output!=OWNED,'Only fresh owned output subfolder allowed'
 assert not a.output.exists(),'Never overwrite source/proof/history'
 if a.mode=='selected':assert a.cells,'Selected requires explicit cells'
 else:assert a.cells is None,'--cells only applies to selected mode'
 if a.mode=='atlas':assert a.approved_directional_matrix,'40cellmatrix needs separate parent grant'
 assert sha(a.reference)==REFERENCE_SHA,'Selected actual reference identity changed'
 return a

def requested(a):
 if a.mode=='proof':return [('idle',0)]
 if a.mode=='selected':return a.cells
 if a.mode=='atlas':return [(p,d) for p in POSES for d in range(8)]
 return []

def png(path,width,height,pixels):
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 raw=b''.join(b'\0'+bytes(pixels[y*width*4:(y+1)*width*4]) for y in range(height))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

def portable_text(role,rigs):
 document={'schema':'original-actor-rig-1','role':role,'palette':PALETTE,'poses':{p:r.data() for p,r in rigs.items()}}
 return json.dumps(document,separators=(',',':'))+'\n'

def embed_portable(bpy,path,expected_text,progress):
 # RNA BlendDataTexts.load defines internal=True; no Text.internal property
 # exists. Record requested internal plus actual RNA state independently.
 expected=expected_text.encode('utf-8');assert path.read_bytes()==expected,'Portable disk bytes changed'
 progress.mark('portable_fileload_begin',bytes=len(expected),internal_requested=True)
 text=bpy.data.texts.load(str(path),internal=True)
 progress.mark('portable_fileload_done',name=text.name,is_in_memory=bool(text.is_in_memory),filepath=text.filepath,internal_requested=True)
 progress.mark('portable_source_validation_begin')
 actual=text.as_string().encode('utf-8')
 state={'name':text.name,'internal_requested':True,'is_in_memory':bool(text.is_in_memory),'filepath':text.filepath,'library_is_none':text.library is None,'use_fake_user':bool(text.use_fake_user),'source_bytes':len(expected),'embedded_utf8_bytes':len(actual),'source_sha256':hashlib.sha256(expected).hexdigest(),'embedded_sha256':hashlib.sha256(actual).hexdigest(),'exact_as_string_bytes_equal':actual==expected,'decoded_document_equal':json.loads(actual)==json.loads(expected)}
 assert state['is_in_memory'] and state['filepath']=='', 'Loaded Text is not internal/no-path'
 assert state['library_is_none'] and state['use_fake_user'],'Embedded source must be local and retained'
 assert state['exact_as_string_bytes_equal'] and state['decoded_document_equal'],'Embedded portable source changed'
 progress.mark('portable_source_validation_done',**state)
 return state

class Exporter:
 def __init__(self,bpy,Matrix,Vector,role,progress):self.bpy,self.Matrix,self.Vector,self.role,self.progress=bpy,Matrix,Vector,role,progress;self.poses={};self.objects=[]
 def setup(self):
  b=self.bpy;b.ops.wm.read_factory_settings(use_empty=True);b.context.preferences.filepaths.save_version=0;s=b.context.scene
  s.render.engine='BLENDER_WORKBENCH';s.render.threads_mode='FIXED';s.render.threads=2
  s.render.film_transparent=True;s.render.resolution_x=s.render.resolution_y=128;s.render.resolution_percentage=100
  s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.display.render_aa='OFF'
  sh=s.display.shading;sh.light='STUDIO';sh.studio_light='paint.sl';sh.color_type='MATERIAL';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH'
  sh.curvature_ridge_factor=1.;sh.curvature_valley_factor=.65;sh.cavity_ridge_factor=1.;sh.cavity_valley_factor=.65;sh.show_specular_highlight=True
  s.view_settings.view_transform='Standard';s.view_settings.look='None';s.world=b.data.worlds.new('Transparent source studio');s.world.color=(.15,.15,.15)
  self.scene=s;self.materials={}
  self.progress.mark('materials_begin')
  legacy_node_enable_count=0
  for name,color in PALETTE.items():
   m=b.data.materials.new(name);m.diffuse_color=color
   # Preserve full shader materials. Avoid an unnecessary deprecated setter
   # when the current Blender Material already owns its default node tree.
   if m.node_tree is None:m.use_nodes=True;legacy_node_enable_count+=1
   assert m.node_tree is not None,'Material node tree unavailable'
   n=m.node_tree.nodes.get('Principled BSDF');assert n is not None
   n.inputs['Base Color'].default_value=color;n.inputs['Roughness'].default_value=.76;n.inputs['Metallic'].default_value=.35 if name in ('iron','steel','brass') else 0;self.materials[name]=m
  self.progress.mark('materials_done',material_count=len(self.materials),legacy_node_enable_count=legacy_node_enable_count)
  s['asset_role']=self.role;s['source_reference_sha256']=REFERENCE_SHA;s['mechanics_changed']=False;s['regions_authored']=False;s['geometry']='Original3Dsolids; no image cards, no mirrored output, no frame-rescale/crop rescue'
  s['pixel_contract']='128cell;1024x640;8directions/5poses;origin64,120;occupiedbottom119'
  for source in ('actor_geometry_v02.py',pathlib.Path(__file__).name):
   text=b.data.texts.new(source);text.write((OWNED/source).read_text())
 def coll(self,name,parent):
  c=self.bpy.data.collections.new(name);parent.children.link(c);return c
 def pose(self,name):
  self.progress.mark('pose_begin',pose=name)
  b=self.bpy;r=build(self.role,name);c=b.data.collections.new('Pose_'+name);c['row']=POSES.index(name);c['anatomy']='Same local meshes/rigid links as all other4poses'
  pivots=self.coll(name+'/Joint pivots',c);assembly=self.coll(name+'/Solid anatomical assemblies',c);materials=self.coll(name+'/Material groups',c);groups={};matgroups={};joints={}
  for key,j in r.joints.items():
   obj=b.data.objects.new(name+'/'+key,None);pivots.objects.link(obj);obj.empty_display_type='SPHERE';obj.empty_display_size=.045
   if j.parent:obj.parent=joints[j.parent]
   obj.matrix_parent_inverse=self.Matrix.Identity(4);obj.matrix_basis=self.Matrix(j.matrix);obj['editable_joint']=True;obj['local_rigid_scale']=[1.,1.,1.];joints[key]=obj;self.objects.append(obj)
  for m in r.meshes:
   mesh=b.data.meshes.new(name+'/'+m.name);mesh.from_pydata(m.vertices,[],m.faces);obj=b.data.objects.new(name+'/'+m.name,mesh)
   group=m.joint.split('/')[0]
   if group not in groups:groups[group]=self.coll(name+'/'+group,assembly)
   groups[group].objects.link(obj);obj.parent=joints[m.joint];obj.matrix_parent_inverse=self.Matrix.Identity(4);obj.matrix_basis=self.Matrix.Identity(4)
   mesh.materials.append(self.materials[m.material])
   if m.highlight_material:
    mesh.materials.append(self.materials[m.highlight_material])
    for index in m.highlight_faces:mesh.polygons[index].material_index=1
   if m.material not in matgroups:matgroups[m.material]=self.coll(name+'/Material_'+m.material,materials)
   matgroups[m.material].objects.link(obj);obj['solid_component']=True;obj['anatomy_id']=m.name;obj['same_template_all5poses']=True;self.objects.append(obj)
  # Keep this complete collection detached while assigning all parent/local
  # matrices. No evaluated world data is read, so no graph rebuild is needed.
  c.hide_render=name!='idle';c.hide_viewport=name!='idle';self.poses[name]=c
  self.progress.mark('pose_done',pose=name,mesh_count=len(r.meshes),joint_count=len(r.joints));return r
 def attach_poses(self):
  self.progress.mark('scene_link_begin')
  for c in self.poses.values():self.scene.collection.children.link(c)
  self.progress.mark('scene_link_done',pose_count=len(self.poses))
 def camera(self):
  b=self.bpy;data=b.data.cameras.new('Fixed contract128px camera');cam=b.data.objects.new('Fixed contract128px camera',data);self.scene.collection.objects.link(cam);data.type='ORTHO';data.ortho_scale=SPEC[self.role]['ortho'];self.scene.camera=cam;self.cam=cam;self.direction(0)
 def direction(self,d):
  a=math.radians(d*45);s=SPEC[self.role];self.cam.location=(10*math.sin(a),-10*math.cos(a),s['camera_z']);self.cam.rotation_euler=(self.Vector((0,0,s['aim']))-self.cam.location).to_track_quat('-Z','Y').to_euler()
 def select(self,name):
  for p,c in self.poses.items():c.hide_render=p!=name;c.hide_viewport=p!=name
  # render/save operators perform their required evaluation; no redundant
  # explicit full-scene update when switching a visibility flag.
 def frame(self,rawpath):
  b=self.bpy;self.scene.render.filepath=str(rawpath);b.ops.render.render(write_still=True)
  image=b.data.images.load(str(rawpath),check_existing=False);rgba=list(image.pixels[:]);b.data.images.remove(image);raw=bytearray(128*128*4)
  for y in range(128):
   for x in range(128):
    i=((127-y)*128+x)*4;o=(y*128+x)*4
    if rgba[i+3]>=.5:raw[o:o+4]=bytes([min(255,round(rgba[i+k]*31)*8) for k in range(3)]+[255])
  occupied=[(x,y) for y in range(128) for x in range(128) if raw[(y*128+x)*4+3]];assert occupied,'Empty rendered cell'
  bbox=[min(x for x,y in occupied),min(y for x,y in occupied),max(x for x,y in occupied),max(y for x,y in occupied)]
  assert bbox[0]>0 and bbox[1]>0 and bbox[2]<127 and bbox[3]<127,'RAW GEOMETRY BORDER FAILURE: '+str(bbox)
  shift=119-bbox[3];aligned=bytearray(len(raw));clipped=0
  for y in range(128):
   dest=y+shift
   if 0<=dest<128:aligned[dest*512:(dest+1)*512]=raw[y*512:(y+1)*512]
   else:clipped+=sum(raw[(y*128+x)*4+3]>0 for x in range(128))
  assert clipped==0,'Fixedfoot registration would clip actual geometry; change model, never crop/scale'
  occupied=[(x,y) for y in range(128) for x in range(128) if aligned[(y*128+x)*4+3]]
  final=[min(x for x,y in occupied),min(y for x,y in occupied),max(x for x,y in occupied),max(y for x,y in occupied)]
  assert final[0]>0 and final[1]>0 and final[2]<127 and final[3]==119,'Registered frame contract failed'
  assert all(aligned[i] in (0,255) for i in range(3,len(aligned),4))
  return aligned,{'raw_bbox':bbox,'registered_bbox':final,'vertical_shift':shift,'clipped_pixels':clipped,'origin_px':list(ANCHOR),'occupied_bottom':119,'same_fixed_camera_no_image_rescale':True}

def main():
 a=arguments(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
 import bpy
 from mathutils import Matrix,Vector
 a.output.mkdir(parents=True);progress=Progress(a.output,a.role);progress.mark('script_ready')
 e=Exporter(bpy,Matrix,Vector,a.role,progress);e.setup();rigs={p:e.pose(p) for p in POSES};e.attach_poses();e.camera();e.select('idle')
 progress.mark('portable_write_begin')
 packed_text=portable_text(a.role,rigs)
 path=a.output/'portable-source.json';path.write_text(packed_text);progress.mark('portable_write_done',bytes=path.stat().st_size)
 embedded_source=embed_portable(bpy,path,packed_text,progress)
 progress.mark('pack_begin');bpy.ops.file.pack_all();progress.mark('pack_done')
 source=a.output/(a.role+'-scavenger-source.blend' if a.role=='crawler' else 'brute-tendon-ram-source.blend')
 progress.mark('save_begin');bpy.ops.wm.save_as_mainfile(filepath=str(source),check_existing=False,compress=False);progress.mark('save_done',bytes=source.stat().st_size)
 receipt={'status':'SOURCE_GENERATED_NOT_ART_ACCEPTED','role':a.role,'poses':list(POSES),'columns':8,'rows':5,'cell':[128,128],'atlas':[1024,640],'origin_px':list(ANCHOR),'occupied_bottom':119,'camera':SPEC[a.role],'direction_contract':'Camera0-Y(front),2+X(right),4+Y(rear); actual same3Danatomy, no image mirroring','reference_sha256':REFERENCE_SHA,'source':{'file':source.name,'sha256':sha(source),'bytes':source.stat().st_size},'portable_source':{'file':path.name,'sha256':sha(path),'bytes':path.stat().st_size},'recipes':{n:sha(OWNED/n) for n in ('actor_geometry_v02.py',pathlib.Path(__file__).name)},'editable_meshes':sum(len(r.meshes) for r in rigs.values()),'editable_joint_pivots':sum(len(r.joints) for r in rigs.values()),'same_anatomy_local_geometry_all5':True,'source_compression':False,'all5poses_full_editable_pack_retained':True,'explicit_source_depsgraph_updates':0,'embedded_portable_source_validation':embedded_source,'mechanics_changed':False,'damage_regions_authored':False,'frames':[],'requested_cells':requested(a),'not_evidence_for':['art acceptance','actual128px legibility','Godot import','gameplay/timing','regions','human','sustainedFPS']}
 receipt_path=a.output/'authoring-receipt.json'
 def checkpoint():receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
 checkpoint()
 if a.export_idle_glb:
  bpy.ops.object.select_all(action='DESELECT')
  for o in e.poses['idle'].all_objects:o.select_set(o.type in ('MESH','EMPTY'))
  glb=a.output/(a.role+'-idle.glb');bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False);receipt['optional_idle_glb']={'file':glb.name,'sha256':sha(glb),'scope':'Source interchange only, not runtime enemy replacement'};checkpoint()
 cells=[]
 for pose,direction in requested(a):
  e.select(pose);e.direction(direction);receipt['attempting']={'pose':pose,'direction':direction};checkpoint()
  progress.mark('render_begin',pose=pose,direction=direction)
  try:pixels,registration=e.frame(a.output/('native-raw-%s-%d.png'%(pose,direction)))
  except BaseException as error:receipt['status']='FRAME_FAILED_NO_CROP_OR_RESCALE';receipt['failure']=repr(error);checkpoint();raise
  path=a.output/('%s-%s-%d.png'%(a.role,pose,direction));png(path,128,128,pixels);cells.append(pixels);progress.mark('render_done',pose=pose,direction=direction);receipt['frames'].append({'file':path.name,'sha256':sha(path),'pose':pose,'row':POSES.index(pose),'direction':direction,'registration':registration});receipt.pop('attempting',None);checkpoint()
 if a.mode=='atlas':
  assert len(cells)==40 and len({hashlib.sha256(c).digest() for c in cells})==40,'Actual40cells must be unique'
  atlas=bytearray(1024*640*4)
  for i,cell in enumerate(cells):
   row,col=divmod(i,8)
   for y in range(128):start=((row*128+y)*1024+col*128)*4;atlas[start:start+512]=cell[y*512:(y+1)*512]
  path=a.output/(a.role+'.png');png(path,1024,640,atlas);receipt['atlas']={'file':path.name,'sha256':sha(path),'bytes':path.stat().st_size};checkpoint()
 receipt['render_count']=len(cells);receipt['phase_progress_file']='phase-progress.json';checkpoint();progress.mark('complete',render_count=len(cells));print('ACTOR_PAIR_DONE '+json.dumps({'role':a.role,'mode':a.mode,'renders':len(cells),'source':str(source)}),flush=True)
if __name__=='__main__':main()
