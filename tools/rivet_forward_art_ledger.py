"""Strict single-owner native Rivet atlas contract; read-only, no engine execution.

The retained raster validator is loaded ONLY for pure PNG/path/JSON helpers.
Never call its validate_ledger: that validator calls this one for the exact
index-1 alternate, and continues guarding all six retained raster outputs.
Native receipts are structurally bound evidence, not authentication of a run.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]
HELPERS = runpy.run_path(str(ROOT / 'source/art/weapon-raster-v3/validate_ledger.py'))
ContractError, fail = HELPERS['ContractError'], HELPERS['fail']
safe_rel, read_json = HELPERS['safe_rel'], HELPERS['read_json']
reject_private = HELPERS['_reject_private_strings']
png_rgba = HELPERS['png_rgba']
LEDGER = 'source/art/rivet-forward-v4/ledger.json'
FAMILY = 'source/art/rivet-forward-v4/'
OUTPUT = 'game/assets/art/weapons/native-v4/rivet_pistol.png'
SOURCE = FAMILY + 'rivet_pistol.blend'
SOURCE_SHA = '99b0882a1b1b9bd1952668cfe645ad3c3a46327fe3d0fb4664341bf683420b56'
OUTPUT_SHA = '9470e33b6c9a33127afb554a1848310c42d0cfd4bab1e05cbbe33a0495524618'
HUD_SHA = '44e466410c46d72431228923082318eb65618b283b5ae86106d02ae981a587f7'
MANIFEST_SHA = 'c9d03e761c85cb24cf2aeb711e04d255201ce85fb08e546e0184834cd8c3a928'
RASTER_SHA = 'a1700b645eaf15185ce0c50cde53bdbd33c1357f9cb794730e24c174b00fbfa5'
PAINTED_SHA = '67a47dfd915feaadbe5cf0602aa723f2a1048c368fabf72f7055d20edfbc3417'
ORIGINAL_SOURCE_SHA = 'b29ac487f2339a7668a7207f84159ad8da4a5aca27803f5349d12ae50a57e3aa'
ORIGINAL_OUTPUT_SHA = 'e774365b70615e5e1efeff1cb0b3264100fc9ed43735a8d389f1048329d47a17'
IDS = ('impact_tool', 'rivet_pistol', 'scattergun', 'sawtooth_repeater', 'marrow_launcher', 'choir_disruptor')
FRAMES = ['idle', 'fire', 'recover']
CONTRACT = {'atlas':[960,200], 'cell_size':[320,200], 'columns':3, 'frames':FRAMES,
            'alpha':[0,255], 'origin_px':[160,200], 'muzzle_px':[140,62],
            'neutral_vanishing_point_px':[140,37], 'hud_destination':[180,143,320,200], 'filter':'nearest'}
LINEAGE = {
 'legacy_manifest':{'path':'source/art/manifest.json','sha256':MANIFEST_SHA},
 'raster_ledger':{'path':'source/art/weapon-raster-v3.json','sha256':RASTER_SHA},
 'retained_painted_output':{'path':'game/assets/art/weapons/painted-v3/rivet_pistol.png','sha256':PAINTED_SHA},
 'original_native_source':{'path':'source/art/rivet_pistol_v2.blend','sha256':ORIGINAL_SOURCE_SHA},
 'original_native_output':{'path':'game/assets/art/weapons/rivet_pistol.png','sha256':ORIGINAL_OUTPUT_SHA}}

PUBLIC_INPUT_PATHS = ('game/assets/art/weapons/native-v4/rivet_pistol.png', 'source/art/rivet-forward-v4/README.md', 'source/art/rivet-forward-v4/construction/camera_model_detailed.py', 'source/art/rivet-forward-v4/construction/detailed_geometry_repair.py', 'source/art/rivet-forward-v4/construction/finish_material_source02.py', 'source/art/rivet-forward-v4/construction/materials-after.json', 'source/art/rivet-forward-v4/construction/materials-before.json', 'source/art/rivet-forward-v4/construction/patch_detailed_repair.py', 'source/art/rivet-forward-v4/construction/patch_detailed_source.py', 'source/art/rivet-forward-v4/export_native.py', 'source/art/rivet-forward-v4/frames/fire.png', 'source/art/rivet-forward-v4/frames/idle.png', 'source/art/rivet-forward-v4/frames/recover.png', 'source/art/rivet-forward-v4/masters/fire-native-render.png', 'source/art/rivet-forward-v4/masters/idle-native-render.png', 'source/art/rivet-forward-v4/masters/recover-native-render.png', 'source/art/rivet-forward-v4/proof/hud-fire.png', 'source/art/rivet-forward-v4/proof/hud-idle.png', 'source/art/rivet-forward-v4/proof/hud-recover.png', 'source/art/rivet-forward-v4/proof/native-hud.json', 'source/art/rivet-forward-v4/proof/native-poses.json', 'source/art/rivet-forward-v4/proof/portable-exporter-static.json', 'source/art/rivet-forward-v4/proof/source-privacy-editability.json', 'source/art/rivet-forward-v4/qualification.json', 'source/art/rivet-forward-v4/registration.json', 'source/art/rivet-forward-v4/rivet_pistol.blend')

def sha(data): return hashlib.sha256(data).hexdigest()

def same(value, expected):
    """JSON contract equality without bool/int or float/int substitution."""
    if type(value) is not type(expected): return False
    if isinstance(expected,dict):
        return value.keys()==expected.keys() and all(same(value[k],v) for k,v in expected.items())
    if isinstance(expected,list):
        return len(value)==len(expected) and all(same(a,b) for a,b in zip(value,expected))
    return value==expected

def checked(root, record, expected_path, expected_sha=None):
    if not isinstance(record,dict) or record.get('path') != expected_path:
        fail('exact referenced path required: '+expected_path)
    digest = record.get('sha256')
    if not isinstance(digest,str) or not re.fullmatch('[0-9a-f]{64}',digest):
        fail('PENDING or malformed hash: '+expected_path)
    if expected_sha is not None and digest != expected_sha:
        fail('accepted lineage hash mismatch: '+expected_path)
    path = safe_rel(root, expected_path, label='native Rivet reference', allowed_roots={'source','game'})
    if not path.is_file(): fail('required public file missing: '+expected_path)
    data = path.read_bytes()
    if sha(data) != digest: fail('file hash mismatch: '+expected_path)
    return path, data

def validate_source(data):
    if len(data)!=219389 or sha(data)!=SOURCE_SHA or not data.startswith((b'BLENDER',b'\x28\xb5\x2f\xfd')):
        fail('accepted editable native source bytes/hash/container mismatch')

def validate_atlas(data):
    dims, pixels = png_rgba(data, label='native Rivet atlas')
    if dims!=(960,200): fail('native Rivet dimensions must be960x200')
    if set(pixels[3::4])!={0,255}: fail('native Rivet alpha must be binary0/255')
    cells=[]
    for i in range(3):
        cell=b''.join(pixels[(y*960+i*320)*4:(y*960+i*320+320)*4] for y in range(200))
        if set(cell[3::4])!={0,255} or sum(a==255 for a in cell[3::4])<80:
            fail('each native pose must contain transparent and visible pixels')
        cells.append(sha(cell))
    if len(set(cells))!=3: fail('three distinct native poses required')
    if sha(data)!=OUTPUT_SHA or len(data)!=41941: fail('accepted native atlas bytes/hash mismatch')
    return {'dimensions':list(dims),'rgba8_pixel_sha256':sha(pixels),'pose_rgba8_sha256':cells}


CONSUMER_COMPAT_SHA = "25a8648955c1406180e4e753ae96a5c1a2bd404ec71a5af48e8fe48b9b5ed5ad"
def consumer_compatibility(root):
    path=safe_rel(Path(root),"tools/art_consumer_compatibility.py",label="exact current consumer helper",allowed_roots={"tools"})
    if path.is_symlink() or sha(path.read_bytes())!=CONSUMER_COMPAT_SHA: fail("exact reviewed consumer compatibility helper required")
    return runpy.run_path(str(path))

V5_GUARD_SHA = "da3d3de947ef6735b6aefc0835502a01d811ba41edc8c367ab4b1db18d68ebc8"
def v5_guard(root):
    path=Path(root)/"source/art/rivet-forward-v5/validate_ledger.py"
    if path.is_symlink() or sha(path.read_bytes())!=V5_GUARD_SHA: fail("exact reviewed v5 validator required")
    return runpy.run_path(str(path))
def validate_pistol_player_compatibility(root,current,descriptor=None):
    v5=v5_guard(root)
    v5["validate"](root,globals())
    doc=read_json(Path(root)/"source/art/rivet-forward-v5/ledger.json")
    declared=doc["player_compatibility"]
    if descriptor is not None and not same(descriptor,declared): fail("exact shared Player compatibility descriptor required")
    return v5["normalize_consuming_player"](root,current,declared,globals())

def validate_player(text, *, native=True):
    records=re.findall(r'\{"name":"[^"]+","asset":"([^"]+)"[^}]*\}',text)
    expected=['painted-v3/'+name for name in IDS]
    if native: expected[1]='native-v4/rivet_pistol'
    if records!=expected:
        fail('only weapon index1 may use native-v4/rivet_pistol; other five positions must remain exact')

def validate_v4_player_consumption(root,current):
    """Preserve v4 layout; later v5 consumers must qualify before normalization.

    The layout selects an audit route, never authorizes the supplied bytes.
    validate_pistol_player_compatibility retains all v5 art/receipt checks and
    its normalize_consuming_player requires exact qualified96 consumption before
    calling the frozen historical one-byte normalize_player.
    """
    records=re.findall(r'\{"name":"[^\"]+","asset":"([^\"]+)"[^}]*\}',current.decode('utf-8'))
    later=['painted-v3/'+name for name in IDS];later[1]='native-v5/rivet_pistol'
    replacement_outputs=[]
    if sha(current)=="0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7" or records==later:
        current=validate_pistol_player_compatibility(root,current)
        replacement_outputs=["game/assets/art/weapons/native-v5/rivet_pistol.png"]
    validate_player(current.decode('utf-8'))
    return replacement_outputs

def validate_lineage(root, value):
    if not same(value,LINEAGE): fail('exact retained original/legacy/raster lineage required')
    for key,record in LINEAGE.items(): checked(root,record,record['path'],record['sha256'])
    catalog=read_json(root/LINEAGE['legacy_manifest']['path'])
    if len(catalog.get('assets',[]))!=119: fail('all119 historic catalog entries must remain')
    raster=read_json(root/LINEAGE['raster_ledger']['path'])
    rows=raster.get('assets',[])
    if len(rows)!=6 or {r.get('id') for r in rows}!=set(IDS): fail('all six raster owners must remain')
    for row in rows:
        path='game/assets/art/weapons/painted-v3/'+row['id']+'.png'
        checked(root,row.get('output'),path)
    return raster

def validate_registration(doc, pixels):
    expected={'schema_version':1,'kind':'native-forward-rivet-registration',
              'source_sha256':SOURCE_SHA,'atlas_sha256':OUTPUT_SHA,
              'runtime_contract':CONTRACT,'pose_rgba8_sha256':pixels['pose_rgba8_sha256']}
    if any(not same(doc.get(k),v) for k,v in expected.items()):
        fail('native registration source/atlas/three-pose/origin/muzzle/VP mismatch')

def receipt(root, asset, key, filename):
    path,_=checked(root,asset.get(key),FAMILY+filename)
    doc=read_json(path);reject_private(doc,key)
    return doc

def check_native_directory(root):
    folder=safe_rel(root,'game/assets/art/weapons/native-v4',label='single native owner')
    actual=set()
    for p in folder.rglob('*'):
        if p.is_symlink(): fail('native owner family may not contain symlinks')
        if p.suffix.lower()=='.png': actual.add(p.relative_to(root).as_posix())
    if actual!={OUTPUT}: fail('unowned PNG in single-asset native-v4 family')

def _active_config_line(line):
    """Strip Godot comments only outside quoted strings."""
    quoted=escaped=False
    for index,char in enumerate(line):
        if escaped:
            escaped=False
        elif quoted and char=='\\':
            escaped=True
        elif char=='"':
            quoted=not quoted
        elif not quoted and char in '#;':
            return line[:index].strip()
    return line.strip()

def active_import_assignments(text):
    """Narrow active Godot .import assignments, not token substring matching.

    Native remap metadata is a multiline dictionary; consume it as one value,
    never as section/key declarations. Required keys are decoded separately.
    """
    sections={};section=None;lines=text.splitlines();index=0
    while index<len(lines):
        line=_active_config_line(lines[index]);index+=1
        if not line: continue
        header=re.fullmatch(r'\[([A-Za-z_][A-Za-z0-9_]*)\]',line)
        if header:
            section=header.group(1)
            if section not in {'remap','deps','params'} or section in sections:
                fail('unknown/duplicate active Godot import section')
            sections[section]={}
            continue
        assignment=re.fullmatch(r'([A-Za-z_][A-Za-z0-9_./-]*)\s*=\s*(.+)',line)
        if section is None or assignment is None: fail('malformed active Godot import assignment')
        key,value=assignment.groups()
        if key in sections[section]: fail('duplicate active Godot import key: '+section+'.'+key)
        if value.startswith('{'):
            if section!='remap' or key!='metadata': fail('unsupported Godot import multiline value')
            while True:
                try:
                    metadata=json.loads(value,object_pairs_hook=HELPERS['_pairs'])
                    break
                except json.JSONDecodeError:
                    if index>=len(lines): fail('malformed multiline Godot remap metadata')
                    value+='\n'+_active_config_line(lines[index]);index+=1
            if not isinstance(metadata,dict): fail('Godot remap metadata must be a dictionary')
        sections[section][key]=value
    if set(sections)!={'remap','deps','params'}: fail('required active Godot import sections missing')
    return sections

def validate_import_sidecar(text):
    sections=active_import_assignments(text)
    def value(section,key):
        raw=sections[section].get(key)
        if raw is None: fail('required active Godot import key missing: '+section+'.'+key)
        if raw.startswith('PackedStringArray(') and raw.endswith(')'):
            raw='['+raw[len('PackedStringArray('):-1]+']'
        try: return json.loads(raw,object_pairs_hook=HELPERS['_pairs'])
        except json.JSONDecodeError: fail('invalid active Godot import value: '+section+'.'+key)
    required={'remap':{'importer':'texture','type':'CompressedTexture2D'},
              'deps':{'source_file':'res://assets/art/weapons/native-v4/rivet_pistol.png'},
              'params':{'compress/mode':0,'mipmaps/generate':False,'process/premult_alpha':False,'process/fix_alpha_border':False}}
    for section,keys in required.items():
        for key,expected in keys.items():
            if not same(value(section,key),expected): fail('active Godot import setting mismatch: '+section+'.'+key)
    uid=value('remap','uid')
    if not isinstance(uid,str) or not re.fullmatch(r'uid://[a-z0-9]+',uid): fail('actual native texture UID missing')
    imported=value('remap','path')
    if not isinstance(imported,str) or not re.fullmatch(r'res://\.godot/imported/rivet_pistol\.png-[0-9a-f]{32}\.ctex',imported):
        fail('exact native imported resource destination missing')
    if not same(value('deps','dest_files'),[imported]): fail('active native import destination binding mismatch')
    return uid,imported

def validate_public_inputs(root, records):
    if not isinstance(records,list) or len(records)!=len(PUBLIC_INPUT_PATHS):
        fail('exact26 public native-family inputs required')
    if any(not isinstance(r,dict) or set(r)!={'path','sha256','bytes'} for r in records):
        fail('strict public native input hash/size records required')
    paths=[r['path'] for r in records]
    if len(set(paths))!=len(paths) or set(paths)!=set(PUBLIC_INPUT_PATHS):
        fail('unknown/missing/duplicate public native-family input')
    for record in records:
        path,data=checked(root,record,record['path'])
        if not same(record['bytes'],len(data)):
            fail('public native input size mismatch: '+record['path'])
        if path.suffix=='.json': reject_private(read_json(path),record['path'])

def validate_ledger(root: Path, ledger_path=LEDGER):
    root=Path(root).absolute()
    if isinstance(ledger_path,Path):
        try: ledger_path=ledger_path.absolute().relative_to(root).as_posix()
        except ValueError: fail('native ledger outside repository')
    if ledger_path!=LEDGER: fail('only exact canonical native Rivet ledger accepted')
    path=safe_rel(root,LEDGER,label='native Rivet ledger',allowed_roots={'source'})
    doc=read_json(path);reject_private(doc)
    if not same(doc.get('schema_version'),1) or doc.get('kind')!='one-native-forward-rivet-atlas':
        fail('unsupported native Rivet ledger schema')
    assets=doc.get('assets')
    if not isinstance(assets,list) or len(assets)!=1 or not isinstance(assets[0],dict): fail('exactly one native owner required')
    asset=assets[0]
    if asset.get('id')!='rivet_pistol' or not same(asset.get('weapon_index'),1):
        fail('exact native Rivet identity/index1 required')
    if asset.get('runtime_uri')!='res://assets/art/weapons/native-v4/rivet_pistol.png' or asset.get('player_asset_path')!='native-v4/rivet_pistol':
        fail('exact native runtime URI/Player asset required')
    if not same(doc.get('runtime_contract'),CONTRACT): fail('exact three-pose native runtime contract required')
    _,data=checked(root,asset.get('output'),OUTPUT,OUTPUT_SHA)
    pixels=validate_atlas(data)
    if not same(asset['output'],{'path':OUTPUT,'sha256':OUTPUT_SHA,'bytes':len(data),**pixels}): fail('output byte/pixel/pose binding mismatch')
    check_native_directory(root)
    player_path=safe_rel(root,'game/scripts/player.gd',label='actual Player')
    replacement_outputs=validate_v4_player_consumption(root,player_path.read_bytes())
    # Frozen v4 receipts still describe their historical HUD. Separately prove
    # the exact current generation before consulting its retained Git snapshot.
    current_hud=safe_rel(root,'game/scripts/hud.gd',label='actual HUD').read_bytes()
    if sha(current_hud)==HUD_SHA:
        hud_path,hud=checked(root,doc.get('hud'), 'game/scripts/hud.gd',HUD_SHA)
    else:
        if not same(doc.get('hud'),{'path':'game/scripts/hud.gd','sha256':HUD_SHA}): fail('unchanged historical HUD reference required')
        hud=consumer_compatibility(root)['historical'](root,'game/scripts/hud.gd',HUD_SHA)
    hud_text=hud.decode('utf-8')
    if HELPERS['HUD_NEAREST'] not in hud_text or HELPERS['HUD_ASSET_CONSUMER'] not in hud_text or 'Vector2(180,143)' not in hud_text or 'Rect2(frame*320,0,320,200)' not in hud_text:
        fail('actual nearest HUD/profile/three-frame destination consumer mismatch')
    validate_public_inputs(root,doc.get('public_inputs'))
    validate_lineage(root,doc.get('lineage'))
    _,source=checked(root,asset.get('source'),SOURCE,SOURCE_SHA)
    validate_source(source)
    if not same(asset['source'].get('bytes'),len(source)): fail('editable source size mismatch')
    reg=receipt(root,asset,'registration','registration.json');validate_registration(reg,pixels)
    frames=reg.get('frame_pngs')
    if not isinstance(frames,list) or len(frames)!=3: fail('three retained native frame PNGs required')
    for index,name in enumerate(FRAMES):
        _,data=checked(root,frames[index],FAMILY+'frames/'+name+'.png')
        dimensions,frame_pixels=png_rgba(data,label='retained native pose '+name)
        if dimensions!=(320,200) or sha(frame_pixels)!=pixels['pose_rgba8_sha256'][index] or not same(frames[index].get('bytes'),len(data)):
            fail('retained native frame PNG differs from accepted atlas pose')

    qual=receipt(root,asset,'qualification','qualification.json')
    for key,value in {'schema_version':1,'status':'PASS','source_sha256':SOURCE_SHA,'atlas_sha256':OUTPUT_SHA,
                      'hud_sha256':HUD_SHA,'failures':0,'three_native_poses_verified':True,'actual_hud_verified':True}.items():
        if not same(qual.get(key),value): fail('native pose/HUD qualification mismatch: '+key)
    images=qual.get('actual_hud_images')
    if not isinstance(images,list) or len(images)!=3: fail('three actual HUD evidence PNGs required')
    for index,name in enumerate(FRAMES):
        _,data=checked(root,images[index],FAMILY+'proof/hud-'+name+'.png')
        dimensions,_=png_rgba(data,label='actual HUD evidence '+name)
        if dimensions!=(640,360) or not same(images[index].get('bytes'),len(data)): fail('actual HUD evidence dimensions/bytes mismatch')
    sidecar=asset.get('import_sidecar')
    _,sidecar_bytes=checked(root,sidecar,OUTPUT+'.import')
    text=sidecar_bytes.decode('utf-8')
    uid,imported=validate_import_sidecar(text)
    imp=receipt(root,asset,'native_import','native-import.json')
    expected={'schema_version':1,'status':'PASS','failures':0,'driver':'Dummy','source_file':'res://assets/art/weapons/native-v4/rivet_pistol.png',
              'png_sha256':OUTPUT_SHA,'sidecar_sha256':sha(sidecar_bytes),'uid':uid, 'dimensions':[960,200], 'imported_path':imported, 'rgba8_pixel_sha256':pixels['rgba8_pixel_sha256'],
              'pose_rgba8_sha256':pixels['pose_rgba8_sha256'], 'bit_exact_rgba_to_source':True, 'binary_alpha':True}
    if any(not same(imp.get(k),v) for k,v in expected.items()): fail('native import receipt/UID/sidecar/PNG binding mismatch')
    if not isinstance(imp.get('godot_version'),str) or not imp['godot_version'].startswith('4.') or type(imp.get('imported_bytes')) is not int or imp['imported_bytes']<=0 or not re.fullmatch('[0-9a-f]{64}',str(imp.get('imported_sha256',''))):
        fail('actual native Godot version/imported resource byte proof missing')
    if doc.get('status')!='QUALIFIED': fail('PENDING native source/qualification/import; no production acceptance')
    return {'status':'STRUCTURAL_SINGLE_NATIVE_RIVET_VALID','entries':1,'runtime_outputs':[OUTPUT]+replacement_outputs,
            'retained_raster_outputs':6,'legacy_catalog_entries':119,'native_receipt_bound':True,
            'note':'Structural exact-file/native-receipt bindings only; not artwork, human input, performance or packed-app authentication.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    args=parser.parse_args()
    try: print('PASS: '+json.dumps(validate_ledger(args.root),sort_keys=True))
    except (ValueError,OSError) as exc: print('FAIL: '+str(exc));return 1
    return 0
if __name__=='__main__': raise SystemExit(main())
