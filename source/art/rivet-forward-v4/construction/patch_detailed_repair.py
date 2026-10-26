"""Apply ONE authorized detailed source repair. No render; source-only export."""
import hashlib,json,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import camera_model_detailed as c
import detailed_geometry_repair as g
import patch_detailed_source as base


def data_digest(mesh):
 import struct
 return hashlib.sha256(b''.join(struct.pack('<fff',*v.co)for v in mesh.vertices)).hexdigest()


def apply(bpy,rigid,original_world):
 from mathutils import Vector
 from bpy_extras.object_utils import world_to_camera_view
 scene=bpy.context.scene
 originals={o.name:o for pose in c.POSES for o in bpy.data.collections[pose].all_objects if o.type=='MESH'}
 before={n:data_digest(o.data)for n,o in originals.items()}
 slots={n:tuple(m.as_pointer()for m in o.data.materials)for n,o in originals.items()}
 idle={o.name.split(' / ',1)[-1]:o for o in bpy.data.collections['idle'].all_objects if o.type=='MESH'}
 sight=idle[g.MODIFIED_PART].data
 for v,new in zip(sight.vertices,g.raise_sight([tuple(v.co)for v in sight.vertices])):v.co=new
 sight.update()
 retired=bpy.data.collections.new('RETIRED_original_black_rear_inset');scene.collection.children.link(retired)
 retired_names=[]
 for pose in c.POSES:
  col=bpy.data.collections[pose];obj=next(o for o in col.all_objects if o.name.split(' / ',1)[-1]==g.RETIRED_PART)
  retired.objects.link(obj);col.objects.unlink(obj);retired_names.append(obj.name)
 retired.hide_render=True;retired.hide_viewport=True
 additions=[]
 for part in g.repair_parts():
  mesh=bpy.data.meshes.new(g.REVISION+' / '+part['name'])
  mesh.from_pydata([g.inverse_rigid(v)for v in part['vertices']],[],part['faces']);mesh.update()
  mesh.materials.append(idle[part['material_source']].data.materials[0])
  pose_names=[]
  for pose in c.POSES:
   obj=bpy.data.objects.new(pose+' / '+part['name'],mesh);bpy.data.collections[pose].objects.link(obj)
   barrel_name=next(n for n in original_world if n.startswith(pose+' / Muzzle black steel barrel'))
   obj.matrix_world=rigid@original_world[barrel_name];pose_names.append(obj.name)
  additions.append({'name':part['name'],'mesh_sha256':data_digest(mesh),'vertices':len(mesh.vertices),'triangles':sum(len(f)-2 for f in part['faces']),'existing_material_source':part['material_source'],'existing_material_name':mesh.materials[0].name,'pose_objects':pose_names})
 # Evaluate all actual pose instances before checking saved-source transforms/geometry.
 for pose in c.POSES:bpy.data.collections[pose].hide_viewport=False
 bpy.context.view_layer.update()
 after={n:data_digest(o.data)for n,o in originals.items()}
 changed=[n for n in before if before[n]!=after[n]]
 if set(changed)!={pose+' / '+g.MODIFIED_PART for pose in c.POSES}:raise ValueError('Geometry repair escaped exact allowed original mesh set')
 if any(tuple(m.as_pointer()for m in o.data.materials)!=slots[n]for n,o in originals.items()):raise ValueError('Original material slots changed')
 axes=[]
 for pose in c.POSES:
  col=bpy.data.collections[pose];barrel=next(o for o in col.all_objects if o.name.split(' / ',1)[-1]=='Muzzle black steel barrel')
  first=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[:20]),Vector())/20
  near=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[20:40]),Vector())/20
  axis=(first-near).normalized();vp=world_to_camera_view(scene,scene.camera,first+axis*1e6)
  if pose=='idle'and max(abs(v-t)for v,t in zip([vp.x*320,(1-vp.y)*200],c.CROSSHAIR))>.001:raise ValueError('Repair changed neutral barrel VP')
  axes.append({'pose':pose,'actual_barrel_axis':list(axis),'axis_vp_px':[vp.x*320,(1-vp.y)*200]})
 for row in axes[1:]:
  if sum((a-b)**2 for a,b in zip(row['actual_barrel_axis'],axes[0]['actual_barrel_axis']))<1e-6:raise ValueError('Pose collapsed during repair')
 for pose in c.POSES:
  col=bpy.data.collections[pose];col.hide_viewport=pose!='idle';col.hide_render=pose!='idle'
 scene['geometry_revision']=g.REVISION
 return{'revision':g.REVISION,'retired_original_meshes_preserved_hidden':retired_names,'changed_original_meshes':changed,'original_sight_mesh_sha256_before':before['idle / '+g.MODIFIED_PART],'original_sight_mesh_sha256_after':after['idle / '+g.MODIFIED_PART],'all_other_original_mesh_vertex_hashes_unchanged':True,'all_original_material_slots_unchanged':True,'added_parts':additions,'actual_postrepair_pose_axes':axes,'bore_muzzle_cage_glove_unchanged':True,'all_original_lights_material_color_pipeline_unchanged':True,'hypothesis':'Closed mechanical breech plus one supported continuous forward dorsal sight rib; no other geometry or lighting change'}


if __name__=='__main__':base.main(repair_hook=apply,output_name='rivet_pistol-detailed-repair01.blend')
