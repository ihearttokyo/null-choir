"""Export actual source geometry only. Never renders or modifies saved blends."""
import bpy,json,hashlib,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent
OUT=Path(sys.argv[sys.argv.index('--')+1]);OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for path in sorted(BASE.glob('*.blend')):
 before=sha(path);bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene
 for pose in ['idle','fire','recover']:
  for c in bpy.data.collections:c.hide_viewport=False;c.hide_render=False
  bpy.ops.object.select_all(action='DESELECT')
  picked=[]
  pose_objects=set(bpy.data.collections[pose].all_objects)|set(bpy.data.collections['V3_'+pose].all_objects)
  for o in scene.objects:
   o.hide_viewport=False;o.hide_set(False)
   if o.type=='MESH' and o in pose_objects:o.select_set(True);picked.append(o)
  assert len(picked)>10,(path,pose)
  name=path.stem+'-'+pose+'.glb'
  bpy.ops.export_scene.gltf(filepath=str(OUT/name),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True,export_yup=True,export_image_format='NONE')
  rows.append({'weapon':path.stem,'pose':pose,'file':name,'sha256':sha(OUT/name),'source_sha256':before,'selected_meshes':len(picked),'selection':'exact original pose hand collection + matching V3 mechanism collection only'})
 assert sha(path)==before
(OUT/'manifest.json').write_text(json.dumps({'scope':'Actual saved/reopened source geometry; one pose per GLB; source files unchanged; no render/bake/sim','views':rows},indent=2));print('PASS18 selected actual source views exported; sources unchanged')
