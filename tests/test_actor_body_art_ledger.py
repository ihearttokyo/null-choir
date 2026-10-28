"""Honest synthetic UNIT contracts + one real Worker input. No7fabricated proofs.
No native/GPU/Blender execution. No fullcohort positive is claimed or supplied.
"""
from pathlib import Path
import copy,hashlib,importlib.util,json,runpy,struct,unittest,zlib
from unittest.mock import patch
P=Path(__file__).resolve().parents[1]
W=P
spec=importlib.util.spec_from_file_location('actor_ledger',P/'tools/actor_body_art_ledger.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
H=v.helpers(W)
def historical_player_bytes():
 path=P/'source/art/rivet-forward-v5/provenance/player-before-v5.gd'
 data=path.read_bytes()
 if v.sha(data)!=v.WORKER['player']:raise AssertionError('Exact historical d3ff Player snapshot required')
 return data
def png(w,h,data):
 def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
 raw=b''.join(b'\0'+data[y*w*4:(y+1)*w*4] for y in range(h))
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
def synthetic_atlas():
 w,h=1024,640;data=bytearray(w*h*4)
 for f in range(40):
  row,col=divmod(f,8)
  for y in range(60,120):
   for x in range(60,71):
    i=((row*128+y)*w+col*128+x)*4;data[i:i+4]=bytes((f*5%256,32,48,255))
 return data
class Contract(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.synthetic=synthetic_atlas();cls.synthetic_png=png(1024,640,cls.synthetic)
  mapping=json.dumps({k:'res://assets/art/sprites/bodies-v1/'+k+'.png' for k in v.KINDS})
  # Honest in-memory GDScript lexical fixture, not an actual native/code receipt.
  cls.consumer='const BODY_ATLASES := '+mapping+'\nconst WINDUPS = '+json.dumps(v.WINDUPS)+'\nconst LATE = '+json.dumps(v.LATE)+\
   '\nfunc configure():\n sprite.texture = load(BODY_ATLASES[kind])\n sprite.hframes = 8\n sprite.vframes = 5\n var cell: int = 256 if kind in ["nursery_warden","choir_avatar"] else 128\n sprite.pixel_size = _profile.get("scale",3.8 if kind == "crawler" else 3.65)/float(cell)\n sprite.position.y = (cell/2.0-8)*sprite.pixel_size\n var rows := WorkerHitRegions.pose_rows(sprite.texture)\n if _worker_atlas_valid: sprite.vframes = rows\nfunc attack():\n attack_time = _profile.get("cooldown",0.8 if kind == "crawler" else 1.7 if kind == "worker" else 2.2)*(0.8 if phase > 0 else 1.0)\n'
  cls.runtime=cls.consumer.split('\n',1)[1]
  cls.worker_root=(P if (P/'game/assets/art/sprites/bodies-v1/worker.png').exists() else P/'tests/real-worker-input')
  cls.worker_available=(cls.worker_root/'game/assets/art/sprites/bodies-v1/worker.png').exists()
  cls.worker_rgba=H['png_rgba']((cls.worker_root/'game/assets/art/sprites/bodies-v1/worker.png').read_bytes())[1] if cls.worker_available else None
  cls.sidecar='[remap]\nimporter="texture"\ntype="CompressedTexture2D"\nuid="uid://syntheticfixture"\npath="res://.godot/imported/worker.png-'+('a'*32)+'.ctex"\n[deps]\nsource_file="res://assets/art/sprites/bodies-v1/worker.png"\ndest_files=["res://.godot/imported/worker.png-'+('a'*32)+'.ctex"]\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/size_limit=0\n'
  if cls.worker_available and (cls.worker_root/'game/assets/art/sprites/bodies-v1/worker.png.import').exists():cls.sidecar=(cls.worker_root/'game/assets/art/sprites/bodies-v1/worker.png.import').read_text()

 def test_synthetic_atlas_subcontract_positive(self):
  stats,_=v.atlas_stats(self.synthetic_png,'crawler',H);self.assertEqual(len(stats['cell_rgba_sha256']),40)
 def test_all_role_contract_dimensions_and_preserved_anchors(self):
  for kind in v.KINDS:
   c=v.contract(kind);cell=256 if kind in v.KINDS[-2:] else 128
   self.assertEqual(c['origin_px'],[cell//2,cell-8]);self.assertEqual(c['occupied_bottom'],cell-9)
   self.assertEqual(c['rows'],6 if kind=='worker' else 5)
 def test_real_worker_48_exact_cells(self):

  if not self.worker_available:self.skipTest('Actual Worker payload supplied only after integration; not fabricated')
  raw=(self.worker_root/'game/assets/art/sprites/bodies-v1/worker.png').read_bytes();stats,_=v.atlas_stats(raw,'worker',H)
  self.assertEqual(stats['rgba_sha256'],v.WORKER['rgba']);self.assertEqual(len(stats['cell_rgba_sha256']),48)
 def test_nonbinary_alpha_rejected(self):
  data=bytearray(self.synthetic);data[(60*1024+60)*4+3]=128
  with self.assertRaisesRegex(ValueError,'binary'):v.atlas_stats(png(1024,640,data),'crawler',H)
 def test_clipping_and_wrong_foot_rejected(self):
  data=bytearray(self.synthetic);data[(60*1024)*4:(60*1024)*4+4]=bytes((0,0,0,255))
  with self.assertRaisesRegex(ValueError,'unclipped'):v.atlas_stats(png(1024,640,data),'crawler',H)
  data=bytearray(self.synthetic)
  for x in range(60,71):data[(119*1024+x)*4+3]=0
  with self.assertRaisesRegex(ValueError,'foot'):v.atlas_stats(png(1024,640,data),'crawler',H)
 def test_duplicate_pose_rejected(self):
  data=bytearray(self.synthetic)
  for y in range(128):data[((128+y)*1024)*4:((128+y)*1024+128)*4]=data[y*1024*4:(y*1024+128)*4]
  with self.assertRaisesRegex(ValueError,'duplicate pose'):v.atlas_stats(png(1024,640,data),'crawler',H)
 def test_crc_dimensions_and_inflation_rejected(self):
  data=bytearray(self.synthetic_png);data[-1]^=1
  with self.assertRaises(ValueError):v.atlas_stats(bytes(data),'crawler',H)
  with self.assertRaisesRegex(ValueError,'dimensions'):v.atlas_stats(self.synthetic_png,'nursery_warden',H)
 def test_actual_import_settings_positive(self):
  uid,target=v.import_contract(self.sidecar,'worker',H);self.assertTrue(uid.startswith('uid://'));self.assertTrue(target.endswith('.ctex'))
 def test_import_active_not_commented_settings_and_duplicates(self):
  for bad in [self.sidecar.replace('process/fix_alpha_border=false','#process/fix_alpha_border=false'),self.sidecar.replace('mipmaps/generate=false','mipmaps/generate=true'),self.sidecar.replace('compress/mode=0','compress/mode=0\ncompress/mode=0')]:
   with self.assertRaises(ValueError):v.import_contract(bad,'worker',H)
 def test_import_uid_path_and_destination_rejected(self):
  for bad in [self.sidecar.replace('uid://','bad://'),self.sidecar.replace('res://assets/art/sprites/bodies-v1/worker.png','res://assets/art/sprites/worker.png'),self.sidecar.replace('worker.png-','wrong.png-')]:
   with self.assertRaises(ValueError):v.import_contract(bad,'worker',H)
 def test_active_consumer_map_positive(self):self.assertTrue(v.consumer_contract(self.consumer,H))
 def test_comment_or_string_dummy_map_not_binding(self):
  for bad in [self.consumer.replace('const BODY_ATLASES :=','#const BODY_ATLASES :='),self.consumer.replace('const BODY_ATLASES :=','var not_a_constant :=')]:
   with self.assertRaises(ValueError):v.consumer_contract(bad,H)
  dummy='var doc = """\nconst BODY_ATLASES := {}\n"""\n'+self.runtime
  with self.assertRaises(ValueError):v.consumer_contract(dummy,H)
 def test_active_fallback_duplicate_map_and_cadence_rejected(self):
  for bad in [self.consumer.replace('load(BODY_ATLASES[kind])','load(BODY_ATLASES.get(kind,"res://assets/art/sprites/worker.png"))'),self.consumer.replace('"crawler": "res://assets/art/sprites/bodies-v1/crawler.png"','"crawler":"x","crawler":"res://assets/art/sprites/bodies-v1/crawler.png"'),self.consumer.replace('"worker": 0.45','"worker": 0.46')]:
   with self.assertRaises(ValueError):v.consumer_contract(bad,H)
 def test_public_pending_wholecohort_always_fails(self):
  doc={'schema':'null-choir-eight-actor-ledger-v1','version':1,'status':'PENDING','actors':[{'kind':'worker'}]}
  with self.assertRaisesRegex(ValueError,'PENDING'):v.envelope(doc,H)
  doc['status']='QUALIFIED'
  with self.assertRaisesRegex(ValueError,'eight actual'):v.envelope(doc,H)
 def test_full_cohort_address_envelope_not_native_qualification(self):
  # Address-only objects, no payload/source/native/acceptance receipts fabricated.
  doc={'schema':'null-choir-eight-actor-ledger-v1','version':1,'status':'QUALIFIED','actors':[{'kind':k} for k in v.KINDS]}
  self.assertEqual(set(v.envelope(doc,H)),set(v.KINDS))
  for rows in [doc['actors'][:-1],doc['actors'][:-1]+[{'kind':'worker'}],doc['actors'][:-1]+[{'kind':'unknown'}]]:
   doc['actors']=rows
   with self.assertRaises(ValueError):v.envelope(doc,H)
 def test_no_private_paths_ratings_or_bool_version(self):
  base={'schema':'null-choir-eight-actor-ledger-v1','version':1,'status':'PENDING','actors':[]}
  for field in [{'note':'/Users/private/work/foo'},{'rating':9.9},{'review_score':5},{'note':'file:///tmp/private'}]:
   with self.assertRaises(ValueError):v.private_guard({**base,**field},H)
  base['version']=True
  with self.assertRaises(ValueError):v.envelope(base,H)
 def test_checked_ref_traversal_and_fake_source_open_not_accepted(self):
  with self.assertRaises(ValueError):v.checked(W,{'path':'../elsewhere.blend','sha256':'a'*64,'bytes':7},'source/art/worker.blend',H)
  source=(P/'tools/actor_body_art_ledger.py').read_text()
  self.assertIn("native.get('opened_saved_source') is True",source)
  self.assertIn("native.get('source_unchanged') is True",source)
  self.assertNotIn("startswith(b'BLENDER')",source)
 def test_exact_worker_real_mask_binding(self):
  if not self.worker_available:self.skipTest('Actual Worker payload absent; no fabricated qualification')
  root=self.worker_root;records={}
  for name,rel in {'manifest':'game/assets/art/regions/worker-clutch-v1.json','mask':'game/assets/art/regions/worker-clutch-v1.regions','helper':'game/scripts/worker_hit_regions.gd','player':'game/scripts/player.gd'}.items():
   target=root/rel;data=historical_player_bytes() if name=='player' else target.read_bytes();records[name]={'path':rel,'sha256':v.sha(data),'bytes':len(data)}
  _,rgba=H['png_rgba']((root/'game/assets/art/sprites/bodies-v1/worker.png').read_bytes())
  self.assertEqual(len(v.validate_worker_binding(root,records,rgba,v.WORKER['source'],H)),2)
 def test_worker_typed_schema_address_objects_and_source_negatives(self):
  self.test_exact_worker_real_mask_binding()
  root=self.worker_root;records={}
  for name,rel in {'manifest':'game/assets/art/regions/worker-clutch-v1.json','mask':'game/assets/art/regions/worker-clutch-v1.regions','helper':'game/scripts/worker_hit_regions.gd','player':'game/scripts/player.gd'}.items():
   p=root/rel;data=historical_player_bytes() if name=='player' else p.read_bytes();records[name]={'path':rel,'sha256':v.sha(data),'bytes':len(data)}
  original=json.loads((root/'game/assets/art/regions/worker-clutch-v1.json').read_text())
  _,rgba=H['png_rgba']((self.worker_root/'game/assets/art/sprites/bodies-v1/worker.png').read_bytes())
  mutations=[]
  bad=copy.deepcopy(original);bad['vframes']=6.0;mutations.append(bad)
  bad=copy.deepcopy(original);bad['frames'][0]['frame']=0.0;mutations.append(bad)
  bad=copy.deepcopy(original);bad['frames'][0]['labels']=True;mutations.append(bad)
  bad=copy.deepcopy(original);bad['authored_objects']=['headbox'];mutations.append(bad)
  bad=copy.deepcopy(original);bad['beauty_path']='res://assets/art/sprites/worker.png';mutations.append(bad)
  for bad in mutations:
   # These are historical Worker schema mutations, not a fresh v5-weapon audit.
   # The unchanged positive above still checks the ACTUAL current Player bridge.
   with patch.object(v,'resident_player_bytes',return_value=historical_player_bytes()),patch.object(v,'doc',return_value=bad),self.assertRaises(ValueError):v.validate_worker_binding(root,records,rgba,v.WORKER['source'],H)
  changed=bytearray(rgba);changed[0]^=1
  with self.assertRaises(ValueError):v.validate_worker_binding(root,records,bytes(changed),v.WORKER['source'],H)
  with self.assertRaises(ValueError):v.validate_worker_binding(root,records,rgba,'0'*64,H)
 def test_worker_public_guard_hashes_preserve_typed_negative_checks(self):
  if not self.worker_available:self.skipTest('Actual Worker helper/Player qualification absent')
  self.assertEqual(v.sha((self.worker_root/'game/scripts/worker_hit_regions.gd').read_bytes()),v.WORKER['helper'])
  old=historical_player_bytes();self.assertEqual(v.sha(old),v.WORKER['player'])
  current=(self.worker_root/'game/scripts/player.gd').read_bytes()
  self.assertEqual(H['validate_pistol_player_compatibility'](self.worker_root,current),old)
 def test_current_Player_qualified_consumption_and_foreign_negative(self):
  current=(P/'game/scripts/player.gd').read_bytes()
  self.assertEqual(H['validate_pistol_player_compatibility'](P,current),historical_player_bytes())
  foreign=current.replace(b'native-v5/rivet_pistol',b'native-v6/rivet_pistol')
  with self.assertRaises(ValueError):H['validate_pistol_player_compatibility'](P,foreign)
 def test_historical_v5_one_byte_alias_stays_exact(self):
  before=historical_player_bytes();legacy=before.replace(b'"asset":"native-v4/rivet_pistol"',b'"asset":"native-v5/rivet_pistol"',1)
  self.assertEqual(v.sha(legacy),'0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7')
  guard=H['v5_guard'](P);descriptor=json.loads((P/'source/art/rivet-forward-v5/ledger.json').read_text())['player_compatibility']
  self.assertEqual(guard['normalize_player'](P,legacy,descriptor),before)
  with self.assertRaises(ValueError):guard['normalize_player'](P,legacy.replace(b'native-v5/rivet_pistol',b'native-v6/rivet_pistol'),descriptor)
 def actual_worker_raw_case(self,f=0):
  if not self.worker_available:self.skipTest('Actual Worker payload absent; no synthetic source qualification')
  con=v.contract('worker');pose=con['poses'][f//8];name='raw-'+pose+'-'+str(f%8).zfill(2)+'.png'
  path=self.worker_root/'source/art/bodies-v1/worker/frames'/name
  if not path.exists():path=P/'tests/real-worker-input/source/art/bodies-v1/worker/frames'/name
  if not path.exists():self.skipTest('Actual native raw Worker inputs not supplied; never fabricate')
  raw=v.pixels(path.read_bytes(),[128,128],H,name)
  compiled=v.cell_bytes(self.worker_rgba,1024,128,f)
  box=v.bbox(raw,128);frame={'frame':f,'pose':pose,'direction':f%8,'raw_bbox':box,'vertical_shift':119-box[3],'raw_rgba_sha256':v.sha(raw),'cell_rgba_sha256':v.sha(compiled)}
  return bytearray(raw),compiled,con,frame
 def test_actual_worker_all48_raw_quant5bit_to_accepted_beauty(self):
  for f in range(48):
   raw,compiled,con,frame=self.actual_worker_raw_case(f);v.validate_raw_frame(raw,compiled,con,frame,f)
 def test_quant5bit_lookup_matches_original_exporter_all_byte_values(self):
  self.assertEqual(v.BEAUTY_QUANT5,tuple(min(255,round((channel/255)*31)*8) for channel in range(256)))
 def test_opaque_raw_magenta_with_updated_own_hash_rejected(self):
  raw,compiled,con,frame=self.actual_worker_raw_case();i=next(i for i in range(0,len(raw),4) if raw[i+3]==255)
  raw[i:i+3]=bytes((255,0,255));frame['raw_rgba_sha256']=v.sha(raw)
  with self.assertRaisesRegex(ValueError,'raw RGBA -> beauty'):v.validate_raw_frame(raw,compiled,con,frame,0)
 def test_raw_alpha_hole_and_nonbinary_with_updated_hash_rejected(self):
  original,compiled,con,frame=self.actual_worker_raw_case();i=next(i for i in range(0,len(original),4) if original[i+3]==255)
  for alpha in [0,128]:
   raw=bytearray(original);raw[i+3]=alpha;changed=copy.deepcopy(frame);changed['raw_rgba_sha256']=v.sha(raw)
   with self.assertRaises(ValueError):v.validate_raw_frame(raw,compiled,con,changed,0)
 def test_declared_raw_shift_color_and_frame_address_negatives(self):
  raw,compiled,con,frame=self.actual_worker_raw_case()
  changed=copy.deepcopy(frame);changed['vertical_shift']+=1
  with self.assertRaisesRegex(ValueError,'identity'):v.validate_raw_frame(raw,compiled,con,changed,0)
  changed=copy.deepcopy(frame);changed['direction']=1
  with self.assertRaisesRegex(ValueError,'identity'):v.validate_raw_frame(raw,compiled,con,changed,0)
  colors=bytearray(compiled);i=next(i for i in range(0,len(colors),4) if colors[i+3]==255);colors[i]=(colors[i]+8)%256;changed=copy.deepcopy(frame);changed['cell_rgba_sha256']=v.sha(colors)
  with self.assertRaisesRegex(ValueError,'raw RGBA -> beauty'):v.validate_raw_frame(raw,bytes(colors),con,changed,0)
 def test_only_approved_quantization_and_transparent_rgb_are_allowed(self):
  raw,compiled,con,frame=self.actual_worker_raw_case();changed=False
  for i in range(0,len(raw),4):
   if raw[i+3]!=255:continue
   for value in range(max(0,raw[i]-2),min(255,raw[i]+2)+1):
    if value!=raw[i] and v.BEAUTY_QUANT5[value]==v.BEAUTY_QUANT5[raw[i]]:raw[i]=value;changed=True;break
   if changed:break
  self.assertTrue(changed);i=next(i for i in range(0,len(raw),4) if raw[i+3]==0);raw[i:i+3]=bytes((255,0,255))
  frame['raw_rgba_sha256']=v.sha(raw);v.validate_raw_frame(raw,compiled,con,frame,0)
 def test_exact_raw_registration_no_gamma_or_unquantized_shortcut(self):
  raw,compiled,con,frame=self.actual_worker_raw_case();c=128;unquantized=bytearray(len(raw));linear=bytearray(len(raw))
  for y in range(c):
   dest=y+frame['vertical_shift']
   if not 0<=dest<c:continue
   for x in range(c):
    i=(y*c+x)*4;o=(dest*c+x)*4
    if raw[i+3]!=255:continue
    unquantized[o:o+4]=raw[i:i+4]
    values=[]
    for b in raw[i:i+3]:
     s=b/255;channel=s/12.92 if s<=.04045 else ((s+.055)/1.055)**2.4;values.append(min(255,round(channel*31)*8))
    linear[o:o+4]=bytes(values+[255])
  for wrong in [unquantized,linear]:
   changed=copy.deepcopy(frame);changed['cell_rgba_sha256']=v.sha(wrong)
   with self.assertRaisesRegex(ValueError,'raw RGBA -> beauty'):v.validate_raw_frame(raw,bytes(wrong),con,changed,0)
 def public_bridge_case(self,kind='worker'):
  root=P if (P/'source/art/bodies-v1/packet-three-actors.json').exists() else P/'tests/real-public-source-input'
  fragment=root/'source/art/bodies-v1/packet-three-actors.json'
  if not fragment.exists():self.skipTest('Actual public-source bridge fixtures absent; never fabricate native proof')
  e=next(e for e in json.loads(fragment.read_text())['actors'] if e['kind']==kind);source=(root/e['source_blend']['path']).read_bytes();native=v.receipt(root,e,'source-native',kind,H)
  common={k:native[k] for k in ['source_blend_sha256','generator_sha256','atlas_sha256','rgba_sha256','cell_rgba_sha256']}
  return root,e,source,native,common,v.contract(kind)
 def altered_public_doc(self,target,change):
  original=v.doc
  def read(root,record,expected,h):
   d=original(root,record,expected,h)
   if expected.endswith('/'+target):d=copy.deepcopy(d);change(d)
   return d
  return patch.object(v,'doc',side_effect=read)
 def retained_independent(self,root,e,kind):
  # Immutable pre-integration packet approval, not final runtime acceptance.
  grade=v.doc(root,e['independent'],v.FAMILY+kind+'/proof/independent.json',H)
  expected={'schema':'null-choir-actor-independent-v1','status':'PASS','evidence_class':'independent-review-of-actual-native','review_role':'independent','actor_kind':kind,'source_blend_sha256':e['source_blend']['sha256'],'atlas_sha256':e['output']['sha256'],'reviewed_cell_sha256':e['output']['cell_rgba_sha256']}
  self.assertTrue(all(v.same(grade.get(k),value) for k,value in expected.items()))
  self.assertEqual(grade.get('actual_context_sha256'),e['actual-context']['sha256'])
  return grade
 def test_actual_three_UI_bridges_and_original_acceptance(self):
  for kind in ['worker','crawler','brute']:
   root,e,source,native,common,con=self.public_bridge_case(kind);authored,bridge=v.validate_public_source_bridge(root,e,kind,source,native,common,con,H)
   self.assertNotEqual(authored,v.sha(source));grade=self.retained_independent(root,e,kind);v.validate_bridge_acceptance(root,e,kind,grade,bridge,authored,common,H)
 def test_worker_public_identity_does_not_relabel_mask_source(self):
  root,e,source,native,common,con=self.public_bridge_case();authored,_=v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H)
  self.assertEqual(authored,v.WORKER['source']);self.assertNotEqual(authored,v.sha(source))
  if not self.worker_available:self.skipTest('Actual mask unavailable, not fabricated')
  records={}
  for name,rel in {'manifest':'game/assets/art/regions/worker-clutch-v1.json','mask':'game/assets/art/regions/worker-clutch-v1.regions','helper':'game/scripts/worker_hit_regions.gd','player':'game/scripts/player.gd'}.items():
   p=self.worker_root/rel;data=historical_player_bytes() if name=='player' else p.read_bytes();records[name]={'path':rel,'sha256':v.sha(data),'bytes':len(data)}
  # The mask's original/private-versus-public source identity is independent
  # of the later pistol-only URI. Bind its exact historical Player snapshot.
  with patch.object(v,'resident_player_bytes',return_value=historical_player_bytes()):
   self.assertEqual(len(v.validate_worker_binding(self.worker_root,records,self.worker_rgba,authored,H)),2)
   with self.assertRaises(ValueError):v.validate_worker_binding(self.worker_root,records,self.worker_rgba,v.sha(source),H)
 def test_public_UI_payload_and_layout_corruption_rejected(self):
  _,_,source,_,_,_=self.public_bridge_case();fields,_=v.public_ui_field(source);start,end=fields['absolute_field_range_half_open']
  for index,value in [(start,ord('x')),(end-1,1),(0,ord('X'))]:
   wrong=bytearray(source);wrong[index]=value
   with self.assertRaises(ValueError):v.public_ui_field(bytes(wrong))
  wrong=bytearray(source);wrong[fields['BHead_header_offset']+4:fields['BHead_header_offset']+8]=struct.pack('<I',0)
  with self.assertRaises(ValueError):v.public_ui_field(bytes(wrong))
 def test_bridge_unknown_field_range_fieldname_and_digest_rejected(self):
  args=self.public_bridge_case();root,e,source,native,common,con=args
  mutations=[lambda d:d.update(unknown_exception=True),lambda d:d['byte_patch_proof'].update(field='other[1282]'),lambda d:d['byte_patch_proof'].update(field_bytes=1283),lambda d:d['byte_patch_proof'].update(DNA_index=850),lambda d:d['byte_patch_proof'].update(absolute_field_range_half_open=[0,1282]),lambda d:d['byte_patch_proof'].update(changed_offsets=[0]),lambda d:d['byte_patch_proof'].update(extra_field='allowed'),lambda d:d.update(decoded_non_UI_sha256='0'*64),lambda d:d['decoded_non_UI_digest_method'].update(normalization='ignore_any_DATA'),lambda d:d['decoded_non_UI_digest_method'].update(original_normalized_sha256='0'*64)]
  for change in mutations:
   with self.altered_public_doc('public-master-bridge.json',change),self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H)
 def test_arbitrary_non_UI_source_change_even_updated_blob_hash_rejected(self):
  root,e,source,native,common,con=self.public_bridge_case();wrong=bytearray(source);wrong[-1]^=1;wrong=bytes(wrong)
  e=copy.deepcopy(e);native=copy.deepcopy(native);common=dict(common);digest=v.sha(wrong)
  e['source_blend']['sha256']=digest;native['source_blend_sha256']=digest;common['source_blend_sha256']=digest
  with self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',wrong,native,common,con,H)
 def test_original_public_hash_swap_and_missing_bridge_rejected(self):
  root,e,source,native,common,con=self.public_bridge_case()
  for changed in [lambda n:n.update(source_blend_sha256=v.WORKER['source']),lambda n:n.update(original_authored_source_sha256=v.sha(source)),lambda n:n.update(public_rendered_frame_count=48),lambda n:n.update(public_RGBA_reproduction_performed=True)]:
   n=copy.deepcopy(native);changed(n)
   with self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',source,n,common,con,H)
  e=copy.deepcopy(e);e.pop('public_master_bridge')
  with self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H)
 def test_native_copy_parity_flags_and_hashlinks_required(self):
  root,e,source,native,common,con=self.public_bridge_case()
  mutations=[lambda d:d.update(opened_public_source=False),lambda d:d.update(opened_original_source=False),lambda d:d.update(source_data_identical_to_original=False),lambda d:d.update(decoded_non_UI_bytes_identical=False),lambda d:d.update(public_source_sha256=v.WORKER['source']),lambda d:d.update(original_source_sha256=v.sha(source)),lambda d:d.update(ui_bridge_sha256='0'*64),lambda d:d.update(original_source_native_proof_sha256='0'*64),lambda d:d.update(source_resaved=True),lambda d:d.update(rendered_frame_count=48)]
  for change in mutations:
   with self.altered_public_doc('public-native-open.json',change),self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H)
 def test_original_source_reproduction_not_substituted(self):
  root,e,source,native,common,con=self.public_bridge_case()
  mutations=[lambda d:d.update(source_blend_sha256=v.sha(source)),lambda d:d.update(opened_saved_source=False),lambda d:d.update(rendered_frame_count=0),lambda d:d.update(rgba_sha256='0'*64),lambda d:d.update(evidence_class='synthetic'),lambda d:d.update(verified_editable_mesh_objects=True)]
  for change in mutations:
   with self.altered_public_doc('source-native-original.json',change),self.assertRaises(ValueError):v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H)
 def test_retained_independent_source_bridge_links_required(self):
  root,e,source,native,common,con=self.public_bridge_case();authored,bridge=v.validate_public_source_bridge(root,e,'worker',source,native,common,con,H);grade=self.retained_independent(root,e,'worker')
  for change in [lambda d:d.update(original_reviewed_source_sha256=v.sha(source)),lambda d:d.update(new_independent_review_of_public_UI_copy_performed=True),lambda d:d.update(public_master_bridge={}),lambda d:d.update(original_independent_acceptance={})]:
   g=copy.deepcopy(grade);change(g)
   with self.assertRaises(ValueError):v.validate_bridge_acceptance(root,e,'worker',g,bridge,authored,common,H)
 def test_unchanged_direct_source_route_has_no_generic_exception(self):
  source=b'honest address-only unit bytes, NOT a native source fixture';n={'source_blend_sha256':v.sha(source)};common=dict(n)
  self.assertEqual(v.validate_public_source_bridge(P,{},'worker',source,n,common,v.contract('worker'),H),(v.sha(source),None))
  n['public_master_bridge']={}
  with self.assertRaises(ValueError):v.validate_public_source_bridge(P,{},'worker',source,n,common,v.contract('worker'),H)
 def test_no_partial_bypass_and_legacy119140_pins(self):
  source=(P/'tools/actor_body_art_ledger.py').read_text();self.assertNotIn('allow_partial',source)
  pin=json.loads((P/'source/art/bodies-v1/legacy-140.json').read_text());self.assertEqual(len(pin['files']),140);self.assertEqual(pin['catalog_entries'],119)
  self.assertEqual(v.sha((P/'source/art/bodies-v1/legacy-140.json').read_bytes()),v.PINSET_SHA)

class FinalConsumerQualification(unittest.TestCase):
 """Actual final idle inputs; source-art matrices and555runtime remain separate evidence."""
 @classmethod
 def setUpClass(cls):
  cls.ledger=json.loads((P/v.LEDGER).read_text());cls.entries={e['kind']:e for e in cls.ledger['actors']}
  cls.h=v.helpers(P)
 def args(self,kind='worker'):
  e=copy.deepcopy(self.entries[kind]);c=json.loads((P/e['actual-context']['path']).read_text());g=json.loads((P/e['independent']['path']).read_text())
  common={k:e['output'][k] for k in ['rgba_sha256','cell_rgba_sha256']};common.update(atlas_sha256=e['output']['sha256'],source_blend_sha256=e['source_blend']['sha256'],generator_sha256=e['generator']['sha256'])
  return [P,e,kind,c,g,common,v.contract(kind),self.h]
 def test_all8_real_final_idle_contexts(self):
  for kind in v.KINDS:self.assertTrue(v.validate_final_context(*self.args(kind)))
 def test_retained_fullmatrix_required(self):
  a=self.args();a[3]['retained_source_art_qualification']={}
  with self.assertRaisesRegex(v.ContractError,'retained fullmatrix'):v.validate_final_context(*a)
 def test_current_normal_constructor_source_uid_and_scope_guards(self):
  for key,value in [('consumer_sha256',v.OLD_CONTEXT_CONSUMER_SHA),('resource_class','ImageTexture'),('normal_import_uid','uid://invented'),('new_fullmatrix_context_rendered',True),('sampled_Metal_RSS_bytes',0)]:
   a=self.args();a[3][key]=value
   with self.assertRaises(v.ContractError):v.validate_final_context(*a)
 def test_wrong_count_and_new_art_grade_rejected(self):
  a=self.args();a[3]['visible_changed_pixels']+=1
  with self.assertRaises(v.ContractError):v.validate_final_context(*a)
  a=self.args();a[4]['new_independent_art_grade_performed']=True
  with self.assertRaises(v.ContractError):v.validate_final_context(*a)
 def test_fixed_final_alias_no_old_context_fallback(self):
  e=copy.deepcopy(self.entries['worker']);e['actual-context']=json.loads((P/e['actual-context']['path']).read_text())['retained_source_art_qualification']['actual-context']
  with self.assertRaises(v.ContractError):v.receipt(P,e,'actual-context','worker',self.h)
 def test_native_map_numbers_exact_bounded_not_bool_coercion(self):
  e={'id':'actor','kind':'worker','cell':[8.5,23.5],'yaw':73};a=copy.deepcopy(e);a['yaw']=73.0
  self.assertTrue(v.native_report_spawn_same(a,e))
  for key,value in [('yaw',True),('yaw',73.00001),('yaw',float('nan')),('yaw',float('inf')),('cell',[8.5]),('cell',[True,23.5]),('unknown',1)]:
   bad=copy.deepcopy(a);bad[key]=value;self.assertFalse(v.native_report_spawn_same(bad,e))
 def test_wall_only_native_and_invisible_actor_rejected(self):
  old=v.doc
  for mutation in ['wall','invisible','override']:
   def altered(root,record,expected,h):
    value=old(root,record,expected,h)
    if expected.endswith('final-context-native-report.json'):
     value=copy.deepcopy(value)
     if mutation=='wall':value['collision_negative_control']['blocked']=False
     if mutation=='invisible':value['views'][0]['stable_opaque_source_witnesses']=0
     if mutation=='override':value['views'][0]['no_ImageTexture_override']=False
    return value
   with patch.object(v,'doc',altered):
    with self.assertRaises(v.ContractError):v.validate_final_context(*self.args())
 def test_rehashed_independent_context_join_rejected(self):
  old=v.doc
  def altered(root,record,expected,h):
   value=old(root,record,expected,h)
   if expected.endswith('/independent-context-review.json'):
    value=copy.deepcopy(value);next(r for r in value['roles'] if r['kind']=='worker')['view_sha256']='0'*64
   return value
  with patch.object(v,'doc',altered):
   with self.assertRaises(v.ContractError):v.validate_final_context(*self.args())
 def test_actual_functional555_scope_distinct_from_old_views(self):
  self.assertTrue(v.validate_final_runtime(P,self.ledger,self.entries,self.h))
  old=v.doc
  def altered(root,record,expected,h):
   value=old(root,record,expected,h)
   if expected.endswith('/functional-runtime.json'):value=copy.deepcopy(value);value['old_eight_context_images_qualified']=True
   return value
  with patch.object(v,'doc',altered):
   with self.assertRaises(v.ContractError):v.validate_final_runtime(P,self.ledger,self.entries,self.h)


if __name__=='__main__':unittest.main(verbosity=2)
