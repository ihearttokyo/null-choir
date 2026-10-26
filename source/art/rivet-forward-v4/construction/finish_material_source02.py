"""One scoped material-only finish. Frozen geometry/camera/poses; no render."""
import hashlib,json,math,struct,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import camera_model_detailed as c
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
SOURCE=HERE/'detailed-repair-source01/rivet_pistol-detailed-repair01.blend'
EXPECTED='8e805ef74c61a12ab56e9e1743df5c0dfefe3a515767fd905cfc0ce159910a10'
OUT=HERE/'detailed-finish-source02'

def plain(v):
 if isinstance(v,(bool,int,float,str))or v is None:return v
 try:return[plain(x)for x in v]
 except TypeError:return getattr(v,'name',str(type(v).__name__))

def graph(mat):
 result={'name':mat.name,'use_nodes':mat.use_nodes,'nodes':[],'links':[]}
 if not mat.use_nodes:return result
 for n in mat.node_tree.nodes:
  row={'name':n.name,'type':n.bl_idname,'inputs':{s.name:plain(s.default_value)for s in n.inputs if hasattr(s,'default_value')}}
  for key in ['noise_dimensions','noise_type','normalize','samples']:
   if hasattr(n,key):row[key]=plain(getattr(n,key))
  if n.bl_idname=='ShaderNodeValToRGB':row['ramp']={'interpolation':n.color_ramp.interpolation,'elements':[{'position':e.position,'color':list(e.color)}for e in n.color_ramp.elements]}
  result['nodes'].append(row)
 result['links']=[{'from':[l.from_node.name,l.from_socket.name],'to':[l.to_node.name,l.to_socket.name]}for l in mat.node_tree.links]
 return result

def geometry(mesh):
 h=hashlib.sha256()
 for v in mesh.vertices:h.update(struct.pack('<fff',*v.co))
 for p in mesh.polygons:h.update(struct.pack('<I',len(p.vertices)));h.update(struct.pack('<'+'I'*len(p.vertices),*p.vertices))
 return h.hexdigest()

def rgba(s):
 values=[int(s[i:i+2],16)/255 for i in[1,3,5]]
 return tuple(v/12.92 if v<=.04045 else((v+.055)/1.055)**2.4 for v in values)+(1.,)

def tune(base,name,dark,light,metal,rough,scale,detail,bump_strength,bump_distance):
 mat=base.copy();mat.name=name;n=mat.node_tree.nodes
 principled=next(x for x in n if x.bl_idname=='ShaderNodeBsdfPrincipled')
 noise=next(x for x in n if x.bl_idname=='ShaderNodeTexNoise');ramp=next(x for x in n if x.bl_idname=='ShaderNodeValToRGB');bump=next(x for x in n if x.bl_idname=='ShaderNodeBump')
 principled.inputs['Metallic'].default_value=metal;principled.inputs['Roughness'].default_value=rough
 noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=detail;noise.inputs['Roughness'].default_value=.4
 ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[-1].position=.85
 ramp.color_ramp.elements[0].color=rgba(dark);ramp.color_ramp.elements[-1].color=rgba(light)
 bump.inputs['Strength'].default_value=bump_strength;bump.inputs['Distance'].default_value=bump_distance
 return mat

def main():
 if OUT.exists()or sha(SOURCE)!=EXPECTED:raise ValueError('Fresh output and exact frozen source required')
 import bpy
 from mathutils import Vector
 from bpy_extras.object_utils import world_to_camera_view
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
 for pose in c.POSES:bpy.data.collections[pose].hide_viewport=False
 bpy.context.view_layer.update()
 objs={o.name:o for o in scene.objects if o.type=='MESH'}
 meshes={o.data.as_pointer():o.data for o in objs.values()}
 geom_before={m.name:geometry(m)for m in meshes.values()}
 poses_before={n:[list(row)for row in o.matrix_basis]for n,o in objs.items()}
 camera_before={'matrix':[list(row)for row in scene.camera.matrix_world],'lens':scene.camera.data.lens,'sensor_width':scene.camera.data.sensor_width,'shift':[scene.camera.data.shift_x,scene.camera.data.shift_y]}
 original_mats=list(bpy.data.materials);graphs_before={m.name:graph(m)for m in original_mats}
 idle={o.name.split(' / ',1)[-1]:o for o in bpy.data.collections['idle'].all_objects if o.type=='MESH'}
 face=tune(idle['Closed octagonal breech backplate'].data.materials[0],'Finish02 controlled worked-metal face','#787d70','#a3a893',.18,.42,5,.5,.04,.0006)
 edge=tune(idle['Continuous slender dorsal sight rib'].data.materials[0],'Finish02 warm bronze edge','#7f653b','#cfb77a',.60,.30,5,.6,.05,.0006)
 lock=tune(idle['Shallow breech locking bar'].data.materials[0],'Finish02 defined steel lock','#272d2c','#505951',.25,.48,6,.5,.04,.0005)
 glove=tune(idle['Glove palm'].data.materials[0],'Finish02 broad charcoal leather','#191918','#323330',0,.90,3.2,.5,.035,.0007)
 wrap=tune(idle['Glove thumb'].data.materials[0],'Finish02 broad folded leather','#282927','#484a44',0,.88,4,.5,.04,.0008)
 # Shader-normal bevel ONLY; no mesh modifier, vertices or polygon changes.
 for mat in[face,edge]:
  nodes=mat.node_tree.nodes;bevel=nodes.new('ShaderNodeBevel');bevel.name='Subpixel worked edge normal only';bevel.samples=4;bevel.inputs['Radius'].default_value=.0045
  bump=next(n for n in nodes if n.bl_idname=='ShaderNodeBump');mat.node_tree.links.new(bevel.outputs['Normal'],bump.inputs['Normal'])
 changes=[];done=set()
 for name,obj in objs.items():
  mesh=obj.data
  if mesh.as_pointer()in done:continue
  done.add(mesh.as_pointer());part=name.split(' / ',1)[-1];before_slots=[m.name for m in mesh.materials];change=False
  if part=='Closed octagonal breech backplate':
   mesh.materials.clear();mesh.materials.append(face);mesh.materials.append(edge)
   for poly in mesh.polygons:poly.material_index=0 if poly.index==0 else 1
   change=True
  elif part=='Shallow breech locking bar':mesh.materials[0]=lock;change=True
  elif part in['Breech fastener upper','Breech fastener lower']:mesh.materials[0]=edge;change=True
  elif any(k in part for k in['Glove','Forearm']):
   for i,mat in enumerate(mesh.materials):
    if mat.name=='glove':mesh.materials[i]=glove;change=True
    elif mat.name=='wrap':mesh.materials[i]=wrap;change=True
  if change:changes.append({'part':part,'before_materials':before_slots,'after_materials':[m.name for m in mesh.materials],'polygon_material_indices':[poly.material_index for poly in mesh.polygons]if part=='Closed octagonal breech backplate'else None})
 if {m.name:geometry(m)for m in meshes.values()}!=geom_before:raise ValueError('Material-only repair changed actual mesh vertices/faces')
 if {n:[list(row)for row in o.matrix_basis]for n,o in objs.items()}!=poses_before:raise ValueError('Frozen pose/object transforms changed')
 if {m.name:graph(m)for m in original_mats}!=graphs_before:raise ValueError('Original material graph changed instead of scoped copy')
 camera_after={'matrix':[list(row)for row in scene.camera.matrix_world],'lens':scene.camera.data.lens,'sensor_width':scene.camera.data.sensor_width,'shift':[scene.camera.data.shift_x,scene.camera.data.shift_y]}
 if camera_after!=camera_before:raise ValueError('Frozen camera changed')
 rows=[]
 for frame,pose in enumerate(c.POSES):
  barrel=next(o for o in bpy.data.collections[pose].all_objects if o.name.split(' / ',1)[-1]=='Muzzle black steel barrel')
  first=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[:20]),Vector())/20;near=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[20:40]),Vector())/20
  axis=(first-near).normalized();a=math.radians((0,1.6,-.65)[frame]);x,y,z=c.A;expected=(math.cos(a)*x+math.sin(a)*z,y,-math.sin(a)*x+math.cos(a)*z)
  if (axis-Vector(tuple(c.dot(expected,row)for row in c.ROWS))).length>2e-6:raise ValueError('Original recoil pose not preserved')
  mu=world_to_camera_view(scene,scene.camera,first);vp=world_to_camera_view(scene,scene.camera,first+axis*1e6)
  if max(abs(v-t)for v,t in zip([mu.x*320,(1-mu.y)*200],c.ANCHOR))>.001:raise ValueError('Muzzle changed')
  if frame==0 and max(abs(v-t)for v,t in zip([vp.x*320,(1-vp.y)*200],c.CROSSHAIR))>.001:raise ValueError('Neutral VP changed')
  rows.append({'pose':pose,'actual_axis':list(axis),'muzzle_px':[mu.x*320,(1-mu.y)*200],'vp_px':[vp.x*320,(1-vp.y)*200]})
 for pose in c.POSES:
  col=bpy.data.collections[pose];col.hide_viewport=pose!='idle';col.hide_render=pose!='idle'
 scene.cycles.samples=64;scene.cycles.device='CPU';scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=2
 scene['material_revision']='worked-metal-broad-leather-finish02'
 OUT.mkdir(exist_ok=False);bpy.context.preferences.filepaths.save_version=0
 dest=OUT/'rivet_pistol-detailed-finish02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(dest),compress=True)
 if sha(SOURCE)!=EXPECTED:raise ValueError('Frozen original source changed')
 before={'graphs':graphs_before,'geometry':geom_before,'object_matrices':poses_before,'camera':camera_before}
 after={'scoped_new_material_graphs':{m.name:graph(m)for m in[face,edge,lock,glove,wrap]},'changed_material_bindings':changes,'geometry':geom_before,'object_matrices':poses_before,'camera':camera_after}
 (OUT/'material-graphs-before.json').write_text(json.dumps(before,indent=2)+'\n');(OUT/'material-graphs-after.json').write_text(json.dumps(after,indent=2)+'\n')
 prior=json.loads((SOURCE.parent/'detailed-source-patch-receipt.json').read_text())
 r={'scope':'ONE scoped material finish02; actual vertices/faces/camera/allposes frozen','output_sha256':sha(dest),'source_bytes':dest.stat().st_size,'input_source_sha256':EXPECTED,'input_source_unchanged':True,'geometry_repair':prior['geometry_repair'],'material_finish':{'revision':'worked-metal-broad-leather-finish02','changed_material_bindings':changes,'geometry_sha256_before_after':geom_before,'all_original_material_graphs_unchanged':True,'cage_original_material_bindings_unchanged':True,'all_pose_object_matrices_unchanged':True,'camera_unchanged':True,'actual_pose_axes':rows,'emission_added':False,'lights_world_changed':False,'samples':64,'graph_before_sha256':sha(OUT/'material-graphs-before.json'),'graph_after_sha256':sha(OUT/'material-graphs-after.json')},'rendered':False,'blender_version':bpy.app.version_string}
 (OUT/'detailed-source-patch-receipt.json').write_text(json.dumps(r,indent=2)+'\n');print('PASS material-only source save; actual mesh/camera/pose/original-material invariants pass; no render')

if __name__=='__main__':main()
