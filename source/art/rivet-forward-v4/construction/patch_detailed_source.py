"""UNRUN source-only alternate. Open pinned detailed v2; proper rigid transform only.
Blender --background --threads1 --python-exit-code1 --python THIS --
--repo READ_ONLY_REPO --output FRESH_OWNED_DIRECT_CHILD --export-source
Never renders or changes geometry/material data; original lamps move rigidly with model.
"""
import argparse,hashlib,importlib.util,json,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import camera_model_detailed as c
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main(repair_hook=None,output_name="rivet_pistol-detailed-forward-proof.blend"):
 p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--export-source',action='store_true',required=True)
 a=p.parse_args(sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else None)
 repo=a.repo.resolve(strict=True);out=a.output
 if not out.is_absolute()or out.resolve()!=out or out.parent!=HERE or out.exists():raise ValueError('Fresh owned direct child required')
 source=repo/c.SOURCE_REL;helper=repo/'tools/build_art.py';recipe=repo/c.RECIPE_REL
 if sha(source)!=c.SOURCE_SHA or sha(recipe)!=c.RECIPE_SHA or sha(helper)!=c.HELPER_SHA:raise ValueError('Pinned source/recipe/helper drift')
 import bpy
 from mathutils import Matrix,Vector
 from bpy_extras.object_utils import world_to_camera_view
 bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene
 # Reopened hidden pose objects can have deferred cached matrix_world values.
 # Enable all pose collections and evaluate BEFORE reading any world transform.
 for pose in c.POSES:bpy.data.collections[pose].hide_viewport=False
 bpy.context.view_layer.update()
 spec=importlib.util.spec_from_file_location('pinned_v2_recipe',recipe);old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
 parts=old.geometry();idle=bpy.data.collections['idle'];lookup={o.name.split(' / ',1)[-1]:o for o in idle.all_objects if o.type=='MESH'}
 if set(lookup)!=set(p['name']for p in parts):raise ValueError('Actual saved source/recipe part names differ')
 for part in parts:
  obj=lookup[part['name']]
  if len(obj.data.vertices)!=len(part['vertices']):raise ValueError('Actual saved source/recipe vertex count differs')
  for actual,expected in zip(obj.data.vertices,part['vertices']):
   if (obj.matrix_world@actual.co-Vector(c.world(expected))).length>2e-6:raise ValueError('Actual idle source geometry differs from inspected recipe')
 all_meshes={o for pose in c.POSES for o in bpy.data.collections[pose].all_objects if o.type=='MESH'}
 pre_pose_matrices=[]
 original_world={}
 for frame,pose in enumerate(c.POSES):
  expected=Matrix.Translation(Vector(c.M))@Matrix.Rotation(__import__('math').radians(old.ROLL[frame]),4,'Y')@Matrix.Translation(-Vector(c.M))
  for o in bpy.data.collections[pose].all_objects:
   if o.type!='MESH':continue
   if o.parent is not None:raise ValueError('Expected original unparented detailed pose mesh')
   basis=o.matrix_basis.copy();world=o.matrix_world.copy()
   if max(abs(basis[i][j]-expected[i][j])for i in range(4)for j in range(4))>2e-6:raise ValueError('Persisted original pose basis differs from genuine recipe ROLL')
   if max(abs(world[i][j]-expected[i][j])for i in range(4)for j in range(4))>2e-6:raise ValueError('Original pose world transform still deferred after explicit evaluation')
   original_world[o.name]=world
  barrel=next(o for o in bpy.data.collections[pose].all_objects if o.name.split(' / ',1)[-1]=='Muzzle black steel barrel')
  pre_pose_matrices.append({'pose':pose,'actual_original_basis':[list(row)for row in barrel.matrix_basis],'actual_original_world':[list(row)for row in barrel.matrix_world],'expected_original_recipe_roll_deg':old.ROLL[frame]})
 original_data={o.name:(o.data.as_pointer(),tuple(tuple(v.co)for v in o.data.vertices),tuple(m.as_pointer()for m in o.data.materials))for o in all_meshes}
 rotation=Matrix(c.ROWS).to_4x4();rigid=rotation@Matrix.Translation(-Vector(c.M))
 # Preserve genuine source lighting colors/energies/size and their model-relative placement.
 original_light_rows=[]
 for o in list(scene.objects):
  if o in all_meshes or o.type=='LIGHT':
   prior=original_world[o.name] if o in all_meshes else o.matrix_world.copy()
   if o.parent is not None:raise ValueError('Expected unparented source object for rigid transform')
   o.matrix_world=rigid@prior
   if o.type=='LIGHT':original_light_rows.append({'name':o.name,'energy':o.data.energy,'color':list(o.data.color),'type':o.data.type})
 # Keep pose collections evaluated through the actual post-transform checks.
 data=bpy.data.cameras.new('Detailed true-muzzle-axis first-person camera');cam=bpy.data.objects.new(data.name,data);scene.collection.objects.link(cam)
 cam.location=c.EYE;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
 data.type='PERSP';data.lens=c.LENS_MM;data.sensor_width=c.SENSOR_MM;data.sensor_fit='HORIZONTAL'
 data.shift_x=.5-140/320;data.shift_y=(62-100)/320;scene.camera=cam
 scene.render.resolution_x,scene.render.resolution_y=c.SIZE;scene.render.resolution_percentage=100
 scene.render.threads_mode='FIXED';scene.render.threads=1
 bpy.context.view_layer.update()
 for o in all_meshes:
  expected=rigid@original_world[o.name]
  if max(abs(o.matrix_world[i][j]-expected[i][j])for i in range(4)for j in range(4))>3e-6:raise ValueError('Actual post-transform pose world matrix was not preserved by rigid composition')
 def px(v):
  p=world_to_camera_view(scene,cam,Vector(v));return[p.x*320,(1-p.y)*200,p.z]
 native_muzzle=px((0,0,0));native_vp=px((0,1e6,0))
 if max(abs(native_muzzle[i]-c.ANCHOR[i])for i in[0,1])>.001 or max(abs(native_vp[i]-c.CROSSHAIR[i])for i in[0,1])>.001:raise ValueError('Actual saved-camera HUD projection contract failed')
 poses=[]
 for pose in c.POSES:
  col=bpy.data.collections[pose];barrel=next(o for o in col.all_objects if o.name.split(' / ',1)[-1]=='Muzzle black steel barrel')
  first=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[:20]),Vector())/20
  near=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[20:40]),Vector())/20
  axis=(first-near).normalized();muzzle_px=px(first);axis_vp=px(first+axis*1e6)
  if max(abs(muzzle_px[i]-c.ANCHOR[i])for i in[0,1])>.001:raise ValueError('Retained pose muzzle pivot no longer registered')
  if pose=='idle'and max(abs(axis_vp[i]-c.CROSSHAIR[i])for i in[0,1])>.001:raise ValueError('Actual first mesh barrel segment axis misses neutral HUD reticle')
  hand=[o for o in col.all_objects if o.type=='MESH'and any(k in o.name for k in['Glove','Forearm'])]
  projected=[px(o.matrix_world@v.co)for o in hand for v in o.data.vertices]
  if min(v[2]for v in projected)<=0:raise ValueError('Hand crosses camera')
  poses.append({'pose':pose,'actual_mesh_muzzle_px_depth':muzzle_px,'actual_mesh_first_segment_axis':list(axis),'axis_vanishing_local_px_depth':axis_vp,'hand_vertex_bounds_unclipped_px':[min(v[0]for v in projected),min(v[1]for v in projected),max(v[0]for v in projected),max(v[1]for v in projected)],'existing_pose_roll_preserved_deg':old.ROLL[c.POSES.index(pose)]})
 idle_axis=poses[0]['actual_mesh_first_segment_axis']
 for row in poses[1:]:
  if sum((row['actual_mesh_first_segment_axis'][i]-idle_axis[i])**2 for i in range(3))<1e-6:raise ValueError('Fire/recover actual barrel axis collapsed to idle; preserved-pose regression')
 for pose in c.POSES:
  col=bpy.data.collections[pose];col.hide_render=pose!='idle';col.hide_viewport=pose!='idle'
 for o in all_meshes:
  pointer,vertices,materials=original_data[o.name]
  if pointer!=o.data.as_pointer()or vertices!=tuple(tuple(v.co)for v in o.data.vertices)or materials!=tuple(m.as_pointer()for m in o.data.materials):raise ValueError('Rigid-only mesh/material invariance failed')
 geometry_repair=repair_hook(bpy,rigid,original_world) if repair_hook else None
 spec=importlib.util.spec_from_file_location('pinned_source_sanitizer',helper);shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared);shared.sanitize_source_paths(bpy)
 scene['qualification']='Detailed source rigid-camera proof only; no native raster/material/HUD acceptance'
 scene['source_ancestry']=c.SOURCE_REL;scene['source_sha256']=c.SOURCE_SHA
 out.mkdir(exist_ok=False);bpy.context.preferences.filepaths.save_version=0
 dest=out/output_name;bpy.ops.wm.save_as_mainfile(filepath=str(dest),compress=True)
 if sha(source)!=c.SOURCE_SHA:raise ValueError('Original changed')
 receipt=c.receipt();receipt.update({'scope':'Native actual saved detailed geometry matched pinned recipe before rigid transform; no render','native_muzzle':native_muzzle,'native_forward_vp':native_vp,'actual_poses':poses,'geometry_repair':geometry_repair,'pretransform_actual_and_expected_pose_matrices':pre_pose_matrices,'all_pose_matrices_compose_original_world_with_rigid':True,'source_bytes':dest.stat().st_size,'output_sha256':sha(dest),'original_source_unchanged':True,'mesh_vertices_material_slots_unchanged':True,'original_light_colors_energies_preserved':original_light_rows,'lights_rigidly_transformed_with_model':True,'view_transform_preserved':scene.view_settings.view_transform,'look_preserved':scene.view_settings.look,'rendered':False,'blender_version':bpy.app.version_string})
 (out/'detailed-source-patch-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PASS detailed actual geometry and neutral barrel VP; SOURCE ONLY no raster')


if __name__=='__main__':main()
