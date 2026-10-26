"""Portable verified native-v4 source exporter. No render unless --render is explicit.
Use Blender5.2.2 background CPU; the caller must provide a bounded native process.
The saved editable blend is authoritative. Intermediate construction rebuilds are optional.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import time
sys.dont_write_bytecode=True
SOURCE_SHA='99b0882a1b1b9bd1952668cfe645ad3c3a46327fe3d0fb4664341bf683420b56'
ATLAS_SHA='9470e33b6c9a33127afb554a1848310c42d0cfd4bab1e05cbbe33a0495524618'
HELPER_SHA='07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a'
POSES=('idle','fire','recover')
EXPECTED_AXES=((0,1,0),(.005580754950642586,.9996629357337952,.02535456418991089),(-.0021928867790848017,.9999443888664246,-.010317415930330753))


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_output(output,owned):
 if not output.is_absolute()or output.resolve()!=output:raise ValueError('Output must be canonical and absolute')
 if not owned.is_absolute()or owned.resolve()!=owned or not owned.is_dir():raise ValueError('Explicit owned output root must be a canonical existing directory')
 if output==owned or not output.is_relative_to(owned)or output.exists():raise ValueError('Output must be a fresh descendant of the explicit owned root')

def compile_cells(cells):
 if len(cells)!=3 or any(len(cell)!=320*200*4 for cell in cells):raise ValueError('Expected three320x200native cells')
 if any(set(cell[3::4])!={0,255}for cell in cells):raise ValueError('Original hardalpha pipeline must be binary and nonempty')
 if len(set(map(bytes,cells)))!=3:raise ValueError('Genuine source poses must produce distinct pixels')
 result=bytearray(960*200*4)
 for frame,cell in enumerate(cells):
  for y in range(200):result[(y*960+frame*320)*4:(y*960+(frame+1)*320)*4]=cell[y*320*4:(y+1)*320*4]
 return result

def verify_native_source(bpy):
 from mathutils import Vector
 from bpy_extras.object_utils import world_to_camera_view
 scene=bpy.context.scene
 if bpy.app.version[:3]!=(5,2,2):raise ValueError('This exact accepted raster requires Blender5.2.2')
 if scene.camera is None or scene.camera.data.type!='PERSP':raise ValueError('Accepted perspective camera required')
 cam=scene.camera;data=cam.data
 if (cam.location-Vector((0,-3.88,.2598214285714285))).length>2e-6:raise ValueError('Frozen camera position changed')
 for actual,expected in[(data.lens,42),(data.sensor_width,36),(data.shift_x,.0625),(data.shift_y,-.11875)]:
  if abs(actual-expected)>2e-6:raise ValueError('Frozen camera optics changed')
 if data.sensor_fit!='HORIZONTAL':raise ValueError('Frozen camera sensor fit changed')
 if scene.render.resolution_x!=320 or scene.render.resolution_y!=200 or scene.render.resolution_percentage!=100:raise ValueError('Native320x200source required')
 for name in POSES:
  if name not in bpy.data.collections:raise ValueError('Missing genuine saved pose collection')
  bpy.data.collections[name].hide_viewport=False
 bpy.context.view_layer.update() # Critical: resolve originally hidden pose matrices BEFORE reading them.
 def project(point):
  p=world_to_camera_view(scene,cam,point);return[p.x*320,(1-p.y)*200,p.z]
 rows=[]
 for index,name in enumerate(POSES):
  collection=bpy.data.collections[name]
  objects=[o for o in collection.all_objects if o.type=='MESH']
  if len(objects)!=99:raise ValueError('Accepted editable source part count changed')
  barrel=next(o for o in objects if o.name.split(' / ',1)[-1]=='Muzzle black steel barrel')
  if len(barrel.data.vertices)!=60:raise ValueError('Actual first barrel segment topology changed')
  first=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[:20]),Vector())/20
  near=sum((barrel.matrix_world@v.co for v in barrel.data.vertices[20:40]),Vector())/20
  axis=(first-near).normalized()
  if(axis-Vector(EXPECTED_AXES[index])).length>2e-6:raise ValueError('Actual reopened source pose axis differs from original retained recoil')
  muzzle=project(first);vanishing=project(first+axis*1e6)
  if max(abs(a-b)for a,b in zip(muzzle[:2],[140,62]))>.001:raise ValueError('Actual finite muzzle pivot changed')
  if index==0 and max(abs(a-b)for a,b in zip(vanishing[:2],[140,37]))>.001:raise ValueError('Actual neutral barrel vanishing point misses logicalHUDreticle')
  materials={m for o in objects for m in o.data.materials if m}
  if any(n.bl_idname=='ShaderNodeTexImage'for m in materials if m.use_nodes for n in m.node_tree.nodes):raise ValueError('Unexpected image-plane/material dependency')
  rows.append({'pose':name,'actual_mesh_axis':list(axis),'muzzle_local_px':muzzle[:2],'axis_vanishing_local_px':vanishing[:2],'editable_mesh_parts':len(objects),'triangles':sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)})
 if not bpy.data.collections['RETIRED_original_black_rear_inset'].hide_render:raise ValueError('Retired black inset unexpectedly visible')
 if any(math.dist(rows[0]['actual_mesh_axis'],r['actual_mesh_axis'])<.01 for r in rows[1:]):raise ValueError('Recoil poses collapsed to neutral')
 return rows

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source',type=Path,default=Path(__file__).resolve().with_name('rivet_pistol.blend'))
 parser.add_argument('--repo',type=Path,required=True,help='Repository containing the pinned tools/build_art.py helper')
 parser.add_argument('--output',type=Path,required=True)
 parser.add_argument('--owned-output-root',type=Path,required=True)
 parser.add_argument('--render',action='store_true',help='Explicitly authorize all three native CPU renders; absent means source verification only')
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else None)
 validate_output(args.output,args.owned_output_root)
 source=args.source.resolve(strict=True);helper=args.repo.resolve(strict=True)/'tools/build_art.py'
 if digest(source)!=SOURCE_SHA or digest(helper)!=HELPER_SHA:raise ValueError('Accepted source/helper hash mismatch; no implicit replacement')
 if args.output.is_relative_to(source.parent):raise ValueError('Export outside the authoritative source packet')
 import bpy
 bpy.ops.wm.open_mainfile(filepath=str(source));rows=verify_native_source(bpy);scene=bpy.context.scene
 report={'scope':'Accepted native Blender source verification; no source save','source':'source/art/rivet-forward-v4/rivet_pistol.blend','source_sha256':SOURCE_SHA,'helper':'tools/build_art.py','helper_sha256':HELPER_SHA,'blender_version':bpy.app.version_string,'actual_reopened_poses':rows,'rendered':False,'frame_size':[320,200],'atlas_size':[960,200],'expected_atlas_sha256':ATLAS_SHA}
 args.output.mkdir(parents=True,exist_ok=False)
 if args.render:
  spec=importlib.util.spec_from_file_location('pinned_original_native_pixel_pipeline',helper);art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
  art.ART=args.output/'source';art.OUT=args.output/'runtime';art.SCRATCH=args.output
  # All original scene lights/world/color/seed/materials remain untouched.
  scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=False
  scene.render.threads_mode='FIXED';scene.render.threads=2
  cells=[];frames=[]
  for name in POSES:
   for pose in POSES:
    col=bpy.data.collections[pose];col.hide_render=pose!=name;col.hide_viewport=pose!=name
   bpy.context.view_layer.update();start=time.monotonic()
   cell=art.pixels_render(scene,'rivet_pistol_'+name,320,200);elapsed=time.monotonic()-start
   if elapsed>10:raise RuntimeError('Native frame exceeded10seconds; retain output and stop without fallback')
   path=args.output/(name+'.png');art.png(path,320,200,cell);cells.append(cell)
   raw=args.output/'frames'/('rivet_pistol_'+name+'.png')
   frames.append({'pose':name,'path':path.name,'sha256':digest(path),'bytes':path.stat().st_size,'native_draw_and_readback_seconds':elapsed,'raw_same_draw_path':raw.relative_to(args.output).as_posix(),'raw_sha256':digest(raw),'raw_classification':'Uncompiled same native draw; not runtime pipeline bytes'})
  atlas=args.output/'rivet_pistol.png';art.png(atlas,960,200,compile_cells(cells))
  report.update({'rendered':True,'engine':'CYCLES','device':'CPU','samples':64,'threads':2,'denoising':False,'frames':frames,'atlas':'rivet_pistol.png','actual_atlas_sha256':digest(atlas),'atlas_bytes':atlas.stat().st_size,'atlas_matches_accepted':digest(atlas)==ATLAS_SHA,'pipeline':'Pinned native readback31-step quantization and hardalpha; no imagewarp/generator'})
  (args.output/'export-verification.json').write_text(json.dumps(report,indent=2)+'\n')
  if digest(atlas)!=ATLAS_SHA:raise RuntimeError('Actual atlas differs from exact accepted raster; preserve evidence, do not promote or rerender automatically')
 if digest(source)!=SOURCE_SHA:raise RuntimeError('Authoritative source unexpectedly changed')
 report['source_unchanged']=True
 (args.output/'export-verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'source_verified':True,'rendered':report['rendered'],'atlas_matches_accepted':report.get('atlas_matches_accepted'),'source_unchanged':True}))

if __name__=='__main__':main()
