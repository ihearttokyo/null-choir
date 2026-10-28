"""Strict, read-only validator for a complete authored threshold-art release ledger.

This verifies repository-local bytes, source/proof bindings, actual GateArt and
door-data contracts, GLB containers, embedded used images, and importer policy.
It does not run Blender/Godot, prove a native run occurred, or judge visual quality.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct

SCHEMA = "null-choir.threshold-art-ledger"
VERSION = 1
GATE_ART_PATH = "game/scripts/gate_art.gd"
DATA_ROOT = "game/data"
SOURCE_ROOT = "source/art/living-thresholds-v3"
REVIEW_SCOPE = "threshold-native640-intended-use-v1"
ROLES = ("StationaryFrame", "MovingLeaf", "BloodLatch", "IvoryLatch", "ReleasedClosure")
NATIVE_CODE_SOURCES = (
    "game/scripts/gate_art.gd", "game/scripts/gate_visual.gd",
    "game/scripts/level.gd", "game/scripts/main.gd",
    "game/tests/test_gate_art.gd", "game/tests/test_gate_integration.gd",
)
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"


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


def _json_bytes(data: bytes, label: str):
    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=_pairs)
    except (UnicodeError, json.JSONDecodeError) as exc:
        fail(f"{label}: invalid UTF-8 JSON: {exc}")


def read_json(path: Path):
    try:
        return _json_bytes(path.read_bytes(), path.name)
    except OSError as exc:
        fail(f"cannot read {path.name}: {exc}")


def _reject_private_strings(obj, location="ledger"):
    if isinstance(obj, dict):
        for key, value in obj.items():
            _reject_private_strings(key, location)
            _reject_private_strings(value, f"{location}.{key}")
    elif isinstance(obj, list):
        for i, value in enumerate(obj):
            _reject_private_strings(value, f"{location}[{i}]")
    elif isinstance(obj, str):
        low = obj.lower()
        if (any(token in low for token in ("/users/", "/private/", "/tmp/", "/var/folders/", "/home/", "file://", "\\users\\", "\\private\\"))
                or re.search(r"(?:^|\s)~[/\\]", obj)):
            fail(f"{location}: absolute/private path leak")


def safe_rel(root: Path, value, *, label: str, roots: set[str]) -> Path:
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        fail(f"{label}: expected canonical repository-relative POSIX path")
    if value.startswith(("/", "~")) or re.match(r"^[A-Za-z]:", value) or value.startswith("file://"):
        fail(f"{label}: absolute/private path forbidden")
    p = PurePosixPath(value)
    if p.is_absolute() or p.as_posix() != value or any(part in ("", ".", "..") for part in p.parts):
        fail(f"{label}: noncanonical/traversal path")
    if not p.parts or p.parts[0] not in roots:
        fail(f"{label}: path outside permitted roots")
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


def checked_file(root: Path, record, *, label: str, roots: set[str], owned: set[str] | None = None) -> tuple[Path, bytes]:
    if not isinstance(record, dict):
        fail(f"{label}: expected path/SHA record")
    path_text, digest = record.get("path"), record.get("sha256")
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        fail(f"{label}: lowercase SHA-256 required")
    path = safe_rel(root, path_text, label=label, roots=roots)
    if not path.is_file():
        fail(f"{label}: referenced file missing")
    data = path.read_bytes()
    if sha(data) != digest:
        fail(f"{label}: SHA-256 mismatch")
    if owned is not None:
        if path_text in owned:
            fail(f"{label}: duplicate file ownership/reference {path_text}")
        owned.add(path_text)
    return path, data


def _door_contract(root: Path) -> dict[str, dict]:
    path = safe_rel(root, GATE_ART_PATH, label="GateArt registry", roots={"game"})
    if not path.is_file():
        fail("GateArt registry missing")
    text = path.read_text(encoding="utf-8")
    match = re.search(r"const\s+REGISTRY\s*=\s*\{(.*?)\}\s*static\s+func\s+create", text, re.S)
    if not match:
        fail("GateArt.REGISTRY shape unsupported; refusing to infer runtime paths")
    pattern = re.compile(r'"([^"]+)"\s*:\s*\{\s*"scene"\s*:\s*"([^"]+)"\s*,\s*"width"\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*\}')
    registry_rows = pattern.findall(match.group(1))
    if len(registry_rows) != match.group(1).count('"scene"') or not registry_rows:
        fail("could not parse every GateArt.REGISTRY entry")
    registry = {}
    for asset_id, scene, width in registry_rows:
        if asset_id in registry or not re.fullmatch(r"[a-z][a-z0-9_]*", asset_id) or not re.fullmatch(r"[a-z][a-z0-9_]*", scene):
            fail("duplicate/invalid GateArt registry identity")
        registry[asset_id] = {"scene": scene, "width": float(width)}
    if len(registry) != 8:
        fail("GateArt.REGISTRY must contain exactly eight stable threshold IDs")
    data_root = safe_rel(root, DATA_ROOT, label="door data root", roots={"game"})
    if not data_root.is_dir():
        fail("door data directory missing")
    doors = {}
    for data_file in sorted(data_root.glob("*.json")):
        if data_file.is_symlink():
            fail("symlinked map JSON forbidden")
        try:
            document = _json_bytes(data_file.read_bytes(), data_file.name)
        except OSError as exc:
            fail(f"cannot read map data {data_file.name}: {exc}")
        entries = document.get("doors", []) if isinstance(document, dict) else []
        if not isinstance(entries, list):
            fail(f"{data_file.name}: doors must be an array")
        for door in entries:
            if not isinstance(door, dict) or not isinstance(door.get("id"), str):
                fail(f"{data_file.name}: malformed door record")
            asset_id = door["id"]
            if asset_id in doors:
                fail(f"door ID duplicated in game/data: {asset_id}")
            size = door.get("size")
            if not isinstance(size, list) or len(size) != 3 or any(type(n) not in (int, float) or not math.isfinite(n) for n in size):
                fail(f"{asset_id}: invalid authored door dimensions")
            doors[asset_id] = {"size": [float(n) for n in size], "data_file": data_file.relative_to(root).as_posix()}
    if set(doors) != set(registry):
        fail("GateArt.REGISTRY must match exactly the authored game/data door IDs")
    for asset_id, record in doors.items():
        expected_width = registry[asset_id]["width"]
        size = record["size"]
        if size != [expected_width, 5.0, 0.6]:
            fail(f"{asset_id}: GateArt width or authored door dimensions mismatch")
        slug = registry[asset_id]["scene"]
        record["runtime_uri"] = f"res://assets/art/thresholds-v3/{slug}_threshold.glb"
        record["runtime_path"] = f"game/assets/art/thresholds-v3/{slug}_threshold.glb"
        record["scene"] = slug
    return doors


def _check_glb(data: bytes, *, label: str) -> dict:
    if len(data) < 20 or data[:4] != b"glTF":
        fail(f"{label}: not a GLB container")
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        fail(f"{label}: GLB header/version/length mismatch")
    offset = 12
    chunks = []
    while offset < len(data):
        if offset + 8 > len(data):
            fail(f"{label}: truncated GLB chunk header")
        length, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        end = offset + length
        if end > len(data) or length % 4:
            fail(f"{label}: invalid GLB chunk length/alignment")
        chunks.append((kind, data[offset:end]))
        offset = end
    if offset != len(data) or not chunks or chunks[0][0] != b"JSON":
        fail(f"{label}: JSON must be first GLB chunk")
    if len(chunks) != 2 or sum(1 for kind, _ in chunks if kind == b"JSON") != 1 or sum(1 for kind, _ in chunks if kind == b"BIN\x00") != 1:
        fail(f"{label}: require exactly one JSON and one BIN chunk")
    try:
        document = _json_bytes(chunks[0][1].rstrip(b" \t\r\n\x00"), label+" JSON chunk")
    except ContractError:
        raise
    if not isinstance(document, dict) or not isinstance(document.get("asset"), dict) or document["asset"].get("version") != "2.0":
        fail(f"{label}: glTF asset.version must be 2.0")
    nodes = document.get("nodes")
    if not isinstance(nodes, list):
        fail(f"{label}: nodes array missing")
    names = [n.get("name") for n in nodes if isinstance(n, dict)]
    for role in ROLES:
        if names.count(role) != 1:
            fail(f"{label}: requires exactly one {role} node")
    buffers = document.get("buffers")
    binary = next((payload for kind, payload in chunks if kind == b"BIN\x00"), None)
    if not isinstance(buffers, list) or len(buffers) != 1 or not isinstance(buffers[0], dict) or not isinstance(binary, bytes):
        fail(f"{label}: require one embedded GLB binary buffer")
    buffer_length = buffers[0].get("byteLength")
    if type(buffer_length) is not int or buffer_length < 1 or buffer_length > len(binary) or "uri" in buffers[0]:
        fail(f"{label}: GLB buffer must be embedded and bounded")
    views = document.get("bufferViews")
    images = document.get("images")
    textures = document.get("textures")
    materials = document.get("materials")
    if not isinstance(views, list) or not isinstance(images, list) or not images or not isinstance(textures, list) or not textures or not isinstance(materials, list) or not materials:
        fail(f"{label}: embedded images/material texture chain missing")
    for view in views:
        if not isinstance(view, dict) or view.get("buffer") != 0:
            fail(f"{label}: bufferView must target the embedded buffer")
        start = view.get("byteOffset", 0)
        length = view.get("byteLength")
        if type(start) is not int or type(length) is not int or start < 0 or length < 1 or start + length > buffer_length:
            fail(f"{label}: bufferView outside embedded binary")
    image_views = set()
    embedded = []
    for image in images:
        if not isinstance(image, dict) or "uri" in image or type(image.get("bufferView")) is not int:
            fail(f"{label}: every image must be embedded by bufferView")
        view_i = image["bufferView"]
        if view_i < 0 or view_i >= len(views) or image.get("mimeType") not in ("image/png", "image/jpeg"):
            fail(f"{label}: invalid embedded image reference/MIME")
        image_views.add(view_i)
        image_name = image.get("name")
        if not isinstance(image_name, str) or not image_name:
            fail(f"{label}: embedded image name required for source binding")
        view = views[view_i]
        start = view.get("byteOffset", 0)
        embedded.append({"name": Path(image_name).stem, "sha256": sha(binary[start:start+view["byteLength"]])})
    texture_sources = set()
    for texture in textures:
        if not isinstance(texture, dict) or type(texture.get("source")) is not int or texture["source"] < 0 or texture["source"] >= len(images):
            fail(f"{label}: texture must reference embedded image")
        texture_sources.add(texture["source"])
    if texture_sources != set(range(len(images))):
        fail(f"{label}: each embedded image must be used by a texture")
    used_textures = set()
    def scan_material(value, key=""):
        if isinstance(value, dict):
            for k, v in value.items():
                if k.endswith("Texture") and isinstance(v, dict) and type(v.get("index")) is int:
                    used_textures.add(v["index"])
                scan_material(v, k)
        elif isinstance(value, list):
            for item in value:
                scan_material(item, key)
    scan_material(materials)
    if used_textures != set(range(len(textures))):
        fail(f"{label}: every declared texture must be used by a material")
    if len({item["name"] for item in embedded}) != len(embedded):
        fail(f"{label}: duplicate embedded image names")
    return {"glb_json": document, "embedded_images": embedded, "embedded_image_buffer_views": sorted(image_views)}


CURRENT_MAIN_SHA = "c4519db809f974a2e11810742e72cdf926f4a1d515629565a6b73819aa0adcd1"
CURRENT_LEVEL_SHA = "93e6b9456e9348c1ba35b01d45b2338d71bbfd2aed0ac9f9d4607aca2437e871"
CURRENT_CONSUMER_HELPER_SHA = "9ba815bc1ef886536641147958521eb969dee2f26d137e6ea13d557c0d5d8e1e"
def _current_consumer_compatibility(root):
    import runpy
    path = safe_rel(root, "tools/art_consumer_compatibility.py", label="current consumer helper", roots={"tools"})
    if sha(path.read_bytes()) != CURRENT_CONSUMER_HELPER_SHA:
        fail("Exact reviewed current consumer helper required")
    return runpy.run_path(str(path))

MAIN_SOURCE = "game/scripts/main.gd"
HISTORICAL_MAIN_SHA = "ee987812f4ac985ed9c3ecc6f980d3fb0876507895e1e8b6156cf20c6372f531"
SELFTEST_MAIN_SHA = "cf4624fa56bb0ecd634e63c0c2ca15b98f4298b4f05365e3a55cdc85d6d52bb0"
MAIN_COMPATIBILITY_SCOPE = "historical-gate-evidence-reuse-only-not-current-native-qualification"
MAIN_SELFTEST_REPLACEMENTS = [{'function': '_verify_export', 'before': '\t\t\tchecks[id+"_actor_"+actor.id] = actor._current_map() and actor.hp > 0 and actor.sprite.texture is Texture2D and actor.sprite.texture.get_width() == cell*8 and actor.sprite.texture.get_height() == cell*5', 'after': '\t\t\t# Fixed qualified body contract: Worker has six physiology rows; other roles retain five.\n\t\t\tvar expected_rows = 6 if actor.kind == "worker" else 5\n\t\t\tchecks[id+"_actor_"+actor.id] = actor._current_map() and actor.hp > 0 and actor.sprite.texture is Texture2D and actor.sprite.texture.get_width() == cell*8 and actor.sprite.texture.get_height() == cell*expected_rows'}, {'function': '_verify_sprite_hit_export', 'before': '\t_sprite_export_check(checks,"original_worker_atlas",valid and sprite.texture.resource_path=="res://assets/art/sprites/worker.png")', 'after': '\t# Pin the approved production body URI independently of Enemy selection; legacy is not a fallback.\n\t_sprite_export_check(checks,"original_worker_atlas",valid and sprite.texture.resource_path=="res://assets/art/sprites/bodies-v1/worker.png")'}]

def _qualified96_generation(root):
    compat = _current_consumer_compatibility(root)
    value = compat['qualify'](root)
    if (not isinstance(value, dict)
            or value.get('schema') != 'null-choir-exact-current-art-consumers-v0096-v1'
            or value.get('status') != 'ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED'):
        fail("Full exact actual96 qualification required before historical threshold reuse")
    return compat, value


def _qualified96_threshold_source(root, relative, supplied, expected_sha):
    """No source alias: current supplied=resident=receipt, then exact history."""
    if relative not in (MAIN_SOURCE, "game/scripts/level.gd"):
        fail("Only Main/Level may consume the qualified96 threshold source bridge")
    compat, value = _qualified96_generation(root)
    row = value.get('current_sources', {}).get(relative)
    if (not isinstance(row, dict) or row.get('path') != relative
            or type(supplied) is not bytes or supplied != compat['record'](root, row)):
        fail("Supplied threshold source differs from exact resident/final96 receipt")
    historical = value.get('historical_sources', {}).get(relative)
    if not isinstance(historical, dict) or historical.get('sha256') != expected_sha:
        fail("Only the exact retained historical threshold source is supported")
    data = compat['record'](root, historical)
    if sha(data) != expected_sha:
        fail("Historical threshold source hash mismatch")
    return data


GATE_FIXTURE_SOURCE = "game/tests/test_gate_integration.gd"
GATE_FIXTURE_CURRENT_SHA = "c64d80008ffc4114b4e1f4601733f092647e41bba2d105793129030a25676522"
GATE_FIXTURE_HISTORICAL_SHA = "9f651471dd0b9537fe6aa35efa34e457b3a2a67933de54045bae9cb00b257237"
GATE_FIXTURE_INVERSE_EDITS = (
    ("_level", 1,
     b'\tif not level.build(main,index):\n\t\tcheck(false,"Actual current Level builds")\n\t\tmain.level = null\n\t\tlevel.free()\n\t\treturn null',
     b'\tcheck(level.build(main,index),"Actual current Level builds")'),
    ("run", 3, b'\tif level == null: main.free();quit(1);return\n', b''),
)


def _gate_fixture_source_compatibility(current):
    """Source-only fail-fast inverse proof, NOT current native qualification."""
    if type(current) is not bytes or sha(current) != GATE_FIXTURE_CURRENT_SHA:
        fail("Exact current fail-fast gate integration fixture required")
    reconstructed = current
    for function, count, before, after in GATE_FIXTURE_INVERSE_EDITS:
        marker = ("\nfunc " + function + "(").encode()
        start = current.find(marker)
        end = current.find(b"\nfunc ", start + 1) if start >= 0 else -1
        if end < 0: end = len(current)
        if (current.count(marker) != 1 or current.count(before) != count
                or start < 0 or current[start:end].count(before) != count):
            fail("Exact gate fixture inverse count/function seam required")
        reconstructed = reconstructed.replace(before, after, count)
    if sha(reconstructed) != GATE_FIXTURE_HISTORICAL_SHA:
        fail("Gate fixture inverse differs from exact historical successful-path source")
    return reconstructed


def _main_selftest_compatibility(root: Path, record, owned: set[str]) -> dict | None:
    if record is None:
        return None
    descriptor_path, raw = checked_file(root, record, label="Main selftest compatibility", roots={"source"}, owned=owned)
    if not descriptor_path.relative_to(root).as_posix().startswith(SOURCE_ROOT + "/compatibility/"):
        fail("Main compatibility descriptor must be retained under threshold compatibility source")
    value = _json_bytes(raw, "Main selftest compatibility")
    _reject_private_strings(value, "Main compatibility")
    if (not isinstance(value, dict) or value.get("schema") != "null-choir.threshold-main-selftest-compatibility"
            or value.get("schema_version") != 1 or value.get("kind") != "exact-main-selftest-two-site-v1"
            or value.get("claim_scope") != MAIN_COMPATIBILITY_SCOPE
            or value.get("fresh_native_qualification") is not False
            or value.get("replacements") != MAIN_SELFTEST_REPLACEMENTS):
        fail("Main compatibility requires the exact two selftest-only replacement records/scope")
    historical = value.get("historical_source")
    current = value.get("current_source")
    if (historical != {"path": SOURCE_ROOT + "/compatibility/main-before-worker-selftest-fix.gd", "sha256": HISTORICAL_MAIN_SHA}
            or current != {"path": MAIN_SOURCE, "sha256": SELFTEST_MAIN_SHA}):
        fail("Main compatibility must bind the one exact historical/current Main pair")
    _, original = checked_file(root, historical, label="Historical Main snapshot", roots={"source"}, owned=owned)
    actual_main = safe_rel(root, MAIN_SOURCE, label="Actual Main", roots={"game"}).read_bytes()
    if sha(actual_main) == SELFTEST_MAIN_SHA:
        _, current_bytes = checked_file(root, current, label="Compatible current Main", roots={"game"})
    elif sha(actual_main) == CURRENT_MAIN_SHA:
        # Reconstruct the OLD two-site selftest bridge against its historical
        # Git snapshot; qualify the current generation in a separate receipt.
        current_bytes = _current_consumer_compatibility(root)['historical'](root, MAIN_SOURCE, SELFTEST_MAIN_SHA)
    else:
        try:
            current_bytes = _qualified96_threshold_source(root, MAIN_SOURCE, actual_main, SELFTEST_MAIN_SHA)
        except (ValueError, OSError) as exc:
            fail("Main compatibility reconstruction requires exact qualified96 source: " + str(exc))
    reconstructed = original
    for edit in MAIN_SELFTEST_REPLACEMENTS:
        before, after = edit["before"].encode(), edit["after"].encode()
        marker = ("\nfunc " + edit["function"] + "(").encode()
        start = original.find(marker)
        end = original.find(b"\nfunc ", start + 1) if start >= 0 else -1
        if end < 0:
            end = len(original)
        position = original.find(before)
        if original.count(before) != 1 or start < 0 or not start < position < end:
            fail("Main compatibility replacement must occur once in its exact selftest function")
        reconstructed = reconstructed.replace(before, after, 1)
    if reconstructed != current_bytes:
        fail("Main compatibility reconstruction differs: unrelated source changes are forbidden")
    return {"historical_sha256": HISTORICAL_MAIN_SHA, "current_sha256": SELFTEST_MAIN_SHA,
            "scope": MAIN_COMPATIBILITY_SCOPE, "descriptor_sha256": sha(raw)}


def _native_receipt(root: Path, entry: dict, *, asset_id: str, source_dir: str,
                    runtime_sha: str, source_sha: str, source_proof_sha: str,
                    owned: set[str], main_compatibility: dict | None = None) -> None:
    receipt_path, raw = checked_file(root, entry.get("native_qualification"), label=f"{asset_id} native qualification receipt", roots={"source"}, owned=owned)
    if not receipt_path.relative_to(root).as_posix().startswith(source_dir + "/"):
        fail(f"{asset_id}: native receipt outside per-gate source folder")
    receipt = _json_bytes(raw, f"{asset_id} native qualification receipt")
    _reject_private_strings(receipt, f"{asset_id} native receipt")
    if not isinstance(receipt, dict) or receipt.get("schema") != "null-choir.threshold-native-qualification":
        fail(f"{asset_id}: native qualification must reference a structured source-bound run receipt")
    expected = {
        "asset_id": asset_id, "runtime_sha256": runtime_sha,
        "source_blend_sha256": source_sha, "source_proof_sha256": source_proof_sha,
        "exit_code": 0, "strict": True, "diagnostics": [],
    }
    for key, value in expected.items():
        if receipt.get(key) != value:
            fail(f"{asset_id}: native run receipt binding/failure at {key}")
    if not isinstance(receipt.get("engine_version"), str) or not receipt["engine_version"].strip():
        fail(f"{asset_id}: native receipt lacks engine version")
    if not isinstance(receipt.get("run_id"), str) or not receipt["run_id"].strip():
        fail(f"{asset_id}: native receipt lacks run identity")
    if receipt.get("claim_scope") != "normal-import-and-runtime-consumer":
        fail(f"{asset_id}: native receipt scope must be normal import/runtime consumer")
    if receipt.get("source_only") is True or receipt.get("visual_acceptance") is True:
        fail(f"{asset_id}: native receipt cannot be a static/source or visual-acceptance claim")
    code_hashes = receipt.get("code_source_hashes")
    if not isinstance(code_hashes, dict) or set(code_hashes) != set(NATIVE_CODE_SOURCES):
        fail(f"{asset_id}: native receipt must bind all six current integration/fixture sources")
    for path_text in NATIVE_CODE_SOURCES:
        path = safe_rel(root, path_text, label=f"{asset_id} native source binding", roots={"game"})
        current_hash = sha(path.read_bytes()) if path.is_file() else None
        if code_hashes.get(path_text) == current_hash and current_hash is not None:
            continue
        if (path_text == MAIN_SOURCE and main_compatibility is not None
                and code_hashes.get(path_text) == HISTORICAL_MAIN_SHA
                and current_hash == SELFTEST_MAIN_SHA
                and main_compatibility.get("historical_sha256") == HISTORICAL_MAIN_SHA
                and main_compatibility.get("current_sha256") == SELFTEST_MAIN_SHA):
            continue  # Explicit static source compatibility; receipt remains historical.
        if ((path_text == MAIN_SOURCE and current_hash == CURRENT_MAIN_SHA)
                or (path_text == "game/scripts/level.gd" and current_hash == CURRENT_LEVEL_SHA)):
            compat = _current_consumer_compatibility(root)
            expected = SELFTEST_MAIN_SHA if path_text == MAIN_SOURCE else code_hashes.get(path_text)
            historical = compat['historical'](root, path_text, expected)
            if sha(historical) == code_hashes.get(path_text):
                continue
            if (path_text == MAIN_SOURCE and code_hashes.get(path_text) == HISTORICAL_MAIN_SHA
                    and main_compatibility is not None):
                continue  # Exact original two-site bridge already reconstructed above.
        if path_text in (MAIN_SOURCE, "game/scripts/level.gd"):
            try:
                expected = SELFTEST_MAIN_SHA if path_text == MAIN_SOURCE else code_hashes.get(path_text)
                historical = _qualified96_threshold_source(root, path_text, path.read_bytes(), expected)
                if sha(historical) == code_hashes.get(path_text):
                    continue
                if (path_text == MAIN_SOURCE and code_hashes.get(path_text) == HISTORICAL_MAIN_SHA
                        and main_compatibility is not None
                        and main_compatibility.get("historical_sha256") == HISTORICAL_MAIN_SHA
                        and main_compatibility.get("current_sha256") == SELFTEST_MAIN_SHA
                        and main_compatibility.get("scope") == MAIN_COMPATIBILITY_SCOPE):
                    continue  # Unchanged exact two-site inverse bridge above; old receipt stays old.
            except (ValueError, OSError) as exc:
                fail(f"{asset_id}: native receipt source hash is stale at {path_text}: {exc}")
        if (path_text == GATE_FIXTURE_SOURCE and current_hash == GATE_FIXTURE_CURRENT_SHA
                and code_hashes.get(path_text) == GATE_FIXTURE_HISTORICAL_SHA):
            _qualified96_generation(root)
            _gate_fixture_source_compatibility(path.read_bytes())
            continue  # Source-only failure-stop cleanup; no new native fixture qualification.
        fail(f"{asset_id}: native receipt source hash is stale at {path_text}")


def _independent_pass(root: Path, entry: dict, *, asset_id: str, source_dir: str,
                      runtime_sha: str, owned: set[str]) -> None:
    record = entry.get("independent_intended_use")
    review_path, raw = checked_file(root, record, label=f"{asset_id} independent intended-use evidence", roots={"source"}, owned=owned)
    if not review_path.relative_to(root).as_posix().startswith(source_dir + "/"):
        fail(f"{asset_id}: independent review outside per-gate source folder")
    review = _json_bytes(raw, f"{asset_id} independent review")
    _reject_private_strings(review, f"{asset_id} independent review")
    if not isinstance(review, dict):
        fail(f"{asset_id}: independent review must be a structured artifact-bound receipt")
    if review.get("asset_id") != asset_id or review.get("asset_sha256") != runtime_sha:
        fail(f"{asset_id}: independent decision is not bound to exact runtime artifact")
    if review.get("decision") != "PASS" or review.get("scope") != REVIEW_SCOPE or review.get("reviewer_independent") is not True:
        fail(f"{asset_id}: independent intended-use PASS with the required scope is absent")
    required = {"actual_level": True, "closed": True, "four_key_states": True, "released": True, "front_and_back": True}
    if review.get("coverage") != required:
        fail(f"{asset_id}: independent review scope does not cover required intended-use states")


def validate_ledger(root: Path, ledger_path: str | Path, *, allow_partial: bool = False) -> dict:
    """Validate a candidate ledger; full exact-eight is mandatory unless explicitly test-only partial."""
    root = Path(root).absolute()
    if not root.is_dir() or any(p.is_symlink() for p in (root, *root.parents)):
        fail("repository root must be an existing nonsymlink directory")
    doors = _door_contract(root)
    if isinstance(ledger_path, Path):
        try:
            ledger_rel = ledger_path.absolute().relative_to(root).as_posix()
        except ValueError:
            fail("ledger path outside repository")
    else:
        ledger_rel = ledger_path
    if not isinstance(ledger_rel, str) or not ledger_rel.startswith("source/art/") or ledger_rel == "source/art/manifest.json":
        fail("threshold ledger must be a separate source/art record; legacy catalog is immutable")
    ledger_file = safe_rel(root, ledger_rel, label="ledger", roots={"source"})
    if not ledger_file.is_file():
        fail("threshold ledger missing")
    ledger = read_json(ledger_file)
    if not isinstance(ledger, dict):
        fail("ledger root must be an object")
    _reject_private_strings(ledger)
    if ledger.get("schema") != SCHEMA or ledger.get("schema_version") != VERSION or ledger.get("kind") != "eight-authored-threshold-assets":
        fail("unsupported threshold ledger schema/kind")
    entries = ledger.get("assets")
    if not isinstance(entries, list) or not entries:
        fail("assets must be a nonempty array")
    ids = [entry.get("id") for entry in entries if isinstance(entry, dict)]
    expected_ids = set(doors)
    if len(ids) != len(entries) or len(ids) != len(set(ids)) or not set(ids) <= expected_ids:
        fail("unknown, malformed, or duplicate threshold asset IDs")
    complete = set(ids) == expected_ids
    if not complete and not allow_partial:
        fail("release ledger requires exact complete GateArt.REGISTRY / game-data eight IDs")
    if complete and len(entries) != 8:
        fail("release ledger must contain exactly eight assets")
    if not complete and allow_partial and len(entries) >= 8:
        fail("partial candidate must be a strict subset of the eight IDs")

    owned: set[str] = set()
    main_compatibility = _main_selftest_compatibility(root, ledger.get("native_code_compatibility"), owned)
    runtime_paths: set[str] = set()
    normalized = []
    for entry in entries:
        asset_id = entry["id"]
        spec = doors[asset_id]
        source_dir = f"{SOURCE_ROOT}/{spec['scene']}"
        if entry.get("dimensions") != spec["size"]:
            fail(f"{asset_id}: ledger dimensions differ from actual game/data door JSON")
        runtime = entry.get("runtime")
        if not isinstance(runtime, dict) or runtime.get("path") != spec["runtime_path"] or runtime.get("uri") != spec["runtime_uri"]:
            fail(f"{asset_id}: exact GateArt runtime path/URI mismatch")
        runtime_file, runtime_bytes = checked_file(root, {"path": runtime.get("path"), "sha256": runtime.get("sha256")}, label=f"{asset_id} runtime GLB", roots={"game"}, owned=owned)
        if runtime_file.relative_to(root).as_posix() != spec["runtime_path"] or (runtime.get("bytes") != len(runtime_bytes)):
            fail(f"{asset_id}: runtime GLB byte count/path mismatch")
        runtime_sha = sha(runtime_bytes)
        glb = _check_glb(runtime_bytes, label=f"{asset_id} runtime GLB")
        if runtime.get("uri") != spec["runtime_uri"]:
            fail(f"{asset_id}: runtime resource URI mismatch")
        if runtime["path"] in runtime_paths:
            fail(f"{asset_id}: runtime GLB output multiply owned")
        runtime_paths.add(runtime["path"])

        policy = entry.get("importer_policy")
        expected_policy = {"importer": "scene", "resource_type": "PackedScene", "embedded_image_handling": 3}
        if policy != expected_policy:
            fail(f"{asset_id}: importer policy must use scene/PackedScene and embedded image handling 3")
        sidecar_path = runtime["path"] + ".import"
        sidecar = safe_rel(root, sidecar_path, label=f"{asset_id} importer sidecar", roots={"game"})
        if not sidecar.is_file():
            fail(f"{asset_id}: normal Godot scene import sidecar missing")
        side_text = sidecar.read_text(encoding="utf-8")
        for token in ('importer="scene"', 'type="PackedScene"', f'source_file="{runtime["uri"]}"', "gltf/embedded_image_handling=3"):
            if token not in side_text:
                fail(f"{asset_id}: importer sidecar missing {token}")
        if sidecar_path in owned:
            fail(f"{asset_id}: importer sidecar multiply owned")
        owned.add(sidecar_path)

        source = entry.get("source_blend")
        source_file, source_bytes = checked_file(root, source, label=f"{asset_id} editable Blender source", roots={"source"}, owned=owned)
        if not source_file.relative_to(root).as_posix().startswith(source_dir + "/") or not source_file.name.endswith(".blend"):
            fail(f"{asset_id}: source must be a portable per-gate .blend under its versioned source folder")
        if not source_bytes.startswith((b"BLENDER", ZSTD_MAGIC)):
            fail(f"{asset_id}: source must have Blender or Zstandard container marker")
        source_sha = sha(source_bytes)

        recipe_file, recipe_bytes = checked_file(root, entry.get("recipe"), label=f"{asset_id} source recipe", roots={"source"}, owned=owned)
        if not recipe_file.relative_to(root).as_posix().startswith(source_dir + "/") or recipe_file.suffix != ".py":
            fail(f"{asset_id}: recipe must be repository-local Python source beside its gate")
        if not recipe_bytes:
            fail(f"{asset_id}: empty source recipe")

        uv_file, uv_bytes = checked_file(root, entry.get("uv_registration"), label=f"{asset_id} UV registration", roots={"source"}, owned=owned)
        if not uv_file.relative_to(root).as_posix().startswith(source_dir + "/"):
            fail(f"{asset_id}: UV registration outside gate source folder")
        uv = _json_bytes(uv_bytes, f"{asset_id} UV registration")
        _reject_private_strings(uv, f"{asset_id} UV registration")
        if not isinstance(uv, dict) or not isinstance(uv.get("coordinates"), str) or not isinstance(uv.get("membrane"), dict) or not isinstance(uv.get("hardware"), dict):
            fail(f"{asset_id}: UV registration must describe membrane and hardware mapping")
        uv_sha = sha(uv_bytes)

        inputs = entry.get("used_raw_inputs")
        if not isinstance(inputs, list) or not inputs:
            fail(f"{asset_id}: used raw inputs with hashes are required")
        input_hashes = {}
        input_hashes_by_path = {}
        local_input_paths = set()
        for raw in inputs:
            _, raw_bytes = checked_file(root, raw, label=f"{asset_id} raw source input", roots={"source"})
            path_text = raw["path"]
            if not path_text.startswith(source_dir + "/raw/") or not path_text.lower().endswith((".png", ".jpg", ".jpeg", ".exr", ".tif", ".tiff")):
                fail(f"{asset_id}: raw input must remain under the per-gate raw/ folder")
            if path_text.lower().endswith(".png") and not raw_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
                fail(f"{asset_id}: .png raw input lacks PNG signature")
            if path_text.lower().endswith((".jpg", ".jpeg")) and not raw_bytes.startswith(b"\xff\xd8\xff"):
                fail(f"{asset_id}: JPEG raw input lacks JPEG signature")
            if path_text in local_input_paths:
                fail(f"{asset_id}: duplicate raw input reference")
            local_input_paths.add(path_text)
            input_name = Path(path_text).stem
            if input_name in input_hashes:
                fail(f"{asset_id}: duplicate raw input stem makes image binding ambiguous")
            input_hashes[input_name] = sha(raw_bytes)
            input_hashes_by_path[path_text] = sha(raw_bytes)
        for section in (uv.get("membrane"), uv.get("hardware")):
            uv_raw = section.get("file")
            uv_hash = section.get("sha256")
            if not isinstance(uv_raw, str) or not isinstance(uv_hash, str):
                fail(f"{asset_id}: UV material mapping must bind its raw image")
            uv_path = source_dir + "/" + uv_raw if not uv_raw.startswith(source_dir + "/") else uv_raw
            if input_hashes_by_path.get(uv_path) != uv_hash:
                fail(f"{asset_id}: UV material input differs from used raw-input ledger")

        source_proof_file, source_proof_bytes = checked_file(root, entry.get("source_proof"), label=f"{asset_id} editable source/export proof", roots={"source"}, owned=owned)
        if not source_proof_file.relative_to(root).as_posix().startswith(source_dir + "/"):
            fail(f"{asset_id}: source/export proof outside gate source folder")
        source_proof = _json_bytes(source_proof_bytes, f"{asset_id} source/export proof")
        _reject_private_strings(source_proof, f"{asset_id} source proof")
        if not isinstance(source_proof, dict):
            fail(f"{asset_id}: source proof root must be an object")
        source_proof_sha = sha(source_proof_bytes)
        proof_expected = {"source_sha256": source_sha, "recipe_sha256": sha(recipe_bytes),
                          "candidate_glb_sha256": runtime_sha, "candidate_glb_bytes": len(runtime_bytes)}
        for key, value in proof_expected.items():
            if source_proof.get(key) != value:
                fail(f"{asset_id}: source proof binding mismatch at {key}")
        if source_proof.get("source") != source_file.name or source_proof.get("recipe") != recipe_file.name:
            fail(f"{asset_id}: source proof names differ from retained source and recipe")
        packed = source_proof.get("packed_images")
        if not isinstance(packed, list) or not packed:
            fail(f"{asset_id}: source proof must enumerate packed source images")
        packed_by_name = {}
        for item in packed:
            if not isinstance(item, dict) or not isinstance(item.get("name"), str) or not isinstance(item.get("packed_sha256"), str):
                fail(f"{asset_id}: malformed packed source image proof")
            stem = Path(item["name"]).stem
            if stem in packed_by_name or input_hashes.get(stem) != item["packed_sha256"]:
                fail(f"{asset_id}: packed source image does not bind a used raw input")
            packed_by_name[stem] = item["packed_sha256"]
        actual_embedded = {item["name"]: item["sha256"] for item in glb["embedded_images"]}
        if actual_embedded != packed_by_name:
            fail(f"{asset_id}: GLB embedded image bytes differ from Blender packed-source proof")

        _native_receipt(root, entry, asset_id=asset_id, source_dir=source_dir, runtime_sha=runtime_sha,
                        source_sha=source_sha, source_proof_sha=source_proof_sha, owned=owned, main_compatibility=main_compatibility)
        _independent_pass(root, entry, asset_id=asset_id, source_dir=source_dir, runtime_sha=runtime_sha, owned=owned)
        normalized.append({"id": asset_id, "runtime_path": runtime["path"], "runtime_sha256": runtime_sha,
                           "source_sha256": source_sha, "embedded_images": len(glb["embedded_images"])})
    if len(runtime_paths) != len(entries):
        fail("duplicate runtime path ownership")
    return {
        "status": "STRUCTURAL_EIGHT_THRESHOLD_LEDGER_VALID" if complete else "INCOMPLETE_CANDIDATE_NOT_RELEASE_VALID",
        "assets": len(entries), "complete_registry": complete,
        "runtime_assets": sorted(normalized, key=lambda row: row["id"]),
        "native_main_source_compatibility": main_compatibility,
        "note": "Structural source/binding/container/import checks only. Validator does not authenticate native execution, score art, or make publication/release decisions."
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", help="Repository-relative threshold art ledger JSON under source/")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[1]), help="Repository root")
    args = parser.parse_args()
    try:
        result = validate_ledger(Path(args.root), args.ledger)
    except (ContractError, OSError, UnicodeError) as exc:
        print(f"FAIL: {exc}")
        return 1
    print("PASS: " + json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
