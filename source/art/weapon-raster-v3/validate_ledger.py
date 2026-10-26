"""Strict structural validator for the separate six-weapon raster ledger.

No Blender/archive execution, network, Godot, or mutations.  The validator reads
files and verifies hashes/contracts; it does not create or promote an art asset.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
import zlib

IDS = frozenset({
    "impact_tool", "rivet_pistol", "scattergun", "sawtooth_repeater",
    "marrow_launcher", "choir_disruptor",
})
FRAMES = ("idle", "fire", "recover")
NATIVE_SIZE = (960, 200)
CELL_SIZE = (320, 200)
ORIGIN = (160, 200)
ALPHA_LEVELS = (0, 255)
SCHEMA = "null-choir.weapon-raster-ledger"
VERSION = 1
LEGACY_MANIFEST = "source/art/manifest.json"
RUNTIME_ROOT = "game/assets/art/weapons/painted-v3"
HUD_PATH = "game/scripts/hud.gd"
PLAYER_PATH = "game/scripts/player.gd"
HUD_NEAREST = "texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST"
HUD_ASSET_CONSUMER = '"res://assets/art/weapons/"+profile.asset+".png"'

class ContractError(ValueError):
    pass


def fail(message: str) -> None:
    raise ContractError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _pairs(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            fail(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_pairs)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"cannot read JSON {path.name}: {exc}")


def safe_rel(root: Path, value, *, label: str, allowed_roots=None, allow_res_uri=False) -> Path:
    """Resolve a repository-relative path without following symlinks or escaping root."""
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        fail(f"{label}: expected canonical repository-relative POSIX path")
    if value.startswith(("/", "~")) or re.match(r"^[A-Za-z]:", value) or value.startswith("file://"):
        fail(f"{label}: absolute/private path is forbidden")
    if allow_res_uri and value.startswith("res://"):
        value = "game/" + value.removeprefix("res://")
    p = PurePosixPath(value)
    if p.is_absolute() or p.as_posix() != value or any(part in ("", ".", "..") for part in p.parts):
        fail(f"{label}: noncanonical or traversal path")
    if allowed_roots and p.parts[0] not in allowed_roots:
        fail(f"{label}: path outside permitted repository roots")
    root = root.absolute()
    if any(part.is_symlink() for part in (root, *root.parents)):
        fail("symlinked repository root")
    current = root
    for part in p.parts:
        current = current / part
        if current.is_symlink():
            fail(f"{label}: symlink path forbidden")
    try:
        current.relative_to(root)
    except ValueError:
        fail(f"{label}: path escapes repository root")
    return current


def _reject_private_strings(obj, location="ledger"):
    """Reject leaked absolute local paths anywhere in untrusted JSON strings."""
    if isinstance(obj, dict):
        for key, value in obj.items():
            _reject_private_strings(key, location)
            _reject_private_strings(value, f"{location}.{key}")
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            _reject_private_strings(value, f"{location}[{index}]")
    elif isinstance(obj, str):
        low = obj.lower()
        bad = ("/users/", "/private/", "/tmp/", "/var/folders/", "/home/",
               "file://", "\\users\\", "\\private\\", "\\temp\\")
        if any(token in low for token in bad) or re.search(r"(?:^|\s)~[/\\]", obj):
            fail(f"{location}: private/absolute path leak")


def _checked_file(root: Path, value, *, label: str, allowed_roots=None) -> tuple[Path, bytes]:
    path = safe_rel(root, value, label=label, allowed_roots=allowed_roots)
    if not path.is_file():
        fail(f"{label}: referenced file missing")
    return path, path.read_bytes()


def png_rgba(data: bytes, *, label="PNG") -> tuple[tuple[int, int], bytes]:
    """Strictly decode non-interlaced 8-bit RGBA PNG and validate CRC/filter stream."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{label}: not PNG")
    pos = 8
    width = height = None
    compressed = bytearray()
    ended = False
    seen_ihdr = seen_iend = False
    while pos < len(data):
        if pos + 12 > len(data):
            fail(f"{label}: truncated chunk")
        length = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4:pos + 8]
        end = pos + 12 + length
        if end > len(data):
            fail(f"{label}: chunk exceeds file")
        payload = data[pos + 8:pos + 8 + length]
        crc = struct.unpack_from(">I", data, pos + 8 + length)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            fail(f"{label}: CRC mismatch in {kind!r}")
        if not seen_ihdr:
            if kind != b"IHDR" or length != 13:
                fail(f"{label}: IHDR must be first")
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if not width or not height or (bit_depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                fail(f"{label}: require noninterlaced 8-bit RGBA PNG")
            seen_ihdr = True
        elif kind == b"IDAT":
            if seen_iend:
                fail(f"{label}: IDAT after IEND")
            compressed.extend(payload)
        elif kind == b"IEND":
            if length or seen_iend:
                fail(f"{label}: malformed IEND")
            seen_iend = True
            if end != len(data):
                fail(f"{label}: trailing bytes after IEND")
            ended = True
        else:
            # Unknown critical chunks change pixel semantics and are not accepted.
            if kind[:1].isupper():
                fail(f"{label}: unsupported critical PNG chunk {kind!r}")
        pos = end
        if seen_iend:
            break
    if not seen_ihdr or not ended:
        fail(f"{label}: missing IHDR/IEND")
    try:
        raw = zlib.decompress(compressed)
    except zlib.error as exc:
        fail(f"{label}: invalid IDAT stream: {exc}")
    stride, bpp = width * 4, 4
    if len(raw) != height * (stride + 1):
        fail(f"{label}: incorrect decompressed length")
    rows = []
    previous = bytearray(stride)
    offset = 0
    for _y in range(height):
        filt = raw[offset]
        scan = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += stride + 1
        if filt > 4:
            fail(f"{label}: unknown PNG row filter")
        for x in range(stride):
            a = scan[x - bpp] if x >= bpp else 0
            b = previous[x]
            c = previous[x - bpp] if x >= bpp else 0
            if filt == 1:
                scan[x] = (scan[x] + a) & 255
            elif filt == 2:
                scan[x] = (scan[x] + b) & 255
            elif filt == 3:
                scan[x] = (scan[x] + ((a + b) // 2)) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
                scan[x] = (scan[x] + predictor) & 255
        rows.append(bytes(scan))
        previous = scan
    return (width, height), b"".join(rows)


def _finite_pair(value, *, label, upper):
    if (not isinstance(value, list) or len(value) != 2 or
            any(type(n) not in (int, float) or not math.isfinite(n) for n in value)):
        fail(f"{label}: expected two finite numbers")
    if not (0 <= value[0] < upper[0] and 0 <= value[1] < upper[1]):
        fail(f"{label}: point outside source/native cell")
    return tuple(float(x) for x in value)


def _relative_digest(root: Path, path_value, digest, *, label, allowed_roots=None) -> tuple[Path, bytes]:
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        fail(f"{label}: lowercase SHA-256 required")
    path, data = _checked_file(root, path_value, label=label, allowed_roots=allowed_roots)
    if sha(data) != digest:
        fail(f"{label}: SHA-256 mismatch")
    return path, data


def _load_legacy(root: Path) -> tuple[dict, set[str]]:
    mpath = safe_rel(root, LEGACY_MANIFEST, label="legacy manifest")
    if not mpath.is_file():
        fail("legacy source/art/manifest.json missing; cannot preserve lineage")
    manifest = read_json(mpath)
    if not isinstance(manifest, dict) or not isinstance(manifest.get("assets"), list):
        fail("legacy manifest shape invalid")
    by_id = {}
    all_outputs = set()
    for entry in manifest["assets"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            fail("legacy manifest entry malformed")
        if entry["id"] in by_id:
            fail("duplicate legacy asset id")
        by_id[entry["id"]] = entry
        for output in entry.get("outputs", []):
            if not isinstance(output, dict) or not isinstance(output.get("path"), str):
                fail("legacy output record malformed")
            safe_rel(root, output["path"], label="legacy output", allowed_roots={"game"})
            if output["path"] in all_outputs:
                fail("duplicate output ownership in legacy catalog")
            all_outputs.add(output["path"])
    return by_id, all_outputs


def _old_lineage(root: Path, asset_id: str, old_entries: dict) -> tuple[str, str, str]:
    entry = old_entries.get(asset_id)
    if not entry:
        fail(f"{asset_id}: historical Blender manifest entry missing")
    source_value = entry.get("source")
    if not isinstance(source_value, str) or not source_value.endswith(".blend"):
        fail(f"{asset_id}: legacy source lineage must remain the recorded Blender source")
    source_path, source_bytes = _checked_file(root, source_value, label=f"{asset_id} legacy source", allowed_roots={"source"})
    if source_bytes[:7] != b"BLENDER" or sha(source_bytes) != entry.get("source_sha256"):
        fail(f"{asset_id}: historic Blender source no longer matches catalog")
    outputs = entry.get("outputs", [])
    if len(outputs) != 1:
        fail(f"{asset_id}: expected one historic weapon raster output")
    old = outputs[0]
    expected_path = f"game/assets/art/weapons/{asset_id}.png"
    if old.get("path") != expected_path:
        fail(f"{asset_id}: historic output path changed")
    old_path, old_bytes = _checked_file(root, expected_path, label=f"{asset_id} legacy output", allowed_roots={"game"})
    if len(old_bytes) != old.get("bytes") or sha(old_bytes) != old.get("sha256"):
        fail(f"{asset_id}: historic output bytes changed")
    return source_value, entry["source_sha256"], old["sha256"]


def _atlas(data: bytes, *, label: str):
    dims, pixels = png_rgba(data, label=label)
    if dims != NATIVE_SIZE:
        fail(f"{label}: runtime atlas must be native 960x200 RGBA8 (not an 8K/master)")
    alpha = set(pixels[3::4])
    if alpha != set(ALPHA_LEVELS):
        fail(f"{label}: runtime alpha must be hard binary {{0,255}} with transparent pixels")
    cells = []
    hashes = []
    for col in range(3):
        cell = bytearray()
        for y in range(CELL_SIZE[1]):
            start = (y*NATIVE_SIZE[0] + col*CELL_SIZE[0])*4
            cell.extend(pixels[start:start+CELL_SIZE[0]*4])
        cell = bytes(cell)
        if set(cell[3::4]) != set(ALPHA_LEVELS):
            fail(f"{label}: every pose must retain both transparent and opaque alpha")
        if sum(a != 0 for a in cell[3::4]) < 80:
            fail(f"{label}: empty/near-empty pose")
        cells.append(cell); hashes.append(sha(cell))
    if len(set(hashes)) != 3:
        fail(f"{label}: idle/fire/recover must be three pixel-distinct poses")
    return dims, pixels, tuple(hashes)


def _import(root: Path, asset_id: str, runtime_path: str):
    ipath_s = runtime_path + ".import"
    ipath, data = _checked_file(root, ipath_s, label=f"{asset_id} Godot import settings", allowed_roots={"game"})
    text = data.decode("utf-8", errors="strict")
    expected = {
      'importer="texture"': "Godot texture importer",
      f'source_file="res://assets/art/weapons/painted-v3/{asset_id}.png"': "exact versioned runtime source",
      'compress/mode=0': "lossless/uncompressed source import",
      'mipmaps/generate=false': "no filtering mip chain",
      'process/premult_alpha=false': "unaltered hard-alpha pixels",
    }
    for token, label in expected.items():
        if token not in text:
            fail(f"{asset_id}: Godot import sidecar missing {label}")
    return ipath


def validate_ledger(root: Path, ledger_path: str | Path) -> dict:
    """Validate the current source/art/weapon-raster-v3.json schema."""
    root=Path(root).absolute()
    if any(p.is_symlink() for p in (root,*root.parents)) or not root.is_dir():
        fail("repository root must be an existing nonsymlink directory")
    if isinstance(ledger_path,Path):
        try: rel=ledger_path.absolute().relative_to(root).as_posix()
        except ValueError: fail("ledger path outside repository root")
    else: rel=ledger_path
    if rel != "source/art/weapon-raster-v3.json":
        fail("only the canonical source/art/weapon-raster-v3.json ledger is accepted")
    lpath=safe_rel(root,rel,label="ledger",allowed_roots={"source"})
    ledger=read_json(lpath); _reject_private_strings(ledger)
    if ledger.get("schema_version")!=1 or ledger.get("kind")!="six-production-directed-registered-raster-weapon-atlases":
        fail("unsupported six-weapon raster ledger schema/kind")
    contract=ledger.get("runtime_contract")
    expected_contract={"atlas":list(NATIVE_SIZE),"cell_size":list(CELL_SIZE),"columns":3,
                       "frames":list(FRAMES),"alpha":list(ALPHA_LEVELS),"origin_px":list(ORIGIN),
                       "impact_flash":False}
    if not isinstance(contract,dict) or any(contract.get(k)!=v for k,v in expected_contract.items()):
        fail("shared runtime atlas contract differs from 960x200 / 3-pose binary-alpha rules")
    legacy=ledger.get("legacy_catalog")
    if not isinstance(legacy,dict) or legacy.get("path")!=LEGACY_MANIFEST:
        fail("separate raster ledger must preserve the historic Blender catalog reference")
    mpath=safe_rel(root,LEGACY_MANIFEST,label="legacy manifest")
    if not mpath.is_file() or sha(mpath.read_bytes())!=legacy.get("sha256_unchanged"):
        fail("historic source/art/manifest.json changed from its recorded lineage hash")
    old_entries,old_owned=_load_legacy(root)
    entries=ledger.get("assets")
    if not isinstance(entries,list) or len(entries)!=6:
        fail("ledger must contain exactly six data-driven assets")
    ids=[e.get("id") for e in entries if isinstance(e,dict)]
    if len(ids)!=6 or set(ids)!=set(IDS) or len(set(ids))!=6:
        fail("exact known six weapon IDs required; unknown/missing/duplicate IDs rejected")
    if sorted(e.get("weapon_index") for e in entries)!=list(range(6)):
        fail("six stable Player weapon indexes 0..5 required")

    player_data=_checked_file(root,PLAYER_PATH,label="Player.WEAPONS consumer",allowed_roots={"game"})[1]
    player_text=player_data.decode("utf-8",errors="strict")
    records=re.findall(r'\{"name":"[^"]+","asset":"([^"]+)"[^}]*\}',player_text)
    expected_player={f"painted-v3/{asset_id}" for asset_id in IDS}
    if len(records)!=6 or set(records)!=expected_player:
        fail("Player.WEAPONS must register all six exact versioned painted-v3 paths")
    hud_data=_checked_file(root,HUD_PATH,label="HUD texture consumer",allowed_roots={"game"})[1]
    hud_text=hud_data.decode("utf-8",errors="strict")
    if HUD_NEAREST not in hud_text or HUD_ASSET_CONSUMER not in hud_text:
        fail("actual HUD must retain nearest filtering and consume profile.asset PNG")

    owned=set(old_owned); claimed=set(); used_refs=set(); observed_compilers=set()
    for entry in entries:
        asset_id=entry["id"]
        if entry.get("runtime_uri")!=f"res://assets/art/weapons/painted-v3/{asset_id}.png":
            fail(f"{asset_id}: runtime URI must stay in versioned painted-v3 directory")
        if entry.get("player_asset_path")!=f"painted-v3/{asset_id}":
            fail(f"{asset_id}: Player.WEAPONS path registration mismatch")
        if entry.get("frames")!=list(FRAMES) or entry.get("columns")!=3 or entry.get("cell_size")!=list(CELL_SIZE) or entry.get("alpha")!=list(ALPHA_LEVELS) or entry.get("filter")!="nearest":
            fail(f"{asset_id}: per-asset cell/alpha/filter contract mismatch")
        legacy_source,legacy_source_sha,legacy_output_sha=_old_lineage(root,asset_id,old_entries)
        legacy_copy=entry.get("legacy_catalog_output")
        if not isinstance(legacy_copy,dict) or legacy_copy.get("path")!=f"game/assets/art/weapons/{asset_id}.png" or legacy_copy.get("sha256")!=legacy_output_sha or legacy_copy.get("unchanged") is not True:
            fail(f"{asset_id}: historic Blender output must remain explicitly unchanged")
        # Preserve the old source and atlas byte hashes in their old manifest; new art has distinct provenance.
        source=entry.get("source"); regrow=entry.get("registration"); comp=entry.get("compiler")
        if not all(isinstance(x,dict) for x in (source,regrow,comp)):
            fail(f"{asset_id}: source/registration/compiler evidence missing")
        if source.get("fully_retained_original") is not True:
            fail(f"{asset_id}: complete original new-raster source must be retained")
        generator=source.get("generator")
        if not isinstance(generator,str) or "builtin image_gen" not in generator.lower() or "not blender" not in generator.lower() or "not native8k" not in generator.lower():
            fail(f"{asset_id}: provenance must state built-in raster, not Blender or native8K")
        source_path,source_bytes=_relative_digest(root,source.get("path"),source.get("sha256"),label=f"{asset_id} production source",allowed_roots={"source"})
        if not source_path.is_relative_to(root/"source/art/weapon-raster-v3" ):
            fail(f"{asset_id}: source must remain under versioned weapon-raster-v3 tree")
        source_dims,source_pixels=png_rgba(source_bytes,label=f"{asset_id} source PNG")
        if source.get("dimensions")!=list(source_dims) or source_dims[0]>=7680 or source_dims[1]>=4320:
            fail(f"{asset_id}: source dimensions do not match bytes or claim/contain native8K")
        reg_path,reg_bytes=_relative_digest(root,regrow.get("path"),regrow.get("sha256"),label=f"{asset_id} registration",allowed_roots={"source"})
        if not reg_path.is_relative_to(root/"source/art/weapon-raster-v3"/asset_id):
            fail(f"{asset_id}: registration outside its own weapon folder")
        reg=read_json(reg_path)
        if (reg.get("weapon_id") not in (None,asset_id) or reg.get("status") not in (
                "NONSHIPPING_MANUALLY_REGISTERED_NEW_PRODUCTION_RASTER_NOT_BLENDER",
                "NONSHIPPING_MANUALLY_REGISTERED_RASTER_SOURCE_NOT_BLENDER")):
            fail(f"{asset_id}: manual per-weapon registration identity/provenance mismatch")
        reg_source_dims=reg.get("source_dimensions",reg.get("original_source_dimensions"))
        if reg.get("source_sha256")!=source.get("sha256") or reg_source_dims!=list(source_dims) or reg.get("alpha_cutoff_byte")!=128 or reg.get("native_origin")!=list(ORIGIN):
            fail(f"{asset_id}: registration must bind exact source, origin and binary alpha cutoff")
        if source_path.name!=reg.get("source_file"):
            fail(f"{asset_id}: registration source filename differs from ledger")
        reg_poses=reg.get("poses")
        rects=reg.get("source_cell_rects")
        if reg.get("schema")==1:
            cell=reg.get("source_cells")
            if not isinstance(cell,list) or len(cell)!=2 or any(type(v) is not int or v<=0 for v in cell) or reg.get("columns")!=3 or reg.get("native_dimensions")!=list(NATIVE_SIZE) or reg.get("native_cell")!=list(CELL_SIZE):
                fail(f"{asset_id}: schema1 native/source cell contract invalid")
            rects=[[i*cell[0],0,cell[0],cell[1]] for i in range(3)]
        if reg.get("schema") not in (1,2) or not isinstance(reg_poses,list) or len(reg_poses)!=3 or [p.get("id") for p in reg_poses]!=list(FRAMES) or not isinstance(rects,list) or len(rects)!=3:
            fail(f"{asset_id}: three explicit manually registered source cells/poses required")
        for i,rect in enumerate(rects):
            if not isinstance(rect,list) or len(rect)!=4 or any(type(v) not in (int,float) for v in rect): fail(f"{asset_id}: malformed source cell rectangle")
            x,y,w,h=rect
            if min(x,y)<0 or min(w,h)<=0 or x+w>source_dims[0] or y+h>source_dims[1]: fail(f"{asset_id}: source cell escapes source PNG")
            pose=reg_poses[i]
            if pose.get("source_cell")!=i: fail(f"{asset_id}: pose order must be idle/fire/recover source cells")
            _finite_pair(pose.get("source_anchor_local",pose.get("muzzle_source_local")),label=f"{asset_id} source landmark",upper=(w,h))
            crop=pose.get("extraction_local")
            if not isinstance(crop,list) or len(crop)!=4 or any(type(v) not in (int,float) for v in crop): fail(f"{asset_id}: extraction rectangle malformed")
            cx,cy,cw,ch=crop
            if min(cx,cy)<0 or min(cw,ch)<=0 or cx+cw>w or cy+ch>h: fail(f"{asset_id}: extraction rectangle escapes its source cell")
        basis=reg.get("manual_measurement",reg.get("manual_landmark_method"))
        if not isinstance(basis,str) or len(basis.strip())<40: fail(f"{asset_id}: specific manual landmark-registration method required")
        if regrow.get("accepted_exact_copy") is not True or regrow.get("native_origin")!=list(ORIGIN): fail(f"{asset_id}: registration record does not bind accepted atlas/origin")
        native_anchor=reg.get("native_anchor_px",reg.get("native_muzzle"))
        _finite_pair(native_anchor,label=f"{asset_id} native anchor",upper=CELL_SIZE)

        if not isinstance(comp.get("path"),str) or not comp.get("path").startswith("source/art/weapon-raster-v3/compilers/"):
            fail(f"{asset_id}: compiler must be versioned repository-local Godot CPU source")
        compiler_path,compiler_bytes=_relative_digest(root,comp.get("path"),comp.get("sha256"),label=f"{asset_id} compiler",allowed_roots={"source"})
        if "godot" not in compiler_bytes.decode("utf-8",errors="replace").lower() or "blender" in comp.get("method","").lower():
            fail(f"{asset_id}: compiler is not truthful native Godot CPU extraction")
        observed_compilers.add((comp["path"],comp["sha256"]))
        accepted=entry.get("accepted_atlas_copy")
        proof=entry.get("compile_proof")
        if not isinstance(accepted,dict) or not isinstance(proof,dict): fail(f"{asset_id}: accepted-copy/compiler proof records required")
        candidate_path,candidate_bytes=_relative_digest(root,accepted.get("path"),accepted.get("sha256"),label=f"{asset_id} accepted candidate atlas",allowed_roots={"source"})
        if not candidate_path.is_relative_to(root/"source/art/weapon-raster-v3"/asset_id): fail(f"{asset_id}: candidate atlas must stay under its weapon folder")
        if reg.get("native_output")!=candidate_path.relative_to(reg_path.parent).as_posix(): fail(f"{asset_id}: manual registration points to another atlas")
        candidate_dims,candidate_pixels,cell_hashes=_atlas(candidate_bytes,label=f"{asset_id} candidate atlas")
        if list(candidate_dims)!=list(NATIVE_SIZE) or accepted.get("sha256")!=entry.get("output",{}).get("sha256"):
            fail(f"{asset_id}: accepted candidate is not the exact runtime atlas")
        if not re.fullmatch(re.escape(asset_id)+r"-registered-v[1-9][0-9]*\.png",candidate_path.name) or candidate_path.parent.name!=re.search(r"candidate-v([1-9][0-9]*)",accepted["path"]).group(0):
            fail(f"{asset_id}: unexpected accepted atlas filename/version")
        proof_path,proof_bytes=_relative_digest(root,proof.get("path"),proof.get("sha256"),label=f"{asset_id} compiler proof",allowed_roots={"source"})
        if not proof_path.is_relative_to(candidate_path.parent): fail(f"{asset_id}: compiler proof must be adjacent to its candidate")
        proof_obj=read_json(proof_path)
        expected_proof={"registration_sha256":regrow["sha256"],"compiler_sha256":comp["sha256"],"output_png_sha256":sha(candidate_bytes),"output_rgba8_sha256":sha(candidate_pixels),"dimensions":list(NATIVE_SIZE),"cell":list(CELL_SIZE),"alpha":list(ALPHA_LEVELS),"failures":0}
        for key,value in expected_proof.items():
            if proof_obj.get(key)!=value: fail(f"{asset_id}: native CPU compiler proof mismatch at {key}")
        proof_weapon=proof_obj.get("weapon_id")
        proof_source=proof_obj.get("source_sha256",proof_obj.get("original_source_sha256"))
        if (proof_weapon is not None and proof_weapon!=asset_id) or (proof_weapon is None and not (asset_id=="rivet_pistol" and reg.get("schema")==1)) or proof_source!=source["sha256"]:
            fail(f"{asset_id}: compiler proof source or weapon binding mismatch")
        proof_poses=proof_obj.get("poses")
        if not isinstance(proof_poses,list) or len(proof_poses)!=3 or [p.get("pose") for p in proof_poses]!=list(FRAMES) or [p.get("rgba8_sha256",p.get("cell_rgba8_sha256")) for p in proof_poses]!=list(cell_hashes):
            fail(f"{asset_id}: compiler proof does not enumerate exact three output poses")
        if [p.get("native_anchor",p.get("native_muzzle")) for p in proof_poses]!=[native_anchor]*3:
            fail(f"{asset_id}: compiled pose anchors do not match registered origin")

        out=entry.get("output")
        if not isinstance(out,dict): fail(f"{asset_id}: runtime output record missing")
        runtime_s=out.get("path")
        if runtime_s!=f"game/assets/art/weapons/painted-v3/{asset_id}.png" or out.get("dimensions")!=list(NATIVE_SIZE):
            fail(f"{asset_id}: runtime path/dimensions invalid")
        if runtime_s in owned or runtime_s in claimed: fail(f"{asset_id}: output collision with legacy or another owner")
        runtime_path,runtime_bytes=_relative_digest(root,runtime_s,out.get("sha256"),label=f"{asset_id} runtime atlas",allowed_roots={"game"})
        if runtime_bytes!=candidate_bytes or out.get("bytes")!=len(runtime_bytes) or out.get("rgba8_pixel_sha256")!=sha(candidate_pixels):
            fail(f"{asset_id}: runtime PNG differs from accepted compiler output")
        claimed.add(runtime_s);owned.add(runtime_s)
        if _old_lineage(root,asset_id,old_entries)[2]!=legacy_output_sha: fail(f"{asset_id}: legacy atlas changed")
        import_rec=entry.get("import")
        if not isinstance(import_rec,dict) or import_rec.get("sidecar_path")!=runtime_s+".import" or import_rec.get("compress_mode")!=0 or import_rec.get("mipmaps") is not False or import_rec.get("premult_alpha") is not False:
            fail(f"{asset_id}: nearest/lossless/binary-alpha import declaration missing")
        import_path=_import(root,asset_id,runtime_s)
        # Immutable compiler implementation may be shared; all produced/owned
        # source, registration, evidence, runtime and import paths remain unique.
        for path in (source.get("path"),regrow.get("path"),accepted.get("path"),proof.get("path"),runtime_s,import_rec.get("sidecar_path")):
            if path in used_refs: fail(f"{asset_id}: duplicate file/path ownership {path}")
            used_refs.add(path)
    # Report reference presence only; this structural validator does not authenticate a native run.
    return {"status":"STRUCTURAL_RASTER_LEDGER_VALID","entries":6,"runtime_outputs":sorted(claimed),"historic_manifest_untouched":True,"player_paths_registered":True,"nearest_lossless_import_declared":True,"actual_native_import_run_receipt_in_ledger":bool(ledger.get("native_import_qualification")),"note":"Structural source/PNG/compiler/import contract only. It does not score artwork, prove end-user use, or authenticate a native Godot fixture run."}

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger",help="Repository-relative versioned raster ledger JSON")
    parser.add_argument("--root",default=str(Path(__file__).resolve().parents[3]),help="Repository root")
    args=parser.parse_args()
    try:
        result=validate_ledger(Path(args.root),args.ledger)
    except ContractError as exc:
        print(f"FAIL: {exc}")
        return 1
    print("PASS: "+json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
