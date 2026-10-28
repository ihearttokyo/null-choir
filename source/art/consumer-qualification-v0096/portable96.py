"""Portable evidence transport, not a new acceptance/qualification validator.
Uses the unchanged pinned producer and existing native relationship validator.
Private execution sources/logs remain SHA commitments, as in v094/v095 receipts.
This public module has generic privacy filters; custom prepublication deny terms
remain solely in the private packager.
"""
from pathlib import Path
import gzip,hashlib,importlib.util,json,re,stat,io,struct,zlib
PREFIX='source/art/consumer-qualification-v0096/'
SCHEMA='null-choir-v096-portable-context-package-v1'
ROLES={'producer','fixture','case_schema','source_manifest','station_view_map','original22_contract',
       'source_scout','source_scout_report','source_scout_near_mid','source_scout_review'}
HEX=re.compile(r'^[0-9a-f]{64}$')

def need(ok,message):
 if not ok:raise ValueError(message)
def sha(data):return hashlib.sha256(data).hexdigest()
def record(root,row):
 need(type(row)is dict and set(row)=={'path','bytes','sha256'} and type(row['bytes'])is int and row['bytes']>=0,'Exact portable artifact record required')
 rel=Path(row['path']);need(not rel.is_absolute() and '..' not in rel.parts and row['path'].startswith(PREFIX),'Portable artifact outside public evidence namespace')
 path=Path(root).resolve()/rel
 need(not any(p.is_symlink() for p in [path,*path.parents]) and stat.S_ISREG(path.lstat().st_mode) and not getattr(path.lstat(),'st_flags',0)&0x40000000,'Resident portable artifact required')
 data=path.read_bytes();need(len(data)==row['bytes'] and sha(data)==row['sha256'],'Portable artifact byte/hash drift: '+row['path']);return data

def _privacy_text(text):
 """Scan real text without changing original bytes; do not join undecodable bytes."""
 patterns=[r'/Users/',r'/home/',r'/private/(?:tmp|var)/',r'\\Users\\',r'\.codex/',
   r'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
   r'(?<!\w)\+[1-9][0-9][0-9 ()-]{6,}[0-9]',
   r'(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
   r'(?i)"(?:pid|ppid|pgid|argv|wrapper_argv|environment|access_token|refresh_token|password)"\s*:']
 texts=[text]
 try:texts.append(json.dumps(json.loads(text),ensure_ascii=False))
 except (ValueError,TypeError):pass
 texts += [value.replace(chr(92),'/') for value in texts]
 # Every match requires its literal sentinel. Check that cheap necessary
 # condition before the original regex: notably the unanchored email pattern
 # otherwise retries long numeric/hex runs at every offset of raw contexts.
 # Patterns and all raw/JSON-decoded/slash-normalized views remain unchanged.
 sentinels=['/Users/','/home/','/private/','\\Users\\','.codex/','@','+','-',':']
 need(not any(sentinel in value and re.search(pattern,value)
              for pattern,sentinel in zip(patterns,sentinels) for value in texts),
      'Privacy gate: retain raw artifact privately; do not auto-redact/re-sign')

PNG_SIGNATURE=b'\x89PNG\r\n\x1a\n'
MAX_PNG_BYTES=32*1024*1024
MAX_PNG_TEXT_BYTES=1024*1024

def _png_text_inflate(raw):
 inflater=zlib.decompressobj()
 text=inflater.decompress(raw,MAX_PNG_TEXT_BYTES+1)
 need(len(text)<=MAX_PNG_TEXT_BYTES and inflater.eof and not inflater.unused_data
      and not inflater.unconsumed_tail,'PNG text compression length/trailing stream refused')
 return text

def _png_scan_text(raw,codec):
 need(b'\0' not in raw,'PNG text cannot hide binary/NUL-encoded metadata')
 _privacy_text(raw.decode(codec))

def _png_privacy(data):
 """CRC/structure verified; inspect text metadata, never treat compressed pixels as text."""
 need(8<len(data)<=MAX_PNG_BYTES,'Bounded PNG required')
 offset=8;chunks=0;seen_IDAT=False;seen_IHDR=False;seen_IEND=False
 numeric={b'sRGB':1,b'gAMA':4,b'cHRM':32,b'pHYs':9,b'tIME':7}
 while offset<len(data):
  need(offset+12<=len(data) and chunks<4096 and not seen_IEND,'Malformed PNG chunk boundary')
  size=struct.unpack('>I',data[offset:offset+4])[0];kind=data[offset+4:offset+8]
  need(re.fullmatch(rb'[A-Za-z]{4}',kind) and offset+size+12<=len(data),'Malformed PNG chunk/type')
  payload=data[offset+8:offset+8+size];crc=struct.unpack('>I',data[offset+8+size:offset+12+size])[0]
  need(zlib.crc32(kind+payload)&0xffffffff==crc,'PNG CRC drift')
  need(seen_IHDR or kind==b'IHDR','PNG IHDR must be first')
  if kind==b'IHDR':
   need(not seen_IHDR and size==13,'Exact single PNG IHDR required');seen_IHDR=True
  elif kind==b'IDAT':seen_IDAT=True
  elif kind==b'IEND':need(size==0 and seen_IDAT,'PNG IEND/IDAT required');seen_IEND=True
  elif kind in numeric:need(size==numeric[kind],'PNG numeric metadata length drift')
  elif kind==b'PLTE':need(0<size<=768 and size%3==0,'PNG palette length drift')
  elif kind in {b'tRNS',b'bKGD',b'sBIT'}:
   need(0<size<={b'tRNS':256,b'bKGD':6,b'sBIT':4}[kind],'PNG color/alpha metadata length drift')
  elif kind in {b'tEXt',b'zTXt',b'iTXt'}:
   need(size<=MAX_PNG_TEXT_BYTES and b'\0' in payload,'Bounded PNG text metadata required')
   keyword,body=payload.split(b'\0',1);need(1<=len(keyword)<=79,'PNG text keyword required')
   _png_scan_text(keyword,'latin1')
   if kind==b'tEXt':_png_scan_text(body,'latin1')
   elif kind==b'zTXt':
    need(body[:1]==b'\0','PNG zTXt compression method required')
    _png_scan_text(_png_text_inflate(body[1:]),'latin1')
   else:
    need(len(body)>=2 and body[0] in (0,1) and body[1]==0,'PNG iTXt compression header required')
    compressed=body[0];parts=body[2:].split(b'\0',2)
    need(len(parts)==3,'PNG iTXt language/translated keyword boundaries required')
    language,translated,text=parts
    _png_scan_text(language,'ascii');_png_scan_text(translated,'utf8')
    text=_png_text_inflate(text) if compressed else text
    _png_scan_text(text,'utf8')
  else:raise ValueError('PNG metadata/chunk is not privacy-reviewed; keep artifact private')
  offset+=size+12;chunks+=1
 need(seen_IHDR and seen_IDAT and seen_IEND and offset==len(data),'Complete exact PNG stream required')

def privacy(data):
 """Never redact/reencode. PNG pixels are not user text; actual text fields are scanned.
 Other binary resources retain conservative UTF8-replacement scanning plus their
 independently required exact source/import-byte joins; no lossy-ignore concatenation.
 """
 if data.startswith(PNG_SIGNATURE):return _png_privacy(data)
 _privacy_text(data.decode('utf8',errors='replace'))

def load_producer(project_root,evidence_root,dependencies,emission,case_schema,*,trusted_producer_sha256):
 """Unchanged FINAL validator; only opaque per-case emission SHA expectations relocate.
 The ten public metadata files remain final/current. These three raw source
 commitments are not substituted executable source or execution authentication.
 """
 need(type(dependencies)is dict and set(dependencies)==ROLES,'Exactly ten public metadata roles required')
 need(type(emission)is dict and set(emission)=={'producer_sha256','fixture_sha256','capture_controller_sha256'}
      and all(HEX.fullmatch(v or '') for v in emission.values()),'Exact per-case emission SHA commitments required')
 need(HEX.fullmatch(trusted_producer_sha256 or '') and dependencies['producer']['sha256']==trusted_producer_sha256,'Externally trusted final producer SHA required before executable import')
 for row in dependencies.values():record(evidence_root,row)
 schema_raw=record(evidence_root,case_schema);privacy(schema_raw)
 need(json.loads(schema_raw).get('station_view_map_path')==Path(dependencies['station_view_map']['path']).name,'Exact local station-map basename required')
 paths={key:Path(evidence_root).resolve()/row['path'] for key,row in dependencies.items()}
 need(len({row['path'] for row in dependencies.values()})==10,'Distinct ten metadata files required')
 need(len({p.parent for p in paths.values()})==1,'Portable metadata must share one provenance directory')
 spec=importlib.util.spec_from_file_location('_portable_exact_v096_producer',paths['producer']);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 for key,value in {'HERE':paths['case_schema'].parent,'PROJECT':Path(project_root).resolve(),
  'SCHEMA_PATH':paths['case_schema'],'SOURCE_PINS_PATH':paths['source_manifest'],
  'ORIGINAL_CASES_PATH':paths['original22_contract'],'FIXTURE_PATH':paths['fixture'],'PRODUCER_PATH':paths['producer'],
  'SCOUT_PATH':paths['source_scout'],'SCOUT_REPORT_PATH':paths['source_scout_report'],
  'SCOUT_NEAR_MID_PATH':paths['source_scout_near_mid'],'SCOUT_REVIEW_PATH':paths['source_scout_review']}.items():setattr(m,key,value)
 schema_path=Path(evidence_root).resolve()/case_schema['path'];m.SCHEMA_PATH=schema_path
 original_build=m.build_job_contract;original_validate=m.validate_job_context
 fixed={'project':Path(project_root).resolve(),'schema_path':schema_path,'source_manifest_path':paths['source_manifest'],
        'fixture_path':paths['fixture'],'producer_path':paths['producer'],'controller_path':paths['producer']}
 def build(case_id,**kwargs):
  contract=original_build(case_id,**fixed)
  for key,value in emission.items():contract[key]=value
  return contract
 def validate(case_id,*,context_path,frames_dir,**kwargs):
  return original_validate(case_id,context_path=context_path,frames_dir=frames_dir,**fixed)
 m.build_job_contract=build;m.validate_job_context=validate
 return m

class ProjectionReader:
 """Internal views reuse existing payload checks; they are never raw guard proof."""
 def __init__(self,root,views):self.root=root;self.views=views
 def record(self,root,row):
  if row['path'] not in self.views:return record(self.root,row)
  data=self.views[row['path']];need(len(data)==row['bytes'] and sha(data)==row['sha256'],'Internal projection-view hash drift');return data

def validate_import_projection(evidence_root,row,commitments,manifest_sha,native_validator):
 raw_projection=record(evidence_root,row);privacy(raw_projection);projection=json.loads(raw_projection)
 need(set(projection)=={'schema','status','raw_import_proof_sha256','raw_import_guard_sha256','current_source_manifest_sha256',
  'strict_resource_guard','fresh_owned_closure','current_source_and_art_bytes_joined','actual_nine_imports','new_UIDs','actual_imported_cache','sidecars','files'},'Exact public import projection required')
 need(projection['schema']=='null-choir-v096-public-native-import-projection-v1' and projection['status']=='PUBLIC_PROJECTION_NOT_EXECUTION_AUTHENTICATION', 'Public import projection scope required')
 need(projection['raw_import_proof_sha256']==commitments['raw_import_proof_sha256'] and projection['raw_import_guard_sha256']==commitments['raw_import_guard_sha256']
  and all(HEX.fullmatch(projection[k] or '') for k in ['raw_import_proof_sha256','raw_import_guard_sha256'])
  and projection['current_source_manifest_sha256']==manifest_sha,'Public projection must preserve exact raw-private import/guard/source commitments')
 need(projection['strict_resource_guard'] is True and projection['fresh_owned_closure'] is True,'Reviewed guard summary required; raw guard stays private')
 # A transparent relationship-only view. Never claim its hash is the private
 # raw proof/guard hash; those commitments above remain separate and unchanged.
 guard=json.dumps({'strict_resource_guard':True,'fresh_owned_closure':True},sort_keys=True).encode()
 proof={k:projection[k] for k in ['current_source_manifest_sha256','current_source_and_art_bytes_joined','actual_nine_imports','new_UIDs','actual_imported_cache','sidecars']}
 proof.update(native_guard_sha256=sha(guard),qualification=False);raw=json.dumps(proof,sort_keys=True).encode()
 views={PREFIX+'__relationship_view/guard.json':guard,PREFIX+'__relationship_view/proof.json':raw}
 rows={key:{'path':path,'bytes':len(data),'sha256':sha(data)} for key,(path,data) in zip(['guard','proof'],views.items())}
 need(type(projection['files'])is dict and set(projection['files'])=={'generated_cache','sidecars','new_UIDs'},'Exact projected native artifact groups required')
 for group in projection['files'].values():
  need(type(group)is dict,'Projected native artifact map required')
  for artifact in group.values():privacy(record(evidence_root,artifact))
 binding={**rows,**projection['files']}
 native_validator(Path(evidence_root),binding,manifest_sha,ProjectionReader(evidence_root,views))
 return projection['raw_import_proof_sha256']

MAX_CONTEXT_BYTES=16*1024*1024

class ContextBytes:
 """One-method carrier: unchanged producer reads precisely these original bytes."""
 def __init__(self,raw):self.raw=raw
 def read_bytes(self):return self.raw

def context_bytes(root,row):
 need(type(row)is dict and set(row)=={'artifact','encoding','raw_bytes','raw_sha256'}
      and row['encoding']=='gzip' and type(row['raw_bytes'])is int
      and 0<row['raw_bytes']<=MAX_CONTEXT_BYTES and HEX.fullmatch(row['raw_sha256'] or ''),'Exact bounded gzip context transport required')
 packed=record(root,row['artifact'])
 need(len(packed)<=MAX_CONTEXT_BYTES,'Bounded compressed context required')
 with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream:
  raw=stream.read(row['raw_bytes']+1)
  need(len(raw)==row['raw_bytes'] and stream.read(1)==b'','Decompressed context length drift/overflow')
 need(sha(raw)==row['raw_sha256'],'Raw context SHA drift');privacy(raw);return raw

def validate_bundle(project_root,evidence_root,index,native_validator,*,trusted_producer_sha256):
 need(type(index)is dict and set(index)=={'schema','status','dependencies','commitments','native_import_projections','jobs','private_artifact_commitments','qualification','execution_authenticated'},'Exact portable evidence package index required')
 need(index['schema']==SCHEMA and index['status']=='PORTABLE_EVIDENCE_NOT_QUALIFICATION' and index['qualification'] is False and index['execution_authenticated'] is False,'Portable packaging is not acceptance or execution authentication')
 need(type(index['dependencies'])is dict and set(index['dependencies'])==ROLES,'Exactly ten public metadata roles required')
 for row in index['dependencies'].values():privacy(record(evidence_root,row))
 raw_commitments=record(evidence_root,index['commitments']);privacy(raw_commitments);commitments=json.loads(raw_commitments)
 need(type(commitments)is dict and set(commitments)=={'native_imports'} and type(commitments['native_imports'])is dict and commitments['native_imports'] and all(HEX.fullmatch(k or '') and HEX.fullmatch(v or '') for k,v in commitments['native_imports'].items()),'Only exact native proof/guard SHA commitments may be public')
 projections=index['native_import_projections'];need(type(projections)is dict and set(projections)==set(commitments['native_imports']),'Every distinct actual import projection required')
 for key,row in projections.items():
  validate_import_projection(evidence_root,row,{'raw_import_proof_sha256':key,'raw_import_guard_sha256':commitments['native_imports'][key]},index['dependencies']['source_manifest']['sha256'],native_validator)
 jobs=index['jobs'];need(type(jobs)is list and len(jobs)==22,'All22 portable jobs required')
 first=load_producer(project_root,evidence_root,index['dependencies'],jobs[0]['emission'],jobs[0]['case_schema'],trusted_producer_sha256=trusted_producer_sha256)
 schema,_=first.load_case_schema(Path(evidence_root)/index['dependencies']['case_schema']['path']);ids=[row['id'] for row in schema['cases']]
 need([job['id'] for job in jobs]==ids,'All22 original ordered portable context jobs required')
 for job in jobs:
  need(type(job)is dict and set(job)=={'id','context','frames','trace_join','raw_guard_sha256','raw_result_sha256','emission','native_import_sha256','case_schema'},'Exact portable job/commitments required')
  need(HEX.fullmatch(job['raw_guard_sha256'] or '') and HEX.fullmatch(job['raw_result_sha256'] or ''),'Raw per-job process/result commitments required')
  raw_import_sha=job['native_import_sha256'];need(raw_import_sha in projections,'Per-case actual native import commitment missing')
  context_raw=context_bytes(evidence_root,job['context']);ctx=json.loads(context_raw)
  folder=PREFIX+'cases/'+job['id']+'/'
  need(job['context']['artifact']['path']==folder+'context.json.gz' and job['trace_join']['path']==folder+'TRACE-JOIN.json','Exact portable case layout required')
  expected=[{'path':folder+frame['file'],'bytes':frame['bytes'],'sha256':frame['PNG_sha256']} for frame in ctx['frames']]
  need(job['frames']==expected,'Portable PNG ordering/hash must remain byte-exact to raw context')
  for frame in job['frames']:privacy(record(evidence_root,frame))
  privacy(record(evidence_root,job['case_schema']))
  m=load_producer(project_root,evidence_root,index['dependencies'],job['emission'],job['case_schema'],trusted_producer_sha256=trusted_producer_sha256)
  validation=m.validate_job_context(job['id'],context_path=ContextBytes(context_raw),frames_dir=Path(evidence_root)/folder)
  joined_raw=record(evidence_root,job['trace_join']);privacy(joined_raw);joined=json.loads(joined_raw)
  need(joined=={'validation':validation,'fresh_import_join_sha256':raw_import_sha,'independent_pixels':'PENDING','qualification':False},'Raw TRACE-JOIN must preserve actual private import proof commitment and exact producer validation')
 need(set(projections)=={job['native_import_sha256'] for job in jobs},'No missing or unused native projection generation allowed')
 need(type(index['private_artifact_commitments'])is dict
      and all(re.fullmatch(r'[a-z][a-z0-9_]{0,63}',k or '') and HEX.fullmatch(v or '') for k,v in index['private_artifact_commitments'].items()),'Private artifacts must be logical names and SHA commitments only')
 return {'status':'PORTABLE_CONTEXT_RELATIONSHIPS_VALIDATED_NOT_QUALIFICATION','cases':22,'qualification':False,'execution_authenticated':False}
