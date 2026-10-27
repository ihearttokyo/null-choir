"""Compact additive v5 registration gate; never weakens or calls the retained v4 guard.
No normal-import/HUD/review receipt can be invented by atlas compilation.
"""
import json,pathlib,re
from common import POSES,RUNTIME,SOURCE_SHA,HELPER_SHA,sha,rgba,quantize,compile_cells,png,same
FAMILY='source/art/rivet-forward-v5/'
OUTPUT='game/assets/art/weapons/native-v5/rivet_pistol.png'
def cells(atlas):return [b''.join(atlas[(y*960+f*320)*4:(y*960+(f+1)*320)*4] for y in range(200)) for f in range(3)]
def record(root,r,path):
 assert isinstance(r,dict) and r.get('path')==path and re.fullmatch('[0-9a-f]{64}',r.get('sha256','')) and type(r.get('bytes')) is int
 p=root/path;assert p.resolve().is_relative_to(root.resolve()) and not any(a.is_symlink() for a in (p,*p.parents))
 b=p.read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256'];return b

def validate_qualified(root,value):
 assert value.get('schema')=='null-choir-rivet-native-v5-v1' and value.get('status')=='QUALIFIED','PENDING actual PBR/import/fullHUD/independent evidence; no partial acceptance'
 assert same(value['runtime_contract'],RUNTIME)
 source=record(root,value['source'],FAMILY+'rivet_pistol.blend');assert sha(source)==SOURCE_SHA
 atlas=record(root,value['output'],OUTPUT);pixels=rgba(atlas,[960,200]);parts=cells(pixels);assert len(set(map(bytes,parts)))==3 and all(set(c[3::4])=={0,255} for c in parts)
 expected={'source_sha256':SOURCE_SHA,'atlas_sha256':sha(atlas),'rgba_sha256':sha(pixels),'pose_rgba_sha256':[sha(c) for c in parts]}
 assert all(same(value.get(k),v) for k,v in expected.items())
 for kind in ['source-pbr','normal-import','full-hud','independent']:
  proof=json.loads(record(root,value['qualification'][kind],FAMILY+'proof/'+kind+'.json'))
  assert proof.get('status')=='PASS' and all(same(proof.get(k),v) for k,v in expected.items()),'Actual qualification must bind exact newsource/newpixels'
  if kind=='source-pbr':assert proof.get('engine')=='CYCLES' and proof.get('device')=='CPU' and same(proof.get('samples'),64) and proof.get('helper_sha256')==HELPER_SHA and proof.get('rendered_poses')==list(POSES)
  elif kind=='normal-import':assert proof.get('resource_class')=='CompressedTexture2D' and re.fullmatch('uid://[a-z0-9]+',proof.get('uid','')) and proof.get('bit_exact') is True and proof.get('actual_engine_generated_uid') is True
  elif kind=='full-hud':assert proof.get('actual_production_draw') is True and proof.get('full_instrument_chrome') is True and proof.get('actual_world_context') is True and proof.get('runtime_uri')=='res://assets/art/weapons/native-v5/rivet_pistol.png' and proof.get('resolution')==[640,360]
  else:assert proof.get('review_role')=='independent' and proof.get('numeric_rating_included') is False
 return {'status':'QUALIFIED_NATIVE_V5_REGISTRATION','runtime_output':OUTPUT,'retains_v4_unchanged':True}

def compile_rendered(batch,output):
 """Pure assembly AFTER3real native draws; creates PENDING, never qualification."""
 assert not output.exists();parts=[];rows=[]
 for pose in POSES:
  directory=batch/pose;r=json.loads((directory/'pose-receipt.json').read_text())
  assert r['status']=='ACTUAL_ONE_CPU_PBR_POSE_NOT_VISUAL_ACCEPTANCE' and r['pose']==pose and r['source_sha256']==SOURCE_SHA and r['helper_sha256']==HELPER_SHA
  assert r['engine']=='CYCLES' and r['device']=='CPU' and r['samples']==64 and r['threads']==2 and r['denoising'] is False and r['source_unchanged'] and r['shading_lights_world_color_unchanged'] and r['draw_and_native_readback_seconds']<10
  frame=(directory/r['frame']['file']).read_bytes();raw=(directory/r['raw']['file']).read_bytes();assert sha(frame)==r['frame']['sha256'] and sha(raw)==r['raw']['sha256']
  cell=rgba(frame,[320,200]);assert sha(cell)==r['frame']['rgba_sha256'] and quantize(rgba(raw,[320,200]))==cell
  parts.append(cell);rows.append({'pose':pose,'png_sha256':sha(frame),'rgba_sha256':sha(cell),'raw_sha256':sha(raw)})
 output.mkdir();atlas=compile_cells(parts);path=output/'rivet_pistol.png';png(path,960,200,atlas)
 registration={'schema':'null-choir-rivet-native-v5-v1','status':'PENDING_NORMAL_IMPORT_FULL_HUD_AND_INDEPENDENT_REVIEW','source_sha256':SOURCE_SHA,'atlas_sha256':sha(path.read_bytes()),'rgba_sha256':sha(atlas),'pose_rgba_sha256':[sha(c) for c in parts],'runtime_contract':RUNTIME,'runtime_uri':'res://assets/art/weapons/native-v5/rivet_pistol.png','frames':rows,'gates_not_fabricated':['normal-import','full-hud','independent'],'original_v4_retained':True}
 (output/'registration.json').write_text(json.dumps(registration,indent=2)+'\n');return registration
