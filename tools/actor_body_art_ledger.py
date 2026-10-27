"""Separate strict8-actor replacement ledger. Read-only; NEVER executes native tools.

Reuses canonical PNG/path/duplicate-JSON/Godot-import parsing helpers. Receipts
bind exact public blobs; they are not authentication of an actual run or art grade.
No partial/cohort bypass. Missing seven actors means FAIL, not Worker-only PASS.
"""
from __future__ import annotations
import argparse,hashlib,json,math,os,re,runpy,stat,struct,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LEDGER='source/art/bodies-v1/ledger.json'
FAMILY='source/art/bodies-v1/'
GAME='game/assets/art/sprites/bodies-v1/'
KINDS=('crawler','worker','caster','brute','guardian','summoner','nursery_warden','choir_avatar')
BASE_POSES=['idle','walk_a','walk_b','attack','dead']
SPANS=dict(zip(KINDS,(3.8,3.65,3.65,4.4,4.7,5.6,7.3,7.6)))
WINDUPS=dict(zip(KINDS,(.25,.45,.70,.80,.75,1.20,1.00,1.05)))
LATE={'brute':{'hp':210,'speed':3.1,'radius':.62,'height':3.3,'scale':4.4,'cooldown':3.0,'recovery':.8},'guardian':{'hp':260,'speed':2.0,'radius':.65,'height':3.7,'scale':4.7,'cooldown':2.6,'recovery':.9},'summoner':{'hp':150,'speed':0.0,'radius':.45,'height':4.2,'scale':5.6,'cooldown':3.8,'recovery':.7},'nursery_warden':{'hp':1200,'speed':2.0,'radius':1.0,'height':5.4,'scale':7.3,'cooldown':3.2,'recovery':.9},'choir_avatar':{'hp':1600,'speed':1.6,'radius':1.0,'height':5.6,'scale':7.6,'cooldown':3.0,'recovery':1.1}}
LEGACY_SHA='c9d03e761c85cb24cf2aeb711e04d255201ce85fb08e546e0184834cd8c3a928'
PINSET_SHA='500bcebfb8ceb3720b159d26d18f96ec331ce0a10bf2fc905b6a0a6f8f6812ae'
WORKER={'atlas':'b42bdcd0e00fe8b2d759241a9a8e3e8780da0eb8a70e01e670e4c4341d49ec52','rgba':'4ee502539f3f3a98de2022e5904100468bd53eaa5884cbacc0005575fb7aff98','source':'ff045773eeb053e030f17bd6007e63ec09afb9329d2ed4e40cb6c60f277ad906','generator':'0a4d74c1a0c7a1f309461e3978a37b81d6898669bba99a1eee0149c1fb3525d4','mask':'e9cc92283fde8ec89340e9f3107c03ee10b32fe38fb5df8ccaf146afab53d1d5','helper':'563f0440b8b00b5469ae450b894402a55a9a144e1015156beb15afe6517f0f67','player':'d3ff20a302f8ead0f6808683e6ccdd9a2b3f10f711b019fe9808a788faef7bff'}
HELPER_PINS={'tools/rivet_forward_art_ledger.py': '5e67ddae230d292b252ca284e82920dba220b067d3c1c341413fb8d4ff722196', 'source/art/weapon-raster-v3/validate_ledger.py': 'e72faeb597885d927374c73100e8608d2c9d8511730d2c909fee2f4e4d1fcf00'}
class ContractError(ValueError):pass
def fail(s):raise ContractError(s)
def require(ok,s):
 if not ok:fail(s)
def sha(b):return hashlib.sha256(b).hexdigest()
def same(a,b):
 if type(a) is not type(b):return False
 if isinstance(b,dict):return a.keys()==b.keys() and all(same(a[k],v) for k,v in b.items())
 if isinstance(b,list):return len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
 return a==b
def digest(v):return isinstance(v,str) and bool(re.fullmatch('[0-9a-f]{64}',v))
def helpers(root):
 # Execute ONLY the exact trusted pure helper generation, never an actor generator.
 root=Path(root).absolute();require(not any(p.is_symlink() for p in (root,*root.parents)),'symlinked helper root')
 for relative,expected in HELPER_PINS.items():
  p=root/relative;require(not any(a.is_symlink() for a in (p,*p.parents)),'helper symlink')
  info=p.lstat();require(stat.S_ISREG(info.st_mode) and not getattr(info,'st_flags',0)&0x40000000 and sha(p.read_bytes())==expected,'trusted canonical helper changed/nonresident')
 return runpy.run_path(str(root/'tools/rivet_forward_art_ledger.py'))
def private_guard(obj,h):
 h['reject_private'](obj)
 if isinstance(obj,dict):
  for k,v in obj.items():
   require(not re.search(r'(?:score|rating|rubric)',str(k),re.I),'private review numbers/keys forbidden in public contract')
   private_guard(v,h)
 elif isinstance(obj,list):
  for v in obj:private_guard(v,h)
def checked(root,record,expected,h):
 require(isinstance(record,dict) and record.get('path')==expected and digest(record.get('sha256')),'exact public path/hash record: '+expected)
 p=h['safe_rel'](Path(root),expected,label='actor reference',allowed_roots={'source','game','tools'})
 s=p.lstat();require(stat.S_ISREG(s.st_mode) and not getattr(s,'st_flags',0)&0x40000000,'missing/nonresident file (no hydration): '+expected)
 data=p.read_bytes();require(sha(data)==record['sha256'],'blob SHA mismatch: '+expected)
 require(type(record.get('bytes')) is int and record['bytes']==len(data) and len(data)>0,'explicit exact blob byte count: '+expected)
 return p,data
def doc(root,record,expected,h):
 p,_=checked(root,record,expected,h);value=h['read_json'](p);require(isinstance(value,dict),'JSON document must be dictionary: '+expected);private_guard(value,h);return value

def contract(kind):
 require(kind in KINDS,'unknown actor')
 c=256 if kind in KINDS[-2:] else 128;poses=BASE_POSES+(['clutch_vent'] if kind=='worker' else [])
 return {'columns':8,'rows':len(poses),'cell_size':[c,c],'dimensions':[c*8,c*len(poses)],'poses':poses,'origin_px':[c//2,c-8],'occupied_bottom':c-9,'pixel_size':SPANS[kind]/c,'sprite_offset_y':(c/2-8)*(SPANS[kind]/c),'filter':'nearest','shaded':True,'billboard':'enabled','alpha_cut':'discard'}
def pixels(data,expected,h,label):
 require(len(data)<16*1024**2 and data[:8]==b'\x89PNG\r\n\x1a\n' and len(data)>=33,'PNG size/header: '+label)
 require(list(struct.unpack('>II',data[16:24]))==expected,'PNG declared dimensions: '+label)
 # Bound inflation BEFORE invoking the retained full CRC/filter parser.
 pos=8;packed=bytearray()
 while pos+12<=len(data):
  n=int.from_bytes(data[pos:pos+4],'big');require(pos+12+n<=len(data),'PNG truncated chunk')
  if data[pos+4:pos+8]==b'IDAT':packed.extend(data[pos+8:pos+8+n])
  pos+=12+n
 maximum=expected[1]*(1+expected[0]*4);dec=zlib.decompressobj();raw=dec.decompress(packed,maximum+1)
 require(len(raw)==maximum and dec.eof and not dec.unconsumed_tail and not dec.unused_data,'PNG bounded exact inflation')
 dims,rgba=h['png_rgba'](data,label=label);require(list(dims)==expected,'PNG dimensions')
 return rgba
def cell_bytes(rgba,width,c,frame):
 row,column=divmod(frame,8)
 return b''.join(rgba[((row*c+y)*width+column*c)*4:((row*c+y)*width+(column+1)*c)*4] for y in range(c))
def bbox(rgba,c):
 points=[(x,y) for y in range(c) for x in range(c) if rgba[(y*c+x)*4+3]]
 require(points,'empty actor cell')
 return [min(x for x,y in points),min(y for x,y in points),max(x for x,y in points),max(y for x,y in points)]

# Exact approved original BEAUTY route: Blender PNG byte samples loaded as
# normalized channels, round(channel*31)*8, binary alpha, fixed-foot shift.
# Integer LUT is equivalent to Python round(v/255*31): integer v has no .5 tie.
# Standard PNG transfer was already applied by the renderer; do NOT linearize
# sRGB again. Actual frozen Worker native raw -> beauty positive covers all48.
BEAUTY_QUANT5=tuple(min(255,((62*v+255)//510)*8) for v in range(256))
def validate_raw_frame(raw,compiled,con,frame,f):
 c=con['cell_size'][0]
 require(len(raw)==len(compiled)==c*c*4,'exact raw/beauty frame byte length')
 box=bbox(raw,c)
 require(set(raw[3::4])=={0,255} and box[0]>0 and box[1]>0 and box[2]<c-1 and box[3]<c-1,'unclipped binary native raw coverage')
 shift=con['occupied_bottom']-box[3];aligned=bytearray(len(raw))
 for y in range(c):
  dest=y+shift
  if not 0<=dest<c:
   require(not any(raw[y*c*4+3:(y+1)*c*4:4]),'clipped raw source at registration')
   continue
  for x in range(c):
   i=(y*c+x)*4;o=(dest*c+x)*4
   if raw[i+3]>=128:aligned[o:o+4]=bytes((BEAUTY_QUANT5[raw[i]],BEAUTY_QUANT5[raw[i+1]],BEAUTY_QUANT5[raw[i+2]],255))
 require(bytes(aligned)==compiled,'raw RGBA -> beauty must match exact approved quant5bit/alpha/footshift transform')
 expected={'frame':f,'pose':con['poses'][f//8],'direction':f%8,'raw_bbox':box,'vertical_shift':shift,'raw_rgba_sha256':sha(raw),'cell_rgba_sha256':sha(compiled)}
 require(all(same(frame.get(k),v) for k,v in expected.items()),'raw/native frame identity mismatch')
 return expected

def atlas_stats(data,kind,h):
 con=contract(kind);c=con['cell_size'][0];rgba=pixels(data,con['dimensions'],h,kind)
 require(set(rgba[3::4])=={0,255},'binary alpha required')
 cells=[];boxes=[]
 for f in range(con['rows']*8):
  raw=cell_bytes(rgba,con['dimensions'][0],c,f);box=bbox(raw,c)
  require(sum(a==255 for a in raw[3::4])>=80,'cell occupancy')
  require(box[0]>0 and box[1]>0 and box[2]<c-1 and box[3]==con['occupied_bottom'],'unclipped cell / exact occupied-foot registration')
  cells.append(sha(raw));boxes.append(box)
 for d in range(8):require(len(set(cells[d::8]))==con['rows'],'duplicate pose in directional column')
 return {'rgba_sha256':sha(rgba),'cell_rgba_sha256':cells,'cell_bbox':boxes},rgba

def import_contract(text,kind,h):
 sections=h['active_import_assignments'](text)
 def val(section,key):
  raw=sections[section].get(key);require(raw is not None,'missing import setting '+key)
  if raw.startswith('PackedStringArray(') and raw.endswith(')'):raw='['+raw[len('PackedStringArray('):-1]+']'
  return json.loads(raw,object_pairs_hook=h['HELPERS']['_pairs'])
 uri='res://assets/art/sprites/bodies-v1/'+kind+'.png'
 expected={'remap':{'importer':'texture','type':'CompressedTexture2D'},'deps':{'source_file':uri},'params':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':False,'process/premult_alpha':False,'process/size_limit':0}}
 for section,keys in expected.items():
  for k,v in keys.items():require(same(val(section,k),v),'active import contract '+k)
 uid=val('remap','uid');target=val('remap','path')
 require(isinstance(uid,str) and bool(re.fullmatch(r'uid://[a-z0-9]+',uid)),'actual Godot UID')
 require(isinstance(target,str) and bool(re.fullmatch(r'res://\.godot/imported/'+re.escape(kind)+r'\.png-[0-9a-f]{32}\.ctex',target)),'exact imported destination')
 require(same(val('deps','dest_files'),[target]),'import destination identity')
 return uid,target

def comment_free(text):
 out=[];quoted=False;escaped=False;comment=False
 for ch in text:
  if comment:
   if ch=='\n':comment=False;out.append(ch)
   continue
  if escaped:out.append(ch);escaped=False;continue
  if quoted and ch=='\\':out.append(ch);escaped=True;continue
  if ch=='"':quoted=not quoted
  if ch=='#' and not quoted:comment=True;continue
  out.append(ch)
 return ''.join(out)
def code_mask(text):
 # Preserve offsets/newlines while hiding quoted strings, including multiline
 # strings, from declaration/assignment discovery. JSON literal decoding still
 # uses original comment-free text after a verified active declaration.
 out=list(text);i=0
 while i<len(text):
  if text[i] not in [chr(34),chr(39)]:i+=1;continue
  quote=text[i];triple=text.startswith(quote*3,i);endmark=quote*3 if triple else quote
  start=i;i+=len(endmark)
  while i<len(text):
   if text[i]=='\\':i+=2;continue
   if text.startswith(endmark,i):i+=len(endmark);break
   i+=1
  for j in range(start,min(i,len(text))):
   if out[j]!='\n':out[j]=' '
 return ''.join(out)
def literal_constant(text,name,h):
 matches=list(re.finditer(r'(?m)^const\s+'+re.escape(name)+r'\s*(?::=|=)\s*',code_mask(text)));require(len(matches)==1,'one active named '+name+' constant required')
 value,_=json.JSONDecoder(object_pairs_hook=h['HELPERS']['_pairs']).raw_decode(text[matches[0].end():]);return value

def consumer_contract(text,h):
 text=comment_free(text)
 mapping=literal_constant(text,'BODY_ATLASES',h)
 require(same(mapping,{k:'res://assets/art/sprites/bodies-v1/'+k+'.png' for k in KINDS}),'exact eight-entry active BODY_ATLASES mapping, no legacy fallback')
 masked=code_mask(text);start=re.search(r'(?m)^func configure\(',masked);require(start is not None,'actual configure function missing')
 end=re.search(r'(?m)^func ',masked[start.end():]);stop=start.end()+end.start() if end else len(text)
 configure=text[start.start():stop]
 hits=list(re.finditer(r'(?m)^\s*sprite\.texture\s*=([^\n]+)',code_mask(configure)))
 assignments=[configure[m.start(1):m.end(1)] for m in hits]
 require(len(assignments)==1 and re.sub(r'\s+','',assignments[0])=='load(BODY_ATLASES[kind])','actual configure must use BODY_ATLASES[kind], not comment/dummy map/fallback')
 require(same(literal_constant(text,'WINDUPS',h),WINDUPS) and same(literal_constant(text,'LATE',h),LATE),'combat numeric profiles/windups changed')
 compact=re.sub(r'\s+','',text)
 for token in ['sprite.hframes=8','sprite.vframes=5','varcell:int=256ifkindin["nursery_warden","choir_avatar"]else128','sprite.pixel_size=_profile.get("scale",3.8ifkind=="crawler"else3.65)/float(cell)','sprite.position.y=(cell/2.0-8)*sprite.pixel_size','varrows:=WorkerHitRegions.pose_rows(sprite.texture)','if_worker_atlas_valid:sprite.vframes=rows','attack_time=_profile.get("cooldown",0.8ifkind=="crawler"else1.7ifkind=="worker"else2.2)*(0.8ifphase>0else1.0)']:
  require(token in compact,'unchanged actual layout/scale/cadence seam missing: '+token)
 return True

def envelope(value,h):
 require(isinstance(value,dict),'ledger must be dictionary')
 private_guard(value,h)
 require(value.get('schema')=='null-choir-eight-actor-ledger-v1' and type(value.get('version')) is int and value['version']==1,'ledger schema')
 require(value.get('status')=='QUALIFIED','PENDING whole cohort: no partial acceptance')
 entries=value.get('actors');require(isinstance(entries,list) and len(entries)==8 and all(isinstance(a,dict) for a in entries),'exact eight actual qualified actors required')
 require(all(isinstance(a.get('kind'),str) for a in entries) and len({a.get('kind') for a in entries})==8 and {a.get('kind') for a in entries}==set(KINDS),'unknown/missing/duplicate actor ownership')
 return {a['kind']:a for a in entries}
def receipt(root,entry,key,kind,h):
 suffix='-final' if key in ['actual-context','independent'] else ''
 path=FAMILY+kind+'/proof/'+key+suffix+'.json';r=doc(root,entry.get(key),path,h)
 require(r.get('schema')=='null-choir-actor-'+key+'-v1' and r.get('status')=='PASS' and r.get('evidence_class')==('independent-review-of-actual-native' if key=='independent' else 'actual-native') and r.get('actor_kind')==kind,'actual qualified '+key+' receipt required (synthetics are not cohort proof)')
 return r

def resident_player_bytes(root,h):
 p=h['safe_rel'](Path(root),'game/scripts/player.gd',label='actual Worker Player forwarding',allowed_roots={'game'})
 info=p.lstat();require(stat.S_ISREG(info.st_mode) and not getattr(info,'st_flags',0)&0x40000000,'regular resident actual Player required; no hydration')
 return p.read_bytes()

def validate_worker_binding(root,record,rgba,source_sha,h):
 require(isinstance(record,dict) and set(record)=={'manifest','mask','helper','player'},'Worker exact actual physiology records required')
 require(source_sha==WORKER['source'] and sha(rgba)==WORKER['rgba'],'frozen actual Worker source/beauty RGBA')
 m=doc(root,record['manifest'],'game/assets/art/regions/worker-clutch-v1.json',h)
 _,mask=checked(root,record['mask'],'game/assets/art/regions/worker-clutch-v1.regions',h)
 _,helper=checked(root,record['helper'],'game/scripts/worker_hit_regions.gd',h)
 player_current=resident_player_bytes(root,h)
 if sha(player_current)=='0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7':
  # Historical Worker/body native receipts remain pinned to d3ff; only the
  # exact qualified v5 weaponURI pair can normalize back to those bytes.
  require(same(record['player'],{'path':'game/scripts/player.gd','sha256':WORKER['player'],'bytes':15851}),'unchanged historical Player record')
  descriptor=h['read_json'](Path(root)/LEDGER).get('current_player_source_compatibility')
  require(isinstance(descriptor,dict),'explicit body-ledger one-pair compatibility descriptor required')
  player=h['validate_pistol_player_compatibility'](root,player_current,descriptor)
 else:
  require(same(record['player'],{'path':'game/scripts/player.gd','sha256':sha(player_current),'bytes':len(player_current)}),'exact historical Player path/SHA/bytes record')
  player=player_current
 require(sha(helper)==WORKER['helper'] and sha(player)==WORKER['player'],'actual qualified helper JSON-int/cache guards and Player forwarding must be preserved')
 expected={'schema':'null-choir-worker-regions-v1','kind':'worker','width':1024,'height':768,'hframes':8,'vframes':6,'vent_pose':5,'cell_size':[128,128],'alpha_min_byte':128,'regions':{'0':'ordinary','1':'pressure_clutch'},'beauty_path':'res://assets/art/sprites/bodies-v1/worker.png','mask_path':'res://assets/art/regions/worker-clutch-v1.regions','beauty_source_sha256':WORKER['atlas'],'source_blend_sha256':source_sha,'beauty_rgba_sha256':sha(rgba),'mask_sha256':sha(mask)}
 require(all(same(m.get(k),v) for k,v in expected.items()),'real worker binding schema/source/path/hash mismatch')
 names=[p+'/'+n for p in BASE_POSES[:4] for n in ['Recessed convex amber pressure chamber','Clutch chamber curved light plane']]
 require(same(m.get('authored_objects'),names),'only actual authored chamber surfaces may be region1')
 require(len(mask)==786432 and sha(mask)==WORKER['mask'] and set(mask)=={0,1} and sum(mask)==1395,'exact real1395 geometry labels required')
 require(not any(mask[4*128*1024:]),'dead/vent region0')
 frames=m.get('frames');require(isinstance(frames,list) and len(frames)==48,'48 mask/beauty frame bindings')
 for f,row in enumerate(frames):
  c=cell_bytes(rgba,1024,128,f);row0,col=divmod(f,8);ids=b''.join(mask[(row0*128+y)*1024+col*128:(row0*128+y)*1024+(col+1)*128] for y in range(128))
  require(all(not v or a>=128 for v,a in zip(ids,c[3::4])),'geometry label outside exact accepted alpha')
  require(not sum(ids) or sum(ids)<sum(a>=128 for a in c[3::4]),'strict per-frame region subset')
  exp={'frame':f,'pose':f//8,'direction':f%8,'labels':sum(ids),'mask_sha256':sha(ids),'beauty_rgba_sha256':sha(c)}
  require(same(row,exp),'exact worker frame/address/hash/label record')
 return ['game/assets/art/regions/worker-clutch-v1.json','game/assets/art/regions/worker-clutch-v1.regions']


def validate_portable_generator(root,e,kind,native,h):
 require(kind in ['nursery_warden','choir_avatar'],'only exact boss generator reference patches supported')
 base=FAMILY+kind+'/';r=doc(root,e.get('portable_generator_bridge'),base+'proof/portable-generator-reference-patch.json',h)
 require(set(r)=={'actor_kind','native_rendered_generator_sha256','operation','original_generator_bytes','original_generator_sha256','portable_generator','portable_generator_native_reproduction_performed','schema','scope','status','unchanged_prefix_sha256','unchanged_suffix_sha256'},'typed portable generator bridge fields')
 require(r['schema']=='null-choir-portable-generator-reference-patch-v1' and r['status']=='PENDING_NATIVE_REPRODUCTION_NOT_PERFORMED' and r['actor_kind']==kind and r['portable_generator_native_reproduction_performed'] is False,'honest original-generator/reference-only bridge scope')
 require(same(r['portable_generator'],e['generator']) and same(native.get('portable_generator_bridge'),e['portable_generator_bridge']) and native.get('portable_generator_native_reproduction_performed') is False,'portable generator bridge links')
 historical=r['original_generator_sha256'];require(digest(historical) and historical==r['native_rendered_generator_sha256']==native.get('native_rendered_generator_sha256') and historical!=e['generator']['sha256'],'historical actually-rendered generator remains distinct')
 _,code=checked(root,e['generator'],e['generator']['path'],h);lines=code.splitlines(keepends=True);operation=r['operation']
 require(set(operation)=={'expected_original_line_sha256','kind','one_based_line','replacement_utf8'} and operation['kind']=='replace_one_complete_line' and same(operation['one_based_line'],18) and operation['replacement_utf8']=="REFERENCE = OWNED / 'actor-animation-reference-v2.png'\n" and digest(operation['expected_original_line_sha256']),'only exact complete reference line18 replacement allowed')
 require(len(lines)>18 and lines[17]==operation['replacement_utf8'].encode() and sha(b''.join(lines[:17]))==r['unchanged_prefix_sha256'] and sha(b''.join(lines[18:]))==r['unchanged_suffix_sha256'],'all geometry/export code prefix/suffix bytes unchanged')
 require(type(r['original_generator_bytes']) is int and 0<r['original_generator_bytes']-(len(code)-len(lines[17]))<1024,'original reference line exact byte envelope')
 return historical

def public_ui_field(source):
 # Deliberately bounded known Blender5.2 public-copy format, not a general blend
 # loader. No native/source execution or compressed/public-master auto-fallback.
 require(17<len(source)<=32*1024**2 and source[:17]==b'BLENDER17-01v0502','known uncompressed public master header/size')
 o=17;rows=[]
 while o<len(source):
  require(o+32<=len(source),'truncated BHead')
  code,dna,old,size,count,flags=struct.unpack_from('<4sIQQII',source,o)
  require(size<=len(source)-o-32 and len(rows)<100000,'bounded BHead')
  rows.append({'header':o,'payload':o+32,'code':code,'dna':dna,'size':size,'count':count,'flags':flags});o+=32+size
 require(o==len(source) and rows[-1]['code']==b'ENDB' and sum(r['code']==b'ENDB' for r in rows)==1,'exact final ENDB')
 ds=[r for r in rows if r['code']==b'DNA1'];require(len(ds)==1,'one saved DNA schema')
 d=source[ds[0]['payload']:ds[0]['payload']+ds[0]['size']];a=8
 require(d[:8]==b'SDNANAME','DNA NAME schema')
 def count32():
  nonlocal a
  require(a+4<=len(d),'DNA count bounds');n=struct.unpack_from('<I',d,a)[0];a+=4;require(n<=100000,'bounded DNA count');return n
 def names():
  nonlocal a
  result=[]
  for _ in range(count32()):
   end=d.find(b'\0',a);require(end>=a and end-a<4096,'bounded DNA string');result.append(d[a:end].decode('ascii'));a=end+1
  a=(a+3)//4*4;return result
 ns=names();require(d[a:a+4]==b'TYPE','DNA TYPE');a+=4;ts=names();require(d[a:a+4]==b'TLEN','DNA TLEN');a+=4
 require(a+len(ts)*2<=len(d),'DNA type lengths');lengths=struct.unpack_from('<'+'H'*len(ts),d,a);a+=len(ts)*2;a=(a+3)//4*4
 require(d[a:a+4]==b'STRC','DNA STRC');a+=4;structures=[]
 for _ in range(count32()):
  require(a+4<=len(d),'DNA structure bounds');t,n=struct.unpack_from('<HH',d,a);a+=4;require(t<len(ts) and a+n*4<=len(d),'DNA structure fields');fields=[]
  for _ in range(n):
   ft,fn=struct.unpack_from('<HH',d,a);a+=4;require(ft<len(ts) and fn<len(ns),'DNA field indices');fields.append((ts[ft],ns[fn],lengths[ft]))
  structures.append((ts[t],lengths[t],fields))
 require(a==len(d),'no unparsed DNA bytes')
 candidates=[r for r in rows if r['dna']<len(structures) and structures[r['dna']][0]=='FileSelectParams']
 require(len(candidates)==1,'one exact saved UI structure')
 r=candidates[0];name,length,fields=structures[r['dna']]
 require(r['code']==b'DATA' and r['size']==length==2280 and r['count']==1 and r['flags']==0 and r['dna']==849,'known exact FileSelectParams layout')
 require(fields[:2]==[('char','title[96]',1),('char','dir[1282]',1)],'unknown UI field definition')
 start=r['payload']+96;end=start+1282
 require(end<=r['payload']+r['size'] and source[start:end]==b'//'+bytes(1280),'only exact portable UI directory payload allowed')
 return {'BHead_code':'DATA','BHead_header_offset':r['header'],'BHead_payload_offset':r['payload'],'BHead_payload_bytes':r['size'],'DNA_index':r['dna'],'DNA_structure':name,'field':'dir[1282]','field_relative_offset':96,'absolute_field_range_half_open':[start,end],'field_bytes':1282,'replacement_directory':'//','replacement_buffer_sha256':sha(source[start:end]),'public_sha256':sha(source),'public_bytes':len(source)},sha(source[:start]+bytes(1282)+source[end:])

def validate_public_source_bridge(root,e,kind,source,native,common,con,h):
 require(common.get('source_blend_sha256')==sha(source) and native.get('source_blend_sha256')==sha(source),'public/native current source blob binding')
 record=e.get('public_master_bridge')
 if record is None:
  require(not any(k in native for k in ['public_master_bridge','original_authored_source_sha256','actual_public_native_open','original_full_beauty_reproduction']),'public source claims require explicit qualified bridge')
  return sha(source),None
 require(kind in KINDS,'only the exact eight actor UI-copy bridges supported')
 boss=kind in ['nursery_warden','choir_avatar'];ritual=kind in ['caster','guardian','summoner'];later=boss or ritual
 base=FAMILY+kind+'/proof/'
 b=doc(root,record,base+'public-master-bridge.json',h)
 keys={'schema','status','actor_kind','actual_public_copy_native_qualified','actual_public_native_open','byte_patch_proof','original_authored_source_sha256','original_encoded_bytes','original_independent_acceptance','original_source_native','output_equivalence_basis','prepared_UI_byte_bridge','prepared_bridge_reference_namespace','public_RGBA_reproduction_performed','public_source','source_data_equal_original','decoded_non_UI_sha256','decoded_non_UI_digest_method'}
 require(set(b)==keys,'qualified source bridge has missing/unknown fields')
 expected={'schema':'null-choir-qualified-public-master-ui-bridge-v1','status':'PASS_PUBLIC_NATIVE_OPEN_AND_EXACT_NON_UI_SOURCE_IDENTITY','actor_kind':kind,'actual_public_copy_native_qualified':True,'source_data_equal_original':True,'public_RGBA_reproduction_performed':False,'public_source':e['source_blend']}
 require(all(same(b.get(k),v) for k,v in expected.items()),'actual qualified public source bridge')
 authored=b['original_authored_source_sha256'];require(digest(authored) and authored!=sha(source),'separate original-authored and public blob identities')
 require(same(native.get('public_master_bridge'),record) and native.get('original_authored_source_sha256')==authored and native.get('public_RGBA_reproduction_performed') is False and same(native.get('public_rendered_frame_count'),0),'public native source identity/count must not substitute original rendering')
 proof=b['byte_patch_proof'];require(isinstance(proof,dict),'UI byte proof required')
 fields,masked=public_ui_field(source)
 proofkeys=set(fields)|{'all_BHead_structure_bytes_equal','changed_byte_count','changed_offsets','native_tested_public_copy','original_buffer_sha256','original_decoded_bytes','original_decoded_sha256','original_encoded_bytes','original_encoded_sha256','original_source_qualification','outside_field_byte_equal','public_copy_qualification','public_encoding'}
 if boss:proofkeys.remove('original_source_qualification')
 require(set(proof)==proofkeys,'byte proof missing/unknown UI fields')
 require(all(same(proof.get(k),v) for k,v in fields.items()),'public blob/DNA/range/payload proof mismatch')
 require(proof['original_encoded_sha256']==authored and same(proof['original_encoded_bytes'],b['original_encoded_bytes']) and type(b['original_encoded_bytes']) is int and b['original_encoded_bytes']>0 and same(proof['original_decoded_bytes'],len(source)) and digest(proof['original_decoded_sha256']) and digest(proof['original_buffer_sha256']),'original encoded/decoded source identity')
 offsets=proof['changed_offsets'];start,end=fields['absolute_field_range_half_open']
 require(isinstance(offsets,list) and offsets and all(type(i) is int and start<=i<end for i in offsets) and offsets==sorted(set(offsets)) and same(proof['changed_byte_count'],len(offsets)),'exact changed bytes restricted to UI span')
 for key in ['all_BHead_structure_bytes_equal','native_tested_public_copy','outside_field_byte_equal']:require(proof[key] is True,'qualified exact UI-only proof '+key)
 require(proof['public_copy_qualification']=='PASS_ACTUAL_READONLY_PUBLIC_SOURCE_OPEN_AND_SOURCE_DATA_PARITY' and proof['public_encoding']=='Uncompressed original BLENDER17-01v0502 byte stream with one field-only patch; no Blender resave','actual copy parity/encoding required')
 method={'algorithm':'sha256','normalization':'zero_only_DNA_FileSelectParams.dir[1282]','absolute_field_range_half_open':[start,end],'field_bytes':1282,'original_normalized_sha256':masked,'public_normalized_sha256':masked,'original_decoded_sha256':proof['original_decoded_sha256'],'public_decoded_sha256':sha(source),'evidence_class':'pure-byte-comparison-of-actual-source-artifacts','native_receipts_unchanged':True}
 require(b['decoded_non_UI_sha256']==masked and same(b['decoded_non_UI_digest_method'],method),'exact original/public non-UI source digest bridge')
 prepared=doc(root,b['prepared_UI_byte_bridge'],base+'public-master-ui-bridge-prepared.json',h)
 prepared_keys={'schema','status','actor_kind','byte_patch_proof','original_source','original_source_native_receipt','public_source','scope'}|({'decoded_non_UI_sha256'} if later else set())
 require(set(prepared)==prepared_keys and (not later or prepared['decoded_non_UI_sha256']==masked),'typed retained prepared bridge fields/digest')
 require(prepared.get('schema')=='null-choir-public-master-ui-bridge-v1' and prepared.get('status')=='PENDING_PUBLIC_COPY_NATIVE_QUALIFICATION' and prepared.get('actor_kind')==kind,'retained prepared bridge identity')
 require(same(prepared.get('public_source'),e['source_blend']) and same(prepared.get('original_source'),{'path':e['source_blend']['path'],'bytes':b['original_encoded_bytes'],'sha256':authored}),'historical original source record, not current public alias')
 pp=dict(proof);pp.update(native_tested_public_copy=False,public_copy_qualification='PENDING_ACTUAL_READONLY_SOURCE_OPEN_AND_REPRODUCTION')
 require(same(prepared.get('byte_patch_proof'),pp),'prepared -> qualified bridge may change only qualification disposition')
 original=doc(root,b['original_source_native'],base+'source-native-original.json',h)
 expected_original=dict(common,source_blend_sha256=authored)
 if boss:expected_original['generator_sha256']=validate_portable_generator(root,e,kind,native,h)
 require(original.get('schema')=='null-choir-actor-source-native-v1' and original.get('status')=='PASS' and original.get('actor_kind')==kind and original.get('evidence_class')=='actual-native' and all(same(original.get(k),v) for k,v in expected_original.items()),'retained actual original fullbeauty source proof')
 for key in ['opened_saved_source','source_unchanged','public_dependencies_only','geometry_not_image_card']:require(original.get(key) is True,'retained original source qualification '+key)
 require(same(original.get('rendered_frame_count'),con['rows']*8) and same(original.get('pose_collections'),con['poses']) and same(original.get('source_inputs'),e['source_inputs']) and type(original.get('verified_editable_mesh_objects')) is int and original['verified_editable_mesh_objects']>0,'original complete native reproduction/editability')
 historical={'path':base+('source-native-original.json' if later else 'source-native.json'),'sha256':b['original_source_native']['sha256'],'bytes':b['original_source_native']['bytes']}
 require(same(native.get('original_full_beauty_reproduction'),b['original_source_native']) and same(prepared.get('original_source_native_receipt'),historical),'original fullbeauty proof references')
 actual=doc(root,b['actual_public_native_open'],base+'public-native-open.json',h)
 require(same(native.get('actual_public_native_open'),b['actual_public_native_open']),'public native proof link')
 expected_actual={'schema':'null-choir-public-master-native-open-v1','status':'PASS_PUBLIC_COPY_NATIVE_OPEN_SOURCE_DATA_MATCH_ORIGINAL','actor_kind':kind,'evidence_class':'actual-native','public_source_sha256':sha(source),'original_source_sha256':authored,'ui_bridge_sha256':b['prepared_UI_byte_bridge']['sha256'],'original_source_native_proof_sha256':b['original_source_native']['sha256'],'decoded_non_UI_bytes_identical':True,'opened_public_source':True,'opened_original_source':True,'source_data_identical_to_original':True,'external_dependencies':False,'residual_home_in_source_data':False,'own_loaded_filepath_excluded':True,'source_resaved':False,'geometry_material_camera_reconstruction':False,'rendered_frame_count':0,'public_RGBA_reproduction_performed':False}
 actual_extra=({'decoded_non_UI_sha256','non_UI_identity_authority','portable_generator_native_reproduction_performed'} if boss else {'decoded_non_UI_sha256'} if ritual else set())
 require(set(actual)==set(expected_actual)|{'actual_source_data','scope'}|actual_extra,'typed actual native copy proof missing/unknown fields')
 if later:require(actual['decoded_non_UI_sha256']==masked,'actual native non-UI source digest')
 if boss:require(actual['portable_generator_native_reproduction_performed'] is False and actual['non_UI_identity_authority']=='Hash-bound pure original-decoded/public byte comparison prepared before native run','honest boss native generator/non-UI proof scope')
 require(all(same(actual.get(k),v) for k,v in expected_actual.items()),'actual original/public source native copy parity required')
 data=actual.get('actual_source_data');require(isinstance(data,dict) and digest(data.get('source_data_sha256')) and same(data.get('mesh_objects'),original['verified_editable_mesh_objects']) and same(data.get('pose_collections'),con['poses']+(['windup','recovery'] if ritual else [])),'actual source-data/editability parity record')
 require(type(data.get('editable_joint_empties')) is int and data['editable_joint_empties']>0 and type(data.get('material_count')) is int and data['material_count']>0 and isinstance(data.get('internal_texts'),list),'actual saved editable material/joint/Text records')
 settings=data.get('settings');require(isinstance(settings,dict) and all(same(settings.get(k),v) for k,v in {'engine':'BLENDER_WORKBENCH','threads':2,'threads_mode':'FIXED','resolution':con['cell_size']+[100],'transparent':True,'render_aa':'OFF','studio_light':'paint.sl','light':'STUDIO','color_type':'TEXTURE' if ritual else 'MATERIAL','view_transform':'Standard','look':'None'}.items()),'actual original/public beauty settings parity')
 if boss:
  require(digest(data.get('base_source_data_sha256')) and digest(data.get('UV_lights_worlds_sha256')) and all(type(data.get(k)) is int and data[k]>=0 for k in ['UV_layer_count','image_count','library_count']),'actual boss UV/light/world source parity')
 if ritual:
  require(same(native.get('extra_source_only_pose_collections'),['windup','recovery']) and same(original.get('extra_source_only_pose_collections'),['windup','recovery']),'extra editable source poses distinct from unchanged runtime5')
  require(digest(data.get('UV_material_camera_world_sha256')),'actual ritual UV/material/camera/world parity digest')
  packed=data.get('packed_image_native_RGBA_UV_PBR');require(isinstance(packed,dict) and set(packed)=={'native_image_RGBA_exact','packed_RGBA_exact','packed_png_sha256','same_active_Workbench_PBR_image','saved_UV_meshes'},'exact actual ritual packedimage parity schema')
  require(all(packed.get(k) is True for k in ['native_image_RGBA_exact','packed_RGBA_exact','same_active_Workbench_PBR_image']) and same(packed['saved_UV_meshes'],data['mesh_objects']) and digest(packed['packed_png_sha256']),'actual native packed RGBA/UV/PBR bindings')
  paint=e.get('editable_surface_paint');require(isinstance(paint,dict) and paint.get('path')==FAMILY+kind+'/'+kind+'-surface-paint.png','exact authored companion paint PNG path')
  _,paint_png=checked(root,paint,paint['path'],h);surface=native.get('surface_paint')
  require(isinstance(surface,dict) and same(surface,original.get('surface_paint')) and same(surface.get('size'),[512,256]) and surface.get('opaque') is True and surface.get('sampling')=='Closest','actual retained surface paint contract')
  paint_rgba=pixels(paint_png,[512,256],h,'authored ritual paint');bottom=b''.join(paint_rgba[y*512*4:(y+1)*512*4] for y in reversed(range(256)))
  require(sha(bottom)==surface.get('rgba_bottom_up_sha256'),'public companion paint samples match actual saved native packed image; encoded PNG identities remain separate')
  refs=[e['generator']]+e['source_inputs']
  for text in data['internal_texts']:
   require(text.get('in_memory') is True and text.get('filepath_empty') is True and text.get('library_none') is True and any(r['path'].endswith('/'+text.get('name','')) and r['sha256']==text.get('sha256') and same(r['bytes'],text.get('bytes')) for r in refs),'actual internal editable Text matches retained portable code bytes')
 return authored,b

# Exact reviewed public-copy receipts are the authority for original encoded
# identities and the one File tEXt removal. Original PNGs/private pathname bytes
# are intentionally not public dependencies; do not pretend to rederive them.
RAW_METADATA_PINS={
 'brute':('808aa9ef9ad88543fa2a7e478b015dad8754985919de2e77c14bbb77c5fdf0d6',168),
 'crawler':('6ede0cbbb83030f62cea65a1a932beafea30f3808eca3d4345289fbe17ecb1fe',171),
 'worker':('7eb0f4dc8cec3554d7613c84fafbeb7597c84db581e6a364138170f48f9effd9',146),

 'nursery_warden':('504445037ae06a62ea2edb706eeb063739cb7fedd34e688a9ee7611882cc08eb',153),
 'choir_avatar':('d9fdf09ca282817e228cade4abbc64bcaea25dc5a76d29abfe4706f2839f6dcb',151),
 'caster':('6035c95b6de28d050df1236734dee560126dbc6d687c0c6ba15d05db210d525c',164),
 'guardian':('288f28aa6212407b4a61ba2d441e59dbcfe7f6af4df97e83f8bc6ac31ffef7b8',168),
 'summoner':('2d0d83410d85cbc124c9e2bf5f904d7eab596ba50ccb9ced5418caa654516d60',168),
}
def validate_raw_metadata_bridge(root,e,kind,native,authored,source_bridge,con,h):
 require(kind in KINDS and kind in RAW_METADATA_PINS,'all eight exact actors require a pinned metadata operation receipt')
 base=FAMILY+kind+'/proof/';record=e.get('raw_png_metadata_bridge')
 require(isinstance(record,dict) and set(record)=={'path','sha256','bytes'},'exact required raw metadata bridge record')
 pinned,removed_bytes=RAW_METADATA_PINS[kind]
 require(record.get('sha256')==pinned,'authorized exact original-encoded metadata receipt required')
 r=doc(root,record,base+'raw-PNG-File-metadata-bridge.json',h)
 boss=kind in ['nursery_warden','choir_avatar'];old=kind in ['worker','crawler','brute']
 authority='original_native_encoded_SHA_authority' if boss else 'original_encoded_SHA_authority'
 expected={
  'schema':'null-choir-public-raw-PNG-File-metadata-bridge-v1','status':'PASS_PURE_EXACT_PINNED_METADATA_COPY','actor_kind':kind,
  'new_native_runs':0,'original_source_blend_sha256':authored,
  'operation':('Remove exactly one tEXt File chunk whose payload equals the exact pinned original saved-master pathname; no other PNG chunk changes' if boss else 'Remove exactly one File tEXt whose payload equals the exact retained original saved-master pathname; no other chunk changes' if old else 'Remove exactly one File tEXt whose payload equals the exact original saved-master pathname; no other chunk changes'),
  'scope':('Public-copy metadata privacy only, exact original native decoded RGBA retained; no pixel reencoding or new native render' if boss else 'Public-copy metadata privacy only; no pixel reencoding, art/source change, render or new native qualification.' if old else 'Public-copy metadata only; no pixel reencoding/render/regeneration.'),
  authority:('Retained actual frozen-source native result file inventory, not self-declared updated raw SHA' if boss else 'Pure retained-public-file SHA inventory recorded during privacy preparation, associated with the exact unchanged original saved-source native receipt and every rawRGBA-to-accepted-cell transform. No native-time encoded raw-PNG SHA inventory is asserted.' if old else 'Pure retained-file SHA inventory recorded during this preparation; exact actual native job association plus every rawRGBA-to-accepted-cell transform independently checked. Earlier native wrapper did not record encoded raw-PNG SHA inventory.'),
 }
 if old:
  require(isinstance(source_bridge,dict),'old3 metadata receipt requires exact original-source bridge')
  expected['retained_original_source_native']=source_bridge['original_source_native']
 require(set(r)==set(expected)|{'frames'} and all(same(r.get(k),v) for k,v in expected.items()),'typed role-specific metadata authority/operation/source scope')
 require(isinstance(source_bridge,dict) and digest(authored) and native.get('original_authored_source_sha256')==authored and native.get('source_blend_sha256')==e['source_blend']['sha256'],'metadata bridge actual original/public source association')
 original=doc(root,source_bridge['original_source_native'],base+'source-native-original.json',h)
 require(original.get('schema')=='null-choir-actor-source-native-v1' and original.get('actor_kind')==kind and original.get('evidence_class')=='actual-native' and original.get('status')=='PASS' and original.get('source_blend_sha256')==authored,'metadata retained actual source-native authority')
 # Original3 evidence receipts (Worker also reconciliation) have no job-list
 # or native-time encoded PNG inventory. Preserve that weaker scope explicitly.
 if old:
  require('actual_native_jobs' not in native and 'actual_native_jobs' not in original,'old3 must not invent native job inventory')
  evidence=original.get('evidence_receipt')
  require(isinstance(evidence,dict) and set(evidence)=={'sha256','bytes'} and digest(evidence['sha256']) and type(evidence['bytes']) is int and evidence['bytes']>0 and same(native.get('evidence_receipt'),evidence),'old3 exact retained actual native evidence association')
  if kind=='worker':require(same(native.get('reconciliation'),original.get('reconciliation')) and isinstance(original.get('reconciliation'),dict),'unchanged actual Worker reconciliation authority')
 else:
  # Ritual's older wrapper did NOT inventory encoded PNG hashes. Its exact
  # retained-file receipt remains the weaker authority; native jobs bind samples.
  require(same(native.get('actual_native_jobs'),original.get('actual_native_jobs')) and isinstance(original.get('actual_native_jobs'),list) and len(original['actual_native_jobs'])==(1 if kind=='nursery_warden' else 2) and same(native.get('evidence_receipt'),original.get('evidence_receipt')),'metadata bridge retained actual native job association')
 count=48 if kind=='worker' else 40
 require(same(native.get('rendered_frame_count'),count) and same(original.get('rendered_frame_count'),count) and same(native.get('cell_rgba_sha256'),original.get('cell_rgba_sha256')) and isinstance(native.get('cell_rgba_sha256'),list) and len(native['cell_rgba_sha256'])==count,'metadata complete actual native frame sample authority')
 frames=e.get('frames');rows=r['frames']
 require(isinstance(frames,list) and isinstance(rows,list) and len(frames)==len(rows)==count and con['poses']==BASE_POSES+(['clutch_vent'] if kind=='worker' else []),'metadata exact complete ordered pose/8-direction frame matrix')
 keys={'IDAT_byte_identical','all_other_chunks_byte_identical','frame','original_chunk_index','original_encoded_bytes','original_encoded_sha256','pixel_reencoded','public_encoded_bytes','public_encoded_sha256','public_raw','removed_chunk_sha256','removed_chunk_type','removed_keyword','removed_payload_sha256','same_decoded_RGBA_sha256'}
 for i,(row,frame) in enumerate(zip(rows,frames)):
  require(isinstance(row,dict) and set(row)==keys,'typed metadata frame row missing/unknown fields')
  path=FAMILY+kind+'/frames/raw-'+con['poses'][i//8]+'-'+str(i%8).zfill(2)+'.png'
  raw_record=frame.get('raw')
  require(isinstance(raw_record,dict) and set(raw_record)=={'path','sha256','bytes'} and same(row['public_raw'],raw_record),'metadata exact public raw record')
  _,encoded=checked(root,raw_record,path,h);rgba=pixels(encoded,con['cell_size'],h,path)
  require(all(digest(row[k]) for k in ['original_encoded_sha256','public_encoded_sha256','removed_chunk_sha256','removed_payload_sha256','same_decoded_RGBA_sha256']),'metadata frame digest types')
  exp={'frame':i,'original_chunk_index':7,'original_encoded_bytes':len(encoded)+removed_bytes,'public_encoded_bytes':len(encoded),'public_encoded_sha256':sha(encoded),'same_decoded_RGBA_sha256':sha(rgba),'removed_chunk_type':'tEXt','removed_keyword':'File','IDAT_byte_identical':True,'all_other_chunks_byte_identical':True,'pixel_reencoded':False}
  require(all(same(row[k],v) for k,v in exp.items()) and row['original_encoded_sha256']!=sha(encoded),'exact authorized single File metadata removal / unchanged samples')
  require(same(frame.get('frame'),i) and same(frame.get('pose'),con['poses'][i//8]) and same(frame.get('direction'),i%8) and frame.get('raw_rgba_sha256')==sha(rgba) and frame.get('cell_rgba_sha256')==native['cell_rgba_sha256'][i],'metadata public raw/frame/address/native-cell join')
  # The retained CRC/filter parser above checked every public chunk. Require the
  # removed File keyword absent and the original insertion point before IDAT.
  require(not re.search(rb'/(?:Users|home)/|file://|[A-Za-z]:[\\/]Users[\\/]',encoded,re.I),'private File/path metadata in public raw PNG')
  pos=8;chunks=[]
  while pos<len(encoded):
   size=int.from_bytes(encoded[pos:pos+4],'big');typ=encoded[pos+4:pos+8];payload=encoded[pos+8:pos+8+size]
   require(not (typ==b'tEXt' and payload.split(b'\0',1)[0]==b'File'),'public raw still contains removed File tEXt')
   chunks.append(typ);pos+=size+12
  require(chunks[:7]==[b'IHDR',b'sRGB',b'gAMA',b'cHRM',b'eXIf',b'oFFs',b'pHYs'] and len(chunks)>7 and chunks[7]==b'tEXt' and chunks.index(b'IDAT')>7,'exact retained File removal position')
 return r

def validate_bridge_acceptance(root,e,kind,grade,bridge,authored,common,h):
 if bridge is None:return
 base=FAMILY+kind+'/proof/';original=doc(root,bridge['original_independent_acceptance'],base+'independent-original.json',h)
 expected={'schema':'null-choir-actor-independent-v1','status':'PASS','actor_kind':kind,'evidence_class':'independent-review-of-actual-native','review_role':'independent','source_blend_sha256':authored,'atlas_sha256':common['atlas_sha256'],'reviewed_cell_sha256':common['cell_rgba_sha256']}
 require(all(same(original.get(k),v) for k,v in expected.items()),'retained independent acceptance binds original art source/cells')
 require(same(grade.get('public_master_bridge'),e['public_master_bridge']) and same(grade.get('original_independent_acceptance'),bridge['original_independent_acceptance']) and grade.get('original_reviewed_source_sha256')==authored and grade.get('new_independent_review_of_public_UI_copy_performed') is False,'honest independent original -> public UI-only source bridge')
 require(grade.get('original_review_sha256')==original.get('original_review_sha256') and digest(original.get('original_review_sha256')),'original independent review identity preserved')

FINAL_CONSUMER_SHA='6463ec67fce42419da719825776811c4779996a6be07dc414390becb10161229'
FINAL_FIXTURE_SHA='bb34ab6131d757d2839568f02c137d47ebb7b9e5c9f25bfc56e0079ba4366d16'
FINAL_REVIEW_SHA='88e98c652f49862d20829d4d9fd1c7d4240260e578671ef870e0e04da0ef950b'
OLD_CONTEXT_CONSUMER_SHA='4b8d84543100529b73145d23ceb4438368b0b12a4479f8f1f6876c6205abe63b'

def native_report_spawn_same(actual,expected):
 # Godot JSON-loaded map yaw emits 73.0 while authored JSON may use 73.
 # Only these explicit bounded map numeric fields permit exact numeric equality;
 # bool/nonfinite/out-of-range/unknown fields never inherit that exception.
 if not isinstance(actual,dict) or not isinstance(expected,dict) or not (set(actual)==set(expected)=={'id','kind','cell','yaw'}):return False
 if not same(actual['id'],expected['id']) or not same(actual['kind'],expected['kind']):return False
 if not isinstance(actual['cell'],list) or not isinstance(expected['cell'],list) or not (len(actual['cell'])==len(expected['cell'])==2):return False
 def number(a,b,limit):return type(a) in [int,float] and type(b) in [int,float] and math.isfinite(a) and math.isfinite(b) and abs(a)<=limit and abs(b)<=limit and a==b
 return number(actual['yaw'],expected['yaw'],360) and all(number(a,b,4096) for a,b in zip(actual['cell'],expected['cell']))

def validate_final_context(root,e,kind,context,grade,common,con,h):
 # Only these fixed final aliases augment the retained immutable packet files.
 base=FAMILY+kind+'/proof/'
 retained=context.get('retained_source_art_qualification')
 require(isinstance(retained,dict) and set(retained)=={'actual-context','independent'},'exact retained fullmatrix context/acceptance records')
 old=doc(root,retained['actual-context'],base+'actual-context.json',h)
 oldgrade=doc(root,retained['independent'],base+'independent.json',h)
 require(old.get('schema')=='null-choir-actor-actual-context-v1' and old.get('evidence_class')=='actual-native' and old.get('status')=='PASS' and old.get('actor_kind')==kind and old.get('atlas_sha256')==common['atlas_sha256'] and old.get('rgba_sha256')==common['rgba_sha256'],'retained actual fullmatrix source-art context identity')
 require(old.get('consumer_sha256')==OLD_CONTEXT_CONSUMER_SHA and old.get('configured_runtime_uri')=='res://assets/art/sprites/'+kind+'.png' and same(old.get('tested_frames'),list(range(con['rows']*8))) and len(old.get('views',[]))==con['rows']*8,'retained fullmatrix is old configured source-art context, not new normal-resource render')
 require(oldgrade.get('schema')=='null-choir-actor-independent-v1' and oldgrade.get('evidence_class')=='independent-review-of-actual-native' and oldgrade.get('status')=='PASS' and oldgrade.get('actor_kind')==kind and oldgrade.get('review_role')=='independent' and oldgrade.get('actual_context_sha256')==retained['actual-context']['sha256'] and oldgrade.get('atlas_sha256')==common['atlas_sha256'] and oldgrade.get('source_blend_sha256')==common['source_blend_sha256'] and same(oldgrade.get('reviewed_cell_sha256'),common['cell_rgba_sha256']),'retained immutable fullmatrix independent source-art approval')
 for key in ['original_review_sha256','original_reviewed_source_sha256','original_independent_acceptance','public_master_bridge']:
  require(same(grade.get(key),oldgrade.get(key)),'do not replace original source-art approval with idle review')
 require(context.get('consumer_sha256')==FINAL_CONSUMER_SHA and context.get('player_sha256')==WORKER['player'] and context.get('worker_helper_sha256')==WORKER['helper'] and context.get('resource_class')=='CompressedTexture2D' and context.get('normal_import_sidecar_sha256')==e['import_sidecar']['sha256'] and same(context.get('tested_frames'),[0]) and context.get('new_fullmatrix_context_rendered') is False,'final exact normal constructor/source binding and honest idle-only scope')
 imported=doc(root,e['normal-import'],base+'normal-import.json',h)
 require(context.get('normal_import_uid')==imported.get('uid'),'final normal resource actual UID identity')
 require(context.get('sampled_Metal_RSS_bytes') is None and context.get('sampled_Metal_RSS_status')=='unavailable; not zero memory','do not relabel missing fast Metal RSS samples as zero usage')
 fixture=context.get('source_fixture');checked(root,fixture,FAMILY+'final-cohort/static_visible_cohort.gd',h)
 require(fixture['sha256']==FINAL_FIXTURE_SHA,'actual visible fixture source identity')
 registry=doc(root,context.get('visible_registry'),FAMILY+'final-cohort/visible-registry.json',h)
 native=doc(root,context.get('native_report'),base+'final-context-native-report.json',h)
 require(native.get('failures')==0 and type(native.get('failures')) is int and isinstance(native.get('checks'),list) and len(native['checks'])==18 and all(isinstance(r,dict) and r.get('passed') is True for r in native['checks']),'all actual native visible checks pass')
 require(native.get('role')==kind and native.get('runtime_uri')==e['runtime_uri'] and native.get('normal_RGBA')==common['rgba_sha256'] and native_report_spawn_same(native.get('actor_spec'),registry[kind]['expected_spawn']) and native.get('map')==registry[kind]['map_file'],'actual authored spawn/map/normalRGBA/native resource join')
 require(native.get('collision_negative_control',{}).get('blocked') is True and native.get('collision_negative_control',{}).get('registered_static_world_colliders',0)>0 and native.get('camera',{}).get('accepted') is True and context.get('native_wall_negative_control') is True,'actual registered wall negative / accepted floor-capsule-LOS camera')
 rows=native.get('views');require(isinstance(rows,list) and len(rows)==1,'one real idle view only');v=rows[0]
 require(same(v.get('tested_frame'),0) and same(v.get('manual_idle_direction'),0) and v.get('no_ImageTexture_override') is True and same(v.get('resolution'),[640,360]) and type(v.get('visible_changed_pixels')) is int and v['visible_changed_pixels']>=64 and type(v.get('stable_opaque_source_witnesses')) is int and 1<=v['stable_opaque_source_witnesses']<=9,'native real visible depth-tested idle/opaque ABA proof')
 require(context.get('visible_changed_pixels')==v['visible_changed_pixels'] and context.get('stable_opaque_source_witnesses')==v['stable_opaque_source_witnesses'],'context/native visible witness counts')
 backgrounds=context.get('backgrounds');require(isinstance(backgrounds,list) and len(backgrounds)==2,'exact two actual ABA backgrounds')
 decoded=[]
 for name,record in zip(['a','b'],backgrounds):
  _,raw=checked(root,record,base+'final-background-'+name+'.png',h);decoded.append(pixels(raw,[640,360],h,'final background'))
 _,raw=checked(root,context['views'][0],base+'final-context-00.png',h);visible=pixels(raw,[640,360],h,'final context')
 changed=sum(decoded[0][i:i+3]!=visible[i:i+3] for i in range(0,len(visible),4))
 require(changed==v['visible_changed_pixels'] and changed>=64,'actual encoded context RGB presence, wall-only image rejected')
 approval=doc(root,grade.get('final_context_independent_review'),FAMILY+'final-cohort/independent-context-review.json',h)
 require(approval.get('schema')=='null-choir-final-context-independent-review-v1' and approval.get('status')=='PASS' and approval.get('review_role')=='independent' and approval.get('evidence_class')=='independent-review-of-actual-native' and approval.get('original_review_sha256')==FINAL_REVIEW_SHA and approval.get('fixture_sha256')==FINAL_FIXTURE_SHA and approval.get('consumer_sha256')==FINAL_CONSUMER_SHA,'actual scoped final independent review identity')
 reviews=approval.get('roles');require(isinstance(reviews,list) and len(reviews)==8 and {r.get('kind') for r in reviews}==set(KINDS),'all eight independently reviewed idle contexts')
 r=next(r for r in reviews if r['kind']==kind)
 expected={'actual_context_sha256':e['actual-context']['sha256'],'native_report_sha256':context['native_report']['sha256'],'view_sha256':context['views'][0]['sha256'],'background_sha256':[b['sha256'] for b in backgrounds],'recomputed_RGB_changed_pixels':changed,'independently_projected_opaque_stable_ABA_witnesses':v['stable_opaque_source_witnesses'],'authored_spec_exact':True,'native_wall_negative_control_pass':True,'manual_idle_direction':0,'normal_RGBA':common['rgba_sha256'],'actual_bearing':v['actual_bearing']}
 require(all(same(r.get(k),value) for k,value in expected.items()),'independent exact role source/context/ABA bindings')
 require(grade.get('new_independent_art_grade_performed') is False and grade.get('retained_fullmatrix_source_art_acceptance_unchanged') is True and grade.get('final_consumer_qualification')=='PASS_MANUAL_IDLE0_NORMAL_RESOURCE_ONLY','do not relabel new idle visibility as fullmatrix art rerender/grade')
 return True

def validate_final_runtime(root,value,entries,h):
 r=doc(root,value.get('runtime_qualification'),FAMILY+'final-cohort/functional-runtime.json',h)
 require(r.get('schema')=='null-choir-eight-actor-functional-runtime-v1' and r.get('status')=='PASS' and r.get('evidence_class')=='actual-native' and r.get('consumer_sha256')==FINAL_CONSUMER_SHA and r.get('player_sha256')==WORKER['player'] and r.get('worker_helper_sha256')==WORKER['helper'] and r.get('old_eight_context_images_qualified') is False,'retained functional actual source binding; failed old views not qualified')
 require(all(same(r.get(k),v) for k,v in {'checks':555,'actors':8,'normal_cell_count':328,'actual_player_query_worker_contacts':9,'fixture_sha256':'0c2db7fa1100d8c34801189c24c8f5e82c1f25d8571d4b9aa383c24170a5cfe2','runner_sha256':'f4998d691020e7199469aaffdd5c118f10cfd2a083b0d66049caef20dfa2e30f'}.items()),'exact retained native functional scope/source identities')
 approval=doc(root,value.get('final_context_independent_review'),FAMILY+'final-cohort/independent-context-review.json',h)
 require(approval.get('original_review_sha256')==FINAL_REVIEW_SHA and approval.get('status')=='PASS','top final independent receipt exact identity')
 for entry in entries.values():
  grade=receipt(root,entry,'independent',entry['kind'],h)
  require(same(grade.get('final_context_independent_review'),value['final_context_independent_review']),'one exact independently qualified eight-context cohort')
 report=doc(root,r.get('report'),FAMILY+'final-cohort/functional-native02-report.json',h)
 require(report.get('failures')==0 and type(report.get('failures')) is int and len(report.get('checks',[]))==555 and all(x.get('passed') is True for x in report['checks']) and len(report.get('contacts',[]))==9,'retained actual555checks/9PlayerQuery contacts')
 cohort=report.get('cohort');require(isinstance(cohort,list) and len(cohort)==8 and {x.get('kind') for x in cohort}==set(KINDS),'actual eight normal constructors')
 for x in cohort:
  e=entries[x['kind']];imported=doc(root,e['normal-import'],FAMILY+x['kind']+'/proof/normal-import.json',h)
  require(x.get('runtime_uri')==e['runtime_uri'] and x.get('resource_class')=='CompressedTexture2D' and x.get('no_ImageTexture_override') is True and x.get('uid')==imported['uid'] and x.get('normal_rgba_sha256')==e['output']['rgba_sha256'] and same(x.get('cell_rgba_sha256'),e['output']['cell_rgba_sha256']),'retained328 normal cells/source UID bindings')
 require(report.get('normal_import',{}).get('mask_sha256')==WORKER['mask'] and report.get('normal_import',{}).get('source_blend_sha256')==WORKER['source'],'actual Worker real authored mask/source, not synthetic region')
 return True

def validate_ledger(root,ledger_path=LEDGER):
 root=Path(root).absolute();h=helpers(root)
 require(ledger_path==LEDGER,'only separate canonical bodies ledger accepted')
 value=h['read_json'](h['safe_rel'](root,ledger_path,label='actor ledger',allowed_roots={'source'}));entries=envelope(value,h)
 pin=doc(root,value.get('legacy_exports'),FAMILY+'legacy-140.json',h)
 require(sha((root/(FAMILY+'legacy-140.json')).read_bytes())==PINSET_SHA and pin.get('runtime_exports')==140 and pin.get('catalog_entries')==119,'unchanged explicit140 export pinset')
 catalog=doc(root,value.get('legacy_catalog'),'source/art/manifest.json',h)
 require(sha((root/'source/art/manifest.json').read_bytes())==LEGACY_SHA and len(catalog.get('assets',[]))==119,'all119 legacy catalog entries unchanged')
 require(len(pin['files'])==140 and len({r['path'] for r in pin['files']})==140,'all140 legacy exports owned')
 for row in pin['files']:checked(root,row,row['path'],h)
 legacy={a['id']:a for a in catalog['assets']}
 actual_path=h['safe_rel'](root,'game/scripts/enemy.gd',label='actual body consumer',allowed_roots={'game'})
 info=actual_path.lstat();require(stat.S_ISREG(info.st_mode) and not getattr(info,'st_flags',0)&0x40000000,'regular resident current body consumer')
 actual_consumer=actual_path.read_bytes()
 if sha(actual_consumer)==FINAL_CONSUMER_SHA:
  _,consumer=checked(root,value.get('consumer'),'game/scripts/enemy.gd',h)
 else:
  require(same(value.get('consumer'),{'path':'game/scripts/enemy.gd','bytes':29804,'sha256':FINAL_CONSUMER_SHA}),'unchanged historical body consumer record')
  consumer=h['consumer_compatibility'](root)['historical'](root,'game/scripts/enemy.gd',FINAL_CONSUMER_SHA)
 # Active constructor contracts still run on CURRENT bytes, while the original
 # context receipts below continue to join their exact historical source bytes.
 consumer_contract(actual_consumer.decode(),h)
 outputs=[];seen_uids=set();seen_imports=set()
 for kind in KINDS:
  e=entries[kind];con=contract(kind);uri='res://assets/art/sprites/bodies-v1/'+kind+'.png'
  require(e.get('runtime_uri')==uri and same(e.get('runtime_contract'),con),'exact actor runtime contract '+kind)
  _,png=checked(root,e.get('output'),GAME+kind+'.png',h);stats,rgba=atlas_stats(png,kind,h)
  require(all(same(e['output'].get(k),v) for k,v in stats.items()),'atlas RGBA/cell/bounds identity '+kind)
  _,imp=checked(root,e.get('import_sidecar'),GAME+kind+'.png.import',h);uid,target=import_contract(imp.decode(),kind,h)
  require(uid not in seen_uids and target not in seen_imports,'duplicate actor UID/import destination');seen_uids.add(uid);seen_imports.add(target)
  source_path=FAMILY+kind+'/'+kind+'.blend';_,source=checked(root,e.get('source_blend'),source_path,h)
  generator=e.get('generator');require(isinstance(generator,dict) and isinstance(generator.get('path'),str) and generator['path'].startswith(FAMILY+kind+'/') and generator['path'].endswith('.py'),'portable generator must be owned under actor source family')
  checked(root,generator,generator['path'],h)
  inputs=e.get('source_inputs');require(isinstance(inputs,list) and all(isinstance(r,dict) and isinstance(r.get('path'),str) for r in inputs) and len({r.get('path') for r in inputs})==len(inputs),'explicit unique portable source input records')
  for item in inputs:
   shared=kind in ['caster','guardian','summoner'] and item['path']==FAMILY+'ritual-shared/actor-animation-reference-v2.png' and item['sha256']=='c2a9b71f2b6c005be50e1797e428138e2872e2708c886b79aca96148ccd5e6ca'
   require(item['path'].startswith(FAMILY+kind+'/') or shared,'source input outside exact role/shared-reference owner');checked(root,item,item['path'],h)
  orig=e.get('lineage');require(isinstance(orig,dict),'original lineage retained')
  checked(root,orig.get('source'),legacy[kind]['source'],h);require(orig['source']['sha256']==legacy[kind]['source_sha256'],'original Blender lineage hash')
  oldpath='game/assets/art/sprites/'+kind+'.png';old=next((r for r in legacy[kind]['outputs'] if r['path']==oldpath),None)
  require(old is not None and orig.get('output',{}).get('sha256')==old['sha256'],'original runtime lineage');checked(root,orig['output'],oldpath,h)
  def original_recipe(logical,digest_value,record):
   require(isinstance(record,dict) and record.get('sha256')==digest_value and record.get('path') in [logical,'source/art/recipe_history/'+digest_value+'/'+logical+'.txt'],'original exact retained recipe generation')
   checked(root,record,record['path'],h)
  original_generator=legacy[kind]['provenance']['authoring_script']
  require(orig.get('logical_generator')==original_generator,'original logical generator identity')
  original_recipe(original_generator,legacy[kind]['recipe_sha256'],orig.get('generator'))
  dependencies=orig.get('generator_dependencies');expected_deps=legacy[kind].get('recipe_dependencies',{})
  require(isinstance(dependencies,dict) and dependencies.keys()==expected_deps.keys(),'original exact recipe dependency closure')
  for logical,digest_value in expected_deps.items():original_recipe(logical,digest_value,dependencies[logical])
  common={'source_blend_sha256':sha(source),'generator_sha256':generator['sha256'],'atlas_sha256':sha(png),'rgba_sha256':stats['rgba_sha256'],'cell_rgba_sha256':stats['cell_rgba_sha256']}
  native=receipt(root,e,'source-native',kind,h)
  require(all(same(native.get(k),v) for k,v in common.items()),'source-native exact blob/output bindings')
  require(native.get('opened_saved_source') is True and native.get('source_unchanged') is True and native.get('public_dependencies_only') is True and type(native.get('verified_editable_mesh_objects')) is int and native['verified_editable_mesh_objects']>0 and same(native.get('pose_collections'),con['poses']) and same(native.get('source_inputs'),inputs) and same(native.get('rendered_frame_count'),con['rows']*8) and native.get('geometry_not_image_card') is True,'actual opened editable source proof required; header/magic alone is NOT proof')
  authored_source_sha,source_bridge=validate_public_source_bridge(root,e,kind,source,native,common,con,h)
  validate_raw_metadata_bridge(root,e,kind,native,authored_source_sha,source_bridge,con,h)
  registration=e.get('frames');require(isinstance(registration,list) and len(registration)==con['rows']*8,'complete native source/raw registration')
  c=con['cell_size'][0]
  for f,frame in enumerate(registration):
   pose=con['poses'][f//8];path=FAMILY+kind+'/frames/raw-'+pose+'-'+str(f%8).zfill(2)+'.png'
   _,data=checked(root,frame.get('raw'),path,h);raw=pixels(data,[c,c],h,path)
   compiled=cell_bytes(rgba,con['dimensions'][0],c,f)
   validate_raw_frame(raw,compiled,con,frame,f)
  imported=receipt(root,e,'normal-import',kind,h)
  imp_expected={'runtime_uri':uri,'png_sha256':sha(png),'sidecar_sha256':sha(imp),'uid':uid,'imported_path':target,'dimensions':con['dimensions'],'rgba_sha256':stats['rgba_sha256'],'cell_rgba_sha256':stats['cell_rgba_sha256'],'bit_exact_to_source':True,'resource_class':'CompressedTexture2D','uid_authority':'actual-godot-generated'}
  require(all(same(imported.get(k),v) for k,v in imp_expected.items()) and digest(imported.get('imported_sha256')) and type(imported.get('imported_bytes')) is int and imported['imported_bytes']>0,'actual normal Texture2D import/UID/bytes proof')
  context=receipt(root,e,'actual-context',kind,h)
  context_expected={'atlas_sha256':sha(png),'rgba_sha256':stats['rgba_sha256'],'consumer_sha256':sha(consumer),'configured_runtime_uri':uri,'resolution':[640,360]}
  require(all(same(context.get(k),v) for k,v in context_expected.items()),'actual Level/Sprite3D consumer identity')
  tested=context.get('tested_frames');require(isinstance(tested,list) and tested and len(set(tested))==len(tested) and all(type(f) is int and 0<=f<con['rows']*8 for f in tested),'honest unique tested context frame addresses')
  views=context.get('views');require(isinstance(views,list) and len(views)==len(tested),'actual context views')
  for f,view in zip(tested,views):
   expected=FAMILY+kind+'/proof/final-context-'+str(f).zfill(2)+'.png';_,b=checked(root,view,expected,h);pixels(b,[640,360],h,expected)
  grade=receipt(root,e,'independent',kind,h)
  require(grade.get('review_role')=='independent' and grade.get('atlas_sha256')==sha(png) and grade.get('source_blend_sha256')==sha(source) and same(grade.get('reviewed_cell_sha256'),stats['cell_rgba_sha256']) and grade.get('actual_context_sha256')==e['actual-context']['sha256'],'independent full matrix + exact declared actual context acceptance')
  validate_bridge_acceptance(root,e,kind,grade,source_bridge,authored_source_sha,common,h)
  validate_final_context(root,e,kind,context,grade,common,con,h)
  if kind=='worker':
   require(sha(png)==WORKER['atlas'] and authored_source_sha==WORKER['source'] and generator['sha256']==WORKER['generator'] and stats['rgba_sha256']==WORKER['rgba'],'frozen accepted Worker art changed')
   outputs+=validate_worker_binding(root,e.get('physiology'),rgba,authored_source_sha,h)
  outputs.append(GAME+kind+'.png')
 family=h['safe_rel'](root,GAME.rstrip('/'),label='eight-actor owner')
 actual={p.relative_to(root).as_posix() for p in family.rglob('*') if p.is_file()}
 require(actual=={GAME+k+'.png'+suffix for k in KINDS for suffix in ['', '.import']},'unowned/missing file in exact8 actor family')
 for p in family.rglob('*'):require(not p.is_symlink(),'actor family symlink')
 validate_final_runtime(root,value,entries,h)
 require(len(outputs)==10,'8 PNG plus exact Worker metadata/mask owners')
 return {'status':'STRUCTURAL_EIGHT_ACTOR_LEDGER_VALID','actors':8,'cells':328,'runtime_outputs':outputs,'legacy_catalog_entries':119,'retained_preexisting_exports':140,'note':'Exact blob/receipt/ownership bindings only; no native execution/art-grade authentication or gameplay/package claim.'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=ROOT);a=p.parse_args()
 try:print('PASS: '+json.dumps(validate_ledger(a.root),sort_keys=True));return 0
 except (ValueError,OSError,KeyError,TypeError) as exc:print('FAIL: '+str(exc));return 1
if __name__=='__main__':raise SystemExit(main())
