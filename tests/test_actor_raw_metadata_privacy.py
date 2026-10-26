"""Pure public raw-PNG privacy/retained-provenance regression; no native tools.
ACTOR_METADATA_BASE_ROOT supports a reviewed sparse COPY overlay during prep;
normal CI omits it and validates the canonical checkout without overlays.
"""
from pathlib import Path
import copy,importlib.util,json,os,re,struct,unittest,zlib
from unittest.mock import patch
P=Path(__file__).resolve().parents[1]
BASE=Path(os.environ.get('ACTOR_METADATA_BASE_ROOT',str(P))).absolute()
s=importlib.util.spec_from_file_location('actor_raw_metadata_candidate',P/'tools/actor_body_art_ledger.py');v=importlib.util.module_from_spec(s);s.loader.exec_module(v)
H=v.helpers(BASE) # Helpers always loaded from the exact pinned canonical root.
if P!=BASE:
 original_safe=H['safe_rel']
 def sparse(root,relative,**kw):
  selected=P if (P/relative).is_file() else Path(root)
  return original_safe(selected,relative,**kw)
 H['safe_rel']=sparse

def read(path):return H['safe_rel'](BASE,path,label='privacy test input',allowed_roots={'source','game','tools'}).read_bytes()
ENTRIES={e['kind']:e for e in json.loads(read(v.LEDGER))['actors']}
def actual(k,e=None,n=None):
 E=ENTRIES[k] if e is None else e;N=v.receipt(BASE,E,'source-native',k,H) if n is None else n;source=read(E['source_blend']['path']);common={key:N[key] for key in ['source_blend_sha256','generator_sha256','atlas_sha256','rgba_sha256','cell_rgba_sha256']};con=v.contract(k)
 authored,bridge=v.validate_public_source_bridge(BASE,E,k,source,N,common,con,H)
 return v.validate_raw_metadata_bridge(BASE,E,k,N,authored,bridge,con,H)
def chunks(encoded):
 assert encoded[:8]==b'\x89PNG\r\n\x1a\n';pos=8;result=[]
 while pos<len(encoded):
  n=int.from_bytes(encoded[pos:pos+4],'big');assert pos+n+12<=len(encoded);typ=encoded[pos+4:pos+8];payload=encoded[pos+8:pos+8+n];crc=int.from_bytes(encoded[pos+8+n:pos+12+n],'big');assert zlib.crc32(typ+payload)&0xffffffff==crc
  result.append((typ,payload));pos+=n+12
 assert pos==len(encoded) and result[-1][0]==b'IEND';return result
class RawMetadataPrivacy(unittest.TestCase):
 def test_all328_public_raw_PNGs_have_no_File_text_or_private_filepath(self):
  count=0
  self.assertEqual(set(ENTRIES),set(v.KINDS));self.assertEqual(set(v.RAW_METADATA_PINS),set(v.KINDS))
  for k,e in ENTRIES.items():
   for frame in e['frames']:
    path=frame['raw']['path'];_,b=v.checked(BASE,frame['raw'],path,H)
    with self.subTest(path=path):
     self.assertFalse(re.search(rb'/(?:Users|home)/|file://|[A-Za-z]:[\\/]Users[\\/]',b,re.I))
     self.assertFalse(any(t==b'tEXt' and p.split(b'\0',1)[0]==b'File' for t,p in chunks(b)))
     self.assertEqual(v.sha(v.pixels(b,v.contract(k)['cell_size'],H,path)),frame['raw_rgba_sha256'])
    count+=1
  self.assertEqual(count,328)
 def test_all8_exact_receipts_native_source_and_sample_joins(self):
  self.assertEqual(sum(len(actual(k)['frames']) for k in v.KINDS),328)
 def test_old3_missing_tampered_rehashed_or_repointed_receipt_rejected(self):
  for k in ['worker','crawler','brute']:
   for how in ['missing','zero','rehashed','path','bytes','unknown']:
    e=copy.deepcopy(ENTRIES[k]);r=e['raw_png_metadata_bridge']
    if how=='missing':e.pop('raw_png_metadata_bridge')
    elif how=='zero':r['sha256']='0'*64
    elif how=='rehashed':r['sha256']=v.sha(b'tampered receipt with updated reference')
    elif how=='path':r['path']=r['path'].replace(k,'caster')
    elif how=='bytes':r['bytes']=True
    else:r['exception']=True
    with self.subTest(kind=k,mutation=how),self.assertRaises(ValueError):actual(k,e=e)
 def test_old3_unknown_scope_row_keys_order_types_and_source_report_rejected(self):
  original=v.doc
  mutations=[lambda d:d.update(extra_exception=True),lambda d:d.update(original_encoded_SHA_authority='Native-time encoded SHA inventory'),lambda d:d.update(new_native_runs=True),lambda d:d.update(original_source_blend_sha256='0'*64),lambda d:d['retained_original_source_native'].update(sha256='0'*64),lambda d:d['frames'].reverse(),lambda d:d['frames'].pop(),lambda d:d['frames'][0].update(frame=True),lambda d:d['frames'][0].update(pixel_reencoded=0),lambda d:d['frames'][0].update(removed_keyword='Other'),lambda d:d['frames'][0].update(extra=True),lambda d:d['frames'][0]['public_raw'].update(sha256='0'*64)]
  for k in ['worker','crawler','brute']:
   for i,change in enumerate(mutations):
    def altered(root,record,path,h):
     d=original(root,record,path,h)
     if path.endswith('/raw-PNG-File-metadata-bridge.json'):d=copy.deepcopy(d);change(d)
     return d
    with self.subTest(kind=k,mutation=i),patch.object(v,'doc',side_effect=altered),self.assertRaises(ValueError):actual(k)
   n=v.receipt(BASE,ENTRIES[k],'source-native',k,H);n=copy.deepcopy(n);n['actual_native_jobs']=[]
   with self.subTest(kind=k,mutation='invented-native-job-list'),self.assertRaises(ValueError):actual(k,n=n)
 def test_full_actual_ledger_8_328_119_140(self):
  with patch.object(v,'helpers',return_value=H):result=v.validate_ledger(BASE)
  self.assertEqual((result['actors'],result['cells'],result['legacy_catalog_entries'],result['retained_preexisting_exports']),(8,328,119,140))
if __name__=='__main__':unittest.main(verbosity=2)
