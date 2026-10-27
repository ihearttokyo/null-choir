"""One exact v5 owner. Missing actual import/fullHUD/world/independent evidence FAILS."""
import hashlib,json,runpy,sys,re,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
need_common=hashlib.sha256((HERE/"common.py").read_bytes()).hexdigest()=="9368ce25e3a4cee9144a7a9defce08770a090ec4eba6e623d0f07531e50f5837"
if not need_common:raise ValueError("Exact original pure helper SHA required")
spec=importlib.util.spec_from_file_location("rivet_v5_exact_common",HERE/"common.py");c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
FAMILY="source/art/rivet-forward-v5/"
OUTPUT="game/assets/art/weapons/native-v5/rivet_pistol.png"
OLD_PLAYER="d3ff20a302f8ead0f6808683e6ccdd9a2b3f10f711b019fe9808a788faef7bff"
NEW_PLAYER="0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7"
ATLAS="6f0dec2a2b9634a69ed6f44a7056e20ac41a74a4cabbd6116a0a7716c809f001"
def need(ok,message):
 if not ok:raise ValueError(message)
def pairs(items):
 d={}
 for k,v in items:
  need(k not in d,"Duplicate JSON key");d[k]=v
 return d
def read_json(path):return json.loads(Path(path).read_text(),object_pairs_hook=pairs)
def record(root,r,path):
 need(type(r) is dict and r.get("path")==path and type(r.get("bytes")) is int and r["bytes"]>0,"Exact path/bytes record")
 p=Path(root)/path;need(not Path(path).is_absolute() and ".." not in Path(path).parts,"Public-relative path")
 need(not any(x.is_symlink() for x in [p,*p.parents]),"No symlink provenance")
 s=p.lstat();need(p.is_file() and not getattr(s,"st_flags",0)&0x40000000,"Regular resident source only")
 b=p.read_bytes();need(len(b)==r["bytes"] and c.sha(b)==r.get("sha256"),"Blob SHA/size mismatch: "+path);return b
def normalize_player(root,current,descriptor):
 value=json.loads(record(root,descriptor,FAMILY+"proof/player-uri-only-compatibility.json"))
 need(value.get("schema")=="exact-player-rivet-uri-compatibility-v1" and value.get("source_path")=="game/scripts/player.gd","One typed Player bridge only")
 need(value.get("historical_sha256")==OLD_PLAYER and value.get("current_sha256")==NEW_PLAYER,"Only frozen old/current pair")
 need(value.get("snapshot")==FAMILY+"provenance/player-before-v5.gd","Exact historical Player snapshot path")
 old=record(root,{"path":value["snapshot"],"bytes":15851,"sha256":OLD_PLAYER},value["snapshot"])
 a=b'"asset":"native-v4/rivet_pistol"';b=b'"asset":"native-v5/rivet_pistol"'
 need(c.sha(old)==OLD_PLAYER and c.sha(current)==NEW_PLAYER and old.count(a)==1 and old.count(b)==0,"Pinned Player source pair")
 need(value.get("exact_old_utf8")==a.decode() and value.get("exact_new_utf8")==b.decode() and type(value.get("occurrences")) is int and value["occurrences"]==1 and type(value.get("changed_bytes")) is int and value["changed_bytes"]==1,"Only the exact one-byte URI replacement")
 need(current==old.replace(a,b,1) and current.replace(b,a,1)==old,"All unrelated Player bytes must roundtrip")
 return old
BRIDGE_SHA="269bfe871808e1eaeb6281ca2c78af1e7e6baaf16c93e49e915a1c1f0c1d7b27"
SOURCE_PBR_SHA="a2e44bb23ae92e1f7374b66d10b422e5500e6eaf13a1c1b322df512510caa3fe"
def validate_metadata_bridge(root,value):
 raw=record(root,value.get("raw_png_metadata_bridge"),FAMILY+"proof/raw-PNG-File-metadata-bridge.json")
 need(c.sha(raw)==BRIDGE_SHA,"Exact independently reviewed metadata bridge; no repinning")
 bridge=json.loads(raw)
 need(set(bridge)=={"schema","status","new_native_runs","source_sha256","frames"} and bridge["schema"]=="rivet-v5-exact-raw-File-metadata-bridge-v1" and bridge["status"]=="PASS_PURE_COPY_NOT_NEW_NATIVE" and bridge["source_sha256"]==c.SOURCE_SHA and type(bridge["new_native_runs"]) is int and bridge["new_native_runs"]==0,"Typed source/operation/native count")
 original=record(root,value["qualification"]["source-pbr"],FAMILY+"proof/source-pbr.json")
 need(c.sha(original)==SOURCE_PBR_SHA,"Exact actual original native source-PBR raw inventory")
 inventory=json.loads(original).get("original_actual_raw_pngs")
 need(type(inventory) is list and len(inventory)==3 and type(bridge["frames"]) is list and len(bridge["frames"])==3,"Actual three raw identities")
 for pose,row,actual in zip(c.POSES,bridge["frames"],inventory):
  need(row.get("pose")==actual.get("pose")==pose,"Three exact ordered pose associations")
  need(row.get("original_encoded_sha256")==actual.get("original_encoded_sha256") and type(actual.get("original_encoded_bytes")) is int and actual["original_encoded_bytes"]>0,"Exact original encoded raw PNG/native draw association")
  for key in ["original_encoded_sha256","public_encoded_sha256","same_RGBA_sha256","removed_chunk_sha256","removed_payload_sha256"]:
   need(type(row.get(key)) is str and re.fullmatch("[0-9a-f]{64}",row[key]),"Typed pinned metadata identity: "+key)
  public=record(root,row["public"],FAMILY+"masters/"+pose+"-native-render.png")
  need(c.sha(public)==row["public_encoded_sha256"] and row["public"]["sha256"]==row["public_encoded_sha256"],"Exact reviewed public encoded bytes; sameRGBA reencoding refused")
  need(row["same_RGBA_sha256"]==actual.get("raw_RGBA_sha256")==c.sha(c.rgba(public,[320,200])),"Exact actual original/public rawRGBA join")
  need(row.get("IDAT_byte_identical") is True and row.get("other_chunks_and_order_byte_identical") is True and row.get("pixel_reencoded") is False,"Only pinned oneFile metadata-copy operation")
 return True

def active_uid(text,uid):
 return re.search('^[\t ]*uid[\t ]*=[\t ]*"'+re.escape(uid)+'"',text,re.M) is not None
def validate(root,h):
 root=Path(root);value=read_json(root/(FAMILY+"ledger.json"))
 need(value.get("schema")=="null-choir-rivet-native-v5-v1" and value.get("status")=="QUALIFIED","PENDING actual normal-import/fullHUD/world/independent qualification")
 need(value.get("source_sha256")==c.SOURCE_SHA and value.get("atlas_sha256")==ATLAS,"Exact accepted source/atlas")
 for name,pin in {"common.py":"9368ce25e3a4cee9144a7a9defce08770a090ec4eba6e623d0f07531e50f5837","export_pose.py":"3ac677d7a69db2199c33960f3377f9115b49ec96a08de5746ef41fa5d79c1c7a","registration_gate.py":"5af8119ef3fc4bdfbddcb73beb544289e1762de88e77b83df18d7cb67c038e8a","proof/source-shape-proof.json":c.PROOF_SHA}.items():
  need(c.sha((root/(FAMILY+name)).read_bytes())==pin,"Exact original portable code/geometry proof")
 need(c.sha((root/"tools/build_art.py").read_bytes())==c.HELPER_SHA,"Retained exact native raster helper")

 need(c.same(value.get("runtime_contract"),c.RUNTIME),"Exact original registration")
 need(c.sha(record(root,value["source"],FAMILY+"rivet_pistol.blend"))==c.SOURCE_SHA,"Original saved master")
 atlas=record(root,value["output"],OUTPUT);pixels=c.rgba(atlas,[960,200])
 parts=[b"".join(pixels[(y*960+i*320)*4:(y*960+(i+1)*320)*4] for y in range(200)) for i in range(3)]
 expected={"source_sha256":c.SOURCE_SHA,"atlas_sha256":ATLAS,"rgba_sha256":c.sha(pixels),"pose_rgba_sha256":[c.sha(x) for x in parts]}
 need(len(set(map(bytes,parts)))==3 and all(set(x[3::4])=={0,255} for x in parts),"Three distinct binaryalpha poses")
 need(all(c.same(value.get(k),v) for k,v in expected.items()),"Exact rawRGBA/pose linkage")
 proofs={}
 for kind in ["source-pbr","normal-import","full-hud","independent"]:
  r=value["qualification"].get(kind);need(type(r) is dict,"Missing actual "+kind)
  proof=json.loads(record(root,r,FAMILY+"proof/"+kind+".json"));proofs[kind]=proof
  need(proof.get("status")=="PASS" and all(c.same(proof.get(k),v) for k,v in expected.items()),"Actual same-source/pixel evidence: "+kind)
 need(proofs["source-pbr"].get("engine")=="CYCLES" and proofs["source-pbr"].get("device")=="CPU" and type(proofs["source-pbr"].get("samples")) is int and proofs["source-pbr"]["samples"]==64 and proofs["source-pbr"].get("helper_sha256")==c.HELPER_SHA,"Actual original CPU raster pipeline")
 for pose,part in zip(c.POSES,parts):
  frame=(root/(FAMILY+"frames/"+pose+".png")).read_bytes();raw=(root/(FAMILY+"masters/"+pose+"-native-render.png")).read_bytes()
  need(c.rgba(frame,[320,200])==part and c.quantize(c.rgba(raw,[320,200]))==part,"Exact rawPNG→quantization→accepted pose")
 validate_metadata_bridge(root,value)
 sidecar=(root/(OUTPUT+".import")).read_bytes();text=sidecar.decode()
 uid=proofs["normal-import"].get("uid");need(type(uid) is str and re.fullmatch("uid://[a-z0-9]+",uid) and uid!="uid://bdoou6uo7or3m","Actual unique new UID")
 new_uri="res://assets/art/weapons/native-v5/rivet_pistol.png";old_uri="res://assets/art/weapons/native-v4/rivet_pistol.png"
 new_cache="res://.godot/imported/rivet_pistol.png-"+hashlib.md5(new_uri.encode()).hexdigest()+".ctex"
 old_cache="res://.godot/imported/rivet_pistol.png-b569979d166978b72f50b616a6602cbc.ctex"
 cfg=h["active_import_assignments"](text)
 need(cfg["deps"].get("source_file")==json.dumps(new_uri) and cfg["remap"].get("path")==json.dumps(new_cache),"Actual exact v5 remap source/cache")
 parsed_uid,_=h["validate_import_sidecar"](text.replace(new_uri,old_uri).replace(new_cache,old_cache))
 need(parsed_uid==uid,"Actual sidecar UID joins native receipt")
 imp=proofs["normal-import"]
 need(imp.get("resource_class")=="CompressedTexture2D" and imp.get("actual_engine_generated_uid") is True and imp.get("bit_exact") is True and imp.get("sidecar_sha256")==c.sha(sidecar) and type(imp.get("imported_bytes")) is int and imp["imported_bytes"]>0 and re.fullmatch("[0-9a-f]{64}",str(imp.get("imported_sha256",""))),"Actual normal import/ctex bytes, no invented UID")
 for p in (root/"game").rglob("*.import"):
  if p==root/(OUTPUT+".import"):continue
  need(not active_uid(p.read_text(),uid),"Native UID duplicates a retained import")
 hud=proofs["full-hud"]
 need(hud.get("actual_production_draw") is True and hud.get("full_instrument_chrome") is True and hud.get("actual_world_context") is True and c.same(hud.get("resolution"),[640,360]) and hud.get("runtime_uri")==new_uri and hud.get("fixture_overrides")==[],"Full production HUD/world, no suppressed chrome or ImageTexture override")
 code={"res://scripts/main.gd":"cf4624fa56bb0ecd634e63c0c2ca15b98f4298b4f05365e3a55cdc85d6d52bb0","res://scripts/player.gd":NEW_PLAYER,"res://scripts/hud.gd":"44e466410c46d72431228923082318eb65618b283b5ae86106d02ae981a587f7"}
 need(hud.get("code_sha256")==code,"Actual exact current Main/Player/HUD receipts")
 for path,pin in code.items():need(c.sha((root/("game/"+path[6:])).read_bytes())==pin,"Current source drift")
 need(len(hud.get("views",[]))==3 and [x.get("pose") for x in hud["views"]]==list(c.POSES),"All three fullHUD poses")
 for row in hud["views"]:
  need(type(row.get("visible_weapon_pixels")) is int and row["visible_weapon_pixels"]>20 and row.get("full_chrome_changed_pixels",0)>1000 and row.get("stable_world_pixels",0)>20000,"Actual visible pixels/chrome/ABA world controls")
  for prefix in ["hud-world-","background-a-","background-b-"]:
   data=record(root,row["images"][prefix],FAMILY+"proof/"+prefix+row["pose"]+".png");c.rgba(data,[640,360])
 independent=proofs["independent"]
 need(independent.get("review_role")=="independent" and independent.get("numeric_rating_included") is False and independent.get("full_hud_receipt_sha256")==value["qualification"]["full-hud"]["sha256"],"Independent actual fullcontext acceptance, no private ratings")
 normalize_player(root,(root/"game/scripts/player.gd").read_bytes(),value["player_compatibility"])
 family=root/"game/assets/art/weapons/native-v5"
 need({x.relative_to(root).as_posix() for x in family.rglob("*.png")}=={OUTPUT},"Exactly one new runtime atlas owner")
 return {"status":"STRUCTURAL_QUALIFIED_RIVET_V5","runtime_outputs":[OUTPUT],"historical_Player_evidence_scope":"Only exact one-byte weaponURI compatibility; no fresh body/Worker/gameplay qualification"}
