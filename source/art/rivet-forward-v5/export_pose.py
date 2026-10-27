"""HELD: source-readonly ONE64sampleCPU PBR pose; requires NEW explicit root grant.
This exact file is also the compact future native-v5 exporter; never builds/saves a source.
"""
import argparse,importlib.util,json,pathlib,sys,time
sys.dont_write_bytecode=True
HERE=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(HERE));import common as c

def validate_source(bpy,source,proof):
 from mathutils import Vector
 from bpy_extras.object_utils import world_to_camera_view
 assert c.sha(source.read_bytes())==c.SOURCE_SHA and pathlib.Path(bpy.data.filepath).resolve()==source.resolve()
 assert bpy.app.version[:3]==(5,2,2)
 scene=bpy.context.scene;cam=scene.camera
 assert cam and cam.data.type=='PERSP' and (cam.location-Vector((0,-3.88,.2598214285714285))).length<2e-6
 assert cam.data.sensor_fit=='HORIZONTAL' and all(abs(a-b)<2e-6 for a,b in [(cam.data.lens,42),(cam.data.sensor_width,36),(cam.data.shift_x,.0625),(cam.data.shift_y,-.11875)])
 assert (scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)==(320,200,100)
 for p in c.POSES:bpy.data.collections[p].hide_viewport=False
 bpy.context.view_layer.update()
 def px(v):
  p=world_to_camera_view(scene,cam,v);return[p.x*320,(1-p.y)*200,p.z]
 def center(o,a=None,b=None):
  vs=list(o.data.vertices)[a:b];return sum((o.matrix_world@v.co for v in vs),Vector())/len(vs)
 rows=[]
 for expected in proof['actual_saved_reopen']:
  pose=expected['pose'];parts={o.name.split(' / ',1)[-1]:o for o in bpy.data.collections[pose].all_objects if o.type=='MESH'};assert len(parts)==99
  barrel=parts['Muzzle black steel barrel'];assert len(barrel.data.vertices)==60
  muzzle=center(barrel,0,20);axis=(muzzle-center(barrel,20,40)).normalized()
  row={'pose':pose,'muzzle':px(muzzle),'axis_vanishing':px(muzzle+axis*1e6),'receiver_center':px(center(parts['Receiver dark mass'])),'rearcap_center':px(center(parts['Short rear brass cap'],16,32)),'closed_breech_center':px(center(parts['Closed octagonal breech backplate'])),'actual_barrel_axis':list(axis)}
  for key in row:
   if key!='pose':assert max(abs(a-b) for a,b in zip(row[key],expected[key]))<.001,('Saved source pose/camera/receiver drift',pose,key)
  rows.append(row)
 assert len(rows)==3 and abs(rows[0]['rearcap_center'][0]-140)<1 and abs(rows[0]['receiver_center'][0]-140)<6
 assert bpy.data.collections['RETIRED_original_black_rear_inset'].hide_render
 assert not bpy.data.images and not bpy.data.libraries,'No external/image-card source dependency'
 return rows

def shading_fingerprint(bpy):
 # Read-only source appearance; no deprecated Material.use_nodes access.
 rows=[]
 for m in sorted(bpy.data.materials,key=lambda x:x.name):
  t=m.node_tree;rows.append([m.name,list(m.diffuse_color),[(n.name,n.bl_idname,[(v.name,repr(v.default_value)) for v in n.inputs if hasattr(v,'default_value')]) for n in t.nodes] if t else [],sorted((l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in t.links) if t else []])
 lights=[[o.name,list(o.location),list(o.rotation_euler),o.data.type,o.data.energy,list(o.data.color),o.data.shape if o.data.type=='AREA' else None] for o in bpy.context.scene.objects if o.type=='LIGHT']
 s=bpy.context.scene;return c.sha(json.dumps([rows,lights,s.view_settings.view_transform,s.view_settings.look,s.view_settings.exposure,s.view_settings.gamma,s.world.name,list(s.world.color)],sort_keys=True).encode())

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--source-proof',type=pathlib.Path,required=True);p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--pose',choices=c.POSES,required=True);p.add_argument('--owned-output-root',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
 source=a.source.resolve();helper=a.repo.resolve()/'tools/build_art.py';out=a.output.resolve()
 assert c.sha(helper.read_bytes())==c.HELPER_SHA and c.sha(a.source_proof.read_bytes())==c.PROOF_SHA
 owned=a.owned_output_root.resolve();assert owned.is_dir() and out.parent==owned and out!=owned and not out.exists() and not out.is_relative_to(source.parent),'Fresh explicit owned onepose output outside authoritative source family only'
 import bpy
 rows=validate_source(bpy,source,json.loads(a.source_proof.read_text()));before=shading_fingerprint(bpy);scene=bpy.context.scene
 for pose in c.POSES:
  col=bpy.data.collections[pose];col.hide_render=pose!=a.pose;col.hide_viewport=pose!=a.pose
 bpy.context.view_layer.update()
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=2
 spec=importlib.util.spec_from_file_location('pinned_original_pbr_pixel_pipeline',helper);art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
 out.mkdir();art.ART=out/'source';art.OUT=out/'runtime';art.SCRATCH=out
 start=time.monotonic();print('DRAW_BEGIN_MONOTONIC='+str(start),flush=True);cell=art.pixels_render(scene,'rivet_pistol_'+a.pose,320,200);elapsed=time.monotonic()-start;print('DRAW_END_MONOTONIC='+str(time.monotonic()),flush=True)
 assert elapsed<10,'Stop: original10second perframe bound exceeded; no fallback'
 assert set(cell[3::4])=={0,255};path=out/(a.pose+'.png');art.png(path,320,200,cell)
 assert shading_fingerprint(bpy)==before and c.sha(source.read_bytes())==c.SOURCE_SHA
 raw=out/'frames'/('rivet_pistol_'+a.pose+'.png');assert c.quantize(c.rgba(raw.read_bytes(),[320,200]))==cell,'Exact original native PNG ->quant5bit/hardalpha route'
 report={'status':'ACTUAL_ONE_CPU_PBR_POSE_NOT_VISUAL_ACCEPTANCE','pose':a.pose,'source_sha256':c.SOURCE_SHA,'source_unchanged':True,'helper_sha256':c.HELPER_SHA,'source_proof_sha256':c.PROOF_SHA,'actual_reopened_poses':rows,'engine':'CYCLES','device':'CPU','samples':64,'threads':2,'denoising':False,'shading_lights_world_color_unchanged':True,'draw_and_native_readback_seconds':elapsed,'frame':{'file':path.name,'sha256':c.sha(path.read_bytes()),'rgba_sha256':c.sha(cell)},'raw':{'file':str(raw.relative_to(out)),'sha256':c.sha(raw.read_bytes())},'no_source_save_or_reconstruction':True}
 (out/'pose-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
